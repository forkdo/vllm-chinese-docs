# 搭建 OpenTelemetry 概念验证环境

来源：<https://github.com/vllm-project/vllm/tree/main/examples/online_serving/opentelemetry>。

1. 安装 OpenTelemetry 相关包：

    ```bash
    pip install \
      'opentelemetry-sdk>=1.26.0,<1.27.0' \
      'opentelemetry-api>=1.26.0,<1.27.0' \
      'opentelemetry-exporter-otlp>=1.26.0,<1.27.0' \
      'opentelemetry-semantic-conventions-ai>=0.4.1,<0.5.0'
    ```

1. 在 Docker 容器中启动 Jaeger：

    ```bash
    # 参考：https://www.jaegertracing.io/docs/1.57/getting-started/
    docker run --rm --name jaeger \
        -e COLLECTOR_ZIPKIN_HOST_PORT=:9411 \
        -p 6831:6831/udp \
        -p 6832:6832/udp \
        -p 5778:5778 \
        -p 16686:16686 \
        -p 4317:4317 \
        -p 4318:4318 \
        -p 14250:14250 \
        -p 14268:14268 \
        -p 14269:14269 \
        -p 9411:9411 \
        jaegertracing/all-in-one:1.57
    ```

1. 在新终端中导出 Jaeger 的 IP 地址：

    ```bash
    export JAEGER_IP=$(docker inspect   --format '{{ .NetworkSettings.IPAddress }}' jaeger)
    export OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=grpc://$JAEGER_IP:4317
    ```

    然后设置 vLLM 的 OpenTelemetry 服务名称，启用与 Jaeger 的不安全连接，并运行 vLLM：

    ```bash
    export OTEL_SERVICE_NAME="vllm-server"
    export OTEL_EXPORTER_OTLP_TRACES_INSECURE=true
    vllm serve facebook/opt-125m --otlp-traces-endpoint="$OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"
    ```

1. 在新终端中，使用带有追踪上下文的虚拟客户端发送请求：

    ```bash
    export JAEGER_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' jaeger)
    export OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=grpc://$JAEGER_IP:4317
    export OTEL_EXPORTER_OTLP_TRACES_INSECURE=true
    export OTEL_SERVICE_NAME="client-service"
    python dummy_client.py
    ```

1. 打开 Jaeger Web UI：<http://localhost:16686/>

    在搜索面板中选择 `vllm-server` 服务，然后点击 `Find Traces`。您应该会看到一系列追踪记录，每个请求对应一条。
    ![追踪记录](https://i.imgur.com/GYHhFjo.png)

1. 点击某条追踪记录将显示其跨度（spans）及其标签。在此演示中，每条追踪记录包含两个跨度：一个来自包含提示文本的虚拟客户端，另一个来自包含请求元数据的 vLLM。
    ![跨度详情](https://i.imgur.com/OPf6CBL.png)

## 导出器协议

OpenTelemetry 的导出器支持使用 `grpc` 或 `http/protobuf` 作为追踪数据的传输协议。
默认使用 `grpc`。如需将 `http/protobuf` 设置为协议，请按如下方式配置 `OTEL_EXPORTER_OTLP_TRACES_PROTOCOL` 环境变量：

```bash
export OTEL_EXPORTER_OTLP_TRACES_PROTOCOL=http/protobuf
export OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://$JAEGER_IP:4318/v1/traces
vllm serve facebook/opt-125m --otlp-traces-endpoint="$OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"
```

## FastAPI 的自动检测

OpenTelemetry 支持对 FastAPI 进行自动检测。

1. 安装检测库

    ```bash
    pip install opentelemetry-instrumentation-fastapi
    ```

1. 使用 `opentelemetry-instrument` 运行 vLLM

    ```bash
    opentelemetry-instrument vllm serve facebook/opt-125m
    ```

1. 向 vLLM 发送请求并在 Jaeger 中查找其追踪记录。此时追踪记录应包含来自 FastAPI 的跨度。

    ![FastAPI 跨度](https://i.imgur.com/hywvoOJ.png)

## 示例材料

??? abstract "dummy_client.py"
    ``````py
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/opentelemetry/dummy_client.py"
    ``````