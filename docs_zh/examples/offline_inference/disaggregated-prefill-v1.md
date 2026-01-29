# 分离式预填充 V1

源代码 <https://github.com/vllm-project/vllm/tree/main/examples/offline_inference/disaggregated-prefill-v1>。

此示例包含演示 vLLM 离线设置中分离式预填充的脚本。

## 文件

- `run.sh` - 一个辅助脚本，用于按顺序运行 `prefill_example.py` 和 `decode_example.py`。
    - 运行 `run.sh` 前，请确保您位于 `examples/offline_inference/disaggregated-prefill-v1` 目录中。
- `prefill_example.py` - 仅执行预填充的脚本，将 KV 状态保存到 `local_storage` 目录，并将提示词保存到 `output.txt`。
- `decode_example.py` - 仅执行解码的脚本，从 `local_storage` 目录加载 KV 状态，并从 `output.txt` 加载提示词。

## 示例材料

??? abstract "decode_example.py"
    ``````py
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/offline_inference/disaggregated-prefill-v1/decode_example.py"
    ``````
??? abstract "prefill_example.py"
    ``````py
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/offline_inference/disaggregated-prefill-v1/prefill_example.py"
    ``````
??? abstract "run.sh"
    ``````sh
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/offline_inference/disaggregated-prefill-v1/run.sh"
    ``````