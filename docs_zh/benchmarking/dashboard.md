# 性能仪表板

性能仪表板用于确认在各种工作负载下，新的更改是否提升了性能或导致性能下降。
每次提交带有 `perf-benchmarks` 和 `ready` 标签的代码，以及将 PR 合并到 vLLM 时，都会触发基准测试运行，从而更新该仪表板。

结果会自动发布到公共的 [vLLM 性能仪表板](https://hud.pytorch.org/benchmark/llms?repoName=vllm-project%2Fvllm)。

## 手动触发基准测试

使用带有 vLLM 基准测试套件的 [vllm-ci-test-repo 镜像](https://gallery.ecr.aws/q9t5s3a7/vllm-ci-test-repo)。
对于 x86 CPU 环境，请使用带有 "-cpu" 后缀的镜像。对于 AArch64 CPU 环境，请使用带有 "-arm64-cpu" 后缀的镜像。

以下是针对 CPU 的 docker run 命令示例。对于 GPU，请跳过设置 `ON_CPU` 环境变量。

```bash
export VLLM_COMMIT=7f42dc20bb2800d09faa72b26f25d54e26f1b694 # 使用主分支的完整提交哈希
export HF_TOKEN=<有效的 Hugging Face token>
if [[ "$(uname -m)" == aarch64 || "$(uname -m)" == arm64 ]]; then
  IMG_SUFFIX="arm64-cpu"
else
  IMG_SUFFIX="cpu"
fi
docker run -it --entrypoint /bin/bash -v /data/huggingface:/root/.cache/huggingface -e HF_TOKEN=$HF_TOKEN -e ON_CPU=1 --shm-size=16g --name vllm-cpu-ci public.ecr.aws/q9t5s3a7/vllm-ci-test-repo:${VLLM_COMMIT}-${IMG_SUFFIX}
```

然后，在 docker 实例中运行以下命令。

```bash
bash .buildkite/performance-benchmarks/scripts/run-performance-benchmarks.sh
```

运行时，基准测试脚本会在 **benchmark/results** 文件夹下生成结果，以及 benchmark_results.md 和 benchmark_results.json 文件。

### 运行时环境变量

- `ON_CPU`：在 Intel® Xeon® 和 Arm® Neoverse™ 处理器上将其值设置为 '1'。默认值为 0。
- `SERVING_JSON`：用于服务测试的 JSON 文件。默认值为空字符串（使用默认文件）。
- `LATENCY_JSON`：用于延迟测试的 JSON 文件。默认值为空字符串（使用默认文件）。
- `THROUGHPUT_JSON`：用于吞吐量测试的 JSON 文件。默认值为空字符串（使用默认文件）。
- `REMOTE_HOST`：要测试的远程 vLLM 服务的 IP。默认值为空字符串。
- `REMOTE_PORT`：要测试的远程 vLLM 服务的端口。默认值为空字符串。

### 可视化

`convert-results-json-to-markdown.py` 可以帮助您将基准测试结果放入一个包含实际基准测试结果的 Markdown 表格中。
您可以在 `buildkite/performance-benchmark` 作业页面中找到以表格形式呈现的结果。
如果您没有看到表格，请等待基准测试运行完成。
表格的 JSON 版本（以及基准测试的 JSON 版本）也将附加到 Markdown 文件中。
原始基准测试结果（JSON 文件格式）位于基准测试的 `Artifacts` 选项卡中。

#### 性能结果比较

`compare-json-results.py` 有助于比较使用 `convert-results-json-to-markdown.py` 转换的基准测试结果 JSON 文件。
运行时，基准测试脚本会在 `benchmark/results` 文件夹下生成结果，以及 `benchmark_results.md` 和 `benchmark_results.json` 文件。
`compare-json-results.py` 会比较两个 `benchmark_results.json` 文件，并提供性能比率，例如输出吞吐量、TTFT 中位数和 TPOT 中位数。  
如果只传递一个 benchmark_results.json 文件，`compare-json-results.py` 会比较 benchmark_results.json 中不同的 TP 和 PP 配置。

以下是使用该脚本比较 result_a 和 result_b 的示例，针对相同的模型、数据集名称、输入/输出长度，比较最大并发数和 QPS。
`python3 compare-json-results.py -f results_a/benchmark_results.json -f results_b/benchmark_results.json`

***输出吞吐量 (tok/s) — 模型 : [ meta-llama/Llama-3.1-8B-Instruct ] , 数据集名称 : [ random ] , 输入长度 : [ 2048.0 ] , 输出长度 : [ 2048.0 ]***

|    | 最大并发数 | qps  | results_a/benchmark_results.json | results_b/benchmark_results.json | 性能比率        |
|----|------|-----|-----------|----------|----------|
| 0  | 12 | inf | 24.98   | 186.03 |  7.45 |
| 1  | 16 | inf|  25.49  | 246.92 | 9.69 |
| 2  | 24 | inf| 27.74  | 293.34 |  10.57 |
| 3  | 32 | inf| 28.61  |306.69 | 10.72 |

***compare-json-results.py – 命令行参数***  

compare-json-results.py 提供可配置参数，用于比较一个或多个 benchmark_results.json 文件，并生成摘要表格和图表。  
在大多数情况下，用户只需指定 --file 来解析所需的基准测试结果。

| 参数              | 类型               | 默认值           | 描述                                                                                           |
| ---------------------- | ------------------ | ----------------------- | ----------------------------------------------------------------------------------------------------- |
| `--file`               | `str` (可追加) | *None*                  | 输入 JSON 结果文件。可以多次指定以比较多个基准测试输出。     |
| `--debug`              | `bool`             | `False`                 | 启用调试模式。设置后，打印所有可用信息以帮助故障排除和验证。 |
| `--plot` / `--no-plot` | `bool`             | `True`                  | 控制是否生成性能图表。使用 `--no-plot` 禁用图表生成。        |
| `--xaxis`              | `str`              | `# of max concurrency.` | 在比较图表中用作 X 轴的名称（例如，并发数或批处理大小）。          |
| `--latency`            | `str`              | `p99`                   | 用于 TTFT/TPOT 的延迟聚合方法。支持的值：`median` 或 `p99`。                   |
| `--ttft-max-ms`        | `float`            | `3000.0`                | TTFT 图表的参考上限（毫秒），通常用于可视化 SLA 阈值。      |
| `--tpot-max-ms`        | `float`            | `100.0`                 | TPOT 图表的参考上限（毫秒），通常用于可视化 SLA 阈值。      |

***有效最大并发数摘要***  

根据配置的 TTFT 和 TPOT SLA 阈值，compare-json-results.py 会为每个基准测试结果计算最大有效并发数。  
“最大并发数 (两者)” 列表示同时满足 TTFT 和 TPOT 约束的最高并发级别。  
该值通常用于容量规划和规模指南。  

| # | 配置  | 最大并发数 (TTFT ≤ 10000 ms) | 最大并发数 (TPOT ≤ 100 ms) | 最大并发数 (两者) | 两者下的输出吞吐量 (tok/s) | 两者下的 TTFT (ms) | 两者下的 TPOT (ms) |
| - | -------------- | ------------------------------------------- | ----------------------------------------- | -------------------------------- | -------------------------- | ---------------- | ---------------- |
| 0 | results-a      | 128.00                                      | 12.00                                     | 12.00                            | 127.76                     | 3000.82          | 93.24            |
| 1 | results-b      | 128.00                                      | 32.00                                     | 32.00                            | 371.42                     | 2261.53          | 81.74            |

有关性能基准测试及其参数的更多信息，请参阅 [基准测试 README](https://github.com/intel-ai-tce/vllm/blob/more_cpu_models/.buildkite/nightly-benchmarks/README.md) 和 [性能基准测试描述](../../.buildkite/performance-benchmarks/performance-benchmarks-descriptions.md)。

## 持续基准测试

持续基准测试为 vLLM 在不同模型和 GPU 设备上提供自动化的性能监控。这有助于跟踪 vLLM 随时间变化的性能特征，并识别任何性能退化或改进。

### 工作原理

持续基准测试通过 PyTorch 基础设施仓库中的 [GitHub workflow CI](https://github.com/pytorch/pytorch-integration-testing/actions/workflows/vllm-benchmark.yml) 触发，该工作流每 4 小时自动运行一次。该工作流执行三种类型的性能测试：

- **服务测试**：测量请求处理和 API 性能
- **吞吐量测试**：评估 token 生成速率
- **延迟测试**：评估响应时间特性

### 基准测试配置

基准测试目前在 [vllm-benchmarks 目录](https://github.com/pytorch/pytorch-integration-testing/tree/main/vllm-benchmarks/benchmarks) 中预定义的一组模型上运行。要添加新的基准测试模型：

1. 导航到基准测试配置中相应的 GPU 目录
2. 将您的模型规格添加到对应的配置文件中
3. 新模型将包含在下一次计划的基准测试运行中