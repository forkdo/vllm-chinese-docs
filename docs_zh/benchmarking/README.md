# 基准测试套件

vLLM 提供了全面的基准测试工具，用于性能测试和评估：

- **[基准测试 CLI](./cli.md)**：`vllm bench` CLI 工具以及用于交互式性能测试的专用基准测试脚本。
- **[参数扫描](./sweeps.md)**：自动运行多个配置的 `vllm bench`，适用于[优化和调优](../configuration/optimization.md)。
- **[性能仪表板](./dashboard.md)**：自动化的 CI，每次提交都会发布基准测试结果。