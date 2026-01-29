# 双批次重叠（Dual Batch Overlap）

## 动机

vLLM 中 DBO 系统的核心动机是将 MoE 层中的稀疏全对全通信与周围的计算重叠。该系统目前仅针对 DP+EP 部署。

## 简介

双批次重叠系统通过在模型运行器中拆分批次、创建两个工作线程，然后在每个工作线程上运行模型来工作。当启用 DBO 时，`FusedMoEModularKernel` 中的 yield 点允许两个 CPU 工作线程（也称为 UBatch 线程）相互乒乓切换，以便当一个线程运行计算时，另一个线程等待通信。在代码中，ubatch 可能被用作 microbatch 的简写；这是简写形式 µ-batch 的 ASCII 友好版本。

DBO 系统包括对 `GpuModelRunner` 和 `ModularKernel` 的修改，并定义了两个实用类：`UBatchWrapper` 和 `UBatchContext`。`UBatchWrapper` 管理线程生命周期和模型的 CUDA 图执行。`UBatchContext` 包装 `ForwardContext` 以协调两个 UBatch 线程之间的同步。

以下是当前在 vLLM 中实现的重叠调度。

```python
# 调度符号说明：
#    S = 共享专家
#    A0 = MLA qkv proj,
#    A1 = 核心注意力 + 输出投影 + MoE 门控
#    D = 分发
#    C = 合并

# 计算: |-A0₀-A1₀-||-MLP₁-||-S₁-MLP₀-||-S₀-A0₁-A1₁-|
# 通信: |----D₁---||--D₀--||----C₁---||-----C₀-----|
# 顺序: D₁ 发送, A0₀, A1₀, D₁ 接收, D₀ 发送, MLP₁, D₀ 接收,
#        C₁ 发送, S₁, MLP₀, C₁ 接收, C₀ 发送, S₀, A0₁, A1₁, C₀ 接收.
# MLP_SHARED_OVERLAP = "mlp_shared_overlap"
```

## 使用 DBO 运行

要启用 DBO 系统，请在 vllm serve 命令中传入 `--enable-dbo` 参数。这必须与 `--data-parallel-size N`（其中 N 大于 1）和 `--enable-expert-parallel` 一起使用。此外，还有两个配置旋钮。

* `--dbo-decode-token-threshold` 启用 DBO 所需的仅解码批次中的最小 token 数量
* `--dbo-prefill-token-threshold` 启用 DBO 所需的包含至少一个预填充的批次中的最小 token 数量

目前，DBO 仅支持 DeepEP，因此必须安装 DeepEP，并且如果工作负载主要是解码请求，则必须将 `--all2all-backend` 参数设置为 `deepep_low_latency`；如果工作负载主要是预填充请求，则必须设置为 `deepep_high_throughput`。

以下是一个命令，将启动一个具有专家并行性和 DBO 启用的两个 DP 秩服务器。
例如：`vllm serve deepseek-ai/DeepSeek-V2-Lite --trust-remote-code --data-parallel-size 2 --enable-expert-parallel --enable-dbo --all2all-backend deepep_low_latency`

请注意，`CUDA_VISIBLE_DEVICES` 中必须至少有两个可见的 GPU。

## DBO 组件

* GPUModelRunner
* UBatchWrapper
* UBatchContext

### GPU 模型运行器

`GPUModelRunner` 类将批次拆分为微批次。这通过两个步骤完成。首先，在所有 DP 秩之间进行协调，以确定是否将应用微批处理。微批处理必须在所有 DP 秩之间保持一致。如果任何 DP 秩无法进行微批处理，则对所有秩禁用微批处理。如果所有 DP 秩都将进行微批处理，则总 token 数将填充到所有秩中的最大 token 数。如果在应用填充后任何秩最终会得到一个空的第二个微批次，则将中止微批处理，并且没有秩会进行微批处理。一旦所有秩都启动了微批处理，将执行第二步。`GPUModelRunner` 将 `CommonAttentionMetadata` 切成两半，以便每个微批次都有一个注意力元数据。

### UBatchWrapper

gpu_ubatch_wrapper

`UBatchWrapper` 类是一个模型包装器，负责 DBO 的所有线程、UBatchContext 和 CUDA 图管理。它的设计对 GPU 模型运行器相对透明。

实现运行模型两次，每个微批次一次。每次模型调用都发生在一个 UBatch 线程中。这些线程并行启动，并使用 `UBatchContext` 进行同步。每个线程都提供了一个切片版本的注意力元数据，用于运行其批次的一半。

DBO 的 CUDA 图完全由 `UBatchWrapper` 管理。因此，DBO 仅支持使用完整 CUDA 图运行。但是，一旦捕获了 DBO CUDA 图，就可以无需任何多线程或 CPU 同步地重放它。

#### 接口

`__init__` 方法接收模型、VllmConfig、CUDAGraphMode 和设备。

`forward` 方法专门接收模型参数。它根据 `forward_context` 中是否存在 `ubatch_slices` 对象来确定是否使用 DBO 运行。否则，模型将在没有 DBO 的情况下运行。

### UBatchContext

ubatch_context

`UBatchContext` 类是一个 `ForwardContext` 包装器类，由 `UBatchWrapper` 类用于同步两个 UBatch 线程。它应该仅通过使用 `make_ubatch_contexts` 实例化。

当其中一个 UBatch 线程到达 `dbo_yield` 调用时，它会暂停，并启动另一个线程，该线程将运行直到到达相同的 `dbo_yield` 调用。这种“乒乓”动态继续，线程在每个 `dbo_yield` 调用时交换，直到模型的执行完成。

当前实现在 `FusedMoEModularKernel.forward` 方法中包含了所有 `dbo_yield` 和 `dbo_maybe_run_recv_hook` 调用。

#### 接口

`make_ubatch_context` 函数初始化两个 `UBatchContexts`，每个 UBatch 线程一个。它接收两个 CUDA 流、预先存在的 `ForwardContexts` 和一个 CPU 线程屏障。该函数应专门用于实例化 `UBatchContexts`。它将处理所有事件初始化。

`dbo_register_recv_hook` 方法注册一个回调，该回调可以由另一个 UBatch 线程的 `UBatchContext` 中的 `FusedMoEPrepareAndFinalize` 类返回。当另一个线程调用 `dbo_maybe_run_recv_hook` 时，将运行该回调。这通常用于等待全对全内核。

`dbo_maybe_run_recv_hook` 方法运行由 `dbo_register_recv_hook` 函数设置的回调（如果该回调存在）。

`dbo_yield` 方法使当前线程休眠并唤醒另一个 UBatch 线程。