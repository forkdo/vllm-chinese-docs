# 自动前缀缓存

## 简介

自动前缀缓存（简称 APC）缓存现有查询的 KV 缓存，这样当新查询与现有查询共享相同前缀时，可以直接复用该 KV 缓存，从而让新查询跳过共享部分的计算。

!!! 注意
关于 vLLM 如何实现 APC 的技术细节可以在[这里](../design/prefix_caching.md)找到。

## 在 vLLM 中启用 APC

在 vLLM 引擎中设置 `enable_prefix_caching=True` 以启用 APC。示例如下：

[examples/features/automatic_prefix_caching/automatic_prefix_caching_offline.py](../../examples/features/automatic_prefix_caching/automatic_prefix_caching_offline.py)

## 示例工作负载

我们描述两个示例工作负载，在这些场景中 APC 可以提供巨大的性能优势：

- 长文档查询，用户反复使用不同的查询查询同一长文档（例如软件手册或年度报告）。在这种情况下，APC 允许 vLLM 只处理一次该长文档，而无需反复处理，所有后续请求都可以通过复用其 KV 缓存来避免重新计算该长文档。这使得 vLLM 能够以更高的吞吐量和更低的延迟为后续请求提供服务。

- 多轮对话，用户可能在同一聊天会话中与应用进行多次聊天。在这种情况下，APC 允许 vLLM 复用聊天历史的处理结果，而无需反复处理整个聊天历史，从而使 vLLM 能够以更高的吞吐量和更低的延迟为后续请求提供服务。

## 限制

APC 通常不会降低 vLLM 的性能。话虽如此，APC 只减少处理查询的时间（预填充阶段），而不会减少生成新 token 的时间（解码阶段）。因此，当 vLLM 大部分时间用于生成查询答案时（例如答案长度较长时），或者新查询与任何现有查询都不共享相同前缀时（因此无法复用计算），APC 不会带来性能提升。