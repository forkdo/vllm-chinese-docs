#### `--url`

:   正在运行的 OpenAI 兼容 RESTful API 服务器的 URL

:   默认值：`http://localhost:8000/v1`

#### `--model-name`

:   提示补全中使用的模型名称，默认为列出模型 API 调用中的第一个模型。

#### `--api-key`

:   OpenAI 服务的 API 密钥。如果提供，此 API 密钥将覆盖通过环境变量获取的 API 密钥。请注意，此选项仅适用于 OpenAI 兼容 API 端点，而不适用于服务器中可能存在的其他端点。有关更多详细信息，请参阅 vLLM 文档中的安全指南。

#### `--system-prompt`

:   要添加到聊天模板中的系统提示，用于支持系统提示的模型。

#### `-q`, `--quick`

:   发送单个提示作为 MESSAGE 并打印响应，然后退出。