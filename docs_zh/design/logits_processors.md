# Logits Processors

!!! important
    某些 logits processors 的设计更改仍在进行中，API 在不久的将来可能会发生变化。我们希望尽快稳定这部分 API。

本文档描述了 vLLM 引擎如何与 logits processors 交互，以及 vLLM 支持的用于实现 logits processors 的编程模型。

## Logits Processors 背景知识

Logits processor 用于调整下一个 token 的概率分布，通常目的是引导模型产生期望的行为。

在 vLLM 中，logits processors 以 batch 粒度运行。在引擎的每一步中，logits processor 会消费一个由模型输出的 `(num_requests) x (vocab_size)` 的原始 logits 张量。对于所有启用了 logits processor 的请求，logits processor 会对 logits 张量中对应的行应用变换，同时保持其他行不变。变换后的 logits 张量随后会传递给 softmax 函数。

## vLLM 引擎中的 Logits Processors

vLLM 引擎的持久化 batch 数据结构维护了一个已加载的 logits processors 列表。

为了对整个 batch 进行操作，每个 logits processor 可能会维护关于 batch 中请求的元数据（即每个请求的 logits-processor-specific 配置设置）。因此，logits processors 是有状态的。

在引擎的每一步中，vLLM 引擎会 (1) 更新每个 logits processor 的内部状态，以及 (2) 将 logits processors 应用于模型输出的 logits。

### 更新 Logits Processor 内部状态

在引擎每一步开始时，持久化 batch 可能会根据调度器的输出添加、丢弃和/或重新排序请求。在持久化 batch 完成重组后，vLLM 引擎会调用每个 logits processor 的 `update_state()` 方法。这是为了确保 logits processors 的内部状态在引擎步骤开始时与新的持久化 batch 状态保持一致。

下面的伪代码展示了 vLLM 持久化 batch 如何通知每个 logits processor batch 状态变化的过程：

??? code "Model Runner 更新 Logits Processor 状态"

    ``` python
    # gpu_model_runner.py

    class GPUModelRunner(...):

        ...

        def execute_model(self, scheduler_output, ...):
            self._update_states(scheduler_output)

            ...

        def _update_states(...):

            ...

            # ...更新持久化 batch 以反映新的/已完成的请求以及 batch 内请求的重新排序...

            ...

            self.input_batch.refresh_metadata()


    # gpu_input_batch.py

    class InputBatch:

        ...

        def refresh_metadata(self):

            ...

            # 更新每个 logits processor 的状态以反映持久化 batch 状态
            batch_update = self.batch_update_builder.get_and_reset(self.num_reqs)
            for logit_proc in self.logitsprocs.all:
                logit_proc.update_state(batch_update)

            ...


    # vllm/v1/sample/logits_processor/interface.py

    @dataclass(frozen=True)
    class BatchUpdate:
        # 传递给 logits processors 的 update_state() 方法的 batch 状态变化数据结构

        batch_size: int

        removed: Sequence[RemovedRequest]
        added: Sequence[AddedRequest]
        moved: Sequence[MovedRequest]
    
    ```

### 将 Logits Processors 应用于模型输出的 Logits

在更新持久化 batch 状态后，vLLM model runner 执行模型推理以获得 logits。然后，model runner 调用 sampler 处理这些 logits。反过来，sampler 操作的一部分是调用 logits processors 的 `apply()` 方法对模型输出的 logits 进行处理，从而得到变换后的 logits（`apply()` 方法可以就地修改 logits 或非就地修改，尽管就地修改更节省内存）。这个过程如下面的伪代码所示。

请注意，sampler 将通过 `SamplingMetadata.logitsprocs` 访问 logits processors。当 vLLM 引擎构建 `SamplingMetadata` 时（下面的代码中未显示），logits processors 列表的引用会从持久化 batch 数据结构传递到 `SamplingMetadata`。

??? code "将 logits processors 应用于模型输出的 logits"

    ``` python
    # gpu_model_runner.py

    class GPUModelRunner(...):

        ...

        def execute_model(self, scheduler_output, ...):
            # （在上一节中讨论过）
            self._update_states(scheduler_output)

            ...

            # ...运行模型推理以获得 logits...

            ...

            # 调用 sampler，它会应用 logits processors
            sampler_output = self.sampler(logits=logits,
                                          sampling_metadata=sampling_metadata)

            ...


    # sampler.py

    class Sampler(nn.Module):

        ...

        def forward(self, logits, sampling_metadata):

            ...

            # 对模型输出的 logits 应用非 argmax 不变的 logits processors
            for processor in (sampling_metadata.logitsprocs.non_argmax_invariant):
                logits = processor.apply(logits)

            sampled = self.sample(logits, sampling_metadata)

            ...

            # ...返回 sampler 输出数据结构...


        def sample(self, logits, sampling_metadata)

            ...

            # ...如果所有请求都是贪婪采样，则提前退出...

            ...

            # 应用 argmax 不变的 logits processors
            for processor in sampling_metadata.logitsprocs.argmax_invariant:
                logits = processor.apply(logits)

            ...

            # ...执行采样并返回采样结果...
    ``` 

在采样时，sampler 会检查持久化 batch 中的所有请求是否都采用贪婪采样。如果是这种情况，sampler 会通过跳过“argmax 不变”的 logits processors 来节省计算资源。在这里，“argmax”是 logits 张量中某一行具有最高 logit 值的 token ID 的简写（即模型对某个请求赋予最高权重的 token）。

* **argmax 不变的 logits processor** 是一种不会修改 argmax 的 logits processor（例如 Min-P）。例如，一个会屏蔽掉最低概率 token 的 logits processor 不会改变具有最大 logit 的 token ID。贪婪采样总是选择具有最高 logit 值的 token ID，因此从概念上讲，对于贪婪采样请求可以跳过 argmax 不变的 logits processor。

* **非 argmax 不变的 logits processor** 是一种可能会修改 argmax 的 logits processor。例如，一个在特定步数后屏蔽除 EOS 之外的所有 token 以强制解码终止的 logits processor 可能会最终屏蔽掉具有最大 logit 值的 token，从而改变 argmax。从概念上讲，这些 logits processor 不能为贪婪采样请求跳过。

vLLM logits processor 抽象要求引擎以 batch 粒度应用 logits processors；因此实际上，只有当整个 batch 都使用贪婪采样时，才能跳过 argmax 不变的 logits processors。

## Logits Processor 编程模型

前面的章节提到了 vLLM logits processors 必须支持的接口。本节将完整介绍实现与 vLLM 引擎兼容的 logits processors 的编程模型，包括 `LogitsProcessor` 基类及其接口方法，以及用于表示持久化 batch 状态变化的 `BatchUpdate` 数据结构，两者如下面的代码所示：

??? code "`LogitsProcessor` 基类和 `BatchUpdate` 数据结构"

    ``` python
    from abc import ABC, abstractmethod
    from collections.abc import Sequence
    from dataclasses import dataclass
    from enum import Enum, auto
    from typing import TYPE_CHECKING

    import torch

    from vllm import SamplingParams

    if TYPE_CHECKING:
        from vllm.config import VllmConfig
    ```

```python
class MoveDirectionality(Enum):
    # One-way i1->i2 req move within batch
    UNIDIRECTIONAL = auto()
    # Two-way i1<->i2 req swap within batch
    SWAP = auto()


# (index, params, prompt_tok_ids, output_tok_ids) tuples for new
# requests added to the batch.
AddedRequest = tuple[int, SamplingParams, list[int], list[int]]

# (index 1, index 2, directionality) tuples representing
# one-way moves or two-way swaps of requests in batch
MovedRequest = tuple[int, int, MoveDirectionality]

# Batch indices of any removed requests.
RemovedRequest = int


@dataclass(frozen=True)
class BatchUpdate:
    """Persistent batch state change info for logitsprocs"""
    batch_size: int  # Current num reqs in batch

    # Metadata for requests added to, removed from, and moved
    # within the persistent batch.
    #
    # Key assumption: the `output_tok_ids` list (which is an element of each
    # tuple in `added`) is a reference to the request's running output tokens
    # list; via this reference, the logits processors always see the latest
    # list of generated output tokens
    removed: Sequence[RemovedRequest]
    moved: Sequence[MovedRequest]
    added: Sequence[AddedRequest]


class LogitsProcessor(ABC):

    @abstractmethod
    def __init__(self, vllm_config: "VllmConfig", device: torch.device,
                is_pin_memory: bool) -> None:
        raise NotImplementedError

    @abstractmethod
    def apply(self, logits: torch.Tensor) -> torch.Tensor:
        raise NotImplementedError

    @abstractmethod
    def is_argmax_invariant(self) -> bool:
        """True if logits processor has no impact on the
        argmax computation in greedy sampling.
        NOTE: may or may not have the same value for all
        instances of a given LogitsProcessor subclass,
        depending on subclass implementation.
        """
        raise NotImplementedError

    @abstractmethod
    def update_state(
        self,
        batch_update: "BatchUpdate" | None,
    ) -> None:
        """Called when there are new output tokens, prior
        to each forward pass.

        Args:
            batch_update is non-None iff there have been
            changes to the batch makeup.
        """
        raise NotImplementedError

    @classmethod
    def validate_params(cls, sampling_params: SamplingParams):
        """Validate sampling params for this logits processor.

        Raise ValueError for invalid ones.
        """
        return None
```

vLLM 的 logits 处理器必须继承 `LogitsProcessor` 类，并至少定义以下方法：

* `__init__(self, vllm_config: VllmConfig, device: torch.device, is_pin_memory: bool)`
    * `vllm_config`: 引擎配置数据结构
    * `device`: 硬件加速器设备信息
    * `is_pin_memory`: 标志位，指示是否支持 pin memory 以支持 logits 处理器实现

* `apply(self, logits: torch.Tensor) -> torch.Tensor`:
    * 接收一个 `(num_requests) x (vocab_size)` 的 logits 张量 (`logits`)
    * 在批次粒度上应用 logits 处理器变换
    * 返回一个变换后的 `(num_requests) x (vocab_size)` logits 张量
    * 你可以就地或异地修改输入的 logits 处理器；就地修改更节省内存

* `is_argmax_invariant(self) -> bool`:
    * 如果 logits 处理器是 argmax 不变的（即从不改变给定请求中最高 logit 值的 token ID），则返回 `True`；如果 logits 处理器可能修改 argmax，则返回 `False`
    * `is_argmax_invariant()` 在启动时评估一次；如果为 `True`，当所有请求都使用贪心采样时，vLLM 将在给定步骤中跳过应用此 logits 处理器

* `update_state(self, batch_update: "BatchUpdate" | None) -> None`:
    * 接收一个 `BatchUpdate` 数据结构，表示当前引擎步骤开始时持久化批次的状态变化
    * 使用 `BatchUpdate` 的成员更新 logits 处理器内部状态
    * **注意：** 批次更新数据结构可能为 `None`，表示批次组成没有变化。在这种情况下，LogitsProcessor 可能仍希望根据其保留的已更新的 `output_token_ids` 列表来更新其状态（这些列表是在添加时保留的）。

* `validate_params(cls, sampling_params: SamplingParams)`:
    * 如果 `SamplingParams` 包含无效参数（尤其是 logits 处理器使用的自定义参数），则引发 `ValueError`
    * 当请求发送到入口点时，`validate_params()` 将验证 `SamplingParams`，并拒绝包含无效参数的请求

### `BatchUpdate` 数据结构

`BatchUpdate` 抽象将持久化批次建模为请求列表，支持以下操作来更改批次状态（请注意，下面提到的操作顺序反映了在 `update_state()` 中应处理它们的顺序）：

* **移除：** 移除（不替换）索引 `i` 处的请求

    * 移除操作在 `Batchupdate.removed` 中表示为一个 `int`（表示 `i`）

    * 移除索引处请求对批次的影响：

        ``` text
        批次: [A,B,C]
        移除 @ i:  1

        =>

        新批次: [A,x,C] # 丢弃 B 并留下一个空槽
        ```

* **添加：** 在索引 `i` 处添加（或替换现有请求）一个新请求。如果替换了请求，则应丢弃其关联状态。

    * 添加操作在 `Batchupdate.added` 中表示为一个元组：

        ``` text
        (index, new request SamplingParams, prompt token ids, output token ids)
        ```

    * `prompt token ids` 和 `output token ids` 分别是请求的 prompt token ids 和 output token ids 列表的引用。请注意，output token ids 列表在每个引擎步骤中增长，并且由于 output token ids 是通过引用传递的，因此这种增长对 logits 处理器是可见的。**这对于需要考虑已生成 token 的 LogitsProcessors 非常重要**。

    * 特定 logits 处理器子类的实现决定了添加请求元组中的字段是否以及如何消化为内部表示。例如，一个不使用 prompt 或 output token ids 的 logits 处理器可能只需要利用 `index` 和 `SamplingParams`，并丢弃其他元组字段

    * 如果索引 `i` 当前持有请求，则发生替换：

        ``` text
        批次: [A,B,C]
        要添加的新请求 @ i: D @ 1

        =>

        新批次: [A,D,C] # 添加 D，丢弃 B
        ```

    * 如果索引 `i` 当前不持有请求（因为 `i` 超出当前批次大小的范围）：

        ``` text
        批次: [A,B,C]
        要添加的新请求 @ i: D @ 3

        =>

        新批次: [A,B,C,D] # 添加 D，扩展批次
        ```

* **移动：** 将索引 `s` 处的请求移动到索引 `d`，或交换索引 `s` 和 `d` 处的请求

    * 移动操作在 `Batchupdate.moved` 中表示为一个元组：

        ``` text
        (s, d, UNIDIRECTIONAL or SWAP)
        ```

    * 如果移动指定为 `UNIDIRECTIONAL`：

        * 索引 `s` 处的请求移动到索引 `d`；索引 `s` 变为空槽

            ``` text
            批次: [A,x,C,D]
            单向移动 s -> d:  3 -> 1

            =>

            新批次: [A,D,C,x] # 将 D 移动到 1，在 3 处留下空槽
            ```

        * 如果另一个请求已经位于索引 `d`，则它将被替换并丢弃

            ``` text
            批次: [A,B,C,D]
            单向移动 s -> d:  3 -> 1

            =>

            新批次: [A,D,C,x] # 将 D 移动到 1，丢弃 B 并在 3 处留下空槽
            ```

    * 如果移动指定为 `SWAP`，则 `s` 和 `d` 处的请求交换索引

        ``` text
        批次: [A,B,C,D]
        交换移动 s <-> d:  3 <-> 1

        =>

        新批次: [A,D,C,B] # 交换 B 和 D
        ```

此外，`BatchUpdate` 数据结构还包含一个表示持久化批次在引擎步骤开始时的尺寸的字段（`batch_size`）。

### vLLM 引擎如何构建 `BatchUpdate` 数据结构

Logits 处理器的 `update_state()` 实现应遵循以下模型，以理解模型运行器如何更新持久化批次状态（此处使用 `BatchUpdate` 抽象来表达）：

1. 识别在当前引擎步骤中已完成的请求的索引

2. 识别在当前步骤中引入的新请求

3. 使用 Add 操作，按被替换请求的索引升序（从最低索引开始），将尽可能多的已完成请求替换为新请求

4. 根据新请求和已完成请求的相对数量：

    1. 如果新请求和已完成请求的数量相同，则进入下一步

    2. *如果新请求多于已完成请求：* 对剩余未替换已完成请求的新请求应用 Add 操作，以扩展批次。为这些新请求分配连续的索引，从 `current_max_batch_index + 1` 开始

    3. *如果新请求少于已完成请求：*

        * 对未被新请求替换的已完成请求应用 Remove 操作。这些被移除的请求的索引必然大于上一步中被替换的已完成请求的最大索引。Remove 操作可能导致批次处于非连续状态

        * **“压缩”批次使其连续：** 从最低索引的空槽位（由 Remove 操作导致）开始，将批次中当前最高的非空槽位通过单向移动（Unidirectional Move）填充到该空槽位。按照空槽位目标索引升序和非空槽位源索引降序的顺序，继续执行额外的单向移动操作，直到批次变为连续

        * **缩小批次：** 压缩批次的一个副作用是，由 Remove 操作产生的空槽位会被集中到批次数组的末尾。因此，在压缩后，更新 `BatchUpdate.batch_size` 以反映非空槽位的数量

5. 为提高效率对批次重新排序。根据注意力后端的实现和批次的当前特征，可能会应用零个或多个交换移动（Swap Move）操作来重新排序批次

注意事项：

* Logits 处理器的 `update_state()` 方法必须按以下顺序处理批次更新操作：移除（removes）、添加（adds）、移动（moves）

* Add 操作的索引参数指的是 Add 操作发生时的索引，即在任意 Move 操作之前
    * 示例：如果一个请求在索引 5 处被添加，然后与索引 3 交换，则 `BatchUpdate.added` 中的 Add 操作将与索引 5 关联，而不是 3
    * 换句话说，可以假设 Move 操作是在 Adds 和 Removes 之后应用的

* 可以假设 Move 操作按照它们在 `BatchUpdate.moved` 中出现的顺序应用

* 如果没有新请求/已完成请求，且没有批次重新排序，则 logits 处理器的批次更新将为 `None`

#### 示例：新请求少于已完成请求的批次更新

以下示例模拟了一个引擎步骤，其中引入了 1 个新请求，消除了 2 个已完成请求，此外注意力后端执行了一次交换以优化批次排序。

``` text
批次状态（引擎步骤开始时）：[A,B,C,D]
批次大小：4

新请求：E

已完成请求：A, C

处理步骤（使用 BatchUpdate 抽象）：

1. 在索引 0 处添加 E

[E,B,C,D] # 丢弃 A
批次大小：4

2. 在索引 2 处移除

[E,B,x,D] # 丢弃 C，索引 2 处出现空槽位
批次大小：4

3. 通过单向移动 3 -> 2 操作压缩批次并缩小批次

[E,B,D] x # 空槽位现在在批次之外
批次大小：3

4. 注意力后端优化：通过交换 0 <-> 1 重新排序批次

[B,E,D]
批次大小：3

```

生成的 `BatchUpdate` 数据结构如下所示：

``` text
BatchUpdate 实例
* added: [(0,E's SamplingParams,E's prompt tokens ref,E's output tokens ref)]
* removed: [2] # 请求 C 被移除且未被替换
* moved: [(3,2,UNIDIRECTIONAL),(0,1,SWAP)]
```

#### 示例：新请求多于已完成请求的批次更新

以下示例模拟了一个引擎步骤，其中引入了 2 个新请求，消除了 1 个已完成请求，此外注意力后端执行了一次交换以优化批次排序。

``` text
批次状态（引擎步骤开始时）：[A,B,C,D]
批次大小：4

新请求：E,F

已完成请求：C

处理步骤（使用 BatchUpdate 抽象）：

1. 在索引 2 处添加 E

[A,B,E,D] # 丢弃 C
批次大小：4

2. 在索引 4 处添加 F（当前最大批次索引 + 1）

[A,B,E,D,F] # 批次扩展 1
批次大小：5

4. 注意力后端优化：通过交换 0 <-> 1 重新排序批次

[B,A,E,D,F]
批次大小：5

```

注意，此处跳过了批次压缩，因为 Remove 操作没有留下任何空槽位。

生成的 `BatchUpdate` 数据结构如下所示：

``` text
BatchUpdate 实例
* added: [(2,E's SamplingParams,E's prompt tokens ref,E's output tokens ref),(4,F's SamplingParams,F's prompt tokens ref,F's output tokens ref)]
* removed: [] # 没有请求被移除且未被替换
* moved: [(0,1,SWAP)]
```

## 如何在 vLLM 中引入新的 Logits 处理器

### 编写内置 Logits 处理器的最佳实践

* 编写高效的 `apply()` 和 `update_state()` 实现，考虑到 logits 处理器是以批次粒度运行的
    * 例如，您可以使用高效的向量化操作来实现 `apply()`，或在 `update_state()` 中更新内部状态向量
    * 但是，如果您认为某个 logits 处理器可能很少被使用，则可以使用请求状态的“稀疏”表示，即该类可以使用字典来表示请求配置，仅存储启用该 logits 处理器的请求的元数据

* 由 logits 处理器作者决定：

    1. **配置 logits 处理器对特定请求行为的每个请求属性。** 例如，如果您正在为 vLLM 编写新的内置 logits 处理器，您可能需要也可能不需要向 `SamplingParams` 和 vLLM REST API 添加额外字段

    2. **logits 处理器在每个请求基础上启用或禁用的条件。** 除非您的意图是让内置 logits 处理器始终对所有请求生效，否则您应以一种方式编写 logits 处理器，使其可能对特定请求禁用，例如通过将参数默认值设为 `None`，或传递特定的无操作参数值（如 `0.0`）。尝试为禁用 logits 处理器的请求节省计算和内存

    3. **在批次级别短路 logits 处理器的条件。** 即使您已定义了在请求级别禁用内置 logits 处理器的方法，也可能难以将其转化为计算节省，例如，如果您的 `update_state()` 和 `apply()` 实现使用高效的向量化实现，这些实现在单个命令中对整个持久化批次进行操作。例如，您不能仅仅因为一个请求禁用了 logits 处理器就跳过 `apply()` 中的整个向量化操作。为了在没有任何运行请求使用内置 logits 处理器的边缘情况下节省计算，我们建议设计 `apply()`，使其在所有请求都禁用 logits 处理器时返回未修改的输入张量。类似地，考虑在没有任何请求启用 logits 处理器时是否可以跳过 `update_state()` 中的步骤

        * 此外，在 `update_state()` 中节省计算的一个简单方法是在 `batch_update` 为 `None` 时提前退出

* 确保 logits 处理器的 `update_state` 方法丢弃有关已完成请求的信息（即被 Add 操作替换或受 Remove 操作影响的请求）

* 如果 logits processor 的行为始终一致，`is_argmax_invariant()` 可以硬编码为 `True` 或 `False`。然而，argmax 不变性也可以通过编程方式确定（例如，如果您的 logits processor 以某种方式支持用户自定义，从而影响其是否具有 argmax 不变性）。因此，`is_argmax_invariant()` 不是类方法。

### 内置 Logits Processors

内置 logits processors 在 vLLM 引擎启动时始终会被加载。请参考 `vllm/v1/sample/logits_processor/builtin.py` 中现有的 vLLM 内置 logits processors 示例，了解如何编写新的内置 vLLM logits processor。如果一个 logits processor 可能对广大用户有用，那么将其作为内置功能并通过 PR 引入是合理的。vLLM 目前基于上述编程模型采用了以下内置 logits processors：

* Min-P

* Logit bias

* Min-tokens

请参考这些 logits processor 的实现，以指导您编写内置 logits processors。

此外，以下类似 logits processor 的功能目前硬编码在 sampler 中，尚未采用上述编程模型。其中大部分功能后续将重构为使用上述 logits processor 编程模型：

* 允许的 token ID（Allowed token IDs）

* 禁用词（Bad words）

* 重复惩罚（Repetition penalty）

* 频率惩罚（Frequency penalty）

* 存在惩罚（Presence penalty）

* 温度（Temperature）

* Top-K

* Top-P

### 自定义 Logits Processors

vLLM 支持通过[用户提供的自定义 logits processors](../features/custom_logitsprocs.md)进行功能扩展。