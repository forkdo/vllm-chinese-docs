# 安全

## 节点间通信

在多节点 vLLM 部署中，所有节点之间的通信**默认情况下是不安全的**，必须通过将节点部署在隔离网络上来进行保护。这包括：

1. PyTorch 分布式通信
2. KV 缓存传输通信
3. 张量、流水线和数据并行通信

### 节点间通信的配置选项

以下选项控制 vLLM 中的节点间通信：

#### 1. **环境变量：**

- `VLLM_HOST_IP`：设置 vLLM 进程通信所使用的 IP 地址

#### 2. **KV 缓存传输配置：**

- `--kv-ip`：KV 缓存传输通信的 IP 地址（默认：127.0.0.1）
- `--kv-port`：KV 缓存传输通信的端口（默认：14579）

#### 3. **数据并行配置：**

- `data_parallel_master_ip`：数据并行主节点的 IP（默认：127.0.0.1）
- `data_parallel_master_port`：数据并行主节点的端口（默认：29500）

### PyTorch 分布式的注意事项

vLLM 使用 PyTorch 的分布式功能进行部分节点间通信。有关 PyTorch 分布式安全注意事项的详细信息，请参阅 [PyTorch 安全指南](https://github.com/pytorch/pytorch/security/policy#using-distributed-features)。

PyTorch 安全指南中的要点：

- PyTorch 分布式功能仅用于内部通信
- 它们不是为在不受信任的环境或网络中使用而构建的
- 由于性能原因，不包含任何授权协议
- 消息以明文形式发送
- 连接来自任何地方，无需检查

### 安全建议

#### 1. **网络隔离：**

- 在专用隔离网络上部署 vLLM 节点
- 使用网络分段防止未授权访问
- 实施适当的防火墙规则

#### 2. **配置最佳实践：**

- 始终将 `VLLM_HOST_IP` 设置为特定 IP 地址，而不是使用默认值
- 配置防火墙，仅允许节点间必要的端口通信

#### 3. **访问控制：**

- 限制对部署环境的物理和网络访问
- 为管理接口实施适当的认证和授权
- 为所有系统组件遵循最小权限原则

#### 4. **限制媒体 URL 的域名访问：**

通过设置 `--allowed-media-domains` 来限制 vLLM 可以访问的媒体 URL 域名，以防止服务器端请求伪造（SSRF）攻击。
（例如 `--allowed-media-domains upload.wikimedia.org github.com www.bogotobogo.com`）

同时，考虑设置 `VLLM_MEDIA_URL_ALLOW_REDIRECTS=0` 以防止 HTTP 重定向绕过域名限制。

## 安全与防火墙：保护暴露的 vLLM 系统

虽然 vLLM 的设计允许将不安全的网络服务隔离到私有网络中，但某些组件——如依赖项和底层框架——可能会在所有网络接口上开启不安全的服务，有时超出 vLLM 的直接控制。

主要关注点是使用 `torch.distributed`，vLLM 利用它进行分布式通信，包括在单一主机上使用 vLLM 时。当 vLLM 使用 TCP 初始化（参见 [PyTorch TCP 初始化文档](https://docs.pytorch.org/docs/stable/distributed.html#tcp-initialization)）时，PyTorch 创建一个 `TCPStore`，默认情况下在所有网络接口上监听。这意味着除非采取额外的保护措施，否则这些服务可能对任何可通过任何网络接口访问您机器的主机开放。

**从 PyTorch 的角度来看，任何使用 `torch.distributed` 的行为都应默认视为不安全的。** 这是 PyTorch 团队已知且有意为之的行为。

### 防火墙配置指南

保护 vLLM 系统的最佳方式是仔细配置防火墙，仅暴露必要的最小网络暴露面。在大多数情况下，这意味着：

- **阻止所有传入连接，仅允许连接到 API 服务器监听的 TCP 端口。**

- 确保用于内部通信的端口（如 `torch.distributed` 和 KV 缓存传输的端口）只能从受信任的主机或网络访问。

- 永远不要将这些内部端口暴露到公共互联网或不受信任的网络。

请参考您的操作系统或应用程序平台文档，获取具体的防火墙配置说明。

## API 密钥认证限制

### 概述

`--api-key` 标志（或 `VLLM_API_KEY` 环境变量）为 vLLM 的 HTTP 服务器提供认证，但**仅适用于 `/v1` 路径前缀下的 OpenAI 兼容 API 端点**。许多其他敏感端点在同一个 HTTP 服务器上暴露，且没有强制执行任何认证。

**重要提示：** 不要仅依赖 `--api-key` 来保护对 vLLM 的访问。生产环境部署需要额外的安全措施。

### 受保护的端点（需要 API 密钥）

当配置了 `--api-key` 时，以下 `/v1` 端点需要 Bearer 令牌认证：

- `/v1/models` - 列出可用模型
- `/v1/chat/completions` - 对话完成
- `/v1/completions` - 文本完成
- `/v1/embeddings` - 生成嵌入向量
- `/v1/audio/transcriptions` - 音频转录
- `/v1/audio/translations` - 音频翻译
- `/v1/messages` - Anthropic 兼容消息 API
- `/v1/responses` - 响应管理
- `/v1/score` - 评分 API
- `/v1/rerank` - 重排序 API

### 未受保护的端点（无需 API 密钥）

以下端点**即使配置了 `--api-key` 也不需要认证**：

**推理端点：**

- `/invocations` - SageMaker 兼容端点（路由到与 `/v1` 端点相同的推理功能）
- `/inference/v1/generate` - 生成完成
- `/pooling` - 池化 API
- `/classify` - 分类 API
- `/score` - 评分 API（非 `/v1` 版本）
- `/rerank` - 重排序 API（非 `/v1` 版本）

**操作控制端点（始终启用）：**

- `/pause` - 暂停生成（会导致服务拒绝）
- `/resume` - 恢复生成
- `/scale_elastic_ep` - 触发扩展操作

**工具端点：**

- `/tokenize` - 标记化文本
- `/detokenize` - 反标记化
- `/health` - 健康检查
- `/ping` - SageMaker 健康检查
- `/version` - 版本信息
- `/load` - 服务器负载指标

**标记器信息端点（仅当设置 `--enable-tokenizer-info-endpoint` 时可用）：**

该端点**仅在设置了 `--enable-tokenizer-info-endpoint` 标志时可用**。它可能会暴露敏感信息，如聊天模板和标记器配置：

- `/tokenizer_info` - 获取包含聊天模板和配置的完整标记器信息

**开发端点（仅当 `VLLM_SERVER_DEV_MODE=1` 时可用）：**

这些端点**仅在环境变量 `VLLM_SERVER_DEV_MODE` 设置为 `1` 时可用**。它们专为开发和调试设计，绝不应在生产环境中启用：

- `/server_info` - 获取详细服务器配置
- `/reset_prefix_cache` - 重置前缀缓存（可能中断服务）
- `/reset_mm_cache` - 重置多模态缓存（可能中断服务）
- `/sleep` - 让引擎休眠（会导致服务拒绝）
- `/wake_up` - 唤醒休眠的引擎
- `/is_sleeping` - 检查引擎是否休眠
- `/collective_rpc` - 在引擎上执行任意 RPC 方法（极其危险）

**性能分析端点（仅当设置 `VLLM_TORCH_PROFILER_DIR` 或 `VLLM_TORCH_CUDA_PROFILE` 时可用）：**

这些端点仅在启用性能分析时可用，仅应用于本地开发：

- `/start_profile` - 启动 PyTorch 性能分析器
- `/stop_profile` - 停止 PyTorch 性能分析器

**注意：** `/invocations` 端点特别值得关注，因为它提供了对与受保护 `/v1` 端点相同推理功能的未认证访问。

### 安全影响

能够访问 vLLM HTTP 服务器的攻击者可以：

1. **绕过身份验证**：通过使用非 `/v1` 接口（如 `/invocations`、`/inference/v1/generate`、`/pooling`、`/classify`、`/score` 或 `/rerank`）运行任意推理任务，无需凭据

2. **导致拒绝服务攻击**：在未提供令牌的情况下调用 `/pause` 或 `/scale_elastic_ep` 接口

3. **访问运维控制功能**：通过未授权方式操纵服务器状态（例如暂停生成过程）

4. **若设置了 `--enable-tokenizer-info-endpoint`**：可访问敏感的分词器配置信息，包括聊天模板，可能泄露提示工程策略或其他实现细节

5. **若设置了 `VLLM_SERVER_DEV_MODE=1`**：可通过 `/collective_rpc` 执行任意 RPC 命令、重置缓存、使引擎休眠，并获取详细的服务器配置信息

### 推荐的安全实践

#### 1. 最小化暴露的接口

**关键提醒**：永远不要在生产环境中设置 `VLLM_SERVER_DEV_MODE=1`。开发接口会暴露极其危险的功能，包括：

- 通过 `/collective_rpc` 执行任意 RPC 命令
- 可能导致服务中断的缓存操作
- 详细的服务器配置信息泄露

同样，不要在生产环境中启用性能分析接口（`VLLM_TORCH_PROFILER_DIR` 或 `VLLM_TORCH_CUDA_PROFILE`）。

**谨慎使用 `--enable-tokenizer-info-endpoint`**：仅在需要暴露分词器配置信息时才启用 `/tokenizer_info` 接口。该接口会公开聊天模板和分词器配置，可能包含敏感的实现细节或提示工程策略。

#### 2. 在反向代理后部署

最有效的方法是将 vLLM 部署在反向代理（如 nginx、Envoy 或 Kubernetes Gateway）之后，该代理应：

- 明确白名单允许仅向终端用户暴露所需的接口
- 阻止所有其他接口，包括未认证的推理接口和运维控制接口
- 在代理层实现额外的身份验证、限流和日志记录功能

## 报告安全漏洞

如果您认为在 vLLM 中发现了安全漏洞，请按照项目的[安全政策](https://github.com/vllm-project/vllm/blob/main/SECURITY.md)进行报告。有关如何报告安全问题以及项目安全政策的更多信息，请参阅[vLLM 安全政策](https://github.com/vllm-project/vllm/blob/main/SECURITY.md)。