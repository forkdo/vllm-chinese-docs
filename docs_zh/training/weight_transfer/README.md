# 权重传输

vLLM 提供了一个可插拔的权重传输系统，用于在强化学习（RL）工作流中将模型权重从训练过程同步到推理引擎。这对于 RLHF、GRPO 和其他在线 RL 方法至关重要，在这些方法中，策略模型在训练期间迭代更新，并且更新后的权重必须在推理引擎中反映以进行 rollout 生成。

## 架构

权重传输有**两个引擎，每个进程一个**，它们是对称的：

| | 训练器进程 | 推理工作进程 |
| --- | --- | --- |
| 类 | `TrainerWeightTransferEngine` | `WeightTransferEngine` |
| 构建者 | `WeightTransferTrainerFactory.trainer_init(...)` | vLLM，来自 `WeightTransferConfig` |
| 驱动方式 | `send_weights()` | 下面的四阶段协议 |
| 持有 | 通信器、传输计划、线束参数 | 通信器、目标模型 |

训练器引擎是有状态的：它拥有自己的通信器和线束参数，从[`WeightSource`](base.md#weightsource)拉取权重，并通过[`VLLMWeightSyncClient`](base.md#vllmweightsyncclient)驱动推理端。训练器代码永远不需要知道传输方式，也永远不需要在每个轮次中将传输状态线程回传——每次同步只需一次 `send_weights()` 调用。

在底层，每个轮次都是相同的**四阶段协议**，由训练器引擎代表您驱动：

1. **初始化** (`init_weight_transfer_engine`)：建立训练器和推理工作进程之间的通信通道。在训练循环开始之前从 `trainer_init` 调用一次。
2. **开始** (`start_weight_update`)：为权重更新准备推理引擎。
3. **权重更新** (`update_weights`)：传输更新的权重。可以调用一次或多次（例如，用于分块传输）。
4. **完成** (`finish_weight_update`)：完成更新（例如，为检查点格式权重运行后处理）。在所有权重传输完成后调用一次。

## 可用后端

| 后端 | 传输 | 使用场景 |
| ------- | --------- | -------- |
| [NCCL](nccl.md) | NCCL 广播 | 训练和推理使用独立 GPU |
| [IPC](ipc.md) | CUDA IPC 句柄 | 同一 GPU 上的共置训练和推理 |
| [sparse_nccl](nccl.md#稀疏-nccl) | NCCL 广播 | 稀疏扁平索引权重补丁（TP=1/PP=1） |
