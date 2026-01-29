# 离线推理

您可以在自己的代码中使用 vLLM 的 [`LLM`][vllm.LLM] 类进行离线推理。

例如，以下代码会从 HuggingFace 下载 [`facebook/opt-125m`](https://huggingface.co/facebook/opt-125m) 模型，并使用默认配置在 vLLM 中运行它。

```python
from vllm import LLM

# 初始化 vLLM 引擎。
llm = LLM(model="facebook/opt-125m")
```

初始化 `LLM` 实例后，您可以使用可用的 API 执行模型推理。可用的 API 取决于模型类型：

- [生成模型](../models/generative_models.md) 输出 logprobs，从中采样以获得最终输出文本。
- [池化模型](../models/pooling_models.md) 直接输出其隐藏状态。

!!! info
    [API 参考](../api/README.md#offline-inference)

## Ray Data LLM API

Ray Data LLM 是一个替代的离线推理 API，它使用 vLLM 作为底层引擎。此 API 增加了多项内置功能，简化了大规模、GPU 高效的推理：

- 流式执行处理超过集群总内存的数据集。
- 自动分片、负载均衡和自动扩缩容，可在 Ray 集群中分配工作，并内置容错能力。
- 连续批处理保持 vLLM 副本饱和，最大化 GPU 利用率。
- 对张量并行和流水线并行的透明支持，实现高效的多 GPU 推理。
- 读取和写入大多数流行的文件格式和云对象存储。
- 无需更改代码即可扩展工作负载。

??? code

    ```python
    import ray  # 需要 ray>=2.44.1
    from ray.data.llm import vLLMEngineProcessorConfig, build_llm_processor

    config = vLLMEngineProcessorConfig(model_source="unsloth/Llama-3.2-1B-Instruct")
    processor = build_llm_processor(
        config,
        preprocess=lambda row: {
            "messages": [
                {"role": "system", "content": "你是一个完成未完成俳句的机器人。"},
                {"role": "user", "content": row["item"]},
            ],
            "sampling_params": {"temperature": 0.3, "max_tokens": 250},
        },
        postprocess=lambda row: {"answer": row["generated_text"]},
    )

    ds = ray.data.from_items(["An old silent pond..."])
    ds = processor(ds)
    ds.write_parquet("local:///tmp/data/")
    ```

有关 Ray Data LLM API 的更多信息，请参阅 [Ray Data LLM 文档](https://docs.ray.io/en/latest/data/working-with-llms.html)。