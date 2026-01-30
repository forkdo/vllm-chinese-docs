---
title: 弹性端点
description: 演示如何使用 vLLM 实现弹性端点，根据负载自动扩展模型实例。
linkTitle: 弹性端点
url: "/examples/online_serving/elastic_ep"
type: "docs"
weight: 3
tags:
  - online serving
  - elastic ep
  - deepseek
  - scaling
keywords:
  - vLLM
  - 在线服务
  - 弹性端点
  - 深度搜索
  - 扩缩容
---

# 弹性端点

源码 <https://github.com/vllm-project/vllm/tree/main/examples/online_serving/elastic_ep>.

## 基准测试

``````sh
--8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/elastic_ep/bench.sh"
``````

## 扩缩容

``````py
--8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/elastic_ep/scale.py"
``````

## 服务 Deepseek V2

``````sh
--8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/elastic_ep/serve_deepseek_v2.sh"
``````