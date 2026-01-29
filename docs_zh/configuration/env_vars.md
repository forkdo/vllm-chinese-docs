# 环境变量

vLLM 使用以下环境变量来配置系统：

!!! warning
    请注意，`VLLM_PORT` 和 `VLLM_HOST_IP` 设置的是 vLLM **内部使用** 的端口和 IP 地址，而非 API 服务器的端口和 IP 地址。如果您使用 `--host $VLLM_HOST_IP` 和 `--port $VLLM_PORT` 来启动 API 服务器，将无法正常工作。

    vLLM 使用的所有环境变量均以 `VLLM_` 作为前缀。**Kubernetes 用户需特别注意**：请勿将服务命名为 `vllm`，否则 Kubernetes 设置的环境变量可能会与 vLLM 的环境变量发生冲突，因为 [Kubernetes 会为每个服务设置以该服务名称的大写形式作为前缀的环境变量](https://kubernetes.io/docs/concepts/services-networking/service/#environment-variables)。

```python
--8<-- "vllm/envs.py:env-vars-definition"
```