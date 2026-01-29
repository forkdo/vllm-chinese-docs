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

最初由加州大学伯克利分校 [Sky Computing Lab](https://sky.cs.berkeley.edu) 开发，vLLM 已发展成为由社区驱动的项目，接受了来自学术界和工业界的贡献。

如何开始使用 vLLM 取决于用户类型。如果您希望：

- 在 vLLM 上运行开源模型，我们建议从 [快速入门指南](./getting_started/quickstart.md) 开始
- 使用 vLLM 构建应用程序，我们建议从 [用户指南](./usage/README.md) 开始
- 构建 vLLM，我们建议从 [开发者指南](./contributing/README.md) 开始

有关 vLLM 开发的信息，请参阅：

- [路线图](https://roadmap.vllm.ai)
- [发布版本](https://github.com/vllm-project/vllm/releases)

vLLM 的优势体现在：

- 具备最先进的服务吞吐量
- 使用 [**PagedAttention**](https://blog.vllm.ai/2023/06/20/vllm.html) 高效管理注意力键和值内存
- 对传入请求进行连续批处理
- 使用 CUDA/HIP 图实现快速模型执行
- 量化支持：[GPTQ](https://arxiv.org/abs/2210.17323)、[AWQ](https://arxiv.org/abs/2306.00978)、INT4、INT8 和 FP8
- 优化的 CUDA 内核，包括与 FlashAttention 和 FlashInfer 的集成
- 规范化解码
- 分块预填充

vLLM 具有灵活性且易于使用，体现在：

- 与流行的 HuggingFace 模型无缝集成
- 支持多种解码算法的高吞吐量服务，包括*并行采样*、*束搜索*等
- 支持张量并行、管道并行、数据并行和专家并行，用于分布式推理
- 流式输出
- 兼容 OpenAI 的 API 服务器
- 支持 NVIDIA GPU、AMD CPU 和 GPU、Intel CPU 和 GPU、PowerPC CPU、Arm CPU 和 TPU。此外，还支持 Intel Gaudi、IBM Spyre 和华为 Ascend 等多样化的硬件插件
- 前缀缓存支持
- 多 LoRA 支持

欲了解更多信息，请参阅以下内容：

- [vLLM 宣布博客文章](https://blog.vllm.ai/2023/06/20/vllm.html)（介绍 PagedAttention）
- [vLLM 论文](https://arxiv.org/abs/2309.06180)（SOSP 2023）
- [Cade Daniel 等人撰写：连续批处理如何在 LLM 推理中实现 23 倍吞吐量提升并降低 p50 延迟](https://www.anyscale.com/blog/continuous-batching-llm-inference)
- [vLLM 线下交流活动](community/meetups.md)