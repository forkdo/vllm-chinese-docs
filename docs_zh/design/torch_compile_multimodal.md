# 使用 torch.compile 编译多模态编码器

`torch.compile` 现已可应用于 vLLM 中的多模态编码器和各种 nn 模块，包括 LLaMA 4、Qwen-VL 等视觉语言模型以及类似的基于编码器的架构。

本文档介绍了 vLLM 中多模态编码器的 `torch.compile` 集成的基本原理，以及如何将装饰器应用于新模型以提升性能。

!!! note
    有关 vLLM 中 `torch.compile` 集成的一般信息，请参阅 [torch.compile 设计文档](./torch_compile.md)。

## 概述

我们最近启用了 `@support_torch_compile` 装饰器，使其可在同一模型类型的多个 nn 模块组件上工作；这使得我们可以为多模态编码器开启编译功能，从而为整个堆栈的更多组件带来性能提升。

当应用于 [`Qwen2_5_vl`](https://github.com/vllm-project/vllm/pull/23207) 的视觉模块时，我们观察到端到端性能提升了约 4.5%，但编译时间略有增加。

此功能默认关闭，但可通过在编译配置中设置 `compile_mm_encoder: true` 来启用（前提是模型已使用 `@support_torch_compile` 装饰器）。

## 多模态组件的编译工作原理

### 启用 API

要编译多模态组件（如编码器），我们遵循与 LLM 文本主干相同的机制，但需要一些额外的脚手架：

1. `@support_torch_compile` 装饰器应包含 `enable_if=should_torch_compile_mm_vit`。这将通过我们的 `compile_mm_encoder` 配置来控制编译的开启。

2. 在 nn.Module 实例化时应使用 `with set_model_tag("<component_name>", is_encoder=True)` 上下文管理器。由于 torch.compile 依赖缓存工件来减少启动时间，我们必须正确地将 `<component_name>` 信息传播到缓存中，以避免与 LLM 文本主干或其他相同工件实例（如视觉模块的情况）发生冲突。`is_encoder=True` 对于编码器组件也是必需的（参见编译范围集成）。

3. 在 nn.Module 的前向调用时应使用 `with set_forward_context` 上下文管理器。这将正确转发 vllm_config，这是 torch.compile 集成所必需的。

### CompilationConfig

除了 `compile_mm_encoder: true` 外，多模态编码器将继承与文本 LLM 相同的编译配置。未来我们可能会扩展此配置以支持更多选项。

## 将 torch.compile 应用于新的多模态模型/组件

要将 `support_torch_compile` 应用于新的通用 nn.Module，建议遵循 [`debug_vllm_compile`](./debug_vllm_compile.md) 中的相同步骤；这包括：

1. 先在较小的模块（如基本 MLP 层）上应用 `support_torch_compile`，然后逐步提升到更通用的模块，直到达到良好的性能权衡。

2. 利用 [`tlparse`](https://github.com/meta-pytorch/tlparse) 来识别并消除重编译和图中断的根源。

3. 使用 `dynamic_arg_dims` 和适当的 `dynamic_shapes_config` 来处理动态性。

### 常见陷阱

## VllmBackend 功能支持

### 编译范围

torch.compile 集成将尝试依赖 max_batch_size 来推断动态形状的编译范围；然而，对于编码器中使用的模块，由于编码器可能看到的输入形状范围未指定，因此可能难以推断此形状。因此，我们依赖 `set_model_tag` 中的 `is_encoder=True` 来提醒 torch.compile 此范围无法推断，并默认使用范围 (1, MAX_INT)。

!!! note
    未来我们可能会寻求收紧此范围以获得更好的性能。

### Cudagraphs

我们尚未探索将 CUDAGraph 集成用于多模态编码器的编译；当前行为未指定。

## 故障排除

### 视觉编码器中的图中断

某些视觉编码器操作可能导致图中断。要识别它们：

```bash
TORCH_LOGS="+dynamo" vllm serve <MODEL>
```

多模态模型中图中断的常见原因：

- **动态图像大小**：使用 `dynamic_shapes_config` 处理可变分辨率
- **不可追踪的操作**：某些操作（如 to_list）可能不受 Dynamo 支持
- **条件处理**：基于图像属性的数据相关分支

### 编译错误

如果多模态模型编译失败：

1. **禁用并测试**：首先验证模型在无编译情况下是否正常工作：
   ```bash
   VLLM_TORCH_COMPILE_LEVEL=0 vllm serve <model> --compilation-config='{"compile_mm_encoder":"false"}'
   ```

2. **检查日志**：启用调试日志以查看编译详情：
   ```bash
   VLLM_LOGGING_LEVEL=DEBUG vllm serve <model> --compilation-config='{"compile_mm_encoder":"true"}'
   ```

3. **报告问题**：如果发现 bug，请[在 GitHub 上提交问题](https://github.com/vllm-project/vllm/issues/new/choose)

## 另请参阅

- [torch.compile 集成](./torch_compile.md) - 核心设计文档
- [调试 torch.compile](./debug_vllm_compile.md) - 详细调试指南
- [多模态输入](../features/multimodal_inputs.md) - 如何传递多模态数据
- [解耦编码器](../features/disagg_encoder.md) - 扩展视觉编码器
- [支持的多模态模型](../models/supported_models.md#list-of-multimodal-language-models) - 模型兼容性