#### `--seed`

:   默认值：`0`

#### `--num-prompts`

:   要处理的提示数量。

:   默认值：`1000`

#### `--dataset-name`

:   可选值：`sharegpt`、`burstgpt`、`sonnet`、`random`、`random-mm`、`random-rerank`、`hf`、`custom`、`prefix_repetition`、`spec_bench`

:   用于基准测试的数据集名称。

:   默认值：`random`

#### `--no-stream`

:   不以流式模式加载数据集。

:   默认值：`False`

#### `--dataset-path`

:   sharegpt/sonnet 数据集的路径。如果使用 HF 数据集，则为 huggingface 数据集 ID。

#### `--no-oversample`

:   如果数据集的样本数量少于 num-prompts，则不进行过采样。

:   默认值：`False`

#### `--skip-chat-template`

:   跳过对支持聊天模板的数据集应用聊天模板。

:   默认值：`False`

#### `--disable-shuffle`

:   禁用数据集样本的随机打乱，以实现确定性排序。

:   默认值：`False`

#### `--label`

:   基准测试结果的前缀标签。如果未指定，则使用 `--backend` 的值作为标签。

#### `--backend`

:   可选值：`vllm`、`openai`、`openai-chat`、`openai-audio`、`openai-embeddings`、`openai-embeddings-chat`、`openai-embeddings-clip`、`openai-embeddings-vlm2vec`、`infinity-embeddings`、`infinity-embeddings-clip`、`vllm-rerank`

:   用于基准测试的后端或端点类型。

:   默认值：`openai`

#### `--base-url`

:   如果不使用 http 主机和端口，则为服务器或 API 的基础 URL。

#### `--host`

:   默认值：`127.0.0.1`

#### `--port`

:   默认值：`8000`

#### `--endpoint`

:   API 端点。

:   默认值：`/v1/completions`

#### `--header`

:   每次请求时要传递的键值对（例如：--header x-additional-info=0.3.3）。这些头部信息会覆盖每个后端的常量和通过环境变量设置的值，并会被其他参数（如请求 ID）覆盖。

#### `--max-concurrency`

:   最大并发请求数。这可用于模拟更高级别组件强制执行最大并发请求数的环境。虽然 --request-rate 参数控制请求发起的速率，但此参数将控制实际允许同时执行的请求数量。这意味着当两者结合使用时，如果服务器处理请求的速度不足以跟上，实际请求速率可能低于 --request-rate 指定的值。

#### `--model`

:   模型名称。如果未指定，将从服务器的 /v1/models 端点获取第一个模型。

#### `--input-len`

:   数据集的通用输入长度。映射到特定数据集的输入长度参数（例如：--random-input-len、--sonnet-input-len）。如果未指定，则使用数据集默认值。

#### `--output-len`

:   数据集的通用输出长度。映射到特定数据集的输出长度参数（例如：--random-output-len、--sonnet-output-len）。如果未指定，则使用数据集默认值。

#### `--tokenizer`

:   分词器的名称或路径，如果不使用默认分词器。

#### `--tokenizer-mode`

:   分词器模式：

            - "auto" 将优先为 Mistral 模型使用 `mistral_common` 中的分词器（如果可用），否则使用 "hf" 分词器。

            - "hf" 将使用快速分词器（如果可用）。

            - "slow" 将始终使用慢速分词器。

            - "mistral" 将始终使用 `mistral_common` 中的分词器。

            - "deepseek_v32" 将始终使用 `deepseek_v32` 中的分词器。

            - 其他自定义值可通过插件支持。

:   默认值：`auto`

#### `--use-beam-search`

:   默认值：`False`

#### `--logprobs`

:   每个 token 要计算并返回的 logprob 数量。如果未指定，则：(1) 如果禁用束搜索，则不计算 logprob，每个 token 返回一个虚拟 logprob；或 (2) 如果启用束搜索，则每个 token 计算 1 个 logprob。

#### `--request-rate`

:   每秒请求数。如果为 inf，则所有请求在时间 0 发送。否则，我们使用泊松过程或伽马分布来合成请求到达时间。

:   默认值：`inf`

#### `--burstiness`

:   请求生成的突发性因子。仅在 request_rate 不为 inf 时生效。默认值为 1，遵循泊松过程。否则，请求间隔遵循伽马分布。较低的突发性值（0 < burstiness < 1）会导致更突发的请求。较高的突发性值（burstiness > 1）会导致更均匀的请求到达。

:   默认值：`1.0`

#### `--trust-remote-code`

:   信任来自 huggingface 的远程代码

:   默认值：`False`

#### `--disable-tqdm`

:   指定以禁用 tqdm 进度条。

:   默认值：`False`

#### `--num-warmups`

:   预热请求数量。

:   默认值：`0`

#### `--profile`

:   使用 vLLM 性能分析。服务器上必须提供 --profiler-config。

:   默认值：`False`

#### `--save-result`

:   指定将基准测试结果保存到 JSON 文件

:   默认值：`False`

#### `--save-detailed`

:   保存结果时，是否包含每个请求的详细信息，如响应、错误、ttft、tpot 等。

:   默认值：`False`

#### `--append-result`

:   将基准测试结果追加到现有的 JSON 文件。

:   默认值：`False`

#### `--metadata`

:   键值对（例如：--metadata version=0.3.3 tp=1），用于保存本次运行的元数据到结果 JSON 文件中，以便记录。

#### `--result-dir`

:   指定保存基准测试 JSON 结果的目录。如果未指定，结果将保存在当前目录。

#### `--result-filename`

:   指定保存基准测试 JSON 结果的文件名。如果未指定，结果将保存为 {label}-{args.request_rate}qps-{base_model_id}-{current_dt}.json 格式。

#### `--ignore-eos`

:   发送基准测试请求时设置 ignore_eos 标志。警告：deepspeed_mii 和 tgi 不支持 ignore_eos。

:   默认值：`False`

#### `--percentile-metrics`

:   以逗号分隔的选定指标列表，用于报告百分位数。此参数指定要报告百分位数的指标。允许的指标名称为 "ttft"、"tpot"、"itl"、"e2el"。如果未指定，默认为生成式模型的 "ttft,tpot,itl" 和池化模型的 "e2el"。

#### `--metric-percentiles`

:   选定指标的百分位数列表，以逗号分隔。要报告第 25、50 和 75 百分位数，请使用 "25,50,75"。默认值为 "99"。使用 "--percentile-metrics" 选择指标。

:   默认值：`99`

#### `--goodput`

:   指定 goodput 的服务级别目标，格式为 "KEY:VALUE" 键值对，其中 key 是指标名称，value 以毫秒为单位。可以提供多个 "KEY:VALUE" 键值对，用空格分隔。允许的请求级别指标名称为 "ttft"、"tpot"、"e2el"。有关 goodput 定义的更多上下文，请参阅 DistServe 论文：https://arxiv.org/pdf/2401.09670 和博客：https://hao-ai-lab.github.io/blogs/distserve

#### `--request-id-prefix`

:   指定请求 ID 的前缀。

:   默认值：`bench-9c1b7dad-`

#### `--served-model-name`

:   API 中使用的模型名称。如果未指定，模型名称将与 `--model` 参数相同。

#### `--lora-modules`

:   启动服务器时传递的 LoRA 模块名称子集。对于每个请求，脚本会随机选择一个 LoRA 模块。

#### `--ramp-up-strategy`

:   可选值：`linear`、`exponential`

:   请求速率提升策略。这将用于在基准测试期间将请求速率从初始 RPS 提升到最终 RPS（由 --ramp-up-start-rps 和 --ramp-up-end-rps 指定）。

#### `--ramp-up-start-rps`

:   请求速率提升的起始请求速率（RPS）。使用 --ramp-up-strategy 时必须指定。

#### `--ramp-up-end-rps`

:   请求速率提升的结束请求速率（RPS）。使用 --ramp-up-strategy 时必须指定。

#### `--ready-check-timeout-sec`

:   等待端点准备就绪的最大时间（秒）。默认情况下将跳过就绪检查。

:   默认值：`0`

#### `--extra-body`

一个 JSON 字符串，表示要在每个请求中包含的额外 body 参数。  
示例：'{"chat_template_kwargs":{"enable_thinking":false}}'

### 自定义数据集选项

#### `--custom-output-len`

:   每个请求的输出 token 数量。除非设置为 -1，否则该值会覆盖从数据集加载的潜在输出长度。仅用于自定义数据集。

:   默认值：`256`

### spec bench 数据集选项

#### `--spec-bench-output-len`

:   每个请求的输出 token 数量，仅用于 spec bench 数据集。

:   默认值：`256`

#### `--spec-bench-category`

:   spec bench 数据集的类别。如果为 None，则使用所有类别。

### sonnet 数据集选项

#### `--sonnet-input-len`

:   每个请求的输入 token 数量，仅用于 sonnet 数据集。

:   默认值：`550`

#### `--sonnet-output-len`

:   每个请求的输出 token 数量，仅用于 sonnet 数据集。

:   默认值：`150`

#### `--sonnet-prefix-len`

:   每个请求的前缀 token 数量，仅用于 sonnet 数据集。

:   默认值：`200`

### sharegpt 数据集选项

#### `--sharegpt-output-len`

:   每个请求的输出长度。覆盖 ShareGPT 数据集中的输出长度。

### blazedit 数据集选项

#### `--blazedit-min-distance`

:   blazedit 数据集的最小距离。最小值：0，最大值：1.0

:   默认值：`0.0`

#### `--blazedit-max-distance`

:   blazedit 数据集的最大距离。最小值：0，最大值：1.0

:   默认值：`1.0`

### 随机数据集选项

#### `--random-input-len`

:   每个请求的输入 token 数量，仅用于随机采样。

:   默认值：`1024`

#### `--random-output-len`

:   每个请求的输出 token 数量，仅用于随机采样。

:   默认值：`128`

#### `--random-range-ratio`

:   采样输入/输出长度的范围比例，仅用于随机采样。必须在 [0, 1) 范围内，用于定义对称采样范围 [length * (1 - range_ratio), length * (1 + range_ratio)]。

:   默认值：`0.0`

#### `--random-prefix-len`

:   请求中随机上下文之前的固定前缀 token 数量。总输入长度为 `random-prefix-len` 与从 [input_len * (1 - range_ratio), input_len * (1 + range_ratio)] 采样的随机上下文长度之和。

:   默认值：`0`

#### `--random-batch-size`

:   随机采样的批处理大小。仅用于嵌入基准测试。

:   默认值：`1`

#### `--no-reranker`

:   模型是否原生支持重排序。仅用于重排序器基准测试。

:   默认值：`False`

### 随机多模态数据集选项（继承自随机数据集）

#### `--random-mm-base-items-per-request`

:   每个请求的多模态项目基础数量（random-mm）。实际每个请求的数量围绕该基础值使用 --random-mm-num-mm-items-range-ratio 进行采样。

:   默认值：`1`

#### `--random-mm-num-mm-items-range-ratio`

:   每个请求采样项目的范围比例 r（范围 [0, 1]）。我们从闭整数范围 [floor(n*(1-r)), ceil(n*(1+r))] 中均匀采样，其中 n 是每个请求的基础项目数。r=0 时保持固定；r=1 时允许 0 个项目。最大值被限制为 --random-mm-limit-mm-per-prompt 中各模态限制的总和。如果计算出的最小值超过最大值，则会引发错误。

:   默认值：`0.0`

#### `--random-mm-limit-mm-per-prompt`

:   每个请求附加项目的每模态硬性上限，例如 '{"image": 3, "video": 0}'。采样的每个请求项目数被限制为这些上限的总和。当某个模态达到上限时，其桶将被排除，概率会重新归一化。  
注：目前仅支持图像采样。

:   默认值：`{'image': 255, 'video': 1}`

#### `--random-mm-bucket-config`

:   桶配置是一个字典，将多模态项目采样配置映射到概率。  
目前支持两种模态：图像和视频。  
桶键是一个元组 (height, width, num_frames)，值是采样该特定项目的概率。  
示例：--random-mm-bucket-config {(256, 256, 1): 0.5, (720, 1280, 1): 0.4, (720, 1280, 16): 0.10}  
第一项：分辨率为 256x256 的图像，概率为 0.5  
第二项：分辨率为 720x1280 的图像，概率为 0.4  
第三项：分辨率为 720x1280 且 16 帧的视频，概率为 0.1  
注：如果概率总和不为 1，则会自动归一化。  
注二：目前仅支持图像采样。

:   默认值：`{(256, 256, 1): 0.5, (720, 1280, 1): 0.5, (720, 1280, 16): 0.0}`

### HuggingFace 数据集选项

#### `--hf-subset`

:   HuggingFace 数据集的子集。

#### `--hf-split`

:   HuggingFace 数据集的分割。

#### `--hf-name`

:   HuggingFace 上的数据集名称（例如 'lmarena-ai/VisionArena-Chat'）。如果 dataset-path 是本地路径，请指定此参数。

#### `--hf-output-len`

:   每个请求的输出长度。覆盖采样的 HuggingFace 数据集中的输出长度。

### 前缀重复数据集选项

#### `--prefix-repetition-prefix-len`

:   每个请求的前缀 token 数量，仅用于前缀重复数据集。

:   默认值：`256`

#### `--prefix-repetition-suffix-len`

:   每个请求的后缀 token 数量，仅用于前缀重复数据集。总输入长度为 prefix_len + suffix_len。

:   默认值：`256`

#### `--prefix-repetition-num-prefixes`

:   要生成的前缀数量，仅用于前缀重复数据集。每个前缀的提示数为 num_requests // num_prefixes。

:   默认值：`10`

#### `--prefix-repetition-output-len`

:   每个请求的输出 token 数量，仅用于前缀重复数据集。

:   默认值：`128`

### 采样参数

#### `--top-p`

:   Top-p 采样参数。仅对 OpenAI 兼容后端生效。

#### `--top-k`

:   Top-k 采样参数。仅对 OpenAI 兼容后端生效。

#### `--min-p`

:   Min-p 采样参数。仅对 OpenAI 兼容后端生效。

#### `--temperature`

:   温度采样参数。仅对 OpenAI 兼容后端生效。

#### `--frequency-penalty`

:   频率惩罚采样参数。仅对 OpenAI 兼容后端生效。

#### `--presence-penalty`

:   存在惩罚采样参数。仅对 OpenAI 兼容后端生效。

#### `--repetition-penalty`

:   重复惩罚采样参数。仅对 OpenAI 兼容后端生效。