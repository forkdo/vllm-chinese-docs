# LoRA 适配器

本文档介绍如何在基础模型之上使用 vLLM 的 [LoRA 适配器](https://arxiv.org/abs/2106.09685)。

LoRA 适配器可用于任何实现了 [SupportsLoRA][vllm.model_executor.models.interfaces.SupportsLoRA] 的 vLLM 模型。

适配器可以按请求高效地提供服务，且开销极小。首先，我们下载适配器并将其保存到本地：

```python
from huggingface_hub import snapshot_download

sql_lora_path = snapshot_download(repo_id="jeeejeee/llama32-3b-text2sql-spider")
```

然后，我们实例化基础模型并传入 `enable_lora=True` 标志：

```python
from vllm import LLM, SamplingParams
from vllm.lora.request import LoRARequest

llm = LLM(model="meta-llama/Llama-3.2-3B-Instruct", enable_lora=True)
```

现在，我们可以提交提示并通过 `lora_request` 参数调用 `llm.generate`。`LoRARequest` 的第一个参数是人类可读的名称，第二个参数是适配器的全局唯一 ID，第三个参数是 LoRA 适配器的路径。

??? code

    ```python
    sampling_params = SamplingParams(
        temperature=0,
        max_tokens=256,
        stop=["[/assistant]"],
    )

    prompts = [
        "[user] Write a SQL query to answer the question based on the table schema.\n\n context: CREATE TABLE table_name_74 (icao VARCHAR, airport VARCHAR)\n\n question: Name the ICAO for lilongwe international airport [/user] [assistant]",
        "[user] Write a SQL query to answer the question based on the table schema.\n\n context: CREATE TABLE table_name_11 (nationality VARCHAR, elector VARCHAR)\n\n question: When Anchero Pantaleone was the elector what is under nationality? [/user] [assistant]",
    ]

    outputs = llm.generate(
        prompts,
        sampling_params,
        lora_request=LoRARequest("sql_adapter", 1, sql_lora_path),
    )
    ```

请查看 [examples/features/lora/multilora_offline.py](../../examples/features/lora/multilora_offline.py)，了解如何使用异步引擎使用 LoRA 适配器，以及如何配置更高级的选项。

## 提供 LoRA 适配器服务

LoRA 适配的模型也可以通过兼容 OpenAI 的 vLLM 服务器提供服务。为此，我们在启动服务器时使用 `--lora-modules {name}={path} {name}={path}` 指定每个 LoRA 模块：

```bash
vllm serve meta-llama/Llama-3.2-3B-Instruct \
    --enable-lora \
    --lora-modules sql-lora=jeeejeee/llama32-3b-text2sql-spider
```

服务器入口点接受所有其他 LoRA 配置参数（`max_loras`、`max_lora_rank`、`max_cpu_loras` 等），这些参数将应用于所有后续请求。查询 `/models` 端点时，我们应该能看到 LoRA 及其基础模型（如果未安装 `jq`，请按照 [此指南](https://jqlang.org/download/) 安装）：

??? console "Command"

    ```bash
    curl localhost:8000/v1/models | jq .
    {
        "object": "list",
        "data": [
            {
                "id": "meta-llama/Llama-3.2-3B-Instruct",
                "object": "model",
                ...
            },
            {
                "id": "sql-lora",
                "object": "model",
                ...
            }
        ]
    }
    ```

请求可以通过 `model` 请求参数指定 LoRA 适配器，就像指定其他模型一样。请求将根据服务器范围的 LoRA 配置进行处理（即与基础模型请求并行处理，如果提供了其他 LoRA 适配器请求且 `max_loras` 设置得足够高，也可能并行处理这些请求）。

以下是请求示例：

```bash
curl http://localhost:8000/v1/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "sql-lora",
        "prompt": "San Francisco is a",
        "max_tokens": 7,
        "temperature": 0
    }' | jq
```

## 动态提供 LoRA 适配器服务

除了在服务器启动时提供 LoRA 适配器外，vLLM 服务器还支持通过专用 API 端点和插件在运行时动态配置 LoRA 适配器。当需要灵活地实时更改模型时，此功能特别有用。

注意：在生产环境中启用此功能存在风险，因为用户可能会参与模型适配器管理。

要启用动态 LoRA 配置，请确保将环境变量 `VLLM_ALLOW_RUNTIME_LORA_UPDATING` 设置为 `True`。

```bash
export VLLM_ALLOW_RUNTIME_LORA_UPDATING=True
```

### 使用 API 端点

加载 LoRA 适配器：

要动态加载 LoRA 适配器，请向 `/v1/load_lora_adapter` 端点发送 POST 请求，并包含要加载的适配器的必要详细信息。请求负载应包括 LoRA 适配器的名称和路径。

加载 LoRA 适配器的示例请求：

```bash
curl -X POST http://localhost:8000/v1/load_lora_adapter \
-H "Content-Type: application/json" \
-d '{
    "lora_name": "sql_adapter",
    "lora_path": "/path/to/sql-lora-adapter"
}'
```

请求成功后，API 将返回 `200 OK` 状态码，`curl` 返回响应正文：`Success: LoRA adapter 'sql_adapter' added successfully`。如果发生错误（例如找不到或无法加载适配器），将返回适当的错误消息。

卸载 LoRA 适配器：

要卸载之前加载的 LoRA 适配器，请向 `/v1/unload_lora_adapter` 端点发送 POST 请求，并包含要卸载的适配器的名称或 ID。

请求成功后，API 将返回 `200 OK` 状态码，`curl` 返回响应正文：`Success: LoRA adapter 'sql_adapter' removed successfully`。

卸载 LoRA 适配器的示例请求：

```bash
curl -X POST http://localhost:8000/v1/unload_lora_adapter \
-H "Content-Type: application/json" \
-d '{
    "lora_name": "sql_adapter"
}'
```

### 使用插件

或者，您可以使用 LoRAResolver 插件动态加载 LoRA 适配器。LoRAResolver 插件支持从本地和远程源（如本地文件系统和 S3）加载 LoRA 适配器。每次请求时，如果有尚未加载的新模型名称，LoRAResolver 将尝试解析并加载相应的 LoRA 适配器。

如果需要从不同源加载 LoRA 适配器，您可以设置多个 LoRAResolver 插件。例如，可以设置一个用于本地文件的解析器，另一个用于 S3 存储的解析器。vLLM 将加载它找到的第一个 LoRA 适配器。

您可以安装现有插件或实现自己的插件。默认情况下，vLLM 自带 [一个用于从本地目录加载 LoRA 适配器的解析器插件，以及一个用于从 Hugging Face Hub 仓库加载 LoRA 适配器的解析器插件](https://github.com/vllm-project/vllm/tree/main/vllm/plugins/lora_resolvers)。要启用这些解析器中的任意一个，必须将 `VLLM_ALLOW_RUNTIME_LORA_UPDATING` 设置为 True。

- 要使用本地目录，请将 `VLLM_PLUGINS` 设置为包含 `lora_filesystem_resolver`，并将 `VLLM_LORA_RESOLVER_CACHE_DIR` 设置为本地目录。当 vLLM 收到使用 LoRA 适配器 `foobar` 的请求时，它会先在本地目录中查找名为 `foobar` 的目录，并尝试将该目录的内容作为 LoRA 适配器加载。如果成功，请求将正常完成，该适配器随后可在服务器上正常使用。
- 要使用 Hugging Face Hub 上的仓库，请将 `VLLM_PLUGINS` 设置为包含 `lora_hf_hub_resolver`，并将 `VLLM_LORA_RESOLVER_HF_REPO_LIST` 设置为 Hugging Face Hub 上仓库 ID 的逗号分隔列表。当 vLLM 收到对 LoRA 适配器 `my/repo/subpath` 的请求时，如果 `my/repo` 的 `subpath` 存在且包含 `adapter_config.json`，它将下载该适配器，然后构建对该适配器缓存目录的请求，类似于 `lora_filesystem_resolver`。请注意，启用远程下载是不安全的，不适用于生产环境。

或者，按照以下示例步骤实现您自己的插件：

1. 实现 LoRAResolver 接口。

??? code "一个简单的 S3 LoRAResolver 实现示例"

    ```python
    import os
    import s3fs
    from vllm.lora.request import LoRARequest
    from vllm.lora.resolver import LoRAResolver

    class S3LoRAResolver(LoRAResolver):
        def __init__(self):
            self.s3 = s3fs.S3FileSystem()
            self.s3_path_format = os.getenv("S3_PATH_TEMPLATE")
            self.local_path_format = os.getenv("LOCAL_PATH_TEMPLATE")

        async def resolve_lora(self, base_model_name, lora_name):
            s3_path = self.s3_path_format.format(base_model_name=base_model_name, lora_name=lora_name)
            local_path = self.local_path_format.format(base_model_name=base_model_name, lora_name=lora_name)

            # 从 S3 下载 LoRA 到本地路径
            await self.s3._get(
                s3_path, local_path, recursive=True, maxdepth=1
            )

            lora_request = LoRARequest(
                lora_name=lora_name,
                lora_path=local_path,
                lora_int_id=abs(hash(lora_name)),
            )
            return lora_request
    ```

2. 注册 `LoRAResolver` 插件。

    ```python
    from vllm.lora.resolver import LoRAResolverRegistry

    s3_resolver = S3LoRAResolver()
    LoRAResolverRegistry.register_resolver("s3_resolver", s3_resolver)
    ```

    更多详细信息，请参阅 [vLLM 插件系统](../design/plugin_system.md)。

### 就地 LoRA 重载

在动态加载 LoRA 适配器时，您可能需要在保持相同名称的情况下，用更新后的权重替换现有适配器。`load_inplace` 参数可实现此功能。这在异步强化学习设置中很常见，其中适配器会持续更新并交换，而不会中断正在进行的推理。

当 `load_inplace=True` 时，vLLM 会用新的适配器替换现有适配器。

加载或替换同名 LoRA 适配器的请求示例：

```bash
curl -X POST http://localhost:8000/v1/load_lora_adapter \
-H "Content-Type: application/json" \
-d '{
    "lora_name": "my-adapter",
    "lora_path": "/path/to/adapter/v2",
    "load_inplace": true
}'
```

## `--lora-modules` 的新格式

在之前的版本中，用户会通过以下格式提供 LoRA 模块，可以是键值对或 JSON 格式。例如：

```bash
--lora-modules  sql-lora=jeeejeee/llama32-3b-text2sql-spider
```

这只会包含每个 LoRA 模块的 `name` 和 `path`，但无法指定 `base_model_name`。
现在，您可以使用 JSON 格式在名称和路径旁边指定 base_model_name。例如：

```bash
--lora-modules '{"name": "sql-lora", "path": "jeeejeee/llama32-3b-text2sql-spider", "base_model_name": "meta-llama/Llama-3.2-3B-Instruct"}'
```

为了提供向后兼容性支持，您仍然可以使用旧的键值格式 (name=path)，但在这种情况下，`base_model_name` 将保持未指定状态。

## 模型卡中的 LoRA 模型谱系

`--lora-modules` 的新格式主要是为了支持在模型卡中显示父模型信息。以下是您当前响应如何支持此功能的说明：

- LoRA 模型 `sql-lora` 的 `parent` 字段现在链接到其基础模型 `meta-llama/Llama-3.2-3B-Instruct`。这正确反映了基础模型和 LoRA 适配器之间的层次关系。
- `root` 字段指向 lora 适配器的工件位置。

??? console "命令输出"

    ```bash
    $ curl http://localhost:8000/v1/models

    {
        "object": "list",
        "data": [
            {
            "id": "meta-llama/Llama-3.2-3B-Instruct",
            "object": "model",
            "created": 1715644056,
            "owned_by": "vllm",
            "root": "meta-llama/Llama-3.2-3B-Instruct",
            "parent": null,
            "permission": [
                {
                .....
                }
            ]
            },
            {
            "id": "sql-lora",
            "object": "model",
            "created": 1715644056,
            "owned_by": "vllm",
            "root": "jeeejeee/llama32-3b-text2sql-spider",
            "parent": "meta-llama/Llama-3.2-3B-Instruct",
            "permission": [
                {
                ....
                }
            ]
            }
        ]
    }
    ```

## 多模态模型的 Tower 和 Connector 的 LoRA 支持

目前，vLLM 实验性地支持多模态模型的 Tower 和 Connector 组件的 LoRA。要启用此功能，您需要为 tower 和 connector 实现相应的 token 辅助函数。有关此方法背后原理的更多详细信息，请参阅 [PR 26674](https://github.com/vllm-project/vllm/pull/26674)。我们欢迎贡献者将 LoRA 支持扩展到更多模型的 tower 和 connector。请参阅 [Issue 31479](https://github.com/vllm-project/vllm/issues/31479) 以查看当前模型支持状态。

## 多模态模型的默认 LoRA 模型

某些模型，例如 [Granite Speech](https://huggingface.co/ibm-granite/granite-speech-3.3-8b) 和 [Phi-4-multimodal-instruct](https://huggingface.co/microsoft/Phi-4-multimodal-instruct) 多模态模型，包含预期在给定模态存在时始终应用的 LoRA 适配器。使用上述方法管理这可能有点繁琐，因为它要求用户根据请求的多模态数据内容发送 `LoRARequest`（离线）或在基础模型和 LoRA 模型之间过滤请求（服务器）。

为此，我们允许注册默认多模态 LoRA 来自动处理此问题，用户可以映射每个模态到 LoRA 适配器，以便在相应输入存在时自动应用它。请注意，目前每个提示只允许一个 LoRA；如果提供了多个模态，每个模态都注册到给定模态，则它们都不会被应用。

??? code "离线推理的示例用法"

    ```python
    from transformers import AutoTokenizer
    from vllm import LLM, SamplingParams
    from vllm.assets.audio import AudioAsset

    model_id = "ibm-granite/granite-speech-3.3-2b"
    tokenizer = AutoTokenizer.from_pretrained(model_id)

    def get_prompt(question: str, has_audio: bool):
        """构建要发送到 vLLM 的输入提示。"""
        if has_audio:
            question = f"<|audio|>{question}"
        chat = [
            {"role": "user", "content": question},
        ]
        return tokenizer.apply_chat_template(chat, tokenize=False)


    llm = LLM(
        model=model_id,
        enable_lora=True,
        max_lora_rank=64,
        max_model_len=2048,
        limit_mm_per_prompt={"audio": 1},
        # 每当请求数据中包含音频时，
        # 将始终传递带有 `model_id` 的 `LoRARequest`。
        default_mm_loras = {"audio": model_id},
        enforce_eager=True,
    )

    question = "你能将语音转录成书面格式吗？"
    prompt_with_audio = get_prompt(
        question=question,
        has_audio=True,
    )
    audio = AudioAsset("mary_had_lamb").audio_and_sample_rate

    inputs = {
        "prompt": prompt_with_audio,
        "multi_modal_data": {
            "audio": audio,
        }
    }


    outputs = llm.generate(
        inputs,
        sampling_params=SamplingParams(
            temperature=0.2,
            max_tokens=64,
        ),
    )
    ```

您还可以传递一个 `--default-mm-loras` 的 json 字典，将模态映射到 LoRA 模型 ID。例如，在启动服务器时：

```bash
vllm serve ibm-granite/granite-speech-3.3-2b \
    --max-model-len 2048 \
    --enable-lora \
    --default-mm-loras '{"audio":"ibm-granite/granite-speech-3.3-2b"}' \
    --max-lora-rank 64
```

注意：默认多模态 LoRA 目前仅适用于 `.generate` 和聊天完成。

## 使用技巧

### 配置 `max_lora_rank`

`--max-lora-rank` 参数用于控制 LoRA 适配器允许的最大秩（rank）。此设置会影响内存分配和性能：

- **将其设置为计划使用的所有 LoRA 适配器中的最大秩**
- **避免设置过高** - 使用远高于实际需求值会浪费内存并可能导致性能问题

例如，如果您的 LoRA 适配器的秩为 [16, 32, 64]，则应使用 `--max-lora-rank 64` 而不是 256

```bash
# 正确：与实际最大秩相匹配
vllm serve model --enable-lora --max-lora-rank 64

# 错误：设置过高，浪费内存
vllm serve model --enable-lora --max-lora-rank 256
```