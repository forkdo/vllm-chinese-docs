# vLLM 性能分析

!!! warning
    性能分析仅适用于 vLLM 开发者和维护者，用于了解代码库不同部分的时间消耗比例。**vLLM 终端用户绝不应启用性能分析**，因为这会显著降低推理速度。

## 使用 PyTorch Profiler 进行性能分析

我们支持使用 `torch.profiler` 模块跟踪 vLLM 工作进程。您可以通过在启动服务器时设置 `--profiler-config` 来启用 PyTorch Profiler，并将配置项 `profiler` 设为 `'torch'`，将 `torch_profiler_dir` 设为保存跟踪文件的目录。此外，您还可以通过配置中的以下附加参数控制性能分析内容：

- `torch_profiler_record_shapes`：启用记录张量形状，默认关闭
- `torch_profiler_with_memory`：记录内存使用情况，默认关闭
- `torch_profiler_with_stack`：启用记录堆栈信息，默认开启
- `torch_profiler_with_flops`：启用记录 FLOPs，默认关闭
- `torch_profiler_use_gzip`：控制是否对性能分析文件进行 gzip 压缩，默认开启
- `torch_profiler_dump_cuda_time_total`：控制是否转储并打印聚合的 CUDA 自耗时表，默认开启

使用 `vllm bench serve` 时，可通过传递 `--profile` 标志启用性能分析。

跟踪结果可使用 <https://ui.perfetto.dev/> 进行可视化。

!!! tip
    您可以直接调用 bench 模块而无需安装 vLLM，使用命令 `python -m vllm.entrypoints.cli.main bench`。

!!! tip
    性能分析时只需向 vLLM 发送少量请求，因为跟踪文件可能会变得非常大。此外，无需解压跟踪文件，可直接查看。

!!! tip
    要停止性能分析器，它会将所有性能分析跟踪文件刷新到指定目录。此过程需要时间，例如对于 llama 70b 模型约 100 个请求的数据，在 H100 上刷新大约需要 10 分钟。
    请在启动服务器前将环境变量 VLLM_RPC_TIMEOUT 设置为一个较大的数值，例如 30 分钟。
    `export VLLM_RPC_TIMEOUT=1800000`

### 示例命令和用法

#### 离线推理

请参考 [examples/offline_inference/simple_profiling.py](../../examples/offline_inference/simple_profiling.py) 获取示例。

#### OpenAI 服务器

```bash
vllm serve meta-llama/Llama-3.1-8B-Instruct --profiler-config '{"profiler": "torch", "torch_profiler_dir": "./vllm_profile"}'
```

vllm bench 命令：

```bash
vllm bench serve \
    --backend vllm \
    --model meta-llama/Llama-3.1-8B-Instruct \
    --dataset-name sharegpt \
    --dataset-path sharegpt.json \
    --profile \
    --num-prompts 2
```

或使用 HTTP 请求：

```shell
# 首先需要调用 /start_profile API 启动性能分析。
$ curl -X POST http://localhost:8000/start_profile

# 调用模型生成。
curl -X POST http://localhost:8000/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{
                "model": "meta-llama/Llama-3.1-8B-Instruct",
                "messages": [
                        {
                                "role": "user",
                                "content": "San Francisco is a"
                        }
                ]
    }'

# 之后需要调用 /stop_profile API 停止性能分析。
$ curl -X POST http://localhost:8000/stop_profile
```

## 使用 NVIDIA Nsight Systems 进行性能分析

Nsight Systems 是一款高级工具，可暴露更多性能分析细节，例如寄存器和共享内存使用情况、带注释的代码区域以及底层 CUDA API 和事件。

使用包管理器[安装 nsight-systems](https://docs.nvidia.com/nsight-systems/InstallationGuide/index.html)。
以下是在 Ubuntu 上的安装示例：

```bash
apt update
apt install -y --no-install-recommends gnupg
echo "deb http://developer.download.nvidia.com/devtools/repos/ubuntu$(source /etc/lsb-release; echo "$DISTRIB_RELEASE" | tr -d .)/$(dpkg --print-architecture) /" | tee /etc/apt/sources.list.d/nvidia-devtools.list
apt-key adv --fetch-keys http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub
apt update
apt install nsight-systems-cli
```

!!! tip
    使用 `nsys` 进行性能分析时，建议设置环境变量 `VLLM_WORKER_MULTIPROC_METHOD=spawn`。默认使用 `fork` 方法而非 `spawn` 方法。有关此主题的更多信息，请参阅 [Nsight Systems 发行说明](https://docs.nvidia.com/nsight-systems/ReleaseNotes/index.html#general-issues)。

Nsight Systems 性能分析器可使用 `nsys profile ...` 启动，并为 vLLM 推荐使用以下标志：`--trace-fork-before-exec=true --cuda-graph-trace=node`。

### 示例命令和用法

#### 离线推理

对于基本用法，您只需在任何现有离线推理脚本前添加性能分析命令即可。

以下是使用 `vllm bench latency` 脚本的示例：

```bash
nsys profile  \
    --trace-fork-before-exec=true \
    --cuda-graph-trace=node \
vllm bench latency \
    --model meta-llama/Llama-3.1-8B-Instruct \
    --num-iters-warmup 5 \
    --num-iters 1 \
    --batch-size 16 \
    --input-len 512 \
    --output-len 8
```

#### OpenAI 服务器

要对服务器进行性能分析，您需要在 `vllm serve` 命令前添加 `nsys profile`，就像离线推理一样，但需要指定一些其他参数以启用动态捕获，类似于 Torch Profiler：

```bash
# 服务器
nsys profile \
    --trace-fork-before-exec=true \
    --cuda-graph-trace=node \
    --capture-range=cudaProfilerApi \
    --capture-range-end repeat \
    vllm serve meta-llama/Llama-3.1-8B-Instruct --profiler-config.profiler cuda

# 客户端
vllm bench serve \
    --backend vllm \
    --model meta-llama/Llama-3.1-8B-Instruct \
    --dataset-name sharegpt \
    --dataset-path sharegpt.json \
    --profile \
    --num-prompts 2
```

使用 `--profile` 时，vLLM 会为每次 `vllm bench serve` 运行捕获性能分析数据。一旦服务器被终止，所有性能分析数据将被保存。

#### 分析

您可以使用 `nsys stats [profile-file]` 在 CLI 中查看这些性能分析数据的摘要，或通过[按照此处说明本地安装 Nsight](https://developer.nvidia.com/nsight-systems/get-started) 在 GUI 中查看。

??? console "CLI 示例"

    ```bash
    nsys stats report1.nsys-rep
    ...
    ** CUDA GPU 内核摘要 (cuda_gpu_kern_sum):

时间（%）  总时间（纳秒）  实例数  平均值（纳秒）  中位数（纳秒）  最小值（纳秒）  最大值（纳秒）  标准差（纳秒）  名称
--------  ---------------  ---------  -----------  -----------  --------  ---------  -----------  ----------------------------------------------------------------------------------------------------
    46.3   10,327,352,338     17,505    589,965.9    144,383.0    27,040  3,126,460    944,263.8  sm90_xmma_gemm_bf16bf16_bf16f32_f32_tn_n_tilesize128x128x64_warpgroupsize1x1x1_execute_segment_k_of…
    14.8    3,305,114,764      5,152    641,520.7    293,408.0   287,296  2,822,716    867,124.9  sm90_xmma_gemm_bf16bf16_bf16f32_f32_tn_n_tilesize256x128x64_warpgroupsize2x1x1_execute_segment_k_of…
    12.1    2,692,284,876     14,280    188,535.4     83,904.0    19,328  2,862,237    497,999.9  sm90_xmma_gemm_bf16bf16_bf16f32_f32_tn_n_tilesize64x128x64_warpgroupsize1x1x1_execute_segment_k_off…
    9.5    2,116,600,578     33,920     62,399.8     21,504.0    15,326  2,532,285    290,954.1  sm90_xmma_gemm_bf16bf16_bf16f32_f32_tn_n_tilesize64x64x64_warpgroupsize1x1x1_execute_segment_k_off_…
    5.0    1,119,749,165     18,912     59,208.4      9,056.0     6,784  2,578,366    271,581.7  void vllm::act_and_mul_kernel<c10::BFloat16, &vllm::silu_kernel<c10::BFloat16>, (bool)1>(T1 *, cons…
    4.1      916,662,515     21,312     43,011.6     19,776.0     8,928  2,586,205    199,790.1  void cutlass::device_kernel<flash::enable_sm90_or_later<flash::FlashAttnFwdSm90<flash::CollectiveMa…
    2.6      587,283,113     37,824     15,526.7      3,008.0     2,719  2,517,756    139,091.1  std::enable_if<T2>(int)0&&vllm::_typeConvert<T1>::exists, void>::type vllm::fused_add_rms_norm_kern…
    1.9      418,362,605     18,912     22,121.5      3,871.0     3,328  2,523,870    175,248.2  void vllm::rotary_embedding_kernel<c10::BFloat16, (bool)1>(const long *, T1 *, T1 *, const T1 *, in…
    0.7      167,083,069     18,880      8,849.7      2,240.0     1,471  2,499,996    101,436.1  void vllm::reshape_and_cache_flash_kernel<__nv_bfloat16, __nv_bfloat16, (vllm::Fp8KVCacheDataType)0…
...

GUI 示例：

<img width="1799" alt="Screenshot 2025-03-05 at 11 48 42 AM" src="https://github.com/user-attachments/assets/c7cff1ae-6d6f-477d-a342-bd13c4fc424c" />

## 持续性能分析

PyTorch 基础设施仓库中有一个 [GitHub CI 工作流](https://github.com/pytorch/pytorch-integration-testing/actions/workflows/vllm-profiling.yml)，可为 vLLM 上的不同模型提供持续性能分析。这种自动化性能分析有助于跟踪不同模型配置下的性能特征随时间的变化。

### 工作原理

该工作流目前每周为选定的模型运行性能分析会话，生成详细的性能跟踪数据，可以使用不同工具进行分析，以识别性能退化或优化机会。但也可以使用 GitHub Action 工具手动触发。

### 添加新模型

要将持续性能分析扩展到其他模型，可以修改 PyTorch 集成测试仓库中的 [profiling-tests.json](https://github.com/pytorch/pytorch-integration-testing/blob/main/vllm-profiling/cuda/profiling-tests.json) 配置文件。只需将模型规范添加到此文件中，即可将其包含在自动化性能分析运行中。

### 查看性能分析结果

持续性能分析工作流生成的性能跟踪数据可在 [vLLM 性能仪表板](https://hud.pytorch.org/benchmark/llms?repoName=vllm-project%2Fvllm) 上公开获取。查找 **Profiling traces** 表以访问和下载不同模型和运行的跟踪数据。

## 分析 vLLM Python 代码

Python 标准库包含 [cProfile](https://docs.python.org/3/library/profile.html) 用于分析 Python 代码。vLLM 包含一些辅助工具，可以轻松将其应用于 vLLM 的某个部分。`vllm.utils.profiling.cprofile` 和 `vllm.utils.profiling.cprofile_context` 函数都可以用于分析代码段。

!!! note
    旧版导入路径 `vllm.utils.cprofile` 和 `vllm.utils.cprofile_context` 已弃用。
    请改用 `vllm.utils.profiling.cprofile` 和 `vllm.utils.profiling.cprofile_context`。

### 使用示例 - 装饰器

第一个辅助工具是一个 Python 装饰器，可用于分析函数。如果指定了文件名，性能分析数据将保存到该文件。如果未指定文件名，性能分析数据将打印到标准输出。

```python
from vllm.utils.profiling import cprofile

@cprofile("expensive_function.prof")
def expensive_function():
    # some expensive code
    pass
```

### 使用示例 - 上下文管理器

第二个辅助工具是一个上下文管理器，可用于分析代码块。与装饰器类似，文件名是可选的。

```python
from vllm.utils.profiling import cprofile_context

def another_function():
    # more expensive code
    pass

with cprofile_context("another_function.prof"):
    another_function()
```

### 分析性能分析结果

有多个工具可用于分析性能分析结果。一个例子是 [snakeviz](https://jiffyclub.github.io/snakeviz/)。

```bash
pip install snakeviz
snakeviz expensive_function.prof
```

### 分析垃圾回收成本

利用 VLLM_GC_DEBUG 环境变量来调试 GC 成本。

- VLLM_GC_DEBUG=1：启用 GC 调试器并记录 gc.collect 的耗时
- VLLM_GC_DEBUG='{"top_objects":5}'：启用 GC 调试器，记录每次 gc.collect 时回收的前 5 个对象