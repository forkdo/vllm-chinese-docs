# BitsAndBytes

vLLM 现在支持 [BitsAndBytes](https://github.com/TimDettmers/bitsandbytes)，以实现更高效的模型推理。
BitsAndBytes 通过对模型进行量化来减少内存使用并提升性能，同时不会显著牺牲准确性。
与其他量化方法相比，BitsAndBytes 消除了使用输入数据对量化模型进行校准的需要。

以下是使用 vLLM 配合 BitsAndBytes 的步骤。

```bash
pip install bitsandbytes>=0.46.1
```

vLLM 读取模型的配置文件，支持在线量化和预量化检查点。

你可以在 [Hugging Face](https://huggingface.co/models?search=bitsandbytes) 上找到 BitsAndBytes 量化的模型。
通常，这些仓库会包含一个 config.json 文件，其中包含 quantization_config 部分。

## 读取量化检查点

对于预量化检查点，vLLM 将尝试从配置文件推断量化方法，因此你不需要显式指定量化参数。

```python
from vllm import LLM
import torch
# unsloth/tinyllama-bnb-4bit 是一个预量化检查点。
model_id = "unsloth/tinyllama-bnb-4bit"
llm = LLM(
    model=model_id,
    dtype=torch.bfloat16,
    trust_remote_code=True,
)
```

## 在线量化：加载为 4bit 量化

对于使用 BitsAndBytes 的 4bit 在线量化，你需要显式指定量化参数。

```python
from vllm import LLM
import torch
model_id = "huggyllama/llama-7b"
llm = LLM(
    model=model_id,
    dtype=torch.bfloat16,
    trust_remote_code=True,
    quantization="bitsandbytes",
)
```

## OpenAI 兼容服务器

为 4bit 在线量化，在模型参数中添加以下内容：

```bash
--quantization bitsandbytes
```