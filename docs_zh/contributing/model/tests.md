# 单元测试

本页面介绍如何编写单元测试来验证您模型的实现。

## 必需测试

这些测试是将您的 PR 合并到 vLLM 库中的必要条件。
缺少这些测试，您的 PR 的 CI 将会失败。

### 模型加载

在 [tests/models/registry.py](../../../tests/models/registry.py) 中为您的模型包含一个示例 HuggingFace 仓库。
这启用了一个单元测试，加载虚拟权重以确保模型可以在 vLLM 中成功初始化。

!!! important
    每个部分中的模型列表应按字母顺序维护。

!!! tip
    如果您的模型需要 HF Transformers 的开发版本，您可以设置
    `min_transformers_version` 来跳过 CI 中的测试，直到模型发布为止。

## 可选测试

这些测试不是将您的 PR 合并到 vLLM 库中的必需条件。
通过这些测试可以更进一步地确认您的实现是正确的，并有助于避免未来的回归问题。

### 模型正确性

这些测试将 vLLM 的模型输出与 [HF Transformers](https://github.com/huggingface/transformers) 进行比较。您可以在 [tests/models](../../../tests/models) 的子目录下添加新的测试。

#### 生成式模型

对于 [生成式模型](../../models/generative_models.md)，有两级正确性测试，定义在 [tests/models/utils.py](../../../tests/models/utils.py) 中：

- 精确正确性 (`check_outputs_equal`)：vLLM 输出的文本应与 HF 输出的文本完全匹配。
- Logprobs 相似性 (`check_logprobs_close`)：vLLM 输出的 logprobs 应在 HF 输出的 top-k logprobs 中，反之亦然。

#### 池化模型

对于 [池化模型](../../models/pooling_models.md)，我们仅检查余弦相似度，定义在 [tests/models/utils.py](../../../tests/models/utils.py) 中。

### 多模态处理

#### 通用测试

将您的模型添加到 [tests/models/multimodal/processing/test_common.py](../../../tests/models/multimodal/processing/test_common.py) 中，可验证以下输入组合产生相同的输出：

- 文本 + 多模态数据
- Token + 多模态数据
- 文本 + 缓存的多模态数据
- Token + 缓存的多模态数据

#### 模型特定测试

您可以在 [tests/models/multimodal/processing](../../../tests/models/multimodal/processing) 下创建新文件，运行仅适用于您模型的测试。

例如，如果您的模型的 HF 处理器接受用户指定的关键字参数，您可以验证这些关键字参数是否被正确应用，如在 [tests/models/multimodal/processing/test_phi3v.py](../../../tests/models/multimodal/processing/test_phi3v.py) 中所示。