# --8<-- [start:installation]

vLLM 包含预编译的 C++ 和 CUDA (12.8) 二进制文件。

# --8<-- [end:installation]
# --8<-- [start:requirements]

- GPU：计算能力 7.0 或更高（例如 V100、T4、RTX20xx、A100、L4、H100 等）

# --8<-- [end:requirements]
# --8<-- [start:set-up-using-python]

!!! note
    通过 `conda` 安装的 PyTorch 会静态链接 `NCCL` 库，这可能会导致 vLLM 使用 `NCCL` 时出现问题。详情请参见 <https://github.com/vllm-project/vllm/issues/8420>。

为了实现高性能，vLLM 需要编译许多 CUDA 内核。遗憾的是，这种编译会引入与其他 CUDA 版本和 PyTorch 版本的二进制不兼容性，即使是相同 PyTorch 版本但构建配置不同也会出现此问题。

因此，建议使用**全新的**环境安装 vLLM。如果您有不同的 CUDA 版本或希望使用现有的 PyTorch 安装，则需要从源代码构建 vLLM。详情请参见[下文](#build-wheel-from-source)。

# --8<-- [end:set-up-using-python]
# --8<-- [start:pre-built-wheels]

```bash
uv pip install vllm --torch-backend=auto
```

??? console "pip"
    ```bash
    # 使用 CUDA 12.9 安装 vLLM。
    pip install vllm --extra-index-url https://download.pytorch.org/whl/cu129
    ```

我们推荐使用 `uv` 通过 `--torch-backend=auto`（或 `UV_TORCH_BACKEND=auto`）[在运行时自动选择合适的 PyTorch 索引](https://docs.astral.sh/uv/guides/integration/pytorch/#automatic-backend-selection)，方法是检查已安装的 CUDA 驱动程序版本。要选择特定的后端（例如 `cu128`），请设置 `--torch-backend=cu128`（或 `UV_TORCH_BACKEND=cu128`）。如果这不起作用，请先尝试运行 `uv self update` 更新 `uv`。

!!! note
    NVIDIA Blackwell GPU（B200、GB200）需要至少 CUDA 12.8，因此请确保安装至少该版本的 PyTorch wheel。PyTorch 本身提供了一个[专用接口](https://pytorch.org/get-started/locally/)来确定给定目标配置应运行的适当 pip 命令。

截至目前，vLLM 的二进制文件默认使用 CUDA 12.9 和公共 PyTorch 发行版本编译。我们还提供了使用 CUDA 12.8、13.0 和公共 PyTorch 发行版本编译的 vLLM 二进制文件：

```bash
# 使用特定 CUDA 版本（例如 13.0）安装 vLLM。
export VLLM_VERSION=$(curl -s https://api.github.com/repos/vllm-project/vllm/releases/latest | jq -r .tag_name | sed 's/^v//')
export CUDA_VERSION=130 # 或其他版本
export CPU_ARCH=$(uname -m) # x86_64 或 aarch64
uv pip install https://github.com/vllm-project/vllm/releases/download/v${VLLM_VERSION}/vllm-${VLLM_VERSION}+cu${CUDA_VERSION}-cp38-abi3-manylinux_2_35_${CPU_ARCH}.whl --extra-index-url https://download.pytorch.org/whl/cu${CUDA_VERSION}
```

#### 安装最新代码

LLM 推理是一个快速发展的领域，最新代码可能包含尚未发布的错误修复、性能改进和新功能。为了让用户无需等待下一次发布即可试用最新代码，vLLM 自 `v0.5.3` 起为每次提交提供 wheel 文件，地址为 <https://wheels.vllm.ai/nightly>。可以使用多个索引：

* `https://wheels.vllm.ai/nightly`：默认变体（CUDA 版本在 `VLLM_MAIN_CUDA_VERSION` 中指定），使用 `main` 分支上的最后一次提交构建。目前为 CUDA 12.9。
* `https://wheels.vllm.ai/nightly/<variant>`：所有其他变体。现在包括 `cu130` 和 `cpu`。默认变体（`cu129`）也有一个子目录以保持一致性。

要从 nightly 索引安装，请运行：

```bash
uv pip install -U vllm \
    --torch-backend=auto \
    --extra-index-url https://wheels.vllm.ai/nightly # 如果需要，在此处添加变体子目录
```

!!! warning "`pip` 注意事项"

    不支持使用 `pip` 从 nightly 索引安装，因为 `pip` 会合并来自 `--extra-index-url` 和默认索引的软件包，仅选择最新版本，这使得安装早于已发布版本的开发版本变得困难。相比之下，`uv` 会给额外索引[高于默认索引的优先级](https://docs.astral.sh/uv/pip/compatibility/#packages-that-exist-on-multiple-indexes)。

    如果您坚持使用 `pip`，则必须指定 wheel 文件的完整 URL（可从网页获取）。

    ```bash
    pip install -U https://wheels.vllm.ai/nightly/vllm-0.11.2.dev399%2Bg3c7461c18-cp38-abi3-manylinux_2_31_x86_64.whl # 当前 nightly 构建（文件名会变化！）
    pip install -U https://wheels.vllm.ai/${VLLM_COMMIT}/vllm-0.11.2.dev399%2Bg3c7461c18-cp38-abi3-manylinux_2_31_x86_64.whl # 从特定提交安装
    ```

##### 安装特定修订版本

如果您想访问以前提交的 wheel 文件（例如，为了二分查找行为变化、性能回归），可以在 URL 中指定提交哈希：

```bash
export VLLM_COMMIT=72d9c316d3f6ede485146fe5aabd4e61dbc59069 # 使用 main 分支的完整提交哈希
uv pip install vllm \
    --torch-backend=auto \
    --extra-index-url https://wheels.vllm.ai/${VLLM_COMMIT} # 如果需要，在此处添加变体子目录
```

# --8<-- [end:pre-built-wheels]
# --8<-- [start:build-wheel-from-source]

#### 使用纯 Python 构建（无需编译）进行设置 {#python-only-build}

如果您只需要更改 Python 代码，可以无需编译即可构建和安装 vLLM。使用 `uv pip` 的 [`--editable` 标志](https://docs.astral.sh/uv/pip/packages/#editable-packages)，您对代码所做的更改将在运行 vLLM 时生效：

```bash
git clone https://github.com/vllm-project/vllm.git
cd vllm
VLLM_USE_PRECOMPILED=1 uv pip install --editable .
```

此命令将执行以下操作：

1. 查找您的 vLLM 克隆中的当前分支。
1. 确定 main 分支中相应的基础提交。
1. 下载基础提交的预构建 wheel。
1. 在安装中使用其编译库。

!!! note
    1. 如果您更改了 C++ 或内核代码，则不能使用纯 Python 构建；否则您将看到关于库未找到或符号未定义的导入错误。
    2. 如果您变基了开发分支，建议卸载 vllm 并重新运行上述命令，以确保您的库是最新的。

如果在运行上述命令时看到关于 wheel 未找到的错误，可能是因为您在 main 分支上基于的提交刚刚合并，wheel 正在构建中。在这种情况下，您可以等待大约一小时再重试，或者使用 `VLLM_PRECOMPILED_WHEEL_LOCATION` 环境变量在手动安装中分配前一个提交。

```bash
export VLLM_PRECOMPILED_WHEEL_COMMIT=$(git rev-parse HEAD~1) # 或 main 分支上更早的提交
export VLLM_USE_PRECOMPILED=1
uv pip install --editable .
```

还有更多环境变量可用于控制纯 Python 构建的行为：

* `VLLM_PRECOMPILED_WHEEL_LOCATION`：指定要使用的预编译 wheel 的确切 URL 或本地文件路径。将跳过查找 wheel 的所有其他逻辑。
* `VLLM_PRECOMPILED_WHEEL_COMMIT`：覆盖要下载预编译 wheel 的提交哈希。可以是 `nightly` 以使用 main 分支上最后一次**已构建**的提交。
* `VLLM_PRECOMPILED_WHEEL_VARIANT`：指定在 nightly 索引上使用的变体子目录，例如 `cu129`、`cu130`、`cpu`。如果未指定，则根据系统的 CUDA 版本（来自 PyTorch 或 nvidia-smi）自动检测变体。您也可以设置 `VLLM_MAIN_CUDA_VERSION` 来覆盖自动检测。

您可以在[安装最新代码](#install-the-latest-code)中找到有关 vLLM wheel 的更多信息。

!!! note
    您的源代码可能与最新的 vLLM wheel 具有不同的提交 ID，这可能会导致未知错误。
    建议为源代码使用与已安装的 vLLM wheel 相同的提交 ID。请参考[安装最新代码](#install-the-latest-code)了解如何安装指定的 wheel。

#### 完整构建（带编译） {#full-build}

如果要修改 C++ 或 CUDA 代码，则需要从源代码构建 vLLM。这可能需要几分钟时间：

```bash
git clone https://github.com/vllm-project/vllm.git
cd vllm
uv pip install -e .
```

!!! tip
    从源代码构建需要大量的编译工作。如果需要反复从源代码构建，缓存编译结果会更高效。

    例如，可以使用 `conda install ccache` 或 `apt install ccache` 安装 [ccache](https://github.com/ccache/ccache)。
    只要 `which ccache` 命令能够找到 `ccache` 二进制文件，构建系统就会自动使用它。首次构建后，后续构建将快得多。

    使用 `ccache` 配合 `pip install -e .` 时，应运行 `CCACHE_NOHASHDIR="true" pip install --no-build-isolation -e .`。这是因为 `pip` 每次构建都会创建一个随机名称的新文件夹，导致 `ccache` 无法识别正在构建的是相同的文件。

    [sccache](https://github.com/mozilla/sccache) 与 `ccache` 类似，但能够在远程存储环境中利用缓存。
    可以设置以下环境变量来配置 vLLM 的 `sccache` 远程缓存：`SCCACHE_BUCKET=vllm-build-sccache SCCACHE_REGION=us-west-2 SCCACHE_S3_NO_CREDENTIALS=1`。我们还建议设置 `SCCACHE_IDLE_TIMEOUT=0`。

!!! note "更快的内核开发"
    对于频繁的 C++/CUDA 内核更改，在完成初始的 `uv pip install -e .` 设置后，请考虑使用[增量编译工作流](../../contributing/incremental_build.md)，这样只需重新构建修改过的内核代码，可显著加快构建速度。

##### 使用现有的 PyTorch 安装

在某些情况下，可能无法通过 `uv` 轻松安装 PyTorch 依赖项，例如使用非默认 PyTorch 构建（如 nightly 版本或自定义构建）构建 vLLM 时。

要使用现有的 PyTorch 安装构建 vLLM：

```bash
# 首先安装 PyTorch，可通过 PyPI 或从源代码安装
git clone https://github.com/vllm-project/vllm.git
cd vllm
python use_existing_torch.py
uv pip install -r requirements/build.txt
uv pip install --no-build-isolation -e .
```

或者：如果专门使用 `uv` 创建和管理虚拟环境，它有一种[独特的机制](https://docs.astral.sh/uv/concepts/projects/config/#disabling-build-isolation)可以针对特定包禁用构建隔离。vLLM 可以利用此机制，将 `torch` 指定为禁用构建隔离的包：

```bash
# 首先安装 PyTorch，可通过 PyPI 或从源代码安装
git clone https://github.com/vllm-project/vllm.git
cd vllm
# 直接使用 pip install -e . 不起作用，只有 uv 才能做到这一点
uv pip install -e .
```

##### 使用本地 cutlass 进行编译

目前，在开始构建过程之前，vLLM 会从 GitHub 获取 cutlass 代码。但在某些情况下，可能需要使用本地版本的 cutlass。
要实现这一点，可以设置环境变量 VLLM_CUTLASS_SRC_DIR 指向本地 cutlass 目录。

```bash
git clone https://github.com/vllm-project/vllm.git
cd vllm
VLLM_CUTLASS_SRC_DIR=/path/to/cutlass uv pip install -e .
```

##### 故障排除

为避免系统过载，可通过环境变量 `MAX_JOBS` 限制同时运行的编译任务数量。例如：

```bash
export MAX_JOBS=6
uv pip install -e .
```

这在性能较弱的机器上构建时特别有用。例如，使用 WSL 时默认只[分配总内存的 50%](https://learn.microsoft.com/zh-cn/windows/wsl/wsl-config#main-wsl-settings)，因此使用 `export MAX_JOBS=1` 可避免同时编译多个文件导致内存耗尽。
副作用是构建过程会慢得多。

此外，如果在构建 vLLM 时遇到问题，建议使用 NVIDIA PyTorch Docker 镜像。

```bash
# 使用 `--ipc=host` 确保共享内存足够大。
docker run \
    --gpus all \
    -it \
    --rm \
    --ipc=host nvcr.io/nvidia/pytorch:23.10-py3
```

如果不想使用 docker，建议完整安装 CUDA Toolkit。可从[官方网站](https://developer.nvidia.com/cuda-toolkit-archive)下载并安装。安装后，将环境变量 `CUDA_HOME` 设置为 CUDA Toolkit 的安装路径，并确保 `nvcc` 编译器位于 `PATH` 中，例如：

```bash
export CUDA_HOME=/usr/local/cuda
export PATH="${CUDA_HOME}/bin:$PATH"
```

以下是一个验证 CUDA Toolkit 是否正确安装的基本检查：

```bash
nvcc --version # 验证 nvcc 是否在 PATH 中
${CUDA_HOME}/bin/nvcc --version # 验证 nvcc 是否在 CUDA_HOME 中
```

#### 不支持的操作系统构建

vLLM 只能在 Linux 上完全运行，但出于开发目的，仍可在其他系统（例如 macOS）上构建，从而实现导入和更便捷的开发环境。二进制文件不会被编译，且无法在非 Linux 系统上运行。

只需在安装前禁用 `VLLM_TARGET_DEVICE` 环境变量：

```bash
export VLLM_TARGET_DEVICE=empty
uv pip install -e .
```

# --8<-- [end:build-wheel-from-source]
# --8<-- [start:pre-built-images]

有关使用官方 Docker 镜像的说明，请参阅[使用 Docker](../../deployment/docker.md)。

另一种访问最新代码的方法是使用 docker 镜像：

```bash
export VLLM_COMMIT=33f460b17a54acb3b6cc0b03f4a17876cff5eafd # 使用主分支的完整提交哈希
docker pull public.ecr.aws/q9t5s3a7/vllm-ci-postmerge-repo:${VLLM_COMMIT}
```

这些 docker 镜像仅用于 CI 和测试，不适用于生产环境。它们将在几天后过期。

最新代码可能包含错误且不稳定，请谨慎使用。

# --8<-- [end:pre-built-images]
# --8<-- [start:build-image-from-source]

有关构建 Docker 镜像的说明，请参阅[从源代码构建 vLLM 的 Docker 镜像](../../deployment/docker.md#building-vllms-docker-image-from-source)。

# --8<-- [end:build-image-from-source]
# --8<-- [start:supported-features]

有关功能支持信息，请参阅[功能 x 硬件](../../features/README.md#feature-x-hardware)兼容性矩阵。

# --8<-- [end:supported-features]