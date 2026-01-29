# 推理输出

vLLM 支持推理模型，例如 [DeepSeek R1](https://huggingface.co/deepseek-ai/DeepSeek-R1)，这些模型专门用于生成包含推理步骤和最终结论的输出。

推理模型在输出中会返回一个额外的 `reasoning` 字段，其中包含生成最终结论所依据的推理步骤。该字段在其他模型的输出中不存在。

!!! warning
    `reasoning` 之前称为 `reasoning_content`。目前 `reasoning_content` 仍将继续工作。但我们建议您迁移至 `reasoning`，以防将来 `reasoning_content` 被移除。

## 支持的模型

vLLM 当前支持以下推理模型：

| 模型系列 | 解析器名称 | 结构化输出支持 | 工具调用 |
|----------|------------|----------------|----------|
| [DeepSeek R1 系列](https://huggingface.co/collections/deepseek-ai/deepseek-r1-678e1e131c0169c0bc89728d) | `deepseek_r1` | `json`，`regex` | ❌ |
| [DeepSeek-V3.1](https://huggingface.co/collections/deepseek-ai/deepseek-v31-68a491bed32bd77e7fca048f) | `deepseek_v3` | `json`，`regex` | ❌ |
| [ERNIE-4.5-VL 系列](https://huggingface.co/baidu/ERNIE-4.5-VL-28B-A3B-PT) | `ernie45` | `json`，`regex` | ❌ |
| [ERNIE-4.5-21B-A3B-Thinking](https://huggingface.co/baidu/ERNIE-4.5-21B-A3B-Thinking) | `ernie45` | `json`，`regex` | ✅ |
| [GLM-4.5 系列](https://huggingface.co/collections/zai-org/glm-45-687c621d34bda8c9e4bf503b) | `glm45` | `json`，`regex` | ✅ |
| [Holo2 系列](https://huggingface.co/collections/Hcompany/holo2) | `holo2` | `json`，`regex` | ✅ |
| [Hunyuan A13B 系列](https://huggingface.co/collections/tencent/hunyuan-a13b-685ec38e5b46321e3ea7c4be) | `hunyuan_a13b` | `json`，`regex` | ✅ |
| [IBM Granite 3.2 语言模型](https://huggingface.co/collections/ibm-granite/granite-32-language-models-67b3bc8c13508f6d064cff9a) | `granite` | ❌ | ❌ |
| [MiniMax-M2](https://huggingface.co/MiniMaxAI/MiniMax-M2) | `minimax_m2_append_think` | `json`，`regex` | ✅ |
| [Qwen3 系列](https://huggingface.co/collections/Qwen/qwen3-67dd247413f0e2e4f653967f) | `qwen3` | `json`，`regex` | ✅ |
| [QwQ-32B](https://huggingface.co/Qwen/QwQ-32B) | `deepseek_r1` | `json`，`regex` | ✅ |

!!! note
    IBM Granite 3.2 和 DeepSeek-V3.1 的推理功能默认情况下被禁用；要启用它，您还必须在 `chat_template_kwargs` 中传递 `thinking=True`。
    Qwen3 系列的推理功能默认启用。要禁用它，您必须在 `chat_template_kwargs` 中传递 `enable_thinking=False`。
    DeepSeek-V3.1 的工具调用在非推理模式下支持。
    Holo2 的推理功能默认启用。要禁用它，您也必须在 `chat_template_kwargs` 中传递 `thinking=False`。

## 快速入门

要使用推理模型，您需要在向聊天补全端点发起请求时指定 `--reasoning-parser` 标志。`--reasoning-parser` 标志指定用于从模型输出中提取推理内容的推理解析器。

```bash
vllm serve deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B \
    --reasoning-parser deepseek_r1
```

接下来，向模型发起请求，该请求应在响应中返回推理内容。

??? code

    ```python
    from openai import OpenAI

    # 修改 OpenAI 的 API 密钥和 API 基地址以使用 vLLM 的 API 服务器。
    openai_api_key = "EMPTY"
    openai_api_base = "http://localhost:8000/v1"

    client = OpenAI(
        api_key=openai_api_key,
        base_url=openai_api_base,
    )

    models = client.models.list()
    model = models.data[0].id

    # 第一轮
    messages = [{"role": "user", "content": "9.11 and 9.8, which is greater?"}]
    # 对于 granite，添加：`extra_body={"chat_template_kwargs": {"thinking": True}}`
    # 对于 Qwen3 系列，如果您想在推理模式下禁用推理，添加：
    # extra_body={"chat_template_kwargs": {"enable_thinking": False}}
    response = client.chat.completions.create(model=model, messages=messages)

    reasoning = response.choices[0].message.reasoning
    content = response.choices[0].message.content

    print("reasoning:", reasoning)
    print("content:", content)
    ```

`reasoning` 字段包含生成最终结论所依据的推理步骤，而 `content` 字段包含最终结论。

## 流式聊天补全

推理模型也支持流式聊天补全。`reasoning` 字段在 [聊天补全响应块](https://platform.openai.com/docs/api-reference/chat/streaming) 的 `delta` 字段中可用。

??? console "Json"

    ```json
    {
        "id": "chatcmpl-123",
        "object": "chat.completion.chunk",
        "created": 1694268190,
        "model": "deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B",
        "system_fingerprint": "fp_44709d6fcb",
        "choices": [
            {
                "index": 0,
                "delta": {
                    "role": "assistant",
                    "reasoning": "is",
                },
                "logprobs": null,
                "finish_reason": null
            }
        ]
    }
    ```

OpenAI Python 客户端库目前不正式支持流式输出中的 `reasoning` 属性。但客户端支持响应中的额外属性。您可以使用 `hasattr` 检查响应中是否包含 `reasoning` 属性。例如：

??? code

    ```python
    from openai import OpenAI

    # 修改 OpenAI 的 API 密钥和 API 基地址以使用 vLLM 的 API 服务器。
    openai_api_key = "EMPTY"
    openai_api_base = "http://localhost:8000/v1"

    client = OpenAI(
        api_key=openai_api_key,
        base_url=openai_api_base,
    )

    models = client.models.list()
    model = models.data[0].id

    messages = [{"role": "user", "content": "9.11 and 9.8, which is greater?"}]
    # 对于 granite，添加：`extra_body={"chat_template_kwargs": {"thinking": True}}`
    # 对于 Qwen3 系列，如果您想在推理模式下禁用推理，添加：
    # extra_body={"chat_template_kwargs": {"enable_thinking": False}}
    stream = client.chat.completions.create(
        model=model,
        messages=messages,
        stream=True,
    )

    print("client: Start streaming chat completions...")
    printed_reasoning = False
    printed_content = False

    for chunk in stream:
        # 安全地从 delta 中提取 reasoning 和 content，
        # 如果属性不存在或为空字符串则默认为 None
        reasoning = (
            getattr(chunk.choices[0].delta, "reasoning", None) or None
        )
        content = getattr(chunk.choices[0].delta, "content", None) or None

        if reasoning is not None:
            if not printed_reasoning:
                printed_reasoning = True
                print("reasoning:", end="", flush=True)
            print(reasoning, end="", flush=True)
        elif content is not None:
            if not printed_content:
                printed_content = True
                print("\ncontent:", end="", flush=True)
            # 提取并打印内容
            print(content, end="", flush=True)
    ```

在访问 `reasoning` 之前，请记得检查它是否存在于响应中。您可以参考 [示例](https://github.com/vllm-project/vllm/blob/main/examples/online_serving/openai_chat_completion_with_reasoning_streaming.py)。

## 工具调用

当同时启用工具调用和推理解析器时，推理内容也可用。此外，工具调用仅从 `content` 字段解析函数，而不从 `reasoning` 字段解析。

??? code

    ```python
    from openai import OpenAI

    client = OpenAI(base_url="http://localhost:8000/v1", api_key="dummy")
    ```

tools = [
    {
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "获取指定位置的当前天气",
            "parameters": {
                "type": "object",
                "properties": {
                    "location": {"type": "string", "description": "城市和州，例如 'San Francisco, CA'"},
                    "unit": {"type": "string", "enum": ["celsius", "fahrenheit"]},
                },
                "required": ["location", "unit"],
            }
        },
    }
]

response = client.chat.completions.create(
    model=client.models.list().data[0].id,
    messages=[{"role": "user", "content": "旧金山的天气怎么样？"}],
    tools=tools,
    tool_choice="auto",
)

print(response)
tool_call = response.choices[0].message.tool_calls[0].function

print(f"reasoning: {response.choices[0].message.reasoning}")
print(f"调用的函数: {tool_call.name}")
print(f"参数: {tool_call.arguments}")
```

更多示例请参考 [examples/online_serving/openai_chat_completion_tool_calls_with_reasoning.py](../../examples/online_serving/openai_chat_completion_tool_calls_with_reasoning.py)。

## 服务端默认聊天模板参数

您可以使用 `--default-chat-template-kwargs` 命令行参数在服务端级别设置默认的 `chat_template_kwargs`。这对于在不需要客户端在每个请求中指定的情况下，跨所有请求配置推理行为非常有用。

### 默认禁用思考模式

对于默认启用思考模式的模型（如 Qwen3），您可以全局禁用它：

```bash
vllm serve Qwen/Qwen3-8B \
    --reasoning-parser qwen3 \
    --default-chat-template-kwargs '{"enable_thinking": false}'
```

### 默认启用思考模式

对于默认禁用思考模式的模型（如 IBM Granite 3.2 或 DeepSeek-V3.1），您可以全局启用它：

```bash
vllm serve ibm-granite/granite-3.2-2b-instruct \
    --reasoning-parser granite \
    --default-chat-template-kwargs '{"thinking": true}'
```

### 请求级别覆盖

请求级别的 `chat_template_kwargs` 总是优先于服务端默认值。例如，如果服务端启动时使用 `enable_thinking=false`，客户端仍可以为特定请求启用它：

```python
response = client.chat.completions.create(
    model=model,
    messages=messages,
    extra_body={"chat_template_kwargs": {"enable_thinking": True}}  # 覆盖服务端默认值
)
```

## 限制

- 推理内容仅在在线服务的聊天完成端点（`/v1/chat/completions`）中可用。

## 如何支持新的推理模型

您可以添加一个新的 `ReasoningParser`，类似于 [vllm/reasoning/deepseek_r1_reasoning_parser.py](../../vllm/reasoning/deepseek_r1_reasoning_parser.py)。

??? code

    ```python
    # 导入所需的包

    from vllm.reasoning import ReasoningParser, ReasoningParserManager
    from vllm.entrypoints.openai.chat_completion.protocol import ChatCompletionRequest
    from vllm.entrypoints.openai.engine.protocol import DeltaMessage

    # 定义推理解析器并注册到 vllm
    # register_module 中的名称列表可用于
    # --reasoning-parser 参数。
    class ExampleParser(ReasoningParser):
        def __init__(self, tokenizer: TokenizerLike):
            super().__init__(tokenizer)

        def extract_reasoning_streaming(
            self,
            previous_text: str,
            current_text: str,
            delta_text: str,
            previous_token_ids: Sequence[int],
            current_token_ids: Sequence[int],
            delta_token_ids: Sequence[int],
        ) -> DeltaMessage | None:
            """
            应该实现的实例方法，用于从不完整的响应中提取推理内容；
            用于处理推理调用和流式传输。必须是实例方法，因为它需要状态 -
            当前的 token/差异，以及关于之前解析和提取的信息（参见构造函数）
            """

        def extract_reasoning(
            self,
            model_output: str,
            request: ChatCompletionRequest | ResponsesRequest,
        ) -> tuple[str | None, str | None]:
            """
            从完整的模型生成字符串中提取推理内容。

            用于非流式响应，此时在发送给客户端之前我们拥有整个模型响应。

            参数：
            model_output: str
                要从中提取推理内容的模型生成字符串。

            request: ChatCompletionRequest
                用于生成 model_output 的请求对象。

            返回：
            tuple[Optional[str], Optional[str]]
                包含推理内容和内容的元组。
            """
    # 注册推理解析器
    ReasoningParserManager.register_lazy_module(
        name="example",
        module_path="vllm.reasoning.example_reasoning_parser",
        class_name="ExampleParser",
    )
    ```

此外，为了启用结构化输出，您需要创建一个新的 `Reasoner`，类似于 [vllm/reasoning/deepseek_r1_reasoning_parser.py](../../vllm/reasoning/deepseek_r1_reasoning_parser.py) 中的。

??? code

    ```python
    @dataclass
    class DeepSeekReasoner(Reasoner):
        """
        DeepSeek R 系列模型的推理器。
        """
        start_token_id: int
        end_token_id: int

        start_token: str = "<tool_call>"
        end_token: str = "</tool_call>"

        @classmethod
        def from_tokenizer(cls, tokenizer: PreTrainedTokenizer) -> Reasoner:
            return cls(
                start_token_id=tokenizer.encode("<tool_call>", add_special_tokens=False)[0],
                end_token_id=tokenizer.encode("</tool_call>", add_special_tokens=False)[0],
            )

        def is_reasoning_end(self, input_ids: list[int]) -> bool:
            return self.end_token_id in input_ids

        def is_reasoning_end_streaming(self, input_ids: list[int], delta_ids: list[int]) -> bool:
            return self.end_token_id in delta_ids
        ...
    ```

结构化输出引擎如 [xgrammar](https://github.com/mlc-ai/xgrammar) 将使用 `end_token_id` 来检查推理内容是否存在于模型输出中，如果存在则跳过结构化输出。

最后，您可以使用 `--reasoning-parser` 标志为模型启用推理。

```bash
vllm serve <model_tag> --reasoning-parser example
```