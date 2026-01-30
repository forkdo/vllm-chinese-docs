# Speculators

[Speculators](https://docs.vllm.ai/projects/speculators/en/latest/) 是一个通过推测性解码加速 LLM 推理的库，提供高效的草稿模型训练，可与 vLLM 无缝集成，从而降低延迟并提高吞吐量。

Speculators 提供以下关键特性：

- **使用 vLLM 生成离线训练数据**：支持使用 vLLM 生成隐藏状态。数据样本会保存到磁盘，可用于草稿模型训练。
- **草稿模型训练支持**：支持单层和多层草稿模型的端到端训练。支持非 MoE 和 MoE 模型的训练。
- **标准化、可扩展的格式**：提供与 Hugging Face 兼容的格式来定义推测性模型，并提供工具将外部研究仓库的模型转换为标准 Speculators 格式，便于采用。
- **与 vLLM 无缝集成**：专为直接部署到 vLLM 而构建，能够以最小开销实现低延迟、生产级的推理。

## 为何使用 Speculators？

大型语言模型一次生成一个 token，这会造成一个根本性的瓶颈：每个 token 都需要通过模型进行一次完整的前向传播，而在等待内存密集型操作时，GPU 计算能力无法得到充分利用。  
推测性解码通过一个更小、更快的“草稿”模型（通常只是一个 transformer 层）提前预测多个 token，然后由主模型并行验证这些 token，从而解决这一问题。

推测性解码提供以下优势：

- **降低延迟**：对于聊天机器人和代码助手等交互式应用，生成 token 的速度可提升 2-3 倍，响应时间直接影响用户体验
- **更好的 GPU 利用率**：将大模型中延迟高、内存密集型的解码转换为计算密集型的并行 token 验证，提高硬件利用率
- **无质量损失**：推测性解码不会近似目标模型。被接受的 token 正是目标模型在相同采样配置下会生成的 token；被拒绝的草稿 token 会被丢弃并由目标模型重新生成
- **成本效益**：通过减少每个请求占用硬件的时间，每个 GPU 可以处理更多请求

对于用户需要实时等待响应的延迟敏感型应用（如对话式 AI、交互式编码助手和流式文本生成），Speculators 尤其有价值。

## 资源

- [Speculators 示例](https://github.com/vllm-project/speculators/tree/main/examples)
- [GitHub 仓库](https://github.com/vllm-project/speculators)