# GGUF

!!! warning
    请注意，vLLM 对 GGUF 的支持目前处于高度实验性阶段，且尚未优化，可能与其他功能不兼容。目前，您可以使用 GGUF 来减少内存占用。如果遇到任何问题，请向 vLLM 团队报告。

!!! warning
    目前，vLLM 仅支持加载单文件 GGUF 模型。如果您有多文件 GGUF 模型，可以使用 [gguf-split](https://github.com/ggerganov/llama.cpp/pull/6135) 工具将其合并为单文件模型。

要使用 vLLM 运行 GGUF 模型，您可以下载并使用来自 [TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF](https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF) 的本地 GGUF 模型，命令如下：

```bash
wget https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf
# 建议使用基础模型的 tokenizer，以避免耗时且容易出错的 tokenizer 转换。
vllm serve ./tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf \
   --tokenizer TinyLlama/TinyLlama-1.1B-Chat-v1.0
```

您也可以添加 `--tensor-parallel-size 2` 以启用 2 个 GPU 的张量并行推理：

```bash
# 建议使用基础模型的 tokenizer，以避免耗时且容易出错的 tokenizer 转换。
vllm serve ./tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf \
   --tokenizer TinyLlama/TinyLlama-1.1B-Chat-v1.0 \
   --tensor-parallel-size 2
```

!!! warning
    我们建议使用基础模型的 tokenizer，而不是 GGUF 模型的 tokenizer。因为从 GGUF 转换 tokenizer 非常耗时且不稳定，尤其是对于词汇量较大的模型。

GGUF 假设 Hugging Face 可以将元数据转换为配置文件。如果 Hugging Face 不支持您的模型，您可以手动创建一个配置文件，并通过 `hf-config-path` 参数传递。

```bash
# 如果您的模型不被 Hugging Face 支持，您可以手动提供一个兼容 Hugging Face 的配置文件路径
vllm serve ./tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf \
   --tokenizer TinyLlama/TinyLlama-1.1B-Chat-v1.0 \
   --hf-config-path Tinyllama/TInyLlama-1.1B-Chat-v1.0
```

您也可以通过 LLM 入口点直接使用 GGUF 模型：

??? code

      ```python
      from vllm import LLM, SamplingParams

      # 在此脚本中，我们演示如何将输入传递给 chat 方法：
      conversation = [
         {
            "role": "system",
            "content": "You are a helpful assistant",
         },
         {
            "role": "user",
            "content": "Hello",
         },
         {
            "role": "assistant",
            "content": "Hello! How can I assist you today?",
         },
         {
            "role": "user",
            "content": "Write an essay about the importance of higher education.",
         },
      ]

      # 创建一个采样参数对象。
      sampling_params = SamplingParams(temperature=0.8, top_p=0.95)

      # 创建一个 LLM 实例。
      llm = LLM(
         model="./tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf",
         tokenizer="TinyLlama/TinyLlama-1.1B-Chat-v1.0",
      )
      # 根据提示生成文本。输出是一个 RequestOutput 对象列表，
      # 包含提示、生成的文本和其他信息。
      outputs = llm.chat(conversation, sampling_params)

      # 打印输出结果。
      for output in outputs:
         prompt = output.prompt
         generated_text = output.outputs[0].text
         print(f"Prompt: {prompt!r}, Generated text: {generated_text!r}")
      ```