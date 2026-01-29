# 分布式部署故障排查

有关常规故障排查，请参阅[故障排查](../usage/troubleshooting.md)。

## 验证节点间 GPU 通信

启动 Ray 集群后，请验证跨节点的 GPU 到 GPU 通信。正确的配置可能并不简单。更多信息请参阅[故障排查脚本](../usage/troubleshooting.md#incorrect-hardwaredriver)。如果需要额外的环境变量来配置通信，请将其追加到 [examples/online_serving/run_cluster.sh](../../examples/online_serving/run_cluster.sh) 中，例如 `-e NCCL_SOCKET_IFNAME=eth0`。建议在创建集群时设置环境变量，因为这些变量会传播到所有节点。相比之下，在 shell 中设置环境变量只会影响本地节点。更多信息请参阅 <https://github.com/vllm-project/vllm/issues/6803>。

## 没有可用的节点类型可以满足资源请求

即使集群有足够的 GPU，也可能会出现错误消息 `Error: No available node types can fulfill resource request`。当节点有多个 IP 地址且 vLLM 无法选择正确的 IP 地址时，通常会出现此问题。请通过在 [examples/online_serving/run_cluster.sh](../../examples/online_serving/run_cluster.sh) 中设置 `VLLM_HOST_IP`（每个节点使用不同的值）来确保 vLLM 和 Ray 使用相同的 IP 地址。使用 `ray status` 和 `ray list nodes` 验证所选的 IP 地址。更多信息请参阅 <https://github.com/vllm-project/vllm/issues/7815>。

## Ray 可观测性

由于规模庞大且复杂，调试分布式系统可能具有挑战性。Ray 提供了一套工具来帮助监控、调试和优化 Ray 应用程序和集群。有关 Ray 可观测性的更多信息，请访问 [Ray 官方可观测性文档](https://docs.ray.io/en/latest/ray-observability/index.html)。有关调试 Ray 应用程序的更多信息，请访问 [Ray 调试指南](https://docs.ray.io/en/latest/ray-observability/user-guides/debug-apps/index.html)。有关 Kubernetes 集群故障排查的信息，请参阅[官方 KubeRay 故障排查指南](https://docs.ray.io/en/latest/serve/advanced-guides/multi-node-gpu-troubleshooting.html)。