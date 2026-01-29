# vLLM V1

!!! 公告

我们已完全弃用 V0。详情请阅读 [RFC #18571](https://github.com/vllm-project/vllm/issues/18571)。如果您有在 V0 引擎上可用但在 V1 上不可用的用例，请在 [GitHub](https://github.com/vllm-project/vllm) 或 [vLLM Slack](https://inviter.co/vllm-slack) 上分享。

vLLM V0 成功支持了广泛的模型和硬件，但随着新功能的独立开发，系统变得越来越复杂。这种复杂性使得集成新功能变得更加困难，并引入了技术债务，因此需要一个更精简、更统一的设计。

在 V0 成功的基础上，vLLM V1 保留了 V0 中稳定且经过验证的组件（如模型、GPU 内核和工具）。同时，它对核心系统进行了重大重构，涵盖调度器、KV 缓存管理器、工作进程、采样器和 API 服务器，以提供一个连贯、可维护的框架，更好地支持持续的增长和创新。

具体而言，V1 的目标是：

- 提供一个**简单、模块化且易于修改的代码库**。
- 确保**高性能**，CPU 开销接近零。
- 将**关键优化**整合到统一的架构中。
- 通过默认启用功能/优化，实现**零配置**。

升级到 V1 核心引擎带来了显著的性能提升，特别是在长上下文场景中。请参阅性能基准测试（待添加）。

更多详情请查看 vLLM V1 博客文章 [vLLM V1: A Major Upgrade to vLLM's Core Architecture](https://blog.vllm.ai/2025/01/27/v1-alpha-release.html)（发布于 2025 年 1 月 27 日）。

本动态用户指南概述了 vLLM V1 引入的一些已知**重要变更和限制**。团队一直在积极努力将 V1 作为默认引擎，因此随着更多功能在 vLLM V1 上得到支持，本指南将不断更新。

## 与 V0 的差异

本节列出了 V0 和 V1 之间的一些行为差异。

### 分块预填充 (Chunked Prefill)

与 V0 中根据模型特性有条件地启用不同，分块预填充现在在可能的情况下默认启用。

### CUDA 图 (CUDA Graphs)

在 V1 中，CUDA 图捕获比 V0 占用更多内存。

### Logprobs 的语义变化

#### Logprobs 计算

默认情况下，V1 中的 logprobs 现在一旦从模型的原始输出计算完成就会立即返回（即在应用任何 logits 后处理（如温度缩放或惩罚调整）之前）。因此，返回的 logprobs 不反映采样期间使用的最终调整后的概率。

您可以通过设置 `--logprobs-mode` 标志来调整此行为。支持四种模式：`raw_logprobs`（默认）、`processed_logprobs`、`raw_logits`、`processed_logits`。Raw 表示在应用任何 logit 处理器（如禁用词）之前的值。Processed 表示在应用所有处理器（包括温度和 top_k/top_p）之后的值。

#### 带前缀缓存的 Prompt Logprobs

虽然 V1 支持在启用前缀缓存的情况下传递 prompt logprobs，但它不再缓存 logprobs。对于需要 prompt logprobs 的请求，引擎将忽略前缀缓存并重新计算完整 prompt 的预填充以生成 logprobs。

## 功能支持

对于每个项目，其在 vLLM V1 中的支持状态分为以下几类：

- **🟢 可用**：完全可用，优化程度与 V0 相当或更好。
- **🟡 进行中**：计划加入 vLLM V1，已有开放的 PR/RFC。
- **🔴 已移除**：已从 vLLM V1 中移除。只有在有强烈需求时才会考虑重新引入。

!!! 注意

vLLM V1 的统一调度器通过使用简单的字典（例如 `{request_id: num_tokens}`）以相同的方式处理 prompt token 和输出 token，为每个请求动态分配固定的 token 预算，从而支持分块预填充、前缀缓存和投机解码等功能，无需在预填充和解码阶段之间进行严格分离。

V1 调度器支持多种调度策略，包括先来先服务（FCFS）和基于优先级的调度（根据分配的优先级处理请求，FCFS 作为平局决胜机制），可通过 `--scheduling-policy` 参数进行配置。

### 硬件

| 硬件 | 状态 |
|------------------|-----------------------------------------------|
| **NVIDIA** | <nobr>🟢</nobr> |
| **AMD** | <nobr>🟢</nobr> |
| **INTEL GPU** | <nobr>🟢</nobr> |
| **TPU** | <nobr>🟢</nobr> |
| **CPU** | <nobr>🟢</nobr> |

!!! 注意

更多硬件平台可能通过插件得到支持，例如：

- [vllm-ascend](https://github.com/vllm-project/vllm-ascend)
- [vllm-spyre](https://github.com/vllm-project/vllm-spyre)
- [vllm-gaudi](https://github.com/vllm-project/vllm-gaudi)
- [vllm-openvino](https://github.com/vllm-project/vllm-openvino)

请查看相应的仓库以获取更多详情。

### 模型

| 模型类型 | 状态 |
|-----------------------------|-------------------------------------------------------------------------|
| **仅解码器模型 (Decoder-only Models)** | <nobr>🟢</nobr> |
| **编码器-解码器模型 (Encoder-Decoder Models)** | <nobr>🟢 (Whisper), 🔴 (其他) </nobr> |
| **池化模型 (Pooling Models)** | <nobr>🟢</nobr> |
| **Mamba 模型 (Mamba Models)** | <nobr>🟢</nobr> |
| **多模态模型 (Multimodal Models)** | <nobr>🟢</nobr> |

请参阅下文了解 V1 中尚未支持或计划支持更多功能的模型状态。

#### 池化模型 (Pooling Models)

现已完全支持，last-pooling 模型新增了前缀缓存和分块预填充功能。我们正在努力为更多类别的池化模型启用前缀缓存和分块预填充。

#### Mamba 模型 (Mamba Models)

支持使用选择性状态空间机制而非标准 Transformer 注意力的模型。支持使用 Mamba-2 和 Mamba-1 层的模型（例如 `Mamba2ForCausalLM`、`MambaForCausalLM`、`FalconMambaForCausalLM`）。还支持将 Mamba-2 和 Mamba-1 层与标准注意力层结合的混合模型（例如 `BambaForCausalLM`、`Zamba2ForCausalLM`、`NemotronHForCausalLM`、`FalconH1ForCausalLM` 和 `GraniteMoeHybridForCausalLM`、`JambaForCausalLM`、`Plamo2ForCausalLM`）。还支持机制不同于 Mamba 的混合模型（例如 `MiniMaxText01ForCausalLM`、`MiniMaxM1ForCausalLM`、`Lfm2ForCausalLM`）。请注意，上述模型目前均不支持前缀缓存。

#### 编码器-解码器模型 (Encoder-Decoder Models)

支持 Whisper。其他需要在独立编码器和解码器之间进行交叉注意力的模型（例如 `BartForConditionalGeneration`、`MllamaForConditionalGeneration`）不再受支持。

### 功能

| 功能 | 状态 |
|---------------------------------------------|-----------------------------------------------------------------------------------|
| **Prefix Caching** | <nobr>🟢 可用</nobr> |
| **Chunked Prefill** | <nobr>🟢 可用</nobr> |
| **LoRA** | <nobr>🟢 可用</nobr> |
| **Logprobs Calculation** | <nobr>🟢 可用</nobr> |
| **FP8 KV Cache** | <nobr>🟢 可用</nobr> |
| **Spec Decode** | <nobr>🟢 可用</nobr> |
| **Prompt Logprobs with Prefix Caching** | <nobr>🟢 可用</nobr> |
| **Structured Output Alternative Backends** | <nobr>🟢 可用</nobr> |
| **Concurrent Partial Prefills** | <nobr>🟡 [进行中](https://github.com/vllm-project/vllm/issues/14003)</nobr> |
| **best_of** | <nobr>🔴 [已移除](https://github.com/vllm-project/vllm/issues/13361)</nobr> |
| **Per-Request Logits Processors** | <nobr>🔴 [已移除](https://github.com/vllm-project/vllm/pull/13360)</nobr> |
| **GPU <> CPU KV Cache Swapping** | <nobr>🔴 已移除</nobr> |
| **Request-level Structured Output Backend** | <nobr>🔴 已移除</nobr> |

!!! note
vLLM V1 的统一调度器通过使用简单的字典（例如 `{request_id: num_tokens}`）以相同的方式处理 prompt token 和 output token，为每个请求动态分配固定的 token 预算，从而支持 chunked prefills、prefix caching 和 speculative decoding 等功能，而无需在 prefill 和 decode 阶段之间进行严格区分。

#### 已移除的功能

作为 vLLM V1 重大架构重构的一部分，一些旧版功能已被移除。

##### 采样功能

- **best_of**：由于使用有限，此功能已被移除。详情请参见 [RFC #13361](https://github.com/vllm-project/vllm/issues/13361)。
- **Per-Request Logits Processors**：在 V0 中，用户可以传递自定义处理函数以在每个请求的基础上调整 logits。在 vLLM V1 中，此功能已被移除。取而代之的是，我们现在支持在启动时设置的**全局 logits processors**，参见 [RFC #17799](https://github.com/vllm-project/vllm/issues/17799)。

##### KV Cache 功能

- **GPU <> CPU KV Cache Swapping**：随着新的简化核心架构的引入，vLLM V1 不再需要 KV cache swapping 来处理请求抢占。

##### 结构化输出功能

- **Request-level Structured Output Backend**：已移除；现在支持带有回退机制的替代后端（outlines、guidance）。