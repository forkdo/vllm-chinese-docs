#### `--user-count-var`

:   Result key that stores concurrent user count. Falls back to max_concurrent_requests if missing.

:   Default: `max_concurrency`

#### `--gpu-count-var`

:   Result key that stores GPU count. If not provided, falls back to num_gpus/gpu_count or tensor_parallel_size * pipeline_parallel_size.

#### `--label-by`

:   Comma-separated list of fields to annotate on Pareto frontier points.

:   Default: `max_concurrency,gpu_count`

#### `--dry-run`

:   If set, prints the figures to plot without drawing them.

:   Default: `False`

