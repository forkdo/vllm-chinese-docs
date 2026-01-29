# Disaggregated Serving

Source <https://github.com/vllm-project/vllm/tree/main/examples/online_serving/disaggregated_serving>.


This example contains scripts that demonstrate the disaggregated serving features of vLLM.

## Files

- `disagg_proxy_demo.py` - Demonstrates XpYd (X prefill instances, Y decode instances).
- `kv_events.sh` - Demonstrates KV cache event publishing.

## Example materials

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
