# --8<-- [start:installation]

vLLM 支持运行 ROCm 6.3 或更高版本的 AMD GPU。目前提供适用于 ROCm 7.0 的预构建 wheel 包。

# --8<-- [end:installation]
# --8<-- [start:requirements]

- GPU：MI200s (gfx90a)、MI300 (gfx942)、MI350 (gfx950)、Radeon RX 7900 系列 (gfx1100/1101)、Radeon RX 9000 系列 (gfx1200/1201)、Ryzen AI MAX / AI 300 系列 (gfx1151/1150)
- ROCm 6.3 或更高版本
    - MI350 需要 ROCm 7.0 或更高版本
    - Ryzen AI MAX / AI 300 系列需要 ROCm 7.0.2 或更高版本

# --8<-- [end:requirements]
# --8<-- [start:set-up-using-python]

vLLM wheel 包捆绑了 PyTorch 和所有必需的依赖项，您应使用其中包含的 PyTorch 以确保兼容性。由于 vLLM 会编译大量 ROCm 内核以确保经过验证的高性能堆栈，因此生成的二进制文件可能与其他 ROCm 或 PyTorch 构建版本不兼容。
如果您需要不同的 ROCm 版本或希望使用现有的 PyTorch 安装，则需要从源代码构建 vLLM。有关更多详细信息，请参阅[下文](#build-wheel-from-source)。

# --8<-- [end:set-up-using-python]
# --8<-- [start:pre-built-wheels]

要为 Python 3.12、ROCm 7.0 和 `glibc >= 2.35` 安装最新版本的 vLLM：

```bash
uv pip install vllm --extra-index-url https://wheels.vllm.ai/rocm/
```

!!! tip
    您可以通过检查 extra-index-url 中的索引 [https://wheels.vllm.ai/rocm/](https://wheels.vllm.ai/rocm/) 来了解最新版本的 vLLM 支持哪个 ROCm 版本。

要安装特定版本和 ROCm 变体的 vLLM wheel 包：

```bash
uv pip install vllm --extra-index-url https://wheels.vllm.ai/rocm/0.15.0/rocm700
```

!!! warning "使用 `pip` 的注意事项"

    我们建议使用 `uv` 来安装 vLLM wheel 包。使用 `pip` 从自定义索引安装较为繁琐，因为 `pip` 会合并来自 `--extra-index-url` 和默认索引的包，仅选择最新版本，这使得如果所有包的精确版本都被明确指定，则很难从自定义索引安装 wheel 包。相比之下，`uv` 会给额外索引[比默认索引更高的优先级](https://docs.astral.sh/uv/pip/compatibility/#packages-that-exist-on-multiple-indexes)。

    如果您坚持使用 `pip`，则必须指定确切的 vLLM 版本和 wheel 路径的完整 URL `https://wheels.vllm.ai/rocm/<version>/<rocm-variant>`（可从网页获取）。

    ```bash
    pip install vllm==0.15.0+rocm700 --extra-index-url https://wheels.vllm.ai/rocm/0.15.0/rocm700
    ```

# --8<-- [end:pre-built-wheels]
# --8<-- [start:build-wheel-from-source]

!!! tip
    - 如果您发现以下安装步骤对您不起作用，请参考 [docker/Dockerfile.rocm_base](https://github.com/vllm-project/vllm/blob/main/docker/Dockerfile.rocm_base)。Dockerfile 是一种安装步骤的形式。

0. 安装先决条件（如果您已经处于安装了以下内容的 environment/docker 中，请跳过此步骤）：

    - [ROCm](https://rocm.docs.amd.com/en/latest/deploy/linux/index.html)
    - [PyTorch](https://pytorch.org/)

    要安装 PyTorch，您可以从一个全新的 docker 镜像开始，例如 `rocm/pytorch:rocm7.0_ubuntu22.04_py3.10_pytorch_release_2.8.0`、`rocm/pytorch-nightly`。如果您使用的是 docker 镜像，可以跳到第 3 步。

    或者，您可以使用 PyTorch wheel 包安装 PyTorch。您可以查看 PyTorch [入门指南](https://pytorch.org/get-started/locally/)中的 PyTorch 安装指南。例如：

    ```bash
    # 安装 PyTorch
    pip uninstall torch -y
    pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/nightly/rocm7.0
    ```

1. 安装 [适用于 ROCm 的 Triton](https://github.com/ROCm/triton.git)

    按照 [ROCm/triton](https://github.com/ROCm/triton.git) 的说明安装 ROCm 的 Triton

    ```bash
    python3 -m pip install ninja cmake wheel pybind11
    pip uninstall -y triton
    git clone https://github.com/ROCm/triton.git
    cd triton
    # git checkout $TRITON_BRANCH
    git checkout f9e5bf54
    if [ ! -f setup.py ]; then cd python; fi
    python3 setup.py install
    cd ../..
    ```

    !!! note
        - 经过验证的 `$TRITON_BRANCH` 可以在 [docker/Dockerfile.rocm_base](https://github.com/vllm-project/vllm/blob/main/docker/Dockerfile.rocm_base) 中找到。
        - 如果您在构建 triton 期间遇到与下载包相关的 HTTP 问题，请重试，因为 HTTP 错误是间歇性的。

2. 可选地，如果您选择使用 CK flash attention，您可以安装 [适用于 ROCm 的 flash attention](https://github.com/Dao-AILab/flash-attention.git)

    按照 [ROCm/flash-attention](https://github.com/Dao-AILab/flash-attention#amd-rocm-support) 的说明安装 ROCm 的 flash attention (v2.8.0)

    例如，对于 ROCm 7.0，假设您的 gfx 架构是 `gfx942`。要获取您的 gfx 架构，请运行 `rocminfo |grep gfx`。

    ```bash
    git clone https://github.com/Dao-AILab/flash-attention.git
    cd flash-attention
    # git checkout $FA_BRANCH
    git checkout 0e60e394
    git submodule update --init
    GPU_ARCHS="gfx942" python3 setup.py install
    cd ..
    ```

    !!! note
        - 经过验证的 `$FA_BRANCH` 可以在 [docker/Dockerfile.rocm_base](https://github.com/vllm-project/vllm/blob/main/docker/Dockerfile.rocm_base) 中找到。


3. 可选地，如果您选择自行构建 AITER 以使用特定分支或提交，您可以使用以下步骤构建 AITER：

    ```bash
    python3 -m pip uninstall -y aiter
    git clone --recursive https://github.com/ROCm/aiter.git
    cd aiter
    git checkout $AITER_BRANCH_OR_COMMIT
    git submodule sync; git submodule update --init --recursive
    python3 setup.py develop
    ```

    !!! note
        - 您需要根据您的目的配置 `$AITER_BRANCH_OR_COMMIT`。
        - 经过验证的 `$AITER_BRANCH_OR_COMMIT` 可以在 [docker/Dockerfile.rocm_base](https://github.com/vllm-project/vllm/blob/main/docker/Dockerfile.rocm_base) 中找到。


4. 可选地，如果您想使用 MORI 进行 EP 或 PD 解聚，您可以使用以下步骤安装 [MORI](https://github.com/ROCm/mori)：

    ```bash
    git clone https://github.com/ROCm/mori.git
    cd mori
    git checkout $MORI_BRANCH_OR_COMMIT
    git submodule sync; git submodule update --init --recursive
    MORI_GPU_ARCHS="gfx942;gfx950" python3 setup.py install
    ```

    !!! note
        - 您需要根据您的目的配置 `$MORI_BRANCH_OR_COMMIT`。
        - 经过验证的 `$MORI_BRANCH_OR_COMMIT` 可以在 [docker/Dockerfile.rocm_base](https://github.com/vllm-project/vllm/blob/main/docker/Dockerfile.rocm_base) 中找到。


5. 构建 vLLM。例如，可以使用以下步骤构建 ROCM 7.0 上的 vLLM：

    ???+ console "命令"

        ```bash
        pip install --upgrade pip

        # 构建并安装 AMD SMI
        pip install /opt/rocm/share/amd_smi

        # 安装依赖项
        pip install --upgrade numba \
            scipy \
            huggingface-hub[cli,hf_transfer] \
            setuptools_scm
        pip install -r requirements/rocm.txt

        # 要为单一架构（例如 MI300）构建以加快安装速度（推荐）：
        export PYTORCH_ROCM_ARCH="gfx942"

        # 要为多个架构 MI210/MI250/MI300 构建 vLLM，请改用此命令
        # export PYTORCH_ROCM_ARCH="gfx90a;gfx942"

        python3 setup.py develop
        ```

    这可能需要 5-10 分钟。目前，从源代码安装 vLLM 时，`pip install .` 在 ROCm 上不起作用。

    !!! tip
        - 理想情况下，PyTorch 的 ROCm 版本应与 ROCm 驱动程序版本匹配。

!!! tip
    - 对于 MI300x (gfx942) 用户，要实现最佳性能，请参考 [MI300x 调优指南](https://rocm.docs.amd.com/en/latest/how-to/tuning-guides/mi300x/index.html)，了解系统和工作流级别的性能优化和调优技巧。
      对于 vLLM，请参考 [vLLM 性能优化](https://rocm.docs.amd.com/en/latest/how-to/rocm-for-ai/inference-optimization/vllm-optimization.html)。

# --8<-- [end:build-wheel-from-source]
# --8<-- [start:pre-built-images]

#### 使用 vLLM 的官方 Docker 镜像

vLLM 提供了一个官方 Docker 镜像用于部署。  
该镜像可用于运行兼容 OpenAI 的服务器，并可在 Docker Hub 上以 [vllm/vllm-openai-rocm](https://hub.docker.com/r/vllm/vllm-openai-rocm/tags) 的形式获取。

???+ console "命令"
    ```bash
    docker run --rm \
        --group-add=video \
        --cap-add=SYS_PTRACE \
        --security-opt seccomp=unconfined \
        --device /dev/kfd \
        --device /dev/dri \
        -v ~/.cache/huggingface:/root/.cache/huggingface \
        --env "HF_TOKEN=$HF_TOKEN" \
        -p 8000:8000 \
        --ipc=host \
        vllm/vllm-openai-rocm:latest \
        --model Qwen/Qwen3-0.6B
    ```

若要将该 Docker 镜像作为开发基础镜像使用，可通过覆盖 entrypoint 以交互模式启动容器。

???+ console "命令"
    ```bash
    docker run --rm -it \
        --group-add=video \
        --cap-add=SYS_PTRACE \
        --security-opt seccomp=unconfined \
        --device /dev/kfd \
        --device /dev/dri \
        -v ~/.cache/huggingface:/root/.cache/huggingface \
        --env "HF_TOKEN=$HF_TOKEN" \
        -p 8000:8000 \
        --ipc=host \
        --entrypoint bash \
        vllm/vllm-openai-rocm:latest
    ```


#### 使用 AMD 提供的 Docker 镜像

[AMD Infinity Hub 中的 vLLM 镜像](https://hub.docker.com/r/rocm/vllm/tags) 提供了一个预构建且经过优化的 Docker 镜像，专为在 AMD Instinct™ MI300X 加速器上验证推理性能而设计。  
AMD 还提供每日构建的预编译镜像，可在 [Docker Hub](https://hub.docker.com/r/rocm/vllm-dev) 上获取，该镜像已安装 vLLM 及其所有依赖项。此镜像的 entrypoint 为 `/bin/bash`（与 vLLM 官方 Docker 镜像不同）。

???+ console "命令"
    ```bash
    docker pull rocm/vllm-dev:nightly # 获取最新镜像
    docker run -it --rm \
    --network=host \
    --group-add=video \
    --ipc=host \
    --cap-add=SYS_PTRACE \
    --security-opt seccomp=unconfined \
    --device /dev/kfd \
    --device /dev/dri \
    -v <path/to/your/models>:/app/models \
    -e HF_HOME="/app/models" \
    rocm/vllm-dev:nightly
    ```

!!! tip
    请查阅 [在 AMD Instinct MI300X 上进行 LLM 推理性能验证](https://rocm.docs.amd.com/en/latest/how-to/performance-validation/mi300x/vllm-benchmark.html)  
    以了解如何使用此预构建 Docker 镜像的详细说明。

# --8<-- [end:pre-built-images]
# --8<-- [start:build-image-from-source]

推荐通过源码构建 Docker 镜像的方式在 ROCm 环境下使用 vLLM。

??? info "（可选）构建包含 ROCm 软件栈的镜像"

    可通过 [docker/Dockerfile.rocm_base](https://github.com/vllm-project/vllm/blob/main/docker/Dockerfile.rocm_base) 构建一个包含 vLLM 所需 ROCm 软件栈的 Docker 镜像。  
    **此步骤为可选，因为该 rocm_base 镜像通常已预构建并存储在 [Docker Hub](https://hub.docker.com/r/rocm/vllm-dev) 上，标签为 `rocm/vllm-dev:base`，以便提升用户体验。**  
    若您选择自行构建此 rocm_base 镜像，步骤如下：

    用户必须使用 buildkit 启动 docker build。可在调用 docker build 命令时设置环境变量 `DOCKER_BUILDKIT=1`，或在 Docker 守护进程配置文件 `/etc/docker/daemon.json` 中启用 buildkit 并重启守护进程：

    ```json
    {
        "features": {
            "buildkit": true
        }
    }
    ```

    若要在 ROCm 7.0 上为 MI200 和 MI300 系列构建 vLLM，可使用默认配置：

    ```bash
    DOCKER_BUILDKIT=1 docker build \
        -f docker/Dockerfile.rocm_base \
        -t rocm/vllm-dev:base .
    ```

#### 构建包含 vLLM 的镜像

首先，基于 [docker/Dockerfile.rocm](https://github.com/vllm-project/vllm/blob/main/docker/Dockerfile.rocm) 构建 Docker 镜像，并从该镜像启动容器。  
用户必须使用 buildkit 启动 docker build。可在调用 docker build 命令时设置环境变量 `DOCKER_BUILDKIT=1`，或在 Docker 守护进程配置文件 `/etc/docker/daemon.json` 中启用 buildkit 并重启守护进程：

```json
{
    "features": {
        "buildkit": true
    }
}
```

[docker/Dockerfile.rocm](https://github.com/vllm-project/vllm/blob/main/docker/Dockerfile.rocm) 默认使用 ROCm 7.0，但也支持旧版 vLLM 分支中的 ROCm 5.7、6.0、6.1、6.2、6.3 和 6.4。  
该 Dockerfile 提供了以下参数以灵活定制镜像构建：

- `BASE_IMAGE`：指定运行 `docker build` 时使用的基镜像。默认值 `rocm/vllm-dev:base` 是由 AMD 发布和维护的镜像，基于 [docker/Dockerfile.rocm_base](https://github.com/vllm-project/vllm/blob/main/docker/Dockerfile.rocm_base) 构建。
- `ARG_PYTORCH_ROCM_ARCH`：允许覆盖基镜像中的 gfx 架构值。

这些参数的值可通过 `docker build` 命令的 `--build-arg` 选项传入。

若要在 ROCm 7.0 上为 MI200 和 MI300 系列构建 vLLM，可使用默认配置（构建一个以 `vllm serve` 为 entrypoint 的 Docker 镜像）：

???+ console "命令"
    ```bash
    DOCKER_BUILDKIT=1 docker build -f docker/Dockerfile.rocm -t vllm-rocm .
    ```

运行上述 `vllm-rocm` 镜像的命令如下：

???+ console "命令"
    ```bash
    docker run -it \
    --network=host \
    --group-add=video \
    --ipc=host \
    --cap-add=SYS_PTRACE \
    --security-opt seccomp=unconfined \
    --device /dev/kfd \
    --device /dev/dri \
    -v <path/to/model>:/app/model \
    vllm-rocm \
    --model Qwen/Qwen3-0.6B
    ```

其中 `<path/to/model>` 是模型存储的路径，例如 llama2 或 llama3 模型的权重文件所在位置。

# --8<-- [end:build-image-from-source]
# --8<-- [start:supported-features]

请参阅 [功能 × 硬件](../../features/README.md#feature-x-hardware) 兼容性矩阵以了解功能支持信息。

# --8<-- [end:supported-features]