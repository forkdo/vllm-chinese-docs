# 分离式预填充（实验性）

本页面向您介绍 vLLM 中的分离式预填充功能。

!!! note
    此功能为实验性功能，可能会发生变化。

## 为什么需要分离式预填充？

主要有两个原因：

- **分别调优首字节延迟（TTFT）和字间延迟（ITL）**。分离式预填充将 LLM 推理的预填充和解码阶段放在不同的 vLLM 实例中。这使您可以为调优 TTFT 而不影响 ITL，或为调优 ITL 而不影响 TTFT，分配不同的并行策略（例如 `tp` 和 `pp`）。
- **控制尾部 ITL**。没有分离式预填充时，vLLM 可能在解码一个请求期间插入一些预填充任务。这会增加尾部延迟。分离式预填充可以帮助您解决此问题并控制尾部 ITL。使用适当的块大小进行分块预填充也可以实现相同目标，但在实践中很难确定正确的块大小值。因此，分离式预填充是控制尾部 ITL 更可靠的方式。

!!! note
    分离式预填充不会提高吞吐量。

## 使用示例

现在支持 9 种类型的连接器：

- **ExampleConnector**：参考 [examples/disaggregated/example_connector/run.sh](../../examples/disaggregated/example_connector/run.sh) 了解 ExampleConnector 分离式预填充的示例用法。
- **LMCacheConnectorV1**：参考 [examples/disaggregated/lmcache/disagg_prefill_lmcache_v1/disagg_example_nixl.sh](../../examples/disaggregated/lmcache/disagg_prefill_lmcache_v1/disagg_example_nixl.sh) 了解 LMCacheConnectorV1 分离式预填充的示例用法，该连接器使用 NIXL 作为底层 KV 传输。LMCache 还通过 `LMCacheMPConnector` 提供多进程 (MP) 模式，其中独立的 `lmcache server` 由一个或多个 vLLM 实例共享 KV 缓存；参见 [LMCache 示例](../../examples/disaggregated/lmcache/README.md) 和 [LMCache 文档](https://docs.lmcache.ai) 了解设置方法。
- **NixlConnector**：参考 [tests/v1/kv_connector/nixl_integration/run_accuracy_test.sh](../../tests/v1/kv_connector/nixl_integration/run_accuracy_test.sh) 了解 NixlConnector 分离式预填充的示例用法，该连接器支持完全异步的发送/接收。详细用法请参阅 [NixlConnector 使用指南](nixl_connector_usage.md)。有关功能兼容性详情，参见 [NixlConnector 兼容性矩阵](nixl_connector_compatibility.md)。您可以指定一个或多个 NIXL 传输后端，例如：

  ```bash
  --kv-transfer-config '{"kv_connector":"NixlConnector","kv_role":"kv_both", "kv_buffer_device":"cuda", "kv_connector_extra_config":{"backends":["UCX", "GDS"]}}'
  ```

- **MooncakeConnector**：参考 [examples/disaggregated/mooncake_connector/run_mooncake_connector.sh](../../examples/disaggregated/mooncake_connector/run_mooncake_connector.sh) 了解 MooncakeConnector 分离式预填充的示例用法。详细用法请参阅 [MooncakeConnector 使用指南](mooncake_connector_usage.md)。
- **MoRIIOConnector**（仅限 ROCm）：参见 [MoRI-IO 使用指南](moriio_connector_usage.md) 了解示例用法和详细文档。
- **MultiConnector**：利用 KVTransferConfig 中已存在的 kv_connector_extra_config: dict[str, Any]，将我们想要的所有连接器存储在有序的 kwargs 列表中。例如：

  ```bash
  --kv-transfer-config '{"kv_connector":"MultiConnector","kv_role":"kv_both","kv_connector_extra_config":{"connectors":[{"kv_connector":"NixlConnector","kv_role":"kv_both"},{"kv_connector":"ExampleConnector","kv_role":"kv_both","kv_connector_extra_config":{"shared_storage_path":"local_storage"}}]}}'
  ```

- **OffloadingConnector**：启用将 KV 数据卸载到 CPU 内存，自定义 CPU 块大小（以 tokens 为单位）和分配的总 CPU 内存字节数：

  ```bash
  --kv-transfer-config '{"kv_connector":"OffloadingConnector","kv_role":"kv_both","kv_connector_extra_config":{"block_size": 64, "cpu_bytes_to_use": 1000000000}}'
  ```

  对于多级卸载（例如，CPU + 文件系统层）和完整的配置参考，参见 [KV 卸载使用指南](kv_offloading_usage.md)。

- **FlexKVConnectorV1**：参考 [examples/disaggregated/flexkv_connector/prefix_caching_flexkv.py](../../examples/disaggregated/flexkv_connector/prefix_caching_flexkv.py) 了解 FlexKVConnectorV1 的示例用法。FlexKV 是一个用于超大规模 LLM 推理的分布式 KV 存储和多层缓存管理系统。

  ```bash
  --kv-transfer-config '{"kv_connector":"FlexKVConnectorV1","kv_role":"kv_both"}'
  ```

## 在解码时重用预填充 token IDs

!!! note
    这适用于在 `/v1/chat/completions` 端点上运行的分离式预填充和解码服务，使用如上使用示例中配置的 KV 连接器。这是实验性的，可能会发生变化。

在分离式服务中，预填充和解码阶段都会从 `messages` 渲染聊天提示并对其进行分词。由于预填充阶段已经生成了 token IDs，解码阶段可以重用它们并跳过自己的模板化和分词。输出与其他正常的聊天补全相同：它会被解码为文本，工具调用和推理解析、流式和结构化输出约束仍然适用。

token IDs 通过 `kv_transfer_params` 传递给解码阶段，该字典已附加到解码请求以协调传输：

1. 使用启用的 `return_token_ids` 发送预填充请求，并从响应中读取 `prompt_token_ids`。
2. 在解码请求上将 `kv_transfer_params["prompt_token_ids"]` 设置为这些 IDs。`messages` 仍然是必需的，但当 IDs 存在时不会对其内容进行分词。

```python
prefill = client.chat.completions.create(
    model=model,
    messages=messages,
    extra_body={"return_token_ids": True, "kv_transfer_params": {"do_remote_decode": True}},
)
ids = prefill.prompt_token_ids

decode = client.chat.completions.create(
    model=model,
    messages=messages,
    stream=True,
    extra_body={"kv_transfer_params": {"do_remote_prefill": True, "prompt_token_ids": ids}},
)
```

## 开发

我们通过运行 2 个 vLLM 实例来实现分离式预填充。一个用于预填充（我们称之为预填充实例），一个用于解码（我们称之为解码实例），然后使用连接器将预填充的 KV 缓存和结果从预填充实例传输到解码实例。

所有分离式预填充实现都位于 `vllm/distributed/kv_transfer` 下。

分离式预填充的关键抽象：

- **Connector**：Connector 允许 **kv consumer** 从 **kv producer** 获取一批请求的 KV 缓存。
- **LookupBuffer**：LookupBuffer 提供两个 API：`insert` KV 缓存和 `drop_select` KV 缓存。`insert` 和 `drop_select` 的语义类似于 SQL，其中 `insert` 将 KV 缓存插入到缓冲区，`drop_select` 返回匹配给定条件的 KV 缓存并将其从缓冲区中删除。
- **Pipe**：用于张量传输的单向 FIFO 管道。它支持 `send_tensor` 和 `recv_tensor`。

!!! note
    `insert` 是非阻塞操作，但 `drop_select` 是阻塞操作。

下面的图展示了上述 3 个抽象是如何组织的：

![分离式预填充抽象](../assets/features/disagg_prefill/abstraction.jpg)

分离式预填充的工作流程如下：

![分离式预填充工作流程](../assets/features/disagg_prefill/overview.jpg)

图中的 `buffer` 对应 LookupBuffer 中的 `insert` API，`drop_select` 对应 LookupBuffer 中的 `drop_select` API。

现在，vLLM 中的每个进程都将有一个对应的连接器。具体来说，我们有：

- 调度器连接器：位于与调度器进程同一进程中的连接器。它调度 KV 缓存传输操作。
- 工作连接器：位于工作进程中的连接器。它们执行 KV 缓存传输操作。

下面的图展示了上述 2 个连接器是如何组织的：

![分离式预填充高层设计](../assets/features/disagg_prefill/high_level_design.png)

下图展示了工作连接器如何与注意力模块配合，实现逐层的 KV 缓存存储和加载：

![分离式预填充工作流程](../assets/features/disagg_prefill/workflow.png)

## 第三方贡献

分离式预填充与基础设施高度相关，因此 vLLM 依赖第三方连接器来实现生产级别的分离式预填充（vLLM 团队将积极审查并合并第三方连接器的新 PR）。

我们推荐三种实现方式：

- **完全自定义连接器**：实现您自己的 `Connector`，调用第三方库发送和接收 KV 缓存，等等（比如编辑 vLLM 的模型输入以执行自定义预填充）。这种方法为您提供最大控制权，但存在与未来 vLLM 版本不兼容的风险。
- **数据库类连接器**：实现您自己的 `LookupBuffer`，支持 `insert` 和 `drop_select` API，就像 SQL 一样。
- **分布式 P2P 连接器**：实现您自己的 `Pipe`，支持 `send_tensor` 和 `recv_tensor` API，就像 `torch.distributed` 一样。