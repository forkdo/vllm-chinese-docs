# 使用统计收集

vLLM 默认收集匿名使用数据，以帮助工程团队更好地了解哪些硬件和模型配置被广泛使用。这些数据使他们能够优先处理最常见的工作负载。收集的数据是透明的，不包含任何敏感信息。经过清洗和聚合后的部分数据将公开发布，以供社区受益。例如，你可以在[这里](https://2024.vllm.ai)查看 2024 年的使用报告。

## 收集哪些数据？

最新版本 vLLM 收集的数据列表可以在这里找到：[vllm/usage/usage_lib.py](../../vllm/usage/usage_lib.py)

以下是截至 v0.4.0 的示例：

??? console "Output"

```json
{
  "uuid": "fbe880e9-084d-4cab-a395-8984c50f1109",
  "provider": "GCP",
  "num_cpu": 24,
  "cpu_type": "Intel(R) Xeon(R) CPU @ 2.20GHz",
  "cpu_family_model_stepping": "6,85,7",
  "total_memory": 101261135872,
  "architecture": "x86_64",
  "platform": "Linux-5.10.0-28-cloud-amd64-x86_64-with-glibc2.31",
  "gpu_count": 2,
  "gpu_type": "NVIDIA L4",
  "gpu_memory_per_device": 23580639232,
  "model_architecture": "OPTForCausalLM",
  "vllm_version": "0.3.2+cu123",
  "context": "LLM_CLASS",
  "log_time": 1711663373492490000,
  "source": "production",
  "dtype": "torch.float16",
  "tensor_parallel_size": 1,
  "block_size": 16,
  "gpu_memory_utilization": 0.9,
  "quantization": null,
  "kv_cache_dtype": "auto",
  "enable_lora": false,
  "enable_prefix_caching": false,
  "enforce_eager": false,
  "disable_custom_all_reduce": true
}
```

你可以通过运行以下命令预览收集的数据：

```bash
tail ~/.config/vllm/usage_stats.json
```

## 退出收集

你可以通过设置 `VLLM_NO_USAGE_STATS` 或 `DO_NOT_TRACK` 环境变量，或者创建 `~/.config/vllm/do_not_track` 文件来退出使用统计收集：

```bash
# 以下任一方法都可以禁用使用统计收集
export VLLM_NO_USAGE_STATS=1
export DO_NOT_TRACK=1
mkdir -p ~/.config/vllm && touch ~/.config/vllm/do_not_track
```