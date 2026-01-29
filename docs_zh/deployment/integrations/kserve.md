# KServe

vLLM 可与 [KServe](https://github.com/kserve/kserve) 一起在 Kubernetes 上部署，以实现高度可扩展的分布式模型服务。

您可以将 vLLM 与 KServe 的 [Hugging Face 服务运行时](https://kserve.github.io/website/docs/model-serving/generative-inference/overview) 配合使用，或通过 [`LLMInferenceService`（使用 llm-d）](https://kserve.github.io/website/docs/model-serving/generative-inference/llmisvc/llmisvc-overview) 进行部署。