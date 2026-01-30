# KV 加载失败恢复测试

源代码 <https://github.com/vllm-project/vllm/tree/main/examples/offline_inference/kv_load_failure_recovery>。

本示例基于 `examples/offline_inference` 中的 `disaggregated-prefill-v1` 示例构建。

它演示了 vLLM 在同步和异步加载模式下从 KV 加载失败中恢复的能力。目标是验证 vLLM 能否正确识别无效的 KV 块、重新调度受影响的请求，并确保输出成功且一致。

## 文件

- `prefill_example.py` – 执行预填充阶段并保存 KV 数据（与 `disaggregated-prefill-v1` 中的相同）。
- `decode_example.py` – 执行解码阶段。接受以下参数：
    - `--simulate-failure`：使用自定义连接器模拟 KV 加载失败。
    - `--async-load`：启用异步 KV 加载模式。
- `load_recovery_example_connector.py` – 定义 `LoadRecoveryExampleConnector`，它是 `ExampleConnector` 的子类，通过无法加载第一个解码请求的块来模拟丢失或损坏的外部 KV 块。
- `run.sh` – 协调整个测试：运行预填充阶段，然后运行三个解码阶段：
    1. 正常解码（基线）。
    2. 模拟同步 KV 加载失败的解码。
    3. 模拟异步 KV 加载失败的解码。

    最后，它将基线输出与恢复后的输出进行比较，以验证正确性。

## 工作原理

- 测试通过 `KVTransferConfig.kv_connector_module_path` 动态加载 `LoadRecoveryExampleConnector`，从而能够在不修改原始连接器的情况下，对加载失败进行受控模拟。
- 模拟失败的解码阶段预计会触发 vLLM 中的恢复逻辑，从而产生与基线解码相同的输出。
- 如果恢复失败，脚本会打印输出不匹配的统一差异（unified diff）并以错误状态退出。

## 使用方法

```bash
./run.sh

## 示例材料

??? abstract "decode_example.py"
    ``````py
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/offline_inference/kv_load_failure_recovery/decode_example.py"
    ``````
??? abstract "load_recovery_example_connector.py"
    ``````py
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/offline_inference/kv_load_failure_recovery/load_recovery_example_connector.py"
    ``````
??? abstract "prefill_example.py"
    ``````py
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/offline_inference/kv_load_failure_recovery/prefill_example.py"
    ``````
??? abstract "run.sh"
    ``````sh
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/offline_inference/kv_load_failure_recovery/run.sh"
    ``````