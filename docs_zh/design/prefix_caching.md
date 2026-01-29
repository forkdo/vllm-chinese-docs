# 自动前缀缓存

前缀缓存 kv-cache 块是 LLM 推理中一种流行的优化技术，用于避免重复的提示计算。其核心思想很简单 – 我们缓存已处理请求的 kv-cache 块，并在新请求具有与先前请求相同前缀时重用这些块。由于前缀缓存几乎是一种免费午餐，且不会改变模型输出，因此已被许多公共端点（例如 OpenAI、Anthropic 等）和大多数开源 LLM 推理框架（例如 SGLang）广泛使用。

虽然实现前缀缓存的方式有多种，但 vLLM 选择了一种基于哈希的方法。具体来说，我们通过块中的令牌和块前前缀中的令牌对每个 kv-cache 块进行哈希：

```text
                    Block 1                  Block 2                  Block 3
         [A gentle breeze stirred] [the leaves as children] [laughed in the distance]
Block 1: |<--- block tokens ---->|
Block 2: |<------- prefix ------>| |<--- block tokens --->|
Block 3: |<------------------ prefix -------------------->| |<--- block tokens ---->|
```

在上面的例子中，第一个块的 KV 缓存可以通过令牌“A gentle breeze stirred”唯一标识。第三个块可以通过块中的令牌“laughed in the distance”以及前缀令牌“A gentle breeze stirred the leaves as children”唯一标识。因此，我们可以构建块哈希 `hash(tuple[components])`，其中 components 包括：

* 父哈希值：父哈希块的哈希值。
* 块令牌：此块中令牌的元组。包含确切令牌的原因是减少潜在的哈希冲突。
* 额外哈希：其他值，用于使此块唯一，例如 LoRA ID、多模态输入哈希（见下例）和用于在多租户环境中隔离缓存的缓存盐。

!!! note "注意 1"
    我们只缓存完整的块。

!!! note "注意 2"
    在之前的版本中，哈希键不能保证无冲突。从 v0.11 开始，默认哈希算法是 `sha256`，这解决了冲突风险。

    对于 `vllm serve`，您可以通过 `--prefix-caching-hash-algo` 控制哈希算法：
    - `sha256`（默认）：使用 Python 的 `pickle` 进行序列化。不同 Python 或 vLLM 版本之间的哈希可能不可重现。
    - `sha256_cbor`：使用 `cbor2` 进行序列化，提供可重现的、跨语言兼容的哈希。建议在跨环境确定性缓存中使用。
    - `xxhash`：使用 Pickle 序列化和 xxHash（128 位）进行更快的非加密哈希。需要可选的 `xxhash` 包。重要提示：使用不被认为是加密安全的哈希算法理论上会增加哈希冲突的风险，这可能在多租户环境中导致未定义行为，甚至泄露私有信息。即使冲突仍然非常不可能，但在启用之前需要权衡安全风险容忍度与性能优势。
    - `xxhash_cbor` 结合规范化的 CBOR 序列化和 xxHash，实现可重现的哈希。需要可选的 `xxhash` 包。

**多模态输入的哈希示例**  
在本例中，我们说明了多模态输入（例如图像）如何与前缀缓存配合工作。假设我们有以下消息的请求：

```text
messages = [
    {"role": "user",
     "content": [
         {"type": "text",
          "text": "What's in this image?"
         },
         {"type": "image_url",
          "image_url": {"url": image_url},
         },
    ]},
]
```

它将变成以下提示：

```text
Prompt:
    <s>[INST]What's in this image?\n[IMG][/INST]

Tokenized prompt:
    [1, 3, 7493, 1681, 1294, 1593, 3937, 9551, 10, 4]

Prompt with placeholders (<P>):
    [1, 3, 7493, 1681, 1294, 1593, 3937, 9551, <P>, <P>, ..., <P>, 4]
```

我们可以看到，在分词之后，`[IMG]` 将被替换为一系列占位符令牌，并且这些占位符将在预填充期间被图像嵌入替换。前缀缓存支持这种情况的挑战是，我们需要区分图像和占位符。为了解决这个问题，我们对前端图像处理器生成的图像哈希进行编码。例如，上述提示中块的哈希将是（假设块大小为 16，且我们有 41 个占位符令牌）：

```text
Block 0
    Parent hash: None
    Token IDs: 1, 3, 7493, 1681, 1294, 1593, 3937, 9551, <p>, ..., <p>
    Extra hash: <image hash>
Block 1
    Parent hash: Block 0 hash
    Token IDs: <p>, ..., <p>
    Extra hash: <image hash>
Block 2
    Parent hash: Block 1 hash
    Token IDs: <p>, ..., <p>
    Extra hash: <image hash>
Block 3
    Parent hash: Block 2 hash
    Token IDs: <p>, ..., <p>, 4
    Extra hash: <image hash>
```

在本文档的其余部分，我们首先介绍 vLLM v1 中用于前缀缓存的数据结构，然后介绍主要 KV 缓存操作符（例如分配、追加、释放、驱逐）的前缀缓存工作流程。最后，我们使用一个示例来说明端到端的前缀缓存工作流程。

**安全的缓存隔离**  
为了在共享环境中提高隐私性，vLLM 支持通过可选的每请求盐值来隔离前缀缓存重用。通过在请求中包含 `cache_salt`，此值会被注入到第一个块的哈希中，确保只有具有相同盐值的请求才能重用缓存的 KV 块。这防止了基于时间的攻击，攻击者可能通过观察延迟差异来推断缓存内容。这在不损害性能的情况下提供了保护。

```json
{
  "messages": [
    {"role": "system", "content": "You are a helpful assistant."},
    {"role": "user", "content": "Here is a document with details about the world series: ..."},
    {"role": "user", "content": "Who won the world series in 2020?"}
  ],
  "cache_salt": "your-cache-salt"
}
```

通过此设置，缓存共享仅限于明确同意使用共同盐值的用户或请求，这允许在信任组内重用缓存，同时隔离其他租户。

## 数据结构

vLLM v1 中的前缀缓存在 KV 缓存管理器中实现。基本构建块是“Block”数据类（简化版）：

```python
class KVCacheBlock:
    # 块 ID（不可变）
    block_id: int
    # 块哈希（在块满时分配，
    # 在块被驱逐时重置）。
    block_hash: BlockHash
    # 当前使用此块的请求数量。
    ref_cnt: int

    # 指针，用于为自由队列构建双向链表。
    prev_free_block: "KVCacheBlock | None" = None
    next_free_block: "KVCacheBlock | None" = None
```

有两个设计要点需要强调：

1. 我们在初始化 KV 缓存管理器时分配所有 KVCacheBlock 作为块池。这避免了 Python 对象创建的开销，并可以轻松跟踪所有块。  
2. 我们在 KVCacheBlock 中直接引入双向链表指针，以便直接构建自由队列。这带来了两个好处：  
    1. 我们可以以 O(1) 复杂度将中间元素移动到尾部。  
    2. 我们可以避免引入另一个 Python 队列（例如 `deque`），它对元素有包装器。

因此，当 KV 缓存管理器初始化时，我们将拥有以下组件：

![组件概览](../assets/design/prefix_caching/overview.png)

* 块池：KVCacheBlock 列表。  
* 自由块队列：仅存储头部和尾部块的指针以进行操作。  
* 缓存块：从哈希键到块 ID 的映射。  
* 请求块：从请求 ID 到已分配块 ID 的映射。

## 操作

### 块分配

**新请求：** 调度器为新请求分配 KV 缓存块的调度工作流程：

1. 调度器调用 `kv_cache_manager.get_computed_blocks()` 来获取已经计算过的块序列。这是通过哈希请求中的提示词标记并查找缓存块来实现的。  
2. 调度器调用 `kv_cache_manager.allocate_slots()`。它执行以下步骤：  
    1. 计算新需要的块数量，如果没有足够的块可供分配则直接返回。  
    2. “标记”已计算的块。它将已计算块的引用计数增加 1，并在该块未被其他请求使用时将其从空闲队列中移除。这是为了避免这些计算过的块被驱逐。请参见下一节中的示例以作说明。  
    3. 通过弹出空闲队列的头部来分配新块。如果头部块是缓存块，这也将“驱逐”该块，使其无法再被其他请求重用。  
    4. 如果分配的块已满令牌，则立即将其添加到缓存块中，以便该批次中的其他请求可以重用该块。

**运行中的请求：** 调度器调度一个正在运行的请求并分配 KV 缓存块的工作流程：

1. 调度器调用 `kv_cache_manager.allocate_slots()`。它执行以下步骤：  
    1. 计算新需要的块数量，如果没有足够的块可供分配则直接返回。  
    2. 通过弹出空闲队列的头部来分配新块。如果头部块是缓存块，这也将“驱逐”该块，使其无法再被其他请求重用。  
    3. 向现有块以及新块中的槽位追加令牌 ID。如果一个块已满，我们将其添加到缓存块中以缓存它。

**重复的块**  
假设块大小为 4，您发送一个请求（请求 1）带有提示词 ABCDEF，解码长度为 3：

```text
提示词：[A, B, C, D, E, F]
输出：[G, H, I]

时间 0：
  令牌：[A, B, C, D, E, F, G]
  块表：[0 (ABCD), 1 (EFG)]
  缓存块：0
时间 1：
  令牌：[A, B, C, D, E, F, G, H]
  块表：[0 (ABCD), 1 (EFGH)]
  缓存块：0, 1
时间 2：
  令牌：[A, B, C, D, E, F, G, H, I]
  块表：[0 (ABCD), 1 (EFGH), 2 (I)]
  缓存块：0, 1
```

现在块 0 和块 1 已被缓存，我们再次发送相同的请求（请求 2）并使用贪婪采样，因此它将产生与请求 1 完全相同的输出：

```text
提示词：[A, B, C, D, E, F]
输出：[G, H, I]

时间 0：
  令牌：[A, B, C, D, E, F, G]
  块表：[0 (ABCD), 3 (EFG)]
  缓存块：0, 1
时间 1：
  令牌：[A, B, C, D, E, F, G, H]
  块表：[0 (ABCD), 3 (EFGH)]
  缓存块：0, 1, 3
```

可以看到，块 3 是一个全新的满块并被缓存。然而，它与块 1 是重复的，意味着我们缓存了相同的块两次。在 v0 中，当我们检测到块 3 是重复的时，我们会释放块 3 并让请求 2 使用块 1，因此在时间 1 时其块表变为 `[0, 1]`。但在 vLLM v1 中，块表是只追加的，意味着不允许将块表从 `[0, 3]` 更改为 `[0, 1]`。因此，我们将为哈希键 E-H 拥有重复的块。这种重复将在请求被释放时被消除。

### 释放

当一个请求完成时，如果没有其他请求在使用这些块（引用计数 = 0），我们释放其所有块。在此示例中，我们释放请求 1 和与其关联的块 2、3、4、8。我们可以看到，释放的块按*逆序*添加到空闲队列的尾部。这是因为请求的最后一个块需要哈希更多令牌，被其他请求重用的可能性较小。因此，它应该优先被驱逐。

![请求释放后的空闲队列](../assets/design/prefix_caching/free.png)

### 驱逐（LRU）

当空闲队列的头部块（最近最少使用的块）是缓存块时，我们必须驱逐该块，以防止它被其他请求使用。具体来说，驱逐包括以下步骤：

1. 从空闲队列的头部弹出该块。这是要被驱逐的 LRU 块。  
2. 从缓存块中移除该块 ID。  
3. 移除该块的哈希。

## 示例

在此示例中，我们假设块大小为 4（每个块可缓存 4 个令牌），并且 KV 缓存管理器中总共有 10 个块。

**时间 1：缓存为空且新请求到来。** 我们分配 4 个块。其中 3 个块已满并被缓存。第四个块部分填充，其中有 3 个令牌。

![示例时间 1](../assets/design/prefix_caching/example-time-1.png)

**时间 2：请求 0 使块 3 满，并请求新块以继续解码。** 我们缓存块 3 并分配块 4。

![示例时间 2](../assets/design/prefix_caching/example-time-3.png)

**时间 3：请求 1 带有 14 个提示词令牌到来，其中前 10 个令牌与请求 0 相同。** 我们可以看到，只有前 2 个块（8 个令牌）命中缓存，因为第 3 个块只匹配了 4 个令牌中的 2 个。

![示例时间 3](../assets/design/prefix_caching/example-time-4.png)

**时间 4：请求 0 完成并释放。** 块 2、3 和 4 按逆序添加到空闲队列（但块 2 和 3 仍被缓存）。块 0 和 1 没有添加到空闲队列，因为它们仍被请求 1 使用。

![示例时间 4](../assets/design/prefix_caching/example-time-5.png)

**时间 5：请求 1 完成并释放。**

![示例时间 5](../assets/design/prefix_caching/example-time-6.png)

**时间 6：请求 2 带有 29 个提示词令牌到来，其中前 12 个令牌与请求 0 相同。** 注意，尽管空闲队列中的块顺序是 `7 - 8 - 9 - 4 - 3 - 2 - 6 - 5 - 1 - 0`，但在分配前被“标记”的缓存命中块（即 0、1、2）从队列中被移除，因此空闲队列变为 `7 - 8 - 9 - 4 - 3 - 6 - 5`。因此，分配的块为 0（已缓存）、1（已缓存）、2（已缓存）、7、8、9、4、3（已被驱逐）。

![示例时间 6](../assets/design/prefix_caching/example-time-7.png)