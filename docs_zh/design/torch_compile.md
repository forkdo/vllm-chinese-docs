# `torch.compile` 集成

在 vLLM 的 V1 架构中，`torch.compile` 默认启用，并且是该框架的关键组成部分。本文档通过一个简单的示例，展示如何理解 `torch.compile` 的使用方式。

在示例中，我们将运行一个常见的 Llama 模型，并开启调试级别的日志记录以显示所有详细信息。使用的命令为：`VLLM_LOGGING_LEVEL=DEBUG vllm serve meta-llama/Llama-3.2-1B`。

!!! note
    有关 `torch.compile` 集成的更多信息和最新进展，请参阅这篇[博客文章](https://blog.vllm.ai/2025/08/20/torch-compile.html)。

## 编译缓存

在非常详细的日志中，我们可以看到：

```console
INFO 03-07 03:06:55 [backends.py:409] Using cache directory: ~/.cache/vllm/torch_compile_cache/1517964802/rank_0_0 for vLLM's torch.compile
```

vLLM 会综合考虑所有可用因素，决定一个目录来存储所有编译产物。这意味着，在部署场景中，您可以直接复制整个 `~/.cache/vllm/torch_compile_cache` 目录，从而节省大量编译时间，加快 vLLM 实例的启动速度。

考虑的因素包括：

- 所有相关配置（请参阅[配置文件夹](../../vllm/config)中各自配置里的 `compute_hash` 函数）
- PyTorch 配置（请参阅 [compiler_interface.py](../../vllm/compilation/compiler_interface.py) 中的 `compute_hash` 函数）
- 模型的前向传播函数以及前向传播函数调用的相关函数（见下文）

通过综合考虑所有这些因素，我们通常可以确保缓存是安全的，不会导致任何意外行为。因此，缓存默认启用。如果您需要调试编译过程，或者怀疑缓存导致了一些问题，可以通过设置环境变量 `VLLM_DISABLE_COMPILE_CACHE=1` 来禁用缓存。

vLLM 的 `torch.compile` 集成的一个独特之处在于，我们保证在处理任何请求之前完成所有编译工作。不会有请求触发新的编译。否则，引擎会被该请求阻塞，响应时间会出现意外的峰值。

默认情况下，缓存会将编译产物保存为二进制文件。如果您需要出于调试目的与生成的代码进行交互，请在编译配置中设置字段 `compile_cache_save_format=unpacked`，或者省略此设置并设置环境变量 `VLLM_COMPILE_CACHE_SAVE_FORMAT=unpacked`。

## 动态形状与 vLLM 守卫丢弃

`torch.compile` 的设计初衷是在需要时毫不犹豫地对动态形状进行守卫。这与 vLLM 的 `torch.compile` 方法相矛盾，后者会丢弃守卫，因为许多守卫可能是实质性的。

`torch.compile` 提供两种动态形状：`backed` 和 `unbacked`。`torch.compile` 会对 `backed` 动态形状进行守卫，但并不保证不会为其添加守卫。用户代码、dynamo、inductor 和 autograd 都可能添加守卫。此外，对于 0/1 特化，即使没有遇到这些范围的分支，backed 符号也会无条件地特化为 0、1 或 >=2。

相反，`unbacked` 动态形状保证不会被守卫，也不会进行 0/1 特化。但是，当遇到需要其值的分支且没有定义显式的 unbacked 处理时，可能会抛出数据依赖错误。框架正在向一种状态收敛，即不会抛出 DDE，而是选择通用路径。使用 unbacked 的一个缺点是可能错过优化机会，这要么是由于性能缺陷，要么是选择了通用路径，要么是使用固定的非示例输入提示（这很快将通过 override_hint API 修复）。选择通用路径的一个例子是，在函数调用 contiguous() 和 reshape() 时假设输入不连续，而无法通过引入 clone 来符号化证明。

`backed_size_oblivious` 是一个标志，它允许在定义了显式 unbacked 处理的地方将 backed 符号视为 unbacked。在这种模式下，框架代码中基本避免了 0/1 特化，也不会发生默认的 0/1 特化。但是，仍然无法保证 torch.compile 不会守卫，尤其是由于用户代码或自定义传递。`backed_size_oblivious` 在 PyTorch compile 中是实验性的，可能会被弃用。话虽如此，它比 `backed` 更安全，降低性能的可能性也低于 `unbacked`。

### 配置动态形状

`DynamicShapesConfig` 允许您通过设置 `type` 字段来控制动态形状行为。您可以在三种模式之间选择：`BACKED`（默认）、`UNBACKED` 和 `BACKED_SIZE_OBLIVIOUS`。

#### 离线推理示例（使用 LLM 类）

当使用 `LLM` 类进行离线推理时，您可以通过 `compilation_config` 参数配置动态形状：

```python
from vllm import LLM, SamplingParams
from vllm.config.compilation import CompilationConfig, DynamicShapesConfig, DynamicShapesType

# 示例：使用 backed_size_oblivious（实验性，比 backed 更安全）
llm = LLM(
    model="meta-llama/Llama-3.2-1B",
    compilation_config=CompilationConfig(
        dynamic_shapes_config=DynamicShapesConfig(
            type=DynamicShapesType.BACKED_SIZE_OBLIVIOUS
        )
    )
)

# 示例：使用 unbacked（对守卫的最强保证）
llm = LLM(
    model="meta-llama/Llama-3.2-1B",
    compilation_config=CompilationConfig(
        dynamic_shapes_config=DynamicShapesConfig(
            type=DynamicShapesType.UNBACKED
        )
    )
)

# 生成输出
prompts = ["Hello, my name is", "The future of AI is"]
sampling_params = SamplingParams(temperature=0.8, top_p=0.95)
outputs = llm.generate(prompts, sampling_params)
```

#### 在线服务示例（使用 vllm serve）

当使用 `vllm serve` 进行在线服务时，您可以通过 `--compilation-config` 标志配置动态形状：

```bash
# 示例：使用 unbacked
vllm serve meta-llama/Llama-3.2-1B \
  --compilation-config '{"dynamic_shapes_config": {"type": "unbacked"}}'


# 替代方案：使用点表示法（单个值更简单）
vllm serve meta-llama/Llama-3.2-1B -cc.dynamic_shapes_config.type=unbacked
```

#### 选择合适的模式

- **BACKED**（默认）：当您愿意接受潜在的不安全守卫丢弃以换取最大性能时使用。守卫可能会被不安全地添加，然后被忽略。

- **UNBACKED**：当您最需要最强保证不出现守卫时使用。这是最保守的选项，但可能会错过一些优化机会。

- **BACKED_SIZE_OBLIVIOUS**：当您希望在避免守卫和性能之间取得平衡时使用。这种实验性模式比 BACKED 更安全，但仍然不如 UNBACKED 保守。

## Python 代码编译

在非常详细的日志中，我们可以看到：

??? console "日志"

      ```text
      DEBUG 03-07 03:06:52 [decorators.py:203] Start compiling function <code object forward at 0x7f08acf40c90, file "xxx/vllm/model_executor/models/llama.py", line 339>
      ```

DEBUG 03-07 03:06:54 [backends.py:370] 已追踪的文件（将被考虑用于编译缓存）：
      DEBUG 03-07 03:06:54 [backends.py:370] xxx/torch/_dynamo/polyfills/builtins.py
      DEBUG 03-07 03:06:54 [backends.py:370] xxx/torch/nn/modules/container.py
      DEBUG 03-07 03:06:54 [backends.py:370] xxx/torch/nn/modules/module.py
      DEBUG 03-07 03:06:54 [backends.py:370] xxx/vllm/attention/layer.py
      DEBUG 03-07 03:06:54 [backends.py:370] xxx/vllm/distributed/communication_op.py
      DEBUG 03-07 03:06:54 [backends.py:370] xxx/vllm/distributed/parallel_state.py
      DEBUG 03-07 03:06:54 [backends.py:370] xxx/vllm/model_executor/custom_op.py
      DEBUG 03-07 03:06:54 [backends.py:370] xxx/vllm/model_executor/layers/activation.py
      DEBUG 03-07 03:06:54 [backends.py:370] xxx/vllm/model_executor/layers/layernorm.py
      DEBUG 03-07 03:06:54 [backends.py:370] xxx/vllm/model_executor/layers/linear.py
      DEBUG 03-07 03:06:54 [backends.py:370] xxx/vllm/model_executor/layers/rotary_embedding.py
      DEBUG 03-07 03:06:54 [backends.py:370] xxx/vllm/model_executor/layers/vocab_parallel_embedding.py
      DEBUG 03-07 03:06:54 [backends.py:370] xxx/vllm/model_executor/models/llama.py

      DEBUG 03-07 03:07:07 [backends.py:462] 计算图已保存至 ~/.cache/vllm/torch_compile_cache/1517964802/rank_0_0/computation_graph.py
      DEBUG 03-07 03:07:07 [wrapper.py:105] Dynamo 转换后的代码已保存至 ~/.cache/vllm/torch_compile_cache/1517964802/rank_0_0/transformed_code.py
      ```

这是关于 Python 代码编译的内容，即 Dynamo 的图捕获。它会尝试追踪 `xxx/vllm/model_executor/models/llama.py:339` 处的函数，也就是我们编译的模型的 `forward` 函数。在前向传播过程中，Dynamo 还会内联调用其他函数，如日志所示，包括来自 `xxx/torch/nn/modules/module.py` 的一些 PyTorch 函数（被 PyTorch 的 `nn.Module` 使用，因为模块属性访问会触发函数调用），以及来自 vLLM 的一些通信/注意力/激活函数。在决定使用哪个缓存目录时，所有被追踪的文件都会被考虑进去。这样，上述任何文件中的代码更改都会导致编译缓存未命中，从而触发重新编译。

Dynamo 编译的结果是一个新函数，存储在 `~/.cache/vllm/torch_compile_cache/1517964802/rank_0_0/transformed_code.py` 中。通常，这个函数会从模块中解包张量，然后将它们传递给追踪到的计算图。计算图则存储在 `~/.cache/vllm/torch_compile_cache/1517964802/rank_0_0/computation_graph.py` 中。

## 计算图处理

计算图中的每个张量都有形状注解。输入包括输入 ID、位置 ID、模型中的权重和缓冲区，输出则是最终的隐藏状态。请注意，语言模型头部投影和采样操作不包含在图中。

计算图的大多数输入都具有静态形状，因为它们是模型权重和缓冲区，在模型生命周期内不会改变。只有输入 ID 和位置 ID 具有符号形状，即形状可能因批次而异。但它们会共享相同的符号形状。也就是说，计算图中唯一变化的大小是批次大小（当前前向传播中处理的 token 数量）。

注意力操作非常复杂，需要与具有复杂形状的 KV 缓存进行交互。幸运的是，注意力操作的输出形状与注意力操作的输入查询形状相同。因此，我们将整个注意力操作封装到一个 PyTorch 自定义操作 `torch.ops.vllm.unified_attention_with_output` 中，这样 Dynamo 就不会尝试检查任何内部操作。这样，尽管注意力操作很复杂，但从 Dynamo 的角度来看，我们仍然可以将模型的计算图捕获为完整图。

计算图进一步被 `splitting_ops`（通常是注意力操作）分割成多个部分。因此，在 `~/.cache/vllm/torch_compile_cache/1517964802/rank_0_0/computation_graph.py` 文件中，我们可以看到许多子模块，每个子模块都是分割后的一个图片段：

- 注意力操作本身是一个子模块。
- 从一个注意力操作到下一个注意力操作的计算图部分是一个子模块。

每个子模块都可以通过其索引来标识，并将被单独处理。

## 计算图编译

在非常详细的日志中，我们还可以看到：

```console
DEBUG 03-07 03:52:37 [backends.py:134] 通过句柄 ('fpegyiq3v3wzjzphd45wkflpabggdbjpylgr7tta4hj6uplstsiw', '~/.cache/vllm/torch_compile_cache/1517964802/rank_0_0/inductor_cache/iw/ciwzrk3ittdqatuzwonnajywvno3llvjcs2vfdldzwzozn3zi3iy.py') 将形状为 None 的第 0 个图存储到 Inductor
DEBUG 03-07 03:52:39 [backends.py:134] 通过句柄 ('f7fmlodmf3h3by5iiu2c4zarwoxbg4eytwr3ujdd2jphl4pospfd', '~/.cache/vllm/torch_compile_cache/1517964802/rank_0_0/inductor_cache/ly/clyfzxldfsj7ehaluis2mca2omqka4r7mgcedlf6xfjh645nw6k2.py') 将形状为 None 的第 1 个图存储到 Inductor
...
DEBUG 03-07 03:52:45 [backends.py:134] 通过句柄 ('f7fmlodmf3h3by5iiu2c4zarwoxbg4eytwr3ujdd2jphl4pospfd', '~/.cache/vllm/torch_compile_cache/1517964802/rank_0_0/inductor_cache/ly/clyfzxldfsj7ehaluis2mca2omqka4r7mgcedlf6xfjh645nw6k2.py') 将形状为 None 的第 15 个图存储到 Inductor
DEBUG 03-07 03:52:45 [backends.py:134] 通过句柄 ('fvj3ccoi7m34f3dnr4itmu55mmun44l5xymwhrjlwisylsk7q6jy', '~/.cache/vllm/torch_compile_cache/1517964802/rank_0_0/inductor_cache/tf/ctfftkglj7b4lcttq5cymx6cew372uoauupqn6ldsvpiucavqcjc.py') 将形状为 None 的第 16 个图存储到 Inductor
```

这意味着第一个计算图片段（符号形状为 `None`）由 Inductor 编译（键为 `fpegyiq3v3wzjzphd45wkflpabggdbjpylgr7tta4hj6uplstsiw`）。编译后的内核存储在 `~/.cache/vllm/torch_compile_cache/1517964802/rank_0_0/inductor_cache/iw/ciwzrk3ittdqatuzwonnajywvno3llvjcs2vfdldzwzozn3zi3iy.py` 中。你可以打开该文件查看 Inductor 最终运行的代码。

还有一个细节：你可以看到第 1 个图和第 15 个图具有相同的键，而第 0 个图和第 16 个图则不同。这是预期的，因为我们将图按注意力操作分割，得到了 3 个唯一的子图：

- 注意力操作前的第一层
- 每个中间层，从一个注意力操作到下一个注意力操作
- 注意力操作后的最后一层

如果我们已经有缓存目录（例如第二次运行相同代码），我们将看到以下日志：

```console
DEBUG 03-07 04:00:45 [backends.py:86] 通过句柄 ('fpegyiq3v3wzjzphd45wkflpabggdbjpylgr7tta4hj6uplstsiw', '~/.cache/vllm/torch_compile_cache/1517964802/rank_0_0/inductor_cache/iw/ciwzrk3ittdqatuzwonnajywvno3llvjcs2vfdldzwzozn3zi3iy.py') 直接从 Inductor 加载形状为 None 的第 0 个图
```

这一次，Inductor 编译被完全绕过，我们将从磁盘加载上次获得的编译产物。

上面的示例仅使用 Inductor 为通用形状（即符号形状）进行编译。我们也可以使用 Inductor 为某些特定形状进行编译，例如：

```bash
vllm serve meta-llama/Llama-3.2-1B \
  --compilation_config '{"compile_sizes": [1, 2, 4, 8]}'
```

然后它还会仅为批次大小 `1, 2, 4, 8` 编译一个特定的内核。此时，计算图中的所有形状都是静态且已知的，我们将启用自动调优以实现最大性能。首次运行时这可能很慢，但下次运行时我们可以直接绕过调优并运行已调优的内核。

当所有形状都已知时，`torch.compile` 可以比较不同的配置，并经常找到一些更好的配置来运行内核。例如，我们可以看到以下日志：

??? console "日志"

```
AUTOTUNE mm(8x2048, 2048x3072)
  triton_mm_4 0.0130 ms 100.0% ACC_TYPE='tl.float32', ALLOW_TF32=False, BLOCK_K=128, BLOCK_M=16, BLOCK_N=32, B_PROLOGUE_CAST_TYPE=None, EVEN_K=True, GROUP_M=8, num_stages=5, num_warps=2
  triton_mm_8 0.0134 ms 97.4% ACC_TYPE='tl.float32', ALLOW_TF32=False, BLOCK_K=128, BLOCK_M=16, BLOCK_N=64, B_PROLOGUE_CAST_TYPE=None, EVEN_K=True, GROUP_M=8, num_stages=5, num_warps=4
  triton_mm_12 0.0148 ms 87.7% ACC_TYPE='tl.float32', ALLOW_TF32=False, BLOCK_K=128, BLOCK_M=16, BLOCK_N=128, B_PROLOGUE_CAST_TYPE=None, EVEN_K=True, GROUP_M=8, num_stages=4, num_warps=4
  mm 0.0160 ms 81.6%
  triton_mm_16 0.0165 ms 78.7% ACC_TYPE='tl.float32', ALLOW_TF32=False, BLOCK_K=64, BLOCK_M=16, BLOCK_N=128, B_PROLOGUE_CAST_TYPE=None, EVEN_K=True, GROUP_M=8, num_stages=5, num_warps=8
  triton_mm_3 0.0199 ms 65.4% ACC_TYPE='tl.float32', ALLOW_TF32=False, BLOCK_K=32, BLOCK_M=16, BLOCK_N=32, B_PROLOGUE_CAST_TYPE=None, EVEN_K=True, GROUP_M=8, num_stages=5, num_warps=2
  triton_mm_1 0.0203 ms 64.2% ACC_TYPE='tl.float32', ALLOW_TF32=False, BLOCK_K=128, BLOCK_M=16, BLOCK_N=32, B_PROLOGUE_CAST_TYPE=None, EVEN_K=True, GROUP_M=8, num_stages=2, num_warps=2
  triton_mm_7 0.0203 ms 64.1% ACC_TYPE='tl.float32', ALLOW_TF32=False, BLOCK_K=64, BLOCK_M=16, BLOCK_N=64, B_PROLOGUE_CAST_TYPE=None, EVEN_K=True, GROUP_M=8, num_stages=3, num_warps=4
  triton_mm_2 0.0208 ms 62.5% ACC_TYPE='tl.float32', ALLOW_TF32=False, BLOCK_K=32, BLOCK_M=16, BLOCK_N=64, B_PROLOGUE_CAST_TYPE=None, EVEN_K=True, GROUP_M=8, num_stages=5, num_warps=4
  tritan_mm_11 0.0215 ms 60.5% ACC_TYPE='tl.float32', ALLOW_TF32=False, BLOCK_K=64, BLOCK_M=16, BLOCK_N=128, B_PROLOGUE_CAST_TYPE=None, EVEN_K=True, GROUP_M=8, num_stages=3, num_warps=4
SingleProcess AUTOTUNE 基准测试耗时 2.0428 秒，预编译耗时 7.5727 秒
```

这意味着，对于形状为 `8x2048x3072` 的矩阵乘法，`torch.compile` 会尝试使用各种配置的 Triton 模板，其性能远优于默认代码（默认代码会调度到 cublas 库）。

遗憾的是，由于自动调优需要耗费较长时间（根据模型大小和批处理大小，可能需要几秒到几分钟），尽管其结果可被缓存以供后续使用，但出于用户体验考虑，我们默认关闭了该功能。如果您希望获得最大性能，建议针对特定形状尝试启用该功能。

## Cudagraph 捕获

vLLM 的 V1 架构采用了分段式 cudagraph，这与分段式编译保持一致。如前所述，整个计算图被分割，我们仅捕获注意力操作之间的计算图片段（包括首个注意力操作之前的计算图，以及所有注意力操作之后的计算图）。这基于一个常见观察：注意力操作之间的计算通常是逐 token 的，易于通过 cudagraph 处理；而注意力操作本身则难以与 cudagraph 兼容。因此，通过在 eager 模式下运行注意力操作，而在 cudagraph 中运行其余操作，我们保持了注意力操作的灵活性。

分段式 cudagraph 还具备细粒度的内存管理能力。其目的是仅将注意力 kernel 排除在 cudagraph 之外，同时确保其余所有模块及内存分配操作均包含在 cudagraph 中。这就是 V1 中注意力操作将输出张量作为注意力输入的原因。

Cudagraph 由编译器后端捕获和管理，并在批处理大小存在对应捕获的 cudagraph 时进行重放。模型调用者（模型运行器）只需确保正确管理输入缓冲区，所有中间缓冲区均由编译器后端自动管理。

默认情况下，vLLM 会尝试确定一组尺寸以捕获 cudagraph。您也可以使用配置 `cudagraph_capture_sizes` 覆盖此行为：

```bash
vllm serve meta-llama/Llama-3.2-1B \
  --compilation-config '{"cudagraph_capture_sizes": [1, 2, 4, 8]}'
```

这将仅针对指定尺寸捕获 cudagraph，有助于实现对 cudagraph 捕获的精细控制。

### 完整 Cudagraph 捕获

如果使用与 cudagraph 兼容的注意力后端，也可以将注意力操作包含在 cudagraph 中。在某些情况下（例如较小模型的解码速度或 MOE 模型），这可以提升性能。详情请参阅 [CUDA Graphs](cuda_graphs.md)。