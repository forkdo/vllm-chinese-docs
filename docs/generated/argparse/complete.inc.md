#### `--url`

:   运行中的 OpenAI 兼容 RESTful API 服务器的 URL

:   默认值：`http://localhost:8000/v1`

#### `--model-name`

:   用于提示补全的模型名称，默认为列出模型 API 调用中的第一个模型。

#### `--api-key`

:   OpenAI 服务的 API 密钥。如果提供，此 API 密钥将覆盖通过环境变量获取的 API 密钥。请注意，此选项仅适用于 OpenAI 兼容的 API 端点，而不适用于服务器中可能存在的其他端点。有关更多详细信息，请参阅 vLLM 文档中的安全指南。

#### `--max-tokens`

:   每个输出序列生成的最大 token 数量。

#### `-q`, `--quick`

:   发送单个提示并打印补全输出，然后退出。