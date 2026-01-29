# 架构概览

本文档提供 vLLM 架构的概览。

[TOC]

## 入口点

vLLM 提供了多个入口点用于与系统交互。下图展示了它们之间的关系。

![入口点图示](../assets/design/arch_overview/entrypoints.excalidraw.png)

### LLM 类

LLM 类提供了进行离线推理的主要 Python 接口，即在不使用单独模型推理服务器的情况下与模型进行交互。

以下是 `LLM` 类的使用示例：

??? code

    ```python
    from vllm import LLM, SamplingParams

    # 定义输入提示列表
    prompts = [
        "Hello, my name is",
        "The capital of France is",
        "The largest ocean is",
    ]

    # 定义采样参数
    sampling_params = SamplingParams(temperature=0.8, top_p=0.95)

    # 使用 OPT-125M 模型初始化 LLM 引擎
    llm = LLM(model="facebook/opt-125m")

    # 为输入提示生成输出
    outputs = llm.generate(prompts, sampling_params)

    # 打印生成的输出
    for output in outputs:
        prompt = output.prompt
        generated_text = output.outputs[0].text
        print(f"Prompt: {prompt!r}, Generated text: {generated_text!r}")
    ```

更多 API 详情请参阅 API 文档中的 [离线推理](../api/README.md#offline-inference) 部分。

`LLM` 类的代码位于 [vllm/entrypoints/llm.py](../../vllm/entrypoints/llm.py)。

### OpenAI 兼容 API 服务器

vLLM 的第二个主要接口是通过其 OpenAI 兼容的 API 服务器。该服务器可以使用 `vllm serve` 命令启动。

```bash
vllm serve <model>
```

`vllm` CLI 的代码位于 [vllm/entrypoints/cli/main.py](../../vllm/entrypoints/cli/main.py)。

有时你可能会直接使用 API 服务器入口点，而不是通过 `vllm` CLI 命令。例如：

```bash
python -m vllm.entrypoints.openai.api_server --model <model>
```

!!! warning

    `python -m vllm.entrypoints.openai.api_server` 已被弃用
    并可能在将来的版本中不再支持。

该代码位于 [vllm/entrypoints/openai/api_server.py](../../vllm/entrypoints/openai/api_server.py)。

关于 API 服务器的更多详情请参阅 [OpenAI 兼容服务器](../serving/openai_compatible_server.md) 文档。

## LLM 引擎

`LLMEngine` 和 `AsyncLLMEngine` 类是 vLLM 系统功能的核心，负责模型推理和异步请求处理。

![LLMEngine 图示](../assets/design/arch_overview/llm_engine.excalidraw.png)

### LLMEngine

`LLMEngine` 类是 vLLM 引擎的核心组件。它负责接收客户端请求并从模型生成输出。`LLMEngine` 包括输入处理、模型执行（可能分布在多个主机和/或 GPU 上）、调度和输出处理。

- **输入处理**：使用指定的分词器对输入文本进行分词处理。
- **调度**：选择在每一步中处理哪些请求。
- **模型执行**：管理语言模型的执行，包括在多个 GPU 上的分布式执行。
- **输出处理**：处理模型生成的输出，将语言模型的 token ID 解码为可读文本。

`LLMEngine` 的代码位于 [vllm/engine/llm_engine.py](../../vllm/engine/llm_engine.py)。

### AsyncLLMEngine

`AsyncLLMEngine` 类是 `LLMEngine` 类的异步包装器。它使用 `asyncio` 创建一个后台循环，持续处理传入请求。`AsyncLLMEngine` 专为在线服务设计，可以处理多个并发请求并将输出流式传输给客户端。

OpenAI 兼容的 API 服务器使用 `AsyncLLMEngine`。还有一个演示 API 服务器，作为更简单的示例位于 [vllm/entrypoints/api_server.py](../../vllm/entrypoints/api_server.py)。

`AsyncLLMEngine` 的代码位于 [vllm/engine/async_llm_engine.py](../../vllm/engine/async_llm_engine.py)。

## 工作器

工作器是一个运行模型推理的进程。vLLM 遵循使用一个进程控制一个加速器设备（如 GPU）的常见做法。例如，如果我们使用大小为 2 的张量并行和大小为 2 的流水线并行，我们将总共拥有 4 个工作器。工作器通过其 `rank` 和 `local_rank` 来标识。`rank` 用于全局编排，而 `local_rank` 主要用于分配加速器设备和访问本地资源，如文件系统和共享内存。

## 模型运行器

每个工作器都有一个模型运行器对象，负责加载和运行模型。大部分模型执行逻辑位于此处，例如准备输入张量和捕获 cudagraphs。

## 模型

每个模型运行器对象都有一个模型对象，这是实际的 `torch.nn.Module` 实例。有关各种配置如何影响我们最终获得的类，请参阅 [huggingface_integration](huggingface_integration.md)。

## 类层次结构

下图展示了 vLLM 的类层次结构：

> <figure markdown="span">
>   ![](../assets/design/hierarchy.png){ align="center" alt="query" width="100%" }
> </figure>

这个类层次结构背后有几个重要的设计选择：

1\. **可扩展性**：层次结构中的所有类都接受一个包含所有必要信息的配置对象。[VllmConfig](https://github.com/vllm-project/vllm/blob/d1c6799b8870e513bf4f2305cbf6cda9fc3d773b/vllm/config.py#L2036)
类是主要的配置对象，会在各处传递。该类层次结构相当深，每个类都需要读取自己感兴趣的配置。通过将所有配置封装在一个对象中，我们可以轻松地传递配置对象并访问所需的配置。假设我们想要添加一个新功能（由于 LLM 推理领域发展迅速，这种情况经常发生），该功能只涉及模型运行器。我们只需要在 `VllmConfig` 类中添加一个新的配置选项。由于我们在各处传递整个配置对象，我们只需将配置选项添加到 `VllmConfig` 类中，模型运行器就可以直接访问它。我们不需要更改引擎、工作器或模型类的构造函数来传递新的配置选项。

2\. **统一性**：模型运行器需要一个统一的接口来创建和初始化模型。vLLM 支持 50 多种流行的开源模型。每个模型都有自己的初始化逻辑。如果构造函数签名因模型而异，模型运行器就无法知道如何相应地调用构造函数，而不需要复杂且容易出错的检查逻辑。通过使模型类的构造函数统一，模型运行器可以轻松创建和初始化模型，而无需知道具体的模型类型。这对于组合模型也很有用。视觉语言模型通常由视觉模型和语言模型组成。通过统一构造函数，我们可以轻松创建视觉模型和语言模型并将它们组合成视觉语言模型。

!!! note
    为了支持这一变化，所有 vLLM 模型的签名都已更新为：

    ```python
    def __init__(self, *, vllm_config: VllmConfig, prefix: str = ""):
    ```

    为了避免意外传递错误的参数，构造函数现在是仅关键字参数。这确保了如果传递旧配置，构造函数会引发错误。vLLM 开发者已经为 vLLM 内的所有模型进行了此更改。对于树外注册的模型，开发者需要更新其模型，例如通过添加适配器代码将旧构造函数签名适配到新签名：

    ??? code

```python
class MyOldModel(nn.Module):
    def __init__(
        self,
        config,
        cache_config: Optional[CacheConfig] = None,
        quant_config: Optional[QuantizationConfig] = None,
        lora_config: Optional[LoRAConfig] = None,
        prefix: str = "",
    ) -> None:
        ...

from vllm.config import VllmConfig
class MyNewModel(MyOldModel):
    def __init__(self, *, vllm_config: VllmConfig, prefix: str = ""):
        config = vllm_config.model_config.hf_config
        cache_config = vllm_config.cache_config
        quant_config = vllm_config.quant_config
        lora_config = vllm_config.lora_config
        super().__init__(config, cache_config, quant_config, lora_config, prefix)

from packaging import version
if version.parse(__version__) >= version.parse("0.6.4"):
    MyModel = MyNewModel
else:
    MyModel = MyOldModel
```

这样，该模型就可以在新旧版本的 vLLM 中正常工作。

3\. **初始化时的分片与量化**：某些功能需要修改模型权重。例如，张量并行需要对模型权重进行分片，而量化需要对模型权重进行量化。有两种可能的实现方式。一种是在模型初始化后修改模型权重，另一种是在模型初始化过程中修改模型权重。vLLM 选择了后者。第一种方法无法扩展到大模型。假设我们想要在 16 张 H100 80GB GPU 上运行一个 405B 模型（约 810GB 权重）。理想情况下，每张 GPU 只需加载 50GB 权重。如果在模型初始化后修改权重，我们需要将完整的 810GB 权重加载到每张 GPU 上，然后再进行分片，这会导致巨大的内存开销。相反，如果在模型初始化过程中进行权重分片，每一层只会创建其所需的权重分片，从而显著减少内存开销。同样的思路也适用于量化。请注意，我们还在模型构造函数中添加了一个额外参数 `prefix`，使得模型可以根据前缀以不同的方式初始化自己。这对于非均匀量化很有用，其中模型的不同部分采用不同的量化方式。对于顶层模型，`prefix` 通常是空字符串，对于子模型则是类似 `"vision"` 或 `"language"` 的字符串。通常，它与检查点文件中模块状态字典的名称相匹配。

这种设计的一个缺点是难以对 vLLM 中的各个组件编写单元测试，因为每个组件都需要通过完整的配置对象进行初始化。我们通过提供一个默认初始化函数来解决这个问题，该函数会创建一个所有字段都设为 `None` 的默认配置对象。如果我们想要测试的组件只关心配置对象中的少数几个字段，我们可以创建一个默认配置对象并设置我们关心的字段。这样，我们就可以隔离地测试该组件。请注意，vLLM 中的许多测试都是端到端测试，测试整个系统，因此这不是一个大问题。

总之，完整的配置对象 `VllmConfig` 可以被视为在所有 vLLM 类之间共享的引擎级全局状态。