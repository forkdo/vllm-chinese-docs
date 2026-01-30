# LMCache 示例

源代码：<https://github.com/vllm-project/vllm/tree/main/examples/others/lmcache>。

本文件夹演示了如何使用 LMCache 实现解耦预填充、CPU 卸载和 KV 缓存共享。

## 1. vLLM v1 中的解耦预填充

本示例演示了如何在单节点上使用 NIXL 运行 LMCache 进行解耦预填充。

### 前提条件

- 安装 [LMCache](https://github.com/LMCache/LMCache)。你可以直接运行 `pip install lmcache`。
- 安装 [NIXL](https://github.com/ai-dynamo/nixl)。
- 至少 2 个 GPU
- 用于 Llama 3.1 8B Instruct 的有效 Hugging Face 令牌（HF_TOKEN）。

### 使用方法

运行
`cd disagg_prefill_lmcache_v1`
进入 `disagg_prefill_lmcache_v1` 文件夹，然后运行

```bash
bash disagg_example_nixl.sh
```

来运行解耦预填充并测试性能。

### 组件

#### 服务器脚本

- `disagg_prefill_lmcache_v1/disagg_vllm_launcher.sh` - 启动用于预填充/解码的各个 vLLM 服务器，并同时启动代理服务器。
- `disagg_prefill_lmcache_v1/disagg_proxy_server.py` - FastAPI 代理服务器，协调预填充器和解码器之间的工作
- `disagg_prefill_lmcache_v1/disagg_example_nixl.sh` - 运行示例的主脚本

#### 配置

- `disagg_prefill_lmcache_v1/configs/lmcache-prefiller-config.yaml` - 预填充器服务器的配置
- `disagg_prefill_lmcache_v1/configs/lmcache-decoder-config.yaml` - 解码器服务器的配置

#### 日志文件

主脚本会生成几个日志文件：

- `prefiller.log` - 预填充服务器的日志
- `decoder.log` - 解码服务器的日志
- `proxy.log` - 代理服务器的日志

## 2. CPU 卸载示例

- `python cpu_offload_lmcache.py -v v0` - vLLM v0 的 CPU 卸载实现
- `python cpu_offload_lmcache.py -v v1` - vLLM v1 的 CPU 卸载实现

## 3. KV 缓存共享

`kv_cache_sharing_lmcache_v1.py` 示例演示了如何在 vLLM v1 实例之间共享 KV 缓存。

## 4. vLLM v0 中的解耦预填充

`disaggregated_prefill_lmcache_v0.py` 提供了一个如何在 vLLM v0 中运行解耦预填充的示例。

## 示例材料

??? abstract "cpu_offload_lmcache.py"
    ``````py
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/others/lmcache/cpu_offload_lmcache.py"
    ``````
??? abstract "disagg_prefill_lmcache_v0.py"
    ``````py
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/others/lmcache/disagg_prefill_lmcache_v0.py"
    ``````
??? abstract "disagg_prefill_lmcache_v1/configs/lmcache-decoder-config.yaml"
    ``````yaml
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/others/lmcache/disagg_prefill_lmcache_v1/configs/lmcache-decoder-config.yaml"
    ``````
??? abstract "disagg_prefill_lmcache_v1/configs/lmcache-prefiller-config.yaml"
    ``````yaml
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/others/lmcache/disagg_prefill_lmcache_v1/configs/lmcache-prefiller-config.yaml"
    ``````
??? abstract "disagg_prefill_lmcache_v1/disagg_example_nixl.sh"
    ``````sh
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/others/lmcache/disagg_prefill_lmcache_v1/disagg_example_nixl.sh"
    ``````
??? abstract "disagg_prefill_lmcache_v1/disagg_proxy_server.py"
    ``````py
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/others/lmcache/disagg_prefill_lmcache_v1/disagg_proxy_server.py"
    ``````
??? abstract "disagg_prefill_lmcache_v1/disagg_vllm_launcher.sh"
    ``````sh
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/others/lmcache/disagg_prefill_lmcache_v1/disagg_vllm_launcher.sh"
    ``````
??? abstract "kv_cache_sharing_lmcache_v1.py"
    ``````py
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/others/lmcache/kv_cache_sharing_lmcache_v1.py"
    ``````