# 服务器参数

`vllm serve` 命令用于启动与 OpenAI 兼容的服务器。

## 命令行参数

`vllm serve` 命令用于启动与 OpenAI 兼容的服务器。
如需查看可用选项，请参阅 [CLI 参考](../cli/README.md)！

## 配置文件

您可以通过 [YAML](https://yaml.org/) 配置文件加载 CLI 参数。
参数名称必须采用[上文](serve_args.md)所述的长格式形式。

例如：

```yaml
# config.yaml

model: meta-llama/Llama-3.1-8B-Instruct
host: "127.0.0.1"
port: 6379
uvicorn-log-level: "info"
```

使用上述配置文件的方法：

```bash
vllm serve --config config.yaml
```

!!! note
    如果某个参数同时通过命令行和配置文件提供，则命令行中的值将优先采用。
    优先级顺序为：`命令行 > 配置文件值 > 默认值`。
    例如：`vllm serve SOME_MODEL --config config.yaml`，此时 SOME_MODEL 将优先于配置文件中的 `model` 参数。