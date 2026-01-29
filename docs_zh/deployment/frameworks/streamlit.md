# Streamlit

[Streamlit](https://github.com/streamlit/streamlit) 让你可以在几分钟内将 Python 脚本转换为交互式 Web 应用，而不是耗时数周。你可以用它来构建仪表板、生成报告或创建聊天应用。

它可以快速与 vLLM 集成，作为后端 API 服务器，通过 API 调用实现强大的 LLM 推理功能。

## 先决条件

通过安装所有必需的包来设置 vLLM 环境：

```bash
pip install vllm streamlit openai
```

## 部署

1. 使用一个支持的聊天补全模型启动 vLLM 服务器，例如：

    ```bash
    vllm serve Qwen/Qwen1.5-0.5B-Chat
    ```

1. 使用以下脚本：[examples/online_serving/streamlit_openai_chatbot_webserver.py](../../../examples/online_serving/streamlit_openai_chatbot_webserver.py)

1. 启动 Streamlit Web UI 并开始聊天：

    ```bash
    streamlit run streamlit_openai_chatbot_webserver.py

    # 或者指定 VLLM_API_BASE 或 VLLM_API_KEY
    VLLM_API_BASE="http://vllm-server-host:vllm-server-port/v1" \
        streamlit run streamlit_openai_chatbot_webserver.py

    # 以调试模式启动以查看更多详细信息
    streamlit run streamlit_openai_chatbot_webserver.py --logger.level=debug
    ```

    ![在 Streamlit 中与 vLLM 助手聊天](../../assets/deployment/streamlit-chat.png)