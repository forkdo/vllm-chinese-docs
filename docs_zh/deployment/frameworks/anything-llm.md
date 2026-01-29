# AnythingLLM

[AnythingLLM](https://github.com/Mintplex-Labs/anything-llm) 是一个全栈应用程序，可让您将任何文档、资源或内容转换为上下文，以供任何 LLM 在聊天过程中作为参考使用。

它允许您部署一个以 vLLM 作为后端的大语言模型（LLM）服务器，该服务器提供 OpenAI 兼容的端点。

## 先决条件

设置 vLLM 环境：

```bash
pip install vllm
```

## 部署

1. 启动支持聊天完成的 vLLM 服务器，例如：

    ```bash
    vllm serve Qwen/Qwen1.5-32B-Chat-AWQ --max-model-len 4096
    ```

1. 下载并安装 [AnythingLLM Desktop](https://anythingllm.com/desktop)。

1. 配置 AI 提供商：

    - 在底部点击 🔧 扳手图标 -> **打开设置** -> **AI 提供商** -> **LLM**。
    - 输入以下值：
        - LLM 提供商：Generic OpenAI
        - 基础 URL：`http://{vllm 服务器主机}:{vllm 服务器端口}/v1`
        - 聊天模型名称：`Qwen/Qwen1.5-32B-Chat-AWQ`

    ![设置 AI 提供商](../../assets/deployment/anything-llm-provider.png)

1. 创建一个工作区：

    1. 在底部点击 ↺ 返回图标，返回工作区列表。
    1. 创建一个工作区（例如 `vllm`），然后开始聊天。

    ![创建工作区](../../assets/deployment/anything-llm-chat-without-doc.png)

1. 添加文档：

    1. 点击 📎 附件图标。
    1. 上传文档。
    1. 选择并把文档移动到您的工作区。
    1. 保存并嵌入文档。

    ![添加文档](../../assets/deployment/anything-llm-upload-doc.png)

1. 使用文档作为上下文进行聊天。

    ![使用上下文聊天](../../assets/deployment/anything-llm-chat-with-doc.png)