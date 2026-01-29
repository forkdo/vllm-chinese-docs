# 优化与调优

本指南介绍了 vLLM V1 的优化策略和性能调优方法。

!!! tip
    内存不足？请参考[本指南](./conserving_memory.md)了解如何节省内存。

## 抢占机制

由于 Transformer 架构的自回归特性，有时 KV 缓存空间不足以处理所有批处理请求。  
在这种情况下，vLLM 会抢占部分请求以释放 KV 缓存空间供其他请求使用。当有足够 KV 缓存空间时，被抢占的请求会重新计算。  
此时，您可能会看到如下警告：

```text
WARNING 05-09 00:49:33 scheduler.py:1057 Sequence group 0 is preempted by PreemptionMode.RECOMPUTE mode because there is not enough KV cache space. This can affect the end-to-end performance. Increase gpu_memory_utilization or tensor_parallel_size to provide more KV cache memory. total_cumulative_preemption_cnt=1
```

虽然该机制能确保系统鲁棒性，但抢占和重计算可能会对端到端延迟产生负面影响。  
如果您频繁遇到抢占，请考虑以下操作：

- 增加 `gpu_memory_utilization`。vLLM 会按此百分比预分配 GPU 缓存。提高利用率可提供更多 KV 缓存空间。
- 减少 `max_num_seqs` 或 `max_num_batched_tokens`。这会降低每批处理的并发请求数，从而减少所需的 KV 缓存空间。
- 增加 `tensor_parallel_size`。这会将模型权重分片到多个 GPU 上，使每个 GPU 有更多内存可用于 KV 缓存。但增加该值可能导致同步开销过大。
- 增加 `pipeline_parallel_size`。这会将模型层分布到多个 GPU 上，减少每个 GPU 上模型权重的内存占用，从而间接为 KV 缓存提供更多内存。但增加该值可能导致延迟增加。

您可以通过 vLLM 暴露的 Prometheus 指标监控抢占请求数量。此外，通过设置 `disable_log_stats=False`，可以记录抢占请求的累计数量。

在 vLLM V1 中，默认抢占模式为 `RECOMPUTE` 而非 `SWAP`，因为在 V1 架构中重计算的开销更低。

## 分块预填充（Chunked Prefill）

分块预填充允许 vLLM 将大型预填充拆分为较小的块，并与解码请求一起批处理。此功能通过更好地平衡计算密集型（预填充）和内存密集型（解码）操作，有助于提高吞吐量和延迟。

在 V1 中，**只要可能，默认启用分块预填充**。启用分块预填充后，调度策略会优先处理解码请求。它会在调度任何预填充操作之前，将所有待处理的解码请求批处理。当 `max_num_batched_tokens` 预算中有可用 token 时，会调度待处理的预填充。如果待处理的预填充请求无法放入 `max_num_batched_tokens`，则会自动将其分块。

此策略有两个优势：

- 通过优先处理解码请求，改善了 ITL 和生成解码性能。
- 通过将计算密集型（预填充）和内存密集型（解码）请求放入同一批次，有助于实现更好的 GPU 利用率。

### 使用分块预填充进行性能调优

您可以通过调整 `max_num_batched_tokens` 来调优性能：

- 较小的值（例如 2048）可实现更好的 token 间延迟（ITL），因为减慢了预填充的解码请求更少。
- 较大的值可实现更好的首 token 时间（TTFT），因为可以在一个批次中处理更多预填充 token。
- 为获得最佳吞吐量，建议设置 `max_num_batched_tokens > 8192`，尤其是在大型 GPU 上运行较小模型时。
- 如果 `max_num_batched_tokens` 与 `max_model_len` 相同，则几乎等同于 V0 的默认调度策略（但仍会优先处理解码）。

!!! warning
    禁用分块预填充时，`max_num_batched_tokens` 必须大于 `max_model_len`。  
    否则，如果 `max_num_batched_tokens < max_model_len`，vLLM 可能在服务器启动时崩溃。

```python
from vllm import LLM

# 设置 max_num_batched_tokens 以调优性能
llm = LLM(model="meta-llama/Llama-3.1-8B-Instruct", max_num_batched_tokens=16384)
```

更多详情请参阅相关论文（<https://arxiv.org/pdf/2401.08671> 或 <https://arxiv.org/pdf/2308.16369>）。

## 并行策略

vLLM 支持多种并行策略，可组合使用以在不同硬件配置下优化性能。

### 张量并行（Tensor Parallelism, TP）

张量并行将每个模型层中的模型参数分片到多个 GPU 上。这是在单节点内进行大型模型推理最常用的策略。

**适用场景：**

- 当模型过大无法放入单个 GPU 时
- 当需要降低每个 GPU 的内存压力，以便为更高吞吐量提供更多 KV 缓存空间时

```python
from vllm import LLM

# 将模型分布到 4 个 GPU 上
llm = LLM(model="meta-llama/Llama-3.3-70B-Instruct", tensor_parallel_size=4)
```

对于无法放入单个 GPU 的模型（如 70B 参数模型），张量并行是必需的。

### 流水线并行（Pipeline Parallelism, PP）

流水线并行将模型层分布到多个 GPU 上。每个 GPU 按顺序处理模型的不同部分。

**适用场景：**

- 当已最大化高效张量并行但仍需进一步分布模型或跨节点时
- 对于非常深且窄的模型，层分布比张量分片更高效时

流水线并行可与张量并行结合用于超大型模型：

```python
from vllm import LLM

# 结合流水线并行和张量并行
llm = LLM(
    model="meta-llama/Llama-3.3-70B-Instruct",
    tensor_parallel_size=4,
    pipeline_parallel_size=2,
)
```

### 专家并行（Expert Parallelism, EP）

专家并行是专为混合专家（MoE）模型设计的一种特殊并行形式，其中不同的专家网络被分布到多个 GPU 上。

**适用场景：**

- 专门用于 MoE 模型（如 DeepSeekV3、Qwen3MoE、Llama-4）
- 当希望在 GPU 之间平衡专家计算负载时

通过设置 `enable_expert_parallel=True` 启用专家并行，这将使 MoE 层使用专家并行而非张量并行。  
其并行度将与您为张量并行设置的度数相同。

### 数据并行（Data Parallelism, DP）

数据并行将整个模型复制到多个 GPU 组上，并并行处理不同批次的请求。

**适用场景：**

- 当您有足够 GPU 可复制整个模型时
- 当需要扩展吞吐量而非模型大小时
- 在多用户环境中，请求批次之间需要隔离时

数据并行可与其他并行策略结合使用，通过 `data_parallel_size=N` 设置。  
注意，MoE 层将根据张量并行大小与数据并行大小的乘积进行分片。

### 多模态编码器的批次级 DP

默认情况下，TP 用于对多模态编码器的权重进行分片，就像对语言解码器一样，  
以降低每个 GPU 的内存和计算负载。

然而，由于多模态编码器的大小远小于语言解码器，  
TP 带来的收益相对较小。另一方面，TP 会带来显著的通信开销，  
因为每层之后都会执行 all-reduce 操作。

鉴于此，改为使用 TP 对批处理输入数据进行分片（即执行批次级 DP）可能更有利。  
这已被证明可将 `tensor_parallel_size=8` 时的吞吐量和 TTFT 提高约 10%。  
对于使用硬件未优化的 Conv3D 操作的视觉编码器，  
批次级 DP 相比常规 TP 可额外提升约 40% 的性能。

尽管如此，由于多模态编码器的权重会在每个 TP 秩上复制，  
内存消耗会有轻微增加，如果您刚好勉强能放下模型，可能会导致 OOM。

您可以通过设置 `mm_encoder_tp_mode="data"` 启用批次级 DP，例如：

```python
from vllm import LLM

```python
llm = LLM(
    model="Qwen/Qwen2.5-VL-72B-Instruct",
    tensor_parallel_size=4,
    # When mm_encoder_tp_mode="data",
    # the vision encoder uses TP=4 (not DP=1) to shard the input data,
    # so the TP size becomes the effective DP size.
    # Note that this is independent of the DP size for language decoder which is used in expert parallel setting.
    mm_encoder_tp_mode="data",
    # The language decoder uses TP=4 to shard the weights regardless
    # of the setting of mm_encoder_tp_mode
)
```

!!! important
    批次级别的 DP 不要与 API 请求级别的 DP 混淆
    （后者由 `data_parallel_size` 控制）。

批次级别的 DP 需要基于每个模型单独实现，
并通过在模型类中设置 `supports_encoder_tp_data = True` 来启用。
无论如何，你都需要在引擎参数中设置 `mm_encoder_tp_mode="data"` 才能使用此功能。

已知支持的模型（包含对应的基准测试）：

- dots_ocr (<https://github.com/vllm-project/vllm/pull/25466>)
- GLM-4.1V 或更高版本 (<https://github.com/vllm-project/vllm/pull/23168>)
- InternVL (<https://github.com/vllm-project/vllm/pull/23909>)
- Kimi-VL (<https://github.com/vllm-project/vllm/pull/23817>)
- Llama4 (<https://github.com/vllm-project/vllm/pull/18368>)
- MiniCPM-V-2.5 或更高版本 (<https://github.com/vllm-project/vllm/pull/23327>, <https://github.com/vllm-project/vllm/pull/23948>)
- Qwen2-VL 或更高版本 (<https://github.com/vllm-project/vllm/pull/22742>, <https://github.com/vllm-project/vllm/pull/24955>, <https://github.com/vllm-project/vllm/pull/25445>)
- Step3 (<https://github.com/vllm-project/vllm/pull/22697>)

## 输入处理

### 并行处理

你可以通过 [API 服务器横向扩展](../serving/data_parallel_deployment.md#internal-load-balancing) 来并行运行输入处理。
当输入处理（在 API 服务器内运行）
成为模型执行（在引擎核心内运行）的瓶颈，
并且你有额外的 CPU 容量时，这非常有用。

```console
# 运行 4 个 API 进程和 1 个引擎核心进程
vllm serve Qwen/Qwen2.5-VL-3B-Instruct --api-server-count 4

# 运行 4 个 API 进程和 2 个引擎核心进程
vllm serve Qwen/Qwen2.5-VL-3B-Instruct --api-server-count 4 -dp 2
```

!!! note
    API 服务器横向扩展仅适用于在线推理。

!!! warning
    默认情况下，每个 API 服务器使用 8 个 CPU 线程从请求数据中加载媒体项（例如图像）。

    如果你应用了 API 服务器横向扩展，请考虑调整 `VLLM_MEDIA_LOADING_THREAD_COUNT`
    以避免 CPU 资源耗尽。

!!! note
    API 服务器横向扩展会禁用 [多模态 IPC 缓存](#ipc-caching)，
    因为它需要 API 和引擎核心进程之间的一一对应关系。

    这不会影响 [多模态处理器缓存](#processor-caching)。

## 多模态缓存

多模态缓存避免了重复传输或处理相同的多模态数据，
这在多轮对话中很常见。

### 处理器缓存

多模态处理器缓存会自动启用，
以避免在 `BaseMultiModalProcessor` 中重复处理相同的多模态输入。

### IPC 缓存

当 API (`P0`) 和引擎核心 (`P1`) 进程之间存在一一对应关系时，
多模态 IPC 缓存会自动启用，
以避免在它们之间重复传输相同的多模态输入。

#### 键复制缓存

默认情况下，IPC 缓存使用 **键复制缓存**，其中缓存键存在于
API (`P0`) 和引擎核心 (`P1`) 进程中，但实际的缓存
数据仅驻留在 `P1` 中。

#### 共享内存缓存

当涉及多个工作进程时（例如，当 TP > 1 时），
**共享内存缓存** 更高效。这可以通过设置
`mm_processor_cache_type="shm"` 来启用。在此模式下，缓存键存储在
`P0` 上，而缓存数据本身则驻留在所有进程可访问的共享内存中。

### 配置

你可以通过设置 `mm_processor_cache_gb` 的值（默认为 4 GiB）来调整缓存的大小。

如果你从缓存中获益不多，你可以通过 `mm_processor_cache_gb=0` 完全禁用 IPC
和处理器缓存。

示例：

```python
# 使用更大的缓存
llm = LLM(
    model="Qwen/Qwen2.5-VL-3B-Instruct",
    mm_processor_cache_gb=8,
)

# 使用基于共享内存的 IPC 缓存
llm = LLM(
    model="Qwen/Qwen2.5-VL-3B-Instruct",
    tensor_parallel_size=2,
    mm_processor_cache_type="shm",
    mm_processor_cache_gb=8,
)

# 禁用缓存
llm = LLM(
    model="Qwen/Qwen2.5-VL-3B-Instruct",
    mm_processor_cache_gb=0,
)
```

### 缓存位置

根据配置，`P0` 和 `P1` 上多模态缓存的内容如下：

| mm_processor_cache_type | 缓存类型 | `P0` 缓存 | `P1` 引擎缓存 | `P1` 工作缓存 | 最大内存 |
|-------------------|-------------|------------|------------|-------------|-------------|
| lru | 处理器缓存 | K + V | N/A | N/A | `mm_processor_cache_gb * data_parallel_size` |
| lru | 键复制缓存 | K | K + V | N/A | `mm_processor_cache_gb * api_server_count` |
| shm | 共享内存缓存 | K | N/A | V | `mm_processor_cache_gb * api_server_count` |
| N/A | 禁用 | N/A | N/A | N/A | `0` |

K: 存储多模态项的哈希值
V: 存储多模态项的处理后的张量数据

## 注意力后端选择

vLLM 支持多个针对不同硬件和使用场景优化的注意力后端。后端会根据你的 GPU 架构、模型类型和配置自动选择，但你也可以手动指定一个以获得最佳性能。

有关可用后端、它们的功能支持以及如何配置它们的详细信息，请参阅 [注意力后端功能支持](../design/attention_backends.md) 文档。