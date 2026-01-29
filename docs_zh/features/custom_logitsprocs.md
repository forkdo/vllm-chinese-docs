# 自定义 Logits 处理器

!!! important
    某些 Logits 处理器的设计变更仍在进行中，API 可能在近期发生变化。我们希望尽快稳定这一部分 API。

"自定义" Logits 处理器由 vLLM 用户编写，并在初始化时加载到 vLLM 中，无需修改或重新编译 vLLM 源代码。它与内置的 Logits 处理器相反。

本文档展示了如何编写、加载和使用自定义 Logits 处理器。

## Logits 处理器背景

Logits 处理器调整下一个 token 的概率分布，通常旨在引导模型朝着期望的行为类型发展。

在 vLLM 中，Logits 处理器在批量粒度上运行。在给定的引擎步骤中，Logits 处理器会消费一个 `(num_requests) x (vocab_size)` 的原始 Logits 张量。对于所有启用了 Logits 处理器的请求，Logits 处理器会对对应的 Logits 张量的行应用变换，而其他行保持不变。变换后的 Logits 张量随后被传递给 softmax。

## 创建自定义 Logits 处理器

自定义 Logits 处理器必须继承 `vllm.v1.sample.logits_processor.LogitsProcessor` 并定义（至少）以下方法：

* `validate_params(cls, sampling_params: SamplingParams)`:
    * 如果 `SamplingParams` 包含 Logits 处理器使用的无效参数（特别是自定义参数），则抛出 `ValueError`
    * 当请求发送到入口点时，`validate_params()` 会验证 `SamplingParams` 并拒绝无效参数的请求。
    * **注意：** 实现 `validate_params()` 很重要，以防止自定义 Logits 处理器中出现无效参数。否则，带有无效参数的请求可能导致自定义 Logits 处理器中的意外行为。

* `__init__(self, vllm_config: VllmConfig, device: torch.device, is_pin_memory: bool)`
    * `vllm_config`: 引擎配置数据结构
    * `device`: 硬件加速器设备信息
    * `is_pin_memory`: 标志，表示是否可用 pin 内存以支持 Logits 处理器实现

* `apply(self, logits: torch.Tensor) -> torch.Tensor`:
    * 消费一个 `(num_requests) x (vocab_size)` 的 Logits 张量 (`logits`)
    * 在批量粒度上应用 Logits 处理器变换
    * 返回一个变换后的 `(num_requests) x (vocab_size)` Logits 张量
    * 可以就地或异地修改输入的 Logits 处理器；就地修改更节省内存

* `is_argmax_invariant(self) -> bool`:
    * 如果 Logits 处理器是 argmax 不变的（从不改变给定请求的最高 Logit 值的 token ID），返回 `True`，如果可能修改 argmax 返回 `False`
    * `is_argmax_invariant()` 在启动时评估一次；如果为 `True`，当所有请求都使用贪心采样时，vLLM 将跳过应用此 Logits 处理器

* `update_state(self, batch_update: Optional["BatchUpdate"]) -> None`:
    * 消费一个 `BatchUpdate` 数据结构，表示当前引擎步骤开始时的持久批量状态变化
    * 使用 `BatchUpdate` 成员来更新 Logits 处理器的内部状态
    * **注意：** 批量更新数据结构可能为 `None`，表示批量组成部分没有变化。在这种情况下，LogitsProcessor 可能仍希望根据其在添加时保留的更新 `output_token_ids` 列表来更新其状态。

### vLLM 引擎如何构建 `BatchUpdate` 数据结构

!!! important
    某些 Logits 处理器的设计变更仍在进行中。我们预计将来在实现 Logits 处理器时不需要考虑批量状态变化，本节中的信息将变得无关紧要。

Logits 处理器 `update_state()` 实现应假设以下模型，即模型运行器如何更新持久批量状态（以 `BatchUpdate` 抽象形式表示）：

1. 识别在当前引擎步骤中完成的请求的索引

2. 识别在当前步骤中引入的新请求

3. 使用 Add 操作按被替换请求的索引递增顺序，从最低索引开始，尽可能多地用新请求替换已完成的请求

4. 根据新请求和已完成请求的相对数量：

    1. 如果新请求和已完成请求的数量相同，则进入下一步

    2. *如果新请求比已完成请求更多：* 使用 Add 操作将剩余的新请求添加到批次中，这些新请求没有替换已完成的请求。为这些新请求分配连续的索引，从 `current_max_batch_index + 1` 开始

    3. *如果新请求比已完成请求更少：*

        * 对未被新请求替换的已完成请求应用 Remove 操作。这些被移除的请求索引必然大于上一步中被替换的已完成请求的最大索引。Remove 操作可能使批次处于非连续状态

        * **"压缩"批次使其连续：** 从最低索引的空槽位（由 Remove 导致）开始，应用单向移动，从批次中当前最高的非空槽位移动到填充空槽位。按空槽位目标索引递增和非空槽位源索引递减的顺序继续应用额外的单向移动操作，直到批次连续

        * **缩小批次：** 压缩批次的副作用是，由 Remove 操作产生的空槽位在批次数组末尾形成一个连续的块。因此，压缩后更新 `BatchUpdate.batch_size` 以反映非空槽位的数量

5. 重新排序批次以提高效率。根据注意力后端实现和当前批次特征，可能应用零个或多个 Swap Move 操作来重新排序批次

说明：

* Logits 处理器 `update_state()` 方法必须按以下顺序处理批次更新操作：移除、添加、移动

* Add 操作的索引参数指的是 Add 发生时的索引，即在任何 Move 操作之前
    * 示例：如果请求在索引 5 处被添加，然后与索引 3 交换，`BatchUpdate.added` 中的 Add 操作将与索引 5 关联，而不是 3
    * 换句话说，Move 操作可以假设在 Add 和 Remove 之后应用

* 可以假设 Move 操作按其在 `BatchUpdate.moved` 中出现的顺序应用

* 如果没有新请求/已完成请求且没有批次重新排序，则 Logits 处理器的批次更新将为 `None`

### 向自定义 Logits 处理器传递自定义参数

与内置 Logits 处理器不同，自定义 Logits 处理器可能需要配置参数，这些参数没有硬编码到 `SamplingParams` 或 vLLM 服务器 REST API 中。为了解决这个问题，自定义 Logits 处理器可以利用 vLLM 的 [自定义参数](./custom_arguments.md) 支持，从用户接收配置设置（尽管您也可以设计一个利用 `SamplingParams` 中现有字段的自定义 Logits 处理器）。

### 示例自定义 Logits 处理器实现

下面的示例实现了一个自定义 Logits 处理器，它消费一个 `(num_requests) \times (vocab_size)` Logits 张量，并用 `float(-inf)` 掩码掉除一个 token（`target_token`）以外的所有 token。对于未指定 `target_token` 的请求，Logits 处理器会被禁用。为了确定 Logits 处理器是否启用以及要保留哪个 token 不被掩码，Logits 处理器会检查 `SamplingParams.extra_args` 中每个请求的 `target_token` 自定义参数：

??? code "示例自定义 Logits 处理器定义"

``` python
import torch
from vllm.config import VllmConfig
from vllm.sampling_params import SamplingParams
from vllm.v1.sample.logits_processor import (BatchUpdate,
                                                LogitsProcessor,
                                                MoveDirectionality)

class DummyLogitsProcessor(LogitsProcessor):
    """Fake logit processor to support unit testing and examples"""

    @classmethod
    def validate_params(cls, params: SamplingParams):
        target_token: int | None = params.extra_args and params.extra_args.get(
            "target_token"
        )
        if target_token is not None and not isinstance(target_token, int):
            raise ValueError(f"target_token value {target_token} is not int")

    def __init__(self, vllm_config: "VllmConfig", device: torch.device,
                is_pin_memory: bool):
        self.req_info: dict[int, int] = {}

    def is_argmax_invariant(self) -> bool:
        """Never impacts greedy sampling"""
        return False

    def update_state(self, batch_update: BatchUpdate | None):
        if not batch_update:
            return

        # Process added requests.
        for index, params, _, _ in batch_update.added:
            assert params is not None
            self.validate_params(params)
            if params.extra_args and (target_token :=
                                    params.extra_args.get("target_token")):
                self.req_info[index] = target_token
            else: 
                self.req_info.pop(index, None)

        if self.req_info:
            # Process removed requests.
            for index in batch_update.removed:
                self.req_info.pop(index, None)

            # Process moved requests, unidirectional move (a->b) and swap
            # (a<->b)
            for adx, bdx, direct in batch_update.moved:
                a_val = self.req_info.pop(adx, None)
                b_val = self.req_info.pop(bdx, None)
                if a_val is not None:
                    self.req_info[bdx] = a_val
                if direct == MoveDirectionality.SWAP and b_val is not None:
                    self.req_info[adx] = b_val

    def apply(self, logits: torch.Tensor) -> torch.Tensor:
        if not self.req_info:
            return logits

        # Save target values before modification
        cols = torch.tensor(
            list(self.req_info.values()), dtype=torch.long, device=logits.device
        )
        rows = torch.tensor(
            list(self.req_info.keys()), dtype=torch.long, device=logits.device
        )
        values_to_keep = logits[rows, cols].clone()

        # Mask all but target tokens
        logits[rows] = float('-inf')
        logits[rows, cols] = values_to_keep

        return logits

```

在本文档的其余部分，我们将使用 `DummyLogitsProcessor` 作为自定义 logit 处理器的示例。

`DummyLogitsProcessor.update_state()` 的实现维护了 `self.req_info` 字典中批处理请求的"稀疏"表示：只有指定了 `target_token` 值的请求在字典中具有键。`update_state()` 根据对持久批处理的 Add、Remove 和 Move 操作，调整存储的请求索引和 `target_token` 值（分别在 `self.req_info` 中为键和值）。

### 封装现有的请求级 Logit 处理器

尽管 vLLM 引擎在批处理粒度上应用 logit 处理器，但一些用户可能希望使用 vLLM 与一个"请求级"的 logit 处理器实现——该实现作用于单个请求。如果你的 logit 处理器是为 vLLM 版本 0 开发的，这一点尤其重要，因为该版本要求它是一个 `Callable`（如 [此处][vllm.logits_process] 所述），符合以下类型注解：

``` python
RequestLogitsProcessor = Union[

    # (output token ids, logits tensor) -> logits tensor
    Callable[[list[int], Tensor], Tensor],

    # (prompt token ids, output token ids, logits tensor) -> logits tensor
    Callable[[list[int], list[int], Tensor], Tensor],
]
```

虽然请求级 logit 处理器在 vLLM 引擎中明确*不*被支持，但 vLLM *确实*提供了一个便捷的流程来封装现有的 `Callable` 请求级 logit 处理器，并创建一个与 vLLM 兼容的批处理级 logit 处理器。`Callable` 必须符合上述类型注解；如果您的请求级 logit 处理器有不同的接口，那么为了封装它，您可能需要修改它或实现额外的封装层以符合上述接口规范。

您可以通过继承 `AdapterLogitsProcessor` 来封装请求级 logit 处理器，如下例所示（在本例中，`DummyPerReqLogitsProcessor` 是您需要封装的请求级 logit 处理器的占位符）：

* 覆盖 `AdapterLogitsProcessor.validate_params(cls, params)` 以验证请求的采样参数。

* 覆盖 `AdapterLogitsProcessor.is_argmax_invariant(self)` 以准确反映您的请求级 logit 处理器是否可能影响具有最高值 logit 的 token。

* 覆盖 `AdapterLogitsProcessor.new_req_logits_processor(self, params)` 以从 `SamplingParams` 实例创建一个新的请求级 logit 处理器实例：

??? code "封装请求级 Logit 处理器的示例"

    ``` python
    ...

    from vllm.v1.sample.logits_processor import (
        AdapterLogitsProcessor, # 封装基类
        RequestLogitsProcessor, # 请求级 logitproc 类型注解
    )

    ...

    # 您的请求级 logit 处理器的占位符：
    class DummyPerReqLogitsProcessor:
        """该请求级 logit 处理器屏蔽除由 `target_token` 标识的 token id 以外的所有 logit 值"""

        def __init__(self, target_token: int) -> None:
            """指定 `target_token`"""
            self.target_token = target_token

        def __call__(
            self,
            output_ids: list[int],
            logits: torch.Tensor,
        ) -> torch.Tensor:
            val_to_keep = logits[self.target_token].item()
            logits[:] = float("-inf")
            logits[self.target_token] = val_to_keep
            return logits

    ...

    # 封装请求级 logit 处理器的示例：
    class WrappedPerReqLogitsProcessor(AdapterLogitsProcessor):
        """将假请求级 logit 处理器封装为批处理级 logit 处理器的示例"""

        @classmethod
        def validate_params(cls, params: SamplingParams):
            target_token: Any | None = params.extra_args and params.extra_args.get(
                "target_token"
            )
            if target_token is not None and not isinstance(target_token, int):
                raise ValueError(
                    f"target_token value {target_token} is not int"
                )

        def is_argmax_invariant(self) -> bool:
            return False

        def new_req_logits_processor(
            self,
            params: SamplingParams,
        ) -> Optional[RequestLogitsProcessor]:
            """此方法返回一个新的请求级 logit 处理器，根据与特定请求关联的 `target_token` 值进行定制。

            如果 logit 处理器不应应用于特定请求，则返回 None。要使用 logit 处理器，请求必须具有一个带有整数值的"target_token"自定义参数。

            参数：
            params: 每个请求的采样参数

返回：
`Callable` 请求 logits 处理器，或 None
"""
            target_token: Any | None = params.extra_args and params.extra_args.get(
                "target_token"
            )
            if target_token is None:
                return None
            return DummyPerReqLogitsProcessor(target_token)
    ```

!!! note
    您的 `new_req_logits_processor()` 重写方法可以返回 `None`，以表示不应该对相关请求应用包装的 logits 处理器。

一旦您创建了一个自定义子类（例如 `WrappedPerReqLogitsProcessor`），它包装了您的请求级别 logits 处理器，您可以通过以下部分中描述的任何方法将自定义子类传递给 vLLM。

## 在 vLLM 中加载自定义 Logits 处理器的方法

Logits 处理器在初始化时加载。关键的是，一旦 vLLM 引擎完成加载，已加载的 logits 处理器集合不能被修改，也无法按需为单个请求加载新的 logits 处理器。

本节详细介绍了使您的 logits 处理器对 vLLM 可见并触发 vLLM 加载您的 logits 处理器的不同方法。

### 方法 1：在初始化时将自定义 Logits 处理器的全限定类名（FQCN）传递给 vLLM

此方法在离线和在线 vLLM 使用场景中均受支持。自定义 logits 处理器的 FQCN（格式为 `dotted.path.to.module:ClassName`）可以作为参数传递给 `LLM` 和 `AsyncLLM` Python 构造函数，或作为 CLI 参数传递给 `vllm serve`，语法如下：

``` bash
vllm serve ... --logits_processors <logits processor 1> <logits processor 2> ...
```

FQCN 的唯一要求是：

1. Python 的 `importlib.import_module()` 必须能够解析 FQCN 的点分路径部分并将其作为模块加载

2. FQCN 的类名部分必须能够从加载的模块中导入

3. FQCN 所指向的对象必须是 `LogitsProcessor` 的子类

请参阅下面的示例：

??? code "在 Python 中将自定义 logits 处理器 FQCN 传递给 `LLM`"

    ``` python
    # 传入 FQCN
    llm = LLM(
        model="facebook/opt-125m",
        logits_processors=["your.module.path:DummyLogitsProcessor"],
    )
    ```

??? code "在 Python 中将自定义 logits 处理器 FQCN 传递给 `AsyncLLM`"

    ``` python
    # 传入 FQCN
    engine_args = AsyncEngineArgs(model="facebook/opt-125m",
                                  logits_processors=["your.module.path:DummyLogitsProcessor"])
    async_llm = AsyncLLM.from_engine_args(engine_args)
    ```

??? code "通过 CLI 将自定义 logits 处理器 FQCN 传递给 vLLM 服务器"

    ```bash
    vllm serve facebook/opt-125m --logits_processors your.module.path:DummyLogitsProcessor
    ```

### 方法 2：自动检测安装在 Python 环境中的自定义 Logits 处理器作为入口点

[`setuptools`](https://setuptools.pypa.io/en/latest/userguide/entry_point.html) 可以使已安装的包通过称为“入口点”的元数据片段，将自己作为插件提供给其他 Python 程序。

在初始化期间，vLLM 会自动扫描 `vllm.logits_processors` 入口点组，并加载其发现的任何已安装的 logits 处理器。

假设您开发了一个包含自定义 logits 处理器的 Python 包。您可以通过为每个 logits 处理器在 logits 处理器 Python 包中添加一个唯一的入口点来将其暴露给 vLLM。下面的示例展示了如何在项目的 `pyproject.toml` 文件中添加入口点：

??? code "将自定义 logits 处理器作为 Python 入口点暴露"

    ``` toml
    [project.entry-points."vllm.logits_processors"]
    dummy_logits_processor = "your.module.path:DummyLogitsProcessor"
    ```

一旦您的包被安装，您的自定义 logits 处理器将在每次 vLLM 初始化时自动加载。如果您通过入口点暴露了您的 logits 处理器，则不需要在初始化时显式地将其传递给 `LLM` 或 `AsyncLLM` 构造函数，或传递给 vLLM 服务器。

!!! note
    vLLM 将 *始终* 加载在 `vllm.logits_processors` 分组下通过入口点暴露的 *所有* logits 处理器。

### 方法 3（仅限离线）：将 Python 类对象传递给 vLLM 构造函数

您可以将一个或多个自定义 logits 处理器类对象传递给 `LLM` 和 `AsyncLLM` 构造函数。此选项非常灵活，因为 logits 处理器类既可以（1）在定义 `LLM` 或 `AsyncLLM` 的同一 Python 源文件中本地定义，也可以（2）从 Python 包中导入。

??? code "在 Python 中将自定义 logits 处理器类对象传递给 `LLM` 或 `AsyncLLM`"

    ``` python
    # 导入自定义 logits 处理器
    from some.module import DummyLogitsProcessor

    # ...或者...

    # 在本地定义自定义 logits 处理器
    from vllm.v1.sample.logits_processor import LogitsProcessor

    class DummyLogitsProcessor(LogitsProcessor):
        # 参见上面的 DummyLogitsProcessor 实现
        ...

    # 将类对象传递给 LLM 构造函数
    llm = LLM(
        model="facebook/opt-125m",
        logits_processors=[DummyLogitsProcessor],
    )

    # 将类对象传递给 AsyncLLM 构造函数
    engine_args = AsyncEngineArgs(model="facebook/opt-125m",
                                  logits_processors=[DummyLogitsProcessor])
    async_llm = AsyncLLM.from_engine_args(engine_args)
    ```

## 对请求调用自定义 Logits 处理器

自定义 logits 处理器的设计决定了该处理器是否必须为给定请求启用/禁用，以及需要提供哪些参数来配置该处理器。

下面的示例展示了用户如何将自定义参数（`target_token`）传递给 `DummyLogitsProcessor`，以（1）为该特定请求启用 logits 处理器，以及（2）控制 logits 处理器的行为。

??? code "vLLM REST API：为请求配置自定义 logits 处理器"

    ``` bash
    curl http://localhost:8000/v1/completions \
        -H "Content-Type: application/json" \
        -d '{
            "model": "Qwen/Qwen2.5-1.5B-Instruct",
            ...
            "vllm_xargs": {"target_token": 67}
        }'
    ```

??? code "OpenAI SDK：为请求配置自定义 logits 处理器"

    ``` python
    batch = await client.completions.create(
        model="Qwen/Qwen2.5-1.5B-Instruct",
        ...,
        extra_body={
            "vllm_xargs": {
                "target_token": 67
            }
        }
    )
    ```

??? code "离线：为 `LLM` 请求配置自定义 logits 处理器"

    ``` python
    outputs_logitproc = llm.generate("your prompt", 
                                     SamplingParams(...,
                                        extra_args={"target_token": 67}))
    ```

??? code "离线：为 `AsyncLLM` 请求配置自定义 logits 处理器"

    ``` python
    async for out in engine.generate(request_id="your request id",
                                     prompt="your prompt",
                                     sampling_params=SamplingParams(...,
                                        extra_args={"target_token": 67})):

        # 处理异步请求输出
        ...
    ```

## 编写自定义 Logits 处理器的最佳实践

一旦 vLLM 在初始化期间加载了 logits 处理器，vLLM 将在每个引擎步骤中对该 logits 处理器调用 `update_state()` 和 `apply()`。这两个方法都会作用于当前位于 vLLM 持久批处理中的所有请求。因此，高效地实现这些方法非常重要。

* 针对 logits 处理器在批处理粒度上运行的事实，编写高效的 `apply()` 和 `update_state()` 实现  
    * 例如，您可以使用高效的向量化操作来实现 `apply()`，或在 `update_state()` 中更新内部状态向量  
    * 但是，如果您认为某个 logits 处理器使用频率较低，使用“稀疏”的请求状态表示可能是合适的，即该类可以使用字典来表示请求配置，仅存储启用该 logits 处理器的请求的元数据  
    * **注意：** 包装的请求级 logits 处理器无需实现 `apply()` 和 `update_state()`；默认的 `AdapterLogitsProcessor.update_state()` 实现维护请求状态的稀疏表示，其中 `new_req_logits_processor()` 返回 `None` 的请求不会在基类状态字典中表示。默认的 `AdapterLogitsProcessor.apply()` 实现顺序地将请求级 logits 处理器应用于输入 logits 的每一行，并组装输出 logits 张量。如果此 `AdapterLogitsProcessor` 默认实现的性能不足，则应避免包装您的请求级 logits 处理器，而应重新实现为 `LogitsProcessor` 子类，提供在批处理粒度上运行的优化的 `apply()` 和 `update_state()` 实现  

* 决定以下内容是 logits 处理器作者的责任：

    1. **配置该请求下 logits 处理器行为的每个请求的属性。** 您的自定义 logits 处理器的 `update_state()` 覆盖方法决定了 `SamplingParams` 字段如何映射到 logits 处理器状态  

        * **注意：** 对于包装的请求级 logits 处理器，`new_req_logits_processor()` 决定了如何使用 `SamplingParams` 字段来初始化请求级 logits 处理器实例  

    2. **logits 处理器在每个请求基础上启用或不启用的条件。** 除非您的意图是让自定义 logits 处理器始终作用于所有请求，否则您应编写代码使得可以针对特定请求禁用该 logits 处理器，例如通过将参数默认设为 `None`，或传入一个特定的无操作参数值（如 `0.0`）。请尽量为禁用了 logits 处理器的请求节省计算和内存  

        * **注意：** 对于包装的每请求 logits 处理器，默认的 `AdapterLogitsProcessor.update_state()` 实现确保当 `new_req_logits_processor()` 对该请求返回 `None` 时禁用请求级 logits 处理器  

    3. **logits 处理器在批处理级别被短路的条件。** 即使您已定义在请求级别禁用自定义 logits 处理器的方式，将其转化为计算节省可能仍具有挑战性（例如，如果您的 `update_state()` 和 `apply()` 实现使用高效的向量化实现，以单条命令对整个持久批处理进行操作）。例如，您无法仅因为一个请求禁用了 logits 处理器就跳过 `apply()` 中的整个向量化操作。为了在没有运行请求使用自定义 logits 处理器的边缘情况下节省计算，我们建议设计 `apply()`，使其在所有请求都禁用 logits 处理器时返回未修改的输入张量。类似地，请考虑是否可以在 `update_state()` 中跳过某些步骤，如果没有任何请求启用了 logits 处理器  

        * 此外，在 `update_state()` 中节省计算的一个简单方法是当 `batch_update` 为 `None` 时提前退出  

        * **注意：** 对于包装的每请求 logits 处理器，`AdapterLogitsProcessor` 基类默认实现了上述优化  

* 确保 logits 处理器的 `update_state` 方法丢弃已完成请求的信息（即被 Add 替换或受到 Remove 操作的请求）  

    * **注意：** 对于包装的每请求 logits 处理器，`AdapterLogitsProcessor` 基类默认处理此操作  

* 如果 logits 处理器的行为保持一致，可以将 `is_argmax_invariant()` 硬编码为 `True` 或 `False`。然而，argmax 不变性也可能通过程序确定（例如，如果您的 logits 处理器以某种方式可由用户自定义，从而影响其是否为 argmax 不变的）。因此，`is_argmax_invariant()` 不是类方法