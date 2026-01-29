# INT4 W4A16

vLLM 支持将权重量化为 INT4，以实现内存节省和推理加速。这种量化方法对于减小模型大小以及在每秒查询数 (QPS) 较低的工作负载中保持低延迟特别有用。

请访问 Hugging Face 上的 [适用于 vLLM 的流行 LLM 的量化 INT4 检查点集合](https://huggingface.co/collections/neuralmagic/int4-llms-for-vllm-668ec34bf3c9fa45f857df2c)。

!!! note
    INT4 计算功能支持计算能力 > 8.0 的 NVIDIA GPU（Ampere、Ada Lovelace、Hopper、Blackwell）。

## 先决条件

要在 vLLM 中使用 INT4 量化，您需要安装 [llm-compressor](https://github.com/vllm-project/llm-compressor/) 库：

```bash
pip install llmcompressor
```

此外，请安装 `vllm` 和 `lm-evaluation-harness` 以进行评估：

```bash
pip install vllm "lm-eval[api]>=0.4.9.2"
```

## 量化流程

量化流程包含四个主要步骤：

1. 加载模型
2. 准备校准数据
3. 应用量化
4. 在 vLLM 中评估准确性

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

### 2. 准备校准数据

将权重量化为 INT4 时，您需要样本数据来估计权重更新和校准比例。
最好使用与您的部署数据非常接近的校准数据。
对于通用指令调优模型，您可以使用类似 `ultrachat` 的数据集：

??? code

    ```python
    from datasets import load_dataset

    NUM_CALIBRATION_SAMPLES = 512
    MAX_SEQUENCE_LENGTH = 2048

    # 加载并预处理数据集
    ds = load_dataset("HuggingFaceH4/ultrachat_200k", split="train_sft")
    ds = ds.shuffle(seed=42).select(range(NUM_CALIBRATION_SAMPLES))

    def preprocess(example):
        return {"text": tokenizer.apply_chat_template(example["messages"], tokenize=False)}
    ds = ds.map(preprocess)

    def tokenize(sample):
        return tokenizer(sample["text"], padding=False, max_length=MAX_SEQUENCE_LENGTH, truncation=True, add_special_tokens=False)
    ds = ds.map(tokenize, remove_columns=ds.column_names)
    ```

### 3. 应用量化

现在，应用量化算法：

??? code

    ```python
    from llmcompressor import oneshot
    from llmcompressor.modifiers.quantization import GPTQModifier
    from llmcompressor.modifiers.smoothquant import SmoothQuantModifier

    # 配置量化算法
    recipe = GPTQModifier(targets="Linear", scheme="W4A16", ignore=["lm_head"])

    # 应用量化
    oneshot(
        model=model,
        dataset=ds,
        recipe=recipe,
        max_seq_length=MAX_SEQUENCE_LENGTH,
        num_calibration_samples=NUM_CALIBRATION_SAMPLES,
    )

    # 保存压缩模型：Meta-Llama-3-8B-Instruct-W4A16-G128
    SAVE_DIR = MODEL_ID.split("/")[1] + "-W4A16-G128"
    model.save_pretrained(SAVE_DIR, save_compressed=True)
    tokenizer.save_pretrained(SAVE_DIR)
    ```

此过程会创建一个 W4A16 模型，其权重被量化为 4 位整数。

### 4. 评估准确性

量化后，您可以在 vLLM 中加载并运行模型：

```python
from vllm import LLM

llm = LLM("./Meta-Llama-3-8B-Instruct-W4A16-G128")
```

要评估准确性，您可以使用 `lm_eval`：

```bash
lm_eval --model vllm \
  --model_args pretrained="./Meta-Llama-3-8B-Instruct-W4A16-G128",add_bos_token=true \
  --tasks gsm8k \
  --num_fewshot 5 \
  --limit 250 \
  --batch_size 'auto'
```

!!! note
    量化模型可能对 `bos` 标记的存在很敏感。运行评估时，请务必包含 `add_bos_token=True` 参数。

## 最佳实践

- 校准数据从 512 个样本开始，如果准确性下降，请增加样本数量
- 确保校准数据包含高度多样化的样本，以防止过度拟合特定用例
- 序列长度从 2048 开始
- 使用模型训练时使用的聊天模板或指令模板
- 如果您对模型进行了微调，请考虑使用训练数据样本来进行校准
- 调整量化算法的关键超参数：
    - `dampening_frac` 设置 GPTQ 算法的影响程度。较低的值可以提高准确性，但可能导致数值不稳定，从而导致算法失败。
    - `actorder` 设置激活顺序。压缩层权重时，量化通道的顺序很重要。设置 `actorder="weight"` 可以在不增加延迟的情况下提高准确性。

以下是一个扩展的量化配方示例，您可以根据自己的用例进行调整：

??? code

    ```python
    from compressed_tensors.quantization import (
        QuantizationArgs,
        QuantizationScheme,
        QuantizationStrategy,
        QuantizationType,
    ) 
    recipe = GPTQModifier(
        targets="Linear",
        config_groups={
            "config_group": QuantizationScheme(
                targets=["Linear"],
                weights=QuantizationArgs(
                    num_bits=4,
                    type=QuantizationType.INT,
                    strategy=QuantizationStrategy.GROUP,
                    group_size=128,
                    symmetric=True,
                    dynamic=False,
                    actorder="weight",
                ),
            ),
        },
        ignore=["lm_head"],
        update_size=NUM_CALIBRATION_SAMPLES,
        dampening_frac=0.01,
    )
    ```

## 故障排除和支持

如果您遇到任何问题或有功能请求，请在 [vllm-project/llm-compressor](https://github.com/vllm-project/llm-compressor/issues) GitHub 仓库中提出问题。`llm-compressor` 中的完整 INT4 量化示例可在[此处](https://github.com/vllm-project/llm-compressor/blob/main/examples/quantization_w4a16/llama3_example.py)找到。