# --8<-- [start:installation]

vLLM 对 IBM Z 平台上的 s390x 架构提供实验性支持。目前，用户必须从源码构建才能在 IBM Z 平台上原生运行。

目前，s390x 架构的 CPU 实现仅支持 FP32 数据类型。

# --8<-- [end:installation]
# --8<-- [start:requirements]

- 操作系统: `Linux`
- SDK: 带命令行工具的 `gcc/g++ >= 12.3.0` 或更高版本
- 指令集架构 (ISA): 需要支持 VXE。适用于 Z14 及以上版本。
- 构建安装 Python 包: `pyarrow`、`torch` 和 `torchvision`

# --8<-- [end:requirements]
# --8<-- [start:set-up-using-python]

# --8<-- [end:set-up-using-python]
# --8<-- [start:pre-built-wheels]

目前没有预构建的 IBM Z CPU 轮子文件。

# --8<-- [end:pre-built-wheels]
# --8<-- [start:build-wheel-from-source]

在构建 vLLM 之前，请先从包管理器安装以下软件包。例如在 RHEL 9.4 上：

```bash
dnf install -y \
    which procps findutils tar vim git gcc g++ make patch make cython zlib-devel \
    libjpeg-turbo-devel libtiff-devel libpng-devel libwebp-devel freetype-devel harfbuzz-devel \
    openssl-devel openblas openblas-devel wget autoconf automake libtool cmake numactl-devel
```

安装 `outlines-core` 和 `uvloop` Python 包所需的 rust>=1.80：

```bash
curl https://sh.rustup.rs -sSf | sh -s -- -y && \
    . "$HOME/.cargo/env"
```

执行以下命令从源码构建并安装 vLLM。

!!! tip
    请在构建 vLLM 之前先从源码构建以下依赖项：`torchvision`、`pyarrow`。

```bash
    sed -i '/^torch/d' requirements/build.txt    # 从 requirements/build.txt 中移除 torch，因为我们使用夜间构建
    uv pip install -v \
        --torch-backend auto \
        -r requirements/build.txt \
        -r requirements/cpu.txt \
    VLLM_TARGET_DEVICE=cpu python setup.py bdist_wheel && \
        uv pip install dist/*.whl
```

??? console "pip"
    ```bash
        sed -i '/^torch/d' requirements/build.txt    # 从 requirements/build.txt 中移除 torch，因为我们使用夜间构建
        pip install -v \
            --extra-index-url https://download.pytorch.org/whl/nightly/cpu \
            -r requirements/build.txt \
            -r requirements/cpu.txt \
        VLLM_TARGET_DEVICE=cpu python setup.py bdist_wheel && \
            pip install dist/*.whl
    ```

# --8<-- [end:build-wheel-from-source]
# --8<-- [start:pre-built-images]

目前没有预构建的 IBM Z CPU 镜像。

# --8<-- [end:pre-built-images]
# --8<-- [start:build-image-from-source]

```bash
docker build -f docker/Dockerfile.s390x \
    --tag vllm-cpu-env .

# 启动 OpenAI 服务器
docker run --rm \
    --privileged true \
    --shm-size 4g \
    -p 8000:8000 \
    -e VLLM_CPU_KVCACHE_SPACE=<KV cache space> \
    -e VLLM_CPU_OMP_THREADS_BIND=<CPU cores for inference> \
    vllm-cpu-env \
    --model meta-llama/Llama-3.2-1B-Instruct \
    --dtype float \
    other vLLM OpenAI server arguments
```

!!! tip
    `--privileged true` 的替代方案是 `--cap-add SYS_NICE --security-opt seccomp=unconfined`。

# --8<-- [end:build-image-from-source]
# --8<-- [start:extra-information]
# --8<-- [end:extra-information]