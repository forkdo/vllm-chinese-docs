# 使用 Run:ai Model Streamer 加载模型

Run:ai Model Streamer 是一个用于并发读取张量并将其流式传输到 GPU 内存的库。
更多相关信息请查阅 [Run:ai Model Streamer 文档](https://github.com/run-ai/runai-model-streamer/blob/master/docs/README.md)。

vLLM 支持使用 Run:ai Model Streamer 加载 Safetensors 格式的权重。
首先需要安装 vLLM 的 RunAI 可选依赖：

```bash
pip3 install vllm[runai]
```

要将其作为 OpenAI 兼容服务器运行，请添加 `--load-format runai_streamer` 标志：

```bash
vllm serve /home/meta-llama/Llama-3.2-3B-Instruct \
    --load-format runai_streamer
```

要从 AWS S3 对象存储运行模型，请执行：

```bash
vllm serve s3://core-llm/Llama-3-8b \
    --load-format runai_streamer
```

要从 Google Cloud Storage 运行模型，请执行：

```bash
vllm serve gs://core-llm/Llama-3-8b \
    --load-format runai_streamer
```

要从兼容 S3 的对象存储运行模型，请执行：

```bash
RUNAI_STREAMER_S3_USE_VIRTUAL_ADDRESSING=0 \
AWS_EC2_METADATA_DISABLED=true \
AWS_ENDPOINT_URL=https://storage.googleapis.com \
vllm serve s3://core-llm/Llama-3-8b \
    --load-format runai_streamer
```

## 可调参数

您可以使用 `--model-loader-extra-config` 调整参数：

您可以调整 `distributed` 参数来控制是否使用分布式流式传输。目前仅在 CUDA 和 ROCM 设备上支持此功能。对于从对象存储或高吞吐量网络文件共享加载模型，这可以显著缩短加载时间。
关于分布式流式传输的更多信息，请[点击此处](https://github.com/run-ai/runai-model-streamer/blob/master/docs/src/usage.md#distributed-streaming)。

```bash
vllm serve /home/meta-llama/Llama-3.2-3B-Instruct \
    --load-format runai_streamer \
    --model-loader-extra-config '{"distributed":true}'
```

您可以调整 `concurrency` 参数来控制并发级别以及从文件读取张量到 CPU 缓冲区的操作系统线程数量。
对于从 S3 读取，这表示主机向 S3 服务器打开的客户端实例数量。

```bash
vllm serve /home/meta-llama/Llama-3.2-3B-Instruct \
    --load-format runai_streamer \
    --model-loader-extra-config '{"concurrency":16}'
```

您可以控制从文件读取张量的 CPU 内存缓冲区大小，并限制此大小。
关于 CPU 缓冲区内存限制的更多信息，请[点击此处](https://github.com/run-ai/runai-model-streamer/blob/master/docs/src/env-vars.md#runai_streamer_memory_limit)。

```bash
vllm serve /home/meta-llama/Llama-3.2-3B-Instruct \
    --load-format runai_streamer \
    --model-loader-extra-config '{"memory_limit":5368709120}'
```

!!! note
    关于可调参数以及通过环境变量配置的其他参数的更多说明，请查阅[环境变量文档](https://github.com/run-ai/runai-model-streamer/blob/master/docs/src/env-vars.md)。

## 分片模型加载

vLLM 还支持使用 Run:ai Model Streamer 加载分片模型。这对于分布在多个文件中的大型模型特别有用。要使用此功能，请使用 `--load-format runai_streamer_sharded` 标志：

```bash
vllm serve /path/to/sharded/model --load-format runai_streamer_sharded
```

分片加载器期望模型文件遵循与常规分片状态加载器相同的命名模式：`model-rank-{rank}-part-{part}.safetensors`。您可以使用 `--model-loader-extra-config` 中的 `pattern` 参数自定义此模式：

```bash
vllm serve /path/to/sharded/model \
    --load-format runai_streamer_sharded \
    --model-loader-extra-config '{"pattern":"custom-model-rank-{rank}-part-{part}.safetensors"}'
```

要创建分片模型文件，您可以使用 [examples/offline_inference/save_sharded_state.py](../../../examples/offline_inference/save_sharded_state.py) 中提供的脚本。该脚本演示了如何以与 Run:ai Model Streamer 分片加载器兼容的分片格式保存模型。

分片加载器支持与常规 Run:ai Model Streamer 相同的所有可调参数，包括 `concurrency` 和 `memory_limit`。这些参数可以通过相同的方式配置：

```bash
vllm serve /path/to/sharded/model \
    --load-format runai_streamer_sharded \
    --model-loader-extra-config '{"concurrency":16, "memory_limit":5368709120}'
```

!!! note
    分片加载器对于张量并行或流水线并行模型特别高效，因为每个工作进程只需读取自己的分片，而不是整个检查点。