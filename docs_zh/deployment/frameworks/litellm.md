# LiteLLM

[LiteLLM](https://github.com/BerriAI/litellm) 使用 OpenAI 格式调用所有 LLM API [Bedrock、Huggingface、VertexAI、TogetherAI、Azure、OpenAI、Groq 等]

LiteLLM 负责管理：

- 将输入转换为提供商的 `completion`、`embedding` 和 `image_generation` 端点
- [一致的输出](https://docs.litellm.ai/docs/completion/output)，文本响应始终位于 `['choices'][0]['message']['content']`
- 跨多个部署的重试/回退逻辑（例如 Azure/OpenAI）- [路由器](https://docs.litellm.ai/docs/routing)
- 按项目、API 密钥、模型设置预算和速率限制 [LiteLLM 代理服务器（LLM 网关）](https://docs.litellm.ai/docs/simple_proxy)

LiteLLM 支持 VLLM 上的所有模型。

## 先决条件

设置 vLLM 和 litellm 环境：

```bash
pip install vllm litellm
```

## 部署

### 聊天补全

1. 使用支持的聊天补全模型启动 vLLM 服务器，例如：

    ```bash
    vllm serve qwen/Qwen1.5-0.5B-Chat
    ```

1. 使用 litellm 调用：

??? code

    ```python
    import litellm 

    messages = [{"content": "Hello, how are you?", "role": "user"}]

    # hosted_vllm 是前缀关键词，必需
    response = litellm.completion(
        model="hosted_vllm/qwen/Qwen1.5-0.5B-Chat", # 传递 vllm 模型名称
        messages=messages,
        api_base="http://{your-vllm-server-host}:{your-vllm-server-port}/v1",
        temperature=0.2,
        max_tokens=80,
    )

    print(response)
    ```

### 嵌入

1. 使用支持的嵌入模型启动 vLLM 服务器，例如：

    ```bash
    vllm serve BAAI/bge-base-en-v1.5
    ```

1. 使用 litellm 调用：

```python
from litellm import embedding   
import os

os.environ["HOSTED_VLLM_API_BASE"] = "http://{your-vllm-server-host}:{your-vllm-server-port}/v1"

# hosted_vllm 是前缀关键词，必需
# 传递 vllm 模型名称
embedding = embedding(model="hosted_vllm/BAAI/bge-base-en-v1.5", input=["Hello world"])

print(embedding)
```

详细信息，请参阅教程 [在 LiteLLM 中使用 vLLM](https://docs.litellm.ai/docs/providers/vllm)。