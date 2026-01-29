# 池化模型（Pooling Models）

vLLM 同样支持池化模型，例如嵌入（embedding）、分类（classification）和奖励（reward）模型。在 vLLM 中，池化模型实现了 [VllmModelForPooling][vllm.model_executor.models.VllmModelForPooling] 接口。这些模型使用 [Pooler][vllm.model_executor.layers.pooler.Pooler] 来提取输入的最终隐藏状态，然后将其返回。

!!! note 我们目前支持池化模型主要是为了方便。这并不能保证比直接使用 Hugging Face Transformers 或 Sentence Transformers 带来任何性能提升。我们计划在 vLLM 中优化池化模型。如果您有任何建议，请在 <https://github.com/vllm-project/vllm/issues/21796> 上留言！

## 配置

### 模型运行器（Model Runner）

通过选项 `--runner pooling` 以池化模式运行模型。

!!! tip 在绝大多数情况下无需设置此选项，因为 vLLM 可以通过 `--runner auto` 自动检测合适的模型运行器。

### 模型转换（Model Conversion）

vLLM 可以通过选项 `--convert <type>` 使模型适应各种池化任务。如果已设置 `--runner pooling`（手动或自动），但模型未实现 [VllmModelForPooling][vllm.model_executor.models.VllmModelForPooling] 接口，vLLM 将尝试根据下表所示的架构名称自动转换模型。

| 架构 | `--convert` | 支持的池化任务 |
|-------------------------------------------------|-------------|---------------------------------------|
| `*ForTextEncoding`, `*EmbeddingModel`, `*Model` | `embed` | `token_embed`, `embed` |
| `*ForRewardModeling`, `*RewardModel` | `embed` | `token_embed`, `embed` |
| `*For*Classification`, `*ClassificationModel` | `classify` | `token_classify`, `classify`, `score` |

!!! tip 您可以显式设置 `--convert <type>` 来指定如何转换模型。

### 池化任务（Pooling Tasks）

根据 [Pooler.get_supported_tasks][vllm.model_executor.layers.pooler.Pooler.get_supported_tasks]，vLLM 中的每个池化模型支持以下一个或多个任务，从而启用相应的 API：

| 任务 | API |
|------------------|-------------------------------------------------------------------------------|
| `embed` | `LLM.embed(...)`, `LLM.score(...)`\*, `LLM.encode(..., pooling_task="embed")` |
| `classify` | `LLM.classify(...)`, `LLM.encode(..., pooling_task="classify")` |
| `score` | `LLM.score(...)` |
| `token_classify` | `LLM.reward(...)`, `LLM.encode(..., pooling_task="token_classify")` |
| `token_embed` | `LLM.encode(..., pooling_task="token_embed")` |
| `plugin` | `LLM.encode(..., pooling_task="plugin")` |

\* 如果模型不支持 `score` 任务，`LLM.score(...)` API 将回退到 `embed` 任务。

### 池化器配置（Pooler Configuration）

#### 预定义模型（Predefined models）

如果模型定义的 [Pooler][vllm.model_executor.layers.pooler.Pooler] 接受 `pooler_config`，您可以通过 `--pooler-config` 选项覆盖其部分属性。

#### 转换后的模型（Converted models）

如果模型已通过 `--convert` 转换（见上文），则分配给每个任务的池化器默认具有以下属性：

| 任务 | 池化类型 | 归一化 | Softmax |
|------------|--------------|---------------|---------|
| `embed` | `LAST` | ✅︎ | ❌ |
| `classify` | `LAST` | ❌ | ✅︎ |

加载 [Sentence Transformers](https://huggingface.co/sentence-transformers) 模型时，其 Sentence Transformers 配置文件（`modules.json`）优先于模型的默认值。您可以通过 `--pooler-config` 选项进一步自定义，该选项优先于模型和 Sentence Transformers 的默认值。

## 离线推理

[LLM][vllm.LLM] 类提供了多种离线推理方法。有关初始化模型时的选项列表，请参阅 [配置](../api/README.md#configuration)。

### `LLM.embed`

[embed][vllm.LLM.embed] 方法为每个提示词（prompt）输出一个嵌入向量。它主要用于嵌入模型。

```python
from vllm import LLM

llm = LLM(model="intfloat/e5-small", runner="pooling")

(output,) = llm.embed("Hello, my name is")

embeds = output.outputs.embedding
print(f"Embeddings: {embeds!r} (size={len(embeds)})")
```

代码示例可在此处找到：[examples/offline_inference/basic/embed.py](../../examples/offline_inference/basic/embed.py)

### `LLM.classify`

[classify][vllm.LLM.classify] 方法为每个提示词输出一个概率向量。它主要用于分类模型。

```python
from vllm import LLM

llm = LLM(model="jason9693/Qwen2.5-1.5B-apeach", runner="pooling")

(output,) = llm.classify("Hello, my name is")

probs = output.outputs.probs
print(f"Class Probabilities: {probs!r} (size={len(probs)})")
```

代码示例可在此处找到：[examples/offline_inference/basic/classify.py](../../examples/offline_inference/basic/classify.py)

### `LLM.score`

[score][vllm.LLM.score] 方法输出句子对之间的相似度分数。它适用于嵌入模型和交叉编码器（cross-encoder）模型。嵌入模型使用余弦相似度，而 [交叉编码器模型](https://www.sbert.net/examples/applications/cross-encoder/README.html) 在 RAG 系统中充当候选查询-文档对之间的重排序器（reranker）。

!!! note vLLM 只能执行 RAG 的模型推理组件（例如嵌入、重排序）。要在更高层次上处理 RAG，您应该使用集成框架，例如 [LangChain](https://github.com/langchain-ai/langchain)。

```python
from vllm import LLM

llm = LLM(model="BAAI/bge-reranker-v2-m3", runner="pooling")

(output,) = llm.score(
    "What is the capital of France?",
    "The capital of Brazil is Brasilia.",
)

score = output.outputs.score
print(f"Score: {score}")
```

代码示例可在此处找到：[examples/offline_inference/basic/score.py](../../examples/offline_inference/basic/score.py)

### `LLM.reward`

[reward][vllm.LLM.reward] 方法适用于 vLLM 中的所有奖励模型。

```python
from vllm import LLM

llm = LLM(model="internlm/internlm2-1_8b-reward", runner="pooling", trust_remote_code=True)

(output,) = llm.reward("Hello, my name is")

data = output.outputs.data
print(f"Data: {data!r}")
```

代码示例可在此处找到：[examples/offline_inference/basic/reward.py](../../examples/offline_inference/basic/reward.py)

### `LLM.encode`

[encode][vllm.LLM.encode] 方法适用于 vLLM 中的所有池化模型。

!!! note 使用 `LLM.encode` 时，请使用以下更具体的方法之一或直接设置任务：

- 对于嵌入，使用 `LLM.embed(...)` 或 `pooling_task="embed"`。
- 对于分类 logits，使用 `LLM.classify(...)` 或 `pooling_task="classify"`。
- 对于相似度分数，使用 `LLM.score(...)`。
- 对于奖励，使用 `LLM.reward(...)` 或 `pooling_task="token_classify"`。
- 对于 token 分类，使用 `pooling_task="token_classify"`。
- 对于多向量检索，使用 `pooling_task="token_embed"`。
- 对于 IO 处理器插件，使用 `pooling_task="plugin"`。

```python
from vllm import LLM

llm = LLM(model="intfloat/e5-small", runner="pooling")

(output,) = llm.encode("Hello, my name is", pooling_task="embed")

data = output.outputs.data
print(f"Data: {data!r}")
```

## 在线服务

我们的 [OpenAI 兼容服务器](../serving/openai_compatible_server.md) 提供了与离线 API 相对应的端点：

- [Embeddings API](../serving/openai_compatible_server.md#embeddings-api) 类似于 `LLM.embed`，接受文本和[多模态输入](../features/multimodal_inputs.md)用于嵌入模型。
- [Classification API](../serving/openai_compatible_server.md#classification-api) 类似于 `LLM.classify`，适用于序列分类模型。
- [Score API](../serving/openai_compatible_server.md#score-api) 类似于用于交叉编码器模型的 `LLM.score`。
- [Pooling API](../serving/openai_compatible_server.md#pooling-api) 类似于 `LLM.encode`，适用于所有类型的池化模型。

!!! note
使用 [Pooling API](../serving/openai_compatible_server.md#pooling-api) 时，请使用更具体的端点之一或直接设置任务：
- 对于嵌入，使用 [Embeddings API](../serving/openai_compatible_server.md#embeddings-api) 或 `"task":"embed"`。
- 对于分类 logits，使用 [Classification API](../serving/openai_compatible_server.md#classification-api) 或 `"task":"classify"`。
- 对于相似度分数，使用 [Score API](../serving/openai_compatible_server.md#score-api)。
- 对于奖励，使用 `"task":"token_classify"`。
- 对于 token 分类，使用 `"task":"token_classify"`。
- 对于多向量检索，使用 `"task":"token_embed"`。
- 对于 IO 处理器插件，使用 `"task":"plugin"`。

```python
# start a supported embeddings model server with `vllm serve`, e.g.
# vllm serve intfloat/e5-small
import requests
host = "localhost"
port = "8000"
model_name = "intfloat/e5-small"
api_url = f"http://{host}:{port}/pooling"
prompts = [
    "Hello, my name is",
    "The president of the United States is",
    "The capital of France is",
    "The future of AI is",
]
prompt = {"model": model_name, "input": prompts, "task": "embed"}
response = requests.post(api_url, json=prompt)
for output in response.json()["data"]:
    data = output["data"]
    print(f"Data: {data!r} (size={len(data)})")
```

## Matryoshka Embeddings

[Matryoshka Embeddings](https://sbert.net/examples/sentence_transformer/training/matryoshka/README.html#matryoshka-embeddings) 或 [Matryoshka Representation Learning (MRL)](https://arxiv.org/abs/2205.13147) 是一种用于训练嵌入模型的技术。它允许用户在性能和成本之间进行权衡。

!!! warning
并非所有嵌入模型都使用 Matryoshka Representation Learning 进行训练。为避免滥用 `dimensions` 参数，vLLM 会对尝试更改不支持 Matryoshka Embeddings 的模型输出维度的请求返回错误。例如，在使用 `BAAI/bge-m3` 模型时设置 `dimensions` 参数将导致以下错误。

```json
{"object":"error","message":"Model \"BAAI/bge-m3\" does not support matryoshka representation, changing output dimensions will lead to poor results.","type":"BadRequestError","param":null,"code":400}
```

### 手动启用 Matryoshka Embeddings

目前没有官方接口用于指定对 Matryoshka Embeddings 的支持。在 vLLM 中，如果 `config.json` 中的 `is_matryoshka` 为 `True`，您可以将输出维度更改为任意值。使用 `matryoshka_dimensions` 来控制允许的输出维度。

对于支持 Matryoshka Embeddings 但未被 vLLM 识别的模型，使用 `hf_overrides={"is_matryoshka": True}` 或 `hf_overrides={"matryoshka_dimensions": [<allowed output dimensions>]}`（离线）手动覆盖配置，或使用 `--hf-overrides '{"is_matryoshka": true}'` 或 `--hf-overrides '{"matryoshka_dimensions": [<allowed output dimensions>]}'`（在线）。

以下是一个启用 Matryoshka Embeddings 的模型服务示例。

```bash
vllm serve Snowflake/snowflake-arctic-embed-m-v1.5 --hf-overrides '{"matryoshka_dimensions":[256]}'
```

### 离线推理

您可以通过在 [PoolingParams][vllm.PoolingParams] 中使用 dimensions 参数来更改支持 Matryoshka Embeddings 的嵌入模型的输出维度。

```python
from vllm import LLM, PoolingParams

llm = LLM(
    model="jinaai/jina-embeddings-v3",
    runner="pooling",
    trust_remote_code=True,
)

outputs = llm.embed(
    ["Follow the white rabbit."],
    pooling_params=PoolingParams(dimensions=32),
)

print(outputs[0].outputs)
```

代码示例可在此处找到：[examples/pooling/embed/embed_matryoshka_fy_offline.py](../../examples/pooling/embed/embed_matryoshka_fy_offline.py)

### 在线推理

使用以下命令启动 vLLM 服务器。

```bash
vllm serve jinaai/jina-embeddings-v3 --trust-remote-code
```

您可以使用 dimensions 参数来更改支持 Matryoshka Embeddings 的嵌入模型的输出维度。

```bash
curl http://127.0.0.1:8000/v1/embeddings \
    -H 'accept: application/json' \
    -H 'Content-Type: application/json' \
    -d '{
        "input": "Follow the white rabbit.",
        "model": "jinaai/jina-embeddings-v3",
        "encoding_format": "float",
        "dimensions": 32
    }'
```

预期输出：

```json
{"id":"embd-5c21fc9a5c9d4384a1b021daccaf9f64","object":"list","created":1745476417,"model":"jinaai/jina-embeddings-v3","data":[{"index":0,"object":"embedding","embedding":[-0.3828125,-0.1357421875,0.03759765625,0.125,0.21875,0.09521484375,-0.003662109375,0.1591796875,-0.130859375,-0.0869140625,-0.1982421875,0.1689453125,-0.220703125,0.1728515625,-0.2275390625,-0.0712890625,-0.162109375,-0.283203125,-0.055419921875,-0.0693359375,0.031982421875,-0.04052734375,-0.2734375,0.1826171875,-0.091796875,0.220703125,0.37890625,-0.0888671875,-0.12890625,-0.021484375,-0.0091552734375,0.23046875]}],"usage":{"prompt_tokens":8,"total_tokens":8,"completion_tokens":0,"prompt_tokens_details":null}}
```

OpenAI 客户端示例可在此处找到：[examples/pooling/embed/openai_embedding_matryoshka_fy_client.py](../../examples/pooling/embed/openai_embedding_matryoshka_fy_client.py)

## 特定模型

### BAAI/bge-m3

`BAAI/bge-m3` 模型带有用于稀疏和 colbert 嵌入的额外权重，但不幸的是，在其 `config.json` 中架构被声明为 `XLMRobertaModel`，这使得 `vLLM` 将其加载为没有额外权重的普通 ROBERTA 模型。

要加载完整的模型权重，请像这样覆盖其架构：

```shell
vllm serve BAAI/bge-m3 --hf-overrides '{"architectures": ["BgeM3EmbeddingModel"]}'
```

然后您可以像这样获取稀疏嵌入：

```shell
curl -s http://localhost:8000/pooling -H "Content-Type: application/json" -d '{
    "model": "BAAI/bge-m3",
    "task": "token_classify",
    "input": ["What is BGE M3?", "Defination of BM25"]
}'
```

由于输出模式的限制，输出由每个输入的每个 token 的 token 分数列表组成。这意味着您还必须调用 `/tokenize` 才能将 token 与分数配对。

请参阅 `tests/models/language/pooling/test_bge_m3.py` 中的测试以了解如何操作。

您可以像这样获取 colbert 嵌入：

```shell
curl -s http://localhost:8000/pooling -H "Content-Type: application/json" -d '{
    "model": "BAAI/bge-m3",
    "task": "token_embed",
    "input": ["What is BGE M3?", "Defination of BM25"]
}'
```

## 已弃用功能

### Encode 任务

我们将 `encode` 任务拆分为两个更具体的 token 级任务：`token_embed` 和 `token_classify`：

- `token_embed` 与 `embed` 相同，使用归一化作为激活函数。
- `token_classify` 与 `classify` 相同，默认使用 softmax 作为激活函数。

### 从 PoolingParams 中移除 softmax

我们将在 v0.15 中从 `PoolingParams` 中移除 `softmax` 和 `activation`。请改用 `use_activation`，因为我们允许 `classify` 和 `token_classify` 使用任何激活函数。

### as_reward_model

!!! warning
我们将在 v0.15 中移除 `--convert reward`，请改用 `--convert embed`。池化模型现在默认支持所有池化，您无需任何设置即可使用。

- 提取隐藏状态建议使用 `token_embed` 任务。
- 奖励模型建议使用 `token_classify` 任务。