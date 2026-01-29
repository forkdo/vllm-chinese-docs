# 插件系统

社区经常要求能够通过自定义功能来扩展 vLLM。为了满足这一需求，vLLM 提供了一个插件系统，允许用户在不修改 vLLM 代码库的情况下添加自定义功能。本文档解释了 vLLM 中插件的工作原理以及如何为 vLLM 创建插件。

## vLLM 中插件的工作原理

插件是用户注册的代码，由 vLLM 执行。鉴于 vLLM 的架构（参见 [架构概览](arch_overview.md)），在使用各种并行技术进行分布式推理时，可能涉及多个进程。为了成功启用插件，vLLM 创建的每个进程都需要加载插件。这是通过 `vllm.plugins` 模块中的 [load_plugins_by_group][vllm.plugins.load_plugins_by_group] 函数完成的。

## vLLM 如何发现插件

vLLM 的插件系统使用标准的 Python `entry_points` 机制。该机制允许开发者在 Python 包中注册函数，供其他包使用。一个插件的示例：

??? code

    ```python
    # 在 `setup.py` 文件中
    from setuptools import setup

    setup(name='vllm_add_dummy_model',
        version='0.1',
        packages=['vllm_add_dummy_model'],
        entry_points={
            'vllm.general_plugins':
            ["register_dummy_model = vllm_add_dummy_model:register"]
        })

    # 在 `vllm_add_dummy_model.py` 文件中
    def register():
        from vllm import ModelRegistry

        if "MyLlava" not in ModelRegistry.get_supported_archs():
            ModelRegistry.register_model(
                "MyLlava",
                "vllm_add_dummy_model.my_llava:MyLlava",
            )
    ```

有关在包中添加入口点的更多信息，请查阅 [官方文档](https://setuptools.pypa.io/en/latest/userguide/entry_point.html)。

每个插件包括三个部分：

1. **插件组**：入口点组的名称。vLLM 使用入口点组 `vllm.general_plugins` 来注册通用插件。这是 `setup.py` 文件中 `entry_points` 的键。vLLM 的通用插件始终使用 `vllm.general_plugins`。
2. **插件名称**：插件的名称。这是 `entry_points` 字典中字典的值。在上面的示例中，插件名称是 `register_dummy_model`。可以使用 `VLLM_PLUGINS` 环境变量按名称过滤插件。要仅加载特定插件，请将 `VLLM_PLUGINS` 设置为插件名称。
3. **插件值**：要在插件系统中注册的函数或模块的完全限定名称。在上面的示例中，插件值是 `vllm_add_dummy_model:register`，它引用 `vllm_add_dummy_model` 模块中的名为 `register` 的函数。

## 支持的插件类型

- **通用插件**（组名为 `vllm.general_plugins`）：这些插件的主要用例是将自定义的、树外模型注册到 vLLM 中。这是通过在插件函数中调用 `ModelRegistry.register_model` 来注册模型来实现的。

- **平台插件**（组名为 `vllm.platform_plugins`）：这些插件的主要用例是将自定义的、树外平台注册到 vLLM 中。当平台在当前环境中不支持时，插件函数应返回 `None`；当平台支持时，应返回平台类的完全限定名称。

- **IO 处理器插件**（组名为 `vllm.io_processor_plugins`）：这些插件的主要用例是为池化模型注册自定义的预处理/后处理模型提示和模型输出。插件函数返回 IOProcessor 类的完全限定名称。

- **统计日志器插件**（组名为 `vllm.stat_logger_plugins`）：这些插件的主要用例是将自定义的、树外日志器注册到 vLLM 中。入口点应该是继承自 StatLoggerBase 的类。

## 编写插件的指南

- **可重入性**：入口点中指定的函数应该是可重入的，意味着可以多次调用而不会出现问题。这是因为该函数在某些进程中可能会被多次调用。

### 平台插件指南

1. 创建一个平台插件项目，例如 `vllm_add_dummy_platform`。项目结构应如下所示：

    ```shell
    vllm_add_dummy_platform/
    ├── vllm_add_dummy_platform/
    │   ├── __init__.py
    │   ├── my_dummy_platform.py
    │   ├── my_dummy_worker.py
    │   ├── my_dummy_attention.py
    │   ├── my_dummy_device_communicator.py
    │   ├── my_dummy_custom_ops.py
    ├── setup.py
    ```

2. 在 `setup.py` 文件中，添加以下入口点：

    ```python
    setup(
        name="vllm_add_dummy_platform",
        ...
        entry_points={
            "vllm.platform_plugins": [
                "my_dummy_platform = vllm_add_dummy_platform:register"
            ]
        },
        ...
    )
    ```

    请确保 `vllm_add_dummy_platform:register` 是一个可调用函数，并返回平台类的完全限定名称。例如：

    ```python
    def register():
        return "vllm_add_dummy_platform.my_dummy_platform.MyDummyPlatform"
    ```

3. 在 `my_dummy_platform.py` 中实现平台类 `MyDummyPlatform`。平台类应继承自 `vllm.platforms.interface.Platform`。请按照接口逐一实现函数。有一些重要的函数和属性至少应该实现：

    - `_enum`：该属性是从 [PlatformEnum][vllm.platforms.interface.PlatformEnum] 的设备枚举。通常应该是 `PlatformEnum.OOT`，表示该平台是树外的。
    - `device_type`：该属性应返回 PyTorch 使用的设备类型。例如，`"cpu"`、`"cuda"` 等。
    - `device_name`：该属性通常与 `device_type` 设置为相同值。主要用于日志记录目的。
    - `check_and_update_config`：此函数在 vLLM 初始化过程的早期被调用。用于插件更新 vllm 配置。例如，块大小、图模式配置等可以在该函数中更新。最重要的是，**worker_cls** 应在该函数中设置，以让 vLLM 知道对工作进程使用哪个工作类。
    - `get_attn_backend_cls`：此函数应返回注意力后端类的完全限定名称。
    - `get_device_communicator_cls`：此函数应返回设备通信器类的完全限定名称。

4. 在 `my_dummy_worker.py` 中实现工作类 `MyDummyWorker`。工作类应继承自 [WorkerBase][vllm.v1.worker.worker_base.WorkerBase]。请按照接口逐一实现函数。基本上，基类中的所有接口都应实现，因为它们在 vLLM 的各个地方被调用。为了确保模型能够执行，应实现的基本函数包括：

    - `init_device`：此函数被调用来为工作器设置设备。
    - `initialize_cache`：此函数被调用来为工作器设置缓存配置。
    - `load_model`：此函数被调用来将模型权重加载到设备。
    - `get_kv_cache_spec`：此函数被调用来为模型生成 kv 缓存规范。
    - `determine_available_memory`：此函数被调用来分析模型的峰值内存使用情况，以确定在不发生 OOM 的情况下可用于 KV 缓存的内存大小。
    - `initialize_from_config`：此函数被调用来使用指定的 kv_cache_config 分配设备 KV 缓存
    - `execute_model`：此函数在每一步被调用来推理模型。

    可以实现的其他函数包括：

- 如果插件需要支持睡眠模式功能，请实现 `sleep` 和 `wakeup` 函数。
- 如果插件需要支持图模式功能，请实现 `compile_or_warm_up_model` 函数。
- 如果插件需要支持推测解码功能，请实现 `take_draft_token_ids` 函数。
- 如果插件需要支持 LoRA 功能，请实现 `add_lora`、`remove_lora`、`list_loras` 和 `pin_lora` 函数。
- 如果插件需要支持数据并行功能，请实现 `execute_dummy_batch` 函数。

请参考工作器基类 [WorkerBase][vllm.v1.worker.worker_base.WorkerBase] 以获取更多可实现的函数。

5. 在 `my_dummy_attention.py` 中实现注意力后端类 `MyDummyAttention`。注意力后端类应继承自 [AttentionBackend][vllm.v1.attention.backend.AttentionBackend]。它用于使用您的设备计算注意力。参考 `vllm.v1.attention.backends` 作为示例，其中包含许多注意力后端实现。

6. 实现高性能的自定义操作。大多数操作可以通过 PyTorch 原生实现运行，但性能可能不佳。在这种情况下，您可以为插件实现特定的自定义操作。目前，vLLM 支持以下几种自定义操作：

- PyTorch 操作
  有 3 种 PyTorch 操作：

  - `通信操作`：设备通信操作。例如全约简、全收集等。
    请在 `my_dummy_device_communicator.py` 中实现设备通信类 `MyDummyDeviceCommunicator`。设备通信类应继承自 [DeviceCommunicatorBase][vllm.distributed.device_communicators.base_device_communicator.DeviceCommunicatorBase]。
  - `通用操作`：通用操作。例如矩阵乘法、softmax 等。
    请通过注册 oot 方式实现通用操作。更多详情请参阅 [CustomOp][vllm.model_executor.custom_op.CustomOp] 类。
  - `C++ 操作`：C++ 操作。此类操作在 C++ 中实现，并注册为 PyTorch 自定义操作。
    按照 csrc 模块和 `vllm._custom_ops` 实现您的操作。

- Triton 操作
  目前自定义方式对 Triton 操作不适用。

7. （可选）实现其他可插拔模块，例如 LoRA、图后端、量化、Mamba 注意力后端等。

## 兼容性保证

vLLM 保证已记录插件的接口，例如 `ModelRegistry.register_model`，将始终对插件注册模型可用。但是，插件开发者有责任确保其插件与目标 vLLM 版本兼容。例如，`"vllm_add_dummy_model.my_llava:MyLlava"` 应与插件目标的 vLLM 版本兼容。

模型/模块的接口可能在 vLLM 开发过程中发生变化。如果您看到任何弃用日志信息，请将插件升级到最新版本。

## 弃用公告

!!! warning "弃用信息"
    - `Platform.get_attn_backend_cls` 中的 `use_v1` 参数已弃用。已在 v0.13.0 中移除。
    - `vllm.attention` 中的 `_Backend` 已弃用。已在 v0.13.0 中移除。请使用 `vllm.v1.attention.backends.registry.register_backend` 将新的注意力后端添加到 `AttentionBackendEnum` 中。
    - 平台接口 `seed_everything` 已弃用。将在 v0.15.0 或更高版本中移除。请使用 `vllm.utils.torch_utils.set_random_seed` 代替。