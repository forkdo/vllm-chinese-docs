# 结构化输出

源码 <https://github.com/vllm-project/vllm/tree/main/examples/online_serving/structured_outputs>.


此脚本演示了 vLLM 的 OpenAI 兼容服务器的各种结构化输出功能。
它可以运行单个约束类型或全部约束类型。
它支持流式响应和并发非流式请求。

要使用此示例，您必须使用任意选择的模型启动 vLLM 服务器。

```bash
vllm serve Qwen/Qwen2.5-3B-Instruct
```

要服务推理模型，您可以使用以下命令：

```bash
vllm serve deepseek-ai/DeepSeek-R1-Distill-Qwen-7B \
    --reasoning-parser deepseek_r1
```

如果您想使用 `uv` 独立运行此脚本，可以使用以下命令：

```bash
uvx --from git+https://github.com/vllm-project/vllm#subdirectory=examples/online_serving/structured_outputs \
    structured-outputs
```

更多信息请参见[功能文档](https://docs.vllm.ai/en/latest/features/structured_outputs.html)。

!!! 提示
    如果 vLLM 在远程运行，则在运行脚本之前设置 `OPENAI_BASE_URL=<remote_url>`。

## 用法

运行所有约束，非流式：

```bash
uv run structured_outputs.py
```

运行所有约束，流式：

```bash
uv run structured_outputs.py --stream
```

运行特定约束，例如 `structural_tag` 和 `regex`，流式：

```bash
uv run structured_outputs.py \
    --constraint structural_tag regex \
    --stream
```

运行所有约束，使用推理模型和流式：

```bash
uv run structured_outputs.py --reasoning --stream
```

## 示例材料

??? abstract "pyproject.toml"
    ``````toml
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/structured_outputs/pyproject.toml"
    ``````
??? abstract "structured_outputs.py"
    ``````py
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/structured_outputs/structured_outputs.py"
    ``````