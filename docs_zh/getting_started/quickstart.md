# 快速入门

本指南将帮助您快速上手使用 vLLM 执行以下任务：

- [离线批量推理](#offline-batched-inference)
- [使用兼容 OpenAI 的服务器进行在线服务](#openai-compatible-server)

## 先决条件

- 操作系统：Linux
- Python：3.10 -- 3.13

## 安装

=== "NVIDIA CUDA"

    如果您使用的是 NVIDIA GPU，可以直接使用 [pip](https://pypi.org/project/vllm/) 安装 vLLM。

    建议使用 [uv](https://docs.astral.sh/uv/)（一个非常快速的 Python 环境管理工具）来创建和管理 Python 环境。请按照 [文档](https://docs.astral.sh/uv/#getting-started) 安装 `uv`。安装 `uv` 后，您可以使用以下命令创建新的 Python 环境并安装 vLLM：

    ```bash
    uv venv --python 3.12 --seed
    source .venv/bin/activate
    uv pip install vllm --torch-backend=auto
    ```

    `uv` 可以通过 `--torch-backend=auto`（或 `UV_TORCH_BACKEND=auto`）检查已安装的 CUDA 驱动版本，从而[在运行时自动选择合适的 PyTorch 后端](https://docs.astral.sh/uv/guides/integration/pytorch/#automatic-backend-selection)。若要指定特定后端（例如 `cu126`），请设置 `--torch-backend=cu126`（或 `UV_TORCH_BACKEND=cu126`）。

    另一种便捷方式是使用 `uv run` 配合 `--with [dependency]` 选项，这样无需创建永久环境即可运行 `vllm serve` 等命令：

    ```bash
    uv run --with vllm vllm --help
    ```

    您也可以使用 [conda](https://docs.conda.io/projects/conda/en/latest/user-guide/getting-started.html) 创建和管理 Python 环境。如果需要在 conda 环境中管理依赖，可通过 `pip` 在该环境中安装 `uv`。

    ```bash
    conda create -n myenv python=3.12 -y
    conda activate myenv
    pip install --upgrade uv
    uv pip install vllm --torch-backend=auto
    ```

=== "AMD ROCm"

    如果您使用的是 AMD GPU，可以使用 `uv` 安装 vLLM。

    建议使用 [uv](https://docs.astral.sh/uv/)，因为它会给额外索引赋予[比默认索引更高的优先级](https://docs.astral.sh/uv/pip/compatibility/#packages-that-exist-on-multiple-indexes)。`uv` 同样是一个非常快速的 Python 环境管理工具。请按照 [文档](https://docs.astral.sh/uv/#getting-started) 安装 `uv`。安装 `uv` 后，您可以使用以下命令创建新的 Python 环境并安装 vLLM：

    ```bash
    uv venv --python 3.12 --seed
    source .venv/bin/activate
    uv pip install vllm --extra-index-url https://wheels.vllm.ai/rocm/
    ```

    !!! note
        当前仅支持 Python 3.12、ROCm 7.0 和 `glibc >= 2.35`。

    !!! note    
        注意：此前，Docker 镜像通过 AMD 的 Docker 发布流水线发布，位于 `rocm/vlm-dev`。现在已改用 vLLM 的 Docker 发布流水线，该方式将被弃用。

=== "Google TPU"

    若要在 Google TPU 上运行 vLLM，需安装 `vllm-tpu` 包。
    
    ```bash
    uv pip install vllm-tpu
    ```

    !!! note
        如需更详细的说明（包括 Docker、从源码安装以及故障排查），请参阅 [vLLM on TPU 文档](https://docs.vllm.ai/projects/tpu/en/latest/)。

!!! note
    如需更详细说明或非 CUDA 平台的安装指导，请参阅 [安装指南](installation/README.md)，了解如何为特定平台安装 vLLM。

## 离线批量推理

安装 vLLM 后，您可以开始对输入提示列表生成文本（即离线批量推理）。参考示例脚本：[examples/offline_inference/basic/basic.py](../../examples/offline_inference/basic/basic.py)

该示例的第一行导入了 [LLM][vllm.LLM] 和 [SamplingParams][vllm.SamplingParams] 类：

- [LLM][vllm.LLM] 是使用 vLLM 引擎进行离线推理的主要类。
- [SamplingParams][vllm.SamplingParams] 指定采样过程的参数。

```python
from vllm import LLM, SamplingParams
```

下一部分定义了输入提示列表和文本生成的采样参数。[采样温度](https://arxiv.org/html/2402.05201v1) 设为 `0.8`，[核采样概率](https://en.wikipedia.org/wiki/Top-p_sampling) 设为 `0.95`。关于采样参数的更多信息，请参见[此处](../api/README.md#inference-parameters)。

!!! important
    默认情况下，如果 Hugging Face 模型仓库中存在 `generation_config.json`，vLLM 将使用模型创建者推荐的采样参数。在大多数情况下，如果不指定 [SamplingParams][vllm.SamplingParams]，这将为您提供最佳结果。

    但如果希望使用 vLLM 的默认采样参数，请在创建 [LLM][vllm.LLM] 实例时将 `generation_config` 设为 `"vllm"`。

```python
prompts = [
    "Hello, my name is",
    "The president of the United States is",
    "The capital of France is",
    "The future of AI is",
]
sampling_params = SamplingParams(temperature=0.8, top_p=0.95)
```

[LLM][vllm.LLM] 类会初始化 vLLM 引擎和 [OPT-125M 模型](https://arxiv.org/abs/2205.01068) 以进行离线推理。支持的模型列表请参见[此处](../models/supported_models.md)。

```python
llm = LLM(model="facebook/opt-125m")
```

!!! note
    默认情况下，vLLM 会从 [Hugging Face](https://huggingface.co/) 下载模型。如果希望使用 [ModelScope](https://www.modelscope.cn) 的模型，请在初始化引擎前设置环境变量 `VLLM_USE_MODELSCOPE`。

    ```shell
    export VLLM_USE_MODELSCOPE=True
    ```

现在，精彩的部分来了！通过 `llm.generate` 生成输出。该方法将输入提示添加到 vLLM 引擎的等待队列中，并执行 vLLM 引擎以高速生成输出。输出以 `RequestOutput` 对象列表的形式返回，其中包含所有输出 token。

```python
outputs = llm.generate(prompts, sampling_params)

for output in outputs:
    prompt = output.prompt
    generated_text = output.outputs[0].text
    print(f"Prompt: {prompt!r}, Generated text: {generated_text!r}")
```

!!! note
    `llm.generate` 方法不会自动对输入提示应用模型的对话模板。因此，如果使用 Instruct 模型或 Chat 模型，应手动应用对应的对话模板以确保预期行为。或者，也可以使用 `llm.chat` 方法并传入消息列表，其格式与传递给 OpenAI 的 `client.chat.completions` 的格式相同：

    ??? code
    
        ```python
        # 使用 tokenizer 应用对话模板
        from transformers import AutoTokenizer
    
        tokenizer = AutoTokenizer.from_pretrained("/path/to/chat_model")
        messages_list = [
            [{"role": "user", "content": prompt}]
            for prompt in prompts
        ]
        texts = tokenizer.apply_chat_template(
            messages_list,
            tokenize=False,
            add_generation_prompt=True,
        )
        
        # 生成输出
        outputs = llm.generate(texts, sampling_params)
        
        # 打印输出
        for output in outputs:
            prompt = output.prompt
            generated_text = output.outputs[0].text
            print(f"Prompt: {prompt!r}, Generated text: {generated_text!r}")
    
        # 使用 chat 接口
        outputs = llm.chat(messages_list, sampling_params)
        for idx, output in enumerate(outputs):
            prompt = prompts[idx]
            generated_text = output.outputs[0].text
            print(f"Prompt: {prompt!r}, Generated text: {generated_text!r}")
        ```

## 兼容 OpenAI 的服务器

vLLM 可以部署为一个实现了 OpenAI API 协议的服务端。这使得 vLLM 能够作为使用 OpenAI API 的应用程序的即插即用替代方案。

默认情况下，服务端启动地址为 `http://localhost:8000`。您可以通过 `--host` 和 `--port` 参数指定地址。服务端目前一次只能托管一个模型，并实现了诸如[列出模型](https://platform.openai.com/docs/api-reference/models/list)、[创建聊天补全](https://platform.openai.com/docs/api-reference/chat/completions/create)和[创建补全](https://platform.openai.com/docs/api-reference/completions/create)等端点。

运行以下命令以使用 [Qwen2.5-1.5B-Instruct](https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct) 模型启动 vLLM 服务端：

```bash
vllm serve Qwen/Qwen2.5-1.5B-Instruct
```

!!! note
    默认情况下，服务端使用分词器中存储的预定义聊天模板。
    您可以了解如何覆盖它[此处](../serving/openai_compatible_server.md#chat-template)。
!!! important
    默认情况下，如果存在，服务端会应用 Hugging Face 模型仓库中的 `generation_config.json`。这意味着某些采样参数的默认值可能会被模型创建者推荐的值覆盖。

    要禁用此行为，请在启动服务端时传递 `--generation-config vllm`。

可以使用与 OpenAI API 相同的格式查询此服务端。例如，列出模型：

```bash
curl http://localhost:8000/v1/models
```

您可以传递 `--api-key` 参数或设置环境变量 `VLLM_API_KEY` 以启用服务端检查请求头中的 API 密钥。
您可以在 `--api-key` 后传递多个密钥，服务端将接受任何传递的密钥，这对于密钥轮换非常有用。

### 使用 vLLM 的 OpenAI 补全 API

一旦您的服务端启动，您可以使用输入提示查询模型：

```bash
curl http://localhost:8000/v1/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "Qwen/Qwen2.5-1.5B-Instruct",
        "prompt": "San Francisco is a",
        "max_tokens": 7,
        "temperature": 0
    }'
```

由于此服务端与 OpenAI API 兼容，您可以将其作为任何使用 OpenAI API 的应用程序的即插即用替代方案。例如，另一种查询服务端的方式是通过 `openai` Python 包：

??? code

    ```python
    from openai import OpenAI

    # 修改 OpenAI 的 API 密钥和 API 基础 URL 以使用 vLLM 的 API 服务端。
    openai_api_key = "EMPTY"
    openai_api_base = "http://localhost:8000/v1"
    client = OpenAI(
        api_key=openai_api_key,
        base_url=openai_api_base,
    )
    completion = client.completions.create(
        model="Qwen/Qwen2.5-1.5B-Instruct",
        prompt="San Francisco is a",
    )
    print("Completion result:", completion)
    ```

更详细的客户端示例可以在这里找到：[examples/offline_inference/basic/basic.py](../../examples/offline_inference/basic/basic.py)

### 使用 vLLM 的 OpenAI 聊天补全 API

vLLM 也设计为支持 OpenAI 聊天补全 API。聊天界面是一种更动态、交互式的与模型通信的方式，允许来回交流并可以存储在聊天历史中。这对于需要上下文或更详细解释的任务非常有用。

您可以使用[创建聊天补全](https://platform.openai.com/docs/api-reference/chat/completions/create)端点与模型交互：

```bash
curl http://localhost:8000/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "Qwen/Qwen2.5-1.5B-Instruct",
        "messages": [
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": "Who won the world series in 2020?"}
        ]
    }'
```

或者，您可以使用 `openai` Python 包：

??? code

    ```python
    from openai import OpenAI
    # 设置 OpenAI 的 API 密钥和 API 基础 URL 以使用 vLLM 的 API 服务端。
    openai_api_key = "EMPTY"
    openai_api_base = "http://localhost:8000/v1"

    client = OpenAI(
        api_key=openai_api_key,
        base_url=openai_api_base,
    )

    chat_response = client.chat.completions.create(
        model="Qwen/Qwen2.5-1.5B-Instruct",
        messages=[
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": "Tell me a joke."},
        ],
    )
    print("Chat response:", chat_response)
    ```

## 关于注意力后端

目前，vLLM 支持多个后端，以便在不同的平台和加速器架构上进行高效的注意力计算。它会自动选择与您的系统和模型规格兼容的性能最佳的后端。

如果需要，您也可以使用 `--attention-backend` CLI 参数手动设置您选择的后端：

```bash
# 用于在线服务
vllm serve Qwen/Qwen2.5-1.5B-Instruct --attention-backend FLASH_ATTN

# 用于离线推理
python script.py --attention-backend FLASHINFER
```

一些可用的后端选项包括：

- 在 NVIDIA CUDA 上：`FLASH_ATTN` 或 `FLASHINFER`。
- 在 AMD ROCm 上：`TRITON_ATTN`、`ROCM_ATTN`、`ROCM_AITER_FA`、`ROCM_AITER_UNIFIED_ATTN`、`TRITON_MLA`、`ROCM_AITER_MLA` 或 `ROCM_AITER_TRITON_MLA`。

!!! warning
    没有包含 Flash Infer 的预构建 vllm wheel，因此您必须先在您的环境中安装它。请参考 [Flash Infer 官方文档](https://docs.flashinfer.ai/) 或查看 [docker/Dockerfile](../../docker/Dockerfile) 以了解如何安装它。