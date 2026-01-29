# 更新 vLLM 开源 CI/CD 中的 PyTorch 版本

vLLM 目前的策略是在 CI/CD 中始终使用最新的 PyTorch 稳定版本。
当新的 [PyTorch 稳定版本](https://github.com/pytorch/pytorch/blob/main/RELEASE.md#release-cadence) 发布时，尽早提交 PR 更新 PyTorch 版本是标准做法。
由于 PyTorch 版本之间存在时间间隔，这个过程并不简单。
使用 <https://github.com/vllm-project/vllm/pull/16859> 作为例子，本文档概述了实现此更新的常见步骤，并列出可能的问题及解决方法。

## 测试 PyTorch 发布候选版本（RC）

在官方发布后才更新 vLLM 中的 PyTorch 并非理想方案，因为此时发现的任何问题只能通过等待下一个版本或在 vLLM 中实施临时解决办法来修复。
更好的解决方案是使用 PyTorch 发布候选版本（RC）测试 vLLM，以确保在每次发布前的兼容性。

PyTorch 发布候选版本可以从 [PyTorch 测试索引](https://download.pytorch.org/whl/test) 下载。
例如，`torch2.7.0+cu12.8` RC 可以使用以下命令安装：

```bash
uv pip install torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/test/cu128
```

当最终 RC 准备好进行测试时，将在 [PyTorch dev-discuss 论坛](https://dev-discuss.pytorch.org/c/release-announcements) 向社区宣布。
在此公告后，我们可以通过按照以下三步流程起草拉取请求开始测试 vLLM 集成：

1. 更新 [需求文件](https://github.com/vllm-project/vllm/tree/main/requirements)
   以指向新的 `torch`、`torchvision` 和 `torchaudio` 版本。

2. 使用以下选项获取最终发布候选版本的轮子。一些常见平台是 `cpu`、`cu128` 和 `rocm6.2.4`。

    ```bash
    --extra-index-url https://download.pytorch.org/whl/test/<PLATFORM>
    ```

3. 由于 vLLM 使用 `uv`，请确保应用以下索引策略：

    - 通过环境变量：

    ```bash
    export UV_INDEX_STRATEGY=unsafe-best-match
    ```

    - 或通过命令行标志：

    ```bash
    --index-strategy unsafe-best-match
    ```

如果在拉取请求中发现失败，请在 vLLM 上以问题形式提出，并抄送 PyTorch 发布团队，以发起如何解决这些问题的讨论。

## 更新 CUDA 版本

PyTorch 发布矩阵包括稳定和实验性 [CUDA 版本](https://github.com/pytorch/pytorch/blob/main/RELEASE.md#release-compatibility-matrix)。由于限制，只有最新的稳定 CUDA 版本（例如 torch `2.7.1+cu126`）会上传到 PyPI。然而，vLLM 可能需要不同的 CUDA 版本，例如 12.8 以支持 Blackwell。
这使过程变得复杂，因为我们无法使用现成的 `pip install torch torchvision torchaudio` 命令。解决方案是在 vLLM 的 Dockerfile 中使用 `--extra-index-url`。

- 当前重要的索引包括：

| 平台 | `--extra-index-url` |
|----------|-----------------|
| CUDA 12.8| [https://download.pytorch.org/whl/cu128](https://download.pytorch.org/whl/cu128)|
| CPU      | [https://download.pytorch.org/whl/cpu](https://download.pytorch.org/whl/cpu)|
| ROCm 6.2 | [https://download.pytorch.org/whl/rocm6.2.4](https://download.pytorch.org/whl/rocm6.2.4) |
| ROCm 6.3 | [https://download.pytorch.org/whl/rocm6.3](https://download.pytorch.org/whl/rocm6.3) |
| XPU      | [https://download.pytorch.org/whl/xpu](https://download.pytorch.org/whl/xpu) |

- 更新以下文件以匹配第 1 步中的 CUDA 版本。这确保发布的 vLLM 轮子在 CI 上经过测试。
    - `.buildkite/release-pipeline.yaml`
    - `.buildkite/scripts/upload-wheels.sh`

## 在 BuildKiteCI 上手动运行 vLLM 构建

当使用新的 PyTorch/CUDA 版本构建 vLLM 时，vLLM sccache S3 存储桶将没有任何缓存工件，这可能导致 CI 构建作业超过 5 小时。
此外，vLLM 的 fastcheck 管道以只读模式运行，不会填充缓存，因此对预热缓存无效。

为了解决这个问题，请手动在 Buildkite 上触发构建以实现两个目标：

1. 通过设置环境变量 `RUN_ALL=1` 和 `NIGHTLY=1` 运行完整的测试套件以测试 PyTorch RC 构建
2. 用编译工件填充 vLLM sccache S3 存储桶，从而实现更快的后续构建

<p align="center" width="100%">
<img width="60%" alt="Buildkite 新建构建弹窗" src="https://github.com/user-attachments/assets/3b07f71b-bb18-4ca3-aeaf-da0fe79d315f" />
</p>

## 更新所有不同的 vLLM 平台

与其试图在单个拉取请求中更新所有 vLLM 平台，不如分别处理某些平台更为可行。
vLLM CI/CD 中不同平台的需求文件和 Dockerfile 的分离允许我们选择性地决定要更新哪些平台。
例如，更新 XPU 需要英特尔的对应发布版本 [Intel Extension for PyTorch](https://github.com/intel/intel-extension-for-pytorch)。
虽然 <https://github.com/vllm-project/vllm/pull/16859> 将 vLLM 更新至 CPU、CUDA 和 ROCm 上的 PyTorch 2.7.0，
但 <https://github.com/vllm-project/vllm/pull/17444> 完成了 XPU 的更新。