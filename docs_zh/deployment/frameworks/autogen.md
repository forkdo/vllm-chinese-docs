# AutoGen [AutoGen](https://github.com/microsoft/autogen) 是一个用于创建多智能体 AI 应用程序的框架，这些应用程序可以自主运行或与人类协同工作。

## 前置条件

设置 vLLM 和 [AutoGen](https://microsoft.github.io/autogen/0.2/docs/installation/) 环境：

```bash
pip install vllm # Install AgentChat and OpenAI client from Extensions
# AutoGen requires Python 3.10 or later.
pip install -U "autogen-agentchat" "autogen-ext[openai]"
```

## 部署

1. 使用支持的对话补全模型启动 vLLM 服务器，例如：

```bash
vllm serve mistralai/Mistral-7B-Instruct-v0.2
```

1. 使用 AutoGen 调用它：??? code

```python
import asyncio
from autogen_core.models import UserMessage
from autogen_ext.models.openai import OpenAIChatCompletionClient
from autogen_core.models import ModelFamily

async def main() -> None:
    # Create a model client
    model_client = OpenAIChatCompletionClient(
        model="mistralai/Mistral-7B-Instruct-v0.2",
        base_url="http://{your-vllm-host-ip}:{your-vllm-host-port}/v1",
        api_key="EMPTY",
        model_info={
            "vision": False,
            "function_calling": False,
            "json_output": False,
            "family": ModelFamily.MISTRAL,
            "structured_output": True,
        },
    )

    messages = [UserMessage(content="Write a very short story about a dragon.", source="user")]

    # Create a stream.
    stream = model_client.create_stream(messages=messages)

    # Iterate over the stream and print the responses.
    print("Streamed responses:")
    async for response in stream:
        if isinstance(response, str):
            # A partial response is a string.
            print(response, flush=True, end="")
        else:
            # The last response is a CreateResult object with the complete message.
            print("\n\n------------\n")
            print("The complete response:", flush=True)
            print(response.content, flush=True)

    # Close the client when done.
    await model_client.close()

asyncio.run(main())
```

有关详细信息，请参阅教程：
- [在 AutoGen 中使用 vLLM](https://microsoft.github.io/autogen/0.2/docs/topics/non-openai-models/local-vllm/)
- [OpenAI 兼容 API 示例](https://microsoft.github.io/autogen/stable/reference/python/autogen_ext.models.openai.html#autogen_ext.models.openai.OpenAIChatCompletionClient)