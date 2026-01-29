# 功能

## 兼容性矩阵

下表展示了互斥功能以及在部分硬件上的支持情况。

表中使用的符号含义如下：

- ✅ = 完全兼容
- 🟠 = 部分兼容
- ❌ = 不兼容
- ❔ = 未知或待定

!!! note
    点击 ❌ 或 🟠 查看不支持的功能/硬件组合的跟踪问题链接。

### 功能 x 功能

<style>
td:not(:first-child) {
  text-align: center !important;
}
td {
  padding: 0.5rem !important;
  white-space: nowrap;
}

th {
  padding: 0.5rem !important;
  min-width: 0 !important;
}

th:not(:first-child) {
  writing-mode: vertical-lr;
  transform: rotate(180deg)
}
</style>

| 功能 | [CP](../configuration/optimization.md#chunked-prefill) | [APC](automatic_prefix_caching.md) | [LoRA](lora.md) | [SD](spec_decode.md) | CUDA graph | [pooling](../models/pooling_models.md) | <abbr title="Encoder-Decoder Models">enc-dec</abbr> | <abbr title="Logprobs">logP</abbr> | <abbr title="Prompt Logprobs">prmpt logP</abbr> | <abbr title="Async Output Processing">async output</abbr> | multi-step | <abbr title="Multimodal Inputs">mm</abbr> | best-of | beam-search | [prompt-embeds](prompt_embeds.md) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [CP](../configuration/optimization.md#chunked-prefill) | ✅ | | | | | | | | | | | | | | |
| [APC](automatic_prefix_caching.md) | ✅ | ✅ | | | | | | | | | | | | | |
| [LoRA](lora.md) | ✅ | ✅ | ✅ | | | | | | | | | | | | |
| [SD](spec_decode.md) | ✅ | ✅ | ❌ | ✅ | | | | | | | | | | | |
| CUDA graph | ✅ | ✅ | ✅ | ✅ | ✅ | | | | | | | | | | |
| [pooling](../models/pooling_models.md) | 🟠\* | 🟠\* | ✅ | ❌ | ✅ | ✅ | | | | | | | | | |
| <abbr title="Encoder-Decoder Models">enc-dec</abbr> | ❌ | [❌](https://github.com/vllm-project/vllm/issues/7366) | ❌ | [❌](https://github.com/vllm-project/vllm/issues/7366) | ✅ | ✅ | ✅ | | | | | | | | |
| <abbr title="Logprobs">logP</abbr> | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | | | | | | | |
| <abbr title="Prompt Logprobs">prmpt logP</abbr> | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | | | | | | |
| <abbr title="Async Output Processing">async output</abbr> | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | | | | | |
| multi-step | ❌ | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | | | | |
| [mm](multimodal_inputs.md) | ✅ | ✅ | [🟠](https://github.com/vllm-project/vllm/pull/4194)<sup>^</sup> | ❔ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❔ | ✅ | | | |
| best-of | ✅ | ✅ | ✅ | [❌](https://github.com/vllm-project/vllm/issues/6137) | ✅ | ❌ | ✅ | ✅ | ✅ | ❔ | [❌](https://github.com/vllm-project/vllm/issues/7968) | ✅ | ✅ | | |
| beam-search | ✅ | ✅ | ✅ | [❌](https://github.com/vllm-project/vllm/issues/6137) | ✅ | ❌ | ✅ | ✅ | ✅ | ❔ | [❌](https://github.com/vllm-project/vllm/issues/7968) | ❔ | ✅ | ✅ | |
| [prompt-embeds](prompt_embeds.md) | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ✅ | ❌ | ❔ | ❔ | ❌ | ❔ | ❔ | ✅ |

\* 分块预填充和前缀缓存仅适用于最后一个token或全token池化与因果注意机制。  
<sup>^</sup> LoRA 仅适用于多模态模型的语言主干。

### 功能 x 硬件

| 功能                                                   | Volta               | Turing    | Ampere    | Ada    | Hopper     | CPU                | AMD    | Intel GPU |
|-----------------------------------------------------------|---------------------|-----------|-----------|--------|------------|--------------------|--------| ------------|
| [CP](../configuration/optimization.md#chunked-prefill)                                     | [❌](https://github.com/vllm-project/vllm/issues/2729) | ✅        | ✅        | ✅     | ✅        | ✅                  | ✅     | ✅        |
| [APC](automatic_prefix_caching.md)                        | [❌](https://github.com/vllm-project/vllm/issues/3687) | ✅        | ✅        | ✅     | ✅        | ✅                  | ✅     | ✅        |
| [LoRA](lora.md)                                           | ✅                  | ✅        | ✅        | ✅     | ✅        | ✅                  | ✅     | ✅        |
| [SD](spec_decode.md)                                      | ✅                  | ✅        | ✅        | ✅     | ✅        | ❌                  | ✅     | ✅        |
| CUDA graph                                                | ✅                  | ✅        | ✅        | ✅     | ✅        | ❌                  | ✅     | [❌](https://github.com/vllm-project/vllm/issues/26970)        |
| [pooling](../models/pooling_models.md)                    | ✅                  | ✅        | ✅        | ✅     | ✅        | ✅                  | ✅     | ✅        |
| <abbr title="Encoder-Decoder Models">enc-dec</abbr>       | ✅                  | ✅        | ✅        | ✅     | ✅        | ✅                  | ❌     | ✅        |
| [mm](multimodal_inputs.md)                                | ✅                  | ✅        | ✅        | ✅     | ✅        | ✅                  | ✅     | ✅        |
| [prompt-embeds](prompt_embeds.md)                         | ✅                  | ✅        | ✅        | ✅     | ✅        | ✅                  | ❔     | ✅        |
| <abbr title="Logprobs">logP</abbr>                        | ✅                  | ✅        | ✅        | ✅     | ✅        | ✅                  | ✅     | ✅        |
| <abbr title="Prompt Logprobs">prmpt logP</abbr>           | ✅                  | ✅        | ✅        | ✅     | ✅        | ✅                  | ✅     | ✅        |
| <abbr title="Async Output Processing">async output</abbr> | ✅                  | ✅        | ✅        | ✅     | ✅        | ❌                  | ❌     | ✅        |
| multi-step                                                | ✅                  | ✅        | ✅        | ✅     | ✅        | [❌](https://github.com/vllm-project/vllm/issues/8477) | ✅     | ✅        |
| best-of                                                   | ✅                  | ✅        | ✅        | ✅     | ✅        | ✅                  | ✅     | ✅        |
| beam-search                                               | ✅                  | ✅        | ✅        | ✅     | ✅        | ✅                  | ✅     | ✅        |

!!! note
    如需了解 Google TPU 上的功能支持信息，请参阅 [TPU-Inference 推荐模型和功能](https://docs.vllm.ai/projects/tpu/en/latest/recommended_models_features/) 文档。