# TorchAO

TorchAO 是 PyTorch 的架构优化库，为推理和训练提供了高性能的数据类型、优化技术和内核，并且可与 torch.compile、FSDP 等原生 PyTorch 功能组合使用。部分基准测试数据可[在此处](https://github.com/pytorch/ao/tree/main/torchao/quantization#benchmarks)查看。

我们推荐安装最新的 torchao nightly 版本：

```bash
# 安装最新的 TorchAO nightly 版本
# 选择与您的系统匹配的 CUDA 版本（cu126、cu128 等）
pip install \
    --pre torchao>=10.0.0 \
    --index-url https://download.pytorch.org/whl/nightly/cu126
```

## 量化 HuggingFace 模型

您可以使用 torchao 量化自己的 huggingface 模型，例如 [transformers](https://huggingface.co/docs/transformers/main/en/quantization/torchao) 和 [diffusers](https://huggingface.co/docs/diffusers/en/quantization/torchao)，并通过以下示例代码将检查点保存到 huggingface hub，如[此示例](https://huggingface.co/jerryzh168/llama3-8b-int8wo)：

??? code

    ```Python
    import torch
    from transformers import TorchAoConfig, AutoModelForCausalLM, AutoTokenizer
    from torchao.quantization import Int8WeightOnlyConfig

    model_name = "meta-llama/Meta-Llama-3-8B"
    quantization_config = TorchAoConfig(Int8WeightOnlyConfig())
    quantized_model = AutoModelForCausalLM.from_pretrained(
        model_name,
        dtype="auto",
        device_map="auto",
        quantization_config=quantization_config
    )
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    input_text = "What are we having for dinner?"
    input_ids = tokenizer(input_text, return_tensors="pt").to("cuda")

    hub_repo = # YOUR HUB REPO ID
    tokenizer.push_to_hub(hub_repo)
    quantized_model.push_to_hub(hub_repo, safe_serialization=False)
    ```

或者，您可以使用 [TorchAO Quantization space](https://huggingface.co/spaces/medmekk/TorchAO_Quantization) 通过简单的 UI 界面来量化模型。