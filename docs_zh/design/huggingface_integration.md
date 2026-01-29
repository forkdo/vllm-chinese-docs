# 与 Hugging Face 的集成

本文档描述了 vLLM 如何与 Hugging Face 库进行集成。我们将逐步解释在运行 `vllm serve` 时底层发生了什么。

假设我们想通过运行 `vllm serve Qwen/Qwen2-7B` 来服务流行的 Qwen 模型。

1. `model` 参数为 `Qwen/Qwen2-7B`。vLLM 通过检查对应的配置文件 `config.json` 来判断该模型是否存在。请参阅此[代码片段](https://github.com/vllm-project/vllm/blob/10b67d865d92e376956345becafc249d4c3c0ab7/vllm/transformers_utils/config.py#L162-L182)以查看实现。在此过程中：
    - 如果 `model` 参数对应一个存在的本地路径，vLLM 将直接从该路径加载配置文件。
    - 如果 `model` 参数是一个由用户名和模型名组成的 Hugging Face 模型 ID，vLLM 首先会在 Hugging Face 本地缓存中查找配置文件，使用 `model` 参数作为模型名，`--revision` 参数作为版本。有关 Hugging Face 缓存工作原理的更多信息，请参阅[其网站](https://huggingface.co/docs/huggingface_hub/en/package_reference/environment_variables#hfhome)。
    - 如果 `model` 参数是一个 Hugging Face 模型 ID，但在缓存中未找到，vLLM 将从 Hugging Face 模型仓库下载配置文件。请参阅[此函数](https://github.com/vllm-project/vllm/blob/10b67d865d92e376956345becafc249d4c3c0ab7/vllm/transformers_utils/config.py#L91)以查看实现。输入参数包括 `model` 参数作为模型名，`--revision` 参数作为版本，以及环境变量 `HF_TOKEN` 作为访问模型仓库的令牌。在我们的例子中，vLLM 将下载[config.json](https://huggingface.co/Qwen/Qwen2-7B/blob/main/config.json)文件。

2. 确认模型存在后，vLLM 会加载其配置文件并将其转换为字典。请参阅此[代码片段](https://github.com/vllm-project/vllm/blob/10b67d865d92e376956345becafc249d4c3c0ab7/vllm/transformers_utils/config.py#L185-L186)以查看实现。

3. 接下来，vLLM [检查](https://github.com/vllm-project/vllm/blob/10b67d865d92e376956345becafc249d4c3c0ab7/vllm/transformers_utils/config.py#L189)配置字典中的 `model_type` 字段，以[生成](https://github.com/vllm-project/vllm/blob/10b67d865d92e376956345becafc249d4c3c0ab7/vllm/transformers_utils/config.py#L190-L216)要使用的配置对象。vLLM 直接支持一些 `model_type` 值；请参阅[此处](https://github.com/vllm-project/vllm/blob/10b67d865d92e376956345becafc249d4c3c0ab7/vllm/transformers_utils/config.py#L48)查看支持的列表。如果 `model_type` 不在列表中，vLLM 将使用 [AutoConfig.from_pretrained](https://huggingface.co/docs/transformers/en/model_doc/auto#transformers.AutoConfig.from_pretrained) 来加载配置类，参数包括 `model`、`--revision` 和 `--trust_remote_code`。请注意：
    - Hugging Face 也有自己的逻辑来确定要使用的配置类。它会再次使用 `model_type` 字段在 transformers 库中搜索类名；请参阅[此处](https://github.com/huggingface/transformers/tree/main/src/transformers/models)查看支持的模型列表。如果 `model_type` 未找到，Hugging Face 将使用配置 JSON 文件中的 `auto_map` 字段来确定类名。具体而言，它是 `auto_map` 下的 `AutoConfig` 字段。请参阅[DeepSeek](https://huggingface.co/deepseek-ai/DeepSeek-V2.5/blob/main/config.json) 作为示例。
    - `auto_map` 下的 `AutoConfig` 字段指向模型仓库中的一个模块路径。为了创建配置类，Hugging Face 将导入该模块并使用 `from_pretrained` 方法来加载配置类。这通常会导致任意代码执行，因此只有在启用 `--trust_remote_code` 时才会执行。

4. 接下来，vLLM 对配置对象应用一些历史补丁。这些主要与 RoPE 配置相关；请参阅[此处](https://github.com/vllm-project/vllm/blob/127c07480ecea15e4c2990820c457807ff78a057/vllm/transformers_utils/config.py#L244)以查看实现。

5. 最后，vLLM 可以到达要初始化的模型类。vLLM 使用配置对象中的 `architectures` 字段来确定要初始化的模型类，因为它在其[注册表](https://github.com/vllm-project/vllm/blob/127c07480ecea15e4c2990820c457807ff78a057/vllm/model_executor/models/registry.py#L80)中维护了架构名称到模型类的映射。如果架构名称在注册表中未找到，意味着 vLLM 不支持此模型架构。对于 `Qwen/Qwen2-7B`，`architectures` 字段为 `["Qwen2ForCausalLM"]`，它对应于[vLLM 代码](https://github.com/vllm-project/vllm/blob/127c07480ecea15e4c2990820c457807ff78a057/vllm/model_executor/models/qwen2.py#L364)中的 `Qwen2ForCausalLM` 类。该类将根据各种配置初始化自身。

除此之外，vLLM 还在两个方面依赖 Hugging Face。

1. **分词器（Tokenizer）**：vLLM 使用来自 Hugging Face 的分词器对输入文本进行分词。分词器通过 [AutoTokenizer.from_pretrained](https://huggingface.co/docs/transformers/en/model_doc/auto#transformers.AutoTokenizer.from_pretrained) 加载，参数包括 `model` 作为模型名，`--revision` 作为版本。也可以通过在 `vllm serve` 命令中指定 `--tokenizer` 参数来使用另一个模型的分词器。其他相关参数包括 `--tokenizer-revision` 和 `--tokenizer-mode`。请查阅 Hugging Face 的文档了解这些参数的含义。这部分逻辑可以在 [get_tokenizer](https://github.com/vllm-project/vllm/blob/127c07480ecea15e4c2990820c457807ff78a057/vllm/transformers_utils/tokenizer.py#L87) 函数中找到。获取分词器后，vLLM 还会将分词器的一些昂贵属性缓存到 [vllm.tokenizers.hf.get_cached_tokenizer][] 中。

2. **模型权重**：vLLM 使用 `model` 参数作为模型名，`--revision` 参数作为版本，从 Hugging Face 模型仓库下载模型权重。vLLM 提供 `--load-format` 参数来控制从模型仓库下载哪些文件。默认情况下，它会尝试以 safetensors 格式加载权重，如果不可用则回退到 PyTorch bin 格式。我们也可以传递 `--load-format dummy` 来跳过下载权重。
    - 建议使用 safetensors 格式，因为它在分布式推理中加载效率高，且不会导致任意代码执行。有关 safetensors 格式的更多信息，请参阅[文档](https://huggingface.co/docs/safetensors/en/index)。这部分逻辑可以在[此处](https://github.com/vllm-project/vllm/blob/10b67d865d92e376956345becafc249d4c3c0ab7/vllm/model_executor/model_loader/loader.py#L385)找到。请注意：

vLLM 与 Hugging Face 的集成到此结束。

总结一下，vLLM 从 Hugging Face 模型仓库或本地目录读取配置文件 `config.json`、分词器和模型权重。它使用来自 vLLM、Hugging Face transformers 或从模型仓库加载的配置类。