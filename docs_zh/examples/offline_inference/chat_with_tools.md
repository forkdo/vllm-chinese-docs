---
title: 使用工具进行聊天
description: 本示例展示了如何使用 vLLM 与工具进行聊天，包括函数调用、工具使用和聊天历史记录的管理。
date: 2023-12-06
draft: false
linkTitle: 使用工具进行聊天
lastmod: 2023-12-06
weight: 30
---

在本示例中，我们将演示如何使用 vLLM 与工具进行聊天，包括：

- 调用工具（函数）
- 使用工具
- 管理聊天历史记录

## 要求

- vLLM 0.5.0 或更高版本

## 实现

```python
--8<-- "examples/offline_inference/chat_with_tools.py"
```

在本示例中，我们使用了以下工具：

- `get_current_weather` - 获取指定位置的当前天气
- `get_n_day_weather_forecast` - 获取指定位置未来 N 天的天气预报

## 运行示例

```bash
python examples/offline_inference/chat_with_tools.py \
    --model /root/workspaces/models/Qwen2-7B-Instruct \
    --tokenizer /root/workspaces/models/Qwen2-7B-Instruct \
    --max-model-len 4096 \
    --temperature 0.0 \
    --top-p 1.0 \
    --tensor-parallel-size 1 \
    --disable-log-requests
```