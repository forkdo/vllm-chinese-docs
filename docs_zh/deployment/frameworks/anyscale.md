# Anyscale

[Anyscale](https://www.anyscale.com) 是由 Ray 创始团队打造的托管式多云平台。

Anyscale 在您的 AWS、GCP 或 Azure 账户中自动化管理整个 Ray 集群生命周期，提供开源 Ray 的灵活性，同时避免了维护 Kubernetes 控制平面、配置自动伸缩器、管理可观测性堆栈，或使用辅助脚本（如 [examples/online_serving/run_cluster.sh](../../../examples/online_serving/run_cluster.sh)）手动管理主节点和工作节点所带来的运维开销。

在使用 vLLM 提供大型语言模型服务时，Anyscale 可以快速创建 [生产就绪的 HTTPS 端点](https://docs.anyscale.com/examples/deploy-ray-serve-llms) 或 [容错的批量推理任务](https://docs.anyscale.com/examples/ray-data-llm)。

## Anyscale 上生产就绪的 vLLM 快速入门

- [离线批量推理](https://console.anyscale.com/template-preview/llm_batch_inference?utm_source=vllm_docs)
- [部署 vLLM 服务](https://console.anyscale.com/template-preview/llm_serving?utm_source=vllm_docs)
- [数据集整理](https://console.anyscale.com/template-preview/audio-dataset-curation-llm-judge?utm_source=vllm_docs)
- [微调 LLM](https://console.anyscale.com/template-preview/entity-recognition-with-llms?utm_source=vllm_docs)