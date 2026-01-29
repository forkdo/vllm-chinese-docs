| 指标名称 | 类型 | 描述 |
|-------------|------|-------------|
| `vllm:corrupted_requests` | 计数器 | 损坏的请求数量，以 logits 中出现 NaN 的请求总数计算。 |
| `vllm:external_prefix_cache_hits` | 计数器 | 来自 KV 连接器跨实例缓存共享的外部前缀缓存命中数，以缓存的 token 数量计算。 |
| `vllm:external_prefix_cache_queries` | 计数器 | 来自 KV 连接器跨实例缓存共享的外部前缀缓存查询数，以查询的 token 数量计算。 |
| `vllm:generation_tokens` | 计数器 | 已处理的生成 token 数量。 |
| `vllm:mm_cache_hits` | 计数器 | 多模态缓存命中数，以缓存的项目数量计算。 |
| `vllm:mm_cache_queries` | 计数器 | 多模态缓存查询数，以查询的项目数量计算。 |
| `vllm:num_preemptions` | 计数器 | 引擎累计抢占次数。 |
| `vllm:prefix_cache_hits` | 计数器 | 前缀缓存命中数，以缓存的 token 数量计算。 |
| `vllm:prefix_cache_queries` | 计数器 | 前缀缓存查询数，以查询的 token 数量计算。 |
| `vllm:prompt_tokens` | 计数器 | 已处理的预填充 token 数量。 |
| `vllm:request_success` | 计数器 | 成功处理的请求数量。 |
| `vllm:engine_sleep_state` | 仪表盘 | 引擎睡眠状态；awake = 0 表示引擎处于睡眠状态；awake = 1 表示引擎处于唤醒状态；weights_offloaded = 1 表示睡眠级别 1；discard_all = 1 表示睡眠级别 2。 |
| `vllm:kv_cache_usage_perc` | 仪表盘 | KV 缓存使用率。1 表示 100% 使用率。 |
| `vllm:lora_requests_info` | 仪表盘 | 关于 LoRA 请求的运行统计信息。 |
| `vllm:num_requests_running` | 仪表盘 | 模型执行批次中的请求数量。 |
| `vllm:num_requests_waiting` | 仪表盘 | 等待处理的请求数量。 |
| `vllm:e2e_request_latency_seconds` | 直方图 | 端到端请求延迟（秒）的直方图。 |
| `vllm:inter_token_latency_seconds` | 直方图 | 令牌间延迟（秒）的直方图。 |
| `vllm:iteration_tokens_total` | 直方图 | 每次引擎步骤处理的 token 数量的直方图。 |
| `vllm:kv_block_idle_before_evict_seconds` | 直方图 | KV 缓存块在被逐出前的空闲时间（秒）的直方图。采样指标（由 --kv-cache-metrics-sample 控制）。 |
| `vllm:kv_block_lifetime_seconds` | 直方图 | KV 缓存块从分配到被逐出的生命周期（秒）的直方图。采样指标（由 --kv-cache-metrics-sample 控制）。 |
| `vllm:kv_block_reuse_gap_seconds` | 直方图 | 连续 KV 缓存块访问之间的时间间隔（秒）的直方图。仅记录最近访问（环形缓冲区）。采样指标（由 --kv-cache-metrics-sample 控制）。 |
| `vllm:request_decode_time_seconds` | 直方图 | 请求在 DECODE 阶段所花费时间的直方图。 |
| `vllm:request_generation_tokens` | 直方图 | 已处理的生成 token 数量。 |
| `vllm:request_inference_time_seconds` | 直方图 | 请求在 RUNNING 阶段所花费时间的直方图。 |
| `vllm:request_max_num_generation_tokens` | 直方图 | 请求的最大生成 token 数量的直方图。 |
| `vllm:request_params_max_tokens` | 直方图 | max_tokens 请求参数的直方图。 |
| `vllm:request_params_n` | 直方图 | n 请求参数的直方图。 |
| `vllm:request_prefill_kv_computed_tokens` | 直方图 | 预填充期间计算的新 KV token 数量的直方图（不包括缓存的 token）。 |
| `vllm:request_prefill_time_seconds` | 直方图 | 请求在 PREFILL 阶段所花费时间的直方图。 |
| `vllm:request_prompt_tokens` | 直方图 | 已处理的预填充 token 数量。 |
| `vllm:request_queue_time_seconds` | 直方图 | 请求在 WAITING 阶段所花费时间的直方图。 |
| `vllm:request_time_per_output_token_seconds` | 直方图 | 每个请求的 time_per_output_token_seconds 的直方图。 |
| `vllm:time_to_first_token_seconds` | 直方图 | 生成第一个 token 所需时间（秒）的直方图。 |