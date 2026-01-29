# MooncakeConnector 使用指南

## 关于 Mooncake

Mooncake 旨在通过在高速互联的 DRAM/SSD 资源上构建多级缓存池，提升大语言模型（LLMs）的推理效率，特别是在慢速对象存储环境中。与传统缓存系统相比，Mooncake 利用（GPUDirect）RDMA 技术以零拷贝方式直接传输数据，同时最大化利用单台机器上的多网卡（NIC）资源。更多关于 Mooncake 的详情，请参考 [Mooncake 项目](https://github.com/kvcache-ai/Mooncake) 和 [Mooncake 文档](https://kvcache-ai.github.io/Mooncake/)。

## 前提条件

### 安装

通过 pip 安装 mooncake：

`uv pip install mooncake-transfer-engine`

更多安装说明请参考 [Mooncake 官方仓库](https://github.com/kvcache-ai/Mooncake)。

## 使用方法

### Prefiller 节点 (192.168.0.2)

```bash
vllm serve Qwen/Qwen2.5-7B-Instruct --port 8010 --kv-transfer-config '{"kv_connector":"MooncakeConnector","kv_role":"kv_producer"}'
```

### Decoder 节点 (192.168.0.3)

```bash
vllm serve Qwen/Qwen2.5-7B-Instruct --port 8020 --kv-transfer-config '{"kv_connector":"MooncakeConnector","kv_role":"kv_consumer"}'
```

### 代理

```bash
python tests/v1/kv_connector/nixl_integration/toy_proxy_server.py --prefiller-host 192.168.0.2 --prefiller-port 8010 --decoder-host 192.168.0.3 --decoder-port 8020
```

> 注意：Mooncake Connector 目前使用来自 nixl_integration 的代理。未来将会替换为自研代理。现在你可以通过 8000 端口向代理服务器发送请求。

## 环境变量

- `VLLM_MOONCAKE_BOOTSTRAP_PORT`：Mooncake 引导服务器的端口
  - 默认值：8998
  - 仅 Prefiller 实例需要
  - 每个 vLLM 工作进程在其主机上需要一个唯一端口；在不同主机上使用相同的端口号是可以的
  - 对于 TP/DP 部署，节点上每个工作进程的端口计算方式为：base_port + dp_rank * tp_size + tp_rank
  - 用于 Decoder 通知 Prefiller

- `VLLM_MOONCAKE_ABORT_REQUEST_TIMEOUT`：自动释放 Prefiller 特定请求 KV 缓存的超时时间（秒）。（可选）
  - 默认值：480
  - 如果请求被中止且 Decoder 尚未通知 Prefiller，Prefill 实例将在该超时时间后释放其 KV 缓存块，以避免无限期持有。

## KV 角色选项

- **kv_producer**：用于生成 KV 缓存的 Prefiller 实例
- **kv_consumer**：用于从 Prefiller 消费 KV 缓存的 Decoder 实例
- **kv_both**：启用对称功能，连接器可以同时作为生产者和消费者。这为实验性设置以及角色区分未预先确定的场景提供了灵活性。