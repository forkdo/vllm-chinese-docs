# --8<-- [start:installation]

vLLM 支持在 x86 CPU 平台上进行基础模型推理和服务，支持的数据类型包括 FP32、FP16 和 BF16。

# --8<-- [end:installation]
# --8<-- [start:requirements]

- 操作系统：Linux
- CPU 标志：`avx512f`（推荐）、`avx512_bf16`（可选）、`avx512_vnni`（可选）

!!! tip
    使用 `lscpu` 命令检查 CPU 标志。

# --8<-- [end:requirements]
# --8<-- [start:set-up-using-python]

# --8<-- [end:set-up-using-python]
# --8<-- [start:pre-built-wheels]

自 v0.13.0 版本起，vLLM 提供了支持 AVX512 的 x86 预构建 wheel 包。要安装发布版本的 wheel 包，请执行：

```bash
export VLLM_VERSION=$(curl -s https://api.github.com/repos/vllm-project/vllm/releases/latest | jq -r .tag_name | sed 's/^v//')

# 使用 uv
uv pip install https://github.com/vllm-project/vllm/releases/download/v${VLLM_VERSION}/vllm-${VLLM_VERSION}+cpu-cp38-abi3-manylinux_2_35_x86_64.whl --torch-backend cpu
```
??? console "pip"
    ```bash
    # 使用 pip
    pip install https://github.com/vllm-project/vllm/releases/download/v${VLLM_VERSION}/vllm-${VLLM_VERSION}+cpu-cp38-abi3-manylinux_2_35_x86_64.whl --extra-index-url https://download.pytorch.org/whl/cpu
    ```
!!! warning "设置 `LD_PRELOAD`"
    在使用通过 wheel 包安装的 vLLM CPU 版本前，请确保已安装 TCMalloc 和 Intel OpenMP，并将其添加到 `LD_PRELOAD` 环境变量中：
    ```bash
    # 安装 TCMalloc，Intel OpenMP 会随 vLLM CPU 一起安装
    sudo apt-get install -y --no-install-recommends libtcmalloc-minimal4

    # 手动查找路径
    sudo find / -iname *libtcmalloc_minimal.so.4
    sudo find / -iname *libiomp5.so
    TC_PATH=...
    IOMP_PATH=...

    # 将其添加到 LD_PRELOAD
    export LD_PRELOAD="$TC_PATH:$IOMP_PATH:$LD_PRELOAD"
    ```

**安装最新代码**

要安装基于最新 main 分支构建的 wheel 包：

```bash
uv pip install vllm --extra-index-url https://wheels.vllm.ai/nightly/cpu --index-strategy first-index --torch-backend cpu
```

**安装特定版本**

如果您需要访问之前提交的 wheel 包（例如为了二分查找行为变更或性能退化问题），可以在 URL 中指定提交哈希值：

```bash
export VLLM_COMMIT=730bd35378bf2a5b56b6d3a45be28b3092d26519 # 使用 main 分支的完整提交哈希
uv pip install vllm --extra-index-url https://wheels.vllm.ai/${VLLM_COMMIT}/cpu --index-strategy first-index --torch-backend cpu
```

# --8<-- [end:pre-built-wheels]
# --8<-- [start:build-wheel-from-source]

安装推荐的编译器。我们建议使用 `gcc/g++ >= 12.3.0` 作为默认编译器以避免潜在问题。例如在 Ubuntu 22.4 上，可以运行：

```bash
sudo apt-get update -y
sudo apt-get install -y gcc-12 g++-12 libnuma-dev
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 10 --slave /usr/bin/g++ g++ /usr/bin/g++-12
```

--8<-- "docs/getting_started/installation/python_env_setup.inc.md"

克隆 vLLM 项目：

```bash
git clone https://github.com/vllm-project/vllm.git vllm_source
cd vllm_source
```

安装所需依赖：

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

构建并安装 vLLM：

```bash
VLLM_TARGET_DEVICE=cpu uv pip install . --no-build-isolation
```

如果您要开发 vLLM，请改用可编辑模式安装：

```bash
VLLM_TARGET_DEVICE=cpu uv pip install -e . --no-build-isolation
```

（可选）构建一个可移植的 wheel 包，以便在其他地方安装：

```bash
VLLM_TARGET_DEVICE=cpu uv build --wheel
```

```bash
uv pip install dist/*.whl
```

??? console "pip"
    ```bash
    VLLM_TARGET_DEVICE=cpu python -m build --wheel --no-isolation
    ```

    ```bash
    pip install dist/*.whl
    ```

!!! warning "设置 `LD_PRELOAD`"
    在使用通过 wheel 包安装的 vLLM CPU 版本前，请确保已安装 TCMalloc 和 Intel OpenMP，并将其添加到 `LD_PRELOAD` 环境变量中：
    ```bash
    # 安装 TCMalloc，Intel OpenMP 会随 vLLM CPU 一起安装
    sudo apt-get install -y --no-install-recommends libtcmalloc-minimal4

    # 手动查找路径
    sudo find / -iname *libtcmalloc_minimal.so.4
    sudo find / -iname *libiomp5.so
    TC_PATH=...
    IOMP_PATH=...

    # 将其添加到 LD_PRELOAD
    export LD_PRELOAD="$TC_PATH:$IOMP_PATH:$LD_PRELOAD"
    ```

!!! example "故障排除"
    - **NumPy ≥2.0 错误**：使用 `pip install "numpy<2.0"` 降级。
    - **CMake 检测到 CUDA**：添加 `CMAKE_DISABLE_FIND_PACKAGE_CUDA=ON` 以防止在 CPU 构建过程中检测到 CUDA（即使已安装 CUDA）。
    - `AMD` 处理器需要至少第 4 代（Zen 4/Genoa）或更高版本才能支持 [AVX512](https://www.phoronix.com/review/amd-zen4-avx512)，从而在 CPU 上运行 vLLM。
    - 如果您收到类似 `Could not find a version that satisfies the requirement torch==X.Y.Z+cpu+cpu` 的错误，请考虑更新 [pyproject.toml](https://github.com/vllm-project/vllm/blob/main/pyproject.toml) 以帮助 pip 解析依赖关系。
    ```toml title="pyproject.toml"
    [build-system]
    requires = [
      "cmake>=3.26.1",
      ...
      "torch==X.Y.Z+cpu"   # <-------
    ]
    ```

# --8<-- [end:build-wheel-from-source]
# --8<-- [start:pre-built-images]

[https://gallery.ecr.aws/q9t5s3a7/vllm-cpu-release-repo](https://gallery.ecr.aws/q9t5s3a7/vllm-cpu-release-repo)

!!! warning
    如果在没有 `avx512f`、`avx512_bf16` 或 `avx512_vnni` 支持的机器上部署预构建镜像，可能会引发 `非法指令` 错误。请参阅下面的“从源码构建镜像”部分，了解如何根据目标 CPU 能力设置构建参数。

# --8<-- [end:pre-built-images]
# --8<-- [start:build-image-from-source]

## 为目标 CPU 构建

```bash
docker build -f docker/Dockerfile.cpu \
        --build-arg VLLM_CPU_DISABLE_AVX512=<false (默认)|true> \
        --build-arg VLLM_CPU_AVX2=<false (默认)|true> \
        --build-arg VLLM_CPU_AVX512=<false (默认)|true> \
        --build-arg VLLM_CPU_AVX512BF16=<false (默认)|true> \
        --build-arg VLLM_CPU_AVX512VNNI=<false (默认)|true> \
        --build-arg VLLM_CPU_AMXBF16=<false|true (默认)> \
        --tag vllm-cpu-env \
        --target vllm-openai .
```

!!! note "默认自动检测"
    默认情况下，CPU 指令集（AVX512、AVX2 等）会根据构建系统的 CPU 标志自动检测。构建参数如 `VLLM_CPU_AVX2`、`VLLM_CPU_AVX512`、`VLLM_CPU_AVX512BF16`、`VLLM_CPU_AVX512VNNI` 和 `VLLM_CPU_AMXBF16` 用于交叉编译：

    - `VLLM_CPU_{ISA}=true` - 强制启用该指令集（无论构建系统能力如何，均使用 ISA 构建）
    - `VLLM_CPU_{ISA}=false` - 依赖自动检测（默认）

### 示例

**自动检测构建（默认）**

```bash
docker build -f docker/Dockerfile.cpu --tag vllm-cpu-env --target vllm-openai .
```

**为 AVX512 交叉编译**

```bash
docker build -f docker/Dockerfile.cpu \
        --build-arg VLLM_CPU_AVX512=true \
        --build-arg VLLM_CPU_AVX512BF16=true \
        --build-arg VLLM_CPU_AVX512VNNI=true \
        --tag vllm-cpu-avx512 \
        --target vllm-openai .
```

**为 AVX2 交叉编译**

```bash
docker build -f docker/Dockerfile.cpu \
        --build-arg VLLM_CPU_AVX2=true \
        --tag vllm-cpu-avx2 \
        --target vllm-openai .
```

## 启动 OpenAI 服务器

```bash
docker run --rm \
            --security-opt seccomp=unconfined \
            --cap-add SYS_NICE \
            --shm-size=4g \
            -p 8000:8000 \
            -e VLLM_CPU_KVCACHE_SPACE=<KV 缓存空间> \
            vllm-cpu-env \
            meta-llama/Llama-3.2-1B-Instruct \
            --dtype=bfloat16 \
            其他 vLLM OpenAI 服务器参数
```

# --8<-- [end:build-image-from-source]
# --8<-- [start:extra-information]
# --8<-- [end:extra-information]