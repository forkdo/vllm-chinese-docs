# GPTQModel

要创建新的 4-bit 或 8-bit GPTQ 量化模型，您可以使用 ModelCloud.AI 提供的 [GPTQModel](https://github.com/ModelCloud/GPTQModel)。

量化将模型精度从 BF16/FP16（16 位）降低到 INT4（4 位）或 INT8（8 位），显著减少模型总内存占用，同时提升推理性能。

兼容的 GPTQModel 量化模型可以利用 `Marlin` 和 `Machete` vLLM 自定义内核，在 Ampere（A100+）和 Hopper（H100+）Nvidia GPU 上最大化批处理事务每秒 `tps` 和令牌延迟性能。这两个内核由 vLLM 和 NeuralMagic（现已成为 Redhat 的一部分）高度优化，可实现量化 GPTQ 模型的世界级推理性能。

GPTQModel 是全球少数支持 `Dynamic` 每模块量化的量化工具包之一，允许对大语言模型中的不同层和/或模块使用自定义量化参数进行进一步优化。`Dynamic` 量化完全集成到 vLLM 中，并得到 ModelCloud.AI 团队的支持。请参阅 [GPTQModel readme](https://github.com/ModelCloud/GPTQModel?tab=readme-ov-file#dynamic-quantization-per-module-quantizeconfig-override) 了解此功能及其他高级功能的更多详情。

## 安装

您可以通过安装 [GPTQModel](https://github.com/ModelCloud/GPTQModel) 来量化自己的模型，或从 [Huggingface 上的 5000+ 模型](https://huggingface.co/models?search=gptq) 中选择。

```bash
pip install -U gptqmodel --no-build-isolation -v
```

## 量化模型

安装 GPTQModel 后，您就可以开始量化模型了。有关更多详情，请参阅 [GPTQModel readme](https://github.com/ModelCloud/GPTQModel/?tab=readme-ov-file#quantization)。

以下是量化 `meta-llama/Llama-3.2-1B-Instruct` 的示例：

??? code

    ```python
    from datasets import load_dataset
    from gptqmodel import GPTQModel, QuantizeConfig

    model_id = "meta-llama/Llama-3.2-1B-Instruct"
    quant_path = "Llama-3.2-1B-Instruct-gptqmodel-4bit"

    calibration_dataset = load_dataset(
        "allenai/c4",
        data_files="en/c4-train.00001-of-01024.json.gz",
        split="train",
    ).select(range(1024))["text"]

    quant_config = QuantizeConfig(bits=4, group_size=128)

    model = GPTQModel.load(model_id, quant_config)

    # 增加 `batch_size` 以匹配 gpu/vram 规格，加快量化速度
    model.quantize(calibration_dataset, batch_size=2)

    model.save(quant_path)
    ```

## 使用 vLLM 运行量化模型

要在 vLLM 中运行 GPTQModel 量化模型，可以使用 [DeepSeek-R1-Distill-Qwen-7B-gptqmodel-4bit-vortex-v2](https://huggingface.co/ModelCloud/DeepSeek-R1-Distill-Qwen-7B-gptqmodel-4bit-vortex-v2) 并执行以下命令：

```bash
python examples/offline_inference/llm_engine_example.py \
    --model ModelCloud/DeepSeek-R1-Distill-Qwen-7B-gptqmodel-4bit-vortex-v2
```

## 在 vLLM 的 Python API 中使用 GPTQModel

GPTQModel 量化模型也通过 LLM 入口点直接支持：

??? code

    ```python
    from vllm import LLM, SamplingParams

    # 示例提示
    prompts = [
        "Hello, my name is",
        "The president of the United States is",
        "The capital of France is",
        "The future of AI is",
    ]

    # 创建采样参数对象
    sampling_params = SamplingParams(temperature=0.6, top_p=0.9)

    # 创建 LLM
    llm = LLM(model="ModelCloud/DeepSeek-R1-Distill-Qwen-7B-gptqmodel-4bit-vortex-v2")

    # 从提示中生成文本。输出是包含提示、生成文本和其他信息的 RequestOutput 对象列表
    outputs = llm.generate(prompts, sampling_params)

    # 打印输出
    print("-"*50)
    for output in outputs:
        prompt = output.prompt
        generated_text = output.outputs[0].text
        print(f"Prompt: {prompt!r}\nGenerated text: {generated_text!r}")
        print("-"*50)
    ```