# 并行化与扩展

## 单模型副本的分布式推理策略

要为单个模型副本选择合适的分布式推理策略，请遵循以下准则：

- **单 GPU（无分布式推理）：** 如果模型可以放入单个 GPU，则可能不需要分布式推理。直接在 GPU 上运行推理。
- **单节点多 GPU（使用张量并行推理）：** 如果模型无法放入单个 GPU，但可以放入具有多个 GPU 的单个节点，请使用*张量并行*。例如，在使用具有 4 个 GPU 的节点时，设置 `tensor_parallel_size=4`。
- **多节点多 GPU（使用张量并行和流水线并行推理）：** 如果模型无法放入单个节点，请结合使用*张量并行*和*流水线并行*。将 `tensor_parallel_size` 设置为每个节点的 GPU 数量，将 `pipeline_parallel_size` 设置为节点数量。例如，在使用 2 个节点（每个节点 8 个 GPU）时，设置 `tensor_parallel_size=8` 和 `pipeline_parallel_size=2`。

增加 GPU 和节点数量，直到有足够的 GPU 内存来容纳模型。将 `tensor_parallel_size` 设置为每个节点的 GPU 数量，将 `pipeline_parallel_size` 设置为节点数量。

在配置足够的资源以容纳模型后，运行 `vllm`。查找如下日志消息：

```text
INFO 07-23 13:56:04 [kv_cache_utils.py:775] GPU KV cache size: 643,232 tokens
INFO 07-23 13:56:04 [kv_cache_utils.py:779] Maximum concurrency for 40,960 tokens per request: 15.70x
```

`GPU KV cache size` 行报告了 GPU KV 缓存一次可以存储的总 token 数。`Maximum concurrency` 行提供了对并发请求数量的估计，前提是每个请求需要指定数量的 token（上例中为 40,960）。每个请求的 token 数取自模型配置中的最大序列长度 `ModelConfig.max_model_len`。如果这些数字低于您的吞吐量要求，请向集群添加更多 GPU 或节点。

!!! note "边缘情况：不均匀的 GPU 划分"
    如果模型可以放入单个节点，但 GPU 数量不能均匀划分模型大小，请启用流水线并行，它沿着层划分模型并支持不均匀划分。在这种情况下，设置 `tensor_parallel_size=1`，并将 `pipeline_parallel_size` 设置为 GPU 数量。此外，如果节点上的 GPU 没有 NVLINK 互连（例如 L40S），请使用流水线并行而不是张量并行，以获得更高的吞吐量和更低的通信开销。

### *专家混合* (*MoE*) 模型的分布式服务

利用专家的固有并行性通常是有益的，可以为专家层使用单独的并行策略。vLLM 支持将数据并行注意力与专家或张量并行 MoE 层相结合的大规模部署。更多信息，请参阅[数据并行部署](data_parallel_deployment.md)。

## 单节点部署

vLLM 支持分布式张量并行和流水线并行推理和服务。实现包括 [Megatron-LM 的张量并行算法](https://arxiv.org/pdf/1909.08053.pdf)。

默认的分布式运行时是 [Ray](https://github.com/ray-project/ray)（用于多节点推理）和原生 Python `multiprocessing`（用于单节点推理）。您可以通过在 `LLM` 类中设置 `distributed_executor_backend` 或在 API 服务器中设置 `--distributed-executor-backend` 来覆盖默认设置。使用 `mp` 表示 `multiprocessing`，使用 `ray` 表示 Ray。

对于多 GPU 推理，请在 `LLM` 类中设置 `tensor_parallel_size` 为所需的 GPU 数量。例如，要在 4 个 GPU 上运行推理：

```python
from vllm import LLM
llm = LLM("facebook/opt-13b", tensor_parallel_size=4)
output = llm.generate("San Francisco is a")
```

对于多 GPU 服务，请在启动服务器时包含 `--tensor-parallel-size`。例如，要在 4 个 GPU 上运行 API 服务器：

```bash
vllm serve facebook/opt-13b \
     --tensor-parallel-size 4
```

要启用流水线并行，请添加 `--pipeline-parallel-size`。例如，要在 8 个 GPU 上使用流水线并行和张量并行运行 API 服务器：

```bash
# 总共八个 GPU
vllm serve gpt2 \
     --tensor-parallel-size 4 \
     --pipeline-parallel-size 2
```

## 多节点部署

如果单个节点没有足够的 GPU 来容纳模型，请在多个节点上部署 vLLM。确保每个节点提供相同的执行环境，包括模型路径和 Python 包。建议使用容器镜像，因为它们提供了一种方便的方式来保持环境一致并隐藏主机异构性。

### Ray 是什么？

Ray 是一个用于扩展 Python 程序的分布式计算框架。多节点 vLLM 部署可以使用 Ray 作为运行时引擎。

vLLM 使用 Ray 来管理跨多个节点的任务分布式执行，并控制执行发生的位置。

Ray 还为大规模[离线批处理推理](https://docs.ray.io/en/latest/data/working-with-llms.html)和[在线服务](https://docs.ray.io/en/latest/serve/llm)提供了高级 API，可以利用 vLLM 作为引擎。这些 API 为 vLLM 工作负载添加了生产级容错、扩展和分布式可观测性。

详细信息，请参阅 [Ray 文档](https://docs.ray.io/en/latest/index.html)。

### 使用容器设置 Ray 集群

辅助脚本 [examples/online_serving/run_cluster.sh](../../examples/online_serving/run_cluster.sh) 跨节点启动容器并初始化 Ray。默认情况下，脚本在没有管理权限的情况下运行 Docker，这会阻止在分析或跟踪时访问 GPU 性能计数器。要启用管理权限，请将 `--cap-add=CAP_SYS_ADMIN` 标志添加到 Docker 命令。

选择一个节点作为头节点并运行：

```bash
bash run_cluster.sh \
                vllm/vllm-openai \
                <HEAD_NODE_IP> \
                --head \
                /path/to/the/huggingface/home/in/this/node \
                -e VLLM_HOST_IP=<HEAD_NODE_IP>
```

在每个工作节点上，运行：

```bash
bash run_cluster.sh \
                vllm/vllm-openai \
                <HEAD_NODE_IP> \
                --worker \
                /path/to/the/huggingface/home/in/this/node \
                -e VLLM_HOST_IP=<WORKER_NODE_IP>
```

请注意，`VLLM_HOST_IP` 对每个工作节点都是唯一的。保持运行这些命令的 shell 处于打开状态；关闭任何 shell 都会终止集群。确保所有节点都可以通过其 IP 地址相互通信。

!!! warning "网络安全"
    为了安全起见，请将 `VLLM_HOST_IP` 设置为私有网段上的地址。通过此网络发送的流量未加密，并且端点交换的数据格式可能会被利用来执行任意代码（如果攻击者获得网络访问权限）。确保不受信任的方无法访问该网络。

从任何节点进入容器并运行 `ray status` 和 `ray list nodes` 以验证 Ray 是否找到预期数量的节点和 GPU。

!!! tip
    或者，使用 KubeRay 设置 Ray 集群。更多信息，请参阅 [KubeRay vLLM 文档](https://docs.ray.io/en/latest/cluster/kubernetes/examples/rayserve-llm-example.html)。

### 在 Ray 集群上运行 vLLM

!!! tip
    如果 Ray 在容器内运行，请在*容器内*（而不是主机上）运行本指南其余部分的命令。要打开容器内的 shell，请连接到一个节点并使用 `docker exec -it <container_name> /bin/bash`。

一旦 Ray 集群运行，就可以像在单节点设置中一样使用 vLLM。Ray 集群中的所有资源对 vLLM 都是可见的，因此单个节点上的单个 `vllm` 命令就足够了。

常见的做法是将张量并行大小设置为每个节点的 GPU 数量，将流水线并行大小设置为节点数量。例如，如果您有 2 个节点上的 16 个 GPU（每个节点 8 个 GPU），请将张量并行大小设置为 8，将流水线并行大小设置为 2：

```bash
vllm serve /path/to/the/model/in/the/container \
    --tensor-parallel-size 8 \
    --pipeline-parallel-size 2 \
    --distributed-executor-backend ray
```

或者，您可以将 `tensor_parallel_size` 设置为集群中 GPU 的总数：

```bash
vllm serve /path/to/the/model/in/the/container \
     --tensor-parallel-size 16 \
     --distributed-executor-backend ray
```

### 使用多进程运行 vLLM

除了 Ray，多节点 vLLM 部署也可以使用 `multiprocessing` 作为运行时引擎。以下是一个在 2 个节点（每个节点 8 个 GPU）上部署模型的示例，其中 `tp_size=8` 且 `pp_size=2`。

选择一个节点作为主节点并运行：

```bash
vllm serve /path/to/the/model/in/the/container \
  --tensor-parallel-size 8 --pipeline-parallel-size 2 \
  --nnodes 2 --node-rank 0 \
  --master-addr <HEAD_NODE_IP>
```

在另一个工作节点上运行：

```bash
vllm serve /path/to/the/model/in/the/container \
  --tensor-parallel-size 8 --pipeline-parallel-size 2 \
  --nnodes 2 --node-rank 1 \
  --master-addr <HEAD_NODE_IP> --headless
```

## 优化张量并行性的网络通信

高效的张量并行性需要快速的节点间通信，最好通过高速网络适配器（如 InfiniBand）实现。
要设置集群以使用 InfiniBand，请在 [examples/online_serving/run_cluster.sh](../../examples/online_serving/run_cluster.sh) 辅助脚本中附加额外参数，例如 `--privileged -e NCCL_IB_HCA=mlx5`。
有关所需标志的更多信息，请联系您的系统管理员。

## 启用 GPUDirect RDMA

GPUDirect RDMA（远程直接内存访问）是 NVIDIA 的一项技术，允许网络适配器直接访问 GPU 内存，绕过 CPU 和系统内存。这种直接访问可降低延迟和 CPU 开销，有利于跨节点 GPU 之间的大数据传输。

要在 vLLM 中启用 GPUDirect RDMA，请配置以下设置：

- `IPC_LOCK` 安全上下文：将 `IPC_LOCK` 能力添加到容器的安全上下文中，以锁定内存页并防止交换到磁盘。
- 使用 `/dev/shm` 的共享内存：在 Pod 规范中挂载 `/dev/shm`，为进程间通信（IPC）提供共享内存。

如果使用 Docker，请按以下方式设置容器：

```bash
docker run --gpus all \
    --ipc=host \
    --shm-size=16G \
    -v /dev/shm:/dev/shm \
    vllm/vllm-openai
```

如果使用 Kubernetes，请按以下方式设置 Pod 规范：

```yaml
...
spec:
  containers:
    - name: vllm
      image: vllm/vllm-openai
      securityContext:
        capabilities:
          add: ["IPC_LOCK"]
      volumeMounts:
        - mountPath: /dev/shm
          name: dshm
      resources:
        limits:
          nvidia.com/gpu: 8
        requests:
          nvidia.com/gpu: 8
  volumes:
    - name: dshm
      emptyDir:
        medium: Memory
...
```

!!! tip "确认 GPUDirect RDMA 操作"
    要确认您的 InfiniBand 卡是否正在使用 GPUDirect RDMA，请使用详细的 NCCL 日志运行 vLLM：`NCCL_DEBUG=TRACE vllm serve ...`。

    然后查找 NCCL 版本和使用的网络。

    - 如果在日志中找到 `[send] via NET/IB/GDRDMA`，则 NCCL 正在使用带有 GPUDirect RDMA 的 InfiniBand，这*是*高效的。
    - 如果在日志中找到 `[send] via NET/Socket`，则 NCCL 使用了原始 TCP 套接字，这对于跨节点张量并行性*不*高效。

!!! tip "预下载 Hugging Face 模型"
    如果使用 Hugging Face 模型，建议在启动 vLLM 之前下载模型。在每个节点上将模型下载到相同路径，或将模型存储在所有节点均可访问的分布式文件系统上。然后将模型路径传递给模型，而不是仓库 ID。否则，请通过将 `-e HF_TOKEN=<TOKEN>` 附加到 `run_cluster.sh` 来提供 Hugging Face 令牌。

## 分布式部署故障排除

有关分布式调试的信息，请参阅 [分布式部署故障排除](distributed_troubleshooting.md)。