# 使用 CoreWeave 的 Tensorizer 加载模型

vLLM 支持使用 [CoreWeave's Tensorizer](https://docs.coreweave.com/coreweave-machine-learning-and-ai/inference/tensorizer) 加载模型。
通过 Tensorizer 序列化到磁盘、HTTP/HTTPS 端点或 S3 端点的 vLLM 模型张量，可以在运行时极快地直接反序列化到 GPU，显著缩短 Pod 启动时间和 CPU 内存使用。还支持张量加密。

vLLM 将 Tensorizer 完全集成到其模型加载机制中。以下将简要介绍如何在 vLLM 中开始使用 Tensorizer。

## 安装 Tensorizer

要安装 `tensorizer`，请运行 `pip install vllm[tensorizer]`。

## 基础知识

要使用 Tensorizer 加载模型，模型首先需要通过 Tensorizer 进行序列化。[示例脚本](../../examples/others/tensorize_vllm_model.md)负责处理此过程。

让我们通过一个基本示例来了解如何使用脚本序列化 `facebook/opt-125m`，然后用于推理。

## 使用 Tensorizer 序列化 vLLM 模型

要使用 Tensorizer 序列化模型，请使用必要的 CLI 参数调用示例脚本。脚本本身的文档字符串详细解释了 CLI 参数及其正确使用方法，我们将直接使用文档字符串中的一个示例，假设我们希望在 S3 存储桶示例 `s3://my-bucket` 中序列化并保存模型：

```bash
python examples/others/tensorize_vllm_model.py \
   --model facebook/opt-125m \
   serialize \
   --serialized-directory s3://my-bucket \
   --suffix v1
```

这将模型张量保存在 `s3://my-bucket/vllm/facebook/opt-125m/v1`。如果您计划对张量化模型应用 LoRA 适配器，可以在上述命令中传递 LoRA 适配器的 HF ID，相关文件也会保存在那里：

```bash
python examples/others/tensorize_vllm_model.py \
   --model facebook/opt-125m \
   --lora-path <lora_id> \
   serialize \
   --serialized-directory s3://my-bucket \
   --suffix v1
```

## 使用 Tensorizer 提供模型服务

模型序列化到所需位置后，您可以使用 `vllm serve` 或 `LLM` 入口点加载模型。您可以将保存模型的目录传递给 `LLM()` 和 `vllm serve` 的 `model` 参数。例如，要提供之前保存的带有 LoRA 适配器的张量化模型，可以这样做：

```bash
vllm serve s3://my-bucket/vllm/facebook/opt-125m/v1 \
    --load-format tensorizer \
    --enable-lora 
```

或者，使用 `LLM()`：

```python
from vllm import LLM
llm = LLM(
    "s3://my-bucket/vllm/facebook/opt-125m/v1", 
    load_format="tensorizer",
    enable_lora=True,
)
```

## 配置 Tensorizer 的选项

`tensorizer` 中负责序列化和反序列化模型的核心对象分别是 `TensorSerializer` 和 `TensorDeserializer`。为了向这些对象传递任意的 kwargs（这将配置序列化和反序列化过程），您可以分别将它们作为 `model_loader_extra_config` 的键提供，键名分别为 `serialization_kwargs` 和 `deserialization_kwargs`。上述对象的所有参数的完整文档字符串可以在 `tensorizer` 的 [serialization.py](https://github.com/coreweave/tensorizer/blob/main/tensorizer/serialization.py) 文件中找到。

例如，当使用 `tensorizer` 序列化时，可以通过 `TensorSerializer` 初始化器中的 `limit_cpu_concurrency` 参数限制 CPU 并发度。要将 `limit_cpu_concurrency` 设置为某个任意值，可以在序列化时这样操作：

```bash
python examples/others/tensorize_vllm_model.py \
   --model facebook/opt-125m \
   --lora-path <lora_id> \
   serialize \
   --serialized-directory s3://my-bucket \
   --serialization-kwargs '{"limit_cpu_concurrency": 2}' \
   --suffix v1
```

例如，当通过 `TensorDeserializer` 自定义加载过程时，您可以通过 `model_loader_extra_config` 中的 `num_readers` 参数限制反序列化过程中的并发读取器数量，如下所示：

```bash
vllm serve s3://my-bucket/vllm/facebook/opt-125m/v1 \
    --load-format tensorizer \
    --enable-lora \
    --model-loader-extra-config '{"deserialization_kwargs": {"num_readers": 2}}'
```

或者使用 `LLM()`：

```python
from vllm import LLM
llm = LLM(
    "s3://my-bucket/vllm/facebook/opt-125m/v1", 
    load_format="tensorizer",
    enable_lora=True,
    model_loader_extra_config={"deserialization_kwargs": {"num_readers": 2}},
)
```