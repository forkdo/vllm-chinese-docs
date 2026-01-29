---
toc_depth: 3
---

# 引擎参数

引擎参数用于控制 vLLM 引擎的行为。

- 对于[离线推理](../serving/offline_inference.md)，它们是 [LLM][vllm.LLM] 类参数的一部分。
- 对于[在线服务](../serving/openai_compatible_server.md)，它们是 `vllm serve` 命令的参数。

引擎参数类 [EngineArgs][vllm.engine.arg_utils.EngineArgs] 和 [AsyncEngineArgs][vllm.engine.arg_utils.AsyncEngineArgs] 是由 [vllm.config][] 中定义的配置类组合而成的。因此，如果您需要开发者文档，建议查看这些配置类，因为它们是类型、默认值和文档字符串的权威来源。

--8<-- "docs/cli/json_tip.inc.md"

## `EngineArgs`

--8<-- "docs/generated/argparse/engine_args.inc.md"

## `AsyncEngineArgs`

--8<-- "docs/generated/argparse/async_engine_args.inc.md"