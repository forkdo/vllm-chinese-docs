# 模型解析

vLLM 通过检查模型仓库中 `config.json` 文件的 `architectures` 字段，并查找注册到 vLLM 的对应实现，来加载与 HuggingFace 兼容的模型。
然而，我们的模型解析可能会因以下原因失败：

- 模型仓库的 `config.json` 缺少 `architectures` 字段。
- 非官方仓库使用 vLLM 未记录的替代名称来引用模型。
- 多个模型使用相同的架构名称，导致无法确定应加载哪个模型。

要解决此问题，请通过向 `hf_overrides` 选项传递 `config.json` 覆盖项来显式指定模型架构。
例如：

```python
from vllm import LLM

llm = LLM(
    model="cerebras/Cerebras-GPT-1.3B",
    hf_overrides={"architectures": ["GPT2LMHeadModel"]},  # GPT-2
)
```

我们的[支持模型列表](../models/supported_models.md)展示了 vLLM 可识别的模型架构。