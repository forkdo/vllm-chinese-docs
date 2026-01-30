---
title: 基础用法
description: 通过 Python 代码直接与模型交互的离线推理接口
linkTitle: 基础用法
weight: 1
type: docs
---

# 基础

源码 <https://github.com/vllm-project/vllm/tree/main/examples/offline_inference/basic>。

`LLM` 类提供了进行离线推理的主要 Python 接口，即在不使用单独模型推理服务器的情况下与模型进行交互。

## 使用方法

此示例中的第一个脚本展示了 vLLM 最基础的用法。如果您是 Python 和 vLLM 的初学者，建议从这里开始。

```bash
python examples/offline_inference/basic/basic.py
```

其余脚本包含一个 [argument parser](https://docs.python.org/3/library/argparse.html)，您可以使用它传递与 [`LLM`](https://docs.vllm.ai/en/latest/api/offline_inference/llm.html) 兼容的任何参数。尝试运行脚本并使用 `--help` 查看所有可用参数的列表。

```bash
python examples/offline_inference/basic/classify.py
```

```bash
python examples/offline_inference/basic/embed.py
```

```bash
python examples/offline_inference/basic/score.py
```

聊天和生成脚本还接受以下[采样参数](https://docs.vllm.ai/en/latest/api/inference_params.html#sampling-parameters)：`max_tokens`、`temperature`、`top_p` 和 `top_k`。

```bash
python examples/offline_inference/basic/chat.py
```

```bash
python examples/offline_inference/basic/generate.py
```

## 功能特性

在支持传递参数的脚本中，您可以尝试以下功能特性。

### 默认生成配置

`--generation-config` 参数指定在调用 `LLM.get_default_sampling_params()` 时从何处加载生成配置。如果设置为 'auto'，则从模型路径加载生成配置。如果设置为文件夹路径，则从指定的文件夹路径加载生成配置。如果不提供此参数，则使用 vLLM 的默认配置。

> 如果在生成配置中指定了 max_new_tokens，它会为所有请求设置服务器范围内的输出 token 数量限制。

请尝试使用以下参数进行体验：

```bash
--generation-config auto
```

### 量化

#### GGUF

vLLM 支持使用 GGUF 进行量化的模型。

请通过下载一个量化 GGUF 模型并使用以下参数进行尝试：

```python
from huggingface_hub import hf_hub_download
repo_id = "bartowski/Phi-3-medium-4k-instruct-GGUF"
filename = "Phi-3-medium-4k-instruct-IQ2_M.gguf"
print(hf_hub_download(repo_id, filename=filename))
```

```bash
--model {local-path-printed-above} --tokenizer microsoft/Phi-3-medium-4k-instruct
```

### CPU 卸载

`--cpu-offload-gb` 参数可以看作是虚拟地增加 GPU 内存大小的方式。例如，如果您有一块 24 GB 的 GPU，并将此参数设为 10，那么您可以将其看作一块 34 GB 的 GPU。然后您可以加载一个 13B 的模型，该模型使用 BF16 权重，至少需要 26GB 的 GPU 内存。请注意，这需要快速的 CPU-GPU 互连，因为在每次模型前向传播过程中，模型的一部分会从 CPU 内存动态加载到 GPU 内存中。

请尝试使用以下参数：

```bash
--model meta-llama/Llama-2-13b-chat-hf --cpu-offload-gb 10
```

## 示例代码

??? abstract "basic.py"
    ``````py
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/offline_inference/basic/basic.py"
    ``````
??? abstract "chat.py"
    ``````py
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/offline_inference/basic/chat.py"
    ``````
??? abstract "classify.py"
    ``````py
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/offline_inference/basic/classify.py"
    ``````
??? abstract "embed.py"
    ``````py
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/offline_inference/basic/embed.py"
    ``````
??? abstract "generate.py"
    ``````py
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/offline_inference/basic/generate.py"
    ``````
??? abstract "reward.py"
    ``````py
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/offline_inference/basic/reward.py"
    ``````
??? abstract "score.py"
    ``````py
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/offline_inference/basic/score.py"
    ``````