# 指标

vLLM 提供了一组丰富的指标，用于支持 V1 引擎的可观测性和容量规划。

## 目标

- 提供全面的引擎级和请求级指标覆盖，以辅助生产环境监控。
- 优先支持 Prometheus 集成，因为这是我们预期在生产环境中使用的方案。
- 提供日志支持（即将指标打印到 info 日志），用于临时测试、调试、开发和探索性用例。

## 背景

vLLM 中的指标可以分类如下：

1. **服务器级指标**：跟踪 LLM 引擎状态和性能的全局指标。这些指标通常在 Prometheus 中暴露为 Gauge（测量值）或 Counter（计数器）。
2. **请求级指标**：跟踪单个请求特征（例如大小和时序）的指标。这些指标通常在 Prometheus 中暴露为 Histogram（直方图），并且通常是 SRE 监控 vLLM 时所关注的 SLO（服务等级目标）。

其思维模型是：服务器级指标有助于解释请求级指标的值。

### 指标概览

### V1 指标

在 V1 中，通过 Prometheus 兼容的 `/metrics` 端点暴露了大量指标，使用 `vllm:` 前缀，例如：

- `vllm:num_requests_running`（Gauge）- 当前正在运行的请求数。
- `vllm:kv_cache_usage_perc`（Gauge）- 已使用的 KV 缓存块比例（0–1）。
- `vllm:prefix_cache_queries`（Counter）- 前缀缓存查询次数。
- `vllm:prefix_cache_hits`（Counter）- 前缀缓存命中次数。
- `vllm:prompt_tokens_total`（Counter）- 已处理的提示 token 总数。
- `vllm:generation_tokens_total`（Counter）- 已生成的 token 总数。
- `vllm:request_success_total`（Counter）- 已完成的请求数（按完成原因统计）。
- `vllm:request_prompt_tokens`（Histogram）- 输入提示 token 数量的直方图。
- `vllm:request_generation_tokens`（Histogram）- 生成 token 数量的直方图。
- `vllm:time_to_first_token_seconds`（Histogram）- 首个 token 生成时间（TTFT）。
- `vllm:inter_token_latency_seconds`（Histogram）- token 间延迟。
- `vllm:e2e_request_latency_seconds`（Histogram）- 端到端请求延迟。
- `vllm:request_prefill_time_seconds`（Histogram）- 请求预填充时间。
- `vllm:request_decode_time_seconds`（Histogram）- 请求解码时间。

这些指标在 [推理与部署 -> 生产指标](../usage/metrics.md) 中有详细说明。

### Grafana 仪表板

vLLM 还提供了[一个参考示例](../../examples/online_serving/prometheus_grafana/README.md)，展示如何使用 Prometheus 收集和存储这些指标，并使用 Grafana 仪表板进行可视化。

Grafana 仪表板中暴露的指标子集表明了哪些指标尤为重要：

- `vllm:e2e_request_latency_seconds_bucket` - 以秒为单位的端到端请求延迟。
- `vllm:prompt_tokens` - 提示 token 数量。
- `vllm:generation_tokens` - 生成 token 数量。
- `vllm:inter_token_latency_seconds` - token 间延迟（每输出 token 时间，TPOT），单位为秒。
- `vllm:time_to_first_token_seconds` - 首个 token 生成时间（TTFT），单位为秒。
- `vllm:num_requests_running`（以及 `_swapped` 和 `_waiting`）- 处于 RUNNING、WAITING 和 SWAPPED 状态的请求数。
- `vllm:kv_cache_usage_perc` - vLLM 已使用的缓存块百分比。
- `vllm:request_prompt_tokens` - 请求提示长度。
- `vllm:request_generation_tokens` - 请求生成长度。
- `vllm:request_success` - 按完成原因统计的已完成请求数：生成 EOS token 或达到最大序列长度。
- `vllm:request_queue_time_seconds` - 队列等待时间。
- `vllm:request_prefill_time_seconds` - 请求预填充时间。
- `vllm:request_decode_time_seconds` - 请求解码时间。
- `vllm:request_max_num_generation_tokens` - 序列组中的最大生成 token 数。

有关此处所做选择的有趣且有用的背景信息，请参阅[添加此仪表板的 PR](https://github.com/vllm-project/vllm/pull/2316)。

### Prometheus 客户端库

Prometheus 支持最初是[使用 aioprometheus 库](https://github.com/vllm-project/vllm/pull/1890)添加的，但很快切换到了[prometheus_client](https://github.com/vllm-project/vllm/pull/2730)。相关理由在两个链接的 PR 中均有讨论。

在这些迁移过程中，我们短暂丢失了用于跟踪 HTTP 指标的 `MetricsMiddleware`，但随后使用 prometheus_fastapi_instrumentator 重新引入：

```bash
$ curl http://0.0.0.0:8000/metrics 2>/dev/null  | grep -P '^http_(?!.*(_bucket|_created|_sum)).*'
http_requests_total{handler="/v1/completions",method="POST",status="2xx"} 201.0
http_request_size_bytes_count{handler="/v1/completions"} 201.0
http_response_size_bytes_count{handler="/v1/completions"} 201.0
http_request_duration_highr_seconds_count 201.0
http_request_duration_seconds_count{handler="/v1/completions",method="POST"} 201.0
```

### 多进程模式

历史上，指标是在引擎核心进程中收集的，多进程模式用于在 API 服务器进程中提供这些指标。参见 <https://github.com/vllm-project/vllm/pull/7279>。

最近，指标是在 API 服务器进程中收集的，多进程模式仅在 `--api-server-count > 1` 时使用。参见 <https://github.com/vllm-project/vllm/pull/17546> 以及 [API 服务器横向扩展](../serving/data_parallel_deployment.md#internal-load-balancing) 中的详细说明。

### 内置 Python/进程指标

以下指标默认由 `prometheus_client` 支持，但在使用多进程模式时不会暴露：

- `python_gc_objects_collected_total`
- `python_gc_objects_uncollectable_total`
- `python_gc_collections_total`
- `python_info`
- `process_virtual_memory_bytes`
- `process_resident_memory_bytes`
- `process_start_time_seconds`
- `process_cpu_seconds_total`
- `process_open_fds`
- `process_max_fds`

因此，当 `--api-server-count > 1` 时，这些指标不可用。由于它们不会聚合构成 vLLM 实例的所有进程的统计信息，因此这些指标的相关性值得怀疑。

## 指标设计

[“Even Better Observability”](https://github.com/vllm-project/vllm/issues/3616) 功能中规划了大部分指标设计。例如，参见[详细路线图](https://github.com/vllm-project/vllm/issues/3616#issuecomment-2030858781)。

### 历史 PR

为了帮助理解指标设计的背景，以下是一些添加了原始（现已过时）指标的相关 PR：

- <https://github.com/vllm-project/vllm/pull/1890>
- <https://github.com/vllm-project/vllm/pull/2316>
- <https://github.com/vllm-project/vllm/pull/2730>
- <https://github.com/vllm-project/vllm/pull/4464>
- <https://github.com/vllm-project/vllm/pull/7279>

### 指标实现 PR

作为背景，以下是与指标实现相关的 PR：<https://github.com/vLLM-project/vLLM/issues/10582>：

- <https://github.com/vLLM-project/vLLM/pull/11962>
- <https://github.com/vLLM-project/vLLM/pull/11973>
- <https://github.com/vLLM-project/vLLM/pull/10907>
- <https://github.com/vLLM-project/vLLM/pull/12416>
- <https://github.com/vLLM-project/vLLM/pull/12478>
- <https://github.com/vLLM-project/vLLM/pull/12516>
- <https://github.com/vLLM-project/vLLM/pull/12530>
- <https://github.com/vLLM-project/vLLM/pull/12561>
- <https://github.com/vLLM-project/vLLM/pull/12579>
- <https://github.com/vLLM-project/vLLM/pull/12592>
- <https://github.com/vLLM-project/vLLM/pull/12644>

### 指标收集

在 V1 中，我们希望将计算和开销移出引擎核心进程，以最小化每次前向传播之间的时间。

V1 EngineCore 设计的总体思路是：

- EngineCore 是内层循环，此处性能最为关键。
- AsyncLLM 是外层循环，理想情况下与 GPU 执行重叠，因此任何“开销”都应尽可能放在这里。因此，AsyncLLM.output_handler_loop 是进行指标记账的理想位置（如果可能的话）。

我们将通过在前端 API 服务器中收集指标来实现这一目标，这些指标基于我们从引擎核心进程返回给前端的 `EngineCoreOutputs` 中获取的信息。

### 时间间隔计算

我们的许多指标都是请求处理过程中各种事件之间的时间间隔。最佳实践是使用基于“单调时间”（`time.monotonic()`）的时间戳，而不是“挂钟时间”（`time.time()`）来计算间隔，因为前者不受系统时钟变化（例如来自 NTP）的影响。

还需要注意的是，不同进程的单调时钟是不同的——每个进程都有自己的参考点。因此，比较来自不同进程的单调时间戳是没有意义的。

因此，为了计算一个时间间隔，我们必须比较来自同一进程的两个单调时间戳。

### 调度器统计信息

引擎核心进程将从调度器收集一些关键统计数据，例如自上次调度器运行以来已调度或等待的请求数量，并将这些统计数据包含在 `EngineCoreOutputs` 中。

### 引擎核心事件

引擎核心还将记录某些每个请求的事件的时间戳，以便前端可以计算这些事件之间的间隔。

这些事件包括：

- `QUEUED` - 当请求被引擎核心接收并添加到调度器队列时。
- `SCHEDULED` - 当请求首次被调度执行时。
- `PREEMPTED` - 请求已被放回等待队列，以便为其他请求完成腾出空间。它将在未来被重新调度，并重新开始其预填充阶段。
- `NEW_TOKENS` - 当 `EngineCoreOutput` 中包含的输出被生成时。由于这在给定迭代中的所有请求中是通用的，我们在 `EngineCoreOutputs` 上使用单个时间戳来记录此事件。

而计算出的间隔包括：

- 队列间隔 - `QUEUED` 和最近一次 `SCHEDULED` 之间的时间。
- 预填充间隔 - 最近一次 `SCHEDULED` 和随后的第一个 `NEW_TOKENS` 之间的时间。
- 解码间隔 - 第一个（在最近一次 `SCHEDULED` 之后）和最后一个 `NEW_TOKENS` 之间的时间。
- 推理间隔 - 最近一次 `SCHEDULED` 和最后一个 `NEW_TOKENS` 之间的时间。
- 令牌间间隔 - 连续的 `NEW_TOKENS` 之间的时间。

换句话说：

![Interval calculations - common case](../assets/design/metrics/intervals-1.png)

我们探索了让前端使用前端可见事件的时间来计算这些间隔的可能性。然而，前端无法看到 `QUEUED` 和 `SCHEDULED` 事件的时间，而且由于我们需要基于来自同一进程的单调时间戳来计算间隔……我们需要引擎核心记录所有这些事件的时间戳。

#### 时间间隔计算与抢占

当在解码期间发生抢占时，由于任何已生成的令牌都会被重用，我们认为抢占会影响令牌间、解码和推理间隔。

![Interval calculations - preempted decode](../assets/design/metrics/intervals-2.png)

当在预填充期间发生抢占时（假设此类事件是可能的），我们认为抢占会影响首个令牌时间和预填充间隔。

![Interval calculations - preempted prefill](../assets/design/metrics/intervals-3.png)

### 前端统计信息收集

当前端处理单个 `EngineCoreOutputs` 时，即单个引擎核心迭代的输出，它会收集与该迭代相关的各种统计数据：

- 此迭代中生成的新令牌总数。
- 此迭代中完成的预填充所处理的提示令牌总数。
- 此迭代中调度的任何请求的队列间隔。
- 此迭代中完成预填充的任何请求的预填充间隔。
- 此迭代中包含的所有请求的令牌间间隔（每个输出令牌的时间，TPOT）。
- 此迭代中完成预填充的任何请求的首个令牌时间（TTFT）。然而，我们计算此间隔是相对于请求首次被前端接收时（`arrival_time`）的，以考虑输入处理时间。

对于在给定迭代中完成的任何请求，我们还会记录：

- 推理和解码间隔 - 相对于调度和首个令牌事件，如上所述。
- 端到端延迟 - 前端 `arrival_time` 和前端接收最终令牌之间的间隔。

### KV 缓存驻留指标

我们还会发布一组直方图，描述采样的 KV 缓存块驻留多长时间以及它们被重用的频率。采样（`--kv-cache-metrics-sample`）使开销非常小；当一个块被选中时，我们会记录：

- `lifetime` – 分配 ⟶ 驱逐
- `idle before eviction` – 最后一次访问 ⟶ 驱逐
- `reuse gaps` – 块被重用时访问之间的暂停

这些直接映射到 Prometheus 指标：

- `vllm:kv_block_lifetime_seconds` – 每个采样的块存在多长时间。
- `vllm:kv_block_idle_before_evict_seconds` – 最终访问后的空闲尾部。
- `vllm:kv_block_reuse_gap_seconds` – 连续访问之间的时间。

引擎核心仅通过 `SchedulerStats` 发送原始驱逐事件；前端会处理这些事件，将其转换为 Prometheus 观测值，并在日志记录开启时通过 `LLM.get_metrics()` 暴露相同的数据。在一个图表中查看生命周期和空闲时间可以很容易地发现 stranded cache 或长时间固定提示进行解码的工作负载。

### 指标发布 - 日志记录

`LoggingStatLogger` 指标发布器每 5 秒输出一条包含一些关键指标的日志 `INFO` 消息：

- 当前正在运行/等待的请求数量
- 当前 GPU 缓存使用情况
- 过去 5 秒内每秒处理的提示令牌数量
- 过去 5 秒内每秒生成的新令牌数量
- 最近 1k 个 kv-cache 块查询的前缀缓存命中率

### 指标发布 - Prometheus

`PrometheusStatLogger` 指标发布器以 Prometheus 兼容的格式通过 `/metrics` HTTP 端点提供指标。然后可以配置 Prometheus 实例来轮询此端点（例如每秒一次），并将其值记录在其时间序列数据库中。Prometheus 通常通过 Grafana 使用，允许这些指标随时间进行图形化展示。

Prometheus 支持以下指标类型：

- 计数器（Counter）：一个随时间增加而从不减少的值，通常在 vLLM 实例重启时重置为零。例如，实例生命周期内生成的令牌数量。
- 仪表盘（Gauge）：一个上下波动的值，例如当前被调度执行的请求数量。
- 直方图（Histogram）：按桶记录的指标样本计数。例如，TTFT 小于 1ms、5ms、10ms、20ms 等的请求数量。

Prometheus 指标也可以被标记，允许根据匹配的标签组合指标。在 vLLM 中，我们为每个指标添加一个 `model_name` 标签，其中包含该实例服务的模型名称。

示例输出：

```bash
$ curl http://0.0.0.0:8000/metrics
# HELP vllm:num_requests_running 模型执行批处理中的请求数量。
# TYPE vllm:num_requests_running gauge
vllm:num_requests_running{model_name="meta-llama/Llama-3.1-8B-Instruct"} 8.0
...
# HELP vllm:generation_tokens_total 已处理的生成令牌总数。
# TYPE vllm:generation_tokens_total counter
vllm:generation_tokens_total{model_name="meta-llama/Llama-3.1-8B-Instruct"} 27453.0
...
# HELP vllm:request_success_total 成功处理的请求计数。
# TYPE vllm:request_success_total counter
vllm:request_success_total{finished_reason="stop",model_name="meta-llama/Llama-3.1-8B-Instruct"} 1.0
vllm:request_success_total{finished_reason="length",model_name="meta-llama/Llama-3.1-8B-Instruct"} 131.0
vllm:request_success_total{finished_reason="abort",model_name="meta-llama/Llama-3.1-8B-Instruct"} 0.0
...
# HELP vllm:time_to_first_token_seconds 首次生成令牌所需时间的直方图（秒）。
# TYPE vllm:time_to_first_token_seconds histogram
vllm:time_to_first_token_seconds_bucket{le="0.001",model_name="meta-llama/Llama-3.1-8B-Instruct"} 0.0
vllm:time_to_first_token_seconds_bucket{le="0.005",model_name="meta-llama/Llama-3.1-8B-Instruct"} 0.0
vllm:time_to_first_token_seconds_bucket{le="0.01",model_name="meta-llama/Llama-3.1-8B-Instruct"} 0.0
vllm:time_to_first_token_seconds_bucket{le="0.02",model_name="meta-llama/Llama-3.1-8B-Instruct"} 13.0
vllm:time_to_first_token_seconds_bucket{le="0.04",model_name="meta-llama/Llama-3.1-8B-Instruct"} 97.0
vllm:time_to_first_token_seconds_bucket{le="0.06",model_name="meta-llama/Llama-3.1-8B-Instruct"} 123.0
vllm:time_to_first_token_seconds_bucket{le="0.08",model_name="meta-llama/Llama-3.1-8B-Instruct"} 138.0
vllm:time_to_first_token_seconds_bucket{le="0.1",model_name="meta-llama/Llama-3.1-8B-Instruct"} 140.0
vllm:time_to_first_token_seconds_count{model_name="meta-llama/Llama-3.1-8B-Instruct"} 140.0
```

!!! note
    选择对用户最有用的直方图桶并不简单，需要在实践中不断优化。

### 缓存配置信息

`prometheus_client` 支持
[Info 指标](https://prometheus.github.io/client_python/instrumenting/info/)，
其功能类似于值永久设置为 1 的 `Gauge`，但通过标签暴露有趣的信息。
这适用于实例启动时观察一次即可的静态信息，并允许在 Prometheus 中跨实例比较。

我们使用这一概念来实现 `vllm:cache_config_info` 指标：

```text
# HELP vllm:cache_config_info LLMEngine CacheConfig 的信息
# TYPE vllm:cache_config_info gauge
vllm:cache_config_info{block_size="16",cache_dtype="auto",calculate_kv_scales="False",cpu_offload_gb="0",enable_prefix_caching="False",gpu_memory_utilization="0.9",...} 1.0
```

然而，`prometheus_client` [从未在 multiprocessing 模式下支持 Info 指标](https://github.com/prometheus/client_python/pull/300)，
原因尚不明确。我们简单地使用一个值为 1 的 `Gauge` 指标，并设置 `multiprocess_mode="mostrecent"` 来替代。

### LoRA 指标

`vllm:lora_requests_info` `Gauge` 与此类似，只是其值为当前时间戳，并在每次迭代时更新。

使用的标签名称包括：

- `running_lora_adapters`：每个适配器正在运行的请求数量，格式为逗号分隔的字符串。
- `waiting_lora_adapters`：类似，但统计的是等待调度的请求。
- `max_lora`：静态的"单个批次中最大 LoRA 数量"配置。

将多个适配器的运行/等待计数编码为逗号分隔的字符串似乎并不合理，我们应该使用标签来区分每个适配器的计数。这一点值得重新审视。

注意，这里使用了 `multiprocess_mode="livemostrecent"`，即只使用当前运行进程中的最新指标。

该指标在 <https://github.com/vllm-project/vllm/pull/9477> 中添加，并且[至少有一个已知用户](https://github.com/kubernetes-sigs/gateway-api-inference-extension/pull/54)。
如果我们重新设计并弃用旧指标，应与下游用户协调，确保他们在删除前完成迁移。

### 前缀缓存指标

在 <https://github.com/vllm-project/vllm/issues/10582> 中关于添加前缀缓存指标的讨论提出了一些有趣的观点，可能对我们未来设计指标有参考价值。

每次查询前缀缓存时，我们都会记录查询的令牌数量和缓存中存在的查询令牌数量（即命中数）。

然而，我们真正关心的指标是命中率，即每次查询的命中数。

对于日志记录，我们预期用户最适合通过计算最近固定数量查询的命中率（目前固定为最近 1k 次查询）来获取该指标。

但对于 Prometheus，我们应该利用其时间序列特性，允许用户选择计算命中率的区间。例如，使用 PromQL 查询过去 5 分钟的命中率：

```text
rate(cache_query_hit[5m]) / rate(cache_query_total[5m])
```

为实现这一点，我们应该在 Prometheus 中将查询数和命中数记录为计数器，而不是将命中率记录为仪表盘。

## 已弃用的指标

### 如何弃用

弃用指标不应掉以轻心。用户可能不会注意到某个指标已被弃用，当它突然（从用户角度看）被移除时，即使用户有等效的替代指标可用，也可能造成极大不便。

例如，`vllm:avg_prompt_throughput_toks_per_s` 指标经历了[被弃用](https://github.com/vllm-project/vllm/pull/2764)（代码中有注释）、[被移除](https://github.com/vllm-project/vllm/pull/12383)，然后[被用户发现](https://github.com/vllm-project/vllm/issues/13218)的过程。

一般来说：

1. 我们应该谨慎对待指标弃用，尤其是因为很难预测对用户的影响。
2. 我们应该在 `/metrics` 输出中包含的帮助字符串中添加明显的弃用通知。
3. 我们应该在面向用户的文档和发布说明中列出已弃用的指标。
4. 我们应该考虑将已弃用的指标隐藏在 CLI 参数后面，以便管理员在删除前有一段时间可以使用[逃生舱](https://kubernetes.io/docs/concepts/cluster-administration/system-metrics/#show-hidden-metrics)。

有关项目范围的弃用政策，请参阅[弃用政策](../contributing/deprecation_policy.md)。

### 未实现 - `vllm:tokens_total`

由 <https://github.com/vllm-project/vllm/pull/4464> 添加，但显然从未实现。可以直接删除。

### 重复 - 队列时间

`vllm:time_in_queue_requests` 直方图指标由 <https://github.com/vllm-project/vllm/pull/9659> 添加，其计算方式为：

```python
    self.metrics.first_scheduled_time = now
    self.metrics.time_in_queue = now - self.metrics.arrival_time
```

两周后，<https://github.com/vllm-project/vllm/pull/4464> 添加了 `vllm:request_queue_time_seconds`，导致我们现在有：

```python
if seq_group.is_finished():
    if (seq_group.metrics.first_scheduled_time is not None and
            seq_group.metrics.first_token_time is not None):
        time_queue_requests.append(
            seq_group.metrics.first_scheduled_time -
            seq_group.metrics.arrival_time)
    ...
    if seq_group.metrics.time_in_queue is not None:
        time_in_queue_requests.append(
            seq_group.metrics.time_in_queue)
```

这似乎是重复的，应该删除其中一个。后者被 Grafana 仪表盘使用，因此我们应该弃用或删除前者。

### 前缀缓存命中率

如上所述，我们现在暴露的是"查询"和"命中"计数器，而不是"命中率"仪表盘。

### KV 缓存卸载

有两个遗留指标与"交换"抢占模式相关，这在 v1 中已不再适用：

- `vllm:num_requests_swapped`
- `vllm:cpu_cache_usage_perc`

在此模式下，当一个请求被抢占时（例如，为了在 KV 缓存中腾出空间以完成其他请求），我们会将 KV 缓存块交换到 CPU 内存中。这也称为“KV 缓存卸载”，通过 `--swap-space` 和 `--preemption-mode` 配置。

从历史上看，[vLLM 很早就支持束搜索（beam search）](https://github.com/vllm-project/vllm/issues/6226)。SequenceGroup 封装了 N 个序列的概念，这些序列共享相同的提示 KV 块。这使得请求之间可以共享 KV 缓存块，并通过写时复制（copy-on-write）实现分支。CPU 交换最初是为类似束搜索的场景设计的。

后来引入了前缀缓存（prefix caching）的概念，允许隐式共享 KV 缓存块。这被证明是比 CPU 交换更好的方案，因为块可以按需缓慢逐出，并且被逐出的提示部分可以重新计算。

SequenceGroup 在 V1 中被移除，尽管“并行采样”（`n>1`）需要一个替代方案。[束搜索功能已从核心中移出](https://github.com/vllm-project/vllm/issues/8306)。这是一个非常不常用的功能，却伴随着大量复杂代码。

在 V1 中，由于前缀缓存更优（零开销）且默认启用，抢占和重新计算策略应该表现更好。

## 未来工作

### 并行采样

某些传统指标仅在“并行采样”的上下文中相关。这是指请求中的 `n` 参数用于从同一提示生成多个补全。

作为在 <https://github.com/vllm-project/vllm/pull/10980> 中添加并行采样支持的一部分，我们还应添加以下指标：

- `vllm:request_params_n`（直方图）

  观察每个已完成请求的 'n' 参数值。

- `vllm:request_max_num_generation_tokens`（直方图）

  观察每个已完成序列组中所有序列的最大输出长度。在没有并行采样的情况下，这等同于 `vllm:request_generation_tokens`。

### 推测解码

某些传统指标特定于“推测解码”。这是指我们使用更快、近似的方法或模型生成候选 token，然后用更大的模型验证这些 token。

- `vllm:spec_decode_draft_acceptance_rate`（仪表盘）
- `vllm:spec_decode_efficiency`（仪表盘）
- `vllm:spec_decode_num_accepted_tokens`（计数器）
- `vllm:spec_decode_num_draft_tokens`（计数器）
- `vllm:spec_decode_num_emitted_tokens`（计数器）

目前有一个正在审查的 PR（<https://github.com/vllm-project/vllm/pull/12193>），旨在为 V1 添加“提示查找（ngram）”推测解码。其他技术将随后跟进。我们应在此背景下重新审视这些指标。

!!! note
    我们可能应该像处理前缀缓存命中率一样，将接受率暴露为单独的“已接受”和“草案”计数器。效率指标可能也需要类似的处理。

### 自动扩缩容与负载均衡

我们指标的常见用例之一是支持 vLLM 实例的自动扩缩容。

有关来自 [Kubernetes Serving 工作组](https://github.com/kubernetes/community/tree/master/wg-serving) 的相关讨论，请参阅：

- [在 Kubernetes 中标准化大模型服务器指标](https://docs.google.com/document/d/1SpSp1E6moa4HSrJnS4x3NpLuj88sMXr2tbofKlzTZpk)
- [在 Kubernetes 中对 LLM 工作负载进行性能评估和自动扩缩容的基准测试](https://docs.google.com/document/d/1k4Q4X14hW4vftElIuYGDu5KDe2LtV1XammoG-Xi3bbQ)
- [推理性能](https://github.com/kubernetes-sigs/wg-serving/tree/main/proposals/013-inference-perf)
- <https://github.com/vllm-project/vllm/issues/5041> 和 <https://github.com/vllm-project/vllm/pull/12726>。

这是一个非平凡的话题。考虑 Rob 的这条评论：

> 我认为该指标应侧重于尝试估算在平均请求长度 > 每秒查询数的情况下，最大并发量是多少……因为这实际上是会“饱和”服务器的因素。

一个明确的目标是，我们应该暴露检测此饱和点所需的指标，以便管理员可以基于这些指标实施自动扩缩容规则。然而，要做到这一点，我们需要明确管理员（和自动化监控系统）应如何判断一个实例是否接近饱和：

> 如何识别模型服务器计算的饱和点（即无法通过更高请求率获得更高吞吐量，但开始产生额外延迟的拐点），以便我们能够有效自动扩缩容？

### 指标命名

我们的指标命名方法可能值得重新审视：

1. 在指标名称中使用冒号似乎与[“冒号保留给用户定义的记录规则”](https://prometheus.io/docs/concepts/data_model/#metric-names-and-labels)相悖。
2. 我们的大多数指标遵循以单位结尾的约定，但并非全部如此。
3. 我们的一些指标名称以 `_total` 结尾：

    如果指标名称有 `_total` 后缀，它将被移除。在暴露计数器的时间序列时，将添加 `_total` 后缀。这是为了兼容 OpenMetrics 和 Prometheus 文本格式，因为 OpenMetrics 要求 `_total` 后缀。

### 添加更多指标

新指标的想法并不缺乏：

- 来自其他项目的示例，如 [TGI](https://github.com/IBM/text-generation-inference?tab=readme-ov-file#metrics)
- 来自特定用例的提案，如上述 Kubernetes 自动扩缩容主题
- 可能来自标准化工作的提案，如 [OpenTelemetry Gen AI 语义约定](https://github.com/open-telemetry/semantic-conventions/tree/main/docs/gen-ai)。

我们在添加新指标时应保持谨慎。虽然指标通常相对容易添加：

1. 它们可能很难移除——参见上文关于弃用的部分。
2. 启用时可能对性能产生有意义的影响。而且，除非指标可以默认在生产环境中启用，否则其用途通常非常有限。
3. 它们对项目的开发和维护有影响。随着时间的推移，每添加一个指标都会使这项工作更加耗时，也许并非所有指标都值得持续投入维护成本。

## 追踪 - OpenTelemetry

指标提供了系统性能和健康状况随时间聚合的视图。而追踪则跟踪单个请求在不同服务和组件中的流转过程。两者都属于更广泛的“可观测性”范畴。

vLLM 支持 OpenTelemetry 追踪：

- 由 <https://github.com/vllm-project/vllm/pull/4687> 添加，并由 <https://github.com/vllm-project/vllm/pull/20372> 恢复
- 通过 `--oltp-traces-endpoint` 和 `--collect-detailed-traces` 配置
- [OpenTelemetry 博客文章](https://opentelemetry.io/blog/2024/llm-observability/)
- [面向用户的文档](../examples/online_serving/opentelemetry.md)
- [博客文章](https://medium.com/@ronen.schaffer/follow-the-trail-supercharging-vllm-with-opentelemetry-distributed-tracing-aa655229b46f)
- [IBM 产品文档](https://www.ibm.com/docs/en/instana-observability/current?topic=mgaa-monitoring-large-language-models-llms-vllm-public-preview)

OpenTelemetry 有一个 [Gen AI 工作组](https://github.com/open-telemetry/community/blob/main/projects/gen-ai.md)。

由于指标本身已经是一个足够大的话题，我们认为追踪的主题与指标相当独立。

### OpenTelemetry 模型前向时间与执行时间

当前实现暴露以下两个指标：

- `vllm:model_forward_time_milliseconds`（直方图）——当此请求在批次中时，模型前向传播所花费的时间。
- `vllm:model_execute_time_milliseconds`（直方图）——模型执行函数所花费的时间。这包括模型前向传播、跨 worker 的块/同步、CPU-GPU 同步时间和采样时间。

这些指标仅在启用 OpenTelemetry 追踪且使用 `--collect-detailed-traces=all/model/worker` 时启用。该选项的文档说明：

> 为指定模块收集详细的跟踪信息。这涉及使用可能代价高昂和/或阻塞的操作，因此可能会对性能产生影响。

这些指标是通过 <https://github.com/vllm-project/vllm/pull/7089> 添加的，并在 OpenTelemetry 跟踪中显示为：

```text
-> gen_ai.latency.time_in_scheduler: Double(0.017550230026245117)
-> gen_ai.latency.time_in_model_forward: Double(3.151565277099609)
-> gen_ai.latency.time_in_model_execute: Double(3.6468167304992676)
```

我们已经有 `inference_time` 和 `decode_time` 指标，因此问题是：是否有足够普遍的用例需要更高精度的计时，从而证明这种开销是合理的。

由于我们将单独讨论 OpenTelemetry 支持的问题，因此我们将把这些特定指标归入该主题下。