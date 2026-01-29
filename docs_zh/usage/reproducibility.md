# 可重现性

出于性能考虑，vLLM 默认不保证结果的可重现性。要实现可重现的结果：

- 在离线模式下，您可以设置 `VLLM_ENABLE_V1_MULTIPROCESSING=0`，这会使调度确定化，
  或者启用 [批处理不变性](../features/batch_invariance.md) 以使输出不受调度影响。
- 在在线模式下，您只能启用 [批处理不变性](../features/batch_invariance.md)。

示例：[examples/offline_inference/reproducibility.py](../../examples/offline_inference/reproducibility.py)

!!! warning

    设置 `VLLM_ENABLE_V1_MULTIPROCESSING=0` 会更改用户代码的随机状态
    （即构造 [LLM][vllm.LLM] 类的代码）。

!!! note

    即使在上述设置下，vLLM 仅在相同硬件和相同 vLLM 版本上运行时才提供可重现性。

## 设置全局种子

vLLM 中的 `seed` 参数用于控制各种随机数生成器的随机状态。

如果提供了特定的种子值，将相应设置 `random`、`np.random` 和 `torch.manual_seed` 的随机状态。

### 默认行为

在 V1 中，`seed` 参数默认为 `0`，这会为每个工作进程设置随机状态，因此即使 `temperature > 0`，每次 vLLM 运行的结果仍保持一致。

对于 V1 来说，无法取消指定种子，因为不同工作进程需要产生相同的输出，以支持诸如推测解码等工作流程。更多信息请参见：<https://github.com/vllm-project/vllm/pull/17929>

!!! note

    只有在工作进程与用户代码在同一进程中运行时（即：`VLLM_ENABLE_V1_MULTIPROCESSING=0`），vLLM 才会更新用户代码的随机状态（即构造 [LLM][vllm.LLM] 类的代码）。

    默认情况下，`VLLM_ENABLE_V1_MULTIPROCESSING=1`，因此您可以使用 vLLM 而不必担心意外地对依赖随机状态的后续操作进行确定化。