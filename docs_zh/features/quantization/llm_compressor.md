# LLM Compressor

[LLM Compressor](https://docs.vllm.ai/projects/llm-compressor/en/latest/) 是一个用于优化模型以配合 vLLM 部署的库。
它提供了一套全面的量化算法，包括对 FP4、FP8、INT8 和 INT4 等量化技术的支持。

## 为何使用 LLM Compressor？

现代 LLM 通常包含数十亿个参数，这些参数以 16 位或 32 位浮点数的形式存储，需要大量 GPU 内存，从而限制了部署选项。
量化通过将模型权重和激活的精度降低到更小的数据类型，从而降低内存需求，同时保持推理输出质量。

LLM Compressor 提供以下优势：

- **减少内存占用**：在较小的 GPU 上运行更大的模型。
- **降低推理成本**：每个 GPU 可服务更多并发用户，直接降低生产部署中每次查询的成本。
- **更快的推理速度**：更小的数据类型意味着消耗更少的内存带宽，这通常会转化为更高的吞吐量，尤其是对于内存密集型工作负载。

LLM Compressor 处理量化、校准和格式转换的复杂性，生成可直接与 vLLM 一起使用的模型。

## 主要特性

- **多种量化算法**：支持 AWQ、GPTQ、AutoRound 和 Round-to-Nearest。
还包括对 QuIP 和 SpinQuant 风格变换以及 KV 缓存和注意力量化的支持。
- **多种量化方法**：支持 FP8、INT8、INT4、NVFP4、MXFP4 和混合精度量化
- **一键式量化**：使用最少的校准数据快速量化模型
- **vLLM 集成**：使用 compressed-tensors 格式无缝部署量化模型到 vLLM
- **Hugging Face 兼容性**：支持来自 Hugging Face Hub 的模型

## 资源

- [LLM Compressor 示例](https://github.com/vllm-project/llm-compressor/tree/main/examples)
- [GitHub 仓库](https://github.com/vllm-project/llm-compressor)