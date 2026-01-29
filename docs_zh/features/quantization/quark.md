# AMD Quark

量化技术能够有效降低内存和带宽使用，加速计算并提高吞吐量，同时将精度损失降至最低。vLLM 可借助 [Quark](https://quark.docs.amd.com/latest/)（一款灵活且强大的量化工具包）生成高性能的量化模型，以便在 AMD GPU 上运行。Quark 专门针对大语言模型提供权重、激活和 kv-cache 量化支持，并集成了 AWQ、GPTQ、旋转量化（Rotation）和 SmoothQuant 等前沿量化算法。

## Quark 安装

在量化模型之前，您需要先安装 Quark。可通过 pip 安装最新版本的 Quark：

```bash
pip install amd-quark
```

如需了解更多安装细节，请参阅 [Quark 安装指南](https://quark.docs.amd.com/latest/install.html)。

此外，还需安装 `vllm` 和 `lm-evaluation-harness` 以进行评估：

```bash
pip install vllm "lm-eval[api]>=0.4.9.2"
```

## 量化流程

安装 Quark 后，我们将通过一个示例说明如何使用 Quark。Quark 的量化流程可分为以下 5 个步骤：

1. 加载模型  
2. 准备校准数据加载器（calibration dataloader）  
3. 设置量化配置  
4. 量化模型并导出  
5. 在 vLLM 中进行评估  

### 1. 加载模型

Quark 使用 [Transformers](https://huggingface.co/docs/transformers/en/index) 获取模型和分词器（tokenizer）。

??? code

    ```python
    from transformers import AutoTokenizer, AutoModelForCausalLM

    MODEL_ID = "meta-llama/Llama-2-70b-chat-hf"
    MAX_SEQ_LEN = 512

    model = AutoModelForCausalLM.from_pretrained(
        MODEL_ID,
        device_map="auto",
        dtype="auto",
    )
    model.eval()

    tokenizer = AutoTokenizer.from_pretrained(MODEL_ID, model_max_length=MAX_SEQ_LEN)
    tokenizer.pad_token = tokenizer.eos_token
    ```

### 2. 准备校准数据加载器

Quark 使用 [PyTorch Dataloader](https://pytorch.org/tutorials/beginner/basics/data_tutorial.html) 加载校准数据。关于如何高效使用校准数据集的更多详情，请参阅 [添加校准数据集](https://quark.docs.amd.com/latest/pytorch/calibration_datasets.html)。

??? code

    ```python
    from datasets import load_dataset
    from torch.utils.data import DataLoader

    BATCH_SIZE = 1
    NUM_CALIBRATION_DATA = 512

    # 加载数据集并获取校准数据。
    dataset = load_dataset("mit-han-lab/pile-val-backup", split="validation")
    text_data = dataset["text"][:NUM_CALIBRATION_DATA]

    tokenized_outputs = tokenizer(
        text_data,
        return_tensors="pt",
        padding=True,
        truncation=True,
        max_length=MAX_SEQ_LEN,
    )
    calib_dataloader = DataLoader(
        tokenized_outputs['input_ids'],
        batch_size=BATCH_SIZE,
        drop_last=True,
    )
    ```

### 3. 设置量化配置

我们需要设置量化配置，更多细节请查阅 [Quark 配置指南](https://quark.docs.amd.com/latest/pytorch/user_guide_config_description.html)。此处我们对权重、激活、kv-cache 使用 FP8 每张量（per-tensor）量化，并采用 AutoSmoothQuant 量化算法。

!!! note
    注意：量化算法需要一个 JSON 配置文件，该文件位于 [Quark PyTorch 示例](https://quark.docs.amd.com/latest/pytorch/pytorch_examples.html) 的 `examples/torch/language_modeling/llm_ptq/models` 目录下。例如，Llama 的 AutoSmoothQuant 配置文件为  
    `examples/torch/language_modeling/llm_ptq/models/llama/autosmoothquant_config.json`。

??? code

    ```python
    from quark.torch.quantization import (Config, QuantizationConfig,
                                        FP8E4M3PerTensorSpec,
                                        load_quant_algo_config_from_file)

    # 定义 FP8/每张量/静态规格。
    FP8_PER_TENSOR_SPEC = FP8E4M3PerTensorSpec(
        observer_method="min_max",
        is_dynamic=False,
    ).to_quantization_spec()

    # 定义全局量化配置：输入张量和权重均应用 FP8_PER_TENSOR_SPEC。
    global_quant_config = QuantizationConfig(
        input_tensors=FP8_PER_TENSOR_SPEC,
        weight=FP8_PER_TENSOR_SPEC,
    )

    # 定义 kv-cache 层的量化配置：输出张量应用 FP8_PER_TENSOR_SPEC。
    KV_CACHE_SPEC = FP8_PER_TENSOR_SPEC
    kv_cache_layer_names_for_llama = ["*k_proj", "*v_proj"]
    kv_cache_quant_config = {
        name: QuantizationConfig(
            input_tensors=global_quant_config.input_tensors,
            weight=global_quant_config.weight,
            output_tensors=KV_CACHE_SPEC,
        )
        for name in kv_cache_layer_names_for_llama
    }
    layer_quant_config = kv_cache_quant_config.copy()

    # 通过配置文件定义算法配置。
    LLAMA_AUTOSMOOTHQUANT_CONFIG_FILE = "examples/torch/language_modeling/llm_ptq/models/llama/autosmoothquant_config.json"
    algo_config = load_quant_algo_config_from_file(LLAMA_AUTOSMOOTHQUANT_CONFIG_FILE)

    EXCLUDE_LAYERS = ["lm_head"]
    quant_config = Config(
        global_quant_config=global_quant_config,
        layer_quant_config=layer_quant_config,
        kv_cache_quant_config=kv_cache_quant_config,
        exclude=EXCLUDE_LAYERS,
        algo_config=algo_config,
    )
    ```

### 4. 量化模型并导出

接下来即可应用量化。量化完成后，需先冻结（freeze）量化模型，再进行导出。注意：必须以 HuggingFace 的 `safetensors` 格式导出模型，更多导出格式详情请参阅 [HuggingFace 格式导出](https://quark.docs.amd.com/latest/pytorch/export/quark_export_hf.html)。

??? code

    ```python
    import torch
    from quark.torch import ModelQuantizer, ModelExporter
    from quark.torch.export import ExporterConfig, JsonExporterConfig

    # 应用量化。
    quantizer = ModelQuantizer(quant_config)
    quant_model = quantizer.quantize_model(model, calib_dataloader)

    # 冻结量化模型以便导出。
    freezed_model = quantizer.freeze(model)

    # 定义导出配置。
    LLAMA_KV_CACHE_GROUP = ["*k_proj", "*v_proj"]
    export_config = ExporterConfig(json_export_config=JsonExporterConfig())
    export_config.json_export_config.kv_cache_group = LLAMA_KV_CACHE_GROUP

    # 模型名称示例：Llama-2-70b-chat-hf-w-fp8-a-fp8-kvcache-fp8-pertensor-autosmoothquant
    EXPORT_DIR = MODEL_ID.split("/")[1] + "-w-fp8-a-fp8-kvcache-fp8-pertensor-autosmoothquant"
    exporter = ModelExporter(config=export_config, export_dir=EXPORT_DIR)
    with torch.no_grad():
        exporter.export_safetensors_model(
            freezed_model,
            quant_config=quant_config,
            tokenizer=tokenizer,
        )
    ```

### 5. 在 vLLM 中进行评估

现在，您可直接通过 LLM 入口点加载并运行 Quark 量化模型：

??? code

    ```python
    from vllm import LLM, SamplingParams

    # 示例提示词。
    prompts = [
        "Hello, my name is",
        "The president of the United States is",
        "The capital of France is",
        "The future of AI is",
    ]
    # 创建采样参数对象。
    sampling_params = SamplingParams(temperature=0.8, top_p=0.95)

    # 创建 LLM 实例。
    llm = LLM(
        model="Llama-2-70b-chat-hf-w-fp8-a-fp8-kvcache-fp8-pertensor-autosmoothquant",
        kv_cache_dtype="fp8",
        quantization="quark",
    )
    # 根据提示词生成文本。输出为 RequestOutput 对象列表，
    # 包含提示词、生成文本及其他信息。
    outputs = llm.generate(prompts, sampling_params)
    # 打印输出结果。
    print("\nGenerated Outputs:\n" + "-" * 60)
    for output in outputs:
        prompt = output.prompt
        generated_text = output.outputs[0].text
        print(f"Prompt:    {prompt!r}")
        print(f"Output:    {generated_text!r}")
        print("-" * 60)
    ```

或者，您也可以使用 `lm_eval` 来评估模型精度：

```bash
lm_eval --model vllm \
  --model_args pretrained=Llama-2-70b-chat-hf-w-fp8-a-fp8-kvcache-fp8-pertensor-autosmoothquant,kv_cache_dtype='fp8',quantization='quark' \
  --tasks gsm8k
```

## Quark 量化脚本

除了上述 Python API 的示例之外，Quark 还提供了一个[量化脚本](https://quark.docs.amd.com/latest/pytorch/example_quark_torch_llm_ptq.html)，可以更便捷地对大语言模型进行量化。该脚本支持使用多种不同的量化方案和优化算法对模型进行量化，并可导出量化后的模型，同时运行评估任务。使用该脚本时，上述示例可以简化为：

```bash
python3 quantize_quark.py --model_dir meta-llama/Llama-2-70b-chat-hf \
                          --output_dir /path/to/output \
                          --quant_scheme w_fp8_a_fp8 \
                          --kv_cache_dtype fp8 \
                          --quant_algo autosmoothquant \
                          --num_calib_data 512 \
                          --model_export hf_format \
                          --tasks gsm8k
```

## 使用 OCP MX（MXFP4、MXFP6）模型

vLLM 支持加载通过 AMD Quark 离线量化的 MXFP4 和 MXFP6 模型，符合 [Open Compute Project (OCP) 规范](https://www.opencompute.org/documents/ocp-microscaling-formats-mx-v1-0-spec-final-pdf)。

该方案目前仅支持激活值的动态量化。

使用示例（需先安装最新版 AMD Quark）：

```bash
vllm serve fxmarty/qwen_1.5-moe-a2.7b-mxfp4 --tensor-parallel-size 1
# 或者，对于使用 fp6 激活值和 fp4 权重的模型：
vllm serve fxmarty/qwen1.5_moe_a2.7b_chat_w_fp4_a_fp6_e2m3 --tensor-parallel-size 1
```

对于原生不支持 OCP MX 运算的设备（例如 AMD Instinct MI325、MI300 和 MI250），可以通过融合内核在运行时将权重从 FP4/FP6 反量化为半精度，从而模拟 MXFP4/MXFP6 中的矩阵乘法执行过程。这在以下场景中非常有用：例如使用 vLLM 评估 FP4/FP6 模型，或者利用相比 float16 和 bfloat16 节省约 2.5-4 倍内存的优势。

要生成使用 MXFP4 数据类型进行离线量化的模型，最简单的方法是使用 AMD Quark 的[量化脚本](https://quark.docs.amd.com/latest/pytorch/example_quark_torch_llm_ptq.html)，示例如下：

```bash
python quantize_quark.py --model_dir Qwen/Qwen1.5-MoE-A2.7B-Chat \
    --quant_scheme w_mxfp4_a_mxfp4 \
    --output_dir qwen_1.5-moe-a2.7b-mxfp4 \
    --skip_evaluation \
    --model_export hf_format \
    --group_size 32
```

当前集成支持[权重或激活值使用 FP4、FP6_E3M2、FP6_E2M3 的所有组合](https://github.com/vllm-project/vllm/blob/main/vllm/model_executor/layers/quantization/utils/ocp_mx_utils.py)。

## 使用 Quark 量化分层自动混合精度 (AMP) 模型

vLLM 还支持加载使用 AMD Quark 进行分层混合精度量化的模型。目前支持 {MXFP4, FP8} 的混合方案，其中 FP8 表示每张量 (per-tensor) 的 FP8 方案。未来计划支持更多混合精度方案，包括：

- 每层可选择非量化 Linear 和/或 MoE 层，即 {MXFP4, FP8, BF16/FP16} 的混合
- MXFP6 量化扩展，即 {MXFP4, MXFP6, FP8, BF16/FP16}

虽然可以在特定设备上使用支持的最低精度（例如 AMD Instinct MI355 使用 MXFP4，AMD Instinct MI300 使用 FP8）以最大化服务吞吐量，但这些激进方案可能会对目标任务中量化后的精度恢复产生不利影响。混合精度可以在最大化精度和吞吐量之间取得平衡。

使用 AMD Quark 生成和部署混合精度量化模型需要两个步骤，如下所示。

### 1. 使用 AMD Quark 以混合精度量化模型

首先，针对给定的 LLM 模型搜索分层混合精度配置，然后使用 AMD Quark 进行量化。我们稍后将提供包含 Quark API 的详细教程。

作为示例，我们提供了一些可直接使用的量化混合精度模型，以展示其在 vLLM 中的用法和精度优势。这些模型包括：

- amd/Llama-2-70b-chat-hf-WMXFP4FP8-AMXFP4FP8-AMP-KVFP8
- amd/Mixtral-8x7B-Instruct-v0.1-WMXFP4FP8-AMXFP4FP8-AMP-KVFP8
- amd/Qwen3-8B-WMXFP4FP8-AMXFP4FP8-AMP-KVFP8

### 2. 在 vLLM 中推理量化混合精度模型

使用 AMD Quark 以混合精度量化的模型可以原生地在 vLLM 中重新加载，例如可以使用 lm-evaluation-harness 进行如下评估：

```bash
lm_eval --model vllm \
    --model_args pretrained=amd/Llama-2-70b-chat-hf-WMXFP4FP8-AMXFP4FP8-AMP-KVFP8,tensor_parallel_size=4,dtype=auto,gpu_memory_utilization=0.8,trust_remote_code=False \
    --tasks mmlu \
    --batch_size auto
```