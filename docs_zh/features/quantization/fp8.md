# FP8 W8A8

vLLM 支持在 Nvidia H100 和 AMD MI300x 等 GPU 上使用硬件加速对权重和激活进行 FP8（8 位浮点）量化。
目前，只有 Hopper 和 Ada Lovelace GPU 正式支持 W8A8。
Ampere GPU 支持 W8A16（仅权重 FP8），利用 Marlin 内核。
使用 FP8 对模型进行量化可以将模型内存需求减少 2 倍，并将吞吐量提高最多 1.6 倍，同时对精度的影响最小。

请访问 HF 集合，获取[适用于 vLLM 的流行 LLM 的量化 FP8 检查点](https://huggingface.co/collections/neuralmagic/fp8-llms-for-vllm-666742ed2b78b7ac8df13127)。

硬件中通常支持的 FP8 类型有两种不同的表示形式，每种形式在不同的场景中都有用：

- **E4M3**：由 1 个符号位、4 个指数位和 3 个尾数位组成。它可以存储最大为 +/-448 和 `nan` 的值。
- **E5M2**：由 1 个符号位、5 个指数位和 2 个尾数位组成。它可以存储最大为 +/-57344、+/- `inf` 和 `nan` 的值。增加动态范围的代价是存储值的精度降低。

!!! note
    FP8 计算支持计算能力 > 8.9（Ada Lovelace、Hopper）的 NVIDIA GPU。
    FP8 模型可以在计算能力 > 8.0（Ampere）的 GPU 上作为仅权重的 W8A16 运行，利用 FP8 Marlin。

## 安装

要使用 vLLM 生成高性能的 FP8 量化模型，您需要安装 [llm-compressor](https://github.com/vllm-project/llm-compressor/) 库：

```bash
pip install llmcompressor
```

## 量化过程

量化过程包括三个主要步骤：

1. 加载模型
2. 应用量化
3. 在 vLLM 中评估精度

### 1. 加载模型

使用标准的 `transformers` AutoModel 类加载您的模型和分词器：

```python
from transformers import AutoTokenizer, AutoModelForCausalLM

MODEL_ID = "meta-llama/Meta-Llama-3-8B-Instruct"
model = AutoModelForCausalLM.from_pretrained(
    MODEL_ID,
    device_map="auto",
    dtype="auto",
)
tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)
```

### 2. 应用量化

对于 FP8 量化，我们可以使用简单的 RTN 量化来恢复精度。我们建议使用 `FP8_DYNAMIC` 方案针对所有 `Linear` 层，该方案使用：

- 权重上的静态、每通道量化
- 激活上的动态、每令牌量化

由于简单的 RTN 不需要数据进行权重量化，并且激活是动态量化的，因此我们不需要任何校准数据来进行此量化流程。

??? code

    ```python
    from llmcompressor import oneshot
    from llmcompressor.modifiers.quantization import QuantizationModifier

    # 配置简单的 PTQ 量化
    recipe = QuantizationModifier(
        targets="Linear",
        scheme="FP8_DYNAMIC",
        ignore=["lm_head"],
    )

    # 应用量化算法。
    oneshot(model=model, recipe=recipe)

    # 保存模型：Meta-Llama-3-8B-Instruct-FP8-Dynamic
    SAVE_DIR = MODEL_ID.split("/")[1] + "-FP8-Dynamic"
    model.save_pretrained(SAVE_DIR)
    tokenizer.save_pretrained(SAVE_DIR)
    ```

### 3. 评估精度

安装 `vllm` 和 `lm-evaluation-harness` 进行评估：

```bash
pip install vllm "lm-eval[api]>=0.4.9.2"
```

在 `vllm` 中加载并运行模型：

```python
from vllm import LLM

llm = LLM("./Meta-Llama-3-8B-Instruct-FP8-Dynamic")
result = llm.generate("Hello my name is")
print(result[0].outputs[0].text)
```

使用 `lm_eval` 评估精度（例如在 `gsm8k` 的 250 个样本上）：

!!! note
    量化模型可能对 `bos` 标记的存在很敏感。`lm_eval` 默认不添加 `bos` 标记，因此请确保在运行评估时包含 `add_bos_token=True` 参数。

```bash
MODEL=$PWD/Meta-Llama-3-8B-Instruct-FP8-Dynamic
lm_eval \
  --model vllm \
  --model_args pretrained=$MODEL,add_bos_token=True \
  --tasks gsm8k  --num_fewshot 5 --batch_size auto --limit 250
```

以下是结果分数的示例：

```text
|Tasks|Version|     Filter     |n-shot|  Metric   |   |Value|   |Stderr|
|-----|------:|----------------|-----:|-----------|---|----:|---|-----:|
|gsm8k|      3|flexible-extract|     5|exact_match|↑  |0.768|±  |0.0268|
|     |       |strict-match    |     5|exact_match|↑  |0.768|±  |0.0268|
```

## 故障排除和支持

如果您遇到任何问题或有功能请求，请在 [vllm-project/llm-compressor](https://github.com/vllm-project/llm-compressor/issues) GitHub 存储库中提出问题。

## 在线动态量化

可以在不需要任何校准数据的情况下，使用 vLLM 将原始精度 BF16/FP16 模型动态量化为 FP8。您可以通过在命令行中指定 `--quantization="fp8"` 或在 LLM 构造函数中设置 `quantization="fp8"` 来启用此功能。

在此模式下，所有线性模块（除了最终的 `lm_head`）的权重都量化为 FP8_E4M3 精度，并使用每张量比例。在每次前向传递期间计算激活的最小值和最大值，以提供高精度的动态每张量比例。因此，在此模式下，延迟改进是有限的。

```python
from vllm import LLM

llm = LLM("facebook/opt-125m", quantization="fp8")
# INFO 06-10 17:55:42 model_runner.py:157] Loading model weights took 0.1550 GB
result = llm.generate("Hello, my name is")
print(result[0].outputs[0].text)
```

!!! warning
    目前，我们在将模型量化为 8 位之前以原始精度加载模型，因此您需要足够的内存来加载整个模型。