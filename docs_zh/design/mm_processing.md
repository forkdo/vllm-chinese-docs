# 多模态数据处理

为了启用 vLLM 中的各种优化功能，例如 [chunked prefill](../configuration/optimization.md#chunked-prefill) 和 [prefix caching](../features/automatic_prefix_caching.md)，我们使用 [BaseMultiModalProcessor][vllm.multimodal.processing.BaseMultiModalProcessor] 来基于 HF 处理器的输出，提供占位符特征标记（例如 `<image>`）与多模态输入（例如原始输入图像）之间的对应关系。

以下是 [BaseMultiModalProcessor][vllm.multimodal.processing.BaseMultiModalProcessor] 的主要特性：

## 提示更新检测

HF 处理器的主要职责之一是使用占位符标记更新提示。例如：

- 在字符串开头插入特征占位符标记（例如 `<image><image>...<image>`，其数量等于特征大小）。
- 将现有的输入占位符标记（例如单个图像的 `<image>`）替换为特征占位符标记（例如 `<image><image>...<image>`，其数量等于特征大小）。

关于哪些标记已被更新的信息，对于找到占位符特征标记与多模态输入之间的对应关系至关重要。

在 vLLM 中，我们使用 [PromptUpdate][vllm.multimodal.processing.PromptUpdate] 在 [_get_prompt_updates][vllm.multimodal.processing.BaseMultiModalProcessor._get_prompt_updates] 中指定此信息。我们可以通过检查更新标记的存在来自动检测 HF 是否已更新提示。

## 标记化提示输入

为了支持在单独进程中进行标记化，我们支持将输入标记 ID 与多模态数据一起传递。

### 问题

考虑 HF 处理器遵循的主要步骤：

1. 标记化文本
2. 处理多模态输入
3. 执行提示更新

而我们的需求是：

- 对于文本 + 多模态输入，应用所有步骤 1--3。
- 对于标记化 + 多模态输入，仅应用步骤 2--3。

如何在不重写 HF 处理器的情况下实现这一点？我们可以尝试对不同的输入多次调用 HF 处理器：

- 对于文本 + 多模态输入，直接调用 HF 处理器。
- 对于标记化 + 多模态输入，仅对多模态输入调用处理器。

虽然 HF 处理器原生支持文本 + 多模态输入，但对标记化 + 多模态输入的支持则不然：如果输入占位符标记的数量与多模态输入的数量不对应，会抛出错误。

此外，由于标记化文本未经过 HF 处理器，我们必须自行应用步骤 3，以保持输出标记和多模态数据的一致性。

### 虚拟文本

我们通过要求每个模型定义如何根据多模态输入的数量生成虚拟文本来解决第一个问题，通过 [get_dummy_text][vllm.multimodal.processing.BaseDummyInputsBuilder.get_dummy_text]。这使我们能够生成对应于多模态输入的虚拟文本，并将其一起输入以获取处理后的多模态数据。

### 自动提示更新

我们通过在 [_apply_prompt_updates][vllm.multimodal.processing.BaseMultiModalProcessor._apply_prompt_updates] 中实现模型无关的代码来解决第二个问题，根据 [_get_prompt_updates][vllm.multimodal.processing.BaseMultiModalProcessor._get_prompt_updates] 输出的规范，自动用特征占位符标记更新提示。

### 总结

借助虚拟文本和自动提示更新，我们的多模态处理器最终可以接受文本和标记提示以及多模态数据。详细逻辑显示在 [_apply_hf_processor_main][vllm.multimodal.processing.BaseMultiModalProcessor._apply_hf_processor_main] 中。

## 处理器输出缓存

某些 HF 处理器，例如 Qwen2-VL 的处理器，[非常慢](https://github.com/vllm-project/vllm/issues/9238)。为了缓解这个问题，我们缓存 HF 处理器的多模态输出，避免重复处理相同的多模态输入（例如图像）。

当传入新数据时，我们首先检查哪些项目在缓存中，哪些缺失。缺失的项目在单个批次中传递给 HF 处理器并缓存，然后与缓存中的现有项目合并。

由于我们只处理缺失的多模态数据项目，输入占位符标记的数量不再对应多模态输入的数量，因此它们无法与文本提示一起传递给 HF 处理器。因此，我们分别处理文本和多模态输入，使用 [虚拟文本](#dummy-text) 来避免 HF 错误。由于这跳过了 HF 的提示更新代码，我们随后应用 [自动提示更新](#automatic-prompt-updating) 来保持输出标记和多模态数据的一致性。