# --8<-- [start:installation]
vLLM 在 Arm CPU 平台上提供基础的模型推理和服务功能，支持 NEON、FP32、FP16 和 BF16 数据类型。
# --8<-- [end:installation]

# --8<-- [start:requirements]
- 操作系统：Linux
- 编译器：`gcc/g++ >= 12.3.0`（可选，推荐）
- 指令集架构（ISA）：需要支持 NEON
# --8<-- [end:requirements]

# --8<-- [start:set-up-using-python]
# --8<-- [end:set-up-using-python]

# --8<-- [start:pre-built-wheels]
自 0.11.2 版本起，vLLM 提供适用于 Arm 的预编译 wheel 包。这些 wheel 包包含预编译的 C++ 二进制文件。

```bash
export VLLM_VERSION=$(curl -s https://api.github.com/repos/vllm-project/vllm/releases/latest | jq -r .tag_name | sed 's/^v//')
uv pip install https://github.com/vllm-project/vllm/releases/download/v${VLLM_VERSION}/vllm-${VLLM_VERSION}+cpu-cp38-abi3-manylinux_2_35_aarch64.whl
```

??? console "pip"
    ```bash
    pip install https://github.com/vllm-project/vllm/releases/download/v${VLLM_VERSION}/vllm-${VLLM_VERSION}+cpu-cp38-abi3-manylinux_2_35_aarch64.whl
    ```

!!! warning "设置 `LD_PRELOAD`"
    在使用通过 wheel 包安装的 vLLM CPU 版本之前，请确保已安装 TCMalloc 并将其添加到 `LD_PRELOAD`：

    ```bash
    # install TCMalloc
    sudo apt-get install -y --no-install-recommends libtcmalloc-minimal4
    # manually find the path
    sudo find / -iname *libtcmalloc_minimal.so.4
    TC_PATH=...
    # add them to LD_PRELOAD
    export LD_PRELOAD="$TC_PATH:$LD_PRELOAD"
    ```

`uv` 方式适用于 vLLM `v0.6.6` 及更高版本。`uv` 的一个独特功能是，`--extra-index-url` 中的包具有[比默认索引更高的优先级](https://docs.astral.sh/uv/pip/compatibility/#packages-that-exist-on-multiple-indexes)。如果最新的公开发布版本是 `v0.6.6.post1`，`uv` 的行为允许通过指定 `--extra-index-url` 来安装 `v0.6.6.post1` 之前的某个提交版本。相比之下，`pip` 会合并来自 `--extra-index-url` 和默认索引的包，并只选择最新版本，这使得安装发布版本之前的开发版本变得困难。

**安装最新代码**

LLM 推理是一个快速发展的领域，最新代码可能包含尚未发布的错误修复、性能改进和新功能。为了让用户无需等待下一次发布即可试用最新代码，vLLM 为自 `v0.11.2` 以来的每一次提交提供了可用的预编译 Arm CPU wheel 包，可在 <https://wheels.vllm.ai/nightly> 获取。

对于原生 CPU wheel 包，应使用以下索引：

* `https://wheels.vllm.ai/nightly/cpu/vllm`

要从 nightly 索引安装，请运行：

```bash
uv pip install vllm --extra-index-url https://wheels.vllm.ai/nightly/cpu --index-strategy first-index
```

??? console "pip（有一个注意事项）"
    不支持使用 `pip` 从 nightly 索引安装，因为 `pip` 会合并来自 `--extra-index-url` 和默认索引的包，并只选择最新版本，这使得安装发布版本之前的开发版本变得困难。相比之下，`uv` 给予额外索引[比默认索引更高的优先级](https://docs.astral.sh/uv/pip/compatibility/#packages-that-exist-on-multiple-indexes)。

    如果您坚持使用 `pip`，则必须指定 wheel 文件的完整 URL（链接地址）（可从 https://wheels.vllm.ai/nightly/cpu/vllm 获取）。

    ```bash
    pip install https://wheels.vllm.ai/4fa7ce46f31cbd97b4651694caf9991cc395a259/vllm-0.13.0rc2.dev104%2Bg4fa7ce46f.cpu-cp38-abi3-manylinux_2_35_aarch64.whl
    # current nightly build (the filename will change!)
    ```

**安装特定版本**

如果您想获取之前提交的 wheel 包（例如，用于二分查找行为变更、性能回归），可以在 URL 中指定提交哈希：

```bash
export VLLM_COMMIT=730bd35378bf2a5b56b6d3a45be28b3092d26519 # use full commit hash from the main branch
uv pip install vllm --extra-index-url https://wheels.vllm.ai/${VLLM_COMMIT}/cpu --index-strategy first-index
```
# --8<-- [end:pre-built-wheels]

# --8<-- [start:build-wheel-from-source]
首先，安装推荐的编译器。我们建议使用 `gcc/g++ >= 12.3.0` 作为默认编译器，以避免潜在问题。例如，在 Ubuntu 22.4 上，您可以运行：

```bash
sudo apt-get update -y
sudo apt-get install -y --no-install-recommends ccache git curl wget ca-certificates gcc-12 g++-12 libtcmalloc-minimal4 libnuma-dev ffmpeg libsm6 libxext6 libgl1 jq lsof
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 10 --slave /usr/bin/g++ g++ /usr/bin/g++-12
```

其次，克隆 vLLM 项目：

```bash
git clone https://github.com/vllm-project/vllm.git vllm_source
cd vllm_source
```

第三，安装所需的依赖项：

```bash
uv pip install -r requirements/cpu-build.txt --torch-backend cpu
uv pip install -r requirements/cpu.txt --torch-backend cpu
```

??? console "pip"
    ```bash
    pip install --upgrade pip
    pip install -v -r requirements/cpu-build.txt --extra-index-url https://download.pytorch.org/whl/cpu
    pip install -v -r requirements/cpu.txt --extra-index-url https://download.pytorch.org/whl/cpu
    ```

最后，构建并安装 vLLM：

```bash
VLLM_TARGET_DEVICE=cpu uv pip install . --no-build-isolation
```

如果您想开发 vLLM，请改用可编辑模式安装。

```bash
VLLM_TARGET_DEVICE=cpu uv pip install -e . --no-build-isolation
```

已在 AWS Graviton3 实例上进行了兼容性测试。

!!! warning "设置 `LD_PRELOAD`"
    在使用通过 wheel 包安装的 vLLM CPU 版本之前，请确保已安装 TCMalloc 并将其添加到 `LD_PRELOAD`：

    ```bash
    # install TCMalloc
    sudo apt-get install -y --no-install-recommends libtcmalloc-minimal4
    # manually find the path
    sudo find / -iname *libtcmalloc_minimal.so.4
    TC_PATH=...
    # add them to LD_PRELOAD
    export LD_PRELOAD="$TC_PATH:$LD_PRELOAD"
    ```
# --8<-- [end:build-wheel-from-source]

# --8<-- [start:pre-built-images]
有关使用官方 Docker 镜像的说明，请参阅[使用 Docker](../../deployment/docker.md)。

从 0.12.0 版本开始，vLLM 为 Arm 预构建稳定的 Docker 镜像。可用的镜像标签请参见：[https://gallery.ecr.aws/q9t5s3a7/vllm-arm64-cpu-release-repo](https://gallery.ecr.aws/q9t5s3a7/vllm-arm64-cpu-release-repo)。

```bash
export VLLM_VERSION=$(curl -s https://api.github.com/repos/vllm-project/vllm/releases/latest | jq -r .tag_name | sed 's/^v//')
docker pull public.ecr.aws/q9t5s3a7/vllm-arm64-cpu-release-repo:v${VLLM_VERSION}
```

您也可以使用 Docker 镜像获取最新代码。这些镜像不适用于生产环境，仅用于 CI 和测试。它们将在几天后过期。最新代码可能包含错误，可能不够稳定。请谨慎使用。

```bash
export VLLM_COMMIT=6299628d326f429eba78736acb44e76749b281f5 # use full commit hash from the main branch
docker pull public.ecr.aws/q9t5s3a7/vllm-ci-postmerge-repo:${VLLM_COMMIT}-arm64-cpu
```
# --8<-- [end:pre-built-images]

# --8<-- [start:build-image-from-source]
```bash
docker build -f docker/Dockerfile.cpu \
    --tag vllm-cpu-env .

# Launching OpenAI server
docker run --rm \
    --privileged=true \
    --shm-size=4g \
    -p 8000:8000 \
    -e VLLM_CPU_KVCACHE_SPACE=<KV cache space> \
    -e VLLM_CPU_OMP_THREADS_BIND=<CPU cores for inference> \
    vllm-cpu-env \
    --model=meta-llama/Llama-3.2-1B-Instruct \
    --dtype=bfloat16 \
    other vLLM OpenAI server arguments
```

!!! tip
    `--privileged=true` 的替代方案是 `--cap-add SYS_NICE --security-opt seccomp=unconfined`。
# --8<-- [end:build-image-from-source]

# --8<-- [start:extra-information]
# --8<-- [end:extra-information]