# NVIDIA Model Optimizer

[NVIDIA Model Optimizer](https://github.com/NVIDIA/Model-Optimizer) 是一个专为 NVIDIA GPU 推理优化模型的库。它包含对大型语言模型（LLMs）、视觉语言模型（VLMs）和扩散模型进行训练后量化（PTQ）和量化感知训练（QAT）的工具。

我们建议通过以下方式安装该库：

```bash
pip install nvidia-modelopt
```

## 支持的 ModelOpt 检查点格式

vLLM 通过 `hf_quant_config.json` 检测 ModelOpt 检查点，并支持以下 `quantization.quant_algo` 值：

- `FP8`: 每张量权重缩放（+ 可选静态激活缩放）。
- `FP8_PER_CHANNEL_PER_TOKEN`: 每通道权重缩放和动态每令牌激活量化。
- `FP8_PB_WO`（ModelOpt 可能输出 `fp8_pb_wo`）: 块缩放 FP8 权重仅量化（通常为 128×128 块）。
- `NVFP4`: ModelOpt NVFP4 检查点（使用 `quantization="modelopt_fp4"`）。

## 使用 PTQ 对 HuggingFace 模型进行量化

您可以使用 Model Optimizer 仓库中提供的示例脚本对 HuggingFace 模型进行量化。LLM PTQ 的主要脚本通常位于 `examples/llm_ptq` 目录中。

下面是一个使用 modelopt PTQ API 对模型进行量化的示例：

??? code

    ```python
    import modelopt.torch.quantization as mtq
    from transformers import AutoModelForCausalLM

    # 从 HuggingFace 加载模型
    model = AutoModelForCausalLM.from_pretrained("<path_or_model_id>")

    # 选择量化配置，例如 FP8
    config = mtq.FP8_DEFAULT_CFG

    # 定义校准的前向循环函数
    def forward_loop(model):
        for data in calib_set:
            model(data)

    # 使用原地替换量化模块进行 PTQ
    model = mtq.quantize(model, config, forward_loop)
    ```

模型量化完成后，可以使用导出 API 将其导出为量化检查点：

```python
import torch
from modelopt.torch.export import export_hf_checkpoint

with torch.inference_mode():
    export_hf_checkpoint(
        model,  # 量化后的模型。
        export_dir,  # 存储导出文件的目录。
    )
```

然后可以使用 vLLM 部署量化检查点。以下代码展示了如何使用 vLLM 部署 `nvidia/Llama-3.1-8B-Instruct-FP8`，该模型是基于 `meta-llama/Llama-3.1-8B-Instruct` 的 FP8 量化检查点：

??? code

    ```python
    from vllm import LLM, SamplingParams

    def main():
        model_id = "nvidia/Llama-3.1-8B-Instruct-FP8"

        # 确保在加载 modelopt 检查点时指定 quantization="modelopt"
        llm = LLM(model=model_id, quantization="modelopt", trust_remote_code=True)

        sampling_params = SamplingParams(temperature=0.8, top_p=0.9)

        prompts = [
            "Hello, my name is",
            "The president of the United States is",
            "The capital of France is",
            "The future of AI is",
        ]

        outputs = llm.generate(prompts, sampling_params)

        for output in outputs:
            prompt = output.prompt
            generated_text = output.outputs[0].text
            print(f"Prompt: {prompt!r}, Generated text: {generated_text!r}")

    if __name__ == "__main__":
        main()
    ```

## 运行 OpenAI 兼容服务器

要通过 OpenAI 兼容 API 提供本地 ModelOpt 检查点服务：

```bash
vllm serve <path_to_exported_checkpoint> \
  --quantization modelopt \
  --host 0.0.0.0 --port 8000
```

## 测试（本地检查点）

vLLM 的 ModelOpt 单元测试受限于本地检查点路径，默认情况下在 CI 中会被跳过。要在本地运行测试：

```bash
export VLLM_TEST_MODELOPT_FP8_PC_PT_MODEL_PATH=<path_to_fp8_pc_pt_checkpoint>
export VLLM_TEST_MODELOPT_FP8_PB_WO_MODEL_PATH=<path_to_fp8_pb_wo_checkpoint>
pytest -q tests/quantization/test_modelopt.py
```