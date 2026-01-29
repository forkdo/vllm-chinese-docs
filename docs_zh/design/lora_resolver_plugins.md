# LoRA 解析器插件

此目录包含基于 `LoRAResolver` 框架构建的 vLLM LoRA 解析器插件。  
这些插件能够自动从指定的本地存储路径发现并加载 LoRA 适配器，无需手动配置或重启服务器。

## 概述

LoRA 解析器插件提供了一种灵活的方式，可在运行时动态加载 LoRA 适配器。当 vLLM 收到对尚未加载的 LoRA 适配器的请求时，解析器插件会尝试从其配置的存储位置定位并加载该适配器。这实现了以下功能：

- **动态 LoRA 加载**：按需加载适配器，无需重启服务器
- **多存储后端支持**：支持文件系统、S3 和自定义后端。内置的 `lora_filesystem_resolver` 需要本地存储路径，而内置的 `hf_hub_resolver` 会从 Huggingface Hub 拉取 LoRA 适配器并以相同方式处理。通常，可以自定义解析器以从任意源获取适配器。
- **自动发现**：与现有 LoRA 工作流无缝集成
- **可扩展部署**：在多个 vLLM 实例间集中管理适配器

## 先决条件

使用 LoRA 解析器插件前，请确保已配置以下环境变量：

### 必需环境变量

1. **`VLLM_ALLOW_RUNTIME_LORA_UPDATING`**：必须设为 `true` 或 `1` 以启用动态 LoRA 加载  
   ```bash
   export VLLM_ALLOW_RUNTIME_LORA_UPDATING=true
   ```

2. **`VLLM_PLUGINS`**：必须包含所需的解析器插件（逗号分隔列表）  
   ```bash
   export VLLM_PLUGINS=lora_filesystem_resolver
   ```

3. **`VLLM_LORA_RESOLVER_CACHE_DIR`**：必须设为文件系统解析器使用的有效目录路径  
   ```bash
   export VLLM_LORA_RESOLVER_CACHE_DIR=/path/to/lora/adapters
   ```

### 可选环境变量

- **`VLLM_PLUGINS`**：如果未设置，将加载所有可用插件。如果设为空字符串，则不加载任何插件。

## 可用解析器

### lora_filesystem_resolver

文件系统解析器默认随 vLLM 安装，支持从本地目录结构加载 LoRA 适配器。

#### 设置步骤

1. **创建 LoRA 适配器存储目录**：  
   ```bash
   mkdir -p /path/to/lora/adapters
   ```

2. **设置环境变量**：  
   ```bash
   export VLLM_ALLOW_RUNTIME_LORA_UPDATING=true
   export VLLM_PLUGINS=lora_filesystem_resolver
   export VLLM_LORA_RESOLVER_CACHE_DIR=/path/to/lora/adapters
   ```

3. **启动 vLLM 服务器**：  
   基础模型可以是 `meta-llama/Llama-2-7b-hf`。请确保已在环境变量中设置 Hugging Face Token：`export HF_TOKEN=xxx235`。  
   ```bash
   python -m vllm.entrypoints.openai.api_server \
       --model your-base-model \
       --enable-lora
   ```

#### 目录结构要求

文件系统解析器期望 LoRA 适配器按以下结构组织：

```text
/path/to/lora/adapters/
├── adapter1/
│   ├── adapter_config.json
│   ├── adapter_model.bin
│   └── tokenizer files (if applicable)
├── adapter2/
│   ├── adapter_config.json
│   ├── adapter_model.bin
│   └── tokenizer files (if applicable)
└── ...
```

每个适配器目录必须包含：

- **`adapter_config.json`**：必需的配置文件，结构如下：  
  ```json
  {
    "peft_type": "LORA",
    "base_model_name_or_path": "your-base-model-name",
    "r": 16,
    "lora_alpha": 32,
    "target_modules": ["q_proj", "v_proj"],
    "bias": "none",
    "modules_to_save": null,
    "use_rslora": false,
    "use_dora": false
  }
  ```

- **`adapter_model.bin`**：LoRA 适配器权重文件

#### 使用示例

1. **准备 LoRA 适配器**：  
   ```bash
   # 假设你的 LoRA 适配器位于 /tmp/my_lora_adapter
   cp -r /tmp/my_lora_adapter /path/to/lora/adapters/my_sql_adapter
   ```

2. **验证目录结构**：  
   ```bash
   ls -la /path/to/lora/adapters/my_sql_adapter/
   # 应显示：adapter_config.json、adapter_model.bin 等
   ```

3. **使用适配器发起请求**：  
   ```bash
   curl http://localhost:8000/v1/completions \
       -H "Content-Type: application/json" \
       -d '{
           "model": "my_sql_adapter",
           "prompt": "Generate a SQL query for:",
           "max_tokens": 50,
           "temperature": 0.1
       }'
   ```

#### 工作原理

1. 当 vLLM 收到对名为 `my_sql_adapter` 的 LoRA 适配器的请求时  
2. 文件系统解析器检查 `/path/to/lora/adapters/my_sql_adapter/` 是否存在  
3. 如果存在，则验证 `adapter_config.json` 文件  
4. 如果配置与基础模型匹配且有效，则加载该适配器  
5. 使用新加载的适配器正常处理请求  
6. 该适配器将保留以供后续请求使用

## 高级配置

### 多解析器

你可以配置多个解析器插件，以从不同源加载适配器：

`lora_s3_resolver` 是你需要实现的自定义解析器示例

```bash
export VLLM_PLUGINS=lora_filesystem_resolver,lora_s3_resolver
```

所有列出的解析器均会被启用；在请求时，vLLM 按顺序尝试它们，直到其中一个成功。

### 自定义解析器实现

要实现你自己的解析器插件：

1. **创建新的解析器类**：  
   ```python
   from vllm.lora.resolver import LoRAResolver, LoRAResolverRegistry
   from vllm.lora.request import LoRARequest
   
   class CustomResolver(LoRAResolver):
       async def resolve_lora(self, base_model_name: str, lora_name: str) -> Optional[LoRARequest]:
           # 在此处实现你的自定义解析逻辑
           pass
   ```

2. **注册解析器**：  
   ```python
   def register_custom_resolver():
       resolver = CustomResolver()
       LoRAResolverRegistry.register_resolver("Custom Resolver", resolver)
   ```

## 故障排除

### 常见问题

1. **"VLLM_LORA_RESOLVER_CACHE_DIR must be set to a valid directory"**  
   - 确保目录存在且可访问  
   - 检查目录的文件权限

2. **"LoRA adapter not found"**  
   - 验证适配器目录名称是否与请求的模型名称匹配  
   - 检查 `adapter_config.json` 是否存在且为有效 JSON  
   - 确保 `adapter_model.bin` 存在于目录中

3. **"Invalid adapter configuration"**  
   - 验证 `peft_type` 是否设为 "LORA"  
   - 检查 `base_model_name_or_path` 是否与你的基础模型匹配  
   - 确保 `target_modules` 配置正确

4. **"LoRA rank exceeds maximum"**  
   - 检查 `adapter_config.json` 中的 `r` 值是否未超过 `max_lora_rank` 设置

### 调试技巧

1. **启用调试日志**：  
   ```bash
   export VLLM_LOGGING_LEVEL=DEBUG
   ```

2. **验证环境变量**：  
   ```bash
   echo $VLLM_ALLOW_RUNTIME_LORA_UPDATING
   echo $VLLM_PLUGINS
   echo $VLLM_LORA_RESOLVER_CACHE_DIR
   ```

3. **测试适配器配置**：  
   ```bash
   python -c "
   import json
   with open('/path/to/lora/adapters/my_adapter/adapter_config.json') as f:
       config = json.load(f)
   print('Config valid:', config)
   "
   ```