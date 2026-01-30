# Helm Charts

来源 <https://github.com/vllm-project/vllm/tree/main/examples/online_serving/chart-helm>。

此目录包含用于部署 vllm 应用程序的 Helm chart。该 chart 包含部署、自动扩缩容、资源管理等配置。

## 文件

- Chart.yaml：定义 chart 元数据，包括名称、版本和维护者。
- ct.yaml：chart 测试的配置。
- lintconf.yaml：YAML 文件的 linting 规则。
- values.schema.json：用于验证 values.yaml 的 JSON 模式。
- values.yaml：Helm chart 的默认值。
- templates/_helpers.tpl：用于定义通用配置的辅助模板。
- templates/configmap.yaml：创建 ConfigMap 的模板。
- templates/custom-objects.yaml：自定义 Kubernetes 对象的模板。
- templates/deployment.yaml：创建 Deployment 的模板。
- templates/hpa.yaml：Horizontal Pod Autoscaler 的模板。
- templates/job.yaml：Kubernetes Job 的模板。
- templates/poddisruptionbudget.yaml：Pod Disruption Budget 的模板。
- templates/pvc.yaml：Persistent Volume Claim 的模板。
- templates/secrets.yaml：Kubernetes Secret 的模板。
- templates/service.yaml：创建 Service 的模板。

## 运行测试

此 chart 包含使用 [helm-unittest](https://github.com/helm-unittest/helm-unittest) 的单元测试。安装插件并运行测试：

```bash
# 安装插件
helm plugin install https://github.com/helm-unittest/helm-unittest

# 运行测试
helm unittest .
```

## 示例材料

??? abstract ".helmignore"
    ``````
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/chart-helm/.helmignore"
    ``````
??? abstract "Chart.yaml"
    ``````yaml
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/chart-helm/Chart.yaml"
    ``````
??? abstract "ct.yaml"
    ``````yaml
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/chart-helm/ct.yaml"
    ``````
??? abstract "lintconf.yaml"
    ``````yaml
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/chart-helm/lintconf.yaml"
    ``````
??? abstract "templates/_helpers.tpl"
    ``````tpl
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/chart-helm/templates/_helpers.tpl"
    ``````
??? abstract "templates/configmap.yaml"
    ``````yaml
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/chart-helm/templates/configmap.yaml"
    ``````
??? abstract "templates/custom-objects.yaml"
    ``````yaml
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/chart-helm/templates/custom-objects.yaml"
    ``````
??? abstract "templates/deployment.yaml"
    ``````yaml
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/chart-helm/templates/deployment.yaml"
    ``````
??? abstract "templates/hpa.yaml"
    ``````yaml
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/chart-helm/templates/hpa.yaml"
    ``````
??? abstract "templates/job.yaml"
    ``````yaml
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/chart-helm/templates/job.yaml"
    ``````
??? abstract "templates/poddisruptionbudget.yaml"
    ``````yaml
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/chart-helm/templates/poddisruptionbudget.yaml"
    ``````
??? abstract "templates/pvc.yaml"
    ``````yaml
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/chart-helm/templates/pvc.yaml"
    ``````
??? abstract "templates/secrets.yaml"
    ``````yaml
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/chart-helm/templates/secrets.yaml"
    ``````
??? abstract "templates/service.yaml"
    ``````yaml
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/chart-helm/templates/service.yaml"
    ``````
??? abstract "tests/deployment_test.yaml"
    ``````yaml
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/chart-helm/tests/deployment_test.yaml"
    ``````
??? abstract "tests/job_test.yaml"
    ``````yaml
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/chart-helm/tests/job_test.yaml"
    ``````
??? abstract "tests/pvc_test.yaml"
    ``````yaml
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/chart-helm/tests/pvc_test.yaml"
    ``````
??? abstract "values.schema.json"
    ``````json
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/chart-helm/values.schema.json"
    ``````
??? abstract "values.yaml"
    ``````yaml
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/chart-helm/values.yaml"
    ``````