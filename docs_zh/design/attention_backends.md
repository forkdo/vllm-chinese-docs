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

优先级表由构建脚本自动生成：

--8<-- "gen:priority-standard"

### MLA Attention（DeepSeek 风格）

优先级表由构建脚本自动生成：

--8<-- "gen:priority-mla"

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

--8<-- "gen:table-standard"

--8<-- "gen:table-minimax"

> **†** FlashInfer 在 Blackwell（SM100）上使用 TRTLLM attention，支持 sinks。通过 `--attention-config.use_trtllm_attention=0` 禁用。
>
> **\*** 通过 `--attention-config.flash_attn_version=2` 或 `3` 指定 FlashAttention 版本。SM90 上默认为 FA3，其他情况为 FA2。

## MLA（Multi-head Latent Attention）Backend

MLA 对 prefill 和 decode 阶段使用不同的 backend。

### Prefill Backend

Prefill backend 在运行时根据硬件和配置选择。

--8<-- "gen:table-mla-prefill"

### Decode Backend

--8<-- "gen:table-mla-decode"

--8<-- "gen:table-mla-v4-decode"