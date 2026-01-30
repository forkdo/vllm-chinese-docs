#### `--serve-cmd`

:   用于运行服务器的命令：`vllm serve ...`

#### `--bench-cmd`

:   用于运行基准测试的命令：`vllm bench serve ...`

#### `--after-bench-cmd`

:   基准测试运行完成后，调用此命令，而不是默认的 `ServerWrapper.clear_cache()`。

#### `--show-stdout`

:   如果设置，则记录子命令的标准输出。对调试有用，但可能会产生大量日志。

:   默认值：`False`

#### `--server-ready-timeout`

:   等待服务器准备就绪的超时时间（秒）。

:   默认值：`300`

#### `--serve-params`

:   包含 `vllm serve` 命令参数组合的 JSON 文件路径。可以是字典列表，也可以是键为基准测试名称的字典。如果同时给出了 `serve_params` 和 `bench_params`，此脚本将遍历它们的笛卡尔积。

#### `--bench-params`

:   包含 `vllm bench serve` 命令参数组合的 JSON 文件路径。可以是字典列表，也可以是键为基准测试名称的字典。如果同时给出了 `serve_params` 和 `bench_params`，此脚本将遍历它们的笛卡尔积。

#### `-o`, `--output-dir`

:   结果写入的目录。

:   默认值：`results`

#### `--num-runs`

:   每个参数组合的运行次数。

:   默认值：`3`

#### `--dry-run`

:   如果设置，则打印要运行的命令，然后退出而不执行它们。

:   默认值：`False`

#### `--resume`

:   将此选项设置为 `output_dir` 下的一个目录名（该目录名是一个时间戳），以恢复此脚本之前的执行，即仅运行那些尚未生成输出文件的参数组合。

#### `--link-vars`

:   服务器和基准测试之间链接变量的逗号分隔列表，例如 `max_num_seqs=max_concurrency,max_model_len=random_input_len`

:   默认值：`""`


### sla 选项

#### `--sla-params`

:   包含要满足的 SLA 约束列表的 JSON 文件路径。每个约束以 `{"<KEY>": "<OP><VALUE>"}` 格式表示，例如：`{"p99_e2el_ms": "<=500"}` 表示 E2E 延迟在 99%% 的情况下应小于 500 毫秒。设置此选项将使脚本在 SLA 模式下运行，该模式会为每个 `serve_params`、`bench_params` 和 `sla_params` 的组合，搜索满足约束的最大 `sla_variable`。

#### `--sla-variable`

:   可选值：`request_rate`, `max_concurrency`

:   是调整请求速率还是最大并发数以满足 SLA 约束。

:   默认值：`request_rate`