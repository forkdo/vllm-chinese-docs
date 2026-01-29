# 参数扫描

## 在线基准测试

### 基础

`vllm bench sweep serve` 会自动启动 `vllm serve` 并运行 `vllm bench serve`，以在多种配置下评估 vLLM 的性能。

请按照以下步骤运行该脚本：

1. 构建 `vllm serve` 的基础命令，并将其传递给 `--serve-cmd` 选项。
2. 构建 `vllm bench serve` 的基础命令，并将其传递给 `--bench-cmd` 选项。
3. （可选）如果要调整 `vllm serve` 的设置，请创建一个新的 JSON 文件，并在其中填充您要测试的参数组合。将文件路径传递给 `--serve-params`。

    - 示例：调整 `--max-num-seqs` 和 `--max-num-batched-tokens`：

    ```json
    [
        {
            "max_num_seqs": 32,
            "max_num_batched_tokens": 1024
        },
        {
            "max_num_seqs": 64,
            "max_num_batched_tokens": 1024
        },
        {
            "max_num_seqs": 64,
            "max_num_batched_tokens": 2048
        },
        {
            "max_num_seqs": 128,
            "max_num_batched_tokens": 2048
        },
        {
            "max_num_seqs": 128,
            "max_num_batched_tokens": 4096
        },
        {
            "max_num_seqs": 256,
            "max_num_batched_tokens": 4096
        }
    ]
    ```

4. （可选）如果要调整 `vllm bench serve` 的设置，请创建一个新的 JSON 文件，并在其中填充您要测试的参数组合。将文件路径传递给 `--bench-params`。

    - 示例：为随机数据集使用不同的输入/输出长度：

    ```json
    [
        {
            "random_input_len": 128,
            "random_output_len": 32
        },
        {
            "random_input_len": 256,
            "random_output_len": 64
        },
        {
            "random_input_len": 512,
            "random_output_len": 128
        }
    ]
    ```

5. 确定您希望保存结果的位置，并将其传递给 `--output-dir`。

示例命令：

```bash
vllm bench sweep serve \
    --serve-cmd 'vllm serve meta-llama/Llama-2-7b-chat-hf' \
    --bench-cmd 'vllm bench serve --model meta-llama/Llama-2-7b-chat-hf --backend vllm --endpoint /v1/completions --dataset-name sharegpt --dataset-path benchmarks/ShareGPT_V3_unfiltered_cleaned_split.json' \
    --serve-params benchmarks/serve_hparams.json \
    --bench-params benchmarks/bench_hparams.json \
    -o benchmarks/results
```

!!! important
    如果同时传递了 `--serve-params` 和 `--bench-params`，脚本将遍历它们的笛卡尔积。
    您可以使用 `--dry-run` 预览将要运行的命令。

    对于每个 `--serve-params`，我们只启动一次服务器，并在多个 `--bench-params` 下保持其运行。
    在每次基准测试运行之间，我们会调用 `/reset_prefix_cache` 和 `/reset_mm_cache` 端点，以便为下一次运行提供一个干净的状态。
    如果您使用的是自定义的 `--serve-cmd`，可以通过设置 `--after-bench-cmd` 来覆盖用于重置状态的命令。

!!! note
    默认情况下，每个参数组合会运行 3 次，以使结果更加可靠。您可以通过设置 `--num-runs` 来调整运行次数。

!!! tip
    如果某次运行失败，您可以使用 `--resume` 选项继续参数扫描。

### SLA 自动调优

`vllm bench sweep serve_sla` 是 `vllm bench sweep serve` 的一个包装器，它会调整请求速率或并发度（通过 `--sla-variable` 选择），以满足由 `--sla-params` 给出的 SLA 约束。

例如，确保 99% 的请求的端到端延迟在以下目标值内：

```json
[
    {
        "p99_e2el_ms": "<=200"
    },
    {
        "p99_e2el_ms": "<=500"
    },
    {
        "p99_e2el_ms": "<=1000"
    },
    {
        "p99_e2el_ms": "<=2000"
    }
]
```

示例命令：

```bash
vllm bench sweep serve_sla \
    --serve-cmd 'vllm serve meta-llama/Llama-2-7b-chat-hf' \
    --bench-cmd 'vllm bench serve --model meta-llama/Llama-2-7b-chat-hf --backend vllm --endpoint /v1/completions --dataset-name sharegpt --dataset-path benchmarks/ShareGPT_V3_unfiltered_cleaned_split.json' \
    --serve-params benchmarks/serve_hparams.json \
    --bench-params benchmarks/bench_hparams.json \
    --sla-params benchmarks/sla_hparams.json \
    --sla-variable max_concurrency \
    -o benchmarks/results
```

调整 SLA 变量的算法如下：

1. 以最大可能的 QPS 运行基准测试一次，以最小可能的 QPS 运行一次。对于每次运行，计算 SLA 指标与其目标的距离，得到 QPS 与 SLA 距离的数据点。
2. 在数据点之间进行样条插值，以估计导致零 SLA 距离的 QPS。
3. 使用估计的 QPS 运行基准测试，并将结果数据点添加到历史记录中。
4. 重复步骤 2 和 3，直到历史记录中通过 SLA 的最大 QPS 和未通过 SLA 的最小 QPS 足够接近。

!!! important
    SLA 调优应用于 `--serve-params`、`--bench-params` 和 `--sla-params` 的每个组合。

    对于给定的 `--serve-params` 和 `--bench-params` 组合，我们会在 `--sla-params` 之间共享基准测试结果，以避免使用相同的 SLA 变量值重复运行基准测试。

### 启动

`vllm bench sweep startup` 会在参数组合上运行 `vllm bench startup`，以比较不同引擎设置的冷启动/热启动时间。

请按照以下步骤运行该脚本：

1. （可选）构建 `vllm bench startup` 的基础命令，并将其传递给 `--startup-cmd`（默认值：`vllm bench startup`）。
2. （可选）重用 `vllm bench sweep serve` 中的 `--serve-params` JSON 来调整引擎设置。只有 `vllm bench startup` 支持的参数才会被应用。
3. （可选）创建一个 `--startup-params` JSON 来调整启动特定的选项，如迭代次数。
4. 确定您希望保存结果的位置，并将其传递给 `--output-dir`。

示例 `--serve-params`：

```json
[
    {
        "_benchmark_name": "tp1",
        "model": "Qwen/Qwen3-0.6B",
        "tensor_parallel_size": 1,
        "gpu_memory_utilization": 0.9
    },
    {
        "_benchmark_name": "tp2",
        "model": "Qwen/Qwen3-0.6B",
        "tensor_parallel_size": 2,
        "gpu_memory_utilization": 0.9
    }
]
```

示例 `--startup-params`：

```json
[
    {
        "_benchmark_name": "qwen3-0.6",
        "num_iters_cold": 2,
        "num_iters_warmup": 1,
        "num_iters_warm": 2
    }
]
```

示例命令：

```bash
vllm bench sweep startup \
    --startup-cmd 'vllm bench startup --model Qwen/Qwen3-0.6B' \
    --serve-params benchmarks/serve_hparams.json \
    --startup-params benchmarks/startup_hparams.json \
    -o benchmarks/results
```

!!! important
    默认情况下，`--serve-params` 或 `--startup-params` 中不支持的参数会被忽略，并显示警告。
    使用 `--strict-params` 可以在遇到未知键时快速失败。

## 可视化

### 基础

`vllm bench sweep plot` 可用于从参数扫描结果中绘制性能曲线。

示例命令：

```bash
vllm bench sweep plot benchmarks/results/<timestamp> \
    --var-x max_concurrency \
    --row-by random_input_len \
    --col-by random_output_len \
    --curve-by api_server_count,max_num_batched_tokens \
    --filter-by 'max_concurrency<=1024'
```

!!! tip
    您可以使用 `--dry-run` 预览将要绘制的图形。

### 帕累托图

`vllm bench sweep plot_pareto` 有助于选择平衡每用户和每 GPU 吞吐量的配置。

更高的并发度或批处理大小可以提高 GPU 效率（每 GPU），但可能会增加每个用户的延迟；更低的并发度可以提高每用户的速率，但会导致 GPU 利用率不足；帕累托前沿显示了您的运行中可实现的最佳组合。

- x 轴：tokens/s/用户 = `output_throughput` ÷ 并发数（`--user-count-var`，默认为 `max_concurrency`，若未设置则回退到 `max_concurrent_requests`）。
- y 轴：tokens/s/GPU = `output_throughput` ÷ GPU 数量（如果设置了 `--gpu-count-var`，则使用该值；否则 GPU 数量为 TP×PP×DP）。
- 输出：在 `OUTPUT_DIR/pareto/PARETO.png` 生成一张图表。
- 在每个数据点显示所使用的配置 `--label-by`（默认为 `max_concurrency,gpu_count`）。

示例：

```bash
vllm bench sweep plot_pareto benchmarks/results/<timestamp> \
  --label-by max_concurrency,tensor_parallel_size,pipeline_parallel_size
```