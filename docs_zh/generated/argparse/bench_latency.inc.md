---
title: vLLM 命令行参数
description: vLLM 命令行参数详细说明
---

#### `--input-len`

:   默认值: `32`

#### `--output-len`

:   默认值: `128`

#### `--batch-size`

:   默认值: `8`

#### `--n`

:   每个提示生成的序列数量。

:   默认值: `1`

#### `--use-beam-search`

:   默认值: `False`

#### `--num-iters-warmup`

:   用于预热的迭代次数。

:   默认值: `10`

#### `--num-iters`

:   要运行的迭代次数。

:   默认值: `30`

#### `--profile`

:   对单个批次的生成过程进行性能分析

:   默认值: `False`

#### `--output-json`

:   保存延迟结果的 JSON 文件路径。

#### `--disable-detokenize`

:   不对响应进行去标记化（即不在延迟测量中包含去标记化时间）

:   默认值: `False`

#### `--disable-log-stats`

:   禁用统计日志记录。

:   默认值: `False`

#### `--aggregate-engine-logging`

:   在使用数据并行时记录聚合统计信息而非每个引擎的统计信息。

:   默认值: `False`


### ModelConfig

模型的配置。

#### `--model`

:   要使用的 Hugging Face 模型的名称或路径。当未指定 `served_model_name` 时，它也用作指标输出中 `model_name` 标签的内容。

:   默认值: `Qwen/Qwen3-0.6B`

#### `--runner`

:   可选值: `auto`, `draft`, `generate`, `pooling`

:   要使用的模型运行器类型。每个 vLLM 实例只支持一个模型运行器，即使同一个模型可以用于多种类型。

:   默认值: `auto`

#### `--convert`

:   可选值: `auto`, `classify`, `embed`, `mm_encoder_only`, `none`, `reward`

:   使用 [vllm.model_executor.models.adapters][] 中定义的适配器转换模型。最常见的用例是将文本生成模型适配为用于池化任务。

:   默认值: `auto`

#### `--tokenizer`

:   要使用的 Hugging Face 分词器的名称或路径。如果未指定，将使用模型名称或路径。

#### `--tokenizer-mode`

:   可选值: `auto`, `deepseek_v32`, `hf`, `mistral`, `slow`

:   分词器模式：

    - "auto" 将在 Mistral 模型可用时使用 `mistral_common` 中的分词器，否则将使用 "hf" 分词器。

    - "hf" 将在可用时使用快速分词器。

    - "slow" 将始终使用慢速分词器。

    - "mistral" 将始终使用 `mistral_common` 中的分词器。

    - "deepseek_v32" 将始终使用 `deepseek_v32` 中的分词器。

    - 其他自定义值可以通过插件支持。

:   默认值: `auto`

#### `--trust-remote-code`, `--no-trust-remote-code`

:   在下载模型和分词器时信任远程代码（例如，来自 HuggingFace）。

:   默认值: `False`

#### `--dtype`

:   可选值: `auto`, `bfloat16`, `float`, `float16`, `float32`, `half`

:   模型权重和激活的数据类型：

    - "auto" 将对 FP32 和 FP16 模型使用 FP16 精度，对 BF16 模型使用 BF16 精度。

    - "half" 用于 FP16。推荐用于 AWQ 量化。

    - "float16" 与 "half" 相同。

    - "bfloat16" 在精度和范围之间取得平衡。

    - "float" 是 FP32 精度的简写。

    - "float32" 用于 FP32 精度。

:   默认值: `auto`

#### `--seed`

:   用于可重复性的随机种子。

    我们必须设置全局种子，否则，
    不同的张量并行工作进程将采样不同的标记，
    导致结果不一致。

:   默认值: `0`

#### `--hf-config-path`

:   要使用的 Hugging Face 配置的名称或路径。如果未指定，将使用模型名称或路径。

#### `--allowed-local-media-path`

:   允许 API 请求从服务器文件系统指定的目录读取本地图像或视频。这是一个安全风险。只应在受信任的环境中启用。

:   默认值: `""`

#### `--allowed-media-domains`

:   如果设置，只有属于此域的媒体 URL 可用于多模态输入。

#### `--revision`

:   要使用的特定模型版本。它可以是分支名称、标签名称或提交 ID。如果未指定，将使用默认版本。

#### `--code-revision`

:   要在 Hugging Face Hub 上使用的模型代码的特定版本。
    它可以是分支名称、标签名称或提交 ID。如果未指定，将
    使用默认版本。

#### `--tokenizer-revision`

:   要在 Hugging Face Hub 上使用的分词器的特定版本。
    它可以是分支名称、标签名称或提交 ID。如果未指定，将
    使用默认版本。

#### `--max-model-len`

:   模型上下文长度（提示和输出）。如果未指定，将从模型配置中自动派生。

    通过 `--max-model-len` 传递时，支持人类可读格式中的 k/m/g/K/M/G。示例：

    - 1k -> 1000

    - 1K -> 1024

    - 25.6k -> 25,600

    - -1 或 'auto' -> 自动选择适合 GPU 内存的最大模型长度。如果适合，将使用模型的最大上下文长度，否则将找到可以容纳的最大长度。

    解析人类可读的整数，如 '1k'、'2M' 等。
    包括带十进制乘数的小数值。
    还接受 -1 或 'auto' 作为自动检测的特殊值。

    示例：
    - '1k' -> 1,000
    - '1K' -> 1,024
    - '25.6k' -> 25,600
    - '-1' 或 'auto' -> -1（自动检测的特殊值）


#### `--quantization`, `-q`

:   用于量化权重的方法。如果为 `None`，我们首先检查
    模型配置文件中的 `quantization_config` 属性。如果该属性为
    `None`，我们假设模型权重未量化并使用 `dtype` 来
    确定权重的数据类型。

#### `--allow-deprecated-quantization`, `--no-allow-deprecated-quantization`

:   是否允许使用已弃用的量化方法。

:   默认值: `False`

#### `--enforce-eager`, `--no-enforce-eager`

:   是否始终使用急切模式 PyTorch。如果为 True，我们将禁用 CUDA
    图并始终在急切模式下执行模型。如果为 False，我们将使用
    CUDA 图和急切执行的混合模式以获得最大性能和
    灵活性。

:   默认值: `False`

#### `--enable-return-routed-experts`, `--no-enable-return-routed-experts`

:   是否返回路由专家。

:   默认值: `False`

#### `--max-logprobs`

:   当在 `SamplingParams` 中指定 `logprobs` 时返回的最大对数概率数。默认值来自
    OpenAI Chat Completions API 的默认值。-1 表示没有限制，即允许返回所有（output_length *
    vocab_size）对数概率，这可能导致内存不足。

:   默认值: `20`

#### `--logprobs-mode`

:   可选值: `processed_logits`, `processed_logprobs`, `raw_logits`, `raw_logprobs`

:   指示在 logprobs 和 prompt_logprobs 中返回的内容。
    支持的模式：
    1) raw_logprobs, 2) processed_logprobs, 3) raw_logits, 4) processed_logits。
    Raw 表示应用任何 logits 处理器之前的值，如不良词汇。
    Processed 表示应用所有处理器后的值，包括
    温度和 top_k/top_p。

:   默认值: `raw_logprobs`

#### `--disable-sliding-window`, `--no-disable-sliding-window`

:   是否禁用滑动窗口。如果为 True，我们将禁用模型的滑动
    窗口功能，限制为滑动窗口大小。如果模型不支持滑动窗口，则忽略此参数。

:   默认值: `False`

#### `--disable-cascade-attn`, `--no-disable-cascade-attn`

:   为 V1 禁用级联注意力。虽然级联注意力不会
    改变数学正确性，但禁用它可能有助于
    防止潜在的数值问题。请注意，即使设置为
    False，级联注意力也只在启发式方法表明
    有益时才会使用。

:   默认值: `False`

#### `--skip-tokenizer-init`, `--no-skip-tokenizer-init`

:   跳过分词器和去分词器的初始化。期望从输入中获得有效的
    `prompt_token_ids` 和 `None` 作为提示。生成的
    输出将包含标记 ID。

:   默认值: `False`

#### `--enable-prompt-embeds`, `--no-enable-prompt-embeds`

:   如果为 `True`，则启用通过 `prompt_embeds` 键传递文本嵌入作为输入。

    警告：如果传递了错误形状的嵌入，vLLM 引擎可能会崩溃。
    仅对受信任的用户启用此标志！

:   默认值：`False`

#### `--served-model-name`

:   API 中使用的模型名称。如果提供了多个名称，服务器将响应任何提供的名称。
    响应中 model 字段的模型名称将是此列表中的第一个名称。如果未指定，
    模型名称将与 `--model` 参数相同。注意，此名称也将在 prometheus 指标
    的 `model_name` 标签内容中使用，如果提供了多个名称，指标标签将采用
    第一个名称。

#### `--config-format`

:   可选值：`auto`, `hf`, `mistral`

:   要加载的模型配置格式：

    - "auto" 将尝试以 mistral 格式加载配置后，如果可用则尝试以 hf 格式加载配置。

    - "hf" 将以 hf 格式加载配置。

    - "mistral" 将以 mistral 格式加载配置。

:   默认值：`auto`

#### `--hf-token`

:   用于远程文件的 HTTP bearer 授权的令牌。如果为
    `True`，将使用运行 `huggingface-cli login` 时生成的令牌
    （存储在 `~/.huggingface` 中）。

#### `--hf-overrides`

:   如果是字典，则包含要转发到 Hugging Face 配置的参数。
    如果是可调用对象，则调用它来更新 HuggingFace 配置。

:   默认值：`{}`

#### `--pooler-config`

:   Pooler 配置，控制 pooling 模型中输出池化的行为。

    应该是有效的 JSON 字符串或单独传递的 JSON 键。

#### `--logits-processor-pattern`

:   可选的正则表达式模式，指定可以使用 `logits_processors` 额外完成参数
    传递的有效 logits 处理器限定名称。默认为 `None`，这将不允许任何处理器。

#### `--generation-config`

:   生成配置的文件夹路径。默认为 `"auto"`，生成配置将从模型路径加载。
    如果设置为 `"vllm"`，则不加载生成配置，将使用 vLLM 默认值。
    如果设置为文件夹路径，则从指定的文件夹路径加载生成配置。
    如果在生成配置中指定了 `max_new_tokens`，则它将设置服务器对所有请求
    的输出 token 数量的全局限制。

:   默认值：`auto`

#### `--override-generation-config`

:   覆盖或设置生成配置。例如 `{"temperature": 0.5}`。如果与
    `--generation-config auto` 一起使用，覆盖参数将与模型的默认配置合并。
    如果与 `--generation-config vllm` 一起使用，则仅使用覆盖参数。

    应该是有效的 JSON 字符串或单独传递的 JSON 键。

:   默认值：`{}`

#### `--enable-sleep-mode`, `--no-enable-sleep-mode`

:   为引擎启用睡眠模式（仅支持 cuda 和 hip 平台）。

:   默认值：`False`

#### `--model-impl`

:   可选值：`auto`, `terratorch`, `transformers`, `vllm`

:   使用哪个模型实现：

    - "auto" 将尝试使用 vLLM 实现（如果存在），如果没有可用的 vLLM 实现，
    则回退到 Transformers 实现。

    - "vllm" 将使用 vLLM 模型实现。

    - "transformers" 将使用 Transformers 模型实现。

    - "terratorch" 将使用 TerraTorch 模型实现。

:   默认值：`auto`

#### `--override-attention-dtype`

:   覆盖注意力机制的 dtype

#### `--logits-processors`

:   一个或多个 logits 处理器的完全限定类名或类定义

#### `--io-processor-plugin`

:   在模型启动时加载的 IOProcessor 插件名称


### LoadConfig

加载模型权重的配置。

#### `--load-format`

:   要加载的模型权重格式：

    - "auto" 将尝试以 safetensors 格式加载权重，如果 safetensors 格式不可用，
    则回退到 pytorch bin 格式。

    - "pt" 将以 pytorch bin 格式加载权重。

    - "safetensors" 将以 safetensors 格式加载权重。

    - "npcache" 将以 pytorch 格式加载权重并存储 numpy 缓存以加速加载。

    - "dummy" 将用随机值初始化权重，主要用于性能分析。

    - "tensorizer" 将使用 CoreWeave 的 tensorizer 库进行快速权重加载。
    请参阅示例部分中的 Tensorize vLLM Model 脚本了解更多信息。

    - "runai_streamer" 将使用 Run:ai Model Streamer 加载 Safetensors 权重。

    - "runai_streamer_sharded" 将使用 Run:ai Model Streamer 从预分片的检查点文件加载权重。

    - "bitsandbytes" 将使用 bitsandbytes 量化加载权重。

    - "sharded_state" 将从预分片的检查点文件加载权重，支持高效的张量并行模型加载。

    - "gguf" 将从 GGUF 格式文件加载权重（详情请参见
    https://github.com/ggml-org/ggml/blob/master/docs/gguf.md）。

    - "mistral" 将从 Mistral 模型使用的合并 safetensors 文件加载权重。
    - 其他自定义值可通过插件支持。

:   默认值：`auto`

#### `--download-dir`

:   下载和加载权重的目录，默认为 Hugging Face 的默认缓存目录。

#### `--safetensors-load-strategy`

:   指定 safetensors 权重的加载策略。
    - "lazy"（默认）：权重从文件内存映射。这启用了按需加载，对于本地存储的模型非常高效。
    - "eager"：在加载前将整个文件读入 CPU 内存。这推荐用于网络文件系统上的模型（例如 Lustre, NFS）
      因为它避免了低效的随机读取，显著加速模型初始化。但是，它使用更多的 CPU RAM。
    - "torchao"：权重预先加载，然后重构为 torchao 张量子类。当检查点使用 torchao 量化并使用 safetensors 保存时使用。
      需要 torchao >= 0.14.0

:   默认值：`lazy`

#### `--model-loader-extra-config`

:   模型加载器的额外配置。这将传递给与所选 load_format 对应的模型加载器。

:   默认值：`{}`

#### `--ignore-patterns`

:   加载模型时要忽略的模式列表。默认为
    "original/**/*" 以避免重复加载 llama 的检查点。

:   默认值：`['original/**/*']`

#### `--use-tqdm-on-load`, `--no-use-tqdm-on-load`

:   加载模型权重时是否启用 tqdm 显示进度条。

:   默认值：`True`

#### `--pt-load-map-location`

:   pt_load_map_location：加载 pytorch 检查点的映射位置，以支持加载只能在特定设备上加载的检查点，如
    "cuda"，这等同于 {"": "cuda"}。另一种支持的格式是不同设备之间的映射，如从 GPU 1 到 GPU 0：
    {"cuda:1": "cuda:0"}。请注意，当从命令行传递时，字典中的字符串需要双引号以进行 json 解析。有关更多详细信息，
    请参见 https://pytorch.org/docs/stable/generated/torch.load.html 中 `map_location` 的原始文档

:   默认值：`cpu`


### AttentionConfig

vLLM 中注意力机制的配置。

#### `--attention-backend`

:   要使用的注意力后端。如果为 None，将自动选择。


### StructuredOutputsConfig

包含引擎结构化输出配置的数据类。

#### `--reasoning-parser`

:   根据使用的模型选择推理解析器。
    这用于将推理内容解析为 OpenAI API 格式。

:   默认值：`""`

#### `--reasoning-parser-plugin`

:   可以动态加载和注册的动态推理解析器插件的路径。

:   默认值：`""`


### ParallelConfig

分布式执行的配置。

#### `--distributed-executor-backend`

:   可选值：`external_launcher`, `mp`, `ray`, `uni`

---
title: 分布式参数
---

#### `--distributed-executor-backend`

:   用于分布式模型工作进程的后端，可以是 "ray" 或 "mp"（multiprocessing）。如果 pipeline_parallel_size 和 tensor_parallel_size 的乘积小于或等于可用的 GPU 数量，将使用 "mp" 以保持在单个主机上处理。否则，将引发错误。要使用 "mp"，您还必须设置 nnodes，要使用 "ray"，您必须手动将 distributed_executor_backend 设置为 "ray"。

    请注意，TPU 仅支持 Ray 进行分布式推理。

#### `--pipeline-parallel-size`, `-pp`

:   流水线并行组的数量。

:   默认值: `1`

#### `--master-addr`

:   当 distributed_executor_backend 为 mp 时，用于多节点分布式推理的分布式主地址。

:   默认值: `127.0.0.1`

#### `--master-port`

:   当 distributed_executor_backend 为 mp 时，用于多节点分布式推理的分布式主端口。

:   默认值: `29501`

#### `--nnodes`, `-n`

:   当 distributed_executor_backend 为 mp 时，用于多节点分布式推理的节点数量。

:   默认值: `1`

#### `--node-rank`, `-r`

:   当 distributed_executor_backend 为 mp 时，用于多节点分布式推理的分布式节点排名。

:   默认值: `0`

#### `--tensor-parallel-size`, `-tp`

:   张量并行组的数量。

:   默认值: `1`

#### `--decode-context-parallel-size`, `-dcp`

:   解码上下文并行组的数量，因为世界大小不会因 dcp 而改变，它只是重用 TP 组的 GPU，并且 tp_size 需要能被 dcp_size 整除。

:   默认值: `1`

#### `--dcp-kv-cache-interleave-size`

:   使用 DCP 时 kv_cache 存储的交错大小。
    dcp_kv_cache_interleave_size 已被 cp_kv_cache_interleave_size 替换，
    并将在 PCP 完全支持时弃用。

:   默认值: `1`

#### `--cp-kv-cache-interleave-size`

:   使用 DCP 或 PCP 时 kv_cache 存储的交错大小。
    对于 `total_cp_rank = pcp_rank * dcp_world_size + dcp_rank`，
        和 `total_cp_world_size = pcp_world_size * dcp_world_size`。
    在 total_cp_rank i 上存储 interleave_size 个令牌，
    然后在 total_cp_rank i+1 上存储下一个 interleave_size 个令牌。
    Interleave_size=1：令牌级对齐，其中令牌 `i` 存储在
        total_cp_rank `i %% total_cp_world_size` 上。
    Interleave_size=block_size：块级对齐，其中令牌首先
        填充到前面的排名。只有在（排名 i，块 j）完全占用后，
        令牌才会存储在（排名 i+1，块 j）中。
    Block_size 应该大于或等于 cp_kv_cache_interleave_size。
    Block_size 应该能被 cp_kv_cache_interleave_size 整除。

:   默认值: `1`

#### `--prefill-context-parallel-size`, `-pcp`

:   预填充上下文并行组的数量。

:   默认值: `1`

#### `--data-parallel-size`, `-dp`

:   数据并行组的数量。MoE 层将根据张量并行大小和数据并行大小的乘积进行分片。

:   默认值: `1`

#### `--data-parallel-rank`, `-dpn`

:   此实例的数据并行排名。设置时，启用外部负载均衡器模式。

#### `--data-parallel-start-rank`, `-dpr`

:   次要节点的起始数据并行排名。

#### `--data-parallel-size-local`, `-dpl`

:   在此节点上运行的数据并行副本数量。

#### `--data-parallel-address`, `-dpa`

:   数据并行集群主节点的地址。

#### `--data-parallel-rpc-port`, `-dpp`

:   数据并行 RPC 通信的端口。

#### `--data-parallel-backend`, `-dpb`

:   数据并行的后端，可以是 "mp" 或 "ray"。

:   默认值: `mp`

#### `--data-parallel-hybrid-lb`, `--no-data-parallel-hybrid-lb`, `-dph`

:   是否使用"混合"DP LB 模式。仅适用于在线服务
    和 data_parallel_size > 0 的情况。这使得可以在"每节点"基础上运行 AsyncLLM
    和 API 服务器，其中 vLLM 在本地数据并行排名之间进行负载均衡，
    但外部 LB 在 vLLM 节点/副本之间进行负载均衡。与
    --data-parallel-start-rank 明确配合设置。

:   默认值: `False`

#### `--data-parallel-external-lb`, `--no-data-parallel-external-lb`, `-dpe`

:   是否使用"外部"DP LB 模式。仅适用于在线服务
    和 data_parallel_size > 0 的情况。这对于 Kubernetes 中的"每个排名一个 pod"
    宽 EP 设置很有用。当 --data-parallel-rank
    明确提供给 vllm serve 时隐式设置。

:   默认值: `False`

#### `--enable-expert-parallel`, `--no-enable-expert-parallel`, `-ep`

:   对 MoE 层使用专家并行而不是张量并行。

:   默认值: `False`

#### `--all2all-backend`

:   可选值: `allgather_reducescatter`, `deepep_high_throughput`, `deepep_low_latency`, `flashinfer_all2allv`, `mori`, `naive`, `pplx`

:   MoE 专家并行通信的 All2All 后端。可用选项：

    - "naive": 使用广播的朴素 all2all 实现

    - "allgather_reducescatter": 基于 allgather 和 reducescatter 的 All2all

    - "pplx": 使用 pplx 内核

    - "deepep_high_throughput": 使用 deepep 高吞吐量内核

    - "deepep_low_latency": 使用 deepep 低延迟内核

    - "mori": 使用 mori 内核

    - "flashinfer_all2allv": 为 mnnvl 使用 flashinfer alltoallv 内核

:   默认值: `allgather_reducescatter`

#### `--enable-dbo`, `--no-enable-dbo`

:   为模型执行器启用双重批次重叠。

:   默认值: `False`

#### `--ubatch-size`

:   ubatch 大小的数量。

:   默认值: `0`

#### `--dbo-decode-token-threshold`

:   仅包含解码的批次的双重批次重叠阈值。
    如果请求中的令牌数量大于此阈值，
    将使用微批次。否则，请求将在单个批次中处理。

:   默认值: `32`

#### `--dbo-prefill-token-threshold`

:   包含一个或多个预填充的批次的双重批次重叠阈值。如果请求中的令牌数量大于此
    阈值，将使用微批次。否则，请求将在单个批次中处理。

:   默认值: `512`

#### `--disable-nccl-for-dp-synchronization`, `--no-disable-nccl-for-dp-synchronization`

:   强制 vllm/v1/worker/dp_utils.py 中的 dp 同步逻辑
    使用 Gloo 而不是 NCCL 进行 all reduce。

    默认情况下，当启用异步调度时为 True，否则为 False。

#### `--enable-eplb`, `--no-enable-eplb`

:   为 MoE 层启用专家并行负载均衡。

:   默认值: `False`

#### `--eplb-config`

:   专家并行配置。

    应该是有效的 JSON 字符串或单独传递的 JSON 键。

:   默认值: `EPLBConfig(window_size=1000, step_interval=3000, num_redundant_experts=0, log_balancedness=False, log_balancedness_interval=1, use_async=False, policy='default')`

#### `--expert-placement-strategy`

:   可选值: `linear`, `round_robin`

:   MoE 层的专家放置策略：

    - "linear": 专家以连续方式放置。例如，有 4
      个专家和 2 个排名时，排名 0 将有专家 [0, 1]，排名 1 将有
      专家 [2, 3]。

    - "round_robin": 专家以循环方式放置。例如，
      有 4 个专家和 2 个排名时，排名 0 将有专家 [0, 2]，排名 1
      将有专家 [1, 3]。这种策略可以帮助改善
      没有冗余专家的分组专家模型的负载均衡。

:   默认值: `linear`

#### `--max-parallel-loading-workers`

:   在多个批次中顺序加载模型时的最大并行加载工作进程数。以避免在使用张量
    并行和大模型时出现 RAM OOM。

#### `--ray-workers-use-nsight`, `--no-ray-workers-use-nsight`

:   是否使用 nsight 分析 Ray 工作进程，请参见 https://docs.ray.io/en/latest/ray-observability/user-guides/profiling.html#profiling-nsight-profiler。

:   默认值: `False`

#### `--disable-custom-all-reduce`, `--no-disable-custom-all-reduce`

:   禁用自定义 all-reduce 内核并回退到 NCCL。

:   默认值: `False`

#### `--worker-cls`

---
title: "vLLM 配置"
description: "vLLM 配置参数说明"
---

:   要使用的 worker 类的完整名称。如果为 "auto"，worker 类将根据平台确定。

:   默认值: `auto`

#### `--worker-extension-cls`

:   要使用的 worker 扩展类的完整名称。worker 扩展类会被 worker 类动态继承。这用于向 worker 类注入新属性和方法，以便在 collective_rpc 调用中使用。

:   默认值: `""`


### CacheConfig

KV 缓存的配置。

#### `--block-size`

:   可选值: `1`, `8`, `16`, `32`, `64`, `128`, `256`

:   连续缓存块的大小（以 token 数量计）。在 CUDA 设备上，仅支持最大为 32 的块大小。

    此配置没有静态默认值。如果用户未指定，将在 `Platform.check_and_update_config()` 中基于当前平台设置。

#### `--gpu-memory-utilization`

:   用于模型执行器的 GPU 内存比例，范围从 0 到 1。例如，值为 0.5 表示 50%% 的 GPU 内存利用率。如果未指定，将使用默认值 0.9。这是每个实例的限制，仅适用于当前 vLLM 实例。如果您在同一个 GPU 上运行另一个 vLLM 实例，这并不重要。例如，如果您在同一个 GPU 上运行两个 vLLM 实例，可以为每个实例设置 GPU 内存利用率为 0.5。

:   默认值: `0.9`

#### `--kv-cache-memory-bytes`

:   每个 GPU 的 KV 缓存大小（以字节为单位）。默认情况下，这被设置为 None，vllm 可以根据 gpu_memory_utilization 自动推断 kv 缓存大小。但是，用户可能希望手动指定 kv 缓存内存大小。与使用 gpu_memory_utilization 相比，kv_cache_memory_bytes 允许更细粒度地控制内存使用量。请注意，kv_cache_memory_bytes（当不为 None 时）会忽略 gpu_memory_utilization

    解析人类可读的整数，如 '1k'、'2M' 等。
    包括带有十进制乘数的小数值。

    示例:
    - '1k' -> 1,000
    - '1K' -> 1,024
    - '25.6k' -> 25,600


#### `--swap-space`

:   每个 GPU 的 CPU 交换空间大小（以 GiB 为单位）。

:   默认值: `4`

#### `--kv-cache-dtype`

:   可选值: `auto`, `bfloat16`, `fp8`, `fp8_ds_mla`, `fp8_e4m3`, `fp8_e5m2`, `fp8_inc`

:   kv 缓存存储的数据类型。如果为 "auto"，将使用模型数据类型。
    CUDA 11.8+ 支持 fp8 (=fp8_e4m3) 和 fp8_e5m2。ROCm (AMD GPU) 支持
    fp8 (=fp8_e4m3)。Intel Gaudi (HPU) 支持 fp8 (使用 fp8_inc)。
    某些模型（即 DeepSeekV3.2）默认使用 fp8，设置为 bfloat16 以使用
    bfloat16，对于不默认使用 fp8 的模型，这是一个无效选项。

:   默认值: `auto`

#### `--num-gpu-blocks-override`

:   要使用的 GPU 块数量。如果指定，这将覆盖已配置的 `num_gpu_blocks`。
    如果为 `None` 则不执行任何操作。用于测试抢占。

#### `--enable-prefix-caching`, `--no-enable-prefix-caching`

:   是否启用前缀缓存。

:   默认值: `False`

#### `--prefix-caching-hash-algo`

:   可选值: `sha256`, `sha256_cbor`, `xxhash`, `xxhash_cbor`

:   设置前缀缓存的哈希算法：

    - "sha256" 在哈希之前使用 Pickle 进行对象序列化。这是当前的默认值，因为 SHA256 是避免潜在哈希冲突的最安全选择。

    - "sha256_cbor" 提供可重现的、跨语言兼容的哈希。它使用规范 CBOR 序列化对象并用 SHA-256 哈希它们。

    - "xxhash" 使用 Pickle 序列化和 xxHash (128-bit) 进行更快的非加密哈希。需要可选的 ``xxhash`` 包。
    重要提示：使用不被认为是加密安全的哈希算法理论上会增加哈希冲突的风险，
    这可能导致未定义行为，甚至在多租户环境中泄露私人信息。即使冲突仍然非常不可能，但在启用此功能之前，
    重要的是要考虑您的安全风险承受能力与性能收益。

    - "xxhash_cbor" 结合规范 CBOR 序列化和 xxHash 进行可重现的哈希。需要可选的 ``xxhash`` 包。

:   默认值: `sha256`

#### `--cpu-offload-gb`

:   每个 GPU 要卸载到 CPU 的空间（以 GiB 为单位）。默认为 0，表示不进行卸载。直观地说，这个参数可以看作是增加 GPU 内存大小的虚拟方式。例如，如果您有一个 24 GB 的 GPU 并将此值设置为 10，虚拟上您可以将其视为 34 GB 的 GPU。然后您可以加载一个 BF16 权重的 13B 模型，这至少需要 26GB GPU 内存。请注意，这需要快速的 CPU-GPU 互连，因为部分模型在每次模型前向传递时都会从 CPU 内存动态加载到 GPU 内存。

:   默认值: `0`

#### `--calculate-kv-scales`, `--no-calculate-kv-scales`

:   当 kv_cache_dtype 为 fp8 时，这启用了 `k_scale` 和 `v_scale` 的动态计算。如果为 `False`，如果可用，将从模型检查点加载缩放值。否则，缩放值将默认为 1.0。

:   默认值: `False`

#### `--kv-sharing-fast-prefill`, `--no-kv-sharing-fast-prefill`

:   此功能正在开发中，启用此标志时目前不会进行预填充优化。

    在某些 KV 共享设置中，例如 YOCO (https://arxiv.org/abs/2405.05254)，
    某些层可以跳过与预填充对应的 token。此标志启用对符合条件的层的注意元数据进行覆盖，
    以使用实现此优化所需的元数据（例如在某些模型中，如 Gemma3n）

:   默认值: `False`

#### `--mamba-cache-dtype`

:   可选值: `auto`, `float16`, `float32`

:   用于 Mamba 缓存的数据类型（卷积和 ssm 状态）。如果设置为 'auto'，数据类型将从模型配置中推断。

:   默认值: `auto`

#### `--mamba-ssm-cache-dtype`

:   可选值: `auto`, `float16`, `float32`

:   用于 Mamba 缓存的数据类型（仅 ssm 状态，卷积状态仍将由 mamba_cache_dtype 控制）。如果设置为 'auto'，ssm 状态的数据类型将由 mamba_cache_dtype 确定。

:   默认值: `auto`

#### `--mamba-block-size`

:   Mamba 缓存的连续缓存块大小（以 token 数量计）。
    仅当启用前缀缓存时才能设置。
    值必须是 8 的倍数以与 causal_conv1d 内核对齐。

#### `--mamba-cache-mode`

:   可选值: `align`, `all`, `none`

:   Mamba 层的缓存策略。
    - "none": 在禁用前缀缓存时设置。
    - "all": 在位置 i * block_size 处缓存所有 token 的 mamba 状态。这是
           启用前缀缓存时的默认行为（对于支持它的模型）。
    - "align": 仅在调度器步骤的最后一个 token 和
           位于位置 i * block_size 的 token 处缓存 mamba 状态。

:   默认值: `none`

#### `--kv-offloading-size`

:   KV 缓存卸载缓冲区的大小（以 GiB 为单位）。当 TP > 1 时，这是跨所有 TP 等级的总缓冲区大小。默认情况下，这被设置为 None，这意味着不启用 KV 卸载。设置后，vLLM 将使用 kv_offloading_backend 启用 KV 缓存到 CPU 的卸载。

#### `--kv-offloading-backend`

:   可选值: `lmcache`, `native`

:   用于 KV 缓存卸载的后端。支持的后端包括
    'native' (vLLM 本地 CPU 卸载)，'lmcache'。
    仅当设置 kv_offloading_size 时才激活 KV 卸载。

:   默认值: `native`


### MultiModalConfig

控制多模态模型的行为。

#### `--limit-mm-per-prompt`

:   每个模态每个提示允许的最大输入项目和选项数量。
    每个模态默认为 999。

    传统格式（仅计数）:
        {"image": 16, "video": 2}

    可配置格式（带选项）:
        {"video": {"count": 1, "num_frames": 32, "width": 512, "height": 512}, 
        "image": {"count": 5, "width": 512, "height": 512}}

---
title: vLLM 命令行参数
description: vLLM 命令行参数的完整列表
---

## 多模态配置

### `--mm-processor-model`

:   用于处理多模态输入的模型名称或路径。如果未指定，将使用主模型路径。

### `--mm-processor-model-override`

:   用于覆盖多模态处理器模型的模型名称或路径。如果未指定，将使用主模型路径。

### `--image-input-type`

:   可能的选择：`pixel_values`, `image_features`

:   指定图像输入的类型。如果为 `pixel_values`，则将原始图像像素值传递给模型。如果为 `image_features`，则将预计算的图像特征传递给模型。

### `--video-input-type`

:   可能的选择：`pixel_values`, `video_features`

:   指定视频输入的类型。如果为 `pixel_values`，则将原始视频像素值传递给模型。如果为 `video_features`，则将预计算的视频特征传递给模型。

### `--image-token-id`

:   用于表示图像占位符的 token ID。如果未指定，将自动推断。

### `--video-token-id`

:   用于表示视频占位符的 token ID。如果未指定，将自动推断。

### `--image-input-shape`

:   指定图像输入的形状，格式为 `{"height": 384, "width": 512}`。

    应为有效的 JSON 字符串或单独传递的 JSON 键。

:   默认值：`{}`

### `--image-feature-size`

:   指定图像特征的大小。如果未指定，将自动推断。

### `--video-input-shape`

:   指定视频输入的形状，格式为 `{"num_frames": 16, "height": 384, "width": 512}`。

    应为有效的 JSON 字符串或单独传递的 JSON 键。

:   默认值：`{}`

### `--video-feature-size`

:   指定视频特征的大小。如果未指定，将自动推断。

### `--mm-cache-preprocessor`, `--no-mm-cache-preprocessor`

:   如果为 `True`，将缓存多模态预处理器的输出。

:   默认值：`False`

### `--mm-embedder-model`, `--mm-embedder-model-path`

:   用于嵌入多模态数据的模型名称或路径。如果未指定，将使用主模型路径。

### `--num-mm-embeds`

:   指定多模态嵌入的数量，格式为 `{"image": 16, "video": {"count": 1, "num_frames": 32, "width": 512, "height": 512}}`。

    混合格式（结合两者）：
        `{"image": 16, "video": {"count": 1, "num_frames": 32, "width": 512, 
        "height": 512}}`

    应为有效的 JSON 字符串或单独传递的 JSON 键。

:   默认值：`{}`

### `--enable-mm-embeds`, `--no-enable-mm-embeds`

:   如果为 `True`，启用传递多模态嵌入：
    对于 `LLM` 类，这指的是 `multi_modal_data` 下的张量输入；
    对于 OpenAI 兼容服务器，这指的是内容为 `"type": "*_embeds"` 的聊天消息。

    警告：如果传递了错误形状的嵌入，vLLM 引擎可能会崩溃。
    仅对受信任的用户启用此标志！

:   默认值：`False`

### `--media-io-kwargs`

:   传递给处理媒体输入的附加参数，按模态分组。
    例如，要设置视频的 num_frames，请设置
    `--media-io-kwargs '{"video": {"num_frames": 40} }'`

    应为有效的 JSON 字符串或单独传递的 JSON 键。

:   默认值：`{}`

### `--mm-processor-kwargs`

:   转发给模型多模态数据处理器的参数，
    例如，图像处理器。覆盖从 `transformers.AutoProcessor.from_pretrained` 获取的多模态处理器。

    可用的覆盖取决于正在运行的模型。

    例如，对于 Phi-3-Vision：
    `{"num_crops": 4}`。

    应为有效的 JSON 字符串或单独传递的 JSON 键。

### `--mm-processor-cache-gb`

:   多模态处理器缓存的大小（以 GiB 为单位），用于避免重新处理过去的多模态输入。

    此缓存在每个 API 进程和引擎核心进程中都有副本，
    导致总内存使用量为
    `mm_processor_cache_gb * (api_server_count + data_parallel_size)`。

    设置为 `0` 以完全禁用此缓存（不推荐）。

:   默认值：`4`

### `--mm-processor-cache-type`

:   可能的选择：`lru`, `shm`

:   用于多模态预处理器/映射器的缓存类型。如果为 `shm`，
    使用共享内存 FIFO 缓存。如果为 `lru`，使用镜像 LRU 缓存。

:   默认值：`lru`

### `--mm-shm-cache-max-object-size-mb`

:   存储在多模态处理器共享内存缓存中的每个对象的大小限制（以 MiB 为单位）。仅在 `mm_processor_cache_type` 为
    `"shm"` 时有效。

:   默认值：`128`

### `--mm-encoder-only`, `--no-mm-encoder-only`

:   启用时，跳过模型的语言组件。

    这通常仅在分离的编码器进程中有效。

:   默认值：`False`

### `--mm-encoder-tp-mode`

:   可能的选择：`data`, `weights`

:   指示如何使用张量并行（TP）优化多模态编码器推理。

    - `"weights"`：在同一个 vLLM 引擎内，将每层的权重跨 TP 等级分割。（默认 TP 行为）

    - `"data"`：在同一个 vLLM 引擎内，将批量输入数据跨 TP 等级分割以并行处理数据，同时在每个 TP 等级上托管完整权重。
        此批量级 DP 不要与 API 请求级 DP（由 `--data-parallel-size` 控制）混淆。
        这仅在模型基础上受支持，如果不支持 DP，则回退到
        `"weights"`。

:   默认值：`weights`

### `--mm-encoder-attn-backend`

:   使用视觉变换器时多模态编码器注意力后端的可选覆盖。接受来自
    `vllm.v1.attention.backends.registry.AttentionBackendEnum` 的任何值（例如 `FLASH_ATTN`）。

### `--interleave-mm-strings`, `--no-interleave-mm-strings`

:   在使用
    --chat-template-content-format=string 时启用多模态提示的完全交错支持。

:   默认值：`False`

### `--skip-mm-profiling`, `--no-skip-mm-profiling`

:   启用时，跳过多模态内存分析，仅在引擎初始化期间使用语言骨干模型进行分析。

    这会减少引擎启动时间，但将多模态编码器和
    嵌入缓存激活的峰值内存使用量估计责任转移给用户。

:   默认值：`False`

### `--video-pruning-rate`

:   通过高效视频采样设置视频修剪率。
    值位于 [0;1) 范围内，确定从每个视频中修剪的媒体 token 分数。


## LoRAConfig

LoRA 的配置。

### `--enable-lora`, `--no-enable-lora`

:   如果为 True，启用 LoRA 适配器的处理。

### `--max-loras`

:   单个批次中的最大 LoRA 数量。

:   默认值：`1`

### `--max-lora-rank`

:   可能的选择：`1`, `8`, `16`, `32`, `64`, `128`, `256`, `320`, `512`

:   最大 LoRA 等级。

:   默认值：`16`

### `--lora-dtype`

:   可能的选择：`auto`, `bfloat16`, `float16`

:   LoRA 的数据类型。如果为 auto，将默认为基础模型数据类型。

:   默认值：`auto`

### `--enable-tower-connector-lora`, `--no-enable-tower-connector-lora`

:   如果为 `True`，将启用多模态模型的塔（视觉编码器）和连接器的 LoRA 支持。这是一个实验性功能，目前仅支持一些 MM 模型，如 Qwen VL 系列。默认为 False。

:   默认值：`False`

### `--max-cpu-loras`

:   存储在 CPU 内存中的最大 LoRA 数量。必须 >= 
    `max_loras`。

### `--fully-sharded-loras`, `--no-fully-sharded-loras`

:   默认情况下，只有半数的 LoRA 计算是用张量并行分片的。
    启用此选项将使用完全分片的层。在高
    序列长度、最大等级或张量并行大小时，这可能更快。

:   默认值：`False`

### `--default-mm-loras`

:   将特定模态映射到 LoRA 模型路径的字典；此字段
    仅适用于多模态模型，应在模型在给定模态存在时始终期望 LoRA 处于活动状态时使用。
    请注意，目前，如果请求提供多个附加
    模态，每个模态都有自己的 LoRA，我们不会应用
    default_mm_loras，因为我们目前只支持每个提示一个 lora 适配器。在离线模式下运行时，n 个模态的 lora ID
    将自动分配为 1-n，模态名称按字母顺序排列。

    应为有效的 JSON 字符串或单独传递的 JSON 键。


## ObservabilityConfig

可观测性配置 - 指标和追踪。

### `--show-hidden-metrics-for-version`

:   启用自指定版本以来已被隐藏的已弃用 Prometheus 指标。例如，如果一个先前弃用的指标自 v0.7.0 版本以来一直被隐藏，您可以使用
    `--show-hidden-metrics-for-version=0.7` 作为临时转义机制，同时
    您迁移到新指标。该指标可能会在即将发布的版本中被完全移除。

### `--otlp-traces-endpoint`

:   OpenTelemetry 追踪将发送到的目标 URL。

### `--collect-detailed-traces`

:   可能的选择：`all`, `model`, `worker`, `None`, `model,worker`, `model,all`, `worker,model`, `worker,all`, `all,model`, `all,worker`

:   仅当设置了 `--otlp-traces-endpoint` 时才有意义。如果
    设置，它将收集指定模块的详细追踪。这
    涉及使用可能昂贵和或阻塞的操作，因此可能
    会影响性能。

    请注意，收集每个请求的详细计时信息可能很昂贵。

### `--kv-cache-metrics`, `--no-kv-cache-metrics`

:   启用 KV 缓存驻留指标（生命周期、空闲时间、重用间隔）。
    使用采样来最小化开销。
    需要启用日志统计（即，未设置 --disable-log-stats）。

:   默认值：`False`

### `--kv-cache-metrics-sample`

:   KV 缓存指标的采样率 (0.0, 1.0]。默认 0.01 = 1%% 的块。

:   默认值：`0.01`

### `--cudagraph-metrics`, `--no-cudagraph-metrics`

:   启用 CUDA 图指标（填充/未填充 token 的数量、运行时 cudagraph
    调度模式，以及它们在每个日志间隔的观察频率）。

:   默认值：`False`

### `--enable-layerwise-nvtx-tracing`, `--no-enable-layerwise-nvtx-tracing`

:   启用逐层 NVTX 跟踪。这将跟踪模型中每一层或模块的执行，并将输入/输出形状等信息附加到 nvtx 范围标记中。注意，这在启用 CUDA graphs 时不工作。

:   默认值: `False`

#### `--enable-mfu-metrics`, `--no-enable-mfu-metrics`

:   启用模型 FLOPs 利用率 (MFU) 指标。

:   默认值: `False`

#### `--enable-logging-iteration-details`, `--no-enable-logging-iteration-details`

:   启用迭代详情的详细日志记录。
    如果设置，vllm EngineCore 将记录迭代详情
    这包括上下文/生成请求的数量和令牌数量
    以及迭代的 CPU 耗时。

:   默认值: `False`


### SchedulerConfig

调度器配置。

#### `--max-num-batched-tokens`

:   单次迭代中要处理的最大令牌数。

    此处的默认值主要用于测试时的便利性。
    在实际使用中，这应该在 `EngineArgs.create_engine_config` 中设置。

    解析人类可读的整数，如 '1k'、'2M' 等。
    包括带有十进制乘数的小数值。

    示例:
    - '1k' -> 1,000
    - '1K' -> 1,024
    - '25.6k' -> 25,600


#### `--max-num-seqs`

:   单次迭代中要处理的最大序列数。

    此处的默认值主要用于测试时的便利性。
    在实际使用中，这应该在 `EngineArgs.create_engine_config` 中设置。

#### `--max-num-partial-prefills`

:   对于分块预填充，可以同时部分预填充的最大序列数。

:   默认值: `1`

#### `--max-long-partial-prefills`

:   对于分块预填充，长度超过 long_prefill_token_threshold 的提示将同时进行预填充的最大数量。将此值设置为小于 max_num_partial_prefills 将允许较短的提示在某些情况下排在较长提示的前面，从而改善延迟。

:   默认值: `1`

#### `--long-prefill-token-threshold`

:   对于分块预填充，如果提示长度超过此令牌数，则认为该请求较长。

:   默认值: `0`

#### `--scheduling-policy`

:   可选值: `fcfs`, `priority`

:   要使用的调度策略：

    - "fcfs" 表示先到先服务，即按到达顺序处理请求。

    - "priority" 表示根据给定优先级（数值越小表示越早处理）和到达时间（决定平局）来处理请求。

:   默认值: `fcfs`

#### `--enable-chunked-prefill`, `--no-enable-chunked-prefill`

:   如果为 True，预填充请求可以根据剩余的 `max_num_batched_tokens` 进行分块。

    此处的默认值主要用于测试时的便利性。
    在实际使用中，这应该在 `EngineArgs.create_engine_config` 中设置。

#### `--disable-chunked-mm-input`, `--no-disable-chunked-mm-input`

:   如果设置为 true 并且启用了分块预填充，我们不希望部分调度多模态项目。仅在 V1 中使用
    这确保了如果请求具有混合提示
    （如文本令牌 TTTT 后跟图像令牌 IIIIIIIIII）其中只能调度一些图像令牌（如 TTTTIIIII，留下 IIIII），
    它将在一个步骤中调度为 TTTT，在下一步中调度为 IIIIIIIIII。

:   默认值: `False`

#### `--scheduler-cls`

:   要使用的调度器类。"vllm.v1.core.sched.scheduler.Scheduler" 是
    默认调度器。可以是直接的类或 "mod.custom_class" 形式的类路径。

#### `--disable-hybrid-kv-cache-manager`, `--no-disable-hybrid-kv-cache-manager`

:   如果设置为 True，KV 缓存管理器将为所有注意力层分配相同大小的 KV 缓存
    即使存在多种类型的注意力层
    如全注意力和滑动窗口注意力。
    如果设置为 None，将根据环境和起始配置确定默认值。

#### `--async-scheduling`, `--no-async-scheduling`

:   如果设置为 False，禁用异步调度。异步调度有助于
    避免 GPU 利用率的间隙，从而实现更好的延迟和吞吐量。

#### `--stream-interval`

:   流式传输的间隔（或缓冲区大小），以令牌长度为单位。
    较小的值（1）通过立即发送每个令牌使流式传输更平滑，
    而较大的值（例如，10）通过在发送前批处理多个令牌来减少主机开销并可能提高吞吐量。

:   默认值: `1`


### CompilationConfig

编译配置。

您必须将 CompilationConfig 传递给 VLLMConfig 构造函数。
VLLMConfig 的 post_init 会进行进一步初始化。如果在
VLLMConfig 之外使用，某些字段将处于不正确的状态。

它有三个部分：

- 顶层编译控制：
    - [`mode`][vllm.config.CompilationConfig.mode]
    - [`debug_dump_path`][vllm.config.CompilationConfig.debug_dump_path]
    - [`cache_dir`][vllm.config.CompilationConfig.cache_dir]
    - [`backend`][vllm.config.CompilationConfig.backend]
    - [`custom_ops`][vllm.config.CompilationConfig.custom_ops]
    - [`splitting_ops`][vllm.config.CompilationConfig.splitting_ops]
    - [`compile_mm_encoder`][vllm.config.CompilationConfig.compile_mm_encoder]
- CudaGraph 捕获：
    - [`cudagraph_mode`][vllm.config.CompilationConfig.cudagraph_mode]
    - [`cudagraph_capture_sizes`]
    [vllm.config.CompilationConfig.cudagraph_capture_sizes]
    - [`max_cudagraph_capture_size`]
    [vllm.config.CompilationConfig.max_cudagraph_capture_size]
    - [`cudagraph_num_of_warmups`]
    [vllm.config.CompilationConfig.cudagraph_num_of_warmups]
    - [`cudagraph_copy_inputs`]
    [vllm.config.CompilationConfig.cudagraph_copy_inputs]
- Inductor 编译：
    - [`compile_sizes`][vllm.config.CompilationConfig.compile_sizes]
    - [`compile_ranges_split_points`]
        [vllm.config.CompilationConfig.compile_ranges_split_points]
    - [`inductor_compile_config`]
    [vllm.config.CompilationConfig.inductor_compile_config]
    - [`inductor_passes`][vllm.config.CompilationConfig.inductor_passes]
    - 自定义 inductor passes

为什么 cudagraph 和 inductor 有不同的大小：
- cudagraph：为特定大小捕获的 cudagraph 只能用于
    相同的大小。我们需要捕获所有要使用大小。
- inductor：inductor 为通用形状编译的图可以用于
    不同的大小。Inductor 也可以为特定大小编译，
    在那里它可以有更多信息来使用完全
    静态形状优化图。然而，我们发现通用形状编译
    对大多数情况来说已经足够。编译
    某些小批量大小可能是有益的，inductor 擅长优化。

#### `--cudagraph-capture-sizes`

:   要捕获 cudagraph 的大小。
    - None (默认)：捕获大小从 vllm 配置中推断。
    - list[int]：捕获大小按给定指定。

#### `--max-cudagraph-capture-size`

:   最大 cudagraph 捕获大小。

    如果指定了 cudagraph_capture_sizes，这将设置为该列表中的最大
    大小（或如果指定了则检查一致性）。如果
    没有指定 cudagraph_capture_sizes，则按照以下模式自动生成大小列表：

        [1, 2, 4] + list(range(8, 256, 8)) + list(
        range(256, max_cudagraph_capture_size + 1, 16))

    如果未指定，max_cudagraph_capture_size 默认设置为 min(max_num_seqs*2,
    512)。这在具有小 max_num_seqs 的紧密内存场景中避免 OOM，并防止捕获许多大图（>512）这将大大增加启动时间而性能提升有限。


### VllmConfig

包含所有 vllm 相关配置的数据类。这
简化了在代码库中传递不同配置的过程。

#### `--speculative-config`

:   推测解码配置。

    应该是有效的 JSON 字符串或单独传递的 JSON 键。

#### `--kv-transfer-config`

:   分布式 KV 缓存传输的配置。

    应该是有效的 JSON 字符串或单独传递的 JSON 键。

#### `--kv-events-config`

:   事件发布的配置。

应该是有效的 JSON 字符串或单独传递的 JSON 键。

#### `--ec-transfer-config`

:   分布式 EC 缓存传输的配置。

    应该是有效的 JSON 字符串或单独传递的 JSON 键。

#### `--compilation-config`, `-cc`

:   模型的 `torch.compile` 和 cudagraph 捕获配置。

    作为简写，可以通过 -cc.parameter=argument 的方式追加编译参数，例如 `-cc.mode=3`（等同于 `-cc='{"mode":3}'`）。

    您可以像这样指定完整的编译配置：
    `{"mode": 3, "cudagraph_capture_sizes": [1, 2, 4, 8]}`

    应该是有效的 JSON 字符串或单独传递的 JSON 键。

:   默认值: `{'level': None, 'mode': None, 'debug_dump_path': None, 'cache_dir': '', 'compile_cache_save_format': 'binary', 'backend': 'inductor', 'custom_ops': [], 'splitting_ops': None, 'compile_mm_encoder': False, 'compile_sizes': None, 'compile_ranges_split_points': None, 'inductor_compile_config': {'enable_auto_functionalized_v2': False, 'combo_kernels': True, 'benchmark_combo_kernel': True}, 'inductor_passes': {}, 'cudagraph_mode': None, 'cudagraph_num_of_warmups': 0, 'cudagraph_capture_sizes': None, 'cudagraph_copy_inputs': False, 'cudagraph_specialize_lora': True, 'use_inductor_graph_partition': None, 'pass_config': {}, 'max_cudagraph_capture_size': None, 'dynamic_shapes_config': {'type': <DynamicShapesType.BACKED: 'backed'>, 'evaluate_guards': False, 'assume_32_bit_indexing': False}, 'local_cache_dir': None, 'static_all_moe_layers': []}`

#### `--attention-config`, `-ac`

:   注意力配置。

    应该是有效的 JSON 字符串或单独传递的 JSON 键。

:   默认值: `AttentionConfig(backend=None, flash_attn_version=None, use_prefill_decode_attention=False, flash_attn_max_num_splits_for_cuda_graph=32, use_cudnn_prefill=False, use_trtllm_ragged_deepseek_prefill=True, use_trtllm_attention=None, disable_flashinfer_prefill=False, disable_flashinfer_q_quantization=False)`

#### `--additional-config`

:   指定平台的额外配置。不同平台可能支持不同的配置。请确保配置对您使用的平台有效。内容必须是可哈希的。

:   默认值: `{}`

#### `--structured-outputs-config`

:   结构化输出配置。

    应该是有效的 JSON 字符串或单独传递的 JSON 键。

:   默认值: `StructuredOutputsConfig(backend='auto', disable_fallback=False, disable_any_whitespace=False, disable_additional_properties=False, reasoning_parser='', reasoning_parser_plugin='', enable_in_reasoning=False)`

#### `--profiler-config`

:   性能分析配置。

    应该是有效的 JSON 字符串或单独传递的 JSON 键。

:   默认值: `ProfilerConfig(profiler=None, torch_profiler_dir='', torch_profiler_with_stack=True, torch_profiler_with_flops=False, torch_profiler_use_gzip=True, torch_profiler_dump_cuda_time_total=True, torch_profiler_record_shapes=False, torch_profiler_with_memory=False, ignore_frontend=False, delay_iterations=0, max_iterations=0)`

#### `--optimization-level`

:   优化级别。这些级别在启动时间成本和性能之间进行权衡，-O0 具有最佳启动时间，-O3 具有最佳性能。默认使用 -O2。请参阅 OptimizationLevel 了解完整描述。

:   默认值: `2`