# KV Load Failure Recovery Test

Source <https://github.com/vllm-project/vllm/tree/main/examples/offline_inference/kv_load_failure_recovery>.


This example builds upon the `disaggregated-prefill-v1` example in `examples/offline_inference`.

It demonstrates vLLM's ability to recover from KV load failures in both synchronous and asynchronous loading modes. The goal is to verify that vLLM correctly identifies invalid KV blocks, reschedules the affected requests, and ensures successful and consistent output.

## Files

- `prefill_example.py` – performs the prefill stage and saves KV data (same as in `disaggregated-prefill-v1`).
- `decode_example.py` – performs the decode stage. Accepts:
    - `--simulate-failure`: simulates KV load failure using a custom connector.
    - `--async-load`: enables asynchronous KV loading mode.
- `load_recovery_example_connector.py` – defines `LoadRecoveryExampleConnector`, a subclass of `ExampleConnector`, that simulates missing or corrupted external KV blocks by failing to load blocks for the first decode request.
- `run.sh` – orchestrates the test: runs the prefill stage, then three decode stages:
    1. Normal decode (baseline).
    2. Decode with simulated sync KV load failure.
    3. Decode with simulated async KV load failure.

    Finally, it compares the output of the baseline with the recovered outputs to verify correctness.

## How It Works

- The test dynamically loads `LoadRecoveryExampleConnector` via `KVTransferConfig.kv_connector_module_path`, enabling controlled simulation of load failures without modifying the original connector.
- The decode stages that simulate failure are expected to trigger recovery logic in vLLM, resulting in the same output as the baseline decode.
- If recovery fails, the script prints a unified diff of the output mismatch and exits with error.

## Usage

```bash
./run.sh

## Example materials

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
