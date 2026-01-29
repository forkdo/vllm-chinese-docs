# 提示词嵌入输入

本页面介绍如何将提示词嵌入输入传递给 vLLM。

## 什么是提示词嵌入？

大型语言模型处理文本数据的传统流程是：先将文本转换为 token ID（通过分词器），然后将 token ID 转换为提示词嵌入。对于传统的仅解码器模型（如 meta-llama/Llama-3.1-8B-Instruct），将 token ID 转换为提示词嵌入的步骤是通过查表从学习到的嵌入矩阵中获取，但模型并不局限于仅处理其 token 词汇表对应的嵌入。

## 离线推理

要输入多模态数据，请按照 [vllm.inputs.EmbedsPrompt][] 中的以下模式操作：

- `prompt_embeds`：一个 torch 张量，表示一系列提示词/token 嵌入。其形状为 (sequence_length, hidden_size)，其中 sequence_length 是 token 嵌入的数量，hidden_size 是模型的隐藏大小（嵌入大小）。

### Hugging Face Transformers 输入

您可以将 Hugging Face Transformers 模型的提示词嵌入传递给提示词嵌入字典的 `'prompt_embeds'` 字段，如下例所示：

[examples/offline_inference/prompt_embed_inference.py](../../examples/offline_inference/prompt_embed_inference.py)

## 在线服务

我们的 OpenAI 兼容服务器通过 [Completions API](https://platform.openai.com/docs/api-reference/completions) 接受提示词嵌入输入。提示词嵌入输入通过 JSON 包中的新 `'prompt_embeds'` 键添加，并通过 `vllm serve` 中的 `--enable-prompt-embeds` 标志启用。

当单个请求中同时提供 `'prompt_embeds'` 和 `'prompt'` 输入时，提示词嵌入总是优先返回。

提示词嵌入以 base64 编码的 torch 张量形式传递。

!!! warning
    如果传递了形状不正确的嵌入，vLLM 引擎可能会崩溃。
    仅对可信用户启用此标志！

### 通过 OpenAI 客户端使用 Transformers 输入

首先，启动 OpenAI 兼容服务器：

```bash
vllm serve meta-llama/Llama-3.2-1B-Instruct --runner generate \
  --max-model-len 4096 --enable-prompt-embeds
```

然后，您可以按如下方式使用 OpenAI 客户端：

[examples/online_serving/prompt_embed_inference_with_openai_client.py](../../examples/online_serving/prompt_embed_inference_with_openai_client.py)