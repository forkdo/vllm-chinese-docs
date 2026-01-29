#### `--user-count-var`

:   存储并发用户数量的结果键。如果缺失，则回退到 max_concurrent_requests。

:   默认值：`max_concurrency`

#### `--gpu-count-var`

:   存储 GPU 数量的结果键。如果未提供，则回退到 num_gpus/gpu_count 或 tensor_parallel_size * pipeline_parallel_size。

#### `--label-by`

:   在帕累托前沿点上标注的字段列表（以逗号分隔）。

:   默认值：`max_concurrency,gpu_count`

#### `--dry-run`

:   如果设置，则仅打印要绘制的图形而不实际绘制它们。

:   默认值：`False`