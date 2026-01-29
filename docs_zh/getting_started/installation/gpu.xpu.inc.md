# --8<-- [start:installation]

vLLM 最初支持在 Intel GPU 平台上进行基本的模型推理和服务。

# --8<-- [end:installation]
# --8<-- [start:requirements]

- 支持的硬件：Intel Data Center GPU，Intel ARC GPU
- OneAPI 要求：oneAPI 2025.1
- Python：3.12
!!! warning
    提供的 IPEX whl 是特定于 Python3.12 的，因此此版本是必需的。

# --8<-- [end:requirements]
# --8<-- [start:set-up-using-python]

对于此设备，暂无关于创建新 Python 环境的额外信息。

# --8<-- [end:set-up-using-python]
# --8<-- [start:pre-built-wheels]

目前，暂无预构建的 XPU 轮子。

# --8<-- [end:pre-built-wheels]
# --8<-- [start:build-wheel-from-source]

- 首先，安装必需的 [驱动程序](https://dgpu-docs.intel.com/driver/installation.html#installing-gpu-drivers) 和 [Intel OneAPI](https://www.intel.com/content/www/us/en/developer/tools/oneapi/base-toolkit.html) 2025.1 或更高版本。
- 其次，安装用于构建 vLLM XPU 后端的 Python 包：

```bash
git clone https://github.com/vllm-project/vllm.git
cd vllm
pip install --upgrade pip
pip install -v -r requirements/xpu.txt
```

- 然后，构建并安装 vLLM XPU 后端：

```bash
VLLM_TARGET_DEVICE=xpu python setup.py install
```

# --8<-- [end:build-wheel-from-source]
# --8<-- [start:pre-built-images]

目前，我们基于 vLLM 发布版本在 docker [hub](https://hub.docker.com/r/intel/vllm/tags) 上发布预构建的 XPU 镜像。欲了解更多信息，请参考发布 [说明](https://github.com/intel/ai-containers/blob/main/vllm)。

# --8<-- [end:pre-built-images]
# --8<-- [start:build-image-from-source]

```bash
docker build -f docker/Dockerfile.xpu -t vllm-xpu-env --shm-size=4g .
docker run -it \
             --rm \
             --network=host \
             --device /dev/dri:/dev/dri \
             -v /dev/dri/by-path:/dev/dri/by-path \
             --ipc=host \
             --privileged \
             vllm-xpu-env
```

# --8<-- [end:build-image-from-source]
# --8<-- [start:supported-features]

XPU 平台支持 **tensor parallel** 推理/服务，还支持 **pipeline parallel** 作为在线服务的 beta 功能。对于 **pipeline parallel**，我们支持在单节点上使用 mp 作为后端。例如，一个参考执行如下：

```bash
vllm serve facebook/opt-13b \
     --dtype=bfloat16 \
     --max_model_len=1024 \
     --distributed-executor-backend=mp \
     --pipeline-parallel-size=2 \
     -tp=8
```

默认情况下，如果系统中未检测到现有实例，将自动启动一个 ray 实例，其中 `num-gpus` 等于 `parallel_config.world_size`。我们建议在执行前适当启动一个 ray 集群，参考 [examples/online_serving/run_cluster.sh](https://github.com/vllm-project/vllm/blob/main/examples/online_serving/run_cluster.sh) 辅助脚本。

# --8<-- [end:supported-features]
# --8<-- [start:distributed-backend]

XPU 平台使用 **torch-ccl** 作为 torch<2.8 的分布式后端，使用 **xccl** 作为 torch>=2.8 的分布式后端，因为 torch 2.8 支持 XPU 的内置 **xccl** 后端。

# --8<-- [end:distributed-backend]