# IO 处理器插件

IO 处理器插件是一项功能，允许对池化模型的模型输入和输出进行预处理和后处理。其核心思想是允许用户向 vLLM 传递自定义输入，该输入会被转换为一个或多个模型提示，并传递给模型的 `encode` 方法。此类插件的一个潜在用例是将 vLLM 用于生成多模态数据。例如，用户向 vLLM 提供一张图像，并获得一张图像作为输出。

在使用 IO 处理器插件执行推理时，提示类型由插件定义，最终请求输出的类型也是如此。vLLM 不会对输入/输出数据进行任何验证，而是由插件负责确保向模型提供正确的数据并将其返回给用户。目前，这些插件仅支持池化模型，可通过 `LLM` 和 `AsyncLLM` 中的 `encode` 方法触发，或在在线服务模式下通过 `/pooling` 端点触发。

## 编写 IO 处理器插件

IO 处理器插件实现了 [`IOProcessor`][vllm.plugins.io_processors.interface.IOProcessor] 接口：

```python
IOProcessorInput = TypeVar("IOProcessorInput")
IOProcessorOutput = TypeVar("IOProcessorOutput")

class IOProcessor(ABC, Generic[IOProcessorInput, IOProcessorOutput]):
    def __init__(self, vllm_config: VllmConfig):
        self.vllm_config = vllm_config

    @abstractmethod
    def pre_process(
        self,
        prompt: IOProcessorInput,
        request_id: str | None = None,
        **kwargs,
    ) -> PromptType | Sequence[PromptType]:
        raise NotImplementedError

    async def pre_process_async(
        self,
        prompt: IOProcessorInput,
        request_id: str | None = None,
        **kwargs,
    ) -> PromptType | Sequence[PromptType]:
        return self.pre_process(prompt, request_id, **kwargs)

    @abstractmethod
    def post_process(
        self,
        model_output: Sequence[PoolingRequestOutput],
        request_id: str | None = None,
        **kwargs,
    ) -> IOProcessorOutput:
        raise NotImplementedError

    async def post_process_async(
        self,
        model_output: AsyncGenerator[tuple[int, PoolingRequestOutput]],
        request_id: str | None = None,
        **kwargs,
    ) -> IOProcessorOutput:
        # We cannot guarantee outputs are returned in the same order they were
        # fed to vLLM.
        # Let's sort them by id before post_processing
        sorted_output = sorted(
            [(i, item) async for i, item in model_output], key=lambda output: output[0]
        )
        collected_output = [output[1] for output in sorted_output]
        return self.post_process(collected_output, request_id, **kwargs)

    @abstractmethod
    def parse_request(self, request: Any) -> IOProcessorInput:
        raise NotImplementedError

    def validate_or_generate_params(
        self, params: SamplingParams | PoolingParams | None = None
    ) -> SamplingParams | PoolingParams:
        return params or PoolingParams()

    @abstractmethod
    def output_to_response(
        self, plugin_output: IOProcessorOutput
    ) -> IOProcessorResponse:
        raise NotImplementedError
```

`parse_request` 方法用于验证用户提示并将其转换为 `pre_process`/`pre_process_async` 方法所期望的输入。
`pre_process*` 方法接收已验证的插件输入，以生成用于常规推理的 vLLM 模型提示。
`post_process*` 方法以 `PoolingRequestOutput` 对象作为输入，并生成自定义插件输出。
`validate_or_generate_params` 方法用于验证用户请求中收到的任何 `SamplingParameters`/`PoolingParameters`，或在未指定参数时生成新的参数。该函数始终返回已验证/生成的参数。
`output_to_response` 方法仅用于在线服务，它将插件输出转换为 `IOProcessorResponse` 类型，然后由 API 服务器返回。`/pooling` 服务端点的实现可在此处找到 [vllm/entrypoints/openai/serving_pooling.py](../../vllm/entrypoints/pooling/pooling/serving.py)。

一个启用使用 PrithviGeospatialMAE 模型生成 geotiff 图像的插件示例实现可在此处找到 [here](https://github.com/IBM/terratorch/tree/main/terratorch/vllm/plugins/segmentation)。还请参考我们的在线 ([examples/pooling/plugin/prithvi_geospatial_mae_online.py](../../examples/pooling/plugin/prithvi_geospatial_mae_online.py)) 和离线 ([examples/pooling/plugin/prithvi_geospatial_mae_io_processor.py](../../examples/pooling/plugin/prithvi_geospatial_mae_io_processor.py)) 推理示例。

## 使用 IO 处理器插件

IO 处理器插件在引擎启动时加载，有两种方法可以指定要加载的插件名称：

1. 通过 vLLM 的 `EngineArgs`：在用于初始化 `AsyncLLM` 的 `EngineArgs` 中设置 `io_processor_plugin` 参数。在离线模式下，可以通过向 `LLM` 传递 `io_processor_plugin` 参数来实现相同的目的，或者在服务模式下通过传递 `--io-processor-plugin` 参数来实现。
2. 通过模型 HF 配置：在模型配置 (config.json) 中添加一个 `io_processor_plugin` 字段。

顺序也决定了方法的优先级。例如，通过 `EngineArgs` 设置插件名称将覆盖模型 HF 配置 (config.json) 中指定的任何插件名称。