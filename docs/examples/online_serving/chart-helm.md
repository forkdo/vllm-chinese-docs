# Helm Charts

Source <https://github.com/vllm-project/vllm/tree/main/examples/online_serving/chart-helm>.


This directory contains a Helm chart for deploying the vllm application. The chart includes configurations for deployment, autoscaling, resource management, and more.

## Files

- Chart.yaml: Defines the chart metadata including name, version, and maintainers.
- ct.yaml: Configuration for chart testing.
- lintconf.yaml: Linting rules for YAML files.
- values.schema.json: JSON schema for validating values.yaml.
- values.yaml: Default values for the Helm chart.
- templates/_helpers.tpl: Helper templates for defining common configurations.
- templates/configmap.yaml: Template for creating ConfigMaps.
- templates/custom-objects.yaml: Template for custom Kubernetes objects.
- templates/deployment.yaml: Template for creating Deployments.
- templates/hpa.yaml: Template for Horizontal Pod Autoscaler.
- templates/job.yaml: Template for Kubernetes Jobs.
- templates/poddisruptionbudget.yaml: Template for Pod Disruption Budget.
- templates/pvc.yaml: Template for Persistent Volume Claims.
- templates/secrets.yaml: Template for Kubernetes Secrets.
- templates/service.yaml: Template for creating Services.

## Running Tests

This chart includes unit tests using [helm-unittest](https://github.com/helm-unittest/helm-unittest). Install the plugin and run tests:

```bash
# Install plugin
helm plugin install https://github.com/helm-unittest/helm-unittest

# Run tests
helm unittest .
```

## Example materials

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
