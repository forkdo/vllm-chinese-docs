| Metric Name | Type | Description |
|-------------|------|-------------|
| `vllm:nixl_num_failed_notifications` | Counter | Number of failed NIXL KV Cache notifications. |
| `vllm:nixl_num_failed_transfers` | Counter | Number of failed NIXL KV Cache transfers. |
| `vllm:nixl_num_kv_expired_reqs` | Counter | Number of requests that had their KV expire. NOTE: This metric is tracked on the P instance. |
| `vllm:nixl_bytes_transferred` | Histogram | Histogram of bytes transferred per NIXL KV Cache transfers. |
| `vllm:nixl_num_descriptors` | Histogram | Histogram of number of descriptors per NIXL  KV Cache transfers. |
| `vllm:nixl_post_time_seconds` | Histogram | Histogram of transfer post time for NIXL KV Cache transfers. |
| `vllm:nixl_xfer_time_seconds` | Histogram | Histogram of transfer duration for NIXL KV Cache transfers. |
