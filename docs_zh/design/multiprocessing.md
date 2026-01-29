# Python 多进程处理

## 调试

请参见[故障排除](../usage/troubleshooting.md#python-multiprocessing)
页面以了解已知问题及其解决方案。

## 介绍

!!! important
    源代码引用基于截至2024年12月撰写时的代码状态。

在 vLLM 中使用 Python 多进程处理面临以下复杂性：

- 将 vLLM 作为库使用且无法控制使用 vLLM 的代码
- 不同的多进程方法与 vLLM 依赖项之间存在不同程度的兼容性问题

本文档描述了 vLLM 如何应对这些挑战。

## 多进程方法

[Python 多进程方法](https://docs.python.org/3/library/multiprocessing.html#contexts-and-start-methods)包括：

- `spawn` - 启动一个新的 Python 进程。Windows 和 macOS 上的默认选项。

- `fork` - 使用 `os.fork()` 分叉 Python 解释器。Python 3.14 之前 Linux 上的默认选项。

- `forkserver` - 启动一个服务器进程，按需分叉新进程。Python 3.14 及更新版本在 Linux 上的默认选项。

### 权衡

`fork` 是最快的方法，但与使用线程的依赖项不兼容。如果您在 macOS 上，使用 `fork` 可能会导致进程崩溃。

`spawn` 与依赖项更兼容，但当 vLLM 作为库使用时可能会出现问题。如果使用代码没有使用 `__main__` 保护（`if __name__ == "__main__":`），当 vLLM 启动新进程时，代码会被意外重新执行。这可能导致无限递归等问题。

`forkserver` 会启动一个服务器进程，按需分叉新进程。不幸的是，当 vLLM 作为库使用时，它与 `spawn` 有同样的问题。服务器进程作为新启动的进程创建，会重新执行未受 `__main__` 保护的代码。

对于 `spawn` 和 `forkserver`，进程不能依赖继承全局状态，就像 `fork` 的情况一样。

## 与依赖项的兼容性

多个 vLLM 依赖项表明要么偏好要么要求使用 `spawn`：

- <https://pytorch.org/docs/stable/notes/multiprocessing.html#cuda-in-multiprocessing>
- <https://pytorch.org/docs/stable/multiprocessing.html#sharing-cuda-tensors>
- <https://docs.habana.ai/en/latest/PyTorch/Getting_Started_with_PyTorch_and_Gaudi/Getting_Started_with_PyTorch.html?highlight=multiprocessing#torch-multiprocessing-for-dataloaders>

更准确地说，似乎是在初始化这些依赖项后使用 `fork` 存在已知问题。

## 当前状态（v0）

环境变量 `VLLM_WORKER_MULTIPROC_METHOD` 可用于控制 vLLM 使用的方法。当前默认值是 `fork`。

- <https://github.com/vllm-project/vllm/blob/d05f88679bedd73939251a17c3d785a354b2946c/vllm/envs.py#L339-L342>

当我们知道由于使用了 `vllm` 命令而拥有进程时，我们使用 `spawn`，因为它的兼容性最广。

- <https://github.com/vllm-project/vllm/blob/d05f88679bedd73939251a17c3d785a354b2946c/vllm/scripts.py#L123-L140>

`multiproc_xpu_executor` 强制使用 `spawn`。

- <https://github.com/vllm-project/vllm/blob/d05f88679bedd73939251a17c3d785a354b2946c/vllm/executor/multiproc_xpu_executor.py#L14-L18>

还有其他一些地方硬编码使用 `spawn`：

- <https://github.com/vllm-project/vllm/blob/d05f88679bedd73939251a17c3d785a354b2946c/vllm/distributed/device_communicators/all_reduce_utils.py#L135>
- <https://github.com/vllm-project/vllm/blob/d05f88679bedd73939251a17c3d785a354b2946c/vllm/entrypoints/openai/api_server.py#L184>

相关 PR：

- <https://github.com/vllm-project/vllm/pull/8823>

## v1 中的先前状态

有一个环境变量用于控制 v1 引擎核心是否使用多进程处理，`VLLM_ENABLE_V1_MULTIPROCESSING`。默认为关闭。

- <https://github.com/vllm-project/vllm/blob/d05f88679bedd73939251a17c3d785a354b2946c/vllm/envs.py#L452-L454>

启用时，v1 的 `LLMEngine` 会创建一个新进程来运行引擎核心。

- <https://github.com/vllm-project/vllm/blob/d05f88679bedd73939251a17c3d785a354b2946c/vllm/v1/engine/llm_engine.py#L93-L95>
- <https://github.com/vllm-project/vllm/blob/d05f88679bedd73939251a17c3d785a354b2946c/vllm/v1/engine/llm_engine.py#L70-L77>
- <https://github.com/vllm-project/vllm/blob/d05f88679bedd73939251a17c3d785a354b2946c/vllm/v1/engine/core_client.py#L44-L45>

默认关闭，原因与上述相同 - 与依赖项和使用 vLLM 作为库的代码的兼容性。

### v1 中的变更

Python 的 `multiprocessing` 中没有一个简单的解决方案可以在所有地方都适用。作为第一步，我们可以让 v1 处于一个状态，使其进行"最佳努力"选择多进程方法以最大化兼容性。

- 默认使用 `fork`。
- 当我们知道控制主进程时（执行了 `vllm`），使用 `spawn`。
- 如果我们检测到之前已初始化 `cuda`，强制使用 `spawn` 并发出警告。我们知道 `fork` 会失败，所以这是最好的选择。

在这种情况下，已知仍会破坏的情况是使用 vLLM 作为库的代码在调用 vLLM 之前初始化了 `cuda`。我们发出的警告应该指导用户添加 `__main__` 保护或禁用多进程处理。

如果发生这种已知的失败情况，用户会看到两条解释情况的消息。首先是一条来自 vLLM 的日志消息：

```console
WARNING 12-11 14:50:37 multiproc_worker_utils.py:281] CUDA was previously
    initialized. We must use the `spawn` multiprocessing start method. Setting
    VLLM_WORKER_MULTIPROC_METHOD to 'spawn'. See
    https://docs.vllm.ai/en/latest/usage/troubleshooting.html#python-multiprocessing
    for more information.
```

其次，Python 本身会引发一个带有良好解释的异常：

```console
RuntimeError:
        An attempt has been made to start a new process before the
        current process has finished its bootstrapping phase.

        This probably means that you are not using fork to start your
        child processes and you have forgotten to use the proper idiom
        in the main module:

            if __name__ == '__main__':
                freeze_support()
                ...

        The "freeze_support()" line can be omitted if the program
        is not going to be frozen to produce an executable.

        To fix this issue, refer to the "Safe importing of main module"
        section in https://docs.python.org/3/library/multiprocessing.html
```

## 考虑的替代方案

### 检测是否存在 `__main__` 保护

有人建议，如果能检测到使用 vLLM 作为库的代码是否设置了 `__main__` 保护，我们可以表现得更好。[这篇 stackoverflow 帖子](https://stackoverflow.com/questions/77220442/multiprocessing-pool-in-a-python-class-without-name-main-guard)
来自一个遇到同样问题的库作者。

可以检测我们是否在原始的 `__main__` 进程中，还是在后续启动的进程中。然而，检测代码中是否存在 `__main__` 保护似乎并不简单。

这个选项已被认为不切实际而被放弃。

### 使用 `forkserver`

起初 `forkserver` 似乎是一个很好的解决方案。然而，它的工作方式在 vLLM 作为库使用时带来了与 `spawn` 相同的挑战。

### 始终强制使用 `spawn`

一种清理方法是始终强制使用 `spawn` 并记录当使用 vLLM 作为库时必须使用 `__main__` 保护。这将不幸破坏现有代码并使 vLLM 更难使用，违背了让 `LLM` 类尽可能易用的愿望。

我们不会将此强加给用户，而是保留复杂性以尽最大努力使事情正常工作。

## 后续工作

我们将来可能需要考虑一种不同的工作进程管理方法来规避这些挑战。

1. 我们可以实现类似 `forkserver` 的机制，但让进程管理器由我们通过运行自己的子进程和自定义入口点来管理（启动一个 `vllm-manager` 进程）。

2. 我们可以探索其他可能更符合我们需求的库。示例包括：

- <https://github.com/joblib/loky>