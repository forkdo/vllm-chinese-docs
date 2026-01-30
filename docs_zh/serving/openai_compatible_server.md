# OpenAI 兼容服务器

vLLM 提供了一个 HTTP 服务器，实现了 OpenAI 的 [Completions API](https://platform.openai.com/docs/api-reference/completions)、[Chat API](https://platform.openai.com/docs/api-reference/chat) 等更多功能！此功能允许您通过 HTTP 客户端来部署模型并与之交互。

在终端中，您可以[安装](../getting_started/installation/README.md) vLLM，然后使用 [`vllm serve`](../configuration/serve_args.md) 命令启动服务器。（您也可以使用我们的 [Docker](../deployment/docker.md) 镜像。）

```bash
vllm serve NousResearch/Meta-Llama-3-8B-Instruct \
  --dtype auto \
  --api-key token-abc123
```

要调用服务器，请在您首选的文本编辑器中创建一个使用 HTTP 客户端的脚本。包含您想要发送给模型的任何消息。然后运行该脚本。以下是一个使用 [官方 OpenAI Python 客户端](https://github.com/openai/openai-python) 的示例脚本。

??? code

    ```python
    from openai import OpenAI
    client = OpenAI(
        base_url="http://localhost:8000/v1",
        api_key="token-abc123",
    )

    completion = client.chat.completions.create(
        model="NousResearch/Meta-Llama-3-8B-Instruct",
        messages=[
            {"role": "user", "content": "Hello!"},
        ],
    )

    print(completion.choices[0].message)
    ```

!!! tip
    vLLM 支持一些 OpenAI 不支持的参数，例如 `top_k`。
    您可以通过 OpenAI 客户端的 `extra_body` 参数将这些参数传递给 vLLM，例如对于 `top_k` 使用 `extra_body={"top_k": 50}`。

!!! important
    默认情况下，如果 Hugging Face 模型仓库中存在 `generation_config.json`，服务器会应用它。这意味着某些采样参数的默认值可能会被模型创建者推荐的值覆盖。

    要禁用此行为，请在启动服务器时传递 `--generation-config vllm`。

## 支持的 API

我们目前支持以下 OpenAI API：

- [Completions API](#completions-api) (`/v1/completions`)
    - 仅适用于[文本生成模型](../models/generative_models.md)。
    - *注意：不支持 `suffix` 参数。*
- [Responses API](#responses-api) (`/v1/responses`)
    - 仅适用于[文本生成模型](../models/generative_models.md)。
- [Chat Completions API](#chat-api) (`/v1/chat/completions`)
    - 仅适用于具有[聊天模板](../serving/openai_compatible_server.md#chat-template)的[文本生成模型](../models/generative_models.md)。
    - *注意：`user` 参数被忽略。*
    - *注意：* 将 `parallel_tool_calls` 参数设置为 `false` 可确保 vLLM 每个请求只返回零个或一个工具调用。将其设置为 `true`（默认值）允许每个请求返回多个工具调用。如果设置为 `true`，并不能保证会返回多个工具调用，因为该行为取决于模型，并非所有模型都设计为支持并行工具调用。
- [Embeddings API](#embeddings-api) (`/v1/embeddings`)
    - 仅适用于[嵌入模型](../models/pooling_models.md)。
- [Transcriptions API](#transcriptions-api) (`/v1/audio/transcriptions`)
    - 仅适用于[自动语音识别 (ASR) 模型](../models/supported_models.md#transcription)。
- [Translation API](#translations-api) (`/v1/audio/translations`)
    - 仅适用于[自动语音识别 (ASR) 模型](../models/supported_models.md#transcription)。
- [Realtime API](#realtime-api) (`/v1/realtime`)
    - 仅适用于[自动语音识别 (ASR) 模型](../models/supported_models.md#transcription)。

此外，我们还有以下自定义 API：

- [Tokenizer API](#tokenizer-api) (`/tokenize`, `/detokenize`)
    - 适用于任何带有分词器的模型。
- [Pooling API](#pooling-api) (`/pooling`)
    - 适用于所有[池化模型](../models/pooling_models.md)。
- [Classification API](#classification-api) (`/classify`)
    - 仅适用于[分类模型](../models/pooling_models.md)。
- [Score API](#score-api) (`/score`)
    - 适用于[嵌入模型和交叉编码器模型](../models/pooling_models.md)。
- [Re-rank API](#re-rank-api) (`/rerank`, `/v1/rerank`, `/v2/rerank`)
    - 实现了 [Jina AI 的 v1 re-rank API](https://jina.ai/reranker/)
    - 同时兼容 [Cohere 的 v1 和 v2 re-rank APIs](https://docs.cohere.com/v2/reference/rerank)
    - Jina 和 Cohere 的 API 非常相似；Jina 的 API 在 rerank 端点的响应中包含额外信息。
    - 仅适用于[交叉编码器模型](../models/pooling_models.md)。

## 聊天模板

为了使语言模型支持聊天协议，vLLM 要求模型在其分词器配置中包含一个聊天模板。聊天模板是一个 Jinja2 模板，它指定了角色、消息和其他聊天特定标记在输入中的编码方式。

`NousResearch/Meta-Llama-3-8B-Instruct` 的聊天模板示例可以在[此处](https://github.com/meta-llama/llama3?tab=readme-ov-file#instruction-tuned-models)找到。

有些模型即使经过指令/聊天微调，也没有提供聊天模板。对于这些模型，您可以在 `--chat-template` 参数中手动指定其聊天模板，参数值为聊天模板的文件路径或字符串形式的模板。没有聊天模板，服务器将无法处理聊天请求，所有聊天请求都会出错。

```bash
vLLM serve <model> --chat-template ./path-to-chat-template.jinja
```

vLLM 社区为流行模型提供了一组聊天模板。您可以在 [examples](../../examples) 目录下找到它们。

随着多模态聊天 API 的加入，OpenAI 规范现在接受一种新格式的聊天消息，该格式同时指定了 `type` 和 `text` 字段。下面提供了一个示例：

```python
completion = client.chat.completions.create(
    model="NousResearch/Meta-Llama-3-8B-Instruct",
    messages=[
        {
            "role": "user",
            "content": [
                {"type": "text", "text": "Classify this sentiment: vLLM is wonderful!"},
            ],
        },
    ],
)
```

大多数 LLM 的聊天模板期望 `content` 字段是一个字符串，但也有一些较新的模型，如 `meta-llama/Llama-Guard-3-1B`，期望内容按照请求中的 OpenAI 模式进行格式化。vLLM 提供了尽最大努力自动检测此格式的支持，这会记录为类似 *"Detected the chat template content format to be..."* 的字符串，并在内部转换传入的请求以匹配检测到的格式，格式可以是以下之一：

- `"string"`：字符串。
    - 示例：`"Hello world"`
- `"openai"`：字典列表，类似于 OpenAI 模式。
    - 示例：`[{"type": "text", "text": "Hello world!"}]`

如果结果不符合您的预期，您可以设置 `--chat-template-content-format` CLI 参数来覆盖要使用的格式。

## 额外参数

vLLM 支持一组不属于 OpenAI API 的参数。
为了使用它们，您可以在 OpenAI 客户端中将其作为额外参数传递。
或者，如果您直接使用 HTTP 调用，可以直接将它们合并到 JSON 负载中。

```python
completion = client.chat.completions.create(
    model="NousResearch/Meta-Llama-3-8B-Instruct",
    messages=[
        {"role": "user", "content": "Classify this sentiment: vLLM is wonderful!"},
    ],
    extra_body={
        "structured_outputs": {"choice": ["positive", "negative"]},
    },
)
```

## 额外 HTTP 头

目前仅支持 `X-Request-Id` HTTP 请求头。可以通过 `--enable-request-id-headers` 启用它。

??? code

    ```python
    completion = client.chat.completions.create(
        model="NousResearch/Meta-Llama-3-8B-Instruct",
        messages=[
            {"role": "user", "content": "Classify this sentiment: vLLM is wonderful!"},
        ],
        extra_headers={
            "x-request-id": "sentiment-classification-00001",
        },
    )
    print(completion._request_id)
    ```

completion = client.completions.create(
        model="NousResearch/Meta-Llama-3-8B-Instruct",
        prompt="A robot may not injure a human being",
        extra_headers={
            "x-request-id": "completion-test",
        },
    )
    print(completion._request_id)
    ```

## 离线 API 文档

默认情况下，FastAPI 的 `/docs` 端点需要互联网连接。要在隔离网络环境中启用离线访问，请使用 `--enable-offline-docs` 标志：

```bash
vllm serve NousResearch/Meta-Llama-3-8B-Instruct --enable-offline-docs
```

## API 参考

### Completions API

我们的 Completions API 兼容 [OpenAI 的 Completions API](https://platform.openai.com/docs/api-reference/completions)；你可以使用 [官方的 OpenAI Python 客户端](https://github.com/openai/openai-python) 与之交互。

代码示例：[examples/online_serving/openai_completion_client.py](../../examples/online_serving/openai_completion_client.py)

#### 额外参数

支持以下 [采样参数](../api/README.md#inference-parameters)。

??? code

    ```python
    --8<-- "vllm/entrypoints/openai/completion/protocol.py:completion-sampling-params"
    ```

支持以下额外参数：

??? code

    ```python
    --8<-- "vllm/entrypoints/openai/completion/protocol.py:completion-extra-params"
    ```

### Chat API

我们的 Chat API 兼容 [OpenAI 的 Chat Completions API](https://platform.openai.com/docs/api-reference/chat)；你可以使用 [官方的 OpenAI Python 客户端](https://github.com/openai/openai-python) 与之交互。

我们同时支持 [视觉](https://platform.openai.com/docs/guides/vision) 和 [音频](https://platform.openai.com/docs/guides/audio?audio-generation-quickstart-example=audio-in) 相关参数；更多信息请参阅我们的 [多模态输入](../features/multimodal_inputs.md) 指南。

- *注意：不支持 `image_url.detail` 参数。*

代码示例：[examples/online_serving/openai_chat_completion_client.py](../../examples/online_serving/openai_chat_completion_client.py)

#### 额外参数

支持以下 [采样参数](../api/README.md#inference-parameters)。

??? code

    ```python
    --8<-- "vllm/entrypoints/openai/chat_completion/protocol.py:chat-completion-sampling-params"
    ```

支持以下额外参数：

??? code

    ```python
    --8<-- "vllm/entrypoints/openai/chat_completion/protocol.py:chat-completion-extra-params"
    ```

### Responses API

我们的 Responses API 兼容 [OpenAI 的 Responses API](https://platform.openai.com/docs/api-reference/responses)；你可以使用 [官方的 OpenAI Python 客户端](https://github.com/openai/openai-python) 与之交互。

代码示例：[examples/online_serving/openai_responses_client_with_tools.py](../../examples/online_serving/openai_responses_client_with_tools.py)

#### 额外参数

请求对象中支持以下额外参数：

??? code

    ```python
    --8<-- "vllm/entrypoints/openai/responses/protocol.py:responses-extra-params"
    ```

响应对象中支持以下额外参数：

??? code

    ```python
    --8<-- "vllm/entrypoints/openai/responses/protocol.py:responses-response-extra-params"
    ```

### Embeddings API

我们的 Embeddings API 兼容 [OpenAI 的 Embeddings API](https://platform.openai.com/docs/api-reference/embeddings)；你可以使用 [官方的 OpenAI Python 客户端](https://github.com/openai/openai-python) 与之交互。

代码示例：[examples/pooling/embed/openai_embedding_client.py](../../examples/pooling/embed/openai_embedding_client.py)

如果模型有 [聊天模板](../serving/openai_compatible_server.md#chat-template)，你可以用 `messages` 列表（与 [Chat API](#chat-api) 相同的模式）替换 `inputs`，它将被视为模型的单个提示。这里提供了一个调用 API 的便捷函数，同时保留了 OpenAI 的类型注解：

??? code

    ```python
    from openai import OpenAI
    from openai._types import NOT_GIVEN, NotGiven
    from openai.types.chat import ChatCompletionMessageParam
    from openai.types.create_embedding_response import CreateEmbeddingResponse

    def create_chat_embeddings(
        client: OpenAI,
        *,
        messages: list[ChatCompletionMessageParam],
        model: str,
        encoding_format: Union[Literal["base64", "float"], NotGiven] = NOT_GIVEN,
    ) -> CreateEmbeddingResponse:
        return client.post(
            "/embeddings",
            cast_to=CreateEmbeddingResponse,
            body={"messages": messages, "model": model, "encoding_format": encoding_format},
        )
    ```

#### 多模态输入

你可以通过为服务器定义自定义聊天模板并在请求中传递 `messages` 列表，将多模态输入传递给嵌入模型。请参考下面的示例进行说明。

=== "VLM2Vec"

    启动模型服务：

    ```bash
    vllm serve TIGER-Lab/VLM2Vec-Full --runner pooling \
      --trust-remote-code \
      --max-model-len 4096 \
      --chat-template examples/template_vlm2vec_phi3v.jinja
    ```

    !!! important
        由于 VLM2Vec 与 Phi-3.5-Vision 具有相同的模型架构，我们必须显式传递 `--runner pooling` 来以嵌入模式而非文本生成模式运行此模型。

        自定义聊天模板与此模型的原始模板完全不同，可以在这里找到：[examples/template_vlm2vec_phi3v.jinja](../../examples/template_vlm2vec_phi3v.jinja)

    由于 OpenAI 客户端未定义请求模式，我们使用较低级别的 `requests` 库向服务器发送请求：

    ??? code

        ```python
        from openai import OpenAI
        client = OpenAI(
            base_url="http://localhost:8000/v1",
            api_key="EMPTY",
        )
        image_url = "https://vllm-public-assets.s3.us-west-2.amazonaws.com/vision_model_images/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg"

        response = create_chat_embeddings(
            client,
            model="TIGER-Lab/VLM2Vec-Full",
            messages=[
                {
                    "role": "user",
                    "content": [
                        {"type": "image_url", "image_url": {"url": image_url}},
                        {"type": "text", "text": "Represent the given image."},
                    ],
                }
            ],
            encoding_format="float",
        )

        print("Image embedding output:", response.data[0].embedding)
        ```

=== "DSE-Qwen2-MRL"

    启动模型服务：

    ```bash
    vllm serve MrLight/dse-qwen2-2b-mrl-v1 --runner pooling \
      --trust-remote-code \
      --max-model-len 8192 \
      --chat-template examples/template_dse_qwen2_vl.jinja
    ```

    !!! important
        与 VLM2Vec 类似，我们必须显式传递 `--runner pooling`。

        此外，`MrLight/dse-qwen2-2b-mrl-v1` 需要 EOS 令牌用于嵌入，这由一个自定义聊天模板处理：[examples/template_dse_qwen2_vl.jinja](../../examples/template_dse_qwen2_vl.jinja)

    !!! important
        `MrLight/dse-qwen2-2b-mrl-v1` 需要一张最小图像尺寸的占位图用于文本查询嵌入。详细信息请参阅下面的完整代码示例。

完整示例：[examples/pooling/embed/vision_embedding_online.py](../../examples/pooling/embed/vision_embedding_online.py)

#### 额外参数

支持以下 [池化参数][vllm.PoolingParams]。

```python
--8<-- "vllm/pooling_params.py:common-pooling-params"
--8<-- "vllm/pooling_params.py:embed-pooling-params"
```

支持以下 Embeddings API 参数：

??? code

    ```python
    --8<-- "vllm/entrypoints/pooling/base/protocol.py:pooling-common-params"
    --8<-- "vllm/entrypoints/pooling/base/protocol.py:completion-params"
    --8<-- "vllm/entrypoints/pooling/base/protocol.py:encoding-params"
    --8<-- "vllm/entrypoints/pooling/base/protocol.py:embed-params"
    ```

支持以下额外参数：

??? code

```python
    --8<-- "vllm/entrypoints/pooling/base/protocol.py:pooling-common-extra-params"
    --8<-- "vllm/entrypoints/pooling/base/protocol.py:completion-extra-params"
    --8<-- "vllm/entrypoints/pooling/base/protocol.py:encoding-extra-params"
    --8<-- "vllm/entrypoints/pooling/base/protocol.py:embed-extra-params"
    ```

对于聊天式输入（即传递了 `messages` 参数时），支持以下参数：

默认支持以下参数：

??? code

    ```python
    --8<-- "vllm/entrypoints/pooling/base/protocol.py:pooling-common-params"
    --8<-- "vllm/entrypoints/pooling/base/protocol.py:chat-params"
    --8<-- "vllm/entrypoints/pooling/base/protocol.py:encoding-params"
    --8<-- "vllm/entrypoints/pooling/base/protocol.py:embed-params"
    ```

而是支持以下额外参数：

??? code

    ```python
    --8<-- "vllm/entrypoints/pooling/base/protocol.py:pooling-common-extra-params"
    --8<-- "vllm/entrypoints/pooling/base/protocol.py:chat-extra-params"
    --8<-- "vllm/entrypoints/pooling/base/protocol.py:encoding-extra-params"
    --8<-- "vllm/entrypoints/pooling/base/protocol.py:embed-extra-params"
    ```

### 语音转写 API

我们的语音转写 API 与 [OpenAI 的语音转写 API](https://platform.openai.com/docs/api-reference/audio/createTranscription) 兼容；你可以使用 [官方的 OpenAI Python 客户端](https://github.com/openai/openai-python) 与之交互。

!!! note
    要使用语音转写 API，请使用 `pip install vllm[audio]` 安装额外的音频依赖。

代码示例：[examples/online_serving/openai_transcription_client.py](../../examples/online_serving/openai_transcription_client.py)

#### API 强制限制

通过 `VLLM_MAX_AUDIO_CLIP_FILESIZE_MB` 环境变量设置 vLLM 将接受的最大音频文件大小（以 MB 为单位）。默认值为 25 MB。

#### 上传音频文件

语音转写 API 支持上传多种格式的音频文件，包括 FLAC、MP3、MP4、MPEG、MPGA、M4A、OGG、WAV 和 WEBM。

**使用 OpenAI Python 客户端：**

??? code

    ```python
    from openai import OpenAI

    client = OpenAI(
        base_url="http://localhost:8000/v1",
        api_key="token-abc123",
    )

    # 从磁盘上传音频文件
    with open("audio.mp3", "rb") as audio_file:
        transcription = client.audio.transcriptions.create(
            model="openai/whisper-large-v3-turbo",
            file=audio_file,
            language="en",
            response_format="verbose_json",
        )

    print(transcription.text)
    ```

**使用 curl 和 multipart/form-data：**

??? code

    ```bash
    curl -X POST "http://localhost:8000/v1/audio/transcriptions" \
      -H "Authorization: Bearer token-abc123" \
      -F "file=@audio.mp3" \
      -F "model=openai/whisper-large-v3-turbo" \
      -F "language=en" \
      -F "response_format=verbose_json"
    ```

**支持的参数：**

- `file`: 要转写的音频文件（必需）
- `model`: 用于转写的模型（必需）
- `language`: 语言代码（例如 "en"、"zh"）（可选）
- `prompt`: 指导转写风格的可选文本（可选）
- `response_format`: 响应格式（"json"、"text"）（可选）
- `temperature`: 采样温度，介于 0 和 1 之间（可选）

有关支持的完整参数列表，包括采样参数和 vLLM 扩展，请参阅 [协议定义](https://github.com/vllm-project/vllm/blob/main/vllm/entrypoints/openai/protocol.py#L2182)。

**响应格式：**

对于 `verbose_json` 响应格式：

??? code

    ```json
    {
      "text": "Hello, this is a transcription of the audio file.",
      "language": "en",
      "duration": 5.42,
      "segments": [
        {
          "id": 0,
          "seek": 0,
          "start": -0.0,
          "end": 2.5,
          "text": "Hello, this is a transcription",
          "tokens": [50364, 938, 428, 307, 275, 28347],
          "temperature": 0.0,
          "avg_logprob": -0.245,
          "compression_ratio": 1.235,
          "no_speech_prob": 0.012
        }
      ]
    }
    ```
目前 `verbose_json` 响应格式不支持 `no_speech_prob`。

#### 额外参数

支持以下 [采样参数](../api/README.md#inference-parameters)。

??? code

    ```python
    --8<-- "vllm/entrypoints/openai/protocol.py:transcription-sampling-params"
    ```

支持以下额外参数：

??? code

    ```python
    --8<-- "vllm/entrypoints/openai/protocol.py:transcription-extra-params"
    ```

### 语音翻译 API

我们的语音翻译 API 与 [OpenAI 的语音翻译 API](https://platform.openai.com/docs/api-reference/audio/createTranslation) 兼容；你可以使用 [官方的 OpenAI Python 客户端](https://github.com/openai/openai-python) 与之交互。
Whisper 模型可以将音频从 55 种支持的非英语语言之一翻译成英语。
请注意，流行的 `openai/whisper-large-v3-turbo` 模型不支持翻译功能。

!!! note
    要使用语音翻译 API，请使用 `pip install vllm[audio]` 安装额外的音频依赖。

代码示例：[examples/online_serving/openai_translation_client.py](../../examples/online_serving/openai_translation_client.py)

#### 额外参数

支持以下 [采样参数](../api/README.md#inference-parameters)。

```python
--8<-- "vllm/entrypoints/openai/protocol.py:translation-sampling-params"
```

支持以下额外参数：

```python
--8<-- "vllm/entrypoints/openai/protocol.py:translation-extra-params"
```

### 实时 API

实时 API 提供基于 WebSocket 的流式音频转写，允许在录制音频时进行实时语音转文本。

!!! note
    要使用实时 API，请使用 `uv pip install vllm[audio]` 安装额外的音频依赖。

#### 音频格式

音频必须以 base64 编码的 PCM16 格式发送，采样率为 16kHz，单声道。

#### 协议概述

1.  客户端连接到 `ws://host/v1/realtime`
2.  服务器发送 `session.created` 事件
3.  客户端可选地发送带有模型/参数的 `session.update`
4.  客户端准备就绪时发送 `input_audio_buffer.commit`
5.  客户端发送带有 base64 PCM16 数据块的 `input_audio_buffer.append` 事件
6.  服务器发送带有增量文本的 `transcription.delta` 事件
7.  服务器发送带有最终文本和用量的 `transcription.done`
8.  对于下一个话语，从步骤 5 重复
9.  可选地，客户端发送带有 `final=True` 的 `input_audio_buffer.commit` 以表示音频输入结束。在流式传输音频文件时很有用

#### 客户端 → 服务器事件

| 事件 | 描述 |
|-------|-------------|
| `input_audio_buffer.append` | 发送 base64 编码的音频块：`{"type": "input_audio_buffer.append", "audio": "<base64>"}` |
| `input_audio_buffer.commit` | 触发转写处理或结束：`{"type": "input_audio_buffer.commit", "final": bool}` |
| `session.update` | 配置会话：`{"type": "session.update", "model": "model-name"}` |

#### 服务器 → 客户端事件

| 事件 | 描述 |
|-------|-------------|
| `session.created` | 连接建立，包含会话 ID 和时间戳 |
| `transcription.delta` | 增量转写文本：`{"type": "transcription.delta", "delta": "text"}` |
| `transcription.done` | 最终转写结果及用量统计 |
| `error` | 错误通知，包含消息和可选代码 |

#### Python WebSocket 示例

??? code

    ```python
    import asyncio
    import base64
    import json
    import websockets

    async def realtime_transcribe():
        uri = "ws://localhost:8000/v1/realtime"

        async with websockets.connect(uri) as ws:
            # 等待 session.created
            response = await ws.recv()
            print(f"Session: {response}")

            # 提交缓冲区
            await ws.send(json.dumps({
                "type": "input_audio_buffer.commit"
            }))
    ```

# 发送音频分片（文件示例）
            with open("audio.raw", "rb") as f:
                while chunk := f.read(4096):
                    await ws.send(json.dumps({
                        "type": "input_audio_buffer.append",
                        "audio": base64.b64encode(chunk).decode()
                    }))

            # 发送信号表示所有音频已发送完毕
            await ws.send(json.dumps({
                "type": "input_audio_buffer.commit",
                "final": True,
            }))

            # 接收转录结果
            while True:
                response = json.loads(await ws.recv())
                if response["type"] == "transcription.delta":
                    print(response["delta"], end="", flush=True)
                elif response["type"] == "transcription.done":
                    print(f"\n最终结果: {response['text']}")
                    break

    asyncio.run(realtime_transcribe())
    ```

### Tokenizer API

我们的 Tokenizer API 是 [HuggingFace 风格分词器](https://huggingface.co/docs/transformers/en/main_classes/tokenizer) 的一个简单封装。
它包含两个端点：

- `/tokenize` 对应调用 `tokenizer.encode()`。
- `/detokenize` 对应调用 `tokenizer.decode()`。

### Pooling API

我们的 Pooling API 使用 [池化模型](../models/pooling_models.md) 对输入提示进行编码，并返回相应的隐藏状态。

输入格式与 [Embeddings API](#embeddings-api) 相同，但输出数据可以包含任意嵌套的列表，而不仅仅是一维浮点数列表。

代码示例：[examples/pooling/pooling/pooling_online.py](../../examples/pooling/pooling/pooling_online.py)

### Classification API

我们的 Classification API 直接支持 Hugging Face 的序列分类模型，例如 [ai21labs/Jamba-tiny-reward-dev](https://huggingface.co/ai21labs/Jamba-tiny-reward-dev) 和 [jason9693/Qwen2.5-1.5B-apeach](https://huggingface.co/jason9693/Qwen2.5-1.5B-apeach)。

我们通过 `as_seq_cls_model()` 自动包装任何其他 transformer 模型，该函数会在最后一个 token 上进行池化，附加一个 `RowParallelLinear` 头，并应用 softmax 来生成每个类别的概率。

代码示例：[examples/pooling/classify/classification_online.py](../../examples/pooling/classify/classification_online.py)

#### 示例请求

你可以通过传递一个字符串数组来对多个文本进行分类：

```bash
curl -v "http://127.0.0.1:8000/classify" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "jason9693/Qwen2.5-1.5B-apeach",
    "input": [
      "喜欢这家新咖啡馆——咖啡很棒。",
      "这次更新把一切都搞坏了。真令人沮丧。"
    ]
  }'
```

??? console "响应"

    ```json
    {
      "id": "classify-7c87cac407b749a6935d8c7ce2a8fba2",
      "object": "list",
      "created": 1745383065,
      "model": "jason9693/Qwen2.5-1.5B-apeach",
      "data": [
        {
          "index": -1,
          "label": "Default",
          "probs": [
            0.565970778465271,
            0.4340292513370514
          ],
          "num_classes": 2
        },
        {
          "index": 1,
          "label": "Spoiled",
          "probs": [
            0.26448777318000793,
            0.7355121970176697
          ],
          "num_classes": 2
        }
      ],
      "usage": {
        "prompt_tokens": 20,
        "total_tokens": 20,
        "completion_tokens": 0,
        "prompt_tokens_details": null
      }
    }
    ```

你也可以直接将一个字符串传递给 `input` 字段：

```bash
curl -v "http://127.0.0.1:8000/classify" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "jason9693/Qwen2.5-1.5B-apeach",
    "input": "喜欢这家新咖啡馆——咖啡很棒。"
  }'
```

??? console "响应"

    ```json
    {
      "id": "classify-9bf17f2847b046c7b2d5495f4b4f9682",
      "object": "list",
      "created": 1745383213,
      "model": "jason9693/Qwen2.5-1.5B-apeach",
      "data": [
        {
          "index": 0,
          "label": "Default",
          "probs": [
            0.565970778465271,
            0.4340292513370514
          ],
          "num_classes": 2
        }
      ],
      "usage": {
        "prompt_tokens": 10,
        "total_tokens": 10,
        "completion_tokens": 0,
        "prompt_tokens_details": null
      }
    }
    ```

#### 额外参数

支持以下 [池化参数][vllm.PoolingParams]。

```python
--8<-- "vllm/pooling_params.py:common-pooling-params"
--8<-- "vllm/pooling_params.py:classify-pooling-params"
```

支持以下 Classification API 参数：

??? code

    ```python
    --8<-- "vllm/entrypoints/pooling/base/protocol.py:pooling-common-params"
    --8<-- "vllm/entrypoints/pooling/base/protocol.py:completion-params"
    --8<-- "vllm/entrypoints/pooling/base/protocol.py:classify-params"
    ```

支持以下额外参数：

??? code

    ```python
    --8<-- "vllm/entrypoints/pooling/base/protocol.py:pooling-common-extra-params"
    --8<-- "vllm/entrypoints/pooling/base/protocol.py:completion-extra-params"
    --8<-- "vllm/entrypoints/pooling/base/protocol.py:classify-extra-params"
    ```

对于类聊天输入（即如果传递了 `messages`），支持以下参数：

??? code

    ```python
    --8<-- "vllm/entrypoints/pooling/base/protocol.py:pooling-common-params"
    --8<-- "vllm/entrypoints/pooling/base/protocol.py:chat-params"
    --8<-- "vllm/entrypoints/pooling/base/protocol.py:classify-params"
    ```

相应地，支持以下额外参数：

??? code

    ```python
    --8<-- "vllm/entrypoints/pooling/base/protocol.py:pooling-common-extra-params"
    --8<-- "vllm/entrypoints/pooling/base/protocol.py:chat-extra-params"
    --8<-- "vllm/entrypoints/pooling/base/protocol.py:classify-extra-params"
    ```

### Score API

我们的 Score API 可以应用交叉编码器模型或嵌入模型来预测句子或多模态对的分数。当使用嵌入模型时，分数对应于每对嵌入之间的余弦相似度。
通常，句子对的分数指的是两个句子之间的相似度，范围从 0 到 1。

你可以在 [sbert.net](https://www.sbert.net/docs/package_reference/cross_encoder/cross_encoder.html) 找到交叉编码器模型的文档。

代码示例：[examples/pooling/score/score_api_online.py](../../examples/pooling/score/score_api_online.py)

#### 评分模板

一些评分模型需要特定的提示格式才能正常工作。你可以使用 `--chat-template` 参数指定自定义的评分模板（参见 [聊天模板](#chat-template)）。

评分模板仅支持**交叉编码器**模型。如果你使用**嵌入**模型进行评分，vLLM 不会应用评分模板。

与聊天模板类似，评分模板接收一个 `messages` 列表。对于评分，每条消息都有一个 `role` 属性——要么是 `"query"`，要么是 `"document"`。对于通常的点式交叉编码器，你可以预期恰好有两条消息：一条查询和一条文档。要访问查询和文档内容，请使用 Jinja 的 `selectattr` 过滤器：

- **查询**：`{{ (messages | selectattr("role", "eq", "query") | first).content }}`
- **文档**：`{{ (messages | selectattr("role", "eq", "document") | first).content }}`

这种方法比基于索引的访问（`messages[0]`、`messages[1]`）更健壮，因为它通过语义角色选择消息。如果将来向 `messages` 添加了额外的消息类型，它也避免了关于消息顺序的假设。

示例模板文件：[examples/pooling/score/template/nemotron-rerank.jinja](../../examples/pooling/score/template/nemotron-rerank.jinja)

#### 单次推理

你可以将字符串传递给 `queries` 和 `documents`，形成一个句子对。

```bash
curl -X 'POST' \
  'http://127.0.0.1:8000/score' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "model": "BAAI/bge-reranker-v2-m3",
  "encoding_format": "float",
  "queries": "法国的首都是什么？",
  "documents": "法国的首都是巴黎。"
}'
```

??? console "响应"

```json
{
  "id": "score-request-id",
  "object": "list",
  "created": 693447,
  "model": "BAAI/bge-reranker-v2-m3",
  "data": [
    {
      "index": \\
      "object": "score",
      "score": 1
    }
  ],
  "usage": {}
}
```

#### 批量推理

你可以向 `queries` 传递一个字符串，向 `documents` 传递一个列表，从而构建多个句子对，其中每个句子对由 `queries` 和 `documents` 中的一个字符串组成。句子对的总数为 `len(documents)`。

??? console "请求"

    ```bash
    curl -X 'POST' \
      'http://127.0.0.1:8000/score' \
      -H 'accept: application/json' \
      -H 'Content-Type: application/json' \
      -d '{
      "model": "BAAI/bge-reranker-v2-m3",
      "queries": "What is the capital of France?",
      "documents": [
        "The capital of Brazil is Brasilia.",
        "The capital of France is Paris."
      ]
    }'
    ```

??? console "响应"

    ```json
    {
      "id": "score-request-id",
      "object": "list",
      "created": 693570,
      "model": "BAAI/bge-reranker-v2-m3",
      "data": [
        {
          "index": 0,
          "object": "score",
          "score": 0.001094818115234375
        },
        {
          "index": 1,
          "object": "score",
          "score": 1
        }
      ],
      "usage": {}
    }
    ```

你也可以向 `queries` 和 `documents` 都传递一个列表，从而构建多个句子对，其中每个句子对由 `queries` 中的一个字符串和 `documents` 中对应位置的字符串组成（类似于 `zip()` 函数）。句子对的总数为 `len(documents)`。

??? console "请求"

    ```bash
    curl -X 'POST' \
      'http://127.0.0.1:8000/score' \
      -H 'accept: application/json' \
      -H 'Content-Type: application/json' \
      -d '{
      "model": "BAAI/bge-reranker-v2-m3",
      "encoding_format": "float",
      "queries": [
        "What is the capital of Brazil?",
        "What is the capital of France?"
      ],
      "documents": [
        "The capital of Brazil is Brasilia.",
        "The capital of France is Paris."
      ]
    }'
    ```

??? console "响应"

    ```json
    {
      "id": "score-request-id",
      "object": "list",
      "created": 693447,
      "model": "BAAI/bge-reranker-v2-m3",
      "data": [
        {
          "index": 0,
          "object": "score",
          "score": 1
        },
        {
          "index": 1,
          "object": "score",
          "score": 1
        }
      ],
      "usage": {}
    }
    ```

#### 多模态输入

你可以通过请求中的 `content` 字段传递包含多模态输入（如图像等）的列表，从而向评分模型传递多模态输入。请参考以下示例进行说明。

=== "JinaVL-Reranker"

    要启动该模型服务：

    ```bash
    vllm serve jinaai/jina-reranker-m0
    ```

    由于请求模式不由 OpenAI 客户端定义，我们使用底层的 `requests` 库向服务器发送请求：

    ??? 代码

        ```python
        import requests

        response = requests.post(
            "http://localhost:8000/v1/score",
            json={
                "model": "jinaai/jina-reranker-m0",
                "queries": "slm markdown",
                "documents": {
                    "content": [
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": "https://raw.githubusercontent.com/jina-ai/multimodal-reranker-test/main/handelsblatt-preview.png"
                            },
                        },
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": "https://raw.githubusercontent.com/jina-ai/multimodal-reranker-test/main/paper-11.png"
                            },
                        },
                    ],
                },
            },
        )
        response.raise_for_status()
        response_json = response.json()
        print("Scoring output:", response_json["data"][0]["score"])
        print("Scoring output:", response_json["data"][1]["score"])
        ```

完整示例：

- [examples/pooling/score/vision_score_api_online.py](../../examples/pooling/score/vision_score_api_online.py)
- [examples/pooling/score/vision_rerank_api_online.py](../../examples/pooling/score/vision_rerank_api_online.py)

#### 额外参数

支持以下 [池化参数][vllm.PoolingParams]。

```python
--8<-- "vllm/pooling_params.py:common-pooling-params"
--8<-- "vllm/pooling_params.py:classify-pooling-params"
```

支持以下 Score API 参数：

```python
--8<-- "vllm/entrypoints/pooling/base/protocol.py:pooling-common-params"
--8<-- "vllm/entrypoints/pooling/score/protocol.py:score-extra-params"
```

支持以下额外参数：

```python
--8<-- "vllm/entrypoints/pooling/base/protocol.py:pooling-common-extra-params"
--8<-- "vllm/entrypoints/pooling/base/protocol.py:classify-extra-params"
--8<-- "vllm/entrypoints/pooling/score/protocol.py:score-extra-params"
```

### 重排序 API

我们的重排序 API 可以应用嵌入模型或交叉编码器模型来预测单个查询与一组文档列表中每个文档之间的相关性分数。通常，句子对的分数指的是两个句子或多模态输入（如图像等）之间的相似度，范围在 0 到 1 之间。

你可以在 [sbert.net](https://www.sbert.net/docs/package_reference/cross_encoder/cross_encoder.html) 找到交叉编码器模型的文档。

重排序端点支持流行的重排序模型，例如 `BAAI/bge-reranker-base` 以及其他支持 `score` 任务的模型。此外，`/rerank`、`/v1/rerank` 和 `/v2/rerank` 端点与 [Jina AI 的重排序 API 接口](https://jina.ai/reranker/) 和 [Cohere 的重排序 API 接口](https://docs.cohere.com/v2/reference/rerank) 兼容，以确保与流行的开源工具兼容。

代码示例：[examples/pooling/score/rerank_api_online.py](../../examples/pooling/score/rerank_api_online.py)

#### 示例请求

请注意，`top_n` 请求参数是可选的，默认为 `documents` 字段的长度。结果文档将按相关性排序，`index` 属性可用于确定原始顺序。

??? console "请求"

    ```bash
    curl -X 'POST' \
      'http://127.0.0.1:8000/v1/rerank' \
      -H 'accept: application/json' \
      -H 'Content-Type: application/json' \
      -d '{
      "model": "BAAI/bge-reranker-base",
      "query": "What is the capital of France?",
      "documents": [
        "The capital of Brazil is Brasilia.",
        "The capital of France is Paris.",
        "Horses and cows are both animals"
      ]
    }'
    ```

??? console "响应"

    ```json
    {
      "id": "rerank-fae51b2b664d4ed38f5969b612edff77",
      "model": "BAAI/bge-reranker-base",
      "usage": {
        "total_tokens": 56
      },
      "results": [
        {
          "index": 1,
          "document": {
            "text": "The capital of France is Paris."
          },
          "relevance_score": 0.99853515625
        },
        {
          "index": 0,
          "document": {
            "text": "The capital of Brazil is Brasilia."
          },
          "relevance_score": 0.0005860328674316406
        }
      ]
    }
    ```

#### 额外参数

支持以下 [池化参数][vllm.PoolingParams]。

```python
--8<-- "vllm/pooling_params.py:common-pooling-params"
--8<-- "vllm/pooling_params.py:classify-pooling-params"
```

支持以下重排序 API 参数：

```python
--8<-- "vllm/entrypoints/pooling/base/protocol.py:pooling-common-params"
--8<-- "vllm/entrypoints/pooling/base/protocol.py:classify-extra-params"
--8<-- "vllm/entrypoints/pooling/score/protocol.py:score-extra-params"
```

支持以下额外参数：

```python
--8<-- "vllm/entrypoints/pooling/base/protocol.py:pooling-common-extra-params"
--8<-- "vllm/entrypoints/pooling/base/protocol.py:classify-extra-params"
--8<-- "vllm/entrypoints/pooling/score/protocol.py:rerank-extra-params"
```

## Ray Serve LLM

Ray Serve LLM 能够实现 vLLM 引擎的可扩展、生产级服务。它与 vLLM 紧密集成，并通过自动扩缩容、负载均衡和背压等特性对其进行扩展。

核心能力：

- 暴露一个 OpenAI 兼容的 HTTP API 以及一个 Pythonic API。
- 无需更改代码即可从单个 GPU 扩展到多节点集群。
- 通过 Ray 仪表板和指标提供可观测性和自动扩缩容策略。

以下示例展示了如何使用 Ray Serve LLM 部署像 DeepSeek R1 这样的大型模型：[examples/online_serving/ray_serve_deepseek.py](../../examples/online_serving/ray_serve_deepseek.py)。

通过官方 [Ray Serve LLM 文档](https://docs.ray.io/en/latest/serve/llm/index.html)了解更多信息。