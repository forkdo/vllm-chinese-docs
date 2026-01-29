# Chatbox

[Chatbox](https://github.com/chatboxai/chatbox) 是一个桌面客户端，支持 LLM，可在 Windows、Mac 和 Linux 上使用。

它允许您使用 vLLM 作为后端部署大型语言模型（LLM）服务器，该服务器提供 OpenAI 兼容的端点。

## 先决条件

设置 vLLM 环境：

```bash
pip install vllm
```

## 部署

1. 使用支持聊天完成的模型启动 vLLM 服务器，例如：

    ```bash
    vllm serve qwen/Qwen1.5-0.5B-Chat
    ```

1. 下载并安装 [Chatbox 桌面客户端](https://chatboxai.app/en#download)。

1. 在设置页面左下角，添加自定义提供商：
    - API 模式：`OpenAI API 兼容`
    - 名称：vllm
    - API 主机：`http://{vllm 服务器主机}:{vllm 服务器端口}/v1`
    - API 路径：`/chat/completions`
    - 模型：`qwen/Qwen1.5-0.5B-Chat`

    ![Chatbox 设置界面](../../assets/deployment/chatbox-settings.png)

1. 进入 `Just chat`，开始聊天：

    ![聊天机器人聊天界面](../../assets/deployment/chatbox-chat.png)