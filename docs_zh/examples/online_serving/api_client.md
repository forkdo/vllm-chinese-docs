---
title: API 客户端
description: 在 vLLM 中使用 HTTP API 客户端
linkTitle: API 客户端
type: book
page_title: API 客户端
---

本页面介绍如何使用 vLLM 的 HTTP API 客户端。

## 快速开始

请参阅 [在线服务](/docs/serving/online_serving) 以了解如何启动 vLLM 服务器。

## 客户端代码

```python
import json
import asyncio
import aiohttp
from typing import AsyncGenerator

API_URL = "http://localhost:8000/v1"
API_KEY = None

# 用于 HTTP 请求的会话
session = None


async def init_http_session():
    global session
    session = aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=3600))


async def get_chat_response(model: str, messages: list, stream=False) -> str:
    """
    通过 Chat Completions API 生成文本
    """
    url = f"{API_URL}/chat/completions"
    headers = {"Content-Type": "application/json"}
    if API_KEY:
        headers["Authorization"] = f"Bearer {API_KEY}"

    payload = {
        "model": model,
        "messages": messages,
        "stream": stream,
    }

    if stream:
        # 流式响应
        async with session.post(url, headers=headers, json=payload) as response:
            async for chunk in response.content.iter_chunked(1024):
                if chunk:
                    # 解码非空块
                    try:
                        decoded_chunk = chunk.decode("utf-8").strip()
                        # 解析每个数据块
                        for line in decoded_chunk.split("\n"):
                            if line.startswith("data: "):
                                data = line[6:]
                                if data == "[DONE]":
                                    break
                                try:
                                    chunk_data = json.loads(data)
                                    content = chunk_data.get("choices", [{}])[0].get("delta", {}).get("content", "")
                                    if content:
                                        print(content, end="", flush=True)
                                except json.JSONDecodeError:
                                    # 忽略解析错误
                                    pass
                    except UnicodeDecodeError:
                        # 忽略解码错误
                        pass
            return ""
    else:
        # 非流式响应
        async with session.post(url, headers=headers, json=payload) as response:
            response_data = await response.json()
            content = response_data.get("choices", [{}])[0].get("content", "")
            return content


async def get_completion_response(model: str, prompt: str, stream=False) -> str:
    """
    通过 Completions API 生成文本
    """
    url = f"{API_URL}/completions"
    headers = {"Content-Type": "application/json"}
    if API_KEY:
        headers["Authorization"] = f"Bearer {API_KEY}"

    payload = {
        "model": model,
        "prompt": prompt,
        "stream": stream,
    }

    if stream:
        # 流式响应
        async with session.post(url, headers=headers, json=payload) as response:
            async for chunk in response.content.iter_chunked(1024):
                if chunk:
                    # 解码非空块
                    try:
                        decoded_chunk = chunk.decode("utf-8").strip()
                        # 解析每个数据块
                        for line in decoded_chunk.split("\n"):
                            if line.startswith("data: "):
                                data = line[6:]
                                if data == "[DONE]":
                                    break
                                try:
                                    chunk_data = json.loads(data)
                                    content = chunk_data.get("choices", [{}])[0].get("text", "")
                                    if content:
                                        print(content, end="", flush=True)
                                except json.JSONDecodeError:
                                    # 忽略解析错误
                                    pass
                    except UnicodeDecodeError:
                        # 忽略解码错误
                        pass
            return ""
    else:
        # 非流式响应
        async with session.post(url, headers=headers, json=payload) as response:
            response_data = await response.json()
            content = response_data.get("choices", [{}])[0].get("content", "")
            return content


async def main():
    # 初始化 HTTP 会话
    await init_http_session()

    # 要请求的模型名称
    model = "llama-2-7b-chat"

    # 使用非流式聊天 API
    print("=== 非流式聊天 API ===")
    messages = [
        {
            "role": "user",
            "content": "请介绍一下你自己。",
        }
    ]
    response = await get_chat_response(model, messages, stream=False)
    print(f"\n\n{response}")

    # 使用流式聊天 API
    print("\n\n=== 流式聊天 API ===")
    messages = [
        {
            "role": "user",
            "content": "请介绍一下你自己。",
        }
    ]
    response = await get_chat_response(model, messages, stream=True)

    # 使用非流式完成 API
    print("\n\n=== 非流式完成 API ===")
    prompt = "请介绍一下你自己。"
    response = await get_completion_response(model, prompt, stream=False)
    print(f"\n\n{response}")

    # 使用流式完成 API
    print("\n\n=== 流式完成 API ===")
    prompt = "请介绍一下你自己。"
    response = await get_completion_response(model, prompt, stream=True)

    # 关闭会话
    await session.close()


if __name__ == "__main__":
    asyncio.run(main())
```

## 使用方法

运行此示例：

```bash
cd vllm && python examples/online_serving/api_client.py
```

---