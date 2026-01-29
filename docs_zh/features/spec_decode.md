# 推测解码

!!! warning
    请注意，vLLM 中的推测解码功能尚未优化，通常不会为所有提示数据集或采样参数带来令牌间延迟的降低。相关优化工作正在进行中，可在此处关注进展：<https://github.com/vllm-project/vllm/issues/4630>

!!! warning
    目前，vLLM 中的推测解码与流水线并行不兼容。

本文档展示了如何在 vLLM 中使用[推测解码](https://x.com/karpathy/status/1697318534555336961)。推测解码是一种能够改善内存受限型 LLM 推理中令牌间延迟的技术。

## 使用草稿模型进行推测

以下代码配置 vLLM 在离线模式下使用草稿模型进行推测解码，每次推测 5 个令牌。

!!! warning
    在 vLLM v0.10.0 中，不支持使用草稿模型的推测解码。
    如果使用以下代码，将会收到 `NotImplementedError` 错误。

??? code

    ```python
    from vllm import LLM, SamplingParams

    prompts = [
        "The future of AI is",
    ]
    sampling_params = SamplingParams(temperature=0.8, top_p=0.95)

    llm = LLM(
        model="facebook/opt-6.7b",
        tensor_parallel_size=1,
        speculative_config={
            "model": "facebook/opt-125m",
            "num_speculative_tokens": 5,
        },
    )
    outputs = llm.generate(prompts, sampling_params)

    for output in outputs:
        prompt = output.prompt
        generated_text = output.outputs[0].text
        print(f"Prompt: {prompt!r}, Generated text: {generated_text!r}")
    ```

要以在线模式执行相同操作，请启动服务器：

```bash
vllm serve facebook/opt-6.7b \
    --host 0.0.0.0 \
    --port 8000 \
    --seed 42 \
    -tp 1 \
    --gpu_memory_utilization 0.8 \
    --speculative_config '{"model": "facebook/opt-125m", "num_speculative_tokens": 5}'
```

!!! warning
    注意：请使用 `--speculative_config` 设置所有与推测解码相关的配置。之前通过 `--speculative_model` 指定模型并单独添加相关参数（例如 `--num_speculative_tokens`）的方法现已弃用。

然后使用客户端：

??? code

    ```python
    from openai import OpenAI

    # 修改 OpenAI 的 API 密钥和 API 基础地址以使用 vLLM 的 API 服务器。
    openai_api_key = "EMPTY"
    openai_api_base = "http://localhost:8000/v1"

    client = OpenAI(
        # 默认为 os.environ.get("OPENAI_API_KEY")
        api_key=openai_api_key,
        base_url=openai_api_base,
    )

    models = client.models.list()
    model = models.data[0].id

    # 补全 API
    stream = False
    completion = client.completions.create(
        model=model,
        prompt="The future of AI is",
        echo=False,
        n=1,
        stream=stream,
    )

    print("Completion results:")
    if stream:
        for c in completion:
            print(c)
    else:
        print(completion)
    ```

## 通过在提示中匹配 n-gram 进行推测

以下代码配置 vLLM 使用推测解码，其中通过匹配提示中的 n-gram 来生成提案。更多信息请阅读[此讨论串](https://x.com/joao_gante/status/1747322413006643259)。

??? code

    ```python
    from vllm import LLM, SamplingParams

    prompts = [
        "The future of AI is",
    ]
    sampling_params = SamplingParams(temperature=0.8, top_p=0.95)

    llm = LLM(
        model="facebook/opt-6.7b",
        tensor_parallel_size=1,
        speculative_config={
            "method": "ngram",
            "num_speculative_tokens": 5,
            "prompt_lookup_max": 4,
        },
    )
    outputs = llm.generate(prompts, sampling_params)

    for output in outputs:
        prompt = output.prompt
        generated_text = output.outputs[0].text
        print(f"Prompt: {prompt!r}, Generated text: {generated_text!r}")
    ```

## 使用后缀解码进行推测

以下代码配置 vLLM 使用推测解码，其中通过后缀解码（[技术报告](https://arxiv.org/abs/2411.04975)）生成提案。

与 n-gram 类似，后缀解码可以通过使用最后 `n` 个生成的令牌进行模式匹配来生成草稿令牌。但与 n-gram 不同的是，后缀解码 (1) 可以对提示和之前的生成结果进行模式匹配，(2) 使用频率计数来提出最可能的延续，(3) 在每次迭代中为每个请求推测自适应数量的令牌，以获得更好的接受率。

后缀解码在具有高重复性的任务上可以实现更好的性能，例如代码编辑、代理循环（例如自我反思、自我一致性）和强化学习推演。

!!! tip "安装 Arctic Inference"
    后缀解码需要[Arctic Inference](https://github.com/snowflakedb/ArcticInference)。可通过 `pip install arctic-inference` 安装。

!!! tip "后缀解码推测令牌"
    后缀解码将在每个解码步骤中为每个请求推测动态数量的令牌，因此 `num_speculative_tokens` 配置指定的是推测令牌数的*最大值*。建议使用较高的数值，例如 `16` 或 `32`（默认值）。

??? code

    ```python
    from vllm import LLM, SamplingParams

    prompts = [
        "The future of AI is",
    ]
    sampling_params = SamplingParams(temperature=0.8, top_p=0.95)

    llm = LLM(
        model="facebook/opt-6.7b",
        tensor_parallel_size=1,
        speculative_config={
            "method": "suffix",
            "num_speculative_tokens": 32,
        },
    )
    outputs = llm.generate(prompts, sampling_params)

    for output in outputs:
        prompt = output.prompt
        generated_text = output.outputs[0].text
        print(f"Prompt: {prompt!r}, Generated text: {generated_text!r}")
    ```

## 使用 MLP 推测器进行推测

以下代码配置 vLLM 使用推测解码，其中通过草稿模型生成提案，这些草稿模型基于上下文向量和采样令牌来条件化草稿预测。更多信息请参见[此博客](https://pytorch.org/blog/hitchhikers-guide-speculative-decoding/)或[此技术报告](https://arxiv.org/abs/2404.19124)。

??? code

    ```python
    from vllm import LLM, SamplingParams

    prompts = [
        "The future of AI is",
    ]
    sampling_params = SamplingParams(temperature=0.8, top_p=0.95)

    llm = LLM(
        model="meta-llama/Meta-Llama-3.1-70B-Instruct",
        tensor_parallel_size=4,
        speculative_config={
            "model": "ibm-ai-platform/llama3-70b-accelerator",
            "draft_tensor_parallel_size": 1,
        },
    )
    outputs = llm.generate(prompts, sampling_params)

    for output in outputs:
        prompt = output.prompt
        generated_text = output.outputs[0].text
        print(f"Prompt: {prompt!r}, Generated text: {generated_text!r}")
    ```

请注意，这些推测模型目前需要在无张量并行的情况下运行，尽管主模型可以使用张量并行（参见上述示例）。由于推测模型相对较小，我们仍然能看到显著的速度提升。不过，此限制将在未来的版本中修复。

HF 中心提供了多种此类推测模型：

- [llama-13b-accelerator](https://huggingface.co/ibm-ai-platform/llama-13b-accelerator)
- [llama3-8b-accelerator](https://huggingface.co/ibm-ai-platform/llama3-8b-accelerator)
- [codellama-34b-accelerator](https://huggingface.co/ibm-ai-platform/codellama-34b-accelerator)
- [llama2-70b-accelerator](https://huggingface.co/ibm-ai-platform/llama2-70b-accelerator)
- [llama3-70b-accelerator](https://huggingface.co/ibm-ai-platform/llama3-70b-accelerator)
- [granite-3b-code-instruct-accelerator](https://huggingface.co/ibm-granite/granite-3b-code-instruct-accelerator)
- [granite-8b-code-instruct-accelerator](https://huggingface.co/ibm-granite/granite-8b-code-instruct-accelerator)
- [granite-7b-instruct-accelerator](https://huggingface.co/ibm-granite/granite-7b-instruct-accelerator)
- [granite-20b-code-instruct-accelerator](https://huggingface.co/ibm-granite/granite-20b-code-instruct-accelerator)

## 使用基于 EAGLE 的草案模型进行推测

以下代码配置 vLLM 使用推测解码，其中提案由基于 [EAGLE（Extrapolation Algorithm for Greater Language-model Efficiency）](https://arxiv.org/pdf/2401.15077) 的草案模型生成。离线模式的更详细示例（包括如何提取请求级别的接受率）可参见[此处](../../examples/offline_inference/spec_decode.py)。

??? code

    ```python
    from vllm import LLM, SamplingParams

    prompts = [
        "The future of AI is",
    ]
    sampling_params = SamplingParams(temperature=0.8, top_p=0.95)

    llm = LLM(
        model="meta-llama/Meta-Llama-3-8B-Instruct",
        tensor_parallel_size=4,
        speculative_config={
            "model": "yuhuili/EAGLE-LLaMA3-Instruct-8B",
            "draft_tensor_parallel_size": 1,
            "num_speculative_tokens": 2,
            "method": "eagle",
        },
    )

    outputs = llm.generate(prompts, sampling_params)

    for output in outputs:
        prompt = output.prompt
        generated_text = output.outputs[0].text
        print(f"Prompt: {prompt!r}, Generated text: {generated_text!r}")

    ```

使用基于 EAGLE 的草案模型时，需要注意以下几点：

1. [EAGLE 模型 HF 仓库](https://huggingface.co/yuhuili) 中的 EAGLE 草案模型在 <https://github.com/vllm-project/vllm/pull/12304> 合并后，应可直接由 vLLM 加载和使用。  
   如果您使用的是 <https://github.com/vllm-project/vllm/pull/12304> 之前的 vLLM 版本，请使用[此脚本](https://gist.github.com/abhigoyal1997/1e7a4109ccb7704fbc67f625e86b2d6d)转换推测模型，并在 `speculative_config` 中指定 `"model": "path/to/modified/eagle/model"`。  
   若使用最新版 vLLM 仍遇到权重加载问题，请留言或提交 issue。

2. 基于 EAGLE 的草案模型必须在**无张量并行**的情况下运行（即在 `speculative_config` 中将 `draft_tensor_parallel_size` 设为 1），但主模型仍可使用张量并行（参见上方示例）。

3. 在 vLLM 中使用基于 EAGLE 的推测器时，观察到的加速比低于参考实现中报告的结果（[此处](https://github.com/SafeAILab/EAGLE)）。该问题正在调查中，跟踪链接：<https://github.com/vllm-project/vllm/issues/9565>。

4. 使用 EAGLE-3 草案模型时，必须将选项 `"method"` 设为 `"eagle3"`，即在 `speculative_config` 中指定 `"method": "eagle3"`。

Hugging Face Hub 上提供了多种 EAGLE 草案模型：

| 基础模型                                                             | Hugging Face 上的 EAGLE 模型              | EAGLE 参数量 |
|---------------------------------------------------------------------|-------------------------------------------|--------------|
| Vicuna-7B-v1.3                                                       | yuhuili/EAGLE-Vicuna-7B-v1.3             | 0.24B        |
| Vicuna-13B-v1.3                                                      | yuhuili/EAGLE-Vicuna-13B-v1.3            | 0.37B        |
| Vicuna-33B-v1.3                                                      | yuhuili/EAGLE-Vicuna-33B-v1.3            | 0.56B        |
| LLaMA2-Chat 7B                                                       | yuhuili/EAGLE-llama2-chat-7B             | 0.24B        |
| LLaMA2-Chat 13B                                                      | yuhuili/EAGLE-llama2-chat-13B            | 0.37B        |
| LLaMA2-Chat 70B                                                      | yuhuili/EAGLE-llama2-chat-70B            | 0.99B        |
| Mixtral-8x7B-Instruct-v0.1                                           | yuhuili/EAGLE-mixtral-instruct-8x7B      | 0.28B        |
| LLaMA3-Instruct 8B                                                   | yuhuili/EAGLE-LLaMA3-Instruct-8B         | 0.25B        |
| LLaMA3-Instruct 70B                                                  | yuhuili/EAGLE-LLaMA3-Instruct-70B        | 0.99B        |
| Qwen2-7B-Instruct                                                    | yuhuili/EAGLE-Qwen2-7B-Instruct          | 0.26B        |
| Qwen2-72B-Instruct                                                   | yuhuili/EAGLE-Qwen2-72B-Instruct         | 1.05B        |

## 推测解码的无损保证

在 vLLM 中，推测解码旨在提升推理效率的同时保持准确性。本节将推测解码的无损保证分为三个关键方面进行说明：

1. **理论无损性**  
   \- 推测解码采样在硬件数值精度范围内理论上是无损的。浮点误差可能导致输出分布出现轻微差异，相关讨论见论文[《Accelerating Large Language Model Decoding with Speculative Sampling》](https://arxiv.org/pdf/2302.01318)。

2. **算法无损性**  
   \- vLLM 的推测解码实现在算法上已验证为无损。关键验证测试包括：

    > - **拒绝采样器收敛性**：确保 vLLM 拒绝采样器的采样结果与目标分布一致。[查看测试代码](https://github.com/vllm-project/vllm/blob/47b65a550866c7ffbd076ecb74106714838ce7da/tests/samplers/test_rejection_sampler.py#L252)  
    > - **贪婪采样一致性**：确认使用推测解码的贪婪采样结果与不使用推测解码的贪婪采样结果一致。这验证了 vLLM 推测解码框架在与 vLLM 前向传播和拒绝采样器集成时提供无损保证。[tests/spec_decode/e2e](../../tests/spec_decode/e2e) 中的绝大多数测试均通过[此断言实现](https://github.com/vllm-project/vllm/blob/b67ae00cdbbe1a58ffc8ff170f0c8d79044a684a/tests/spec_decode/e2e/conftest.py#L291)验证该特性。

3. **vLLM Logprob 稳定性**  
   \- vLLM 目前**不保证** token 对数概率（logprobs）的稳定性。这可能导致同一请求在不同运行中产生不同输出。详情请参见 [FAQ](../usage/faq.md) 中的 *Can the output of a prompt vary across runs in vLLM?* 条目。

尽管 vLLM 力求在推测解码中确保无损性，但由于以下因素，使用与不使用推测解码时仍可能出现生成输出的差异：

- **浮点精度**：硬件数值精度的差异可能导致输出分布出现轻微偏差。
- **批处理大小与数值稳定性**：批处理大小的变化可能导致 logprobs 和输出概率的波动，可能源于批处理操作中的非确定性行为或数值不稳定性。

缓解策略请参见 [FAQ](../usage/faq.md) 中的 *Can the output of a prompt vary across runs in vLLM?* 条目。

## vLLM 贡献者资源

- [vLLM 中的推测解码：黑客指南](https://www.youtube.com/watch?v=9wNAgpX6z_4)
- [vLLM 中的前瞻调度是什么？](https://docs.google.com/document/d/1Z9TvqzzBPnh5WHcRwjvK2UEeFeq5zMZb5mFE8jR0HCs/edit#heading=h.1fjfb0donq5a)
- [批处理扩展相关信息](https://docs.google.com/document/d/1T-JaS2T1NRfdP51qzqpyakoCXxSXTtORppiwaj5asxA/edit#heading=h.kk7dq05lc6q8)
- [动态推测解码](https://github.com/vllm-project/vllm/issues/4565)