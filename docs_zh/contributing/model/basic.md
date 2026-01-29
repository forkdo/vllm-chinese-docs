# 基础模型

本指南将引导您完成实现一个基础 vLLM 模型的步骤。

## 1. 引入模型代码

首先，从源代码仓库克隆 PyTorch 模型代码。
例如，vLLM 的 [OPT 模型](../../../vllm/model_executor/models/opt.py) 就是基于
HuggingFace 的 [modeling_opt.py](https://github.com/huggingface/transformers/blob/main/src/transformers/models/opt/modeling_opt.py) 文件改编而来的。

!!! warning
    请务必审阅并遵守原始代码的版权和许可条款！

## 2. 使您的代码与 vLLM 兼容

为确保与 vLLM 兼容，您的模型必须满足以下要求：

### 初始化代码

模型中所有 vLLM 模块的构造函数都必须包含一个 `prefix` 参数。此 `prefix` 通常是模型状态字典中模块的完整名称，对于以下内容至关重要：

- 运行时支持：vLLM 的注意力操作符通过其完整名称在模型状态中注册。每个注意力操作符必须具有唯一的前缀作为其层名，以避免冲突。
- 非均匀量化支持：量化检查点可以选择性地量化某些层，而将其他层保持在全精度。通过初始化时提供 `prefix`，vLLM 可以将当前层的 `prefix` 与量化配置匹配，以确定该层是否应以量化模式初始化。

初始化代码应如下所示：

??? code

    ```python
    from torch import nn
    from vllm.config import VllmConfig
    from vllm.model_executor.layers.attention import Attention

    class MyAttention(nn.Module):
        def __init__(self, vllm_config: VllmConfig, prefix: str):
            super().__init__()
            self.attn = Attention(prefix=f"{prefix}.attn")

    class MyDecoderLayer(nn.Module):
        def __init__(self, vllm_config: VllmConfig, prefix: str):
            super().__init__()
            self.self_attn = MyAttention(prefix=f"{prefix}.self_attn")

    class MyModel(nn.Module):
        def __init__(self, vllm_config: VllmConfig, prefix: str):
            super().__init__()
            self.layers = nn.ModuleList(
                [MyDecoderLayer(vllm_config, prefix=f"{prefix}.layers.{i}") for i in range(vllm_config.model_config.hf_config.num_hidden_layers)]
            )

    class MyModelForCausalLM(nn.Module):
        def __init__(self, vllm_config: VllmConfig, prefix: str = ""):
            super().__init__()
            self.model = MyModel(vllm_config, prefix=f"{prefix}.model")
    ```

### 计算代码

- 在 `MyModel` 模块内添加一个 `embed_input_ids` 方法，给定 `input_ids` 返回文本嵌入。这等同于直接调用文本嵌入层，但提供统一接口，以防 `MyModel` 被用于复合多模态模型。

```python
class MyModel(nn.Module):
        ...

    def embed_input_ids(self, input_ids: torch.Tensor) -> torch.Tensor:
        ... 
```

- 重写您模型的 [forward][torch.nn.Module.forward] 方法，删除任何不必要的代码，例如特定于训练的代码。修改输入参数，将 `input_ids` 和 `positions` 视为具有单一批大小维度的扁平张量，不包含最大序列长度维度。

```python
def forward(
    self,
    input_ids: torch.Tensor | None,
    positions: torch.Tensor,
    intermediate_tensors: IntermediateTensors | None = None,
    inputs_embeds: torch.Tensor | None = None,
) -> torch.Tensor:
    ...
```

!!! note
    目前，vLLM 支持基本的多头注意力机制及其使用旋转位置嵌入的变体。
    如果您的模型使用不同的注意力机制，您需要在 vLLM 中实现新的注意力层。

请参考我们的 [Llama 实现](../../../vllm/model_executor/models/llama.py)。vLLM 已经支持大量模型。建议找到一个与您模型相似的模型，并根据您模型的架构进行适配。请查看 [vllm/model_executor/models](../../../vllm/model_executor/models) 以获取更多示例。

## 3. （可选）实现张量并行和量化支持

如果您的模型太大，无法装入单个 GPU，您可以使用张量并行来管理它。
为此，将您的模型的线性层和嵌入层替换为其张量并行版本。
对于嵌入层，您可以简单地将 [torch.nn.Embedding][] 替换为 `VocabParallelEmbedding`。对于输出语言模型头部，您可以使用 `ParallelLMHead`。
对于线性层，我们提供以下选项来并行化它们：

- `ReplicatedLinear`：在多个 GPU 上复制输入和权重。不节省内存。
- `RowParallelLinear`：输入张量沿着隐藏维度进行分区。权重矩阵沿着行（输入维度）进行分区。矩阵乘法后执行 *all-reduce* 操作以减少结果。通常用于第二个 FFN 层和注意力层的输出线性变换。
- `ColumnParallelLinear`：输入张量被复制。权重矩阵沿着列（输出维度）进行分区。结果沿着列维度进行分区。通常用于第一个 FFN 层和原始 Transformer 中注意力层的分离 QKV 变换。
- `MergedColumnParallelLinear`：合并多个 `ColumnParallelLinear` 操作符的列并行线性层。通常用于具有加权激活函数的第一个 FFN 层（例如 SiLU）。此类处理多个权重矩阵的分片权重加载逻辑。
- `QKVParallelLinear`：用于多头和组查询注意力机制中查询、键和值投影的并行线性层。当键/值头数量小于世界大小时，此类正确地复制键/值头。此类处理权重矩阵的权重加载和复制。

请注意，上述所有线性层都以 `linear_method` 作为输入。vLLM 会根据不同的量化方案设置此参数以支持权重量化。

## 4. 实现权重加载逻辑

现在您需要在 `*ForCausalLM` 类中实现 `load_weights` 方法。
该方法应从 HuggingFace 的检查点文件加载权重，并将其分配给您模型中的相应层。具体而言，对于 `MergedColumnParallelLinear` 和 `QKVParallelLinear` 层，如果原始模型具有分离的权重矩阵，您需要分别加载不同的部分。

## 5. 注册您的模型

请参阅 [此页面](registration.md) 了解如何注册您的新模型以供 vLLM 使用的说明。

## 常见问题

### 如何支持具有交错滑动窗口的模型？

要支持具有交错滑动窗口的模型，我们需要注意以下细节：

- 确保模型的 `config.json` 包含 `layer_types`。
- 在建模代码中，解析每一层的正确滑动窗口值，并将其传递给注意力层的 `per_layer_sliding_window` 参数。请参考 [此行](https://github.com/vllm-project/vllm/blob/996357e4808ca5eab97d4c97c7d25b3073f46aab/vllm/model_executor/models/llama.py#L171)。

通过这两个步骤，交错滑动窗口应该能够与模型正常工作。

### 如何支持使用 Mamba 的模型？

我们考虑以下三种不同情况：

1. 使用 Mamba 层（Mamba-1 或 Mamba-2）但不使用注意力层的模型。
2. 将 Mamba 层（Mamba-1 或 Mamba-2）与注意力层结合使用的模型。
3. 将 Mamba 类机制（例如线性注意力、ShortConv）与注意力层结合使用的模型。

对于情况 (1)，我们建议参考 [`MambaForCausalLM`](../../../vllm/model_executor/models/mamba.py)（用于 Mamba-1）或 [`Mamba2ForCausalLM`](../../../vllm/model_executor/models/mamba2.py)（用于 Mamba-2）的实现作为参考。
该模型应继承协议 `IsAttentionFree`，并实现类方法 `get_mamba_state_dtype_from_config` 和 `get_mamba_state_shape_from_config`，以从配置中计算状态形状和数据类型。
对于 mamba 层本身，请使用 [`MambaMixer`](../../../vllm/model_executor/layers/mamba/mamba_mixer.py)（用于 Mamba-1）或 [`MambaMixer2`](../../../vllm/model_executor/layers/mamba/mamba_mixer2.py)（用于 Mamba-2）类。
该模型还应添加到 [vllm/model_executor/models/config.py](../../../vllm/model_executor/models/config.py) 中的 `MODELS_CONFIG_MAP` 字典中，以确保运行时默认值得到优化。

对于情况 (2)，我们建议参考 [`JambaForCausalLM`](../../../vllm/model_executor/models/jamba.py)（用于 Mamba-1 与注意力结合使用模型的示例）或 [`BambaForCausalLM`](../../../vllm/model_executor/models/bamba.py)（用于 Mamba-2 与注意力结合使用模型的示例）的实现。
这些模型应遵循与情况 (1) 相同的说明，但应继承协议 `IsHybrid`（而非 `IsAttentionFree`），并且无需将其添加到 `MODELS_CONFIG_MAP` 中（它们的运行时默认值将从协议推断得出）。

对于情况 (3)，我们建议参考 [`MiniMaxText01ForCausalLM`](../../../vllm/model_executor/models/minimax_text_01.py) 或 [`Lfm2ForCausalLM`](../../../vllm/model_executor/models/lfm2.py) 的实现，这些模型分别使用自定义的“mamba-like”层 `MiniMaxText01LinearAttention` 和 `ShortConv`。
实现这些模型时，请遵循与情况 (2) 相同的指南。
我们使用“mamba-like”来指代那些以原地更新其状态（而不是像注意力的 KV 缓存那样进行追加）的层。
在实现新的自定义 mamba-like 层时，应继承自 `MambaBase` 并实现方法 `get_state_dtype` 和 `get_state_shape`，以在运行时计算数据类型和状态形状，以及 `mamba_type` 和 `get_attn_backend`。
还需要实现一个“注意力元数据”类，用于处理所有层之间共享的元数据。
请参见 [`LinearAttentionMetadata`](../../../vllm/v1/attention/backends/linear_attn.py) 或 [`ShortConvAttentionMetadata`](../../../vllm/v1/attention/backends/short_conv_attn.py) 以了解此类的示例。
还值得注意的是，当我们添加新的 mamba 后端时，应更新 [`registry.py`](../../../vllm/v1/attention/backends/registry.py) 中的 `MAMBA_TYPE_TO_BACKEND_MAP` 和 `MambaAttentionBackendEnum`。
最后，如果希望支持 torch 编译和 CUDA 图，需要将对 mamba-like 层的调用包装在自定义操作中并注册。
请参见 [vllm/model_executor/models/minimax_text_01.py](../../../vllm/model_executor/models/minimax_text_01.py) 或 [vllm/model_executor/layers/mamba/short_conv.py](../../../vllm/model_executor/layers/mamba/short_conv.py) 中的 `direct_register_custom_op` 调用示例。
新的自定义操作随后应添加到 [vllm/config/compilation.py](../../../vllm/config/compilation.py) 中的列表 `_attention_ops` 中，以确保分段 CUDA 图能按预期工作。