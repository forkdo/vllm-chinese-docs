# 总结

!!! important
    现在，许多解码器语言模型都可以使用 [Transformers 建模后端](../../models/supported_models.md#transformers) 自动加载，而无需在 vLLM 中实现它们。请先尝试运行 `vllm serve <model>` 命令！

vLLM 模型是专门的 [PyTorch](https://pytorch.org/) 模型，它们利用各种[特性](../../features/README.md#compatibility-matrix)来优化性能。

将模型集成到 vLLM 中的复杂性在很大程度上取决于模型的架构。
如果模型与 vLLM 中已有的模型具有相似的架构，那么这个过程会相当简单。
然而，对于包含新算子（例如新的注意力机制）的模型，这个过程可能会更加复杂。

请阅读以下页面以获取分步指南：

- [基础模型](basic.md)
- [注册模型](registration.md)
- [单元测试](tests.md)
- [多模态支持](multimodal.md)
- [语音转文本支持](transcription.md)

!!! tip
    如果您在将模型集成到 vLLM 时遇到问题，请随时提出 [GitHub issue](https://github.com/vllm-project/vllm/issues)
    或在我们的[开发者 Slack](https://slack.vllm.ai) 上提问。
    我们很乐意帮助您！