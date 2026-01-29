# Attention Backend Feature Support

本文件由 `tools/pre_commit/generate_attention_backend_docs.py` 自动生成。
它展示了每个已注册的 attention backend 的功能支持情况，
基于 `AttentionBackend.validate_configuration()` 中的检查。

**请勿手动编辑此文件。** 运行以下命令以重新生成：

```bash
python tools/pre_commit/generate_attention_backend_docs.py
```

## 设置 Attention Backend

### 命令行

有两种方式可以从命令行指定 backend：

**选项 1：使用 `--attention-backend`（简单）**

```bash
vllm serve <model> --attention-backend FLASH_ATTN
```

**选项 2：使用 `--attention-config.backend` / `-ac.backend`（结构化配置）**

```bash
# 点号表示法
vllm serve <model> --attention-config.backend FLASH_ATTN
vllm serve <model> -ac.backend FLASH_ATTN

# JSON 格式
vllm serve <model> --attention-config '{"backend": "FLASH_ATTN"}'
vllm serve <model> -ac '{"backend": "FLASH_ATTN"}'
```

> **注意：** `--attention-backend` 和 `--attention-config.backend` 是互斥的。
> 请使用其中之一，不要同时使用。

### Python API

在 `LLM` 类中使用 `AttentionConfig`：

```python
from vllm import LLM
from vllm.config import AttentionConfig
from vllm.v1.attention.backends.registry import AttentionBackendEnum

# 方法 1：使用 AttentionConfig 和枚举
llm = LLM(
    model="Qwen/Qwen3-0.6B",
    attention_config=AttentionConfig(backend=AttentionBackendEnum.FLASH_ATTN),
)

# 方法 2：使用 attention_backend 参数和字符串
llm = LLM(
    model="Qwen/Qwen3-0.6B",
    attention_backend="FLASH_ATTN",
)
```

## Backend 选择行为

### 手动选择

当您通过 `--attention-backend` 或 `AttentionConfig` 显式设置 backend 时：

1. 该 backend 会根据您的配置（模型 dtype、head size、compute capability 等）进行**验证**
2. 如果该 backend **不支持**您的配置，则会抛出错误并附带具体原因
3. 如果有效，则使用该 backend

选择不兼容 backend 时的错误示例：

```text
ValueError: Selected backend FLASHMLA is not valid for this configuration.
Reason: ['compute capability not supported']
```

### 自动选择

当未指定 backend 时（默认情况）：

1. vLLM 按**优先级顺序**遍历 backend（参见下表）
2. 每个 backend 都会根据您的配置进行验证
3. 选择**第一个兼容的 backend**
4. 如果没有兼容的 backend，则会抛出错误，列出所有 backend 及其不兼容原因

## Backend 优先级（CUDA）

当未显式选择 backend 时，vLLM 会从这些按优先级排序的列表中选择第一个兼容的 backend。

优先级 **1 = 最高**（最先尝试）。

### 标准 Attention（MHA、MQA、GQA）

**Blackwell（SM 10.x）：**

| 优先级 | Backend |
|--------|---------|
| 1 | `FLASHINFER` |
| 2 | `FLASH_ATTN` |
| 3 | `TRITON_ATTN` |
| 4 | `FLEX_ATTENTION` |

**Ampere/Hopper（SM 8.x-9.x）：**

| 优先级 | Backend |
|--------|---------|
| 1 | `FLASH_ATTN` |
| 2 | `FLASHINFER` |
| 3 | `TRITON_ATTN` |
| 4 | `FLEX_ATTENTION` |

### MLA Attention（DeepSeek 风格）

**Blackwell（SM 10.x）：**

| 优先级 | Backend |
|--------|---------|
| 1 | `FLASHINFER_MLA` |
| 2 | `CUTLASS_MLA` |
| 3 | `FLASH_ATTN_MLA` |
| 4 | `FLASHMLA` |
| 5 | `TRITON_MLA` |
| 6 | `FLASHMLA_SPARSE` |

**Ampere/Hopper（SM 8.x-9.x）：**

| 优先级 | Backend |
|--------|---------|
| 1 | `FLASH_ATTN_MLA` |
| 2 | `FLASHMLA` |
| 3 | `FLASHINFER_MLA` |
| 4 | `TRITON_MLA` |
| 5 | `FLASHMLA_SPARSE` |

> **注意：** ROCm 和 CPU 平台有各自的选择逻辑。有关详细信息，请参阅特定平台的文档。

## 图例

| 列 | 描述 |
|----|------|
| **Dtypes** | 支持的模型数据类型（fp16、bf16、fp32） |
| **KV Dtypes** | 支持的 KV cache 数据类型（`auto`、`fp8`、`fp8_e4m3` 等） |
| **Block Sizes** | 支持的 KV cache block 大小（%N 表示 N 的倍数） |
| **Head Sizes** | 支持的 attention head 大小 |
| **Sink** | Attention sink 支持（用于 StreamingLLM） |
| **Sparse** | Sparse attention 支持（仅 MLA） |
| **MM Prefix** | Multimodal prefix full attention 支持 |
| **Attention Types** | 支持的 attention 模式（Decoder、Encoder、Enc-Dec） |
| **Compute Cap.** | 所需的 CUDA compute capability（非 CUDA backend 为 N/A） |

**符号：** ✅ = 支持，❌ = 不支持

## 标准 Attention（MHA、MQA、GQA）Backend

| Backend | 版本 | Dtypes | KV Dtypes | Block Sizes | Head Sizes | Sink | MM Prefix | Attention Types | Compute Cap. |
|---------|------|--------|-----------|-------------|------------|------|-----------|-----------------|--------------|
| `CPU_ATTN` |  | fp16, bf16, fp32 | `auto` | Any | 32, 64, 80, 96, 112, 128, 160, 192, 224, 256 | ❌ | ❌ | All | N/A |
| `FLASHINFER` | Native† | fp16, bf16 | `auto`, `bfloat16`, `fp8`, `fp8_e4m3`, `fp8_e5m2` | 16, 32, 64 | 64, 128, 256 | ❌ | ❌ | Decoder | 7.x-9.x |
| `FLASHINFER` | TRTLLM† | fp16, bf16 | `auto`, `bfloat16`, `fp8`, `fp8_e4m3`, `fp8_e5m2` | 16, 32, 64 | 64, 128, 256 | ✅ | ❌ | Decoder | 10.x |
| `FLASH_ATTN` | FA2* | fp16, bf16 | `auto`, `bfloat16` | %16 | Any | ❌ | ❌ | All | ≥8.0 |
| `FLASH_ATTN` | FA3* | fp16, bf16 | `auto`, `bfloat16`, `fp8`, `fp8_e4m3`, `fp8_e5m2` | %16 | Any | ✅ | ❌ | All | 9.x |
| `FLASH_ATTN_DIFFKV` |  | fp16, bf16 | `auto` | Any | Any | ❌ | ❌ | Decoder | Any |
| `FLEX_ATTENTION` |  | fp16, bf16, fp32 | `auto`, `bfloat16` | Any | Any | ❌ | ✅ | Decoder, Encoder Only | Any |
| `ROCM_AITER_FA` |  | fp16, bf16 | `auto` | %16 | 64, 128, 256 | ❌ | ❌ | Decoder | N/A |
| `ROCM_AITER_UNIFIED_ATTN` |  | fp16, bf16 | `auto` | Any | Any | ❌ | ❌ | Decoder | N/A |
| `ROCM_ATTN` |  | fp16, bf16, fp32 | `auto` | 16, 32, 544 | 32, 64, 96, 128, 160, 192, 224, 256 | ❌ | ❌ | Decoder | N/A |
| `TREE_ATTN` |  | fp16, bf16 | `auto` | %16 | 32, 64, 96, 128, 160, 192, 224, 256 | ❌ | ❌ | Decoder | Any |
| `TRITON_ATTN` |  | fp16, bf16, fp32 | `auto`, `bfloat16`, `fp8`, `fp8_e4m3`, `fp8_e5m2` | %16 | Any | ✅ | ✅ | All | Any |

> **†** FlashInfer 在 Blackwell（SM100）上使用 TRTLLM attention，支持 sinks。通过 `--attention-config.use_trtllm_attention=0` 禁用。
>
> **\*** 通过 `--attention-config.flash_attn_version=2` 或 `3` 指定 FlashAttention 版本。SM90 上默认为 FA3，其他情况为 FA2。

## MLA（Multi-head Latent Attention）Backend

MLA 对 prefill 和 decode 阶段使用不同的 backend。

### Prefill Backend

Prefill backend 在运行时根据硬件和配置选择。

| Backend | 描述 | Compute Cap. | 启用 | 禁用 | 备注 |
|---------|------|--------------|------|------|------|
| TRT-LLM Ragged‡ | TensorRT-LLM ragged attention | 10.x | SM100 上默认 | `-ac.use_trtllm_ragged_deepseek_prefill=0` | 仅 DeepSeek R1 dims |
| FlashInfer | FlashInfer CUTLASS backend | 10.x | `-ac.disable_flashinfer_prefill=0` | `-ac.disable_flashinfer_prefill=1` | 仅 DeepSeek R1 dims |
| cuDNN | 基于 cuDNN 的 attention | 10.x | `-ac.use_cudnn_prefill=1` | `-ac.use_cudnn_prefill=0` |  |
| FlashAttention | FlashAttention varlen（FA2/FA3） | Any | 默认 fallback | 使用其他 backend | SM90 上为 FA3，其他情况为 FA2 |

> **‡** TRT-LLM Ragged 是 Blackwell（SM100）上的默认 backend。
> 在其他 GPU 上，FlashAttention 作为默认 backend 使用。

### Decode Backend

| 后端 | 数据类型 | KV 数据类型 | 块大小 | 头大小 | 汇流 | 稀疏 | MM 前缀 | 注意力类型 | 计算能力 |
|---------|--------|-----------|-------------|------------|------|--------|-----------|-----------------|--------------|
| `CUTLASS_MLA` | fp16, bf16 | `auto`, `bfloat16`, `fp8`, `fp8_e4m3` | 128 | 任意 | ❌ | ❌ | ❌ | 解码器 | 10.x |
| `FLASHINFER_MLA` | fp16, bf16 | `auto`, `bfloat16`, `fp8`, `fp8_e4m3` | 32, 64 | 任意 | ❌ | ❌ | ❌ | 解码器 | 10.x |
| `FLASHMLA` | fp16, bf16 | `auto`, `bfloat16`, `fp8`, `fp8_e4m3` | 64 | 任意 | ❌ | ❌ | ❌ | 解码器 | 9.x-10.x |
| `FLASHMLA_SPARSE` | bf16 | `auto`, `bfloat16`, `fp8_ds_mla` | 64 | 576 | ❌ | ✅ | ❌ | 解码器 | 9.x-10.x |
| `FLASH_ATTN_MLA` | fp16, bf16 | `auto`, `bfloat16` | %16 | 任意 | ❌ | ❌ | ❌ | 解码器 | 9.x |
| `ROCM_AITER_MLA` | fp16, bf16 | `auto` | 1 | 任意 | ❌ | ❌ | ❌ | 解码器 | N/A |
| `ROCM_AITER_MLA_SPARSE` | fp16, bf16 | `auto` | 任意 | 576 | ❌ | ❌ | ❌ | 解码器 | N/A |
| `ROCM_AITER_TRITON_MLA` | fp16, bf16 | `auto` | 任意 | 任意 | ❌ | ❌ | ❌ | 解码器 | N/A |
| `TRITON_MLA` | fp16, bf16 | `auto`, `bfloat16` | 任意 | 任意 | ❌ | ❌ | ❌ | 解码器 | 任意 |