# 支持的模型

vLLM 支持各种任务中的[生成式](./generative_models.md)和[池化](./pooling_models.md)模型。

对于每个任务，我们列出了已在 vLLM 中实现的模型架构。
在每个架构旁边，我们包含了一些使用该架构的流行模型。

## 模型实现

### vLLM

如果 vLLM 原生支持某个模型，其实现可以在 [vllm/model_executor/models](../../vllm/model_executor/models) 中找到。

这些模型就是我们在[支持的文本模型列表](#list-of-text-only-language-models)和[支持的多模态模型列表](#list-of-multimodal-language-models)中列出的模型。

### Transformers

vLLM 还支持 Transformers 中可用的模型实现。你应该期望在 vLLM 中使用的 Transformers 模型实现的性能在 <5% 范围内与专用 vLLM 模型实现的性能相当。我们称此功能为"Transformers 建模后端"。

目前，Transformers 建模后端适用于以下内容：

- 模态：嵌入模型、语言模型和视觉语言模型*
- 架构：仅编码器、仅解码器、专家混合
- 注意力类型：全注意力和/或滑动注意力

_*视觉语言模型目前仅接受图像输入。对视频输入的支持将在未来版本中添加。_

如果 Transformers 模型实现遵循了[编写自定义模型](#writing-custom-models)中的所有步骤，那么当与 Transformers 建模后端一起使用时，它将与以下 vLLM 功能兼容：

- [兼容性矩阵](../features/README.md#feature-x-feature)中列出的所有功能
- 以下 vLLM 并行化方案的任意组合：
    - 数据并行
    - 张量并行
    - 专家并行
    - 流水线并行

检查建模后端是否为 Transformers 很简单：

```python
from vllm import LLM
llm = LLM(model=...)  # 您模型的名称或路径
llm.apply_model(lambda model: print(type(model)))
```

如果打印的类型以 `Transformers...` 开头，那么它正在使用 Transformers 模型实现！

如果一个模型有 vLLM 实现，但您更愿意通过 Transformers 建模后端使用 Transformers 实现，请为[离线推理](../serving/offline_inference.md)设置 `model_impl="transformers"` 或为[在线服务](../serving/openai_compatible_server.md)设置 `--model-impl transformers`。

!!! note
    对于视觉语言模型，如果您使用 `dtype="auto"` 加载，vLLM 会使用配置中的 `dtype`（如果存在）加载整个模型。相比之下，原生 Transformers 会尊重模型中每个主干的 `dtype` 属性。这可能会导致性能上的轻微差异。

#### 自定义模型

如果一个模型既不被 vLLM 也不被 Transformers 原生支持，它仍然可以在 vLLM 中使用！

要使模型与 vLLM 的 Transformers 建模后端兼容，它必须：

- 是一个 Transformers 兼容的自定义模型（参见 [Transformers - Customizing models](https://huggingface.co/docs/transformers/en/custom_models)）：
    - 模型目录必须具有正确的结构（例如存在 `config.json`）。
    - `config.json` 必须包含 `auto_map.AutoModel`。
- 是一个 vLLM 的 Transformers 建模后端兼容模型（参见[编写自定义模型](#writing-custom-models)）：
    - 自定义应该在基础模型中完成（例如在 `MyModel` 中，而不是 `MyModelForCausalLM` 中）。

如果兼容模型是：

- 在 Hugging Face Model Hub 上，只需为[离线推理](../serving/offline_inference.md)设置 `trust_remote_code=True` 或为[openai兼容服务器](../serving/openai_compatible_server.md)设置 `--trust-remote-code`。
- 在本地目录中，只需将目录路径传递给 `model=<MODEL_DIR>` 用于[离线推理](../serving/offline_inference.md)或 `vllm serve <MODEL_DIR>` 用于[openai兼容服务器](../serving/openai_compatible_server.md)。

这意味着，通过 vLLM 的 Transformers 建模后端，可以在 Transformers 或 vLLM 官方支持之前使用新模型！

#### 编写自定义模型

本节详细说明了对 Transformers 兼容的自定义模型进行必要的修改，以使其与 vLLM 的 Transformers 建模后端兼容。（我们假设已经创建了 Transformers 兼容的自定义模型，参见 [Transformers - Customizing models](https://huggingface.co/docs/transformers/en/custom_models)）。

要使您的模型与 Transformers 建模后端兼容，它需要：

1. `kwargs` 从 `MyModel` 到 `MyAttention` 的所有模块中传递。
    - 如果您的模型是仅编码器：
        1. 在 `MyAttention` 中添加 `is_causal = False`。
    - 如果您的模型是专家混合（MoE）：
        1. 您的稀疏 MoE 块必须有一个名为 `experts` 的属性。
        2. `experts` 的类（`MyExperts`）必须要么：
            - 继承自 `nn.ModuleList`（简单）。
            - 或包含所有 3D `nn.Parameters`（打包）。
        3. `MyExperts.forward` 必须接受 `hidden_states`、`top_k_index`、`top_k_weights`。
2. `MyAttention` 必须使用 `ALL_ATTENTION_FUNCTIONS` 来调用注意力。
3. `MyModel` 必须包含 `_supports_attention_backend = True`。

<details class="code">
<summary>modeling_my_model.py</summary>

```python

from transformers import PreTrainedModel
from torch import nn

class MyAttention(nn.Module):
    is_causal = False  # 仅对仅编码器模型执行此操作

    def forward(self, hidden_states, **kwargs):
        ...
        attention_interface = ALL_ATTENTION_FUNCTIONS[self.config._attn_implementation]
        attn_output, attn_weights = attention_interface(
            self,
            query_states,
            key_states,
            value_states,
            **kwargs,
        )
        ...

# 仅对专家混合模型执行此操作
class MyExperts(nn.ModuleList):
    def forward(self, hidden_states, top_k_index, top_k_weights):
        ...

# 仅对专家混合模型执行此操作
class MySparseMoEBlock(nn.Module):
    def __init__(self, config):
        ...
        self.experts = MyExperts(config)
        ...

    def forward(self, hidden_states: torch.Tensor):
        ...
        hidden_states = self.experts(hidden_states, top_k_index, top_k_weights)
        ...

class MyModel(PreTrainedModel):
    _supports_attention_backend = True
```

</details>

以下是加载此模型时在后台发生的情况：

1. 加载配置。
2. 从配置中的 `auto_map` 加载 `MyModel` Python 类，我们检查模型是否 `is_backend_compatible()`。
3. `MyModel` 被加载到 [vllm/model_executor/models/transformers](../../vllm/model_executor/models/transformers) 中的 Transformers 建模后端类之一，该类设置 `self.config._attn_implementation = "vllm"` 以便使用 vLLM 的注意力层。

就是这样！

要使您的模型与 vLLM 的张量并行和/或流水线并行功能兼容，您必须在模型的配置类中添加 `base_model_tp_plan` 和/或 `base_model_pp_plan`：

<details class="code">
<summary>configuration_my_model.py</summary>

```python

from transformers import PretrainedConfig

class MyConfig(PretrainedConfig):
    base_model_tp_plan = {
        "layers.*.self_attn.k_proj": "colwise",
        "layers.*.self_attn.v_proj": "colwise",
        "layers.*.self_attn.o_proj": "rowwise",
        "layers.*.mlp.gate_proj": "colwise",
        "layers.*.mlp.up_proj": "colwise",
        "layers.*.mlp.down_proj": "rowwise",
    }
    base_model_pp_plan = {
        "embed_tokens": (["input_ids"], ["inputs_embeds"]),
        "layers": (["hidden_states", "attention_mask"], ["hidden_states"]),
        "norm": (["hidden_states"], ["hidden_states"]),
    }
```

</details>

- `base_model_tp_plan` 是一个 `dict`，它将完全限定的层名称模式映射到张量并行样式（目前仅支持 `"colwise"` 和 `"rowwise"`）。
- `base_model_pp_plan` 是一个 `dict`，它将直接子层名称映射到 `str` 的 `list` 的 `tuple`：
    - 您只需要为不是在所有流水线阶段都存在的层执行此操作
    - vLLM 假设只会有一个 `nn.ModuleList`，它在流水线阶段之间分布
    - `tuple` 第一个元素中的 `list` 包含输入参数的名称
    - `tuple` 最后一个元素中的 `list` 包含在您的建模代码中层输出到的变量名称

## 加载模型

### Hugging Face Hub

默认情况下，vLLM 从 [Hugging Face (HF) Hub](https://huggingface.co/models) 加载模型。要更改模型的下载路径，您可以设置 `HF_HOME` 环境变量；更多详细信息，请参阅 [他们的官方文档](https://huggingface.co/docs/huggingface_hub/package_reference/environment_variables#hfhome)。

要确定给定模型是否原生支持，您可以检查 HF 仓库内的 `config.json` 文件。
如果 `"architectures"` 字段包含以下列出的模型架构，则应该原生支持。

模型在 vLLM 中使用时并不 _需要_ 原生支持。
[Transformers 建模后端](#transformers) 使您能够直接使用其 Transformers 实现运行模型（甚至可以使用 Hugging Face Model Hub 上的远程代码！）。

!!! tip
    检查您的模型在运行时是否真正受支持的最简单方法是运行以下程序：

    ```python
    from vllm import LLM

    # 仅适用于生成模型 (runner=generate)
    llm = LLM(model=..., runner="generate")  # 您模型的名称或路径
    output = llm.generate("Hello, my name is")
    print(output)

    # 仅适用于池化模型 (runner=pooling)
    llm = LLM(model=..., runner="pooling")  # 您模型的名称或路径
    output = llm.encode("Hello, my name is")
    print(output)
    ```

    如果 vLLM 成功返回文本（对于生成模型）或隐藏状态（对于池化模型），则表明您的模型受支持。

否则，请参阅 [添加新模型](../contributing/model/README.md) 了解如何在 vLLM 中实现您的模型的说明。
或者，您可以 [在 GitHub 上提交问题](https://github.com/vllm-project/vllm/issues/new/choose) 请求 vLLM 支持。

#### 下载模型

如果愿意，您可以使用 Hugging Face CLI [下载模型](https://huggingface.co/docs/huggingface_hub/guides/cli#huggingface-cli-download) 或从模型仓库下载特定文件：

```bash
# 下载模型
huggingface-cli download HuggingFaceH4/zephyr-7b-beta

# 指定自定义缓存目录
huggingface-cli download HuggingFaceH4/zephyr-7b-beta --cache-dir ./path/to/cache

# 从模型仓库下载特定文件
huggingface-cli download HuggingFaceH4/zephyr-7b-beta eval_results.json
```

#### 列出已下载的模型

使用 Hugging Face CLI [管理](https://huggingface.co/docs/huggingface_hub/guides/manage-cache#scan-your-cache) 存储在本地缓存中的模型：

```bash
# 列出缓存的模型
huggingface-cli scan-cache

# 显示详细（详细）输出
huggingface-cli scan-cache -v

# 指定自定义缓存目录
huggingface-cli scan-cache --dir ~/.cache/huggingface/hub
```

#### 删除缓存的模型

使用 Hugging Face CLI 交互式地从缓存中 [删除下载的模型](https://huggingface.co/docs/huggingface_hub/guides/manage-cache#clean-your-cache)：

<details>
<summary>命令</summary>

```console
# `delete-cache` 命令需要额外的依赖项才能与 TUI 一起工作。
# 请运行 `pip install huggingface_hub[cli]` 来安装它们。

# 启动交互式 TUI 以选择要删除的模型
$ huggingface-cli delete-cache
? Select revisions to delete: 1 revisions selected counting for 438.9M.
  ○ None of the following (if selected, nothing will be deleted).
Model BAAI/bge-base-en-v1.5 (438.9M, used 1 week ago)
❯ ◉ a5beb1e3: main # modified 1 week ago

Model BAAI/bge-large-en-v1.5 (1.3G, used 1 week ago)
  ○ d4aa6901: main # modified 1 week ago

Model BAAI/bge-reranker-base (1.1G, used 4 weeks ago)
  ○ 2cfc18c9: main # modified 4 weeks ago

Press <space> to select, <enter> to validate and <ctrl+c> to quit without modification.

# 选择后需要确认
? Select revisions to delete: 1 revision(s) selected.
? 1 revisions selected counting for 438.9M. Confirm deletion ? Yes
Start deletion.
Done. Deleted 1 repo(s) and 0 revision(s) for a total of 438.9M.
```

</details>

#### 使用代理

以下是一些使用代理从 Hugging Face 加载/下载模型的提示：

- 为您的会话全局设置代理（或在配置文件中设置）：

```shell
export http_proxy=http://your.proxy.server:port
export https_proxy=http://your.proxy.server:port
```

- 仅为当前命令设置代理：

```shell
https_proxy=http://your.proxy.server:port huggingface-cli download <model_name>

# 或直接使用 vllm 命令
https_proxy=http://your.proxy.server:port  vllm serve <model_name>
```

- 在 Python 解释器中设置代理：

```python
import os

os.environ["http_proxy"] = "http://your.proxy.server:port"
os.environ["https_proxy"] = "http://your.proxy.server:port"
```

### ModelScope

要使用 [ModelScope](https://www.modelscope.cn) 的模型而不是 Hugging Face Hub，请设置环境变量：

```shell
export VLLM_USE_MODELSCOPE=True
```

并使用 `trust_remote_code=True`。

```python
from vllm import LLM

llm = LLM(model=..., revision=..., runner=..., trust_remote_code=True)

# 仅适用于生成模型 (runner=generate)
output = llm.generate("Hello, my name is")
print(output)

# 仅适用于池化模型 (runner=pooling)
output = llm.encode("Hello, my name is")
print(output)
```

## 功能状态图例

- ✅︎ 表示该功能受模型支持。

- 🚧 表示该功能已计划但尚未受模型支持。

- ⚠️ 表示该功能可用但可能存在已知问题或限制。

## 纯文本语言模型列表

### 生成模型

有关如何使用生成模型的更多信息，请参见 [此页面](generative_models.md)。

#### 文本生成

这些模型主要接受 [`LLM.generate`](./generative_models.md#llmgenerate) API。Chat/Instruct 模型还支持 [`LLM.chat`](./generative_models.md#llmchat) API。

<style>
th {
  white-space: nowrap;
  min-width: 0 !important;
}
</style>

| 架构 | 模型 | 示例 HF 模型 | [LoRA](../features/lora.md) | [PP](../serving/parallelism_scaling.md) |
|--------------|--------|-------------------|----------------------|---------------------------|
| `AfmoeForCausalLM` | Afmoe | TBA | ✅︎ | ✅︎ |
| `ApertusForCausalLM` | Apertus | `swiss-ai/Apertus-8B-2509`, `swiss-ai/Apertus-70B-Instruct-2509`, 等 | ✅︎ | ✅︎ |
| `AquilaForCausalLM` | Aquila, Aquila2 | `BAAI/Aquila-7B`, `BAAI/AquilaChat-7B`, 等 | ✅︎ | ✅︎ |
| `ArceeForCausalLM` | Arcee (AFM) | `arcee-ai/AFM-4.5B-Base`, 等 | ✅︎ | ✅︎ |
| `ArcticForCausalLM` | Arctic | `Snowflake/snowflake-arctic-base`, `Snowflake/snowflake-arctic-instruct`, 等 | | ✅︎ |
| `BaiChuanForCausalLM` | Baichuan2, Baichuan | `baichuan-inc/Baichuan2-13B-Chat`, `baichuan-inc/Baichuan-7B`, 等 | ✅︎ | ✅︎ |
| `BailingMoeForCausalLM` | Ling | `inclusionAI/Ling-lite-1.5`, `inclusionAI/Ling-plus`, 等 | ✅︎ | ✅︎ |
| `BailingMoeV2ForCausalLM` | Ling | `inclusionAI/Ling-mini-2.0`, 等 | ✅︎ | ✅︎ |
| `BambaForCausalLM` | Bamba | `ibm-ai-platform/Bamba-9B-fp8`, `ibm-ai-platform/Bamba-9B` | ✅︎ | ✅︎ |
| `BloomForCausalLM` | BLOOM, BLOOMZ, BLOOMChat | `bigscience/bloom`, `bigscience/bloomz`, 等 | | ✅︎ |
| `ChatGLMModel`, `ChatGLMForConditionalGeneration` | ChatGLM | `zai-org/chatglm2-6b`, `zai-org/chatglm3-6b`, `thu-coai/ShieldLM-6B-chatglm3`, 等 | ✅︎ | ✅︎ |
| `CohereForCausalLM`, `Cohere2ForCausalLM` | Command-R, Command-A | `CohereLabs/c4ai-command-r-v01`, `CohereLabs/c4ai-command-r7b-12-2024`, `CohereLabs/c4ai-command-a-03-2025`, `CohereLabs/command-a-reasoning-08-2025`, 等 | ✅︎ | ✅︎ |
| `DbrxForCausalLM` | DBRX | `databricks/dbrx-base`, `databricks/dbrx-instruct`, 等 | | ✅︎ |
| `DeciLMForCausalLM` | DeciLM | `nvidia/Llama-3_3-Nemotron-Super-49B-v1`, 等 | ✅︎ | ✅︎ |
| `DeepseekForCausalLM` | DeepSeek | `deepseek-ai/deepseek-llm-67b-base`, `deepseek-ai/deepseek-llm-7b-chat`, 等 | ✅︎ | ✅︎ |
| `DeepseekV2ForCausalLM` | DeepSeek-V2 | `deepseek-ai/DeepSeek-V2`, `deepseek-ai/DeepSeek-V2-Chat`, 等 | ✅︎ | ✅︎ |
| `DeepseekV3ForCausalLM` | DeepSeek-V3 | `deepseek-ai/DeepSeek-V3`, `deepseek-ai/DeepSeek-R1`, `deepseek-ai/DeepSeek-V3.1`, 等 | ✅︎ | ✅︎ |
| `Dots1ForCausalLM` | dots.llm1 | `rednote-hilab/dots.llm1.base`, `rednote-hilab/dots.llm1.inst`, 等 | | ✅︎ |
| `DotsOCRForCausalLM` | dots_ocr | `rednote-hilab/dots.ocr` | ✅︎ | ✅︎ |
| `Ernie4_5ForCausalLM` | Ernie4.5 | `baidu/ERNIE-4.5-0.3B-PT`, 等 | ✅︎ | ✅︎ |
| `Ernie4_5_MoeForCausalLM` | Ernie4.5MoE | `baidu/ERNIE-4.5-21B-A3B-PT`, `baidu/ERNIE-4.5-300B-A47B-PT`, 等 |✅︎| ✅︎ |
| `ExaoneForCausalLM` | EXAONE-3 | `LGAI-EXAONE/EXAONE-3.0-7.8B-Instruct`, 等 | ✅︎ | ✅︎ |
| `ExaoneMoeCausalLM` | K-EXAONE | `LGAI-EXAONE/K-EXAONE-236B-A23B`, 等 | | |
| `Exaone4ForCausalLM` | EXAONE-4 | `LGAI-EXAONE/EXAONE-4.0-32B`, 等 | ✅︎ | ✅︎ |
| `Fairseq2LlamaForCausalLM` | Llama (fairseq2 format) | `mgleize/fairseq2-dummy-Llama-3.2-1B`, 等 | ✅︎ | ✅︎ |
| `FalconForCausalLM` | Falcon | `tiiuae/falcon-7b`, `tiiuae/falcon-40b`, `tiiuae/falcon-rw-7b`, 等 | | ✅︎ |
| `FalconMambaForCausalLM` | FalconMamba | `tiiuae/falcon-mamba-7b`, `tiiuae/falcon-mamba-7b-instruct`, 等 | | ✅︎ |
| `FalconH1ForCausalLM` | Falcon-H1 | `tiiuae/Falcon-H1-34B-Base`, `tiiuae/Falcon-H1-34B-Instruct`, 等 | ✅︎ | ✅︎ |
| `FlexOlmoForCausalLM` | FlexOlmo | `allenai/FlexOlmo-7x7B-1T`, `allenai/FlexOlmo-7x7B-1T-RT`, 等 | | ✅︎ |
| `GemmaForCausalLM` | Gemma | `google/gemma-2b`, `google/gemma-1.1-2b-it`, 等 | ✅︎ | ✅︎ |
| `Gemma2ForCausalLM` | Gemma 2 | `google/gemma-2-9b`, `google/gemma-2-27b`, 等 | ✅︎ | ✅︎ |
| `Gemma3ForCausalLM` | Gemma 3 | `google/gemma-3-1b-it`, 等 | ✅︎ | ✅︎ |
| `Gemma3nForCausalLM` | Gemma 3n | `google/gemma-3n-E2B-it`, `google/gemma-3n-E4B-it`, 等 | | |
| `GlmForCausalLM` | GLM-4 | `zai-org/glm-4-9b-chat-hf`, 等 | ✅︎ | ✅︎ |
| `Glm4ForCausalLM` | GLM-4-0414 | `zai-org/GLM-4-32B-0414`, 等 | ✅︎ | ✅︎ |
| `Glm4MoeForCausalLM` | GLM-4.5, GLM-4.6, GLM-4.7 | `zai-org/GLM-4.5`, 等 | ✅︎ | ✅︎ |
| `GPT2LMHeadModel` | GPT-2 | `openai-community/gpt2`, `openai-community/gpt2-xl`, 等 | | ✅︎ |
| `GPTBigCodeForCausalLM` | StarCoder, SantaCoder, WizardCoder | `bigcode/starcoder`, `bigcode/gpt_bigcode-santacoder`, `WizardLM/WizardCoder-15B-V1.0`, 等 | ✅︎ | ✅︎ |
| `GPTJForCausalLM` | GPT-J | `EleutherAI/gpt-j-6b`, `nomic-ai/gpt4all-j`, 等 | | ✅︎ |
| `GPTNeoXForCausalLM` | GPT-NeoX, Pythia, OpenAssistant, Dolly V2, StableLM | `EleutherAI/gpt-neox-20b`, `EleutherAI/pythia-12b`, `OpenAssistant/oasst-sft-4-pythia-12b-epoch-3.5`, `databricks/dolly-v2-12b`, `stabilityai/stablelm-tuned-alpha-7b`, 等 | | ✅︎ |
| `GptOssForCausalLM` | GPT-OSS | `openai/gpt-oss-120b`, `openai/gpt-oss-20b` | ✅︎ | ✅︎ |
| `GraniteForCausalLM` | Granite 3.0, Granite 3.1, PowerLM | `ibm-granite/granite-3.0-2b-base`, `ibm-granite/granite-3.1-8b-instruct`, `ibm/PowerLM-3b`, 等 | ✅︎ | ✅︎ |
| `GraniteMoeForCausalLM` | Granite 3.0 MoE, PowerMoE | `ibm-granite/granite-3.0-1b-a400m-base`, `ibm-granite/granite-3.0-3b-a800m-instruct`, `ibm/PowerMoE-3b`, 等 | ✅︎ | ✅︎ |
| `GraniteMoeHybridForCausalLM` | Granite 4.0 MoE Hybrid | `ibm-granite/granite-4.0-tiny-preview`, 等 | ✅︎ | ✅︎ |
| `GraniteMoeSharedForCausalLM` | Granite MoE Shared | `ibm-research/moe-7b-1b-active-shared-experts` (测试模型) | ✅︎ | ✅︎ |
| `GritLM` | GritLM | `parasail-ai/GritLM-7B-vllm`. | ✅︎ | ✅︎ |
| `Grok1ModelForCausalLM` | Grok1 | `hpcai-tech/grok-1`. | ✅︎ | ✅︎ |
| `Grok1ForCausalLM` | Grok2 | `xai-org/grok-2` | ✅︎ | ✅︎ |
| `HunYuanDenseV1ForCausalLM` | Hunyuan Dense | `tencent/Hunyuan-7B-Instruct` | ✅︎ | ✅︎ |
| `HunYuanMoEV1ForCausalLM` | Hunyuan-A13B | `tencent/Hunyuan-A13B-Instruct`, `tencent/Hunyuan-A13B-Pretrain`, `tencent/Hunyuan-A13B-Instruct-FP8`, 等 | ✅︎ | ✅︎ |
| `HCXVisionForCausalLM` | HyperCLOVAX-SEED-Vision-Instruct-3B | `naver-hyperclovax/HyperCLOVAX-SEED-Vision-Instruct-3B` | | |
| `InternLMForCausalLM` | InternLM | `internlm/internlm-7b`, `internlm/internlm-chat-7b`, 等 | ✅︎ | ✅︎ |
| `InternLM2ForCausalLM` | InternLM2 | `internlm/internlm2-7b`, `internlm/internlm2-chat-7b`, 等 | ✅︎ | ✅︎ |
| `InternLM3ForCausalLM` | InternLM3 | `internlm/internlm3-8b-instruct`, 等 | ✅︎ | ✅︎ |
| `IQuestCoderForCausalLM` | IQuestCoderV1 | `IQuestLab/IQuest-Coder-V1-40B-Instruct`, 等 | | |
| `IQuestLoopCoderForCausalLM` | IQuestLoopCoderV1 | `IQuestLab/IQuest-Coder-V1-40B-Loop-Instruct`, 等 | | |
| `JAISLMHeadModel` | Jais | `inceptionai/jais-13b`, `inceptionai/jais-13b-chat`, `inceptionai/jais-30b-v3`, `inceptionai/jais-30b-chat-v3`, 等 | | ✅︎ |
| `Jais2ForCausalLM` | Jais2 | `inceptionai/Jais-2-8B-Chat`, `inceptionai/Jais-2-70B-Chat`, 等 | | ✅︎ |
| `JambaForCausalLM` | Jamba | `ai21labs/AI21-Jamba-1.5-Large`, `ai21labs/AI21-Jamba-1.5-Mini`, `ai21labs/Jamba-v0.1`, 等 | ✅︎ | ✅︎ |
| `KimiLinearForCausalLM` | Kimi-Linear-48B-A3B-Base, Kimi-Linear-48B-A3B-Instruct | `moonshotai/Kimi-Linear-48B-A3B-Base`, `moonshotai/Kimi-Linear-48B-A3B-Instruct` | | ✅︎ |
| `Lfm2ForCausalLM`  | LFM2  | `LiquidAI/LFM2-1.2B`, `LiquidAI/LFM2-700M`, `LiquidAI/LFM2-350M`, 等 | ✅︎ | ✅︎ |
| `Lfm2MoeForCausalLM`  | LFM2MoE  | `LiquidAI/LFM2-8B-A1B-preview`, 等 | ✅︎ | ✅︎ |
| `LlamaForCausalLM` | Llama 3.1, Llama 3, Llama 2, LLaMA, Yi | `meta-llama/Meta-Llama-3.1-405B-Instruct`, `meta-llama/Meta-Llama-3.1-70B`, `meta-llama/Meta-Llama-3-70B-Instruct`, `meta-llama/Llama-2-70b-hf`, `01-ai/Yi-34B`, 等 | ✅︎ | ✅︎ |
| `MambaForCausalLM` | Mamba | `state-spaces/mamba-130m-hf`, `state-spaces/mamba-790m-hf`, `state-spaces/mamba-2.8b-hf`, 等 | | ✅︎ |
| `Mamba2ForCausalLM` | Mamba2 | `mistralai/Mamba-Codestral-7B-v0.1`, 等 | | ✅︎ |
| `MiMoForCausalLM` | MiMo | `XiaomiMiMo/MiMo-7B-RL`, 等 | ✅︎ | ✅︎ |

| `MiMoV2FlashForCausalLM` | MiMoV2Flash | `XiaomiMiMo/MiMo-V2-Flash`, 等 | ︎| ✅︎ |
| `MiniCPMForCausalLM` | MiniCPM | `openbmb/MiniCPM-2B-sft-bf16`, `openbmb/MiniCPM-2B-dpo-bf16`, `openbmb/MiniCPM-S-1B-sft`, 等 | ✅︎ | ✅︎ |
| `MiniCPM3ForCausalLM` | MiniCPM3 | `openbmb/MiniCPM3-4B`, 等 | ✅︎ | ✅︎ |
| `MiniMaxM2ForCausalLM` | MiniMax-M2, MiniMax-M2.1 |`MiniMaxAI/MiniMax-M2`, 等 | ✅︎ | ✅︎ |
| `MistralForCausalLM` | Ministral-3, Mistral, Mistral-Instruct | `mistralai/Ministral-3-3B-Instruct-2512`, `mistralai/Mistral-7B-v0.1`, `mistralai/Mistral-7B-Instruct-v0.1`, 等 | ✅︎ | ✅︎ |
| `MistralLarge3ForCausalLM` | Mistral-Large-3-675B-Base-2512, Mistral-Large-3-675B-Instruct-2512 | `mistralai/Mistral-Large-3-675B-Base-2512`, `mistralai/Mistral-Large-3-675B-Instruct-2512`, 等 | ✅︎ | ✅︎ |
| `MixtralForCausalLM` | Mixtral-8x7B, Mixtral-8x7B-Instruct | `mistralai/Mixtral-8x7B-v0.1`, `mistralai/Mixtral-8x7B-Instruct-v0.1`, `mistral-community/Mixtral-8x22B-v0.1`, 等 | ✅︎ | ✅︎ |
| `MPTForCausalLM` | MPT, MPT-Instruct, MPT-Chat, MPT-StoryWriter | `mosaicml/mpt-7b`, `mosaicml/mpt-7b-storywriter`, `mosaicml/mpt-30b`, 等 | | ✅︎ |
| `NemotronForCausalLM` | Nemotron-3, Nemotron-4, Minitron | `nvidia/Minitron-8B-Base`, `mgoin/Nemotron-4-340B-Base-hf-FP8`, 等 | ✅︎ | ✅︎ |
| `NemotronHForCausalLM` | Nemotron-H | `nvidia/Nemotron-H-8B-Base-8K`, `nvidia/Nemotron-H-47B-Base-8K`, `nvidia/Nemotron-H-56B-Base-8K`, 等 | ✅︎ | ✅︎ |
| `OLMoForCausalLM` | OLMo | `allenai/OLMo-1B-hf`, `allenai/OLMo-7B-hf`, 等 | ✅︎ | ✅︎ |
| `OLMo2ForCausalLM` | OLMo2 | `allenai/OLMo-2-0425-1B`, 等 | ✅︎ | ✅︎ |
| `OLMo3ForCausalLM` | OLMo3 | `allenai/Olmo-3-7B-Instruct`, `allenai/Olmo-3-32B-Think`, 等 | ✅︎ | ✅︎ |
| `OLMoEForCausalLM` | OLMoE | `allenai/OLMoE-1B-7B-0924`, `allenai/OLMoE-1B-7B-0924-Instruct`, 等 | | ✅︎ |
| `OPTForCausalLM` | OPT, OPT-IML | `facebook/opt-66b`, `facebook/opt-iml-max-30b`, 等 | ✅︎ | ✅︎ |
| `OrionForCausalLM` | Orion | `OrionStarAI/Orion-14B-Base`, `OrionStarAI/Orion-14B-Chat`, 等 | | ✅︎ |
| `OuroForCausalLM` | ouro | `ByteDance/Ouro-1.4B`, `ByteDance/Ouro-2.6B`, 等 | ✅︎ | |
| `PanguEmbeddedForCausalLM` |openPangu-Embedded-7B | `FreedomIntelligence/openPangu-Embedded-7B-V1.1` | ✅︎ | ✅︎ |
| `PanguProMoEV2ForCausalLM` |openpangu-pro-moe-v2 | | ✅︎ | ✅︎ |
| `PanguUltraMoEForCausalLM` |openpangu-ultra-moe-718b-model | `FreedomIntelligence/openPangu-Ultra-MoE-718B-V1.1` | ✅︎ | ✅︎ |
| `PhiForCausalLM` | Phi | `microsoft/phi-1_5`, `microsoft/phi-2`, 等 | ✅︎ | ✅︎ |
| `Phi3ForCausalLM` | Phi-4, Phi-3 | `microsoft/Phi-4-mini-instruct`, `microsoft/Phi-4`, `microsoft/Phi-3-mini-4k-instruct`, `microsoft/Phi-3-mini-128k-instruct`, `microsoft/Phi-3-medium-128k-instruct`, 等 | ✅︎ | ✅︎ |
| `PhiMoEForCausalLM` | Phi-3.5-MoE | `microsoft/Phi-3.5-MoE-instruct`, 等 | ✅︎ | ✅︎ |
| `PersimmonForCausalLM` | Persimmon | `adept/persimmon-8b-base`, `adept/persimmon-8b-chat`, 等 | | ✅︎ |
| `Plamo2ForCausalLM` | PLaMo2 | `pfnet/plamo-2-1b`, `pfnet/plamo-2-8b`, 等 | ✅ | ✅︎ |
| `Plamo3ForCausalLM` | PLaMo3 | `pfnet/plamo-3-nict-2b-base`, `pfnet/plamo-3-nict-8b-base`, 等 | ✅ | ✅︎ |
| `QWenLMHeadModel` | Qwen | `Qwen/Qwen-7B`, `Qwen/Qwen-7B-Chat`, 等 | ✅︎ | ✅︎ |
| `Qwen2ForCausalLM` | QwQ, Qwen2 | `Qwen/QwQ-32B-Preview`, `Qwen/Qwen2-7B-Instruct`, `Qwen/Qwen2-7B`, 等 | ✅︎ | ✅︎ |
| `Qwen2MoeForCausalLM` | Qwen2MoE | `Qwen/Qwen1.5-MoE-A2.7B`, `Qwen/Qwen1.5-MoE-A2.7B-Chat`, 等 | ✅︎ | ✅︎ |
| `Qwen3ForCausalLM` | Qwen3 | `Qwen/Qwen3-8B`, 等 | ✅︎ | ✅︎ |
| `Qwen3MoeForCausalLM` | Qwen3MoE | `Qwen/Qwen3-30B-A3B`, 等 | ✅︎ | ✅︎ |
| `Qwen3NextForCausalLM` | Qwen3NextMoE | `Qwen/Qwen3-Next-80B-A3B-Instruct`, 等 | ✅︎ | ✅︎ |
| `SeedOssForCausalLM` | SeedOss | `ByteDance-Seed/Seed-OSS-36B-Instruct`, 等 | ✅︎ | ✅︎ |
| `SolarForCausalLM` | Solar Pro | `upstage/solar-pro-preview-instruct`, 等 | ✅︎ | ✅︎ |
| `StableLmForCausalLM` | StableLM | `stabilityai/stablelm-3b-4e1t`, `stabilityai/stablelm-base-alpha-7b-v2`, 等 | | |
| `Starcoder2ForCausalLM` | Starcoder2 | `bigcode/starcoder2-3b`, `bigcode/starcoder2-7b`, `bigcode/starcoder2-15b`, 等 | | ✅︎ |
| `Step1ForCausalLM` | Step-Audio | `stepfun-ai/Step-Audio-EditX`, 等 | ✅︎ | ✅︎ |
| `TeleChat2ForCausalLM` | TeleChat2 | `Tele-AI/TeleChat2-3B`, `Tele-AI/TeleChat2-7B`, `Tele-AI/TeleChat2-35B`, 等 | ✅︎ | ✅︎ |
| `TeleFLMForCausalLM` | TeleFLM | `CofeAI/FLM-2-52B-Instruct-2407`, `CofeAI/Tele-FLM`, 等 | ✅︎ | ✅︎ |
| `XverseForCausalLM` | XVERSE | `xverse/XVERSE-7B-Chat`, `xverse/XVERSE-13B-Chat`, `xverse/XVERSE-65B-Chat`, 等 | ✅︎ | ✅︎ |
| `MiniMaxM1ForCausalLM` | MiniMax-Text | `MiniMaxAI/MiniMax-M1-40k`, `MiniMaxAI/MiniMax-M1-80k`, 等 | | |
| `MiniMaxText01ForCausalLM` | MiniMax-Text | `MiniMaxAI/MiniMax-Text-01`, 等 | | |
| `Zamba2ForCausalLM` | Zamba2 | `Zyphra/Zamba2-7B-instruct`, `Zyphra/Zamba2-2.7B-instruct`, `Zyphra/Zamba2-1.2B-instruct`, 等 | | |
| `LongcatFlashForCausalLM` | LongCat-Flash | `meituan-longcat/LongCat-Flash-Chat`, `meituan-longcat/LongCat-Flash-Chat-FP8` | ✅︎ | ✅︎ |

!!! note
    Grok2 需要安装 `tiktoken` 的 `tokenizer.tok.json`。您可以选择性地使用 `moe_router_renormalize` 来覆盖 MoE 路由器重新归一化。

某些模型仅通过 [Transformers 建模后端](#transformers) 支持。下表的目的是确认我们以这种方式正式支持的模型。日志将显示正在使用 Transformers 建模后端，并且您不会看到这是回退行为的警告。这意味着，如果您对下面列出的任何模型有问题，请 [创建问题](https://github.com/vllm-project/vllm/issues/new/choose)，我们将尽力修复！

| 架构 | 模型 | 示例 HF 模型 | [LoRA](../features/lora.md) | [PP](../serving/parallelism_scaling.md) |
|--------------|--------|-------------------|----------------------|---------------------------|
| `SmolLM3ForCausalLM` | SmolLM3 | `HuggingFaceTB/SmolLM3-3B` | ✅︎ | ✅︎ |

!!! note
    目前，vLLM 的 ROCm 版本仅支持上下文长度最多为 4096 的 Mistral 和 Mixtral。

### 池化模型

有关如何使用池化模型的更多信息，请参见 [此页面](./pooling_models.md)。

!!! important
    由于某些模型架构同时支持生成和池化任务，
    您应明确指定 `--runner pooling` 以确保模型在池化模式下而不是生成模式下使用。

#### 嵌入

这些模型主要支持 [`LLM.embed`](./pooling_models.md#llmembed) API。

| 架构 | 模型 | 示例 HF 模型 | [LoRA](../features/lora.md) | [PP](../serving/parallelism_scaling.md) |
|--------------|--------|-------------------|----------------------|---------------------------|
| `BertModel`<sup>C</sup> | 基于 BERT | `BAAI/bge-base-en-v1.5`, `Snowflake/snowflake-arctic-embed-xs`, 等 | | |
| `BertSpladeSparseEmbeddingModel` | SPLADE | `naver/splade-v3` | | |
| `Gemma2Model`<sup>C</sup> | 基于 Gemma 2 | `BAAI/bge-multilingual-gemma2`, 等 | ✅︎ | ✅︎ |
| `Gemma3TextModel`<sup>C</sup> | 基于 Gemma 3 | `google/embeddinggemma-300m`, 等 | ✅︎ | ✅︎ |
| `GritLM` | GritLM | `parasail-ai/GritLM-7B-vllm`. | ✅︎ | ✅︎ |
| `GteModel`<sup>C</sup> | Arctic-Embed-2.0-M | `Snowflake/snowflake-arctic-embed-m-v2.0`. |  |  |
| `GteNewModel`<sup>C</sup> | mGTE-TRM (见注释) | `Alibaba-NLP/gte-multilingual-base`, 等 |  |  |
| `ModernBertModel`<sup>C</sup> | 基于 ModernBERT | `Alibaba-NLP/gte-modernbert-base`, 等 |  |  |
| `NomicBertModel`<sup>C</sup> | Nomic BERT | `nomic-ai/nomic-embed-text-v1`, `nomic-ai/nomic-embed-text-v2-moe`, `Snowflake/snowflake-arctic-embed-m-long`, 等 |  |  |
| `LlamaBidirectionalModel`<sup>C</sup> | 基于 Llama 的双向注意力 | `nvidia/llama-nemotron-embed-1b-v2`, 等 | ✅︎ | ✅︎ |
| `LlamaModel`<sup>C</sup>, `LlamaForCausalLM`<sup>C</sup>, `MistralModel`<sup>C</sup>, 等 | 基于 Llama | `intfloat/e5-mistral-7b-instruct`, 等 | ✅︎ | ✅︎ |
| `Qwen2Model`<sup>C</sup>, `Qwen2ForCausalLM`<sup>C</sup> | 基于 Qwen2 | `ssmits/Qwen2-7B-Instruct-embed-base` (见注释), `Alibaba-NLP/gte-Qwen2-7B-instruct` (见注释), 等 | ✅︎ | ✅︎ |
| `Qwen3Model`<sup>C</sup>, `Qwen3ForCausalLM`<sup>C</sup> | 基于 Qwen3 | `Qwen/Qwen3-Embedding-0.6B`, 等 | ✅︎ | ✅︎ |
| `RobertaModel`, `RobertaForMaskedLM` | 基于 RoBERTa | `sentence-transformers/all-roberta-large-v1`, 等 | | |
| `*Model`<sup>C</sup>, `*ForCausalLM`<sup>C</sup>, 等 | 生成模型 | N/A | \* | \* |

<sup>C</sup> 通过 `--convert embed` 自动转换为嵌入模型。([详情](./pooling_models.md#model-conversion))  
\* 功能支持与原始模型相同。

!!! note
    `ssmits/Qwen2-7B-Instruct-embed-base` 的 Sentence Transformers 配置定义不当。
    您需要通过传递 `--pooler-config '{"pooling_type": "MEAN"}'` 来手动设置平均池化。

!!! note
    对于 `Alibaba-NLP/gte-Qwen2-*`，您需要启用 `--trust-remote-code` 以加载正确的分词器。
    参见 [HF Transformers 上的相关问题](https://github.com/huggingface/transformers/issues/34882)。

!!! note
    `jinaai/jina-embeddings-v3` 通过 LoRA 支持多个任务，而 vllm 暂时只支持通过合并 LoRA 权重进行文本匹配任务。

!!! note
    第二代 GTE 模型 (mGTE-TRM) 命名为 `NewModel`。`NewModel` 这个名称过于通用，您应该设置 `--hf-overrides '{"architectures": ["GteNewModel"]}'` 来指定使用 `GteNewModel` 架构。

如果您的模型不在上述列表中，我们将尝试使用
[as_embedding_model][vllm.model_executor.models.adapters.as_embedding_model] 自动转换模型。默认情况下，从对应于最后一个 token 的归一化隐藏状态中提取整个提示的嵌入。

#### 分类

这些模型主要支持 [`LLM.classify`](./pooling_models.md#llmclassify) API。

| 架构 | 模型 | 示例 HF 模型 | [LoRA](../features/lora.md) | [PP](../serving/parallelism_scaling.md) |
|--------------|--------|-------------------|----------------------|---------------------------|
| `JambaForSequenceClassification` | Jamba | `ai21labs/Jamba-tiny-reward-dev`, 等 | ✅︎ | ✅︎ |
| `GPT2ForSequenceClassification` | GPT2 | `nie3e/sentiment-polish-gpt2-small` | | |
| `*Model`<sup>C</sup>, `*ForCausalLM`<sup>C</sup>, 等 | 生成模型 | N/A | \* | \* |

<sup>C</sup> 通过 `--convert classify` 自动转换为分类模型。([详情](./pooling_models.md#model-conversion))  
\* 功能支持与原始模型相同。

如果您的模型不在上述列表中，我们将尝试使用
[as_seq_cls_model][vllm.model_executor.models.adapters.as_seq_cls_model] 自动转换模型。默认情况下，从对应于最后一个 token 的 softmax 隐藏状态中提取类别概率。

#### 交叉编码器 / 重排序器

交叉编码器和重排序器模型是分类模型的一个子集，接受两个提示作为输入。
这些模型主要支持 [`LLM.score`](./pooling_models.md#llmscore) API。

| 架构 | 模型 | 示例 HF 模型 | 评分模板 (见注释) | [LoRA](../features/lora.md) | [PP](../serving/parallelism_scaling.md) |
|--------------|--------|-------------------|---------------------------|-----------------------------|-----------------------------------------|
| `BertForSequenceClassification` | 基于 BERT | `cross-encoder/ms-marco-MiniLM-L-6-v2`, 等 | N/A | | |
| `GemmaForSequenceClassification` | 基于 Gemma | `BAAI/bge-reranker-v2-gemma`(见注释), 等 | [bge-reranker-v2-gemma.jinja](../../examples/pooling/score/template/bge-reranker-v2-gemma.jinja) | ✅︎ | ✅︎ |
| `GteNewForSequenceClassification` | mGTE-TRM (见注释) | `Alibaba-NLP/gte-multilingual-reranker-base`, 等 | N/A | | |
| `LlamaBidirectionalForSequenceClassification`<sup>C</sup> | 基于 Llama 的双向注意力 | `nvidia/llama-nemotron-rerank-1b-v2`, 等 | [nemotron-rerank.jinja](../../examples/pooling/score/template/nemotron-rerank.jinja) | ✅︎ | ✅︎ |
| `Qwen2ForSequenceClassification`<sup>C</sup> | 基于 Qwen2 | `mixedbread-ai/mxbai-rerank-base-v2`(见注释), 等 | [mxbai_rerank_v2.jinja](../../examples/pooling/score/template/mxbai_rerank_v2.jinja) | ✅︎ | ✅︎ |
| `Qwen3ForSequenceClassification`<sup>C</sup> | 基于 Qwen3 | `tomaarsen/Qwen3-Reranker-0.6B-seq-cls`, `Qwen/Qwen3-Reranker-0.6B`(见注释), 等 | [qwen3_reranker.jinja](../../examples/pooling/score/template/qwen3_reranker.jinja) | ✅︎ | ✅︎ |
| `RobertaForSequenceClassification` | 基于 RoBERTa | `cross-encoder/quora-roberta-base`, 等 | N/A | | |
| `XLMRobertaForSequenceClassification` | 基于 XLM-RoBERTa | `BAAI/bge-reranker-v2-m3`, 等 | N/A | | |
| `*Model`<sup>C</sup>, `*ForCausalLM`<sup>C</sup>, 等 | 生成模型 | N/A | N/A | \* | \* |

<sup>C</sup> 通过 `--convert classify` 自动转换为分类模型。([详情](./pooling_models.md#model-conversion))  
\* 功能支持与原始模型相同。

!!! note
    某些模型需要特定的提示格式才能正常工作。

    您可以在 [examples/pooling/score/template/](../../examples/pooling/score/template) 中找到示例 HF 模型对应的评分模板

    示例 : [examples/pooling/score/using_template_offline.py](../../examples/pooling/score/using_template_offline.py) [examples/pooling/score/using_template_online.py](../../examples/pooling/score/using_template_online.py)

!!! note
    使用以下命令加载官方原始 `BAAI/bge-reranker-v2-gemma`。

    ```bash
    vllm serve BAAI/bge-reranker-v2-gemma --hf_overrides '{"architectures": ["GemmaForSequenceClassification"],"classifier_from_token": ["Yes"],"method": "no_post_processing"}'
    ```

!!! note
    第二代 GTE 模型 (mGTE-TRM) 命名为 `NewForSequenceClassification`。`NewForSequenceClassification` 这个名称过于通用，您应该设置 `--hf-overrides '{"architectures": ["GteNewForSequenceClassification"]}'` 来指定使用 `GteNewForSequenceClassification` 架构。

!!! note
    使用以下命令加载官方原始 `mxbai-rerank-v2`。

    ```bash
    vllm serve mixedbread-ai/mxbai-rerank-base-v2 --hf_overrides '{"architectures": ["Qwen2ForSequenceClassification"],"classifier_from_token": ["0", "1"], "method": "from_2_way_softmax"}'
    ```

!!! note
    通过使用以下命令加载官方原始的 `Qwen3 Reranker`。更多信息可以在以下位置找到：[examples/pooling/score/qwen3_reranker_offline.py](../../examples/pooling/score/qwen3_reranker_offline.py) [examples/pooling/score/qwen3_reranker_online.py](../../examples/pooling/score/qwen3_reranker_online.py)。

    ```bash
    vllm serve Qwen/Qwen3-Reranker-0.6B --hf_overrides '{"architectures": ["Qwen3ForSequenceClassification"],"classifier_from_token": ["no", "yes"],"is_original_qwen3_reranker": true}'
    ```

#### 奖励建模

这些模型主要支持 [`LLM.reward`](./pooling_models.md#llmreward) API。

| 架构 | 模型 | 示例 HF 模型 | [LoRA](../features/lora.md) | [PP](../serving/parallelism_scaling.md) |
|--------------|--------|-------------------|----------------------|---------------------------|
| `InternLM2ForRewardModel` | 基于 InternLM2 | `internlm/internlm2-1_8b-reward`, `internlm/internlm2-7b-reward` 等 | ✅︎ | ✅︎ |
| `LlamaForCausalLM` | 基于 Llama | `peiyi9979/math-shepherd-mistral-7b-prm` 等 | ✅︎ | ✅︎ |
| `Qwen2ForRewardModel` | 基于 Qwen2 | `Qwen/Qwen2.5-Math-RM-72B` 等 | ✅︎ | ✅︎ |
| `Qwen2ForProcessRewardModel` | 基于 Qwen2 | `Qwen/Qwen2.5-Math-PRM-7B` 等 | ✅︎ | ✅︎ |

!!! important
    对于过程监督奖励模型，如 `peiyi9979/math-shepherd-mistral-7b-prm`，应该显式设置 pooling 配置，
    例如：`--pooler-config '{"pooling_type": "STEP", "step_tag_id": 123, "returned_token_ids": [456, 789]}'`。

#### 令牌分类

这些模型主要支持 [`LLM.encode`](./pooling_models.md#llmencode) API。

| 架构 | 模型 | 示例 HF 模型 | [LoRA](../features/lora.md) | [PP](../serving/parallelism_scaling.md) |
|--------------|--------|-------------------|-----------------------------|-----------------------------------------|
| `BertForTokenClassification` | 基于 bert | `boltuix/NeuroBERT-NER` (参见注释) 等 |  |  |
| `ModernBertForTokenClassification` | 基于 ModernBERT | `disham993/electrical-ner-ModernBERT-base` |  |  |

!!! note
    命名实体识别 (NER) 用法，请参考 [examples/pooling/token_classify/ner_offline.py](../../examples/pooling/token_classify/ner_offline.py), [examples/pooling/token_classify/ner_online.py](../../examples/pooling/token_classify/ner_online.py)。

## 多模态语言模型列表

根据模型的不同，支持以下模态：

- **T**ext (文本)
- **I**mage (图像)
- **V**ideo (视频)
- **A**udio (音频)

支持由 `+` 连接的任意模态组合。

- 例如：`T + I` 表示模型支持纯文本、纯图像和图文混合输入。

另一方面，由 `/` 分隔的模态是互斥的。

- 例如：`T / I` 表示模型支持纯文本和纯图像输入，但不支持图文混合输入。

请参阅[此页面](../features/multimodal_inputs.md)了解如何向模型传递多模态输入。

!!! tip
    对于仅混合模式的模型，如 Llama-4、Step3 和 Mistral-3，可以通过将所有支持的多模态模态设置为 0（例如，`--limit-mm-per-prompt '{"image":0}`）来启用纯文本模式，这样它们的多模态模块将不会被加载，从而为 KV 缓存释放更多 GPU 内存。

!!! note
    vLLM 目前支持为大多数多模态模型的语言骨干添加 LoRA 适配器。此外，vLLM 现在实验性地支持为某些多模态模型的 tower 和 connector 模块添加 LoRA。请参阅[此页面](../features/lora.md)。

### 生成模型

请参阅[此页面](generative_models.md)了解如何使用生成模型的更多信息。

#### 文本生成

这些模型主要接受 [`LLM.generate`](./generative_models.md#llmgenerate) API。Chat/Instruct 模型还支持 [`LLM.chat`](./generative_models.md#llmchat) API。

| 架构 | 模型 | 输入 | 示例 HF 模型 | [LoRA](../features/lora.md) | [PP](../serving/parallelism_scaling.md) |
|--------------|--------|--------|-------------------|----------------------|---------------------------|
| `AriaForConditionalGeneration` | Aria | T + I<sup>+</sup> | `rhymes-ai/Aria` | | |
| `AudioFlamingo3ForConditionalGeneration` | AudioFlamingo3 | T + A<sup>+</sup> | `nvidia/audio-flamingo-3-hf`, `nvidia/music-flamingo-hf` | ✅︎ | ✅︎ |
| `AyaVisionForConditionalGeneration` | Aya Vision | T + I<sup>+</sup> | `CohereLabs/aya-vision-8b`, `CohereLabs/aya-vision-32b`, 等 | ✅︎ | ✅︎ |
| `BagelForConditionalGeneration` | BAGEL | T + I<sup>+</sup> | `ByteDance-Seed/BAGEL-7B-MoT` | ✅︎ | ✅︎ |
| `BeeForConditionalGeneration` | Bee-8B | T + I<sup>E+</sup> | `Open-Bee/Bee-8B-RL`, `Open-Bee/Bee-8B-SFT` | | ✅︎ |
| `Blip2ForConditionalGeneration` | BLIP-2 | T + I<sup>E</sup> | `Salesforce/blip2-opt-2.7b`, `Salesforce/blip2-opt-6.7b`, 等 | ✅︎ | ✅︎ |
| `ChameleonForConditionalGeneration` | Chameleon | T + I | `facebook/chameleon-7b`, 等 | | ✅︎ |
| `Cohere2VisionForConditionalGeneration` | Command A Vision | T + I<sup>+</sup> | `CohereLabs/command-a-vision-07-2025`, 等 | | ✅︎ |
| `DeepseekVLV2ForCausalLM`<sup>^</sup> | DeepSeek-VL2 | T + I<sup>+</sup> | `deepseek-ai/deepseek-vl2-tiny`, `deepseek-ai/deepseek-vl2-small`, `deepseek-ai/deepseek-vl2`, 等 | | ✅︎ |
| `DeepseekOCRForCausalLM` | DeepSeek-OCR | T + I<sup>+</sup> | `deepseek-ai/DeepSeek-OCR`, 等 | ✅︎ | ✅︎ |
| `Eagle2_5_VLForConditionalGeneration` | Eagle2.5-VL | T + I<sup>E+</sup> | `nvidia/Eagle2.5-8B`, 等 | ✅︎ | ✅︎ |
| `Ernie4_5_VLMoeForConditionalGeneration` | Ernie4.5-VL | T + I<sup>+</sup>/ V<sup>+</sup> | `baidu/ERNIE-4.5-VL-28B-A3B-PT`, `baidu/ERNIE-4.5-VL-424B-A47B-PT` | | ✅︎ |
| `FuyuForCausalLM` | Fuyu | T + I | `adept/fuyu-8b`, 等 | | ✅︎ |
| `Gemma3ForConditionalGeneration` | Gemma 3 | T + I<sup>E+</sup> | `google/gemma-3-4b-it`, `google/gemma-3-27b-it`, 等 | ✅︎ | ✅︎ |
| `Gemma3nForConditionalGeneration` | Gemma 3n | T + I + A | `google/gemma-3n-E2B-it`, `google/gemma-3n-E4B-it`, 等 | | |
| `GLM4VForCausalLM`<sup>^</sup> | GLM-4V | T + I | `zai-org/glm-4v-9b`, `zai-org/cogagent-9b-20241220`, 等 | ✅︎ | ✅︎ |
| `Glm4vForConditionalGeneration` | GLM-4.1V-Thinking | T + I<sup>E+</sup> + V<sup>E+</sup> | `zai-org/GLM-4.1V-9B-Thinking`, 等 | ✅︎ | ✅︎ |
| `Glm4vMoeForConditionalGeneration` | GLM-4.5V | T + I<sup>E+</sup> + V<sup>E+</sup> | `zai-org/GLM-4.5V`, 等 | ✅︎ | ✅︎ |
| `GlmOcrForConditionalGeneration` | GLM-OCR | T + I<sup>E+</sup>  | `zai-org/GLM-OCR`, 等 | ✅︎ | ✅︎ |
| `GraniteSpeechForConditionalGeneration` | Granite Speech | T + A | `ibm-granite/granite-speech-3.3-8b` | ✅︎ | ✅︎ |
| `H2OVLChatModel` | H2OVL | T + I<sup>E+</sup> | `h2oai/h2ovl-mississippi-800m`, `h2oai/h2ovl-mississippi-2b`, 等 | | ✅︎ |
| `HunYuanVLForConditionalGeneration` | HunyuanOCR | T + I<sup>E+</sup> | `tencent/HunyuanOCR`, 等 | ✅︎ | ✅︎ |
| `Idefics3ForConditionalGeneration` | Idefics3 | T + I | `HuggingFaceM4/Idefics3-8B-Llama3`, 等 | ✅︎ | |
| `IsaacForConditionalGeneration` | Isaac | T + I<sup>+</sup> | `PerceptronAI/Isaac-0.1` | ✅︎ | ✅︎ |
| `InternS1ForConditionalGeneration` | Intern-S1 | T + I<sup>E+</sup> + V<sup>E+</sup> | `internlm/Intern-S1`, `internlm/Intern-S1-mini`, 等 | ✅︎ | ✅︎ |
| `InternVLChatModel` | InternVL 3.5, InternVL 3.0, InternVideo 2.5, InternVL 2.5, Mono-InternVL, InternVL 2.0 | T + I<sup>E+</sup> + (V<sup>E+</sup>) | `OpenGVLab/InternVL3_5-14B`, `OpenGVLab/InternVL3-9B`, `OpenGVLab/InternVideo2_5_Chat_8B`, `OpenGVLab/InternVL2_5-4B`, `OpenGVLab/Mono-InternVL-2B`, `OpenGVLab/InternVL2-4B`, 等 | ✅︎ | ✅︎ |
| `InternVLForConditionalGeneration` | InternVL 3.0 (HF 格式) | T + I<sup>E+</sup> + V<sup>E+</sup> | `OpenGVLab/InternVL3-1B-hf`, 等 | ✅︎ | ✅︎ |
| `KananaVForConditionalGeneration` | Kanana-V | T + I<sup>+</sup> | `kakaocorp/kanana-1.5-v-3b-instruct`, 等 | | ✅︎ |
| `KeyeForConditionalGeneration` | Keye-VL-8B-Preview | T + I<sup>E+</sup> + V<sup>E+</sup> | `Kwai-Keye/Keye-VL-8B-Preview` | ✅︎ | ✅︎ |
| `KeyeVL1_5ForConditionalGeneration` | Keye-VL-1_5-8B | T + I<sup>E+</sup> + V<sup>E+</sup> | `Kwai-Keye/Keye-VL-1_5-8B` | ✅︎ | ✅︎ |
| `KimiVLForConditionalGeneration` | Kimi-VL-A3B-Instruct, Kimi-VL-A3B-Thinking | T + I<sup>+</sup> | `moonshotai/Kimi-VL-A3B-Instruct`, `moonshotai/Kimi-VL-A3B-Thinking` | | ✅︎ |
| `KimiK25ForConditionalGeneration` | Kimi-K2.5 | T + I<sup>+</sup> | `moonshotai/Kimi-K2.5` | | ✅︎ |
| `LightOnOCRForConditionalGeneration`  | LightOnOCR-1B  | T + I<sup>+</sup> | `lightonai/LightOnOCR-1B`, 等 | ✅︎ | ✅︎ |
| `Lfm2VlForConditionalGeneration` | LFM2-VL | T + I<sup>+</sup> | `LiquidAI/LFM2-VL-450M`, `LiquidAI/LFM2-VL-3B`, `LiquidAI/LFM2-VL-8B-A1B`, 等 | ✅︎ | ✅︎ |
| `Llama4ForConditionalGeneration` | Llama 4 | T + I<sup>+</sup> | `meta-llama/Llama-4-Scout-17B-16E-Instruct`, `meta-llama/Llama-4-Maverick-17B-128E-Instruct-FP8`, `meta-llama/Llama-4-Maverick-17B-128E-Instruct`, 等 | ✅︎ | ✅︎ |
| `Llama_Nemotron_Nano_VL` | Llama Nemotron Nano VL | T + I<sup>E+</sup> | `nvidia/Llama-3.1-Nemotron-Nano-VL-8B-V1` | ✅︎ | ✅︎ |
| `LlavaForConditionalGeneration` | LLaVA-1.5, Pixtral (HF Transformers) | T + I<sup>E+</sup> | `llava-hf/llava-1.5-7b-hf`, `TIGER-Lab/Mantis-8B-siglip-llama3` (参见注释), `mistral-community/pixtral-12b`, 等 | ✅︎ | ✅︎ |
| `LlavaNextForConditionalGeneration` | LLaVA-NeXT | T + I<sup>E+</sup> | `llava-hf/llava-v1.6-mistral-7b-hf`, `llava-hf/llava-v1.6-vicuna-7b-hf`, 等 | | ✅︎ |
| `LlavaNextVideoForConditionalGeneration` | LLaVA-NeXT-Video | T + V | `llava-hf/LLaVA-NeXT-Video-7B-hf`, 等 | | ✅︎ |
| `LlavaOnevisionForConditionalGeneration` | LLaVA-Onevision | T + I<sup>+</sup> + V<sup>+</sup> | `llava-hf/llava-onevision-qwen2-7b-ov-hf`, `llava-hf/llava-onevision-qwen2-0.5b-ov-hf`, 等 | | ✅︎ |
| `MiDashengLMModel` | MiDashengLM | T + A<sup>+</sup> | `mispeech/midashenglm-7b` | | ✅︎ |
| `MiniCPMO` | MiniCPM-O | T + I<sup>E+</sup> + V<sup>E+</sup> + A<sup>E+</sup> | `openbmb/MiniCPM-o-2_6`, 等 | ✅︎ | ✅︎ |
| `MiniCPMV` | MiniCPM-V | T + I<sup>E+</sup> + V<sup>E+</sup> | `openbmb/MiniCPM-V-2` (参见注释), `openbmb/MiniCPM-Llama3-V-2_5`, `openbmb/MiniCPM-V-2_6`, `openbmb/MiniCPM-V-4`, `openbmb/MiniCPM-V-4_5`, 等 | ✅︎ | |
| `MiniMaxVL01ForConditionalGeneration` | MiniMax-VL | T + I<sup>E+</sup> | `MiniMaxAI/MiniMax-VL-01`, 等 | | ✅︎ |
| `Mistral3ForConditionalGeneration` | Mistral3 (HF Transformers) | T + I<sup>+</sup> | `mistralai/Mistral-Small-3.1-24B-Instruct-2503`, 等 | ✅︎ | ✅︎ |
| `MolmoForCausalLM` | Molmo | T + I<sup>+</sup> | `allenai/Molmo-7B-D-0924`, `allenai/Molmo-7B-O-0924`, 等 | ✅︎ | ✅︎ |
| `Molmo2ForConditionalGeneration` | Molmo2 | T + I<sup>+</sup> / V | `allenai/Molmo2-4B`, `allenai/Molmo2-8B`, `allenai/Molmo2-O-7B` | ✅︎ | ✅︎ |
| `NVLM_D_Model` | NVLM-D 1.0 | T + I<sup>+</sup> | `nvidia/NVLM-D-72B`, 等 | | ✅︎ |
| `OpenCUAForConditionalGeneration` | OpenCUA-7B | T + I<sup>E+</sup> | `xlangai/OpenCUA-7B` | ✅︎ | ✅︎ |
| `Ovis` | Ovis2, Ovis1.6 | T + I<sup>+</sup> | `AIDC-AI/Ovis2-1B`, `AIDC-AI/Ovis1.6-Llama3.2-3B`, 等 | | ✅︎ |
| `Ovis2_5` | Ovis2.5 | T + I<sup>+</sup> + V | `AIDC-AI/Ovis2.5-9B`, 等 | | |
| `PaddleOCRVLForConditionalGeneration` | Paddle-OCR | T + I<sup>+</sup> | `PaddlePaddle/PaddleOCR-VL`, 等 | | |
| `PaliGemmaForConditionalGeneration` | PaliGemma, PaliGemma 2 | T + I<sup>E</sup> | `google/paligemma-3b-pt-224`, `google/paligemma-3b-mix-224`, `google/paligemma2-3b-ft-docci-448`, 等 | ✅︎ | ✅︎ |
| `Phi3VForCausalLM` | Phi-3-Vision, Phi-3.5-Vision | T + I<sup>E+</sup> | `microsoft/Phi-3-vision-128k-instruct`, `microsoft/Phi-3.5-vision-instruct`, 等 | | ✅︎ |
| `Phi4MMForCausalLM` | Phi-4-multimodal | T + I<sup>+</sup> / T + A<sup>+</sup> / I<sup>+</sup> + A<sup>+</sup> | `microsoft/Phi-4-multimodal-instruct`, 等 | ✅︎ | ✅︎ |

| `PixtralForConditionalGeneration` | Ministral 3 (Mistral 格式), Mistral 3 (Mistral 格式), Mistral Large 3 (Mistral 格式), Pixtral (Mistral 格式) | T + I<sup>+</sup> | `mistralai/Ministral-3-3B-Instruct-2512`, `mistralai/Mistral-Small-3.1-24B-Instruct-2503`, `mistralai/Mistral-Large-3-675B-Instruct-2512` `mistralai/Pixtral-12B-2409` 等 | ✅︎ | ✅︎ |
| `QwenVLForConditionalGeneration`<sup>^</sup> | Qwen-VL | T + I<sup>E+</sup> | `Qwen/Qwen-VL`, `Qwen/Qwen-VL-Chat`, 等 | ✅︎ | ✅︎ |
| `Qwen2AudioForConditionalGeneration` | Qwen2-Audio | T + A<sup>+</sup> | `Qwen/Qwen2-Audio-7B-Instruct` | | ✅︎ |
| `Qwen2VLForConditionalGeneration` | QVQ, Qwen2-VL | T + I<sup>E+</sup> + V<sup>E+</sup> | `Qwen/QVQ-72B-Preview`, `Qwen/Qwen2-VL-7B-Instruct`, `Qwen/Qwen2-VL-72B-Instruct`, 等 | ✅︎ | ✅︎ |
| `Qwen2_5_VLForConditionalGeneration` | Qwen2.5-VL | T + I<sup>E+</sup> + V<sup>E+</sup> | `Qwen/Qwen2.5-VL-3B-Instruct`, `Qwen/Qwen2.5-VL-72B-Instruct`, 等 | ✅︎ | ✅︎ |
| `Qwen2_5OmniThinkerForConditionalGeneration` | Qwen2.5-Omni | T + I<sup>E+</sup> + V<sup>E+</sup> + A<sup>+</sup> | `Qwen/Qwen2.5-Omni-3B`, `Qwen/Qwen2.5-Omni-7B` | ✅︎ | ✅︎ |
| `Qwen3VLForConditionalGeneration` | Qwen3-VL | T + I<sup>E+</sup> + V<sup>E+</sup> | `Qwen/Qwen3-VL-4B-Instruct`, 等 | ✅︎ | ✅︎ |
| `Qwen3VLMoeForConditionalGeneration` | Qwen3-VL-MOE | T + I<sup>E+</sup> + V<sup>E+</sup> | `Qwen/Qwen3-VL-30B-A3B-Instruct`, 等 | ✅︎ | ✅︎ |
| `Qwen3OmniMoeThinkerForConditionalGeneration` | Qwen3-Omni | T + I<sup>E+</sup> + V<sup>E+</sup> + A<sup>+</sup> | `Qwen/Qwen3-Omni-30B-A3B-Instruct`, `Qwen/Qwen3-Omni-30B-A3B-Thinking` | ✅︎ | ✅︎ |
| `Qwen3ASRForConditionalGeneration` | Qwen3-ASR | T + A<sup>+</sup> | `Qwen/Qwen3-ASR-1.7B` | ✅︎ | ✅︎ |
| `RForConditionalGeneration` | R-VL-4B | T + I<sup>E+</sup> | `YannQi/R-4B` | | ✅︎ |
| `SkyworkR1VChatModel` | Skywork-R1V-38B | T + I | `Skywork/Skywork-R1V-38B` | | ✅︎ |
| `SmolVLMForConditionalGeneration` | SmolVLM2 | T + I | `SmolVLM2-2.2B-Instruct` | ✅︎ | |
| `Step3VLForConditionalGeneration` | Step3-VL | T + I<sup>+</sup> | `stepfun-ai/step3` | | ✅︎ |
| `StepVLForConditionalGeneration` | Step3-VL-10B | T + I<sup>+</sup> | `stepfun-ai/Step3-VL-10B` | | ✅︎ |
| `TarsierForConditionalGeneration` | Tarsier | T + I<sup>E+</sup> | `omni-search/Tarsier-7b`, `omni-search/Tarsier-34b` | | ✅︎ |
| `Tarsier2ForConditionalGeneration`<sup>^</sup> | Tarsier2 | T + I<sup>E+</sup> + V<sup>E+</sup> | `omni-research/Tarsier2-Recap-7b`, `omni-research/Tarsier2-7b-0115` | | ✅︎ |
| `UltravoxModel` | Ultravox | T + A<sup>E+</sup> | `fixie-ai/ultravox-v0_5-llama-3_2-1b` | ✅︎ | ✅︎ |

某些模型仅通过 [Transformers 建模后端](#transformers) 支持。下表的目的是确认我们以这种方式正式支持的模型。日志会显示正在使用 Transformers 建模后端，并且您不会看到任何关于这是回退行为的警告。这意味着，如果您对下面列出的任何模型遇到问题，请 [创建一个议题](https://github.com/vllm-project/vllm/issues/new/choose)，我们会尽力解决！

| 架构 | 模型 | 输入 | 示例 HF 模型 | [LoRA](../features/lora.md) | [PP](../serving/parallelism_scaling.md) |
|--------------|--------|--------|-------------------|-----------------------------|-----------------------------------------|
| `Emu3ForConditionalGeneration` | Emu3 | T + I | `BAAI/Emu3-Chat-hf` | ✅︎ | ✅︎ |

<sup>^</sup> 您需要通过 `--hf-overrides` 设置架构名称以匹配 vLLM 中的名称。
&nbsp;&nbsp;&nbsp;&nbsp;• 例如，要使用 DeepSeek-VL2 系列模型：
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`--hf-overrides '{"architectures": ["DeepseekVLV2ForCausalLM"]}'`
<sup>E</sup> 可以为此模态输入预计算的嵌入。
<sup>+</sup> 每个文本提示可以为此模态输入多个项目。

!!! note
    `Gemma3nForConditionalGeneration` 仅在 V1 上支持，因为它依赖于共享 KV 缓存，并且依赖于 `timm>=1.0.17` 来使用其
    MobileNet-v5 视觉骨干。

    性能尚未完全优化，主要原因是：

    - 音频和视觉 MM 编码器都使用 `transformers.AutoModel` 实现。
    - 没有 PLE 缓存或内存交换支持，如 [Google's blog](https://developers.googleblog.com/en/introducing-gemma-3n/) 中所述。这些功能可能对 vLLM 来说过于模型特定，特别是交换功能可能更适合受限环境。

!!! note
    对于 `InternVLChatModel`，目前只有 InternVL2.5 与 Qwen2.5 文本骨干（`OpenGVLab/InternVL2.5-1B` 等）、InternVL3 和 InternVL3.5 支持视频输入。

!!! note
    要使用 `TIGER-Lab/Mantis-8B-siglip-llama3`，您必须在运行 vLLM 时传递 `--hf_overrides '{"architectures": ["MantisForConditionalGeneration"]}'`。

!!! note
    官方的 `openbmb/MiniCPM-V-2` 还不能工作，所以我们目前需要使用一个分支（`HwwwH/MiniCPM-V-2`）。
    更多详情，请参见：<https://github.com/vllm-project/vllm/pull/4087#issuecomment-2250397630>

#### 转录

专门用于自动语音识别训练的 Speech2Text 模型。

| 架构 | 模型 | 示例 HF 模型 | [LoRA](../features/lora.md) | [PP](../serving/parallelism_scaling.md) |
|--------------|--------|-------------------|----------------------|---------------------------|
| `Gemma3nForConditionalGeneration` | Gemma3n | `google/gemma-3n-E2B-it`, `google/gemma-3n-E4B-it`, 等 | | |
| `GlmAsrForConditionalGeneration` | GLM-ASR | `zai-org/GLM-ASR-Nano-2512` | ✅︎ | ✅︎ |
| `GraniteSpeechForConditionalGeneration` | Granite Speech | `ibm-granite/granite-speech-3.3-2b`, `ibm-granite/granite-speech-3.3-8b`, 等 | ✅︎ | ✅︎ |
| `Qwen3ASRForConditionalGeneration` | Qwen3-ASR | `Qwen/Qwen3-ASR-1.7B`, 等 | | ✅︎ |
| `VoxtralForConditionalGeneration` | Voxtral (Mistral 格式) | `mistralai/Voxtral-Mini-3B-2507`, `mistralai/Voxtral-Small-24B-2507`, 等 | ✅︎ | ✅︎ |
| `WhisperForConditionalGeneration` | Whisper | `openai/whisper-small`, `openai/whisper-large-v3-turbo`, 等 | | |

!!! note
    `VoxtralForConditionalGeneration` 需要安装 `mistral-common[audio]`。

### 池化模型

有关如何使用池化模型的更多信息，请参见 [此页面](./pooling_models.md)。

#### 嵌入

这些模型主要支持 [`LLM.embed`](./pooling_models.md#llmembed) API。

!!! note
    为了获得最佳结果，您应该使用专门训练为池化模型的模型。

下表列出了在 vLLM 中测试过的模型。

| 架构 | 模型 | 输入 | 示例 HF 模型 | [LoRA](../features/lora.md) | [PP](../serving/parallelism_scaling.md) |
|--------------|--------|--------|-------------------|----------------------|---------------------------|
| `CLIPModel` | CLIP | T / I | `openai/clip-vit-base-patch32`, `openai/clip-vit-large-patch14`, 等 | | |
| `LlavaNextForConditionalGeneration`<sup>C</sup> | 基于 LLaVA-NeXT | T / I | `royokong/e5-v` | | ✅︎ |
| `Phi3VForCausalLM`<sup>C</sup> | 基于 Phi-3-Vision | T + I | `TIGER-Lab/VLM2Vec-Full` | | ✅︎ |
| `Qwen3VLForConditionalGeneration`<sup>C</sup> | Qwen3-VL | T + I + V | `Qwen/Qwen3-VL-Embedding-2B`, 等 | ✅︎ | ✅︎ |
| `SiglipModel` | SigLIP, SigLIP2 | T / I | `google/siglip-base-patch16-224`, `google/siglip2-base-patch16-224` | | |
| `*ForConditionalGeneration`<sup>C</sup>, `*ForCausalLM`<sup>C</sup>, 等 | 生成模型 | \* | N/A | \* | \* |

<sup>C</sup> 通过 `--convert embed` 自动转换为嵌入模型。（[详情](./pooling_models.md#model-conversion)）
\* 功能支持与原始模型相同。

---

#### 交叉编码器 / 重排序器

交叉编码器和重排序器模型是一类接受两个提示作为输入的分类模型的子集。
这些模型主要支持 [`LLM.score`](./pooling_models.md#llmscore) API。

| 架构 | 模型 | 输入 | 示例 HF 模型 | [LoRA](../features/lora.md) | [PP](../serving/parallelism_scaling.md) |
|--------------|--------|--------|-------------------|----------------------|---------------------------|
| `JinaVLForSequenceClassification` | 基于 JinaVL | T + I<sup>E+</sup> | `jinaai/jina-reranker-m0` 等 | ✅︎ | ✅︎ |
| `Qwen3VLForSequenceClassification` | Qwen3-VL-Reranker | T + I<sup>E+</sup> + V<sup>E+</sup> | `Qwen/Qwen3-VL-Reranker-2B`（见注释）等 | ✅︎ | ✅︎ |

<sup>C</sup> 通过 `--convert classify` 自动转换为分类模型。（[详情](./pooling_models.md#model-conversion)）  
\* 功能支持与原始模型相同。

!!! note
    与 Qwen3-Reranker 类似，您需要使用以下 `--hf_overrides` 来加载官方原始的 `Qwen3-VL-Reranker`。

    ```bash
    vllm serve Qwen/Qwen3-VL-Reranker-2B --hf_overrides '{"architectures": ["Qwen3VLForSequenceClassification"],"classifier_from_token": ["no", "yes"],"is_original_qwen3_reranker": true}'
    ```

## 模型支持政策

在 vLLM 中，我们致力于促进第三方模型在我们生态系统中的集成和支持。我们的方法旨在平衡对稳健性的需求和广泛支持各种模型的实际限制。以下是我们的第三方模型支持管理方式：

1. **社区驱动支持**：我们鼓励社区贡献来添加新模型。当用户请求支持新模型时，我们欢迎来自社区的拉取请求（PR）。这些贡献主要根据它们生成的输出的合理性进行评估，而不是与现有实现（如 transformers）的严格一致性。**征召贡献**：来自模型供应商的直接 PR 非常受欢迎！

2. **尽力而为的一致性**：虽然我们力求在 vLLM 中实现的模型与其他框架（如 transformers）之间保持一定程度的一致性，但完全对齐并不总是可行的。加速技术和低精度计算的使用可能会引入差异。我们的承诺是确保实现的模型功能正常并产生合理的结果。

    !!! tip
        在比较 Hugging Face Transformers 的 `model.generate` 输出和 vLLM 的 `llm.generate` 输出时，请注意前者读取模型的生成配置文件（即 [generation_config.json](https://github.com/huggingface/transformers/blob/19dabe96362803fb0a9ae7073d03533966598b17/src/transformers/generation/utils.py#L1945)）并应用生成的默认参数，而后者仅使用传递给函数的参数。在比较输出时确保所有采样参数相同。

3. **问题解决和模型更新**：我们鼓励用户报告他们在第三方模型中遇到的任何错误或问题。建议的修复应通过 PR 提交，并清楚说明问题和建议解决方案背后的理由。如果一个模型的修复影响了另一个模型，我们依靠社区来突出并解决这些跨模型依赖关系。注意：对于错误修复 PR，礼貌地通知原始作者以寻求他们的反馈是良好的做法。

4. **监控和更新**：对特定模型感兴趣的用户应监控这些模型的提交历史（例如，通过跟踪 main/vllm/model_executor/models 目录中的更改）。这种主动方法帮助用户了解可能影响他们使用的模型的更新和更改。

5. **选择性关注**：我们的资源主要集中在具有重要用户兴趣和影响的模型上。使用较少的模型可能获得较少的关注，我们依靠社区在它们的维护和改进中发挥更积极的作用。

通过这种方法，vLLM 培养了一个协作环境，核心开发团队和更广泛的社区都为在我们生态系统中支持的第三方模型的稳健性和多样性做出贡献。

请注意，作为推理引擎，vLLM 不会引入新模型。因此，所有由 vLLM 支持的模型在这一方面都是第三方模型。

我们有以下模型测试级别：

1. **严格一致性**：我们在贪婪解码下比较模型的输出与 HuggingFace Transformers 库中模型的输出。这是最严格的测试。请参阅 [模型测试](https://github.com/vllm-project/vllm/blob/main/tests/models) 了解通过此测试的模型。
2. **输出合理性**：我们检查模型的输出是否合理和连贯，通过测量输出的困惑度并检查任何明显错误。这是较不严格的测试。
3. **运行时功能**：我们检查模型是否可以加载和运行而不出错。这是最不严格的测试。请参阅 [功能测试](../../tests) 和 [示例](../../examples) 了解通过此测试的模型。
4. **社区反馈**：我们依靠社区提供模型反馈。如果模型损坏或未按预期工作，我们鼓励用户提出问题报告或打开拉取请求进行修复。其余模型属于此类别。