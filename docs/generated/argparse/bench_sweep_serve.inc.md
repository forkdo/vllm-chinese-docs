#### `--serve-cmd`

:   The command used to run the server: `vllm serve ...`

#### `--bench-cmd`

:   The command used to run the benchmark: `vllm bench serve ...`

#### `--after-bench-cmd`

:   After a benchmark run is complete, invoke this command instead of the default `ServerWrapper.clear_cache()`.

#### `--show-stdout`

:   If set, logs the standard output of subcommands. Useful for debugging but can be quite spammy.

:   Default: `False`

#### `--server-ready-timeout`

:   Timeout in seconds to wait for the server to become ready.

:   Default: `300`

#### `--serve-params`

:   Path to JSON file containing parameter combinations for the `vllm serve` command. Can be either a list of dicts or a dict where keys are benchmark names. If both `serve_params` and `bench_params` are given, this script will iterate over their Cartesian product.

#### `--bench-params`

:   Path to JSON file containing parameter combinations for the `vllm bench serve` command. Can be either a list of dicts or a dict where keys are benchmark names. If both `serve_params` and `bench_params` are given, this script will iterate over their Cartesian product.

#### `-o`, `--output-dir`

:   The directory to which results are written.

:   Default: `results`

#### `--num-runs`

:   Number of runs per parameter combination.

:   Default: `3`

#### `--dry-run`

:   If set, prints the commands to run, then exits without executing them.

:   Default: `False`

#### `--resume`

:   Set this to the name of a directory under `output_dir` (which is a timestamp) to resume a previous execution of this script, i.e., only run parameter combinations for which there are still no output files.

#### `--link-vars`

:   Comma-separated list of linked variables between serve and bench, e.g. max_num_seqs=max_concurrency,max_model_len=random_input_len

:   Default: `""`

