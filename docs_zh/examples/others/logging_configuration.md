# 日志配置

来源 <https://github.com/vllm-project/vllm/blob/main/examples/others/logging_configuration.md>。

vLLM 利用 Python 的 `logging.config.dictConfig` 功能，实现对 vLLM 使用的各种日志记录器的强大且灵活的配置。

vLLM 提供了两个环境变量，可用于适应从简单但不灵活到更复杂但更灵活的多种日志配置需求。

- 无 vLLM 日志（简单但不灵活）
    - 设置 `VLLM_CONFIGURE_LOGGING=0`（不设置 `VLLM_LOGGING_CONFIG_PATH`）
- vLLM 的默认日志配置（简单但不灵活）
    - 不设置 `VLLM_CONFIGURE_LOGGING` 或设置 `VLLM_CONFIGURE_LOGGING=1`
- 细粒度自定义日志配置（更复杂，更灵活）
    - 不设置 `VLLM_CONFIGURE_LOGGING` 或设置 `VLLM_CONFIGURE_LOGGING=1`，并设置 `VLLM_LOGGING_CONFIG_PATH=<path-to-logging-config.json>`

## 日志配置环境变量

### `VLLM_CONFIGURE_LOGGING`

`VLLM_CONFIGURE_LOGGING` 控制 vLLM 是否对 vLLM 使用的日志记录器执行任何配置操作。此功能默认启用，但可通过在运行 vLLM 时设置 `VLLM_CONFIGURE_LOGGING=0` 来禁用。

如果启用了 `VLLM_CONFIGURE_LOGGING` 且未为 `VLLM_LOGGING_CONFIG_PATH` 指定值，vLLM 将使用内置默认配置来配置根 vLLM 日志记录器。默认情况下，不会配置其他 vLLM 日志记录器，因此所有 vLLM 日志记录器都将委托给根 vLLM 日志记录器来做出所有日志记录决策。

如果禁用了 `VLLM_CONFIGURE_LOGGING` 且为 `VLLM_LOGGING_CONFIG_PATH` 指定了值，则在启动 vLLM 时会发生错误。

### `VLLM_LOGGING_CONFIG_PATH`

`VLLM_LOGGING_CONFIG_PATH` 允许用户指定一个指向 JSON 文件的路径，该文件包含替代的自定义日志配置，将用于替代 vLLM 的内置默认日志配置。日志配置应以 JSON 格式提供，遵循 Python 的[日志配置字典模式](https://docs.python.org/3/library/logging.config.html#dictionary-schema-details)中指定的模式。

如果指定了 `VLLM_LOGGING_CONFIG_PATH`，但 `VLLM_CONFIGURE_LOGGING` 被禁用，则在启动 vLLM 时会发生错误。

## 示例

### 示例 1：自定义 vLLM 根日志记录器

在此示例中，我们将自定义 vLLM 根日志记录器，使用 [`python-json-logger`](https://github.com/nhairs/python-json-logger)（容器镜像的一部分）以 JSON 格式将日志记录到控制台的 STDOUT，日志级别为 `INFO`。

首先，创建一个适当的 JSON 日志配置文件：

??? note "/path/to/logging_config.json"

    ```json
    {
      "formatters": {
        "json": {
          "class": "pythonjsonlogger.jsonlogger.JsonFormatter"
        }
      },
      "handlers": {
        "console": {
          "class" : "logging.StreamHandler",
          "formatter": "json",
          "level": "INFO",
          "stream": "ext://sys.stdout"
        }
      },
      "loggers": {
        "vllm": {
          "handlers": ["console"],
          "level": "INFO",
          "propagate": false
        }
      },
      "version": 1
    }
    ```

最后，使用 `VLLM_LOGGING_CONFIG_PATH` 环境变量设置为自定义日志配置 JSON 文件的路径来运行 vLLM：

```bash
VLLM_LOGGING_CONFIG_PATH=/path/to/logging_config.json \
    vllm serve mistralai/Mistral-7B-v0.1 --max-model-len 2048
```

### 示例 2：静默特定 vLLM 日志记录器

要静默特定的 vLLM 日志记录器，需要为目标日志记录器提供自定义日志配置，配置该日志记录器使其不会将其日志消息传播到根 vLLM 日志记录器。

当为任何日志记录器提供自定义配置时，还必须为根 vLLM 日志记录器提供配置，因为任何自定义日志记录器配置都会覆盖 vLLM 使用的内置默认日志配置。

首先，创建一个适当的 JSON 日志配置文件，其中包含根 vLLM 日志记录器和您希望静默的日志记录器的配置：

??? note "/path/to/logging_config.json"

    ```json
    {
      "formatters": {
        "vllm": {
          "class": "vllm.logging_utils.NewLineFormatter",
          "datefmt": "%m-%d %H:%M:%S",
          "format": "%(levelname)s %(asctime)s %(filename)s:%(lineno)d] %(message)s"
        }
      },
      "handlers": {
        "vllm": {
          "class" : "logging.StreamHandler",
          "formatter": "vllm",
          "level": "INFO",
          "stream": "ext://sys.stdout"
        }
      },
      "loggers": {
        "vllm": {
          "handlers": ["vllm"],
          "level": "DEBUG",
          "propagate": false
        },
        "vllm.example_noisy_logger": {
          "propagate": false
        }
      },
      "version": 1
    }
    ```

最后，使用 `VLLM_LOGGING_CONFIG_PATH` 环境变量设置为自定义日志配置 JSON 文件的路径来运行 vLLM：

```bash
VLLM_LOGGING_CONFIG_PATH=/path/to/logging_config.json \
    vllm serve mistralai/Mistral-7B-v0.1 --max-model-len 2048
```

### 示例 3：禁用 vLLM 默认日志配置

要禁用 vLLM 的默认日志配置并静默所有 vLLM 日志记录器，只需在运行 vLLM 时设置 `VLLM_CONFIGURE_LOGGING=0`。这将阻止 vLLM 配置根 vLLM 日志记录器，从而静默所有其他 vLLM 日志记录器。

```bash
VLLM_CONFIGURE_LOGGING=0 \
    vllm serve mistralai/Mistral-7B-v0.1 --max-model-len 2048
```

### 示例 4：禁用健康检查端点的访问日志

在生产环境中，负载均衡器和监控系统会频繁调用 `/health`、`/metrics` 和 `/ping` 等健康检查端点，从而产生大量重复的访问日志。为了减少日志噪音，同时保留其他端点的日志，请使用 `--disable-access-log-for-endpoints` 选项。

**禁用健康和指标端点的访问日志：**

```bash
vllm serve mistralai/Mistral-7B-v0.1 --max-model-len 2048 \
    --disable-access-log-for-endpoints /health,/metrics,/ping
```

**可考虑过滤的常见端点：**

| 端点       | 描述               | 典型调用者                                         |
| ---------- | ------------------ | -------------------------------------------------- |
| `/health`  | 健康检查           | Kubernetes 存活/就绪探针、负载均衡器               |
| `/metrics` | Prometheus 指标    | Prometheus 抓取器（每 15-60 秒）                   |
| `/ping`    | SageMaker 健康检查 | SageMaker 基础设施                                 |
| `/load`    | 服务器负载指标     | 自定义监控                                         |

**注意事项：**

- 此选项仅影响 uvicorn 访问日志，不影响 vLLM 应用程序日志
- 多个端点请用逗号分隔（不要加空格）
- 过滤器使用精确路径匹配，忽略查询参数（例如 `/health?verbose=true` 会匹配 `/health`）
- 如果需要完全禁用所有访问日志，请使用 `--disable-uvicorn-access-log` 替代

## 其他资源

- [`logging.config` 字典模式详细信息](https://docs.python.org/3/library/logging.config.html#dictionary-schema-details)