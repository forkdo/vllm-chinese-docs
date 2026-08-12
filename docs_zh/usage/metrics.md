# 生产环境指标

vLLM 暴露了一系列可用于监控系统健康状况的指标。这些指标通过 vLLM 的 OpenAI 兼容 API 服务器上的 `/metrics` 端点提供。

你可以使用 Python 启动服务器，或使用 [Docker](../deployment/docker.md)：

```bash
vllm serve unsloth/Llama-3.2-1B-Instruct
```

然后查询该端点以获取服务器的最新指标：

??? console "输出"

    ```console
    $ curl http://0.0.0.0:8000/metrics

    # HELP vllm:iteration_tokens_total 每个 engine_step 中 token 数量的直方图。
    # TYPE vllm:iteration_tokens_total histogram
    vllm:iteration_tokens_total_sum{model_name="unsloth/Llama-3.2-1B-Instruct"} 0.0
    vllm:iteration_tokens_total_bucket{le="1.0",model_name="unsloth/Llama-3.2-1B-Instruct"} 3.0
    vllm:iteration_tokens_total_bucket{le="8.0",model_name="unsloth/Llama-3.2-1B-Instruct"} 3.0
    vllm:iteration_tokens_total_bucket{le="16.0",model_name="unsloth/Llama-3.2-1B-Instruct"} 3.0
    vllm:iteration_tokens_total_bucket{le="32.0",model_name="unsloth/Llama-3.2-1B-Instruct"} 3.0
    vllm:iteration_tokens_total_bucket{le="64.0",model_name="unsloth/Llama-3.2-1B-Instruct"} 3.0
    vllm:iteration_tokens_total_bucket{le="128.0",model_name="unsloth/Llama-3.2-1B-Instruct"} 3.0
    vllm:iteration_tokens_total_bucket{le="256.0",model_name="unsloth/Llama-3.2-1B-Instruct"} 3.0
    vllm:iteration_tokens_total_bucket{le="512.0",model_name="unsloth/Llama-3.2-1B-Instruct"} 3.0
    ...
    ```

以下指标被暴露：

## 通用指标

--8<-- "gen:metrics-general"

## 推测解码指标

--8<-- "gen:metrics-spec-decode"

## NIXL KV 连接器指标

--8<-- "gen:metrics-nixl"

## 模型 FLOPs 利用率（MFU）指标

--8<-- "gen:metrics-mfu"

## 废弃策略

注意：当某个指标在版本 `X.Y` 中被废弃时，它在版本 `X.Y+1` 中将被隐藏，但可通过 `--show-hidden-metrics-for-version=X.Y` 这一临时选项重新启用，然后在版本 `X.Y+2` 中被移除。