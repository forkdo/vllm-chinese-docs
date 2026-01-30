---
title: Logits 处理器
description: 了解如何使用 vLLM 的 Logits 处理器进行离线推理的自定义输出控制
linkTitle: Logits 处理器
summary: 掌握 vLLM Logits 处理器的使用方法，实现对生成输出的精细控制
draft: false
type: docs
weight: 50
---

# Logits 处理器

源码 <https://github.com/vllm-project/vllm/tree/main/examples/offline_inference/logits_processor>.

## 自定义

``````py
--8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/offline_inference/logits_processor/custom.py"
``````

## 自定义请求

``````py
--8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/offline_inference/logits_processor/custom_req.py"
``````

## 自定义请求初始化

``````py
--8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/offline_inference/logits_processor/custom_req_init.py"
``````