# LangChain

vLLM 也可以通过 [LangChain](https://github.com/langchain-ai/langchain) 使用。

要安装 LangChain，请运行

```bash
pip install langchain langchain_community -q
```

要在单个或多个 GPU 上运行推理，请使用来自 `langchain` 的 `VLLM` 类。

??? code

    ```python
    from langchain_community.llms import VLLM

    llm = VLLM(
        model="Qwen/Qwen3-4B",
        trust_remote_code=True,  # hf 模型的必需参数
        max_new_tokens=128,
        top_k=10,
        top_p=0.95,
        temperature=0.8,
        # 用于分布式推理
        # tensor_parallel_size=...,
    )

    print(llm("法国的首都是什么？"))
    ```

更多详细信息请参考此 [教程](https://python.langchain.com/docs/integrations/llms/vllm)。