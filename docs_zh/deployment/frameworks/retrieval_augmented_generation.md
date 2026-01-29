# 检索增强生成

[检索增强生成（Retrieval-augmented generation，简称 RAG）](https://en.wikipedia.org/wiki/Retrieval-augmented_generation) 是一种使生成式人工智能（Gen AI）模型能够检索并整合新信息的技术。该技术通过修改与大语言模型（LLM）的交互方式，使模型在响应用户查询时能够参考指定的文档集合，并利用这些信息补充其预训练数据中的知识。这使得 LLM 能够使用特定领域的信息和/或最新信息。典型用例包括：让聊天机器人访问公司内部数据，或基于权威来源生成回复。

以下是集成方案：

- vLLM + [langchain](https://github.com/langchain-ai/langchain) + [milvus](https://github.com/milvus-io/milvus)
- vLLM + [llamaindex](https://github.com/run-llama/llama_index) + [milvus](https://github.com/milvus-io/milvus)

## vLLM + langchain

### 先决条件

设置 vLLM 和 langchain 环境：

```bash
pip install -U vllm \
            langchain_milvus langchain_openai \
            langchain_community beautifulsoup4 \
            langchain-text-splitters
```

### 部署

1. 使用支持的嵌入模型启动 vLLM 服务，例如：

    ```bash
    # 启动嵌入服务（端口 8000）
    vllm serve ssmits/Qwen2-7B-Instruct-embed-base
    ```

1. 使用支持的聊天补全模型启动 vLLM 服务，例如：

    ```bash
    # 启动聊天服务（端口 8001）
    vllm serve qwen/Qwen1.5-0.5B-Chat --port 8001
    ```

1. 使用脚本：[examples/online_serving/retrieval_augmented_generation_with_langchain.py](../../../examples/online_serving/retrieval_augmented_generation_with_langchain.py)

1. 运行脚本：

    ```bash
    python retrieval_augmented_generation_with_langchain.py
    ```

## vLLM + llamaindex

### 先决条件

设置 vLLM 和 llamaindex 环境：

```bash
pip install vllm \
            llama-index llama-index-readers-web \
            llama-index-llms-openai-like    \
            llama-index-embeddings-openai-like \
            llama-index-vector-stores-milvus
```

### 部署

1. 使用支持的嵌入模型启动 vLLM 服务，例如：

    ```bash
    # 启动嵌入服务（端口 8000）
    vllm serve ssmits/Qwen2-7B-Instruct-embed-base
    ```

1. 使用支持的聊天补全模型启动 vLLM 服务，例如：

    ```bash
    # 启动聊天服务（端口 8001）
    vllm serve qwen/Qwen1.5-0.5B-Chat --port 8001
    ```

1. 使用脚本：[examples/online_serving/retrieval_augmented_generation_with_llamaindex.py](../../../examples/online_serving/retrieval_augmented_generation_with_llamaindex.py)

1. 运行脚本：

    ```bash
    python retrieval_augmented_generation_with_llamaindex.py
    ```