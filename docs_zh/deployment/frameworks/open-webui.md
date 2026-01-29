# Open WebUI

[Open WebUI](https://github.com/open-webui/open-webui) 是一个可扩展、功能丰富且用户友好的自托管 AI 平台，专为完全离线运行而设计。
它支持多种 LLM 运行器，如 Ollama 和 OpenAI 兼容 API，并具备内置的 RAG 功能，使其成为强大的 AI 部署解决方案。

要使用 vLLM 开始使用 Open WebUI，请按照以下步骤操作：

1. 安装 [Docker](https://docs.docker.com/engine/install/)。

2. 使用支持聊天完成的模型启动 vLLM 服务器：

    ```console
    vllm serve Qwen/Qwen3-0.6B-Chat
    ```

    !!! note
        启动 vLLM 服务器时，请务必使用 `--host` 和 `--port` 标志指定主机和端口。
        例如：

        ```console
        vllm serve <model> --host 0.0.0.0 --port 8000
        ```

3. 启动 Open WebUI Docker 容器：

    ```console
    docker run -d \
        --name open-webui \
        -p 3000:8080 \
        -v open-webui:/app/backend/data \
        -e OPENAI_API_BASE_URL=http://0.0.0.0:8000/v1 \
        --restart always \
        ghcr.io/open-webui/open-webui:main
    ```

4. 在浏览器中打开：<http://open-webui-host:3000/>

    页面顶部您应该能看到模型 `Qwen/Qwen3-0.6B-Chat`。

    ![模型 Qwen/Qwen3-0.6B-Chat 的 Web 门户](../../assets/deployment/open_webui.png)