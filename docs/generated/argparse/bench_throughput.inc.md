#### `--backend`

:   Possible choices: `vllm`, `hf`, `mii`, `vllm-chat`

:   Default: `vllm`

#### `--dataset-name`

:   Possible choices: `sharegpt`, `random`, `sonnet`, `burstgpt`, `hf`, `prefix_repetition`, `random-mm`, `random-rerank`

:   Name of the dataset to benchmark on.

:   Default: `sharegpt`

#### `--dataset`

:   Path to the ShareGPT dataset, will be deprecated in            the next release. The dataset is expected to be a json in form of list[dict[..., conversations: list[dict[..., value: <prompt_or_response>]]]]

#### `--dataset-path`

:   Path to the dataset

#### `--input-len`

:   Input prompt length for each request

#### `--output-len`

:   Output length for each request. Overrides the output length from the dataset.

#### `--n`

:   Number of generated sequences per prompt.

:   Default: `1`

#### `--num-prompts`

:   Number of prompts to process.

:   Default: `1000`

#### `--hf-max-batch-size`

:   Maximum batch size for HF backend.

#### `--output-json`

:   Path to save the throughput results in JSON format.

#### `--async-engine`

:   Use vLLM async engine rather than LLM class.

:   Default: `False`

#### `--disable-frontend-multiprocessing`

:   Disable decoupled async engine frontend.

:   Default: `False`

#### `--disable-detokenize`

:   Do not detokenize the response (i.e. do not include detokenization time in the measurement)

:   Default: `False`

#### `--lora-path`

:   Path to the lora adapters to use. This can be an absolute path, a relative path, or a Hugging Face model identifier.

#### `--prefix-len`

:   Number of fixed prefix tokens before the random context in a request (default: 0).

:   Default: `0`

#### `--hf-subset`

:   Subset of the HF dataset.

#### `--hf-split`

:   Split of the HF dataset.

#### `--profile`

:   Use vLLM Profiling. --profiler-config must be provided on the server.

:   Default: `False`

#### `--prefix-repetition-prefix-len`

:   Number of prefix tokens per request, used only for prefix repetition dataset.

#### `--prefix-repetition-suffix-len`

:   Number of suffix tokens per request, used only for prefix repetition dataset. Total input length is prefix_len + suffix_len.

#### `--prefix-repetition-num-prefixes`

:   Number of prefixes to generate, used only for prefix repetition dataset. Prompts per prefix is num_requests // num_prefixes.

#### `--prefix-repetition-output-len`

:   Number of output tokens per request, used only for prefix repetition dataset.

#### `--random-input-len`

:   Number of input tokens per request, used only for random sampling.

:   Default: `1024`

#### `--random-output-len`

:   Number of output tokens per request, used only for random sampling.

:   Default: `128`

#### `--random-range-ratio`

:   Range ratio for sampling input/output length, used only for random sampling. Must be in the range [0, 1) to define a symmetric sampling range[length * (1 - range_ratio), length * (1 + range_ratio)].

:   Default: `0.0`

#### `--random-prefix-len`

:   Number of fixed prefix tokens before the random context in a request. The total input length is the sum of `random-prefix-len` and a random context length sampled from [input_len * (1 - range_ratio), input_len * (1 + range_ratio)].

:   Default: `0`

#### `--random-batch-size`

:   Batch size for random sampling. Only used for embeddings benchmark.

:   Default: `1`

#### `--no-reranker`

:   Whether the model supports reranking natively. Only used for reranker benchmark.

:   Default: `False`

#### `--random-mm-base-items-per-request`

:   Base number of multimodal items per request for random-mm. Actual per-request count is sampled around this base using --random-mm-num-mm-items-range-ratio.

:   Default: `1`

#### `--random-mm-num-mm-items-range-ratio`

:   Range ratio r in [0, 1] for sampling items per request. We sample uniformly from the closed integer range [floor(n*(1-r)), ceil(n*(1+r))] where n is the base items per request. r=0 keeps it fixed; r=1 allows 0 items. The maximum is clamped to the sum of per-modality limits from --random-mm-limit-mm-per-prompt. An error is raised if the computed min exceeds the max.

:   Default: `0.0`

#### `--random-mm-limit-mm-per-prompt`

:   Per-modality hard caps for items attached per request, e.g. '{"image": 3, "video": 0}'. The sampled per-request item count is clamped to the sum of these limits. When a modality reaches its cap, its buckets are excluded and probabilities are renormalized.OBS.: Only image sampling is supported for now.

:   Default: `{'image': 255, 'video': 1}`

#### `--random-mm-bucket-config`

:   The bucket config is a dictionary mapping a multimodal itemsampling configuration to a probability.Currently allows for 2 modalities: images and videos. An bucket key is a tuple of (height, width, num_frames)The value is the probability of sampling that specific item. Example: --random-mm-bucket-config {(256, 256, 1): 0.5, (720, 1280, 1): 0.4, (720, 1280, 16): 0.10} First item: images with resolution 256x256 w.p. 0.5Second item: images with resolution 720x1280 w.p. 0.4 Third item: videos with resolution 720x1280 and 16 frames w.p. 0.1OBS.: If the probabilities do not sum to 1, they are normalized.OBS bis.: Only image sampling is supported for now.

:   Default: `{(256, 256, 1): 0.5, (720, 1280, 1): 0.5, (720, 1280, 16): 0.0}`

#### `--disable-log-stats`

:   Disable logging statistics.

:   Default: `False`

#### `--aggregate-engine-logging`

:   Log aggregate rather than per-engine statistics when using data parallelism.

:   Default: `False`

#### `--enable-log-requests`, `--no-enable-log-requests`

:   Enable logging requests.

:   Default: `False`

#### `--disable-log-requests`, `--no-disable-log-requests`

:   [DEPRECATED] Disable logging requests.

:   Default: `True`


### ModelConfig

Configuration for the model.

#### `--model`

:   Name or path of the Hugging Face model to use. It is also used as the
    content for `model_name` tag in metrics output when `served_model_name` is
    not specified.

:   Default: `Qwen/Qwen3-0.6B`

#### `--runner`

:   Possible choices: `auto`, `draft`, `generate`, `pooling`

:   The type of model runner to use. Each vLLM instance only supports one
    model runner, even if the same model can be used for multiple types.

:   Default: `auto`

#### `--convert`

:   Possible choices: `auto`, `classify`, `embed`, `mm_encoder_only`, `none`, `reward`

:   Convert the model using adapters defined in
    [vllm.model_executor.models.adapters][]. The most common use case is to
    adapt a text generation model to be used for pooling tasks.

:   Default: `auto`

#### `--tokenizer`

:   Name or path of the Hugging Face tokenizer to use. If unspecified, model
    name or path will be used.

#### `--tokenizer-mode`

:   Possible choices: `auto`, `deepseek_v32`, `hf`, `mistral`, `slow`

:   Tokenizer mode:

    - "auto" will use the tokenizer from `mistral_common` for Mistral models
    if available, otherwise it will use the "hf" tokenizer.

    - "hf" will use the fast tokenizer if available.

    - "slow" will always use the slow tokenizer.

    - "mistral" will always use the tokenizer from `mistral_common`.

    - "deepseek_v32" will always use the tokenizer from `deepseek_v32`.

    - Other custom values can be supported via plugins.

:   Default: `auto`

#### `--trust-remote-code`, `--no-trust-remote-code`

:   Trust remote code (e.g., from HuggingFace) when downloading the model
    and tokenizer.

:   Default: `False`

#### `--dtype`

:   Possible choices: `auto`, `bfloat16`, `float`, `float16`, `float32`, `half`

:   Data type for model weights and activations:

    - "auto" will use FP16 precision for FP32 and FP16 models, and BF16
    precision for BF16 models.

    - "half" for FP16. Recommended for AWQ quantization.

    - "float16" is the same as "half".

    - "bfloat16" for a balance between precision and range.

    - "float" is shorthand for FP32 precision.

    - "float32" for FP32 precision.

:   Default: `auto`

#### `--seed`

:   Random seed for reproducibility.

    We must set the global seed because otherwise,
    different tensor parallel workers would sample different tokens,
    leading to inconsistent results.

:   Default: `0`

#### `--hf-config-path`

:   Name or path of the Hugging Face config to use. If unspecified, model
    name or path will be used.

#### `--allowed-local-media-path`

:   Allowing API requests to read local images or videos from directories
    specified by the server file system. This is a security risk. Should only
    be enabled in trusted environments.

:   Default: `""`

#### `--allowed-media-domains`

:   If set, only media URLs that belong to this domain can be used for
    multi-modal inputs.

#### `--revision`

:   The specific model version to use. It can be a branch name, a tag name,
    or a commit id. If unspecified, will use the default version.

#### `--code-revision`

:   The specific revision to use for the model code on the Hugging Face Hub.
    It can be a branch name, a tag name, or a commit id. If unspecified, will
    use the default version.

#### `--tokenizer-revision`

:   The specific revision to use for the tokenizer on the Hugging Face Hub.
    It can be a branch name, a tag name, or a commit id. If unspecified, will
    use the default version.

#### `--max-model-len`

:   Model context length (prompt and output). If unspecified, will be
    automatically derived from the model config.

    When passing via `--max-model-len`, supports k/m/g/K/M/G in human-readable
    format. Examples:

    - 1k -> 1000

    - 1K -> 1024

    - 25.6k -> 25,600

    - -1 or 'auto' -> Automatically choose the maximum model length that fits in
    GPU memory. This will use the model's maximum context length if it fits,
    otherwise it will find the largest length that can be accommodated.

    Parse human-readable integers like '1k', '2M', etc.
    Including decimal values with decimal multipliers.
    Also accepts -1 or 'auto' as a special value for auto-detection.

    Examples:
    - '1k' -> 1,000
    - '1K' -> 1,024
    - '25.6k' -> 25,600
    - '-1' or 'auto' -> -1 (special value for auto-detection)


#### `--quantization`, `-q`

:   Method used to quantize the weights. If `None`, we first check the
    `quantization_config` attribute in the model config file. If that is
    `None`, we assume the model weights are not quantized and use `dtype` to
    determine the data type of the weights.

#### `--allow-deprecated-quantization`, `--no-allow-deprecated-quantization`

:   Whether to allow deprecated quantization methods.

:   Default: `False`

#### `--enforce-eager`, `--no-enforce-eager`

:   Whether to always use eager-mode PyTorch. If True, we will disable CUDA
    graph and always execute the model in eager mode. If False, we will use
    CUDA graph and eager execution in hybrid for maximal performance and
    flexibility.

:   Default: `False`

#### `--enable-return-routed-experts`, `--no-enable-return-routed-experts`

:   Whether to return routed experts.

:   Default: `False`

#### `--max-logprobs`

:   Maximum number of log probabilities to return when `logprobs` is
    specified in `SamplingParams`. The default value comes the default for the
    OpenAI Chat Completions API. -1 means no cap, i.e. all (output_length *
    vocab_size) logprobs are allowed to be returned and it may cause OOM.

:   Default: `20`

#### `--logprobs-mode`

:   Possible choices: `processed_logits`, `processed_logprobs`, `raw_logits`, `raw_logprobs`

:   Indicates the content returned in the logprobs and prompt_logprobs.
    Supported mode:
    1) raw_logprobs, 2) processed_logprobs, 3) raw_logits, 4) processed_logits.
    Raw means the values before applying any logit processors, like bad words.
    Processed means the values after applying all processors, including
    temperature and top_k/top_p.

:   Default: `raw_logprobs`

#### `--disable-sliding-window`, `--no-disable-sliding-window`

:   Whether to disable sliding window. If True, we will disable the sliding
    window functionality of the model, capping to sliding window size. If the
    model does not support sliding window, this argument is ignored.

:   Default: `False`

#### `--disable-cascade-attn`, `--no-disable-cascade-attn`

:   Disable cascade attention for V1. While cascade attention does not
    change the mathematical correctness, disabling it could be useful for
    preventing potential numerical issues. Note that even if this is set to
    False, cascade attention will be only used when the heuristic tells that
    it's beneficial.

:   Default: `False`

#### `--skip-tokenizer-init`, `--no-skip-tokenizer-init`

:   Skip initialization of tokenizer and detokenizer. Expects valid
    `prompt_token_ids` and `None` for prompt from the input. The generated
    output will contain token ids.

:   Default: `False`

#### `--enable-prompt-embeds`, `--no-enable-prompt-embeds`

:   If `True`, enables passing text embeddings as inputs via the
    `prompt_embeds` key.

    WARNING: The vLLM engine may crash if incorrect shape of embeddings is passed.
    Only enable this flag for trusted users!

:   Default: `False`

#### `--served-model-name`

:   The model name(s) used in the API. If multiple names are provided, the
    server will respond to any of the provided names. The model name in the
    model field of a response will be the first name in this list. If not
    specified, the model name will be the same as the `--model` argument. Noted
    that this name(s) will also be used in `model_name` tag content of
    prometheus metrics, if multiple names provided, metrics tag will take the
    first one.

#### `--config-format`

:   Possible choices: `auto`, `hf`, `mistral`

:   The format of the model config to load:

    - "auto" will try to load the config in hf format if available after trying
    to load in mistral format.

    - "hf" will load the config in hf format.

    - "mistral" will load the config in mistral format.

:   Default: `auto`

#### `--hf-token`

:   The token to use as HTTP bearer authorization for remote files . If
    `True`, will use the token generated when running `huggingface-cli login`
    (stored in `~/.huggingface`).

#### `--hf-overrides`

:   If a dictionary, contains arguments to be forwarded to the Hugging Face
    config. If a callable, it is called to update the HuggingFace config.

:   Default: `{}`

#### `--pooler-config`

:   Pooler config which controls the behaviour of output pooling in pooling
    models.

    Should either be a valid JSON string or JSON keys passed individually.

#### `--logits-processor-pattern`

:   Optional regex pattern specifying valid logits processor qualified names
    that can be passed with the `logits_processors` extra completion argument.
    Defaults to `None`, which allows no processors.

#### `--generation-config`

:   The folder path to the generation config. Defaults to `"auto"`, the
    generation config will be loaded from model path. If set to `"vllm"`, no
    generation config is loaded, vLLM defaults will be used. If set to a folder
    path, the generation config will be loaded from the specified folder path.
    If `max_new_tokens` is specified in generation config, then it sets a
    server-wide limit on the number of output tokens for all requests.

:   Default: `auto`

#### `--override-generation-config`

:   Overrides or sets generation config. e.g. `{"temperature": 0.5}`. If
    used with `--generation-config auto`, the override parameters will be
    merged with the default config from the model. If used with
    `--generation-config vllm`, only the override parameters are used.

    Should either be a valid JSON string or JSON keys passed individually.

:   Default: `{}`

#### `--enable-sleep-mode`, `--no-enable-sleep-mode`

:   Enable sleep mode for the engine (only cuda and
    hip platforms are supported).

:   Default: `False`

#### `--model-impl`

:   Possible choices: `auto`, `terratorch`, `transformers`, `vllm`

:   Which implementation of the model to use:

    - "auto" will try to use the vLLM implementation, if it exists, and fall
    back to the Transformers implementation if no vLLM implementation is
    available.

    - "vllm" will use the vLLM model implementation.

    - "transformers" will use the Transformers model implementation.

    - "terratorch" will use the TerraTorch model implementation.

:   Default: `auto`

#### `--override-attention-dtype`

:   Override dtype for attention

#### `--logits-processors`

:   One or more logits processors' fully-qualified class names or class
    definitions

#### `--io-processor-plugin`

:   IOProcessor plugin name to load at model startup


### LoadConfig

Configuration for loading the model weights.

#### `--load-format`

:   The format of the model weights to load:

    - "auto" will try to load the weights in the safetensors format and fall
    back to the pytorch bin format if safetensors format is not available.

    - "pt" will load the weights in the pytorch bin format.

    - "safetensors" will load the weights in the safetensors format.

    - "npcache" will load the weights in pytorch format and store a numpy cache
    to speed up the loading.

    - "dummy" will initialize the weights with random values, which is mainly
    for profiling.

    - "tensorizer" will use CoreWeave's tensorizer library for fast weight
    loading. See the Tensorize vLLM Model script in the Examples section for
    more information.

    - "runai_streamer" will load the Safetensors weights using Run:ai Model
    Streamer.

    - "runai_streamer_sharded" will load weights from pre-sharded checkpoint
    files using Run:ai Model Streamer.

    - "bitsandbytes" will load the weights using bitsandbytes quantization.

    - "sharded_state" will load weights from pre-sharded checkpoint files,
    supporting efficient loading of tensor-parallel models.

    - "gguf" will load weights from GGUF format files (details specified in
    https://github.com/ggml-org/ggml/blob/master/docs/gguf.md).

    - "mistral" will load weights from consolidated safetensors files used by
    Mistral models.
    - Other custom values can be supported via plugins.

:   Default: `auto`

#### `--download-dir`

:   Directory to download and load the weights, default to the default
    cache directory of Hugging Face.

#### `--safetensors-load-strategy`

:   Specifies the loading strategy for safetensors weights.
    - "lazy" (default): Weights are memory-mapped from the file. This enables
      on-demand loading and is highly efficient for models on local storage.
    - "eager": The entire file is read into CPU memory upfront before loading.
      This is recommended for models on network filesystems (e.g., Lustre, NFS)
      as it avoids inefficient random reads, significantly speeding up model
      initialization. However, it uses more CPU RAM.
    - "torchao": Weights are loaded in upfront and then reconstructed
      into torchao tensor subclasses. This is used when the checkpoint
      was quantized using torchao and saved using safetensors.
      Needs torchao >= 0.14.0

:   Default: `lazy`

#### `--model-loader-extra-config`

:   Extra config for model loader. This will be passed to the model loader
    corresponding to the chosen load_format.

:   Default: `{}`

#### `--ignore-patterns`

:   The list of patterns to ignore when loading the model. Default to
    "original/**/*" to avoid repeated loading of llama's checkpoints.

:   Default: `['original/**/*']`

#### `--use-tqdm-on-load`, `--no-use-tqdm-on-load`

:   Whether to enable tqdm for showing progress bar when loading model
    weights.

:   Default: `True`

#### `--pt-load-map-location`

:   pt_load_map_location: the map location for loading pytorch checkpoint, to
    support loading checkpoints can only be loaded on certain devices like
    "cuda", this is equivalent to {"": "cuda"}. Another supported format is
    mapping from different devices like from GPU 1 to GPU 0:
    {"cuda:1": "cuda:0"}. Note that when passed from command line, the strings
    in dictionary needs to be double quoted for json parsing. For more details,
    see original doc for `map_location` in https://pytorch.org/docs/stable/generated/torch.load.html

:   Default: `cpu`


### AttentionConfig

Configuration for attention mechanisms in vLLM.

#### `--attention-backend`

:   Attention backend to use. If None, will be selected automatically.


### StructuredOutputsConfig

Dataclass which contains structured outputs config for the engine.

#### `--reasoning-parser`

:   Select the reasoning parser depending on the model that you're using.
    This is used to parse the reasoning content into OpenAI API format.

:   Default: `""`

#### `--reasoning-parser-plugin`

:   Path to a dynamically reasoning parser plugin that can be dynamically
    loaded and registered.

:   Default: `""`


### ParallelConfig

Configuration for the distributed execution.

#### `--distributed-executor-backend`

:   Possible choices: `external_launcher`, `mp`, `ray`, `uni`

:   Backend to use for distributed model workers, either "ray" or "mp"
    (multiprocessing). If the product of pipeline_parallel_size and tensor_parallel_size
    is less than or equal to the number of GPUs available, "mp" will be used to
    keep processing on a single host. Otherwise, an error will be raised. To use "mp"
    you must also set nnodes, and to use "ray" you must manually set
    distributed_executor_backend to "ray".

    Note that tpu only support Ray for distributed inference.

#### `--pipeline-parallel-size`, `-pp`

:   Number of pipeline parallel groups.

:   Default: `1`

#### `--master-addr`

:   distributed master address for multi-node distributed 
    inference when distributed_executor_backend is mp.

:   Default: `127.0.0.1`

#### `--master-port`

:   distributed master port for multi-node distributed 
    inference when distributed_executor_backend is mp.

:   Default: `29501`

#### `--nnodes`, `-n`

:   num of nodes for multi-node distributed 
    inference when distributed_executor_backend is mp.

:   Default: `1`

#### `--node-rank`, `-r`

:   distributed node rank for multi-node distributed 
    inference when distributed_executor_backend is mp.

:   Default: `0`

#### `--tensor-parallel-size`, `-tp`

:   Number of tensor parallel groups.

:   Default: `1`

#### `--decode-context-parallel-size`, `-dcp`

:   Number of decode context parallel groups, because the world size does
    not change by dcp, it simply reuse the GPUs of TP group, and tp_size
    needs to be divisible by dcp_size.

:   Default: `1`

#### `--dcp-kv-cache-interleave-size`

:   Interleave size of kv_cache storage while using DCP.
    dcp_kv_cache_interleave_size has been replaced by cp_kv_cache_interleave_size,
    and will be deprecated when PCP is fully supported.

:   Default: `1`

#### `--cp-kv-cache-interleave-size`

:   Interleave size of kv_cache storage while using DCP or PCP.
    For `total_cp_rank = pcp_rank * dcp_world_size + dcp_rank`,
        and `total_cp_world_size = pcp_world_size * dcp_world_size`.
    store interleave_size tokens on total_cp_rank i,
    then store next interleave_size tokens on total_cp_rank i+1.
    Interleave_size=1: token-level alignment, where token `i` is stored on
        total_cp_rank `i %% total_cp_world_size`.
    Interleave_size=block_size: block-level alignment, where tokens are
        first populated to the preceding ranks. Tokens are then stored
        in (rank i+1, block j) only after (rank i, block j) is fully occupied.
    Block_size should be greater than or equal to cp_kv_cache_interleave_size.
    Block_size should be divisible by cp_kv_cache_interleave_size.

:   Default: `1`

#### `--prefill-context-parallel-size`, `-pcp`

:   Number of prefill context parallel groups.

:   Default: `1`

#### `--data-parallel-size`, `-dp`

:   Number of data parallel groups. MoE layers will be sharded according to
    the product of the tensor parallel size and data parallel size.

:   Default: `1`

#### `--data-parallel-rank`, `-dpn`

:   Data parallel rank of this instance. When set, enables external load balancer mode.

#### `--data-parallel-start-rank`, `-dpr`

:   Starting data parallel rank for secondary nodes.

#### `--data-parallel-size-local`, `-dpl`

:   Number of data parallel replicas to run on this node.

#### `--data-parallel-address`, `-dpa`

:   Address of data parallel cluster head-node.

#### `--data-parallel-rpc-port`, `-dpp`

:   Port for data parallel RPC communication.

#### `--data-parallel-backend`, `-dpb`

:   Backend for data parallel, either "mp" or "ray".

:   Default: `mp`

#### `--data-parallel-hybrid-lb`, `--no-data-parallel-hybrid-lb`, `-dph`

:   Whether to use "hybrid" DP LB mode. Applies only to online serving
    and when data_parallel_size > 0. Enables running an AsyncLLM
    and API server on a "per-node" basis where vLLM load balances
    between local data parallel ranks, but an external LB balances
    between vLLM nodes/replicas. Set explicitly in conjunction with
    --data-parallel-start-rank.

:   Default: `False`

#### `--data-parallel-external-lb`, `--no-data-parallel-external-lb`, `-dpe`

:   Whether to use "external" DP LB mode. Applies only to online serving
    and when data_parallel_size > 0. This is useful for a "one-pod-per-rank"
    wide-EP setup in Kubernetes. Set implicitly when --data-parallel-rank
    is provided explicitly to vllm serve.

:   Default: `False`

#### `--enable-expert-parallel`, `--no-enable-expert-parallel`, `-ep`

:   Use expert parallelism instead of tensor parallelism for MoE layers.

:   Default: `False`

#### `--all2all-backend`

:   Possible choices: `allgather_reducescatter`, `deepep_high_throughput`, `deepep_low_latency`, `flashinfer_all2allv`, `mori`, `naive`, `pplx`

:   All2All backend for MoE expert parallel communication. Available options:

    - "naive": Naive all2all implementation using broadcasts

    - "allgather_reducescatter": All2all based on allgather and reducescatter

    - "pplx": Use pplx kernels

    - "deepep_high_throughput": Use deepep high-throughput kernels

    - "deepep_low_latency": Use deepep low-latency kernels

    - "mori": Use mori kernels

    - "flashinfer_all2allv": Use flashinfer alltoallv kernels for mnnvl

:   Default: `allgather_reducescatter`

#### `--enable-dbo`, `--no-enable-dbo`

:   Enable dual batch overlap for the model executor.

:   Default: `False`

#### `--ubatch-size`

:   Number of ubatch size.

:   Default: `0`

#### `--dbo-decode-token-threshold`

:   The threshold for dual batch overlap for batches only containing decodes.
    If the number of tokens in the request is greater than this threshold,
    microbatching will be used. Otherwise, the request will be processed in a
    single batch.

:   Default: `32`

#### `--dbo-prefill-token-threshold`

:   The threshold for dual batch overlap for batches that contain one or more
    prefills. If the number of tokens in the request is greater than this
    threshold, microbatching will be used. Otherwise, the request will be
    processed in a single batch.

:   Default: `512`

#### `--disable-nccl-for-dp-synchronization`, `--no-disable-nccl-for-dp-synchronization`

:   Forces the dp synchronization logic in vllm/v1/worker/dp_utils.py 
    to use Gloo instead of NCCL for its all reduce.

    Defaults to True when async scheduling is enabled, False otherwise.

#### `--enable-eplb`, `--no-enable-eplb`

:   Enable expert parallelism load balancing for MoE layers.

:   Default: `False`

#### `--eplb-config`

:   Expert parallelism configuration.

    Should either be a valid JSON string or JSON keys passed individually.

:   Default: `EPLBConfig(window_size=1000, step_interval=3000, num_redundant_experts=0, log_balancedness=False, log_balancedness_interval=1, use_async=False, policy='default')`

#### `--expert-placement-strategy`

:   Possible choices: `linear`, `round_robin`

:   The expert placement strategy for MoE layers:

    - "linear": Experts are placed in a contiguous manner. For example, with 4
      experts and 2 ranks, rank 0 will have experts [0, 1] and rank 1 will have
      experts [2, 3].

    - "round_robin": Experts are placed in a round-robin manner. For example,
      with 4 experts and 2 ranks, rank 0 will have experts [0, 2] and rank 1
      will have experts [1, 3]. This strategy can help improve load balancing
      for grouped expert models with no redundant experts.

:   Default: `linear`

#### `--max-parallel-loading-workers`

:   Maximum number of parallel loading workers when loading model
    sequentially in multiple batches. To avoid RAM OOM when using tensor
    parallel and large models.

#### `--ray-workers-use-nsight`, `--no-ray-workers-use-nsight`

:   Whether to profile Ray workers with nsight, see https://docs.ray.io/en/latest/ray-observability/user-guides/profiling.html#profiling-nsight-profiler.

:   Default: `False`

#### `--disable-custom-all-reduce`, `--no-disable-custom-all-reduce`

:   Disable the custom all-reduce kernel and fall back to NCCL.

:   Default: `False`

#### `--worker-cls`

:   The full name of the worker class to use. If "auto", the worker class
    will be determined based on the platform.

:   Default: `auto`

#### `--worker-extension-cls`

:   The full name of the worker extension class to use. The worker extension
    class is dynamically inherited by the worker class. This is used to inject
    new attributes and methods to the worker class for use in collective_rpc
    calls.

:   Default: `""`


### CacheConfig

Configuration for the KV cache.

#### `--block-size`

:   Possible choices: `1`, `8`, `16`, `32`, `64`, `128`, `256`

:   Size of a contiguous cache block in number of tokens. On CUDA devices,
    only block sizes up to 32 are supported.

    This config has no static default. If left unspecified by the user, it will
    be set in `Platform.check_and_update_config()` based on the current
    platform.

#### `--gpu-memory-utilization`

:   The fraction of GPU memory to be used for the model executor, which can
    range from 0 to 1. For example, a value of 0.5 would imply 50%% GPU memory
    utilization. If unspecified, will use the default value of 0.9. This is a
    per-instance limit, and only applies to the current vLLM instance. It does
    not matter if you have another vLLM instance running on the same GPU. For
    example, if you have two vLLM instances running on the same GPU, you can
    set the GPU memory utilization to 0.5 for each instance.

:   Default: `0.9`

#### `--kv-cache-memory-bytes`

:   Size of KV Cache per GPU in bytes. By default, this is set to None
    and vllm can automatically infer the kv cache size based on
    gpu_memory_utilization. However, users may want to manually specify
    the kv cache memory size. kv_cache_memory_bytes allows more fine-grain
    control of how much memory gets used when compared with using
    gpu_memory_utilization. Note that kv_cache_memory_bytes
    (when not-None) ignores gpu_memory_utilization

    Parse human-readable integers like '1k', '2M', etc.
    Including decimal values with decimal multipliers.

    Examples:
    - '1k' -> 1,000
    - '1K' -> 1,024
    - '25.6k' -> 25,600


#### `--swap-space`

:   Size of the CPU swap space per GPU (in GiB).

:   Default: `4`

#### `--kv-cache-dtype`

:   Possible choices: `auto`, `bfloat16`, `fp8`, `fp8_ds_mla`, `fp8_e4m3`, `fp8_e5m2`, `fp8_inc`

:   Data type for kv cache storage. If "auto", will use model data type.
    CUDA 11.8+ supports fp8 (=fp8_e4m3) and fp8_e5m2. ROCm (AMD GPU) supports
    fp8 (=fp8_e4m3). Intel Gaudi (HPU) supports fp8 (using fp8_inc).
    Some models (namely DeepSeekV3.2) default to fp8, set to bfloat16 to use
    bfloat16 instead, this is an invalid option for models that do not default
    to fp8.

:   Default: `auto`

#### `--num-gpu-blocks-override`

:   Number of GPU blocks to use. This overrides the profiled `num_gpu_blocks`
    if specified. Does nothing if `None`. Used for testing preemption.

#### `--enable-prefix-caching`, `--no-enable-prefix-caching`

:   Whether to enable prefix caching.

#### `--prefix-caching-hash-algo`

:   Possible choices: `sha256`, `sha256_cbor`, `xxhash`, `xxhash_cbor`

:   Set the hash algorithm for prefix caching:

    - "sha256" uses Pickle for object serialization before hashing. This is the
    current default, as SHA256 is the most secure choice to avoid potential
    hash collisions.

    - "sha256_cbor" provides a reproducible, cross-language compatible hash. It
    serializes objects using canonical CBOR and hashes them with SHA-256.

    - "xxhash" uses Pickle serialization with xxHash (128-bit) for faster,
    non-cryptographic hashing. Requires the optional ``xxhash`` package.
    IMPORTANT: Use of a hashing algorithm that is not considered 
    cryptographically secure theoretically increases the risk of hash collisions,
    which can cause undefined behavior or even leak private information in
    multi-tenant environments. Even if collisions are still very unlikely, it is
    important to consider your security risk tolerance against the performance
    benefits before turning this on.

    - "xxhash_cbor" combines canonical CBOR serialization with xxHash for
    reproducible hashing. Requires the optional ``xxhash`` package.

:   Default: `sha256`

#### `--cpu-offload-gb`

:   The space in GiB to offload to CPU, per GPU. Default is 0, which means
    no offloading. Intuitively, this argument can be seen as a virtual way to
    increase the GPU memory size. For example, if you have one 24 GB GPU and
    set this to 10, virtually you can think of it as a 34 GB GPU. Then you can
    load a 13B model with BF16 weight, which requires at least 26GB GPU memory.
    Note that this requires fast CPU-GPU interconnect, as part of the model is
    loaded from CPU memory to GPU memory on the fly in each model forward pass.

:   Default: `0`

#### `--calculate-kv-scales`, `--no-calculate-kv-scales`

:   This enables dynamic calculation of `k_scale` and `v_scale` when
    kv_cache_dtype is fp8. If `False`, the scales will be loaded from the model
    checkpoint if available. Otherwise, the scales will default to 1.0.

:   Default: `False`

#### `--kv-sharing-fast-prefill`, `--no-kv-sharing-fast-prefill`

:   This feature is work in progress and no prefill optimization takes place
    with this flag enabled currently.

    In some KV sharing setups, e.g. YOCO (https://arxiv.org/abs/2405.05254),
    some layers can skip tokens corresponding to prefill. This flag enables
    attention metadata for eligible layers to be overridden with metadata
    necessary for implementing this optimization in some models (e.g. Gemma3n)

:   Default: `False`

#### `--mamba-cache-dtype`

:   Possible choices: `auto`, `float16`, `float32`

:   The data type to use for the Mamba cache (both the conv as well as the
    ssm state). If set to 'auto', the data type will be inferred from the model
    config.

:   Default: `auto`

#### `--mamba-ssm-cache-dtype`

:   Possible choices: `auto`, `float16`, `float32`

:   The data type to use for the Mamba cache (ssm state only, conv state will
    still be controlled by mamba_cache_dtype). If set to 'auto', the data type
    for the ssm state will be determined by mamba_cache_dtype.

:   Default: `auto`

#### `--mamba-block-size`

:   Size of a contiguous cache block in number of tokens for mamba cache.
    Can be set only when prefix caching is enabled.
    Value must be a multiple of 8 to align with causal_conv1d kernel.

#### `--mamba-cache-mode`

:   Possible choices: `align`, `all`, `none`

:   The cache strategy for Mamba layers.
    - "none": set when prefix caching is disabled.
    - "all": cache the mamba state of all tokens at position i * block_size. This is 
           the default behavior (for models that support it) when prefix caching is
           enabled.
    - "align": only cache the mamba state of the last token of each scheduler step and
           when the token is at position i * block_size.

:   Default: `none`

#### `--kv-offloading-size`

:   Size of the KV cache offloading buffer in GiB. When TP > 1, this is
    the total buffer size summed across all TP ranks. By default, this is set
    to None, which means no KV offloading is enabled. When set, vLLM will
    enable KV cache offloading to CPU using the kv_offloading_backend.

#### `--kv-offloading-backend`

:   Possible choices: `lmcache`, `native`

:   The backend to use for KV cache offloading. Supported backends include
    'native' (vLLM native CPU offloading), 'lmcache'.
    KV offloading is only activated when kv_offloading_size is set.

:   Default: `native`


### MultiModalConfig

Controls the behavior of multimodal models.

#### `--limit-mm-per-prompt`

:   The maximum number of input items and options allowed per 
        prompt for each modality.
    Defaults to 999 for each modality.

    Legacy format (count only):
        {"image": 16, "video": 2}

    Configurable format (with options):
        {"video": {"count": 1, "num_frames": 32, "width": 512, "height": 512}, 
        "image": {"count": 5, "width": 512, "height": 512}}

    Mixed format (combining both):
        {"image": 16, "video": {"count": 1, "num_frames": 32, "width": 512, 
        "height": 512}}

    Should either be a valid JSON string or JSON keys passed individually.

:   Default: `{}`

#### `--enable-mm-embeds`, `--no-enable-mm-embeds`

:   If `True`, enables passing multimodal embeddings:
    for `LLM` class, this refers to tensor inputs under `multi_modal_data`;
    for the OpenAI-compatible server, this refers to chat messages with content
    `"type": "*_embeds"`.

    WARNING: The vLLM engine may crash if incorrect shape of embeddings is passed.
    Only enable this flag for trusted users!

:   Default: `False`

#### `--media-io-kwargs`

:   Additional args passed to process media inputs, keyed by modalities.
    For example, to set num_frames for video, set
    `--media-io-kwargs '{"video": {"num_frames": 40} }'`

    Should either be a valid JSON string or JSON keys passed individually.

:   Default: `{}`

#### `--mm-processor-kwargs`

:   Arguments to be forwarded to the model's processor for multi-modal data,
    e.g., image processor. Overrides for the multi-modal processor obtained
    from `transformers.AutoProcessor.from_pretrained`.

    The available overrides depend on the model that is being run.

    For example, for Phi-3-Vision:
    `{"num_crops": 4}`.

    Should either be a valid JSON string or JSON keys passed individually.

#### `--mm-processor-cache-gb`

:   The size (in GiB) of the multi-modal processor cache, which is used to
    avoid re-processing past multi-modal inputs.

    This cache is duplicated for each API process and engine core process,
    resulting in a total memory usage of
    `mm_processor_cache_gb * (api_server_count + data_parallel_size)`.

    Set to `0` to disable this cache completely (not recommended).

:   Default: `4`

#### `--mm-processor-cache-type`

:   Possible choices: `lru`, `shm`

:   Type of cache to use for the multi-modal preprocessor/mapper. If `shm`,
    use shared memory FIFO cache. If `lru`, use mirrored LRU cache.

:   Default: `lru`

#### `--mm-shm-cache-max-object-size-mb`

:   Size limit (in MiB) for each object stored in the multi-modal processor
    shared memory cache. Only effective when `mm_processor_cache_type` is
    `"shm"`.

:   Default: `128`

#### `--mm-encoder-only`, `--no-mm-encoder-only`

:   When enabled, skips the language component of the model.

    This is usually only valid in disaggregated Encoder process.

:   Default: `False`

#### `--mm-encoder-tp-mode`

:   Possible choices: `data`, `weights`

:   Indicates how to optimize multi-modal encoder inference using tensor
    parallelism (TP).

    - `"weights"`: Within the same vLLM engine, split the weights of
        each layer across TP ranks. (default TP behavior)

    - `"data"`: Within the same vLLM engine, split the batched input data
        across TP ranks to process the data in parallel, while hosting
        the full weights on each TP rank.
        This batch-level DP is not to be confused with API request-level
        DP (which is controlled by `--data-parallel-size`).
        This is only supported on a per-model basis and falls back to
        `"weights"` if the encoder does not support DP.

:   Default: `weights`

#### `--mm-encoder-attn-backend`

:   Optional override for the multi-modal encoder attention backend when
    using vision transformers. Accepts any value from
    `vllm.v1.attention.backends.registry.AttentionBackendEnum` (e.g. `FLASH_ATTN`).

#### `--interleave-mm-strings`, `--no-interleave-mm-strings`

:   Enable fully interleaved support for multimodal prompts, while using
    --chat-template-content-format=string.

:   Default: `False`

#### `--skip-mm-profiling`, `--no-skip-mm-profiling`

:   When enabled, skips multimodal memory profiling and only profiles with
    language backbone model during engine initialization.

    This reduces engine startup time but shifts the responsibility to users for
    estimating the peak memory usage of the activation of multimodal encoder and
    embedding cache.

:   Default: `False`

#### `--video-pruning-rate`

:   Sets pruning rate for video pruning via Efficient Video Sampling.
    Value sits in range [0;1) and determines fraction of media tokens
    from each video to be pruned.


### LoRAConfig

Configuration for LoRA.

#### `--enable-lora`, `--no-enable-lora`

:   If True, enable handling of LoRA adapters.

#### `--max-loras`

:   Max number of LoRAs in a single batch.

:   Default: `1`

#### `--max-lora-rank`

:   Possible choices: `1`, `8`, `16`, `32`, `64`, `128`, `256`, `320`, `512`

:   Max LoRA rank.

:   Default: `16`

#### `--lora-dtype`

:   Possible choices: `auto`, `bfloat16`, `float16`

:   Data type for LoRA. If auto, will default to base model dtype.

:   Default: `auto`

#### `--enable-tower-connector-lora`, `--no-enable-tower-connector-lora`

:   If `True`, LoRA support for the tower (vision encoder) and connector 
    of multimodal models will be enabled. This is an experimental feature and 
    currently only supports some MM models such as the Qwen VL series. The default 
    is False.

:   Default: `False`

#### `--max-cpu-loras`

:   Maximum number of LoRAs to store in CPU memory. Must be >= than
    `max_loras`.

#### `--fully-sharded-loras`, `--no-fully-sharded-loras`

:   By default, only half of the LoRA computation is sharded with tensor
    parallelism. Enabling this will use the fully sharded layers. At high
    sequence length, max rank or tensor parallel size, this is likely faster.

:   Default: `False`

#### `--default-mm-loras`

:   Dictionary mapping specific modalities to LoRA model paths; this field
    is only applicable to multimodal models and should be leveraged when a
    model always expects a LoRA to be active when a given modality is present.
    Note that currently, if a request provides multiple additional
    modalities, each of which have their own LoRA, we do NOT apply
    default_mm_loras because we currently only support one lora adapter
    per prompt. When run in offline mode, the lora IDs for n modalities
    will be automatically assigned to 1-n with the names of the modalities
    in alphabetic order.

    Should either be a valid JSON string or JSON keys passed individually.


### ObservabilityConfig

Configuration for observability - metrics and tracing.

#### `--show-hidden-metrics-for-version`

:   Enable deprecated Prometheus metrics that have been hidden since the
    specified version. For example, if a previously deprecated metric has been
    hidden since the v0.7.0 release, you use
    `--show-hidden-metrics-for-version=0.7` as a temporary escape hatch while
    you migrate to new metrics. The metric is likely to be removed completely
    in an upcoming release.

#### `--otlp-traces-endpoint`

:   Target URL to which OpenTelemetry traces will be sent.

#### `--collect-detailed-traces`

:   Possible choices: `all`, `model`, `worker`, `None`, `model,worker`, `model,all`, `worker,model`, `worker,all`, `all,model`, `all,worker`

:   It makes sense to set this only if `--otlp-traces-endpoint` is set. If
    set, it will collect detailed traces for the specified modules. This
    involves use of possibly costly and or blocking operations and hence might
    have a performance impact.

    Note that collecting detailed timing information for each request can be
    expensive.

#### `--kv-cache-metrics`, `--no-kv-cache-metrics`

:   Enable KV cache residency metrics (lifetime, idle time, reuse gaps).
    Uses sampling to minimize overhead.
    Requires log stats to be enabled (i.e., --disable-log-stats not set).

:   Default: `False`

#### `--kv-cache-metrics-sample`

:   Sampling rate for KV cache metrics (0.0, 1.0]. Default 0.01 = 1%% of blocks.

:   Default: `0.01`

#### `--cudagraph-metrics`, `--no-cudagraph-metrics`

:   Enable CUDA graph metrics (number of padded/unpadded tokens, runtime cudagraph
    dispatch modes, and their observed frequencies at every logging interval).

:   Default: `False`

#### `--enable-layerwise-nvtx-tracing`, `--no-enable-layerwise-nvtx-tracing`

:   Enable layerwise NVTX tracing. This traces the execution of each layer or
    module in the model and attach informations such as input/output shapes to
    nvtx range markers. Noted that this doesn't work with CUDA graphs enabled.

:   Default: `False`

#### `--enable-mfu-metrics`, `--no-enable-mfu-metrics`

:   Enable Model FLOPs Utilization (MFU) metrics.

:   Default: `False`

#### `--enable-logging-iteration-details`, `--no-enable-logging-iteration-details`

:   Enable detailed logging of iteration details.
    If set, vllm EngineCore will log iteration details
    This includes number of context/generation requests and tokens
    and the elapsed cpu time for the iteration.

:   Default: `False`


### SchedulerConfig

Scheduler configuration.

#### `--max-num-batched-tokens`

:   Maximum number of tokens to be processed in a single iteration.

    The default value here is mainly for convenience when testing.
    In real usage, this should be set in `EngineArgs.create_engine_config`.

    Parse human-readable integers like '1k', '2M', etc.
    Including decimal values with decimal multipliers.

    Examples:
    - '1k' -> 1,000
    - '1K' -> 1,024
    - '25.6k' -> 25,600


#### `--max-num-seqs`

:   Maximum number of sequences to be processed in a single iteration.

    The default value here is mainly for convenience when testing.
    In real usage, this should be set in `EngineArgs.create_engine_config`.

#### `--max-num-partial-prefills`

:   For chunked prefill, the maximum number of sequences that can be
    partially prefilled concurrently.

:   Default: `1`

#### `--max-long-partial-prefills`

:   For chunked prefill, the maximum number of prompts longer than
    long_prefill_token_threshold that will be prefilled concurrently. Setting
    this less than max_num_partial_prefills will allow shorter prompts to jump
    the queue in front of longer prompts in some cases, improving latency.

:   Default: `1`

#### `--long-prefill-token-threshold`

:   For chunked prefill, a request is considered long if the prompt is
    longer than this number of tokens.

:   Default: `0`

#### `--scheduling-policy`

:   Possible choices: `fcfs`, `priority`

:   The scheduling policy to use:

    - "fcfs" means first come first served, i.e. requests are handled in order
    of arrival.

    - "priority" means requests are handled based on given priority (lower
    value means earlier handling) and time of arrival deciding any ties).

:   Default: `fcfs`

#### `--enable-chunked-prefill`, `--no-enable-chunked-prefill`

:   If True, prefill requests can be chunked based
    on the remaining `max_num_batched_tokens`.

    The default value here is mainly for convenience when testing.
    In real usage, this should be set in `EngineArgs.create_engine_config`.

#### `--disable-chunked-mm-input`, `--no-disable-chunked-mm-input`

:   If set to true and chunked prefill is enabled, we do not want to
    partially schedule a multimodal item. Only used in V1
    This ensures that if a request has a mixed prompt
    (like text tokens TTTT followed by image tokens IIIIIIIIII) where only
    some image tokens can be scheduled (like TTTTIIIII, leaving IIIII),
    it will be scheduled as TTTT in one step and IIIIIIIIII in the next.

:   Default: `False`

#### `--scheduler-cls`

:   The scheduler class to use. "vllm.v1.core.sched.scheduler.Scheduler" is
    the default scheduler. Can be a class directly or the path to a class of
    form "mod.custom_class".

#### `--disable-hybrid-kv-cache-manager`, `--no-disable-hybrid-kv-cache-manager`

:   If set to True, KV cache manager will allocate the same size of KV cache
    for all attention layers even if there are multiple type of attention layers
    like full attention and sliding window attention.
    If set to None, the default value will be determined based on the environment
    and starting configuration.

#### `--async-scheduling`, `--no-async-scheduling`

:   If set to False, disable async scheduling. Async scheduling helps to
    avoid gaps in GPU utilization, leading to better latency and throughput.

#### `--stream-interval`

:   The interval (or buffer size) for streaming in terms of token length.
    A smaller value (1) makes streaming smoother by sending each token immediately,
    while a larger value (e.g., 10) reduces host overhead and may increase throughput
    by batching multiple tokens before sending.

:   Default: `1`


### CompilationConfig

Configuration for compilation.

You must pass CompilationConfig to VLLMConfig constructor.
VLLMConfig's post_init does further initialization. If used outside of the
VLLMConfig, some fields will be left in an improper state.

It has three parts:

- Top-level Compilation control:
    - [`mode`][vllm.config.CompilationConfig.mode]
    - [`debug_dump_path`][vllm.config.CompilationConfig.debug_dump_path]
    - [`cache_dir`][vllm.config.CompilationConfig.cache_dir]
    - [`backend`][vllm.config.CompilationConfig.backend]
    - [`custom_ops`][vllm.config.CompilationConfig.custom_ops]
    - [`splitting_ops`][vllm.config.CompilationConfig.splitting_ops]
    - [`compile_mm_encoder`][vllm.config.CompilationConfig.compile_mm_encoder]
- CudaGraph capture:
    - [`cudagraph_mode`][vllm.config.CompilationConfig.cudagraph_mode]
    - [`cudagraph_capture_sizes`]
    [vllm.config.CompilationConfig.cudagraph_capture_sizes]
    - [`max_cudagraph_capture_size`]
    [vllm.config.CompilationConfig.max_cudagraph_capture_size]
    - [`cudagraph_num_of_warmups`]
    [vllm.config.CompilationConfig.cudagraph_num_of_warmups]
    - [`cudagraph_copy_inputs`]
    [vllm.config.CompilationConfig.cudagraph_copy_inputs]
- Inductor compilation:
    - [`compile_sizes`][vllm.config.CompilationConfig.compile_sizes]
    - [`compile_ranges_split_points`]
        [vllm.config.CompilationConfig.compile_ranges_split_points]
    - [`inductor_compile_config`]
    [vllm.config.CompilationConfig.inductor_compile_config]
    - [`inductor_passes`][vllm.config.CompilationConfig.inductor_passes]
    - custom inductor passes

Why we have different sizes for cudagraph and inductor:
- cudagraph: a cudagraph captured for a specific size can only be used
    for the same size. We need to capture all the sizes we want to use.
- inductor: a graph compiled by inductor for a general shape can be used
    for different sizes. Inductor can also compile for specific sizes,
    where it can have more information to optimize the graph with fully
    static shapes. However, we find the general shape compilation is
    sufficient for most cases. It might be beneficial to compile for
    certain small batchsizes, where inductor is good at optimizing.

#### `--cudagraph-capture-sizes`

:   Sizes to capture cudagraph.
    - None (default): capture sizes are inferred from vllm config.
    - list[int]: capture sizes are specified as given.

#### `--max-cudagraph-capture-size`

:   The maximum cudagraph capture size.

    If cudagraph_capture_sizes is specified, this will be set to the largest
    size in that list (or checked for consistency if specified). If
    cudagraph_capture_sizes is not specified, the list of sizes is generated
    automatically following the pattern:

        [1, 2, 4] + list(range(8, 256, 8)) + list(
        range(256, max_cudagraph_capture_size + 1, 16))

    If not specified, max_cudagraph_capture_size is set to min(max_num_seqs*2,
    512) by default. This voids OOM in tight memory scenarios with small
    max_num_seqs, and prevents capture of many large graphs (>512) that would
    greatly increase startup time with limited performance benefit.


### VllmConfig

Dataclass which contains all vllm-related configuration. This
simplifies passing around the distinct configurations in the codebase.

#### `--speculative-config`

:   Speculative decoding configuration.

    Should either be a valid JSON string or JSON keys passed individually.

#### `--kv-transfer-config`

:   The configurations for distributed KV cache transfer.

    Should either be a valid JSON string or JSON keys passed individually.

#### `--kv-events-config`

:   The configurations for event publishing.

    Should either be a valid JSON string or JSON keys passed individually.

#### `--ec-transfer-config`

:   The configurations for distributed EC cache transfer.

    Should either be a valid JSON string or JSON keys passed individually.

#### `--compilation-config`, `-cc`

:   `torch.compile` and cudagraph capture configuration for the model.

    As a shorthand, one can append compilation arguments via
    -cc.parameter=argument such as `-cc.mode=3` (same as `-cc='{"mode":3}'`).

    You can specify the full compilation config like so:
    `{"mode": 3, "cudagraph_capture_sizes": [1, 2, 4, 8]}`

    Should either be a valid JSON string or JSON keys passed individually.

:   Default: `{'level': None, 'mode': None, 'debug_dump_path': None, 'cache_dir': '', 'compile_cache_save_format': 'binary', 'backend': 'inductor', 'custom_ops': [], 'splitting_ops': None, 'compile_mm_encoder': False, 'compile_sizes': None, 'compile_ranges_split_points': None, 'inductor_compile_config': {'enable_auto_functionalized_v2': False, 'combo_kernels': True, 'benchmark_combo_kernel': True}, 'inductor_passes': {}, 'cudagraph_mode': None, 'cudagraph_num_of_warmups': 0, 'cudagraph_capture_sizes': None, 'cudagraph_copy_inputs': False, 'cudagraph_specialize_lora': True, 'use_inductor_graph_partition': None, 'pass_config': {}, 'max_cudagraph_capture_size': None, 'dynamic_shapes_config': {'type': <DynamicShapesType.BACKED: 'backed'>, 'evaluate_guards': False, 'assume_32_bit_indexing': False}, 'local_cache_dir': None, 'static_all_moe_layers': []}`

#### `--attention-config`, `-ac`

:   Attention configuration.

    Should either be a valid JSON string or JSON keys passed individually.

:   Default: `AttentionConfig(backend=None, flash_attn_version=None, use_prefill_decode_attention=False, flash_attn_max_num_splits_for_cuda_graph=32, use_cudnn_prefill=False, use_trtllm_ragged_deepseek_prefill=True, use_trtllm_attention=None, disable_flashinfer_prefill=False, disable_flashinfer_q_quantization=False)`

#### `--additional-config`

:   Additional config for specified platform. Different platforms may
    support different configs. Make sure the configs are valid for the platform
    you are using. Contents must be hashable.

:   Default: `{}`

#### `--structured-outputs-config`

:   Structured outputs configuration.

    Should either be a valid JSON string or JSON keys passed individually.

:   Default: `StructuredOutputsConfig(backend='auto', disable_fallback=False, disable_any_whitespace=False, disable_additional_properties=False, reasoning_parser='', reasoning_parser_plugin='', enable_in_reasoning=False)`

#### `--profiler-config`

:   Profiling configuration.

    Should either be a valid JSON string or JSON keys passed individually.

:   Default: `ProfilerConfig(profiler=None, torch_profiler_dir='', torch_profiler_with_stack=True, torch_profiler_with_flops=False, torch_profiler_use_gzip=True, torch_profiler_dump_cuda_time_total=True, torch_profiler_record_shapes=False, torch_profiler_with_memory=False, ignore_frontend=False, delay_iterations=0, max_iterations=0)`

#### `--optimization-level`

:   The optimization level. These levels trade startup time cost for
    performance, with -O0 having the best startup time and -O3 having the best
    performance. -02 is used by defult. See  OptimizationLevel for full
    description.

:   Default: `2`

