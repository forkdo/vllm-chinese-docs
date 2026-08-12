<!-- FILE: README.md -->

```markdown
# 欢迎来到 vLLM

<figure markdown="span">
  ![](./assets/logos/vllm-logo-text-light.png){ align="center" alt="vLLM Light" class="logo-light" width="60%" }
  ![](./assets/logos/vllm-logo-text-dark.png){ align="center" alt="vLLM Dark" class="logo-dark" width="60%" }
</figure>

<p style="text-align:center">
<strong>为所有人提供简单、快速且低成本的 LLM 服务
</strong>
</p>

<p style="text-align:center">
<script async defer src="https://buttons.github.io/buttons.js"></script>
<a class="github-button" href="https://github.com/vllm-project/vllm" data-show-count="true" data-size="large" aria-label="Star">Star</a>
<a class="github-button" href="https://github.com/vllm-project/vllm/subscription" data-show-count="true" data-icon="octicon-eye" data-size="large" aria-label="Watch">Watch</a>
<a class="github-button" href="https://github.com/vllm-project/vllm/fork" data-show-count="true" data-icon="octicon-repo-forked" data-size="large" aria-label="Fork">Fork</a>
</p>

vLLM 是一个快速且易于使用的 LLM 推理和服务库。

最初由加州大学伯克利分校 [Sky Computing Lab](https://sky.cs.berkeley.edu) 开发，vLLM 已发展成为最活跃的开源 AI 项目之一，由来自 2000 多位贡献者的众多学术机构和公司共同构建和维护。

如何开始使用 vLLM 取决于用户类型。如果您希望：

- 在 vLLM 上运行开源模型，我们建议从 [快速入门指南](./getting_started/quickstart.md) 开始
- 使用 vLLM 构建应用程序，我们建议从 [用户指南](./usage/README.md) 开始
- 构建 vLLM，我们建议从 [开发者指南](./contributing/README.md) 开始

vLLM 速度快的原因包括：

- 最先进的推理吞吐量
- 通过 [**PagedAttention**](https://blog.vllm.ai/2023/06/20/vllm.html) 高效管理注意力键值内存
- 对传入请求的连续批处理、分块预填充、前缀缓存
- 通过分段和完整 CUDA/HIP 图进行快速灵活的模型执行
- 量化：FP8、MXFP8/MXFP4、NVFP4、INT8、INT4、GPTQ/AWQ、GGUF、compressed-tensors、ModelOpt、TorchAO 以及[更多](https://docs.vllm.ai/en/latest/features/quantization/index.html)
- 优化的注意力内核，包括 FlashAttention、FlashInfer、TRTLLM-GEN、FlashMLA 和 Triton
- 使用 CUTLASS、TRTLLM-GEN、CuTeDSL 针对各种精度的优化 GEMM/MoE 内核
- 投机解码，包括 n-gram、后缀、EAGLE、DFlash
- 使用 torch.compile 的自动内核生成和图级变换
- 分离的预填充、解码和编码

vLLM 灵活且易于使用的原因包括：

- 与流行的 Hugging Face 模型无缝集成
- 通过多种解码算法（包括*并行采样*、*束搜索*等）实现高吞吐量服务
- 支持张量、流水线、数据、专家和平行上下文分布式推理
- 流式输出
- 使用 xgrammar 或 guidance 生成结构化输出
- 工具调用和推理解析器
- OpenAI 兼容 API 服务器，以及 Anthropic Messages API 和 gRPC 支持
- 针对密集层和 MoE 层的高效多 LoRA 支持
- 支持 NVIDIA GPU、AMD GPU 以及 x86/ARM/PowerPC CPU。此外还有多样化的硬件插件，如 Google TPU、Intel Gaudi、IBM Spyre、华为 Ascend、Rebellion NPU、Apple Silicon、MetaX GPU 等。

vLLM 无缝支持 HuggingFace 上的 200+ 模型架构，包括：

- 仅解码器 LLM（如 Llama、Qwen、Gemma）
- 混合专家 LLM（如 Mixtral、DeepSeek-V3、Qwen-MoE、GPT-OSS）
- 混合注意力与状态空间模型（如 Mamba、Qwen3.5）
- 多模态模型（如 LLaVA、Qwen-VL、Pixtral）
- 嵌入和检索模型（如 E5-Mistral、GTE、ColBERT）
- 奖励和分类模型（如 Qwen-Math）

查找支持的完整模型列表 [这里](./models/supported_models.md)。

更多信息，请查看以下内容：
