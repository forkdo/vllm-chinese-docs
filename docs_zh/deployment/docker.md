# 使用 Docker

## 使用 vLLM 官方 Docker 镜像

vLLM 提供了一个用于部署的官方 Docker 镜像。  
该镜像可用于运行兼容 OpenAI 的服务器，并在 Docker Hub 上以 [vllm/vllm-openai](https://hub.docker.com/r/vllm/vllm-openai/tags) 的形式提供。

```bash
docker run --runtime nvidia --gpus all \
    -v ~/.cache/huggingface:/root/.cache/huggingface \
    --env "HF_TOKEN=$HF_TOKEN" \
    -p 8000:8000 \
    --ipc=host \
    vllm/vllm-openai:latest \
    --model Qwen/Qwen3-0.6B
```

该镜像也可以与其他容器引擎（如 [Podman](https://podman.io/)）一起使用。

```bash
podman run --device nvidia.com/gpu=all \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  --env "HF_TOKEN=$HF_TOKEN" \
  -p 8000:8000 \
  --ipc=host \
  docker.io/vllm/vllm-openai:latest \
  --model Qwen/Qwen3-0.6B
```

你可以在镜像标签（`vllm/vllm-openai:latest`）之后添加任何你需要的 [engine-args](../configuration/engine_args.md)。

!!! note
    你可以使用 `ipc=host` 标志或 `--shm-size` 标志来允许容器访问主机的共享内存。vLLM 使用 PyTorch，而 PyTorch 在底层使用共享内存来在进程之间共享数据，尤其是在张量并行推理时。

!!! note
    为了避免许可问题（例如 <https://github.com/vllm-project/vllm/issues/8030>），可选依赖项未包含在镜像中。

    如果你需要使用这些依赖项（已接受许可条款），请在基础镜像之上创建一个自定义 Dockerfile，并添加一个安装这些依赖项的额外层：

    ```Dockerfile
    FROM vllm/vllm-openai:v0.11.0

    # 例如：安装 `audio` 可选依赖项
    # 注意：请确保 vLLM 的版本与基础镜像匹配！
    RUN uv pip install --system vllm[audio]==0.11.0
    ```

!!! tip
    某些新模型可能仅在 [HF Transformers](https://github.com/huggingface/transformers) 的主分支中可用。

    要使用 `transformers` 的开发版本，请在基础镜像之上创建一个自定义 Dockerfile，并添加一个从源码安装其代码的额外层：

    ```Dockerfile
    FROM vllm/vllm-openai:latest

    RUN uv pip install --system git+https://github.com/huggingface/transformers.git
    ```

## 从源码构建 vLLM 的 Docker 镜像

你可以通过提供的 [docker/Dockerfile](../../docker/Dockerfile) 从源码构建并运行 vLLM。要构建 vLLM，请执行以下命令：

```bash
# 可选参数：--build-arg max_jobs=8 --build-arg nvcc_threads=2
DOCKER_BUILDKIT=1 docker build . \
    --target vllm-openai \
    --tag vllm/vllm-openai \
    --file docker/Dockerfile
```

!!! note
    默认情况下，vLLM 会为所有 GPU 类型构建，以实现最广泛的兼容性。如果你只是想为当前机器运行的 GPU 类型构建，可以添加参数 `--build-arg torch_cuda_arch_list=""`，vLLM 会自动检测当前 GPU 类型并为其构建。

    如果你使用的是 Podman 而不是 Docker，可能需要在运行 `podman build` 命令时添加 `--security-opt label=disable` 以禁用 SELinux 标签，以避免某些[已知问题](https://github.com/containers/buildah/discussions/4184)。

!!! note
    如果你没有修改任何 C++ 或 CUDA 内核代码，可以使用预编译的 wheel 文件来显著减少 Docker 构建时间。

    *   **启用该功能**：添加构建参数 `--build-arg VLLM_USE_PRECOMPILED="1"`。
    *   **工作原理**：默认情况下，vLLM 会自动从我们的[每日构建](../contributing/ci/nightly_builds.md)中找到正确的 wheel 文件，方法是使用与上游 `main` 分支的合并基础提交。
    *   **覆盖提交**：要使用特定提交的 wheel 文件，请提供 `--build-arg VLLM_PRECOMPILED_WHEEL_COMMIT=<commit_hash>` 参数。

    详细说明请参考[从源码构建 wheel](../contributing/ci/nightly_builds.md#precompiled-wheels-usage) 文档中的“使用纯 Python 构建（无需编译）”部分，这些参数类似。

## 为 Arm64/aarch64 构建

可以为 aarch64 系统（如 Nvidia Grace-Hopper 和 Grace-Blackwell）构建 Docker 容器。使用 `--platform "linux/arm64"` 标志将为 arm64 构建。

!!! note
    需要编译多个模块，因此此过程可能需要一些时间。建议使用 `--build-arg max_jobs=` 和 `--build-arg nvcc_threads=` 标志来加速构建过程。但请确保 `max_jobs` 远大于 `nvcc_threads` 以获得最大收益。  
    注意并行作业时的内存使用情况，因为它可能非常大（见下面的示例）。

??? console "命令"

    ```bash
    # 在 Nvidia GH200 服务器上构建的示例。（内存使用：~15GB，构建时间：~1475s / ~25 分钟，镜像大小：6.93GB）
    DOCKER_BUILDKIT=1 docker build . \
    --file docker/Dockerfile \
    --target vllm-openai \
    --platform "linux/arm64" \
    -t vllm/vllm-gh200-openai:latest \
    --build-arg max_jobs=66 \
    --build-arg nvcc_threads=2 \
    --build-arg torch_cuda_arch_list="9.0 10.0+PTX" \
    --build-arg RUN_WHEEL_CHECK=false
    ```

对于 (G)B300，我们推荐使用 CUDA 13，如下面的命令所示。

??? console "命令"

    ```bash
    DOCKER_BUILDKIT=1 docker build \
    --build-arg CUDA_VERSION=13.0.1 \
    --build-arg BUILD_BASE_IMAGE=nvidia/cuda:13.0.1-devel-ubuntu22.04 \
    --build-arg max_jobs=256 \
    --build-arg nvcc_threads=2 \
    --build-arg RUN_WHEEL_CHECK=false \
    --build-arg torch_cuda_arch_list='9.0 10.0+PTX' \
    --platform "linux/arm64" \
    --tag vllm/vllm-gb300-openai:latest \
    --target vllm-openai \
    -f docker/Dockerfile \
    .
    ```

!!! note
    如果你在非 ARM 主机（例如 x86_64 机器）上构建 `linux/arm64` 镜像，需要确保你的系统已使用 QEMU 设置好交叉编译。这允许你的主机模拟 ARM64 执行。

    在主机上运行以下命令以注册 QEMU 用户静态处理程序：

    ```bash
    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
    ```

    设置好 QEMU 后，你可以在 `docker build` 命令中使用 `--platform "linux/arm64"` 标志。

## 使用自定义构建的 vLLM Docker 镜像

要使用自定义构建的 Docker 镜像运行 vLLM：

```bash
docker run --runtime nvidia --gpus all \
    -v ~/.cache/huggingface:/root/.cache/huggingface \
    -p 8000:8000 \
    --env "HF_TOKEN=<secret>" \
    vllm/vllm-openai <args...>
```

参数 `vllm/vllm-openai` 指定要运行的镜像，应替换为自定义构建镜像的名称（即构建命令中的 `-t` 标签）。

!!! note
    **仅适用于版本 0.4.1 和 0.4.2** - 这些版本的 vLLM Docker 镜像需要在 root 用户下运行，因为在运行时需要加载 root 用户主目录下的一个库，即 `/root/.config/vllm/nccl/cu12/libnccl.so.2.18.1`。如果你在非 root 用户下运行容器，可能需要先更改该库（及其所有父目录）的权限，以允许该用户访问它，然后使用环境变量 `VLLM_NCCL_SO_PATH=/root/.config/vllm/nccl/cu12/libnccl.so.2.18.1` 运行 vLLM。