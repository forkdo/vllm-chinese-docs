# NixlConnector 使用指南

NixlConnector 是一个高性能的 KV 缓存传输连接器，专为 vLLM 的分散预填充功能设计。它利用 NIXL 库提供完全异步的发送/接收操作，实现高效的跨进程 KV 缓存传输。

## 前置条件

### 安装

安装 NIXL 库：`uv pip install nixl`，作为在 Nvidia 平台上的快速入门。

- 更多安装说明请参考 [NIXL 官方仓库](https://github.com/ai-dynamo/nixl)
- 指定必需的 NIXL 版本可在 [requirements/kv_connectors.txt](../../requirements/kv_connectors.txt) 和其他相关配置文件中找到

对于 ROCm 平台，[基础 ROCm docker 文件](../../docker/Dockerfile.rocm_base) 已包含 RIXL 和 ucx。

- 更多信息请参考 [RIXL 官方仓库](https://github.com/rocm/rixl)
- RIXL 的支持库可在 [requirements/kv_connectors_rocm.txt](../../requirements/kv_connectors_rocm.txt) 中找到
- 未来我们可能会从 docker 镜像文件中移除 RIXL，用户将能够从预编译的二进制包中安装

对于非 CUDA 平台，请按照以下说明从源码安装带有 ucx 的 nixl。

```bash
python tools/install_nixl_from_source_ubuntu.py
```

### 传输配置

NixlConnector 使用 NIXL 库进行底层通信，支持多种传输后端。UCX（Unified Communication X）是 NIXL 使用的主要默认传输库。配置传输环境变量：

```bash
# 示例 UCX 配置，根据您的环境进行调整
export UCX_TLS=all  # 或指定特定传输方式，如 "rc,ud,sm,^cuda_ipc" 等
export UCX_NET_DEVICES=all  # 或指定网络设备，如 "mlx5_0:1,mlx5_1:1"
```

!!! tip
    当使用 UCX 作为传输后端时，NCCL 环境变量（如 `NCCL_IB_HCA`、`NCCL_SOCKET_IFNAME`）不适用于 NixlConnector，因此请配置 UCX 特定的环境变量而不是 NCCL 变量。

## 基本使用（在同一主机上）

### 生产者（预填充器）配置

启动一个生成 KV 缓存的预填充器实例

```bash
# 第 1 块 GPU 作为预填充器
CUDA_VISIBLE_DEVICES=0 \
UCX_NET_DEVICES=all \
VLLM_NIXL_SIDE_CHANNEL_PORT=5600 \
vllm serve Qwen/Qwen3-0.6B \
  --port 8100 \
  --enforce-eager \
  --kv-transfer-config '{"kv_connector":"NixlConnector","kv_role":"kv_both","kv_load_failure_policy":"fail"}'
```

### 消费者（解码器）配置

启动一个消费 KV 缓存的解码器实例：

```bash
# 第 2 块 GPU 作为解码器
CUDA_VISIBLE_DEVICES=1 \
UCX_NET_DEVICES=all \
VLLM_NIXL_SIDE_CHANNEL_PORT=5601 \
vllm serve Qwen/Qwen3-0.6B \
  --port 8200 \
  --enforce-eager \
  --kv-transfer-config '{"kv_connector":"NixlConnector","kv_role":"kv_both","kv_load_failure_policy":"fail"}'
```

### 代理服务器

使用代理服务器在预填充器和解码器之间路由请求：

```bash
python tests/v1/kv_connector/nixl_integration/toy_proxy_server.py \
  --port 8192 \
  --prefiller-hosts localhost \
  --prefiller-ports 8100 \
  --decoder-hosts localhost \
  --decoder-ports 8200
```

## 环境变量

- `VLLM_NIXL_SIDE_CHANNEL_PORT`: NIXL 握手通信端口
    - 默认值：5600
    - **预填充器和解码器实例都需要**
    - 每个 vLLM 工作器在其主机上需要一个唯一的端口；在不同主机上使用相同的端口号是可以的
    - 对于 TP/DP 部署，节点上每个工作器的端口计算为：base_port + dp_rank（例如，使用 `--data-parallel-size=2` 和 base_port=5600，dp_rank 0..1 在该节点上使用端口 5600、5601）
    - 用于预填充器和解码器之间的初始 NIXL 握手

- `VLLM_NIXL_SIDE_CHANNEL_HOST`: 侧信道通信主机
    - 默认值："localhost"
    - 当预填充器和解码器位于不同机器上时进行设置
    - 连接信息通过 KVTransferParams 从预填充器传递给解码器以进行握手

- `VLLM_NIXL_ABORT_REQUEST_TIMEOUT`: 自动释放预填充器 KV 缓存的超时时间（秒）。（可选）
    - 默认值：480
    - 如果请求被中止且解码器尚未通过 nixl 通道读取 KV 缓存块，预填充实例将在此超时后释放其 KV 缓存块，以避免无限期持有。

## 多实例设置

### 不同机器上的多个预填充器实例

```bash
# 机器 A 上的预填充器 1（示例 IP：${IP1}）
VLLM_NIXL_SIDE_CHANNEL_HOST=${IP1} \
VLLM_NIXL_SIDE_CHANNEL_PORT=5600 \
UCX_NET_DEVICES=all \
vllm serve Qwen/Qwen3-0.6B --port 8000 \
  --tensor-parallel-size 8 \
  --kv-transfer-config '{"kv_connector":"NixlConnector","kv_role":"kv_producer","kv_load_failure_policy":"fail"}'

# 机器 B 上的预填充器 2（示例 IP：${IP2}）
VLLM_NIXL_SIDE_CHANNEL_HOST=${IP2} \
VLLM_NIXL_SIDE_CHANNEL_PORT=5600 \
UCX_NET_DEVICES=all \
vllm serve Qwen/Qwen3-0.6B --port 8000 \
  --tensor-parallel-size 8 \
  --kv-transfer-config '{"kv_connector":"NixlConnector","kv_role":"kv_producer","kv_load_failure_policy":"fail"}'
```

### 不同机器上的多个解码器实例

```bash
# 机器 C 上的解码器 1（示例 IP：${IP3}）
VLLM_NIXL_SIDE_CHANNEL_HOST=${IP3} \
VLLM_NIXL_SIDE_CHANNEL_PORT=5600 \
UCX_NET_DEVICES=all \
vllm serve Qwen/Qwen3-0.6B --port 8000 \
  --tensor-parallel-size 8 \
  --kv-transfer-config '{"kv_connector":"NixlConnector","kv_role":"kv_consumer","kv_load_failure_policy":"fail"}'

# 机器 D 上的解码器 2（示例 IP：${IP4}）
VLLM_NIXL_SIDE_CHANNEL_HOST=${IP4} \
VLLM_NIXL_SIDE_CHANNEL_PORT=5600 \
UCX_NET_DEVICES=all \
vllm serve Qwen/Qwen3-0.6B --port 8000 \
  --tensor-parallel-size 8 \
  --kv-transfer-config '{"kv_connector":"NixlConnector","kv_role":"kv_consumer","kv_load_failure_policy":"fail"}'
```

### 多实例代理

```bash
python tests/v1/kv_connector/nixl_integration/toy_proxy_server.py \
  --port 8192 \
  --prefiller-hosts ${IP1} ${IP2} \
  --prefiller-ports 8000 8000 \
  --decoder-hosts ${IP3} ${IP4} \
  --decoder-ports 8000 8000
```

对于多主机 DP 部署，只需提供头实例的主机/端口即可。

### KV 角色选项

- **kv_producer**: 用于生成 KV 缓存的预填充器实例
- **kv_consumer**: 用于从预填充器消费 KV 缓存的解码器实例
- **kv_both**: 启用对称功能，连接器可以同时充当生产者和消费者。这为实验性设置和角色区分未预先确定的场景提供了灵活性。

!!! tip
    NixlConnector 目前不区分 `kv_role`；实际的预填充器/解码器角色由上层代理决定（例如，`toy_proxy_server.py` 使用 `--prefiller-hosts` 和 `--decoder-hosts`）。
    因此，`--kv-transfer-config` 中的 `kv_role` 实际上是一个占位符，不影响 NixlConnector 的行为。

### KV 加载失败策略

`kv_load_failure_policy` 设置控制解码器实例从预填充器实例加载 KV 缓存块失败时系统如何处理：

- **fail**（推荐）：KV 加载失败时立即请求失败并报错。这通过避免在解码实例上重新计算预填充工作来防止性能下降。
- **recompute**（默认）：在解码实例上本地重新计算失败的块。这可能导致解码实例出现性能 _抖动_，因为计划的预填充会延迟并干扰其他解码操作。此外，解码实例通常配置了低延迟优化。

!!! warning
    使用 `kv_load_failure_policy="recompute"` 可能会导致生产部署中的性能下降。当 KV 加载失败时，解码实例将使用针对解码优化的配置执行预填充工作，这是低效的，违背了分散预填充的目的。这也增加了其他正在进行的解码请求的尾部延迟。

## 实验性功能

### 异构 KV 布局支持

支持用例：使用实验性配置以 'HND' 预填充和以 'NHD' 解码

```bash
--kv-transfer-config '{..., "enable_permute_local_kv":"True"}'
```

## 示例脚本/代码

请参考 vLLM 仓库中的这些示例脚本：

- [run_accuracy_test.sh](../../tests/v1/kv_connector/nixl_integration/run_accuracy_test.sh)
- [toy_proxy_server.py](../../tests/v1/kv_connector/nixl_integration/toy_proxy_server.py)
- [test_accuracy.py](../../tests/v1/kv_connector/nixl_integration/test_accuracy.py)