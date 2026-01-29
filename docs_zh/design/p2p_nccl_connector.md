# P2P NCCL 连接器

这是一个基于点对点通信、部分受 Dynamo 启发的 xPyD 实现，支持动态扩缩容。

## 详细设计

### 整体流程

如图 1 所示，该 **PD 解耦** 解决方案的整体流程通过请求流描述如下：

1. 客户端向 Proxy/Router 的 `/v1/completions` 接口发送 HTTP 请求。
2. Proxy/Router 通过轮询或随机选择方式选取一个 **1P1D（1 个 Prefill 实例 + 1 个 Decode 实例）**，生成一个 `request_id`（规则将在后文介绍），将 HTTP 请求消息中的 `max_tokens` 修改为 **1**，然后将请求转发给 **P 实例**。
3. 紧接着，Proxy/Router 将**原始 HTTP 请求**转发给 **D 实例**。
4. **P 实例**执行 **Prefill**，然后**主动将生成的 KV 缓存**发送给 D 实例（使用 **PUT_ASYNC** 模式）。D 实例的 `zmq_addr` 可通过 `request_id` 解析得到。
5. **D 实例**有一个**专用线程**用于接收 KV 缓存（避免阻塞主进程）。接收到的 KV 缓存会保存到 **GPU 内存缓冲区**中，其大小由 vLLM 启动参数 `kv_buffer_size` 决定。当 GPU 缓冲区满时，KV 缓存会存储在**本地张量内存池**中。
6. 在 **Decode** 过程中，D 实例的主进程会从 **GPU 缓冲区**或**内存池**中检索 KV 缓存（由 P 实例传输而来），从而**跳过 Prefill**。
7. 完成 **Decode** 后，D 实例将结果返回给 **Proxy/Router**，再由 Proxy/Router 转发给**客户端**。

![image1](https://github.com/user-attachments/assets/fb01bde6-755b-49f7-ad45-48a94b1e10a7)

### Proxy/Router（演示版）

一个简单的 HTTP 服务作为客户端请求的入口，并启动一个后台线程监听 P/D 实例上报其 HTTP IP 和 PORT，以及 ZMQ IP 和 PORT。它维护一个 `http_addr -> zmq_addr` 的字典。其中，`http_addr` 是 vLLM 实例请求的 IP:PORT，而 `zmq_addr` 是用于 KV 缓存握手和元数据接收的地址。

Proxy/Router 负责根据客户端请求的特征（如 prompt）选择 1P1D，并生成对应的 `request_id`，例如：

```text
cmpl-___prefill_addr_10.0.1.2:21001___decode_addr_10.0.1.3:22001_93923d63113b4b338973f24d19d4bf11-0
```

目前，为了快速验证 xPyD 是否能工作，采用的是轮询方式选择 1P1D。未来计划结合 trie 结构和实例的负载状态来选择合适的 P 和 D。

每个 P/D 实例会定期向 Proxy/Router 发送心跳包（目前每 3 秒一次），用于注册（即上报 `http_addr -> zmq_addr`）并保持连接活跃。如果某个实例崩溃且在一段时间内未能发送心跳，Proxy/Router 将移除超时的实例（此功能尚未开发）。

### KV 缓存传输方式

KVCache 传输有三种方式：PUT、GET 和 PUT_ASYNC。这些方式可通过 `--kv-transfer-config` 和 `kv_connector_extra_config` 参数指定，具体通过 `send_type` 字段设置。PUT 和 PUT_ASYNC 均为 P 实例主动向 D 实例发送 KVCache，区别在于 PUT 是同步传输方式，会阻塞主进程，而 PUT_ASYNC 是异步传输方式。PUT_ASYNC 使用专用线程发送 KVCache，因此不会阻塞主进程。相比之下，GET 方式则是 P 实例在计算 prefill 后将 KVCache 保存到内存缓冲区，D 实例在为其 KVCache 分配空间后主动从 P 实例拉取已计算的 KVCache。

实验结果表明，这些方式的性能从高到低依次为：PUT_ASYNC → GET → PUT。

### 通过 ZMQ 和 NCCL 实现 P2P 通信

只要知道对端的地址，即可执行点对点 KV 缓存传输（使用 NCCL），不受 rank 和 world size 的限制。这支持 PD 解耦场景下的实例动态扩缩容，即添加或移除 P/D 实例无需全系统重启。

每个 P/D 实例只需创建一个 `P2pNcclEngine` 实例。该实例维护一个 ZMQ Server，运行专用线程监听 `zmq_addr` 地址，接收来自其他实例的控制流请求。这些请求包括建立 NCCL 连接的请求和发送 KVCache 元数据（如张量形状和数据类型）的请求，但不实际传输 KVCache 数据本身。

当 P 实例和 D 实例首次传输 KVCache 时，需要建立 ZMQ 连接和 NCCL 组。后续的 KVCache 传输将复用该 ZMQ 连接和 NCCL 组。NCCL 组仅包含两个 rank，即 world size 等于 2。此设计旨在支持动态扩缩容，即添加或移除 P/D 实例无需全系统重启。只要知道对端地址，即可执行点对点 KVCache 传输，不受 rank 或 world size 限制。

### NCCL 组拓扑结构

目前仅支持对称 TP（张量并行）方式进行 KVCache 传输。未来将支持非对称 TP 和 PP（流水线并行）方式。图 2 展示了 1P2D 配置，其中每个实例的 TP（张量并行）度为 2。总共有 7 个 NCCL 组：三个 vLLM 实例各自拥有一个 TP=2 的 NCCL 组。此外，P 实例的第 0 块 GPU 卡与每个 D 实例的第 0 块 GPU 卡建立一个 NCCL 组。类似地，P 实例的第 1 块 GPU 卡与每个 D 实例的第 1 块 GPU 卡建立一个 NCCL 组。

![image2](https://github.com/user-attachments/assets/837e61d6-365e-4cbf-8640-6dd7ab295b36)

每个 NCCL 组会占用一定量的 GPU 内存缓冲区用于通信，其大小主要受 `NCCL_MAX_NCHANNELS` 环境变量影响。当 `NCCL_MAX_NCHANNELS=16` 时，一个 NCCL 组通常占用 100MB；当 `NCCL_MAX_NCHANNELS=8` 时，通常占用 52MB。对于大规模 xPyD 配置（如 DeepSeek 的 96P144D），当前实现尚不可行。未来我们考虑使用 RDMA 进行点对点通信，并持续关注 UCCL。

### GPU 内存缓冲区和张量内存池

内存缓冲区大小的权衡如下：对于 P 实例，在 PUT 和 PUT_ASYNC 模式下不需要内存缓冲区，但在 GET 模式下需要。对于 D 实例，三种模式下均需要内存缓冲区。D 实例的内存缓冲区不宜过大。同样，P 实例在 GET 模式下的内存缓冲区也不宜过大。D 实例的内存缓冲区用于临时存储 P 实例发送的 KVCache。如果过大，会减少 D 实例正常推理可用的 KVCache 空间，从而降低推理批处理大小，最终导致输出吞吐量下降。内存缓冲区大小由参数 `kv_buffer_size` 配置，单位为字节，通常设置为内存大小的 5%～10%。

如果 P 实例的 `--max-num-seqs` 参数设置较大，由于批处理规模大，P 实例会同时生成大量 KVCache。这可能超过 D 实例内存缓冲区的容量，导致 KVCache 丢失。一旦 KVCache 丢失，D 实例需要重新计算 Prefill，相当于执行两次 Prefill。因此，首 token 时间（TTFT）将显著增加，导致性能下降。

为了解决上述问题，我设计并开发了一个本地 Tensor 内存池用于存储 KVCache，灵感来源于 Linux 内存模块中使用的伙伴系统（buddy system）。由于内存足够大，通常在服务器上为 TB 级别，因此无需考虑前缀缓存或使用基于块的设计来复用内存，从而节省空间。当内存缓冲区不足时，KVCache 可以直接存储在 Tensor 内存池中，D 实例随后可以从中检索 KVCache。读写速度为 PCIe 的速度，PCIe 4.0 的速度约为 21 GB/s，通常比 Prefill 的速度更快。否则，就不需要 Mooncake 和 lmcache 等解决方案了。Tensor 内存池的作用类似于泄洪区，除了在流量突增时，通常不会被使用。在最坏情况下，我的解决方案性能不会比使用 Cache store 的正常情况更差。

## 安装 vLLM

```shell
pip install "vllm>=0.9.2"
```

## 运行 xPyD

### 使用说明

- 以下示例在 A800（80GB）设备上运行，使用 Meta-Llama-3.1-8B-Instruct 模型。
- 注意设置 `kv_buffer_size`（单位为字节）。经验值为 GPU 内存大小的 10%。这与 kvcache 的大小相关。如果设置过小，用于临时存储接收到的 kvcache 的 GPU 内存缓冲区会溢出，导致 kvcache 被存储到 tensor 内存池中，从而增加延迟。如果设置过大，可用于推理的 kvcache 会减少，导致 batch size 变小，吞吐量下降。
- 对于 Prefill 实例，在使用非 GET 模式时，`kv_buffer_size` 可以设置为 1，因为 Prefill 目前不需要接收 kvcache。但在使用 GET 模式时，需要更大的 `kv_buffer_size`，因为它需要存储发送到 D 实例的 kvcache。
- 你可能需要修改以下命令中的 `kv_buffer_size` 和 `port`（如果存在冲突）。
- `PUT_ASYNC` 提供最佳性能，应优先使用。
- `--port` 必须与 `--kv-transfer-config` 中的 `http_port` 保持一致。
- `disagg_proxy_p2p_nccl_xpyd.py` 脚本将使用端口 10001（用于接收客户端请求）和端口 30001（用于接收来自 P 和 D 实例的服务发现）。
- 运行 proxy 的节点必须安装 `quart`。
- 支持多节点；你只需修改 `--kv-transfer-config` 中的 `proxy_ip` 和 `proxy_port`。
- 在以下示例中，假设 **proxy 的 IP 为 10.0.1.1**。

### 运行 1P3D

#### Proxy（例如 10.0.1.1）

```shell
cd {your vllm directory}/examples/online_serving/disaggregated_serving_p2p_nccl_xpyd/
python3 disagg_proxy_p2p_nccl_xpyd.py &
```

#### Prefill1（例如 10.0.1.2 或 10.0.1.1）

??? console "命令"

    ```shell
    CUDA_VISIBLE_DEVICES=0 vllm serve {your model directory} \
        --host 0.0.0.0 \
        --port 20001 \
        --tensor-parallel-size 1 \
        --seed 1024 \
        --served-model-name base_model \
        --dtype float16 \
        --max-model-len 10000 \
        --max-num-batched-tokens 10000 \
        --max-num-seqs 256 \
        --trust-remote-code \
        --gpu-memory-utilization 0.9 \
        --kv-transfer-config \
        '{"kv_connector":"P2pNcclConnector","kv_role":"kv_producer","kv_buffer_size":"1e1","kv_port":"21001","kv_connector_extra_config":{"proxy_ip":"10.0.1.1","proxy_port":"30001","http_port":"20001"}}' > /var/vllm.log 2>&1 &
    ```

#### Decode1（例如 10.0.1.3 或 10.0.1.1）

??? console "命令"

    ```shell
    CUDA_VISIBLE_DEVICES=1 vllm serve {your model directory} \
        --host 0.0.0.0 \
        --port 20002 \
        --tensor-parallel-size 1 \
        --seed 1024 \
        --served-model-name base_model \
        --dtype float16 \
        --max-model-len 10000 \
        --max-num-batched-tokens 10000 \
        --max-num-seqs 256 \
        --trust-remote-code \
        --gpu-memory-utilization 0.7 \
        --kv-transfer-config \
        '{"kv_connector":"P2pNcclConnector","kv_role":"kv_consumer","kv_buffer_size":"8e9","kv_port":"22001","kv_connector_extra_config":{"proxy_ip":"10.0.1.1","proxy_port":"30001","http_port":"20002"}}' > /var/vllm.log 2>&1 &
    ```

#### Decode2（例如 10.0.1.4 或 10.0.1.1）

??? console "命令"

    ```shell
    CUDA_VISIBLE_DEVICES=2 vllm serve {your model directory} \
        --host 0.0.0.0 \
        --port 20003 \
        --tensor-parallel-size 1 \
        --seed 1024 \
        --served-model-name base_model \
        --dtype float16 \
        --max-model-len 10000 \
        --max-num-batched-tokens 10000 \
        --max-num-seqs 256 \
        --trust-remote-code \
        --gpu-memory-utilization 0.7 \
        --kv-transfer-config \
        '{"kv_connector":"P2pNcclConnector","kv_role":"kv_consumer","kv_buffer_size":"8e9","kv_port":"23001","kv_connector_extra_config":{"proxy_ip":"10.0.1.1","proxy_port":"30001","http_port":"20003"}}' > /var/vllm.log 2>&1 &
    ```

#### Decode3（例如 10.0.1.5 或 10.0.1.1）

??? console "命令"

    ```shell
    CUDA_VISIBLE_DEVICES=3 vllm serve {your model directory} \
        --host 0.0.0.0 \
        --port 20004 \
        --tensor-parallel-size 1 \
        --seed 1024 \
        --served-model-name base_model \
        --dtype float16 \
        --max-model-len 10000 \
        --max-num-batched-tokens 10000 \
        --max-num-seqs 256 \
        --trust-remote-code \
        --gpu-memory-utilization 0.7 \
        --kv-transfer-config \
        '{"kv_connector":"P2pNcclConnector","kv_role":"kv_consumer","kv_buffer_size":"8e9","kv_port":"24001","kv_connector_extra_config":{"proxy_ip":"10.0.1.1","proxy_port":"30001","http_port":"20004"}}' > /var/vllm.log 2>&1 &
    ```

### 运行 3P1D

#### Proxy（例如 10.0.1.1）

```shell
cd {your vllm directory}/examples/online_serving/disaggregated_serving_p2p_nccl_xpyd/
python3 disagg_proxy_p2p_nccl_xpyd.py &
```

#### Prefill1（例如 10.0.1.2 或 10.0.1.1）

??? console "命令"

    ```shell
    CUDA_VISIBLE_DEVICES=0 vllm serve {your model directory} \
        --host 0.0.0.0 \
        --port 20001 \
        --tensor-parallel-size 1 \
        --seed 1024 \
        --served-model-name base_model \
        --dtype float16 \
        --max-model-len 10000 \
        --max-num-batched-tokens 10000 \
        --max-num-seqs 256 \
        --trust-remote-code \
        --gpu-memory-utilization 0.9 \
        --kv-transfer-config \
        '{"kv_connector":"P2pNcclConnector","kv_role":"kv_producer","kv_buffer_size":"1e1","kv_port":"21001","kv_connector_extra_config":{"proxy_ip":"10.0.1.1","proxy_port":"30001","http_port":"20001"}}' > /var/vllm.log 2>&1 &
    ```

#### Prefill2（例如 10.0.1.3 或 10.0.1.1）

??? console "命令"

    ```shell
    CUDA_VISIBLE_DEVICES=1 vllm serve {your model directory} \
        --host 0.0.0.0 \
        --port 20002 \
        --tensor-parallel-size 1 \
        --seed 1024 \
        --served-model-name base_model \
        --dtype float16 \
        --max-model-len 10000 \
        --max-num-batched-tokens 10000 \
        --max-num-seqs 256 \
        --trust-remote-code \
        --gpu-memory-utilization 0.9 \
        --kv-transfer-config \
        '{"kv_connector":"P2pNcclConnector","kv_role":"kv_producer","kv_buffer_size":"1e1","kv_port":"22001","kv_connector_extra_config":{"proxy_ip":"10.0.1.1","proxy_port":"30001","http_port":"20002"}}' > /var/vllm.log 2>&1 &
    ```

#### Prefill3（例如 10.0.1.4 或 10.0.1.1）

??? console "命令"

    ```shell
    CUDA_VISIBLE_DEVICES=2 vllm serve {your model directory} \
        --host 0.0.0.0 \
        --port 20003 \
        --tensor-parallel-size 1 \
        --seed 1024 \
        --served-model-name base_model \
        --dtype float16 \
        --max-model-len 10000 \
        --max-num-batched-tokens 10000 \
        --max-num-seqs 256 \
        --trust-remote-code \
        --gpu-memory-utilization 0.9 \
        --kv-transfer-config \
        '{"kv_connector":"P2pNcclConnector","kv_role":"kv_producer","kv_buffer_size":"1e1","kv_port":"23001","kv_connector_extra_config":{"proxy_ip":"10.0.1.1","proxy_port":"30001","http_port":"20003"}}' > /var/vllm.log 2>&1 &
    ```

#### Decode1（例如 10.0.1.5 或 10.0.1.1）

??? console "命令"

    ```shell
    CUDA_VISIBLE_DEVICES=3 vllm serve {your model directory} \
        --host 0.0.0.0 \
        --port 20004 \
        --tensor-parallel-size 1 \
        --seed 1024 \
        --served-model-name base_model \
        --dtype float16 \
        --max-model-len 10000 \
        --max-num-batched-tokens 10000 \
        --max-num-seqs 256 \
        --trust-remote-code \
        --gpu-memory-utilization 0.7 \
        --kv-transfer-config \
        '{"kv_connector":"P2pNcclConnector","kv_role":"kv_consumer","kv_buffer_size":"8e9","kv_port":"24001","kv_connector_extra_config":{"proxy_ip":"10.0.1.1","proxy_port":"30001","http_port":"20004"}}' > /var/vllm.log 2>&1 &
    ```

## 单次请求

```shell
curl -X POST -s http://10.0.1.1:10001/v1/completions \
-H "Content-Type: application/json" \
-d '{
    "model": "base_model",
    "prompt": "San Francisco is a",
    "max_tokens": 10,
    "temperature": 0
}'
```

## 基准测试

??? console "命令"

    ```shell
    vllm bench serve \
        --backend vllm \
        --model base_model \
        --tokenizer meta-llama/Llama-3.1-8B-Instruct \
        --dataset-name "random" \
        --host 10.0.1.1 \
        --port 10001 \
        --random-input-len 1024 \
        --random-output-len 1024 \
        --ignore-eos \
        --burstiness 100 \
        --percentile-metrics "ttft,tpot,itl,e2el" \
        --metric-percentiles "90,95,99" \
        --seed $(date +%s) \
        --trust-remote-code \
        --request-rate 3 \
        --num-prompts 1000
    ```

## 关闭服务

```shell
pgrep python | xargs kill -9 && pkill -f python
```

## 测试数据

### **场景**：1K 输入 & 200 输出 token，端到端 P99 延迟约 2 秒

![testdata](https://github.com/user-attachments/assets/cef0953b-4567-4bf9-b940-405b92a28eb1)