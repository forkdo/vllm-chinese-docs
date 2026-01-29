# 分页注意力机制

!!! warning
    这是一份基于 vLLM 原始论文的文档（https://arxiv.org/abs/2309.06180）。
    它不再描述当今 vLLM 中使用的代码。

目前，vLLM 使用了自己实现的多头查询注意力内核（`csrc/attention/attention_kernels.cu`）。
此内核被设计为与 vLLM 的分页 KV 缓存兼容，其中键和值缓存存储在
单独的块中（请注意，此块概念不同于 GPU
线程块。因此在后续文档中，我将把 vLLM 分页注意力块称为"块"，而将 GPU 线程块称为
"线程块"）。

为了实现高性能，此内核依赖于一种专门设计的内存布局和访问方法，特别是当线程
从全局内存读取数据到共享内存时。本文档的目的是逐步提供内核实现的高级解释，
帮助那些想要了解 vLLM 多头查询注意力内核的人。在阅读完本文档后，用户
应该能够更好地理解并更容易跟随实际实现。

请注意，本文档可能不会涵盖所有细节，例如如何计算相应数据的正确索引或点
乘法实现。但是，在阅读本文档并熟悉高级逻辑流程后，您应该能够更容易地
阅读实际代码并理解细节。

## 输入参数

内核函数接受当前线程执行其分配任务的一系列参数。三个最重要的参数是
输入指针 `q`、`k_cache` 和 `v_cache`，它们指向需要从全局内存中读取和处理的查询、键和值数据。输出指针 `out` 指向全局内存，结果应该写入此处。这些四个指针实际上指向多维数组，但每个线程只访问分配给它的数据部分。为了简化，我在这里省略了所有其他运行时参数。

```cpp
template<typename scalar_t, int HEAD_SIZE, int BLOCK_SIZE, int NUM_THREADS, int PARTITION_SIZE = 0>
__device__ void paged_attention_kernel(
    ... // 其他辅助参数。
    const scalar_t* __restrict__ out,       // [num_seqs, num_heads, max_num_partitions, head_size]
    const scalar_t* __restrict__ q,         // [num_seqs, num_heads, head_size]
    const scalar_t* __restrict__ k_cache,   // [num_blocks, num_kv_heads, head_size/x, block_size, x]
    const scalar_t* __restrict__ v_cache,   // [num_blocks, num_kv_heads, head_size, block_size]
    ... // 其他辅助参数。
)
```

函数签名上方还有一系列在编译时确定的模板参数。`scalar_t` 表示查询、键和值数据元素的数据类型，例如 FP16。`HEAD_SIZE` 表示每个头中的元素数量。`BLOCK_SIZE` 指的是每个块中的令牌数量。`NUM_THREADS` 表示每个线程块中的线程数量。`PARTITION_SIZE` 表示张量并行 GPU 的数量（为简化起见，我们假设这是 0 并且张量并行被禁用）。

有了这些参数，我们需要进行一系列准备工作。这包括计算当前头索引、块索引和其他必要的变量。但是，目前我们可以忽略这些准备工作，直接进入实际计算。一旦我们掌握了整个流程，理解它们会更容易。

## 概念

在我们深入计算流程之前，我想描述一些在后续部分需要的概念。如果您遇到任何令人困惑的术语，您可以跳过本节，稍后再回来。

- **序列**：序列代表一个客户端请求。例如，`q` 指向的数据具有形状 `[num_seqs, num_heads, head_size]`。这表示总共有 `num_seqs` 的查询序列数据被 `q` 指向。由于此内核是单查询注意力内核，每个序列只有一个查询令牌。因此，`num_seqs` 等于批处理中处理的令牌总数。
- **上下文**：上下文由序列生成的令牌组成。例如，`["What", "is", "your"]` 是上下文令牌，输入查询令牌是 `"name"`。模型可能会生成令牌 `"?"`。
- **向量**：向量是一起获取和计算的元素列表。对于查询和键数据，向量大小（`VEC_SIZE`）被确定为每个线程组每次可以获取和计算 16 字节的数据。对于值数据，向量大小（`V_VEC_SIZE`）被确定为每个线程每次可以获取和计算 16 字节的数据。例如，如果 `scalar_t` 是 FP16（2 字节）且 `THREAD_GROUP_SIZE` 是 2，那么 `VEC_SIZE` 将是 4，而 `V_VEC_SIZE` 将是 8。
- **线程组**：线程组是一小组线程（`THREAD_GROUP_SIZE`），每次获取和计算一个查询令牌和一个键令牌。每个线程只处理令牌数据的一部分。一个线程组处理的元素总数被称为 `x`。例如，如果线程组包含 2 个线程且头大小是 8，那么线程 0 处理索引 0、2、4、6 处的查询和键元素，而线程 1 处理索引 1、3、5、7 处的元素。
- **块**：vLLM 中的键和值缓存数据被分割成块。每个块存储一个头中固定数量（`BLOCK_SIZE`）令牌的数据。每个块可能只包含整个上下文令牌的一部分。例如，如果块大小是 16 且头大小是 128，那么对于一个头，一个块可以存储 16 * 128 = 2048 个元素。
- **线程束**：线程束是一组 32 个线程（`WARP_SIZE`），它们在流多处理器（SM）上同时执行。在此内核中，每个线程束每次处理一个查询令牌与一个完整块的键令牌之间的计算（它可能在多次迭代中处理多个块）。例如，如果有 4 个线程束和一个上下文的 6 个块，分配将像线程束 0 处理第 0 和第 4 块，线程束 1 处理第 1 和第 5 块，线程束 2 处理第 2 块，线程束 3 处理第 3 块。
- **线程块**：线程块是一组线程（`NUM_THREADS`），它们可以访问相同的共享内存。每个线程块包含多个线程束（`NUM_WARPS`），在此内核中，每个线程块处理一个查询令牌与整个上下文的键令牌之间的计算。
- **网格**：网格是线程块的集合，定义了集合的形状。在此内核中，形状是 `(num_heads, num_seqs, max_num_partitions)`。因此，每个线程块只处理一个头、一个序列和一个分区的计算。

## 查询

本节将介绍查询数据在内存中的存储方式以及每个线程如何获取它。如上所述，每个线程组获取一个查询令牌数据，而每个线程本身只处理一个查询令牌数据的一部分。在每个线程束中，每个线程组都将获取相同的查询令牌数据，但会将其与不同的键令牌数据相乘。

```cpp
const scalar_t* q_ptr = q + seq_idx * q_stride + head_idx * HEAD_SIZE;
```

![query](../assets/design/paged_attention/query.png)

每个线程定义自己的 `q_ptr`，该指针指向全局内存中分配的查询令牌数据。例如，如果 `VEC_SIZE` 是 4 且 `HEAD_SIZE` 是 128，则 `q_ptr` 指向包含总共 128 个元素的数据，分为 128 / 4 = 32 个向量。

![q_vecs](../assets/design/paged_attention/q_vecs.png)

```cpp
__shared__ Q_vec q_vecs[THREAD_GROUP_SIZE][NUM_VECS_PER_THREAD];
```

接下来，我们需要将 `q_ptr` 指向的全局内存数据读取到共享内存中，作为 `q_vecs`。需要注意的是，每个 vecs 被分配到不同的行。例如，如果 `THREAD_GROUP_SIZE` 为 2，线程 0 将处理第 0 行的 vecs，而线程 1 处理第 1 行的 vecs。通过这种方式读取查询数据，相邻线程（如线程 0 和线程 1）可以读取相邻内存，实现内存合并以提高性能。

## Key

与“Query”部分类似，本节介绍键数据的内存布局和分配。虽然每个线程组在一次内核运行中只处理一个查询 token，但在多次迭代中可能处理多个键 token。同时，每个 warp 将在多次迭代中处理多个键 token 块，确保在内核运行结束后，所有上下文 token 都能被整个线程组处理。在这里，“handle”指的是执行查询数据与键数据之间的点乘操作。

```cpp
const scalar_t* k_ptr = k_cache + physical_block_number * kv_block_stride
                    + kv_head_idx * kv_head_stride
                    + physical_block_offset * x;
```

与 `q_ptr` 不同，每个线程的 `k_ptr` 在不同迭代中将指向不同的键 token。如上所示，`k_ptr` 根据 `k_cache`、分配的块、分配的头和分配的 token 指向键 token 数据。

![key](../assets/design/paged_attention/key.png)

上图说明了键数据的内存布局。它假设 `BLOCK_SIZE` 为 16，`HEAD_SIZE` 为 128，`x` 为 8，`THREAD_GROUP_SIZE` 为 2，总共有 4 个 warp。每个矩形代表一个头中一个键 token 的所有元素，将由一个线程组处理。左半部分显示了 warp 0 的 16 个键 token 数据块，右半部分表示其他 warp 或迭代的其余键 token 数据。每个矩形内部总共包含 32 个 vecs（一个 token 的 128 个元素），将由 2 个线程（一个线程组）分别处理。

![k_vecs](../assets/design/paged_attention/k_vecs.png)

```cpp
K_vec k_vecs[NUM_VECS_PER_THREAD]
```

接下来，我们需要从 `k_ptr` 读取键 token 数据并将其存储在寄存器内存中作为 `k_vecs`。我们使用寄存器内存存储 `k_vecs`，因为其仅被单个线程访问一次，而 `q_vecs` 将被多个线程多次访问。每个 `k_vecs` 将包含多个向量供后续计算使用。每个 vec 在每次内循环中设置。vecs 的分配允许 warp 内相邻线程一起读取相邻内存，再次促进内存合并。例如，线程 0 读取 vec 0，线程 1 读取 vec 1。在下一次内循环中，线程 0 读取 vec 2，线程 1 读取 vec 3，依此类推。

你可能仍然对整体流程有些困惑。别担心，请继续阅读下面的“QK”部分。它将以更清晰和更高层次的方式说明查询和键的计算流程。

## QK

如下伪代码所示，在整个 for 循环块之前，我们先获取一个 token 的查询数据并将其存储在 `q_vecs` 中。然后，在外层 for 循环中，我们遍历指向不同 token 的不同 `k_ptrs`，并在内层 for 循环中准备 `k_vecs`。最后，我们执行 `q_vecs` 与每个 `k_vecs` 之间的点乘操作。

```cpp
q_vecs = ...
for ... {
    k_ptr = ...
    for ... {
        k_vecs[i] = ...
    }
    ...
    float qk = scale * Qk_dot<scalar_t, THREAD_GROUP_SIZE>::dot(q_vecs[thread_group_offset], k_vecs);
}
```

如前所述，对于每个线程，它一次只获取查询和键 token 数据的一部分。然而，在 `Qk_dot<>::dot` 中会进行跨线程组的约简操作。因此，此处返回的 `qk` 不仅是查询和键 token 部分的点乘结果，实际上是整个查询与键 token 数据的完整结果。

例如，如果 `HEAD_SIZE` 为 128 且 `THREAD_GROUP_SIZE` 为 2，每个线程的 `k_vecs` 将包含总共 64 个元素。但是，返回的 `qk` 实际上是 128 个查询元素与 128 个键元素之间的点乘结果。如果你想了解更多关于点乘和约简的细节，可以参考 `Qk_dot<>::dot` 的实现。但为了简洁起见，本文档中将不再详细说明。

## Softmax

接下来，我们需要为所有 `qk` 计算归一化的 softmax，如上所示，其中每个 $x$ 代表一个 `qk`。为此，我们必须获得 `qk_max`（$m(x)$）的约简值以及所有 `qk` 的 `exp_sum`（$\ell(x)$）。约简操作应在整个线程块上进行，涵盖查询 token 与所有上下文键 token 之间的结果。

$$
\begin{gather*}
m(x):=\max _i \quad x_i \\ \quad f(x):=\left[\begin{array}{lll}e^{x_1-m(x)} & \ldots & e^{x_B-m(x)}\end{array}\right]\\ \quad \ell(x):=\sum_i f(x)_i \\
\quad \operatorname{softmax}(x):=\frac{f(x)}{\ell(x)}
\end{gather*}
$$

### `qk_max` 和 `logits`

刚刚得到 `qk` 结果后，我们可以用 `qk` 设置临时的 `logits` 结果（最终，`logits` 应存储归一化的 softmax 结果）。同时，我们可以比较并收集当前线程组计算的所有 `qk` 的 `qk_max`。

```cpp
if (thread_group_offset == 0) {
    const bool mask = token_idx >= context_len;
    logits[token_idx - start_token_idx] = mask ? 0.f : qk;
    qk_max = mask ? qk_max : fmaxf(qk_max, qk);
}
```

请注意，此处的 `logits` 位于共享内存中，因此每个线程组将为其分配的上下文 token 设置相应字段。总体而言，`logits` 的大小应为上下文 token 的数量。

```cpp
for (int mask = WARP_SIZE / 2; mask >= THREAD_GROUP_SIZE; mask /= 2) {
    qk_max = fmaxf(qk_max, VLLM_SHFL_XOR_SYNC(qk_max, mask));
}

if (lane == 0) {
    red_smem[warp_idx] = qk_max;
}
```

然后我们需要在每个 warp 中获得约简的 `qk_max`。主要思想是让 warp 内的线程相互通信以获得最终的最大 `qk`。

```cpp
for (int mask = NUM_WARPS / 2; mask >= 1; mask /= 2) {
    qk_max = fmaxf(qk_max, VLLM_SHFL_XOR_SYNC(qk_max, mask));
}
qk_max = VLLM_SHFL_SYNC(qk_max, 0);
```

最后，我们可以通过比较该线程块中所有 warp 的 `qk_max` 来获得整个线程块的约简 `qk_max`。然后需要将最终结果广播到每个线程。

### `exp_sum`

类似于 `qk_max`，我们也需要从整个线程块获得约简的求和值。

```cpp
for (int i = thread_idx; i < num_tokens; i += NUM_THREADS) {
    float val = __expf(logits[i] - qk_max);
    logits[i] = val;
    exp_sum += val;
}
...
exp_sum = block_sum<NUM_WARPS>(&red_smem[NUM_WARPS], exp_sum);
```

首先，求和每个线程组中所有 exp 值，同时将 `logits` 中的每个条目从 `qk` 转换为 `exp(qk - qk_max)`。请注意，此处的 `qk_max` 已经是整个线程块中的最大 `qk`。然后我们可以像 `qk_max` 一样，在整个线程块中对 `exp_sum` 进行约简。

```cpp
const float inv_sum = __fdividef(1.f, exp_sum + 1e-6f);
for (int i = thread_idx; i < num_tokens; i += NUM_THREADS) {
    logits[i] *= inv_sum;
}
```

最后，借助约简的 `qk_max` 和 `exp_sum`，我们可以获得最终的归一化 softmax 结果作为 `logits`。此 `logits` 变量将在后续步骤中用于与值数据的点乘操作。现在，它应存储所有分配上下文 token 的 `qk` 归一化 softmax 结果。

## Value

![value](../assets/design/paged_attention/value.png)

![logits_vec](../assets/design/paged_attention/logits_vec.png)

![v_vec](../assets/design/paged_attention/v_vec.png)

现在我们需要检索值数据并将其与 `logits` 进行点乘操作。与查询和键不同，值数据没有线程组概念。如图所示，与键 token 内存布局不同，相同列中的元素对应同一个值 token。对于一个值数据块，有 `HEAD_SIZE` 行和 `BLOCK_SIZE` 列，被分割为多个 `v_vecs`。

每个线程总是每次从相同数量的 token 中获取 `V_VEC_SIZE` 个元素。因此，单个线程通过多次内部迭代从不同行和相同列中检索多个 `v_vec`。对于每个 `v_vec`，需要与对应的 `logits_vec` 进行点积运算，该 `logits_vec` 也是从 `logits` 中取出的 `V_VEC_SIZE` 个元素。总体而言，通过多次内部迭代，每个 warp 将处理一个价值 token 块。通过多次外部迭代，整个上下文价值 token 都将被处理。

```cpp
float accs[NUM_ROWS_PER_THREAD];
for ... { // 在不同块上的迭代。
    logits_vec = ...
    for ... { // 在不同行上的迭代。
        v_vec = ...
        ...
        accs[i] += dot(logits_vec, v_vec);
    }
}
```

如上述伪代码所示，在外部循环中，类似于 `k_ptr`，`logits_vec` 在不同块上迭代，从 `logits` 中读取 `V_VEC_SIZE` 个元素。在内部循环中，每个线程从相同 token 读取 `V_VEC_SIZE` 个元素作为 `v_vec` 并执行点积运算。需要注意的是，在每次内部迭代中，线程为相同 token 获取不同的头位置元素。点积结果随后累积到 `accs` 中。因此，`accs` 的每个条目映射到当前线程分配的头位置。

例如，如果 `BLOCK_SIZE` 为 16 且 `V_VEC_SIZE` 为 8，则每个线程每次为 8 个 token 获取 8 个价值元素。每个元素来自相同头位置的不同 token。如果 `HEAD_SIZE` 为 128 且 `WARP_SIZE` 为 32，则每次内部循环，一个 warp 需要获取 `WARP_SIZE * V_VEC_SIZE = 256` 个元素。这意味着一个 warp 处理整个价值 token 块总共需要 128 * 16 / 256 = 8 次内部迭代。并且每个线程中的每个 `accs` 包含在 8 个不同头位置累积的 8 个元素。对于线程 0，`accs` 变量将有 8 个元素，它们是从分配的所有 8 个 token 累积的值头的第 0、32、...、224 个元素。

## LV

现在，我们需要在每个 warp 内对 `accs` 执行约简操作。此过程允许每个线程为一个块中所有 token 的分配头位置累积 `accs`。

```cpp
for (int i = 0; i < NUM_ROWS_PER_THREAD; i++) {
    float acc = accs[i];
    for (int mask = NUM_V_VECS_PER_ROW / 2; mask >= 1; mask /= 2) {
        acc += VLLM_SHFL_XOR_SYNC(acc, mask);
    }
    accs[i] = acc;
}
```

接下来，我们在所有 warp 之间对 `accs` 执行约简操作，使每个线程拥有所有上下文 token 的分配头位置的 `accs` 累积。请注意，每个线程中的每个 `accs` 仅存储所有上下文 token 的整个头的一部分元素的累积。然而，总体而言，所有输出结果都已计算完成，只是存储在不同的线程寄存器内存中。

??? code

    ```cpp
    float* out_smem = reinterpret_cast<float*>(shared_mem);
    for (int i = NUM_WARPS; i > 1; i /= 2) {
        // 上层 warp 写入共享内存。
        ...
        float* dst = &out_smem[(warp_idx - mid) * HEAD_SIZE];
        for (int i = 0; i < NUM_ROWS_PER_THREAD; i++) {
            ...
            dst[row_idx] = accs[i];
        }

        // 下层 warp 更新输出。
        const float* src = &out_smem[warp_idx * HEAD_SIZE];
        for (int i = 0; i < NUM_ROWS_PER_THREAD; i++) {
            ...
            accs[i] += src[row_idx];
        }

        // 写出 accs。
    }
    ```

## Output

现在我们可以将所有计算结果从本地寄存器内存写入最终的输出全局内存。

```cpp
scalar_t* out_ptr = out + seq_idx * num_heads * max_num_partitions * HEAD_SIZE
                + head_idx * max_num_partitions * HEAD_SIZE
                + partition_idx * HEAD_SIZE;
```

首先，我们需要定义 `out_ptr` 变量，它指向分配序列和分配头的起始地址。

```cpp
for (int i = 0; i < NUM_ROWS_PER_THREAD; i++) {
    const int row_idx = lane / NUM_V_VECS_PER_ROW + i * NUM_ROWS_PER_ITER;
    if (row_idx < HEAD_SIZE && lane % NUM_V_VECS_PER_ROW == 0) {
        from_float(*(out_ptr + row_idx), accs[i]);
    }
}
```

最后，我们需要遍历不同的分配头位置，并根据 `out_ptr` 写出相应的累积结果。

## Citation

```bibtex
@inproceedings{kwon2023efficient,
  title={Efficient Memory Management for Large Language Model Serving with PagedAttention},
  author={Woosuk Kwon and Zhuohan Li and Siyuan Zhuang and Ying Sheng and Lianmin Zheng and Cody Hao Yu and Joseph E. Gonzalez and Hao Zhang and Ion Stoica},
  booktitle={Proceedings of the ACM SIGOPS 29th Symposium on Operating Systems Principles},
  year={2023}
}
```