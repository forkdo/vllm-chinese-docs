# 融合 MoE 内核特性

本文档旨在概述各种 MoE 内核（包括模块化与非模块化），以便更轻松地根据特定场景选择适当的内核组合。内容涵盖模块化内核所使用的 all2all 后端相关信息。

## 融合 MoE 模块化 All2All 后端

为实现 `FusedMoE` 层中的专家并行（Expert Parallelism, EP），系统采用了多种 all2all 通信后端。不同的 `FusedMoEPrepareAndFinalize` 子类为每种 all2all 后端提供了统一接口。

下表描述了各后端的关键特性，包括激活格式、支持的量化方案以及异步支持能力。

输出激活格式（标准或批处理）对应于 `FusedMoEPrepareAndFinalize` 子类 prepare 步骤的输出，而 finalize 步骤要求输入采用相同格式。所有后端的 `prepare` 方法均期望接收标准格式的激活张量，所有 `finalize` 方法也返回标准格式的激活张量。关于格式的更多详细信息，请参阅 [融合 MoE 模块化内核](./fused_moe_modular_kernel.md) 文档。

量化类型与格式列出了每个 `FusedMoEPrepareAndFinalize` 类所支持的量化方案。量化操作可在分发（dispatch）之前或之后执行，具体取决于 all2all 后端所支持的格式。例如，deepep_high_throughput 仅支持块级 fp8 量化格式；若使用其他格式，则会在更高精度下进行分发，之后再执行量化。每个后端的 prepare 步骤输出均为量化后的类型。finalize 步骤通常要求输入类型与原始激活类型一致。例如，若原始输入为 bfloat16，且量化方案为 fp8 配合每张量缩放因子（per-tensor scales），则 `prepare` 将返回 fp8/每张量缩放因子的激活张量，而 `finalize` 则接收 bfloat16 类型的激活张量。有关 MoE 流程各步骤中激活张量类型与格式的详细说明，请参见 [融合 MoE 模块化内核](./fused_moe_modular_kernel.md) 中的示意图。若未指定量化类型，则内核默认在 float16 和/或 bfloat16 精度下运行。

异步后端支持 DBO（双批次重叠）以及共享专家重叠（即在 combine 步骤期间计算共享专家）。

某些模型（如 Llama）在 topk==1 时，要求将 topk 权重应用于输入激活张量而非输出激活张量。对于模块化内核，此功能由 `FusedMoEPrepareAndFinalize` 子类提供支持；而对于非模块化内核，则由专家函数自行处理该标志。

除非另有说明，否则后端通过 `--all2all-backend` 命令行参数（或 `ParallelConfig` 中的 `all2all_backend` 参数）进行控制。除 `flashinfer` 外，所有后端仅支持 EP+DP 或 EP+TP 模式；`Flashinfer` 可在 EP 或 DP（无需 EP）模式下运行。

<style>
td {
  padding: 0.5rem !important;
  white-space: nowrap;
}

th {
  padding: 0.5rem !important;
  min-width: 0 !important;
}
</style>

| 后端 | 输出激活格式 | 量化类型 | 量化格式 | 异步支持 | 权重应用于输入 | 子类 |
|---------|--------------------|--------------|---------------|-------|-----------------------|-----------|
| naive | 标准 | 全部<sup>1</sup> | G,A,T | 否 | <sup>6</sup> | [layer.py][vllm.model_executor.layers.fused_moe.layer.FusedMoE.forward_impl] |
| pplx | 批处理 | fp8,int8 | G,A,T | 是 | 是 | [`PplxPrepareAndFinalize`][vllm.model_executor.layers.fused_moe.pplx_prepare_finalize.PplxPrepareAndFinalize] |
| deepep_high_throughput | 标准 | fp8 | G(128),A,T<sup>2</sup> | 是 | 是 | [`DeepEPLLPrepareAndFinalize`][vllm.model_executor.layers.fused_moe.deepep_ll_prepare_finalize.DeepEPLLPrepareAndFinalize] |
| deepep_low_latency | 批处理 | fp8 | G(128),A,T<sup>3</sup> | 是 | 是 | [`DeepEPHTPrepareAndFinalize`][vllm.model_executor.layers.fused_moe.deepep_ht_prepare_finalize.DeepEPHTPrepareAndFinalize] |
| flashinfer_all2allv | 标准 | nvfp4,fp8 | G,A,T | 否 | 否 | [`FlashInferA2APrepareAndFinalize`][vllm.model_executor.layers.fused_moe.flashinfer_a2a_prepare_finalize.FlashInferA2APrepareAndFinalize] |
| MoEPrepareAndFinalizeNoEP<sup>5</sup> | 标准 | fp8,int8 | G,A,T | 否 | 是 | [`MoEPrepareAndFinalizeNoEP`][vllm.model_executor.layers.fused_moe.prepare_finalize.MoEPrepareAndFinalizeNoEP] |
| BatchedPrepareAndFinalize<sup>5</sup> | 批处理 | fp8,int8 | G,A,T | 否 | 是 | [`BatchedPrepareAndFinalize`][vllm.model_executor.layers.fused_moe.fused_batched_moe.BatchedPrepareAndFinalize] |

!!! info "表格说明"
    1. 全部类型：mxfp4, nvfp4, int4, int8, fp8
    2. A,T 量化在分发后执行。
    3. 所有量化均在分发后执行。
    4. 通过不同环境变量控制（`VLLM_FLASHINFER_MOE_BACKEND` 设为 "throughput" 或 "latency"）
    5. 这是一个空操作分发器，可与任意模块化专家配对，生成无需执行分发或合并操作的模块化内核。无法通过环境变量选择。通常用于测试或将专家子类适配到 `fused_experts` API。
    6. 这取决于专家的具体实现。

    ---

    - G - 分组（Grouped）
    - G(N) - 分组且块大小为 N
    - A - 每激活 token
    - T - 每张量（Per tensor）

以下 `FusedMoEMethodBase` 类支持模块化内核：

- [`ModelOptFp8MoEMethod`][vllm.model_executor.layers.quantization.modelopt.ModelOptFp8MoEMethod]
- [`Fp8MoEMethod`][vllm.model_executor.layers.quantization.fp8.Fp8MoEMethod]
- [`CompressedTensorsW4A4Nvfp4MoEMethod`][vllm.model_executor.layers.quantization.compressed_tensors.compressed_tensors_moe.CompressedTensorsW4A4Nvfp4MoEMethod]
- [`CompressedTensorsW8A8Fp8MoEMethod`][vllm.model_executor.layers.quantization.compressed_tensors.compressed_tensors_moe.CompressedTensorsW8A8Fp8MoEMethod]
- [`Mxfp4MoEMethod`][vllm.model_executor.layers.quantization.mxfp4.Mxfp4MoEMethod]
- [`UnquantizedFusedMoEMethod`][vllm.model_executor.layers.fused_moe.layer.UnquantizedFusedMoEMethod]

## 融合专家内核

针对不同量化类型和架构，系统提供了多种 MoE 专家内核实现。大多数遵循基础 Triton [`fused_experts`][vllm.model_executor.layers.fused_moe.fused_moe.fused_experts] 函数的标准 API。许多内核配有模块化适配器，因此可与兼容的 all2all 后端配合使用。下表列出了各专家内核及其特定属性。

每个内核必须接收一种受支持的输入激活格式。部分内核变体通过不同入口点同时支持标准和批处理格式，例如 `TritonExperts` 和 `BatchedTritonExperts`。目前，批处理格式内核仅用于匹配特定 all2all 后端（如 `pplx` 和 `DeepEPLLPrepareAndFinalize`）。

与后端内核类似，每个专家内核仅支持特定的量化格式。对于非模块化专家，激活张量保持原始类型，由内核内部完成量化；而模块化专家则期望接收已量化的激活张量。两类专家最终均输出原始激活类型的结果。

每个专家内核支持一种或多种激活函数（如 silu 或 gelu），这些函数将应用于中间结果。

与后端类似，部分专家支持将 topk 权重应用于输入激活张量。本表该列内容仅适用于非模块化专家。

大多数专家变体均包含等效的模块化接口，其形式为 `FusedMoEPermuteExpertsUnpermute` 的子类。

要与特定的 `FusedMoEPrepareAndFinalize` 子类配合使用，MoE 内核必须在激活格式、量化类型及量化格式方面保持兼容。

| 内核 | 输入激活格式 | 量化类型 | 量化格式 | 激活函数 | 对输入应用权重 | 模块化 | 源码 |
|--------|-------------------|--------------|---------------|---------------------|-----------------------|---------|--------|
| triton | 标准 | 全部<sup>1</sup> | G,A,T | silu, gelu,</br>swigluoai,</br>silu_no_mul,</br>gelu_no_mul | 是 | 是 | [`fused_experts`][vllm.model_executor.layers.fused_moe.fused_moe.fused_experts],</br>[`TritonExperts`][vllm.model_executor.layers.fused_moe.fused_moe.TritonExperts] |
| triton (批处理) | 批处理 | 全部<sup>1</sup> | G,A,T | silu, gelu | <sup>6</sup> | 是 | [`BatchedTritonExperts`][vllm.model_executor.layers.fused_moe.fused_batched_moe.BatchedTritonExperts] |
| deep gemm | 标准,</br>批处理 | fp8 | G(128),A,T | silu, gelu | <sup>6</sup> | 是 | </br>[`DeepGemmExperts`][vllm.model_executor.layers.fused_moe.deep_gemm_moe.DeepGemmExperts],</br>[`BatchedDeepGemmExperts`][vllm.model_executor.layers.fused_moe.batched_deep_gemm_moe.BatchedDeepGemmExperts] |
| cutlass_fp4 | 标准,</br>批处理 | nvfp4 | A,T | silu | 是 | 是 | [`CutlassExpertsFp4`][vllm.model_executor.layers.fused_moe.cutlass_moe.CutlassExpertsFp4] |
| cutlass_fp8 | 标准,</br>批处理 | fp8 | A,T | silu, gelu | 是 | 是 | [`CutlassExpertsFp8`][vllm.model_executor.layers.fused_moe.cutlass_moe.CutlassExpertsFp8],</br>[`CutlasBatchedExpertsFp8`][vllm.model_executor.layers.fused_moe.cutlass_moe.CutlassBatchedExpertsFp8] |
| flashinfer | 标准 | nvfp4,</br>fp8 | T | <sup>5</sup> | 否 | 是 | [`FlashInferExperts`][vllm.model_executor.layers.fused_moe.flashinfer_cutlass_moe.FlashInferExperts] |
| gpt oss triton | 标准 | 不适用 | 不适用 | <sup>5</sup> | 是 | 是 | [`triton_kernel_fused_experts`][vllm.model_executor.layers.fused_moe.gpt_oss_triton_kernels_moe.triton_kernel_fused_experts],</br>[`OAITritonExperts`][vllm.model_executor.layers.fused_moe.gpt_oss_triton_kernels_moe.OAITritonExperts] |
| marlin | 标准,</br>批处理 | <sup>3</sup> / 不适用 | <sup>3</sup> / 不适用 | silu,</br>swigluoai | 是 | 是 | [`fused_marlin_moe`][vllm.model_executor.layers.fused_moe.fused_marlin_moe.fused_marlin_moe],</br>[`MarlinExperts`][vllm.model_executor.layers.fused_moe.fused_marlin_moe.MarlinExperts],</br>[`BatchedMarlinExperts`][vllm.model_executor.layers.fused_moe.fused_marlin_moe.BatchedMarlinExperts] |
| trtllm | 标准 | mxfp4,</br>nvfp4 | G(16),G(32) | <sup>5</sup> | 否 | 是 | [`TrtLlmGenExperts`][vllm.model_executor.layers.fused_moe.trtllm_moe.TrtLlmGenExperts] |
| rocm aiter moe | 标准 | fp8 | G(128),A,T | silu, gelu | 是 | 否 | [`rocm_aiter_fused_experts`][vllm.model_executor.layers.fused_moe.rocm_aiter_fused_moe.rocm_aiter_fused_experts] |
| cpu_fused_moe | 标准 | 不适用 | 不适用 | silu | 否 | 否 | [`CPUFusedMOE`][vllm.model_executor.layers.fused_moe.cpu_fused_moe.CPUFusedMOE] |
| naive batched<sup>4</sup> | 批处理 | int8,</br>fp8 | G,A,T | silu, gelu | <sup>6</sup> | 是 | [`NaiveBatchedExperts`][vllm.model_executor.layers.fused_moe.fused_batched_moe.NaiveBatchedExperts] |

!!! info "表格说明"
    1. 全部类型: mxfp4, nvfp4, int4, int8, fp8
    2. 围绕 triton 和 deep gemm 专家的调度器包装器。将根据类型 + 形状 + 量化参数进行选择
    3. uint4, uint8, fp8, fp4
    4. 这是支持批处理格式的专家的简单实现。主要用于测试。
    5. `activation` 参数被忽略，默认使用 SwiGlu。
    6. 仅由模块化内核处理或支持。

## 模块化内核"家族"

下表显示了旨在协同工作的模块化内核"家族"。某些组合可能有效但尚未经过测试，例如 flashinfer 与其他 fp8 专家的组合。请注意，"naive"后端可与任何非模块化专家配合使用。

| 后端 | `FusedMoEPrepareAndFinalize` 子类 | `FusedMoEPermuteExpertsUnpermute` 子类 |
|---------|-----------------------------------------|----------------------------------------------|
| deepep_high_throughput | `DeepEPHTPrepareAndFinalize` |  `DeepGemmExperts`,</br>`TritonExperts`,</br>`TritonOrDeepGemmExperts`,</br>`CutlassExpertsFp8`, </br>`MarlinExperts` |
| deepep_low_latency,</br>pplx | `DeepEPLLPrepareAndFinalize`,</br>`PplxPrepareAndFinalize` |  `BatchedDeepGemmExperts`,</br>`BatchedTritonExperts`,</br>`CutlassBatchedExpertsFp8`,</br>`BatchedMarlinExperts` |
| flashinfer | `FlashInferCutlassMoEPrepareAndFinalize` | `FlashInferExperts` |