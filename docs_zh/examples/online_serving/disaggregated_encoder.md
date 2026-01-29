# 分离式编码器

源码 <https://github.com/vllm-project/vllm/tree/main/examples/online_serving/disaggregated_encoder>。

这些示例脚本演示了 vLLM 的分离式编码器（EPD）功能。

有关 EPD 功能的详细说明，请参阅[分离式编码器功能文档](https://github.com/vllm-project/vllm/tree/main/docs/features/disagg_encoder.md)。

## 文件

- `disagg_epd_proxy.py` - 演示 XeYpZd 设置的代理脚本（X 个编码实例，Y 个预填充实例，Z 个解码实例）。目前 1e1p1d 配置稳定可用。

- `disagg_1e1p1d_example.sh` - 设置 1e1p1d 配置，运行 VisionArena 基准测试，并使用本地图像处理单个请求。

- `disagg_1e1pd_example.sh` - 设置 1e1pd 配置，运行 VisionArena 基准测试，并使用本地图像处理单个请求。

### 自定义配置

```bash
# 使用特定 GPU
GPU_E=0 GPU_PD=1 GPU_P=1 GPU_D=2 bash disagg_1e1p1d_example.sh

# 使用特定端口
ENDPOINT_PORT=10001 bash disagg_1e1p1d_example.sh

# 使用特定模型
MODEL="Qwen/Qwen2.5-VL-3B-Instruct" bash disagg_1e1p1d_example.sh

# 使用特定存储路径
EC_SHARED_STORAGE_PATH="/tmp/my_ec_cache" bash disagg_1e1p1d_example.sh
```

## 编码器实例

编码器引擎应使用以下标志启动：

- `--enforce-eager` **(必需)** - 当前的 EPD 实现仅兼容以该模式运行的编码器实例。

- `--no-enable-prefix-caching` **(必需)** - 编码器实例不消耗 KV 缓存；禁用前缀缓存以避免与其他功能冲突。

- `--max-num-batched-tokens=<较大值>` **(默认值：2048)** - 此标志控制每个解码步骤的令牌调度预算，与仅编码器实例无关。**将其设置为非常高的值（实际上无限制）以绕过调度器限制。** 实际令牌预算由编码器缓存管理器管理。

- `--mm-encoder-only` **(可选)** - 如果可能，在初始化期间跳过语言模型以减少设备内存使用。

## 本地媒体输入

要支持本地图像输入（来自您的 ```MEDIA_PATH``` 目录），请将以下标志添加到编码器实例：

```bash
--allowed-local-media-path $MEDIA_PATH
```

vllm 实例和 `disagg_encoder_proxy` 支持使用 ```{"url": "file://'"$MEDIA_PATH_FILENAME"'}``` 作为多模态输入的本地 URI。每个 URI 从 `disagg_encoder_proxy` 原样传递到编码器实例，以便编码器可以本地加载媒体。

## EC 连接器和 KV 传输

`ECExampleonnector` 用于在本地磁盘上存储编码器缓存并促进传输。要启用编码器分离功能，请添加以下配置：

```bash
# 添加到编码器实例：
--ec-transfer-config '{
    "ec_connector": "ECExampleConnector",
    "ec_role": "ec_producer",
    "ec_connector_extra_config": {
        "shared_storage_path": "'"$EC_SHARED_STORAGE_PATH"'"
    }
}' 

# 添加到预填充/预填充+解码实例：
--ec-transfer-config '{
    "ec_connector": "ECExampleConnector",
    "ec_role": "ec_consumer",
    "ec_connector_extra_config": {
        "shared_storage_path": "'"$EC_SHARED_STORAGE_PATH"'"
    }
}' 
```

`$EC_SHARED_STORAGE_PATH` 是 EC 连接器临时存储缓存的路径。

如果启用预填充实例（`--prefill-servers-urls` 未禁用），您将需要 --kv-transfer-config 来实现 PD 分离。目前，我们使用 `NixlConnector` 来实现此目的。有关使用 Nixl 进行 PD 分离的更多示例代码，请参阅 `tests/v1/kv_connector/nixl_integration`。

```bash
# 添加到预填充实例：
--kv-transfer-config '{
    "kv_connector": "NixlConnector",
    "kv_role": "kv_producer"
}' 

# 添加到解码实例：
--kv-transfer-config '{
    "kv_connector": "NixlConnector",
    "kv_role": "kv_consumer"
}' 
```

## 代理实例标志 (`disagg_epd_proxy.py`)

| 标志 | 描述 |
|------|-------------|
| `--encode-servers-urls` | 编码器端点的逗号分隔列表。从请求中提取的每个多模态项以轮询方式分发到这些 URL 之一。 |
| `--prefill-servers-urls` | 预填充端点的逗号分隔列表。设置为 `disable`、`none` 或 `""` 以跳过专用预填充阶段并运行 E+PD（编码器 + 组合预填充/解码）。 |
| `--decode-servers-urls` | 解码端点的逗号分隔列表。非流式传输和流式传输路径都对此列表进行轮询。 |
| `--host`, `--port` | 代理本身的绑定地址（默认值：`0.0.0.0:8000`）。 |

使用示例：
对于 E + PD 设置：

```bash
$ python disagg_encoder_proxy.py \
      --encode-servers-urls "http://e1:8001,http://e2:8002" \
      --prefill-servers-urls "disable" \
      --decode-servers-urls "http://pd1:8003,http://pd2:8004"
```

对于 E + P + D 设置：

```bash
$ python disagg_encoder_proxy.py \
      --encode-servers-urls "http://e1:8001,http://e2:8001" \
      --prefill-servers-urls "http://p1:8003,http://p2:8004" \ 
      --decode-servers-urls "http://d1:8005,http://d2:8006"
```

## 示例材料

??? abstract "disagg_1e1p1d_example.sh"
    ``````sh
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/disaggregated_encoder/disagg_1e1p1d_example.sh"
    ``````
??? abstract "disagg_1e1pd_example.sh"
    ``````sh
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/disaggregated_encoder/disagg_1e1pd_example.sh"
    ``````
??? abstract "disagg_epd_proxy.py"
    ``````py
    --8<-- "/root/workspaces/docs/vllm-chinese-docs/docsite/examples/online_serving/disaggregated_encoder/disagg_epd_proxy.py"
    ``````