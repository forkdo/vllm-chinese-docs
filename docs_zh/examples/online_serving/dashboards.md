# 监控仪表板

来源：<https://github.com/vllm-project/vllm/tree/main/examples/online_serving/dashboards>

此目录包含 vLLM 的监控仪表板配置，为您的 vLLM 部署提供全面的可观测性。

## 仪表板平台

我们为两个流行的可观测性平台提供了仪表板：

- **[Grafana](https://grafana.com)**
- **[Perses](https://perses.dev)**

## 仪表板格式方案

所有仪表板均以**原生格式**提供，可在不同的部署方法中使用：

### Grafana（JSON）

- ✅ 适用于任何 Grafana 实例（云端、自托管、Docker）
- ✅ 可通过 Grafana UI 或 API 直接导入
- ✅ 可在需要时封装到 Kubernetes 操作器中
- ✅ 无厂商锁定或部署依赖

### Perses（YAML）

- ✅ 适用于独立的 Perses 实例
- ✅ 与 Perses API 和 CLI 兼容
- ✅ 支持“仪表板即代码”（Dashboard-as-Code）工作流
- ✅ 可在需要时封装到 Kubernetes 操作器中

## 仪表板内容

两个平台均提供等效的监控功能：

| 仪表板 | 说明 |
|--------|------|
| **性能统计** | 跟踪延迟、吞吐量和性能指标 |
| **查询统计** | 监控请求量、查询性能和关键绩效指标（KPI） |

## 快速入门

首先，进入此示例目录：

```bash
cd examples/online_serving/dashboards
```

### Grafana

直接将 JSON 导入 Grafana UI，或使用 API：

```bash
curl -X POST http://grafana/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @grafana/performance_statistics.json
```

### Perses

通过 Perses CLI 导入：

```bash
percli apply -f perses/performance_statistics.yaml
```

## 要求

- 来自 vLLM 部署的 **Prometheus** 指标
- 在监控平台中配置**数据源**
- 启用并可访问 **vLLM 指标**

## 平台专属文档

有关详细的部署说明和平台专属选项，请参阅：

- **[Grafana 文档](https://github.com/vllm-project/vllm/tree/main/examples/online_serving/dashboards/grafana)** - JSON 仪表板、操作器用法、手动导入
- **[Perses 文档](https://github.com/vllm-project/vllm/tree/main/examples/online_serving/dashboards/perses)** - YAML 规范、CLI 用法、操作器封装

## 贡献指南

添加新仪表板时，请：

1. 提供原生格式（Grafana 使用 JSON，Perses 使用 YAML 规范）
2. 更新平台专属的 README 文件
3. 确保仪表板可在不同部署方法中运行
4. 使用最新平台版本进行测试

## 示例材料

??? abstract "grafana/README.md"
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/dashboards/grafana/README.md"
??? abstract "grafana/performance_statistics.json"
    ``````json
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/dashboards/grafana/performance_statistics.json"
    ``````
??? abstract "grafana/query_statistics.json"
    ``````json
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/dashboards/grafana/query_statistics.json"
    ``````
??? abstract "perses/README.md"
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/dashboards/perses/README.md"
??? abstract "perses/performance_statistics.yaml"
    ``````yaml
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/dashboards/perses/performance_statistics.yaml"
    ``````
??? abstract "perses/query_statistics.yaml"
    ``````yaml
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/dashboards/perses/query_statistics.yaml"
    ``````