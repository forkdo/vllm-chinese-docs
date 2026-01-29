# 常见问题

> Q: 如何使用 OpenAI API 在单个端口上服务多个模型？

A: 假设您指的是使用 OpenAI 兼容服务器同时服务多个模型，目前暂不支持此功能。您可以同时运行服务器的多个实例（每个实例服务不同的模型），并通过另一层路由机制将传入请求路由到正确的服务器。

---

> Q: 离线推理嵌入应使用哪个模型？

A: 您可以尝试 [e5-mistral-7b-instruct](https://huggingface.co/intfloat/e5-mistral-7b-instruct) 和 [BAAI/bge-base-en-v1.5](https://huggingface.co/BAAI/bge-base-en-v1.5)；
更多模型请参见 [此处](../models/supported_models.md)。

通过提取隐藏状态，vLLM 可以自动将文本生成模型（如 [Llama-3-8B](https://huggingface.co/meta-llama/Meta-Llama-3-8B)、
[Mistral-7B-Instruct-v0.3](https://huggingface.co/mistralai/Mistral-7B-Instruct-v0.3) 等）转换为嵌入模型，
但这些模型在嵌入任务上的表现通常不如专门为此任务训练的模型。

---

> Q: vLLM 中提示的输出在不同运行之间会变化吗？

A: 是的，会变化。vLLM 不保证输出 token 的 logprob（对数概率）的稳定性。logprob 的变化可能由以下原因引起：
Torch 操作中的数值不稳定性，或在批处理大小发生变化时批处理 Torch 操作的非确定性行为。更多详情，
请参见 [数值精度章节](https://pytorch.org/docs/stable/notes/numerical_accuracy.html#batched-computations-or-slice-computations)。

在 vLLM 中，由于其他并发请求、批处理大小变化或推测解码中的批扩展等因素，相同请求可能会以不同的方式批处理。这些批处理差异，结合 Torch 操作的数值不稳定性，
可能导致每一步的 logit/logprob 值略有不同。这些差异可能累积，从而导致采样出不同的 token。一旦采样出不同的 token，进一步的偏离就很可能发生。

## 缓解策略

- 为提高稳定性和减少方差，请使用 `float32`。注意这会占用更多内存。
- 如果使用 `bfloat16`，切换到 `float16` 也可能有所帮助。
- 使用请求种子可以帮助在温度 > 0 时实现更稳定的生成，但由于精度差异仍可能出现不一致。