# Claude Code [Claude Code](https://code.claude.com/docs/en/quickstart) 是 Anthropic 官方的终端智能编程工具。它能够理解你的代码库、编辑文件、运行命令，并帮助你更高效地编写代码。通过将 Claude Code 指向 vLLM 服务器，你可以使用自己的模型作为后端，替代 Anthropic API。这适用于：

- 运行完全本地/私密的编程辅助
- 使用具备工具调用能力的开源权重模型
- 使用自定义模型进行测试和开发

## 工作原理

vLLM 实现了 Anthropic Messages API，这是 Claude Code 用于与 Anthropic 服务器通信的相同 API。通过设置 `ANTHROPIC_BASE_URL` 指向你的 vLLM 服务器，Claude Code 会将其请求发送给 vLLM 而非 Anthropic。vLLM 随后会将这些请求转换为适用于本地模型的格式，并以 Claude Code 期望的格式返回响应。这意味着任何由 vLLM 提供服务的、具备适当工具调用支持的模型，都可以作为 Claude Code 中 Claude 模型的直接替代品。

## 要求

Claude Code 需要具备强大工具调用能力的模型。该模型必须支持 OpenAI 兼容的工具调用 API。有关如何为你的模型启用工具调用的详细信息，请参阅[工具调用](../../features/tool_calling.md)。

## 安装

首先，按照[官方安装指南](https://docs.anthropic.com/en/docs/claude-code/getting-started)安装 Claude Code。

## 启动 vLLM 服务器

使用具备工具调用能力的模型启动 vLLM —— 以下是使用 `openai/gpt-oss-120b` 的示例：

```bash
vllm serve openai/gpt-oss-120b --served-model-name my-model --enable-auto-tool-choice --tool-call-parser openai
```

对于其他模型，你需要使用 `--enable-auto-tool-choice` 和正确的 `--tool-call-parser` 显式启用工具调用。有关适合你模型的正确参数，请参阅[工具调用文档](../../features/tool_calling.md)。

## 配置 Claude Code

使用指向 vLLM 服务器的环境变量启动 Claude Code：

```bash
ANTHROPIC_BASE_URL=http://localhost:8000 \
ANTHROPIC_API_KEY=dummy \
ANTHROPIC_AUTH_TOKEN=dummy \
ANTHROPIC_DEFAULT_OPUS_MODEL=my-model \
ANTHROPIC_DEFAULT_SONNET_MODEL=my-model \
ANTHROPIC_DEFAULT_HAIKU_MODEL=my-model \
claude
```

环境变量：

| 变量 | 说明 |
| -------------------------------- | --------------------------------------------------------------------- |
| `ANTHROPIC_BASE_URL` | 指向你的 vLLM 服务器（默认端口为 8000） |
| `ANTHROPIC_API_KEY` | 可以是任意值，因为 vLLM 默认不需要身份验证 |
| `ANTHROPIC_AUTH_TOKEN` | 是必需的。可以是任意值。 |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | Opus 级别请求的模型名称 |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | Sonnet 级别请求的模型名称 |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | Haiku 级别请求的模型名称 |

!!! 提示

你可以将这些环境变量添加到你的 shell 配置文件（例如 `.bashrc`、`.zshrc`）、Claude Code 配置文件（`~/.claude/settings.json`）中，或者创建一个包装脚本以方便使用。

## 测试配置

Claude Code 启动后，尝试一个简单的提示来验证连接：

![Claude Code example chat](../../assets/deployment/claude-code-example.png)

如果模型正确响应，说明你的配置正在工作。你现在可以使用 Claude Code 配合 vLLM 提供的模型进行编程任务。

## 故障排除

**连接被拒绝**：确保 vLLM 正在运行并且可以通过指定的 URL 访问。检查端口是否匹配。

**工具调用不工作**：验证你的模型是否支持工具调用，并且你已使用正确的 `--tool-call-parser` 参数启用它。请参阅[工具调用](../../features/tool_calling.md)。

**模型未找到**：确保 `--served-model-name` 与环境变量中的模型名称匹配。你不能使用包含 `/` 的模型名称，例如直接从 Huggingface 使用的 `openai/gpt-oss-120b`，因此请注意 Claude Code 的这一限制。