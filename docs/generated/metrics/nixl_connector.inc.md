| 指标名称 | 类型 | 描述 |
|---------|------|------|
| `vllm:nixl_num_failed_notifications` | Counter | NIXL KV 缓存通知失败的次数。 |
| `vllm:nixl_num_failed_transfers` | Counter | NIXL KV 缓存传输失败的次数。 |
| `vllm:nixl_num_kv_expired_reqs` | Counter | KV 缓存过期的请求数量。注意：此指标在 P 实例上进行统计。 |
| `vllm:nixl_bytes_transferred` | Histogram | 每次 NIXL KV 缓存传输所传输字节数的直方图。 |
| `vllm:nixl_num_descriptors` | Histogram | 每次 NIXL KV 缓存传输中描述符数量的直方图。 |
| `vllm:nixl_post_time_seconds` | Histogram | NIXL KV 缓存传输的发布耗时直方图。 |
| `vllm:nixl_xfer_time_seconds` | Histogram | NIXL KV 缓存传输持续时间的直方图。 |