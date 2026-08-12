<!-- FILE: api/README.md -->

```markdown
# 摘要

## 配置

vLLM 配置类的 API 文档。

- [vllm.config.ModelConfig][]
- [vllm.config.CacheConfig][]
- [vllm.config.LoadConfig][]
- [vllm.config.ParallelConfig][]
- [vllm.config.SchedulerConfig][]
- [vllm.config.DeviceConfig][]
- [vllm.config.SpeculativeConfig][]
- [vllm.config.LoRAConfig][]
- [vllm.config.MultiModalConfig][]
- [vllm.config.PoolerConfig][]
- [vllm.config.StructuredOutputsConfig][]
- [vllm.config.ProfilerConfig][]
- [vllm.config.ObservabilityConfig][]
- [vllm.config.KVTransferConfig][]
- [vllm.config.CompilationConfig][]
- [vllm.config.VllmConfig][]

## 离线推理

LLM 类。

- [vllm.LLM][]

LLM API 的提示架构。

- [vllm.inputs.llm][]

## vLLM 引擎

想要添加自己的多模态模型？请按照[此处](https://docs.vllm.ai/en/latest/development/multimodal/)的说明操作。

- [vllm.multimodal.MULTIMODAL_REGISTRY][]

### 内部数据结构

- [vllm.multimodal.inputs.PlaceholderRange][]
- [vllm.multimodal.inputs.NestedTensors][]
- [vllm.multimodal.inputs.MultiModalFieldConfig][]
- [vllm.multimodal.inputs.MultiModalKwargsItem][]
- [vllm.multimodal.inputs.MultiModalKwargsItems][]

### 数据解析

- [vllm.multimodal.inputs.image][]
- [vllm.multimodal.inputs.video][]
- [vllm.multimodal.inputs.audio][]

## vLLM 调度器

以下是用于自定义调度器的 API 参考。

- [vllm.scheduler.PrefixCachingStats][]
- [vllm.scheduler.RequestsStatus][]
- [vllm.scheduler.ScheduledBatch][]
- [vllm.scheduler.Scheduler][]

## Server

vLLM API 服务器相关类。

- [vllm.entrypoints.openai.protocol.ChatCompletionRequest][]
- [vllm.entrypoints.openai.protocol.ChatCompletionResponse][]
- [vllm.entrypoints.openai.protocol.ChatCompletionStreamOptions][]
- [vllm.entrypoints.openai.protocol.ChatCompletionTokenLogprob][]
- [vllm.entrypoints.openai.protocol.ChatMessage][]
- [vllm.entrypoints.openai.protocol.Choice][]
- [vllm.entrypoints.openai.protocol.ChoiceDelta][]
- [vllm.entrypoints.openai.protocol.ChoiceDeltaFunctionCall][]
- [vllm.entrypoints.openai.protocol.ChoiceDeltaToolCall][]
- [vllm.entrypoints.openai.protocol.Completion][]
- [vllm.entrypoints.openai.protocol.CompletionChoice][]
- [vllm.entrypoints.openai.protocol.CompletionLogprobs][]
- [vllm.entrypoints.openai.protocol.CompletionResponse][]
- [vllm.entrypoints.openai.protocol.Embedding][]
- [vllm.entrypoints.openai.protocol.EmbeddingResponse][]
- [vllm.entrypoints.openai.protocol.FunctionDefinition][]
- [vllm.entrypoints.openai.protocol.FunctionName][]
- [vllm.entrypoints.openai.protocol.ImagePart][]
- [vllm.entrypoints.openai.protocol.LogProbs][]
- [vllm.entrypoints.openai.protocol.Message][]
- [vllm.entrypoints.openai.protocol.Model][]
- [vllm.entrypoints.openai.protocol.ModelCard][]
- [vllm.entrypoints.openai.protocol.ModelList][]
- [vllm.entrypoints.openai.protocol.ModelsResponse][]
- [vllm.entrypoints.openai.protocol.Tool][]
- [vllm.entrypoints.openai.protocol.ToolCall][]
- [vllm.entrypoints.openai.protocol.ToolInputText][]
- [vllm.entrypoints.openai.protocol.TranscriptionRequest][]
- [vllm.entrypoints.openai.protocol.TranscriptionResult][]
- [vllm.entrypoints.openai.protocol.TranslationRequest][]
- [vllm.entrypoints.openai.protocol.TranslationResult][]
- [vllm.entrypoints.openai.protocol.Usage][]

## SGLang 运行时

SGLang 运行时 API。

- [vllm.entrypoints.sdl.Request][]
- [vllm.entrypoints.sdl.Response][]

## V0 后端

V0 后端的 API 参考。

- [vllm.v0.core.agent_scratchpad.AgentScratchPad][]
- [vllm.v0.core.sampling_params.SamplingParams][]
- [vllm.v0.executor.abstract.Executor][]
- [vllm.v0.outputs.BaseRequestOutput][]
- [vllm.v0.outputs.CompletionOutput][]
- [vllm.v0.outputs.FinishedReason][]
- [vllm.v0.outputs.LightCompletionOutput][]
- [vllm.v0.outputs.LightRequestOutput][]
- [vllm.v0.outputs.RequestOutput][]
- [vllm.v0.outputs.TokenOutput][]

## vllm 配置

vLLM 配置模块。

- [vllm.config.Config][]

## vllm 版本

vLLM 版本信息。

- [vllm.version.__version__][]
- [vllm.version.__version_tuple__][]
- [vllm.version.version][]
- [vllm.version.version_info][]

## Dev API

vLLM Dev API 类。

- [vllm.dev_ops.checkpoint_tools.get_vllm_checkpoint_state_dict][]
- [vllm.dev_ops.checkpoint_tools.is_offload_file_name][]
- [vllm.dev_ops.generate_dummy_config][]
- [vllm.dev_ops.load_checkpoint][]
- [vllm.dev_ops.merge_and_unload][]
- [vllm.dev_ops.offload weights.convert_gpu_weights_cpu][]
- [vllm.dev_ops.offload weights.convert_gpu_weights_cpu][]
- [vllm.dev_ops.offload weights.convert_shard_files][]
- [vllm.dev_ops.offload weights.offload_gpu_weights][]
- [vllm.dev_ops.pynccl_wrapper.PyNCCLWrapper][]
- [vllm.dev_ops.pynccl_wrapper.get_nccl_version][]
- [vllm.dev_ops.pynccl_wrapper.init_process_group][]
- [vllm.dev_ops.pynccl_wrapper.nccl_all_reduce][]
- [vllm.dev_ops.pynccl_wrapper.nccl_all_reduce_async][]
- [vllm.dev_ops.pynccl_wrapper.nccl_broadcast][]
- [vllm.dev_ops.pynccl_wrapper.nccl_broadcast_async][]
- [vllm.dev_ops.pynccl_wrapper.nccl_point_to_point][]
- [vllm.dev_ops.pynccl_wrapper.nccl_point_to_point_async][]
- [vllm.dev_ops.pynccl_wrapper.nccl_reduce][]
- [vllm.dev_ops.pynccl_wrapper.nccl_reduce_async][]
- [vllm.dev_ops.pynccl_wrapper.nccl_recv][]
- [vllm.dev_ops.pynccl_wrapper.nccl_recv_async][]
- [vllm.dev_ops.pynccl_wrapper.nccl_send][]
- [vllm.dev_ops.pynccl_wrapper.nccl_send_async][]
- [vllm.dev_ops.pynccl_wrapper.nccl_wait][]
- [vllm.dev_ops.remote_expert_worker.remote_expert_worker][]
- [vllm.dev_ops.sequence.Sequence][]
- [vllm.dev_ops.television.television_wrapper.television_wrapper][]

## Executor

执行器相关类。

- [vllm.executor.gpu_executor.GPUExecutor][]
- [vllm.executor.gpu_executor.GPUExecutorWorker][]
- [vllm.executor.multiproc_worker_pool.MultiprocessingWorker][]
- [vllm.executor.multiproc_worker_pool.MultiprocessingWorkerPoolExecutor][]
- [vllm.executor.multiproc_worker_pool.MultiprocessingWorkerPoolExecutorWithMemory][]
- [vllm.executor.parallel_state.GroupStateObject][]
- [villm.executor.remote_expert_worker.RemoteExpertWorker][]

## Inputs

输入相关类。

- [vllm.inputs.Any[]]
- [vllm.inputs.ChatCompletionMessage][]
- [vllm.inputs.ChatCompletionMessageParam][]
- [vllm.inputs.ChatCompletionRequest][]
- [vllm.inputs.ChatPrompt][]
- [vllm.inputs.ConcreteChatCompletionMessageParam][]
- [vllm.inputs.ConcreteMessagePart][]
- [vllm.inputs.ConcreteTextPrompt][]
- [vllm.inputs.ConcreteTokensPrompt][]
- [vllm.inputs.ContentPart][]
- [vllm.inputs.DefinedFunction][]
- [vllm.inputs.DefinedTool][]
- [vllm.inputs.DefinedToolChoice][]
- [vllm.inputs.ImageContentPart][]
- [villm.inputs.InputMetadata][]
- [vllm.inputs.InputRouterArgs][]
- [vllm.inputs.InputType][]
- [vllm.inputs.LLMInputs][]
- [vllm.inputs.ModelRequestData][]
- [vllm.inputs.MultimodalData][]
- [vllm.inputs.MultimodalDataKwargs][]
- [vllm.inputs.MultimodalInputs][]
- [vllm.inputs.MultimodalPrompt][]
- [vllm.inputs.MultimodalPromptData][]
- [vllm.inputs.PlainTextchatCompletionMessage][]
- [vllm.inputs.TextPrompt][]
- [vllm.inputs.TokenizedPrompt][]
- [vllm.inputs.TokenizedMultimodalPrompt][]
- [vllm.inputs.ToolContentPart][]
- [vllm.inputs.ToolResponseContentPart][]
- [vllm.inputs.TranscriptionRequestInput][]
- [vllm.inputs.TranslationRequestInput][]
- [vllm.inputs.VllmPartialRequestData][]
- [vllm.inputs.VllmRequestData][]
- [vllm.inputs.decoding.PhasedDecodingStep][]
- [vllm.inputs.decoding.PhasedDecodingStepConfig][]
- [vllm.inputs.image.ImageBlock][]
- [vllm.inputs.image.ImageBlockBase][]
- [vllm.inputs.image.ImageModelInputs][]
- [vllm.inputs.image.ImageURL][]
- [vllm.inputs.multimodal.MultiModalInputs][]
- [vllm.inputs.multimodal.MultiModalInputType][]
- [vllm.inputs.multimodal.MultiModalKind][]
- [vllm.inputs.multimodal.inputs.MultiModalDataDict][]
- [vllm.inputs.multimodal.inputs.MultiModalFieldConfig][]
- [vllm.inputs.multimodal.inputs.MultiModalKwargs][]
- [vllm.inputs.multimodal.inputs.MultiModalKwargsItem][]
- [vllm.inputs.multimodal.inputs.MultiModalKwargsItems][]
- [vllm.inputs.multimodal.inputs.MultiModalPlaceholder][]
- [vllm.inputs.multimodal.inputs.NestedTensors][]
- [vllm.inputs.multimodal.inputs.OptimizedTensor][]
- [vllm.inputs.multimodal.inputs.PartiallyUnpackedOptimizedTensor][]
- [vllm.inputs.multimodal.inputs.PlaceholderRange][]
- [vllm.inputs.multimodal.registry.MULTIMODAL_REGISTRY][]
- [vllm.inputs.multimodal.registry.register_multimodal][]
- [vllm.inputs.prompt.LLMInputsManager][]
- [vllm.inputs.prompt.LLMInputsManagerForEngine][]
- [vllm.inputs.prompt.LLMInputsManagerForModel][]
- [vllm.inputs.prompt.ParseLLMInputsError][]
- [vllm.inputs.prompt.ParseLLMInputsResult][]
- [vllm.inputs.prompt.ParseLLMInputsResultForModel][]
- [vllm.inputs.prompt.ParseRequestDataResult][]
- [vllm.inputs.prompt.ParseRequestInputResult][]
- [vllm.inputs.prompt.ValidateLLMInputsResult][]
- [vllm.inputs.prompt.ValidateRequestDataResult][]
- [vllm.inputs.prompt.ValidateRequestInputResult][]
- [vllm.inputs.video.VideoBlock][]
- [vllm.inputs.video.VideoURL][]

## Logging

日志记录相关类。

- [vllm.logging.formatters.PlainFormatter][]
- [vllm.logging.formatters.PreciseFormatter][]
- [vllm.logging.utils.LogContext][]

## Prompts

提示相关类。

- [vllm.prompts.AICompilerPromptParser][]
- [vllm.prompts.DefaultPromptParser][]
- [vllm.prompts.PromptParser][]
- [vllm.prompts.PromptParserOutput][]
- [vllm.prompts.PromptType][]
- [vllm.prompts.ShareGPTPromptParser][]

## Sampling

采样相关类。

- [vllm.sampling_params.SamplingParams][]

## Scheduler

调度器相关类。

- [vllm.scheduler.Scheduler][]
- [vllm.scheduler.SchedulerConfig][]
- [vllm.scheduler.ScheduledBatch][]
- [vllm.scheduler.Step][]
- [vllm.scheduler.SequenceGroup][]
- [villm.scheduler.SequenceGroupState][]
- [vllm.scheduler.SequenceState][]

## Speculative Decode

投机解码相关类。

- [vllm.spec_decode.spec_decode_metrics.SpecDecodeMetrics][]

## Versions

版本相关类。

- [vllm.version.__version__][]
- [vllm.version.__version_tuple__][]
- [vllm.version.version][]
- [vllm.version.version_info][]

## V1

V1 后端相关类。

- [vllm.v1.core.agent_scratchpad.AgentScratchPad][]
- [vllm.v1.core.kv_cache_utils.KVCacheConfig][]
- [vllm.v1.core.kv_cache_utils.KVCacheSpec][]
- [vllm.v1.core.kv_cache_utils.KVCacheType][]
- [vllm.v1.core.policy.Policy][]
- [vllm.v1.core.sampling_params.SamplingParams][]
- [vllm.v1.core.seq_seq.OutputSeqAlignment][]
- [vllm.v1.core.sg_kernel_attention.SGKernelAttention][]
- [vllm.v1.executor.abstract.Executor][]
- [vllm.v1.executor.gpu_executor.GPUExecutor][]
- [vllm.v1.executor.gpu_executor.GPUExecutorWorker][]
- [vllm.v1.outputs.BaseRequestOutput][]
- [vllm.v1.outputs.CompletionOutput][]
- [vllm.v1.outputs.FinishedReason][]
- [vllm.v1.outputs.LightCompletionOutput][]
- [vllm.v1.outputs.LightRequestOutput][]
- [vllm.v1.outputs.RequestOutput][]
- [vllm.v1.outputs.TokenOutput][]
