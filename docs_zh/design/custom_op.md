# CustomOp

`CustomOp` 是一个抽象类，用于将各种操作的前向方法调度到合适的后端。它还提供了 vLLM 和 OOT（Out-Of-Tree）插件注册自定义操作的机制。

本文档将介绍 CustomOp 在 vLLM 中的工作原理以及如何实现一个新的 `CustomOp`。

## CustomOp 在 vLLM 中的工作原理

`CustomOp` 在其类中管理两个字典，分别存储 vLLM 和 OOT 插件的所有自定义操作（即操作类，以注册名称作为索引）。

我们可以使用 `@CustomOp.register("op_name")` 将一个操作类注册到 `CustomOp` 系统中。注册后，`op_name` 及其对应的类会被添加到 `op_registry` 字典中。此外，我们也可以通过 `@CustomOp.register_oot("op_name")` 注册一个 OOT 操作。稍后我们会详细介绍这一机制。

当调用一个 `CustomOp` 时（即调用其 `forward()` 方法），如果该操作已启用（即通过 `--compilation_config.custom_ops '["+op_name"]'` 启用），它会根据 `current_platform` 自动将前向方法调度到合适的后端。否则（即未启用），它只会调用 `forward_native()` 方法，使用 PyTorch 原生的实现。

- **CPU 平台：** 调度到 `forward_cpu()`。
- **CUDA 平台：** 调度到 `forward_cuda()`。
- **ROCm 平台：** 调度到 `forward_hip()`。如果未实现 `forward_hip()`，则回退到使用 `forward_cuda()`。
- **XPU 平台：** 调度到 `forward_xpu()`。
- **TPU 平台：** 调度到 `forward_tpu()`。
- **OOT 平台：** 调度到 `forward_oot()`。此方法仅在 OOT 平台上调用。
- **默认：** 作为所有平台的最终回退方案，调度到 `forward_native()`。

!!! note
    注意，由于类继承的存在，调度逻辑可能不是绝对的。派生类可能会覆盖该行为。

此外，vLLM 根据 `compilation_config.custom_ops` 决定是否启用或禁用某个 `CustomOp`。具体来说，如果某个 `CustomOp` 未在 `compilation_config.custom_ops` 中注册（即使用默认配置），那么当 `compilation_config.custom_ops` 包含 `all` 时，该操作会被启用；如果包含 `none`，则会被禁用。

!!! note
    注意，`all` 和 `none` 不能同时存在于 `compilation_config.custom_ops` 中。

默认情况下，如果 `compilation_config.backend == "inductor"` 且 `compilation_config.mode != CompilationMode.NONE`，则会在 `compilation_config.custom_ops` 中追加一个 `none`，否则会追加一个 `all`。换句话说，这意味着在某些平台（即那些使用 `inductor` 作为 `torch.compile` 默认后端的平台）上，当以 torch compile 模式运行时，`CustomOp` 会被禁用。在这种情况下，Inductor 会为这些被禁用的自定义操作生成（融合的）Triton 内核。

!!! note
    对于多模态模型，vLLM 强制启用了一些自定义操作，以便在 ViT 部分使用针对设备深度优化的内核，从而获得更好的性能，例如 `MMEncoderAttention` 和 `ApplyRotaryEmb`。我们也可以向 `CustomOp` 的 `__init__()` 方法传递 `enforce_enable=True` 参数，以在对象级别强制启用该操作。

    注意，在我们为多模态部分添加独立的 `compilation_config` 后，此 `enforce_enable` 机制将被移除。

## 如何为 CustomOp 自定义配置

vLLM 还为用户提供了细粒度的控制，允许用户手动指定启用或禁用哪些自定义操作，方法是在启动服务器时传递 `--compilation_config.custom_ops '["..."]'`。

例如：

- 使用 `--compilation_config.custom_ops '["all"]'` 启用所有自定义操作。
- 使用 `--compilation_config.custom_ops '["none"]'` 禁用所有自定义操作。
- 使用 `--compilation_config.custom_ops '["all,-op1"]'` 启用除 op1 以外的所有自定义操作（即以 `-` 为前缀表示“禁用”）。
- 使用 `--compilation_config.custom_ops '["none,+op1,+op2"]'` 仅启用 op1 和 op2（即以 `+` 为前缀表示“启用”）。

## vLLM 中支持的 CustomOp 类型

**1. Attention:**

```python
--8<-- "vllm/model_executor/layers/attention/mm_encoder_attention.py:mm_encoder_attn"

--8<-- "vllm/model_executor/layers/mla.py:multi_head_latent_attention"
```

**2. Activation:**

```python
--8<-- "vllm/model_executor/layers/activation.py:silu_and_mul"

--8<-- "vllm/model_executor/layers/activation.py:mul_and_silu"

--8<-- "vllm/model_executor/layers/activation.py:gelu_new"

--8<-- "vllm/model_executor/layers/activation.py:gelu_fast"

--8<-- "vllm/model_executor/layers/activation.py:quick_gelu"

--8<-- "vllm/model_executor/layers/activation.py:gelu_and_mul"

--8<-- "vllm/model_executor/layers/activation.py:gelu_and_mul_sparse"

--8<-- "vllm/model_executor/layers/activation.py:relu2"

--8<-- "vllm/model_executor/layers/activation.py:xielu"

--8<-- "vllm/model_executor/layers/activation.py:swigluoai_and_mul"

--8<-- "vllm/model_executor/layers/activation.py:fatrelu_and_mul"
```

**3. MM-Conv:**

```python
--8<-- "vllm/model_executor/layers/conv.py:conv2d"

--8<-- "vllm/model_executor/layers/conv.py:conv3d"
```

**4. Embedding:**

```python
--8<-- "vllm/model_executor/layers/vocab_parallel_embedding.py:vocab_parallel_embedding"

--8<-- "vllm/model_executor/layers/vocab_parallel_embedding.py:parallel_lm_head"
```

**5. Linear:**

```python
--8<-- "vllm/model_executor/layers/linear.py:row_parallel_linear"

--8<-- "vllm/model_executor/layers/linear.py:column_parallel_linear"

--8<-- "vllm/model_executor/layers/linear.py:replicated_linear"
```

**6. Logits Processor:**

```python
--8<-- "vllm/model_executor/layers/logits_processor.py:logits_processor"
```

**7. Mamba:**

```python
--8<-- "vllm/model_executor/layers/mamba/mamba_mixer.py:mamba_mixer"

--8<-- "vllm/model_executor/layers/mamba/mamba_mixer2.py:mamba_mixer2"

--8<-- "vllm/model_executor/layers/mamba/mamba_mixer2.py:mixer2_gated_rms_norm"

--8<-- "vllm/model_executor/models/plamo2.py:plamo2_mamba_mixer"

--8<-- "vllm/model_executor/layers/mamba/short_conv.py:short_conv"
```

**8. MoE:**

```python
--8<-- "vllm/model_executor/layers/fused_moe/layer.py:fused_moe"

--8<-- "vllm/model_executor/layers/fused_moe/fused_moe_modular_method.py:modular_fused_moe"

--8<-- "vllm/model_executor/layers/fused_moe/unquantized_fused_moe_method.py:unquantized_fused_moe"

--8<-- "vllm/model_executor/models/transformers/moe.py:transformers_fused_moe"

--8<-- "vllm/model_executor/layers/fused_moe/fused_moe.py:grouped_topk"
```

**9. Norm:**

```python
--8<-- "vllm/model_executor/layers/layernorm.py:rms_norm"

--8<-- "vllm/model_executor/layers/layernorm.py:rms_norm_gated"

--8<-- "vllm/model_executor/layers/layernorm.py:gemma_rms_norm"
```

**10. Quantization:**

```python
--8<-- "vllm/model_executor/layers/quantization/input_quant_fp8.py:quant_fp8"
```

**11. Rope:**

```python
--8<-- "vllm/model_executor/layers/rotary_embedding/base.py:rotary_embedding"

--8<-- "vllm/model_executor/layers/rotary_embedding/dual_chunk_rope.py:dual_chunk_rotary_embedding"

--8<-- "vllm/model_executor/layers/rotary_embedding/common.py:apply_rotary_emb"
```

## 实现新 CustomOp 的指南

### 在 vLLM 中实现新的 CustomOp

本部分是一个教程，介绍如何在 vLLM 中实现一个新的 `CustomOp`。

步骤：

1. 实现一个新的操作类，继承自 `CustomOp` 基类。
2. 在该操作类上添加 `@CustomOp.register("op_name")` 装饰器，将其注册到 `CustomOp` 系统中。
3. 根据需要实现不同的 `forward_xxx()` 方法。

以 `MMEncoderAttention` 为例：

??? code

    ```python
    @CustomOp.register("mm_encoder_attn")
    class MMEncoderAttention(CustomOp):

        def __init__(
            self,
            num_heads: int,
            head_size: int,
            scale: float | None = None,
            num_kv_heads: int | None = None,
            prefix: str = "",
            multimodal_config: MultiModalConfig | None = None,
        ) -> None:
            super().__init__()
            # Init...

def forward_native(
            self,
            query: torch.Tensor,
            key: torch.Tensor,
            value: torch.Tensor,
            cu_seqlens: torch.Tensor | None = None,
            max_seqlen: torch.Tensor | None = None,  # Only used for Flash Attention
        ) -> torch.Tensor:
            # Call TORCH_SDPA implementation...

        def forward_cuda(
            self,
            query: torch.Tensor,
            key: torch.Tensor,
            value: torch.Tensor,
            cu_seqlens: torch.Tensor | None = None,
            max_seqlen: torch.Tensor | None = None,  # Only used for Flash Attention
        ) -> torch.Tensor:
            # Call FA or TORCH_SDPA implementation...

        def forward_cpu(
            self,
            query: torch.Tensor,
            key: torch.Tensor,
            value: torch.Tensor,
            cu_seqlens: torch.Tensor | None = None,
            max_seqlen: torch.Tensor | None = None,  # Only used for Flash Attention
        ) -> torch.Tensor:
            # Call TORCH_SDPA implementation...

        def forward_xpu(
            self,
            query: torch.Tensor,
            key: torch.Tensor,
            value: torch.Tensor,
            cu_seqlens: torch.Tensor | None = None,
            max_seqlen: torch.Tensor | None = None,  # Only used for Flash Attention
        ) -> torch.Tensor:
            # Call FA implementation...

        def forward_tpu(
            self,
            query: torch.Tensor,
            key: torch.Tensor,
            value: torch.Tensor,
            cu_seqlens: torch.Tensor | None = None,
            max_seqlen: torch.Tensor | None = None,  # Only used for Flash Attention
        ) -> torch.Tensor:
            # Call PALLAS implementation...
    ```

### 在 OOT 设备插件中注册新的 CustomOp

目前，得益于 [vLLM 的硬件插件机制](./plugin_system.md)，各种 OOT 设备插件不断涌现，使得 vLLM 能够无缝运行在不同的硬件上。您还可以在 [Introducing vLLM Hardware Plugin, Best Practice from Ascend NPU](https://blog.vllm.ai/2025/05/12/hardware-plugin.html) 中找到有关此机制的更多详细信息。

- **官方设备插件：** [vllm-ascend](https://github.com/vllm-project/vllm-ascend)（适用于华为昇腾 NPU）、[vllm-spyre](https://github.com/vllm-project/vllm-spyre)（适用于 Spyre）、[vllm-gaudi](https://github.com/vllm-project/vllm-gaudi)（适用于英特尔 Gaudi）、[vllm-neuron](https://github.com/vllm-project/vllm-neuron)（适用于 AWS Neuron）、[vllm-meta](https://github.com/vllm-project/vllm-metal)（适用于 Apple Silicon）等。
- **非官方设备插件：** [vllm-metax](https://github.com/MetaX-MACA/vLLM-metax)（适用于 MetaX GPU）、[vllm-kunlun](https://github.com/baidu/vLLM-Kunlun)（适用于百度昆仑 XPU）等。

在这种情况下，`CustomOp` 可以让这些硬件制造商在运行时通过注册一个 OOT `CustomOp` 并实现 `forward_oot()` 方法，无缝地用其针对特定设备深度优化的内核替换 vLLM 的操作。

现在，本部分将向您展示如何为设备插件注册一个 OOT `CustomOp`。

以 `MMEncoderAttention` 为例：

1. 实现一个 `CustomMMEncoderAttention` 类，该类继承自 `MMEncoderAttention` 并实现其 `forward_oot()` 方法。
2. 将您的 `CustomMMEncoderAttention` 注册到 vLLM 中以替换 `MMEncoderAttention`。

??? code

    ```python
    from vllm.model_executor.layers.attention import MMEncoderAttention
    from vllm.model_executor.custom_op import CustomOp


    @CustomOp.register_oot("MMEncoderAttention")
    class CustomMMEncoderAttention(MMEncoderAttention):

        def __init__(...):
            super().__init__(...)
        
        def forward_oot(...):
            # Call optimized device-specific kernels.
            ...
    ```

在这种情况下，一个新的条目 `{"MMEncoderAttention": CustomMMEncoderAttention}` 将被添加到 `op_registry_oot` 中。当初始化一个 `MMEncoderAttention` 操作对象时，如果类名（即 `MMEncoderAttention`）包含在 `op_registry_oot` 的键中，vLLM 将用我们注册的类（即 `CustomMMEncoderAttention`）替换它并实例化它。

之后，当调用此 `MMEncoderAttention` 操作时，如果启用了您的 `forward_oot()`，则会调用它。因此，您无需直接修改 vLLM 即可在硬件上获得预期的性能。

此外，您还可以将所有 `CustomOp` 注册在一个地方以便更好地管理。

??? code

    ```python
    from vllm.model_executor.custom_op import CustomOp


    REGISTERED_CUSTOM_OPS = {
        "CustomOP1": YourCustomOp1,
        "CustomOP2": YourCustomOp2,
        "CustomOP3": YourCustomOp3,
    }

    for op_name, op_cls in REGISTERED_CUSTOM_OPS.items():
        CustomOp.register_oot(_decorated_op_cls=op_cls, name=op_name)
    ```