# Dify

[Dify](https://github.com/langgenius/dify) 是一个开源的 LLM 应用开发平台。其直观的界面集成了智能体 AI 工作流、RAG 管道、智能体能力、模型管理、可观测性等功能，让您能够快速从原型开发过渡到生产部署。

Dify 支持将 vLLM 作为模型提供商，以高效地提供大型语言模型服务。

本指南将引导您使用 vLLM 后端部署 Dify。

## 先决条件

设置 vLLM 环境：

```bash
pip install vllm
```

并安装 [Docker](https://docs.docker.com/engine/install/) 和 [Docker Compose](https://docs.docker.com/compose/install/)。

## 部署

1. 使用支持的聊天补全模型启动 vLLM 服务器，例如：

    ```bash
    vllm serve Qwen/Qwen1.5-7B-Chat
    ```

1. 使用 docker compose 启动 Dify 服务器（[详情](https://github.com/langgenius/dify?tab=readme-ov-file#quick-start)）：

    ```bash
    git clone https://github.com/langgenius/dify.git
    cd dify
    cd docker
    cp .env.example .env
    docker compose up -d
    ```

1. 打开浏览器访问 `http://localhost/install`，配置基本登录信息并登录。

1. 在右上角用户菜单（位于头像图标下方）中，进入“设置”，然后点击“模型提供商”，找到 `vLLM` 提供商并安装它。

1. 按如下方式填写模型提供商详细信息：

    - **模型类型**：`LLM`
    - **模型名称**：`Qwen/Qwen1.5-7B-Chat`
    - **API 端点 URL**：`http://{vllm_server_host}:{vllm_server_port}/v1`
    - **API 端点的模型名称**：`Qwen/Qwen1.5-7B-Chat`
    - **补全模式**：`Completion`

    ![Dify 设置界面](../../assets/deployment/dify-settings.png)

1. 要创建测试聊天机器人，请进入“工作室 → 聊天机器人 → 从空白创建”，然后选择“聊天机器人”作为类型：

    ![Dify 创建聊天机器人界面](../../assets/deployment/dify-create-chatbot.png)

1. 点击您刚刚创建的聊天机器人以打开聊天界面，并开始与模型交互：

    ![Dify 聊天界面](../../assets/deployment/dify-chat.png)