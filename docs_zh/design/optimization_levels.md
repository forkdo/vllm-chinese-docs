# 优化级别

## 概述

vLLM 现在支持优化级别 (`-O0`, `-O1`, `-O2`, `-O3`)。优化级别为用户提供了一种直观的机制，可以在启动时间和性能之间进行权衡。更高级别的优化具有更好的性能但启动时间更长。这些优化级别具有相关默认设置，帮助用户获得预期的开箱即用性能。重要的是，由优化级别设置的默认值纯粹是默认值；明确的用户设置不会被覆盖。

## 级别摘要和使用示例
```bash
# CLI 使用
python -m vllm.entrypoints.api_server --model RedHatAI/Llama-3.2-1B-FP8 -O0

# Python API 使用
from vllm.entrypoints.llm import LLM

llm = LLM(
    model="RedHatAI/Llama-3.2-1B-FP8",
    optimization_level=0
)
```

#### `-O1`: 快速优化
- **启动时间**: 中等启动时间
- **性能**: Inductor 编译，CUDAGraphMode.PIECEWISE
- **使用场景**: 大多数开发场景的平衡选择

```bash
# CLI 使用
python -m vllm.entrypoints.api_server --model RedHatAI/Llama-3.2-1B-FP8 -O1

# Python API 使用
from vllm.entrypoints.llm import LLM

llm = LLM(
    model="RedHatAI/Llama-3.2-1B-FP8",
    optimization_level=1
)
```

#### `-O2`: 完整优化（默认）
- **启动时间**: 更长的启动时间
- **性能**: `-O1` + CUDAGraphMode.FULL_AND_PIECEWISE
- **使用场景**: 性能重要的生产工作负载。这是默认使用场景。它也非常类似于之前的默认设置。主要区别是启用了 noop 和融合标志。

```bash
# CLI 使用（默认，可选）
python -m vllm.entrypoints.api_server --model RedHatAI/Llama-3.2-1B-FP8 -O2

# Python API 使用
from vllm.entrypoints.llm import LLM

llm = LLM(
    model="RedHatAI/Llama-3.2-1B-FP8",
    optimization_level=2  # 这是默认值
)
```

#### `-O3`: 完整优化
仍在开发中。添加了基础设施以防止在将来版本中更改 API。目前行为与 O2 相同。

## 故障排除

### 常见问题

1. **启动时间过长**: 使用 `-O0` 或 `-O1` 以获得更快的启动
2. **编译错误**: 使用 `debug_dump_path` 获取额外的调试信息
3. **性能问题**: 确保在生产环境中使用 `-O2`