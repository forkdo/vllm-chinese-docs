# 在线服务

vLLM 提供了一个与许多接口兼容的 HTTP 服务器！

## OpenAI 兼容服务器

我们目前支持以下 OpenAI API：

- [Completions API](./openai_compatible_server.md#completions-api) (`/v1/completions`)
    - 仅适用于[文本生成模型](../../models/generative_models.md)。
    - *注意：不支持 `suffix` 参数。*
- [Chat Completions API](./openai_compatible_server.md#chat-api) (`/v1/chat/completions`)
    - 仅适用于具有[聊天模板](#chat-template)的[文本生成模型](../../models/generative_models.md)。
    - *注意：`user` 参数被忽略。*
    - *注意：* 将 `parallel_tool_calls` 参数设置为 `false` 可确保 vLLM 每个请求只返回零或一个工具调用。将其设置为 `true`（默认值）允许每个请求返回多个工具调用。如果设置为 `true`，不能保证会返回多个工具调用，因为这种行为取决于模型，并且并非所有模型都设计为支持并行工具调用。
- [Chat Completions batch API](./openai_compatible_server.md#chat-api) (`/v1/chat/completions/batch`)
- [Responses API](./openai_compatible_server.md#responses-api) (`/v1/responses`, `/v1/responses/{response_id}`, `/v1/responses/{response_id}/cancel`)
    - 仅适用于[文本生成模型](../../models/generative_models.md)。
- [Embeddings API](../../models/pooling_models/embed.md#openai-compatible-embeddings-api) (`/v1/embeddings`)
    - 仅适用于[嵌入模型](../../models/pooling_models/embed.md)。
- [Transcriptions API](./speech_to_text.md#transcriptions-api) (`/v1/audio/transcriptions`)
    - 仅适用于[自动语音识别 (ASR) 模型](../../models/supported_models.md#transcription)。
- [Translation API](./speech_to_text.md#translations-api) (`/v1/audio/translations`)
    - 仅适用于[自动语音识别 (ASR) 模型](../../models/supported_models.md#transcription)。

## Anthropic APIs

- Anthropic messages API (`/v1/messages`, `/v1/messages/count_tokens`)

## Cohere APIs

- [Cohere Embed API](../../models/pooling_models/embed.md#cohere-embed-api) (`/v2/embed`)
    - 与[Cohere 的 Embed API](https://docs.cohere.com/reference/embed)兼容
    - 适用于任何[嵌入模型](../../models/pooling_models/embed.md#supported-models)，包括多模态模型。
- [Cohere Rerank API](../../models/pooling_models/scoring.md#cohere-rerank-api) (`/rerank`, `/v1/rerank`, `/v2/rerank`)
    - 实现了[Jina AI 的 v1 rerank API](https://jina.ai/reranker/)
    - 与[Cohere 的 v1 & v2 rerank APIs](https://docs.cohere.com/v2/reference/rerank)兼容

## 池化 APIs

有关池化模型的更多详情，请参阅[此页面](../../models/pooling_models/README.md)。

- [分类用法](../../models/pooling_models/classify.md)
    - [分类 API](../../models/pooling_models/classify.md#online-serving) (`/classify`)
    - 仅适用于[分类模型](../../models/pooling_models/classify.md)。
- [嵌入用法](../../models/pooling_models/embed.md)
    - [Cohere Embed API](../../models/pooling_models/embed.md#cohere-embed-api) (`/v2/embed`)
    - [OpenAI 兼容嵌入 API](../../models/pooling_models/embed.md#openai-compatible-embeddings-api) (`/v1/embeddings`)
    - 仅适用于[嵌入模型](../../models/pooling_models/embed.md)。
- [评分用法](../../models/pooling_models/scoring.md)
    - [评分 API](../../models/pooling_models/scoring.md#score-api) (`/score`, `/v1/score`)
    - [Cohere Rerank API](../../models/pooling_models/scoring.md#cohere-rerank-api) (`/rerank`, `/v1/rerank`, `/v2/rerank`)
    - 适用于[评分模型](../../models/pooling_models/scoring.md)（交叉编码器、双编码器、晚期交互）。
- [池化 API](../../models/pooling_models/README.md#pooling-api) (`/pooling`)
    - 适用于所有[池化模型](../../models/pooling_models/README.md)。

## 语音转文本 APIs

有关语音转文本的更多详情，请参阅[此页面](speech_to_text.md)。

- [转录 API](./speech_to_text.md#transcriptions-api) (`/v1/audio/transcriptions`)
    - 仅适用于[自动语音识别 (ASR) 模型](../../models/supported_models.md#transcription)。
- [翻译 API](./speech_to_text.md#translations-api) (`/v1/audio/translations`)
    - 仅适用于[自动语音识别 (ASR) 模型](../../models/supported_models.md#transcription)。
- [实时 API](./speech_to_text.md#realtime-api) (`/v1/realtime`)
    - 仅适用于[自动语音识别 (ASR) 模型](../../models/supported_models.md#realtime-transcription)。

## 自定义 APIs

- [分类 API](../../models/pooling_models/classify.md#classification-api) (`/classify`)
    - 仅适用于[分类模型](../../models/pooling_models/classify.md)。
- [评分 API](../../models/pooling_models/scoring.md#score-api) (`/score`, `/v1/score`)
    - 适用于[评分模型](../../models/pooling_models/scoring.md)（交叉编码器、双编码器、晚期交互）。
- [池化 API](../../models/pooling_models/README.md#pooling-api) (`/pooling`)
    - 适用于所有[池化模型](../../models/pooling_models/README.md)。
- [生成式评分 API](generative_scoring.md) (`/generative_scoring`)
    - 适用于[因果语言模型](../../models/generative_models.md)（任务 `"generate"`）。
    - 计算指定 `label_token_ids` 的下一个令牌概率。

## 仪表器 APIs

### 基础 APIs

- `/version` - 版本信息
- `/load` - 服务器负载指标
- `/v1/models` - 列出可用模型
- `/health` - 健康检查

### 指标 APIs

有关指标的更多详情，请参阅[此页面](../../design/metrics.md)。

- `/metrics` - Prometheus 兼容的指标 HTTP 端点

### 离线 API 文档

FastAPI `/docs` 端点默认需要互联网连接。要在气隙环境中启用离线访问，请使用 `--enable-offline-docs` 标志：

```bash
vllm serve NousResearch/Meta-Llama-3-8B-Instruct --enable-offline-docs
```
