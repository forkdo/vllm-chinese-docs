# 解耦式部署

来源 <https://github.com/vllm-project/vllm/tree/main/examples/online_serving/disaggregated_serving>。

本示例包含展示 vLLM 解耦式部署功能的脚本。

## 文件

- `disagg_proxy_demo.py` - 演示 XpYd（X 个预填充实例，Y 个解码实例）。
- `kv_events.sh` - 演示 KV 缓存事件发布。

## 示例材料

??? abstract "disagg_proxy_demo.py"
    ``````py
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/disaggregated_serving/disagg_proxy_demo.py"
    ``````
??? abstract "kv_events.sh"
    ``````sh
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/disaggregated_serving/kv_events.sh"
    ``````
??? abstract "moriio_toy_proxy_server.py"
    ``````py
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/disaggregated_serving/moriio_toy_proxy_server.py"
    ``````