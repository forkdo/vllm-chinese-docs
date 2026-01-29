#### `--serve-cmd`

:   用于运行服务器的命令：`vllm serve ...`

#### `--bench-cmd`

:   用于运行基准测试的命令：`vllm bench serve ...`

#### `--after-bench-cmd`

:   基准测试运行完成后，调用此命令，而不是默认的 `ServerWrapper.clear_cache()`。

#### `--show-stdout`

:   如果设置，将记录子命令的标准输出。对于调试很有用，但可能会产生大量输出。

:   默认值：`False`

#### `--server-ready-timeout`

:   等待服务器准备就绪的超时时间（以秒为单位）。

:   默认值：`300`

#### `--serve-params`

:   包含 `vllm serve` 命令参数组合的 JSON 文件路径。可以是一个字典列表，也可以是一个字典，其中键为基准测试名称。如果同时提供了 `serve_params` 和 `bench_params`，此脚本将遍历它们的笛卡尔积。

#### `--bench-params`

:   包含 `vllm bench serve` 命令参数组合的 JSON 文件路径。可以是一个字典列表，也可以是一个字典，其中键为基准测试名称。如果同时提供了 `serve_params` 和 `bench_params`，此脚本将遍历它们的笛卡尔积。

#### `-o`, `--output-dir`

:   结果写入的目录。

:   默认值：`results`

#### `--num-runs`

:   每个参数组合的运行次数。

:   默认值：`3`

#### `--dry-run`

:   如果设置，将打印要运行的命令，然后退出而不执行它们。

:   默认值：`False`

#### `--resume`

:   将其设置为 `output_dir` 下的目录名称（这是一个时间戳），以恢复此脚本的先前执行，即仅运行那些仍没有输出文件的参数组合。

#### `--link-vars`

:   服务器和基准测试之间链接变量的逗号分隔列表，例如 max_num_seqs=max_concurrency,max_model_len=random_input_len

:   默认值：`""`