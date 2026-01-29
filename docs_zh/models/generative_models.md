# 生成模型

vLLM 对生成模型提供了一流的支持，涵盖了大多数大型语言模型（LLM）。

在 vLLM 中，生成模型实现了 [VllmModelForTextGeneration][vllm.model_executor.models.VllmModelForTextGeneration] 接口。  
这些模型基于输入的最终隐藏状态，输出生成 token 的对数概率，然后通过 [Sampler][vllm.v1.sample.sampler.Sampler] 获得最终的文本。

## 配置

### 模型运行器 (`--runner`)

通过 `--runner generate` 选项以生成模式运行模型。

!!! tip
    在绝大多数情况下无需设置此选项，因为 vLLM 可通过 `--runner auto` 自动检测要使用的模型运行器。

## 离线推理

[LLM][vllm.LLM] 类提供了多种用于离线推理的方法。  
初始化模型时的选项列表，请参见 [配置](../api/README.md#configuration)。

### `LLM.generate`

[generate][vllm.LLM.generate] 方法可用于 vLLM 中的所有生成模型。  
它与 [Hugging Face Transformers 中的对应方法](https://huggingface.co/docs/transformers/main/en/main_classes/text_generation#transformers.GenerationMixin.generate) 类似，  
但额外自动执行了分词（tokenization）和去分词（detokenization）。

```python
from vllm import LLM

llm = LLM(model="facebook/opt-125m")
outputs = llm.generate("Hello, my name is")

for output in outputs:
    prompt = output.prompt
    generated_text = output.outputs[0].text
    print(f"Prompt: {prompt!r}, Generated text: {generated_text!r}")
```

你可以通过传入 [SamplingParams][vllm.SamplingParams] 可选地控制语言生成过程。  
例如，通过设置 `temperature=0` 可使用贪心采样：

```python
from vllm import LLM, SamplingParams

llm = LLM(model="facebook/opt-125m")
params = SamplingParams(temperature=0)
outputs = llm.generate("Hello, my name is", params)

for output in outputs:
    prompt = output.prompt
    generated_text = output.outputs[0].text
    print(f"Prompt: {prompt!r}, Generated text: {generated_text!r}")
```

!!! important
    默认情况下，如果 Hugging Face 模型仓库中存在 `generation_config.json`，vLLM 将使用模型创建者推荐的采样参数。在大多数情况下，如果未指定 [SamplingParams][vllm.SamplingParams]，这将为你提供最佳结果。

    然而，如果更倾向于使用 vLLM 的默认采样参数，请在创建 [LLM][vllm.LLM] 实例时传入 `generation_config="vllm"`。  
    代码示例可参见：[examples/offline_inference/basic/basic.py](../../examples/offline_inference/basic/basic.py)

### `LLM.beam_search`

[beam_search][vllm.LLM.beam_search] 方法在 [generate][vllm.LLM.generate] 的基础上实现了[束搜索（beam search）](https://huggingface.co/docs/transformers/en/generation_strategies#beam-search)。  
例如，使用 5 个束并最多输出 50 个 token：

```python
from vllm import LLM
from vllm.sampling_params import BeamSearchParams

llm = LLM(model="facebook/opt-125m")
params = BeamSearchParams(beam_width=5, max_tokens=50)
outputs = llm.beam_search([{"prompt": "Hello, my name is "}], params)

for output in outputs:
    generated_text = output.sequences[0].text
    print(f"Generated text: {generated_text!r}")
```

### `LLM.chat`

[chat][vllm.LLM.chat] 方法在 [generate][vllm.LLM.generate] 的基础上实现了聊天功能。  
特别地，它接受类似于 [OpenAI 聊天补全 API](https://platform.openai.com/docs/api-reference/chat) 的输入，  
并自动应用模型的[聊天模板（chat template）](https://huggingface.co/docs/transformers/en/chat_templating)来格式化提示。

!!! important
    通常只有经过指令微调的模型才具有聊天模板。  
    基础模型可能表现不佳，因为它们并未针对聊天对话进行训练。

??? code

    ```python
    from vllm import LLM

    llm = LLM(model="meta-llama/Meta-Llama-3-8B-Instruct")
    conversation = [
        {
            "role": "system",
            "content": "You are a helpful assistant",
        },
        {
            "role": "user",
            "content": "Hello",
        },
        {
            "role": "assistant",
            "content": "Hello! How can I assist you today?",
        },
        {
            "role": "user",
            "content": "Write an essay about the importance of higher education.",
        },
    ]
    outputs = llm.chat(conversation)

    for output in outputs:
        prompt = output.prompt
        generated_text = output.outputs[0].text
        print(f"Prompt: {prompt!r}, Generated text: {generated_text!r}")
    ```

代码示例可参见：[examples/offline_inference/basic/chat.py](../../examples/offline_inference/basic/chat.py)

如果模型没有聊天模板，或你想指定另一个模板，  
可以显式传入一个聊天模板：

```python
from vllm.entrypoints.chat_utils import load_chat_template

# 你可以在 `examples/` 下找到现有聊天模板的列表
custom_template = load_chat_template(chat_template="<path_to_template>")
print("Loaded chat template:", custom_template)

outputs = llm.chat(conversation, chat_template=custom_template)
```

## 在线服务

我们的 [OpenAI 兼容服务器](../serving/openai_compatible_server.md) 提供了与离线 API 对应的端点：

- [补全 API（Completions API）](../serving/openai_compatible_server.md#completions-api) 类似于 `LLM.generate`，但仅接受文本输入。
- [聊天 API（Chat API）](../serving/openai_compatible_server.md#chat-api) 类似于 `LLM.chat`，对于具有聊天模板的模型，支持文本和[多模态输入](../features/multimodal_inputs.md)。