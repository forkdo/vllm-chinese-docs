# 专家并行部署

vLLM 支持专家并行（Expert Parallelism, EP），该技术允许混合专家（MoE）模型中的专家分布在不同的 GPU 上，从而提升局部性、效率和整体吞吐量。

EP 通常与数据并行（Data Parallelism, DP）结合使用。虽然 DP 可以独立于 EP 使用，但与 DP 联合使用时，EP 效率更高。您可以在这里了解更多关于数据并行的信息：[data_parallel_deployment.md](data_parallel_deployment.md)。

## 前置条件

在使用 EP 之前，您需要安装必要的依赖项。我们正在积极改进这一过程，使其在未来更加便捷：

1. **安装 DeepEP 和 pplx-kernels**：按照 vLLM 为 EP 内核提供的指南设置主机环境：[ep_kernels](../../tools/ep_kernels)。
2. **安装 DeepGEMM 库**：请遵循[官方说明](https://github.com/deepseek-ai/DeepGEMM#installation)。
3. **用于解耦部署**：通过运行 [`install_gdrcopy.sh`](../../tools/install_gdrcopy.sh) 脚本安装 `gdrcopy`（例如：`install_gdrcopy.sh "${GDRCOPY_OS_VERSION}" "12.8" "x64"`）。您可以在[此处](https://developer.download.nvidia.com/compute/redist/gdrcopy/CUDA%2012.8/)找到可用的操作系统版本。

### 后端选择指南

vLLM 为 EP 提供了多种通信后端。使用 `--all2all-backend` 来选择其中之一：

| 后端 | 使用场景 | 功能 | 最适合 |
|------|----------|------|--------|
| `allgather_reducescatter` | 默认后端 | 使用 allgather/reducescatter 原语的标准 all2all | 通用用途，适用于任何 EP+DP 配置 |
| `pplx` | 单节点 | 支持分块预填充，高效节点内通信 | 单节点部署，开发环境 |
| `deepep_high_throughput` | 多节点预填充 | 带连续布局的分组 GEMM，针对预填充优化 | 以预填充为主的负载，高吞吐场景 |
| `deepep_low_latency` | 多节点解码 | 支持 CUDA 图，带掩码布局，针对解码优化 | 以解码为主的负载，低延迟场景 |
| `flashinfer_all2allv` | MNNVL 系统 | FlashInfer alltoallv 内核用于多节点 NVLink | 节点间具备 NVLink 的系统 |
| `naive` | 测试/调试 | 基于广播的简单实现 | 调试，不推荐用于生产环境 |

## 单节点部署

!!! warning
    EP 是一项实验性功能。参数名称和默认值可能在将来发生变化。

### 配置

通过设置 `--enable-expert-parallel` 标志启用 EP。EP 大小会自动计算为：

```text
EP_SIZE = TP_SIZE × DP_SIZE
```

其中：

- `TP_SIZE`：张量并行大小
- `DP_SIZE`：数据并行大小
- `EP_SIZE`：专家并行大小（自动计算）

### 启用 EP 时的层行为

启用 EP 后，MoE 模型中的不同层行为各异：

| 层类型 | 行为 | 使用的并行方式 |
|--------|------|----------------|
| **专家（MoE）层** | 在所有 EP 排名上分片 | 专家并行（EP），大小为 `TP × DP` |
| **注意力层** | 行为取决于 TP 大小 | 详见下文 |

**注意力层并行方式：**

- **当 `TP = 1`**：注意力权重在所有 DP 排名上**复制**（数据并行）
- **当 `TP > 1`**：注意力权重在每个 DP 组内的 TP 排名上使用**张量并行**分片

例如，使用 `TP=2, DP=4`（共 8 个 GPU）：

- 专家层形成大小为 8 的 EP 组，专家分布在所有 GPU 上
- 注意力层在每个 DP 组内使用 TP=2

!!! note "与数据并行部署的关键差异"
    在未启用 `--enable-expert-parallel` 时，MoE 层会使用张量并行（形成大小为 `TP × DP` 的 TP 组），类似于密集模型。启用 EP 后，专家层切换为专家并行，这可能为 MoE 模型提供更好的效率和局部性。

### 示例命令

以下命令在 8 个 GPU 的 H200（或 H20）节点上部署 `DeepSeek-V3-0324` 模型，采用 1 路张量并行、8 路（注意力）数据并行和 8 路专家并行。注意力权重在所有 GPU 上复制，而专家权重在 GPU 之间分片。对于 H100，您可以尝试部署较小的模型，或参考多节点部署部分。

```bash
# 使用 pplx 后端的单节点 EP 部署
vllm serve deepseek-ai/DeepSeek-V3-0324 \
    --tensor-parallel-size 1 \       # 跨 1 个 GPU 的张量并行
    --data-parallel-size 8 \         # 跨 8 个进程的数据并行
    --enable-expert-parallel \       # 启用专家并行
    --all2all-backend pplx           # 使用 pplx 通信后端
```

## 多节点部署

对于多节点部署，请使用 DeepEP 通信内核，并选择以下两种模式之一（见上方[后端选择指南](#backend-selection-guide)）。

### 部署步骤

1. **每个节点运行一条命令** - 每个节点需要自己的启动命令
2. **配置网络** - 确保 IP 地址和端口配置正确
3. **设置节点角色** - 第一个节点处理请求，额外节点以无头模式运行

### 示例：2 节点部署

以下示例使用 `deepep_low_latency` 模式在 2 个节点上部署 `DeepSeek-V3-0324`：

```bash
# 节点 1（主节点 - 处理传入请求）
vllm serve deepseek-ai/DeepSeek-V3-0324 \
    --all2all-backend deepep_low_latency \
    --tensor-parallel-size 1 \               # 每个节点的 TP 大小
    --enable-expert-parallel \               # 启用 EP
    --data-parallel-size 16 \                # 所有节点的总 DP 大小
    --data-parallel-size-local 8 \           # 本节点的本地 DP 大小（每节点 8 个 GPU）
    --data-parallel-address 192.168.1.100 \  # 替换为节点 1 的实际 IP
    --data-parallel-rpc-port 13345 \         # RPC 通信端口，只要所有节点可达即可使用任意端口
    --api-server-count=8                     # 用于负载处理的 API 服务器数量（建议扩展到本地排名数量）

# 节点 2（从节点 - 无头模式，无 API 服务器）
vllm serve deepseek-ai/DeepSeek-V3-0324 \
    --all2all-backend deepep_low_latency \
    --tensor-parallel-size 1 \               # 每个节点的 TP 大小
    --enable-expert-parallel \               # 启用 EP
    --data-parallel-size 16 \                # 所有节点的总 DP 大小
    --data-parallel-size-local 8 \           # 本节点的本地 DP 大小
    --data-parallel-start-rank 8 \           # 本节点的起始排名偏移
    --data-parallel-address 192.168.1.100 \  # 主节点（节点 1）的 IP
    --data-parallel-rpc-port 13345 \         # 与主节点相同的 RPC 端口
    --headless                               # 无 API 服务器，仅作工作节点
```

### 关键配置说明

- **无头模式**：从节点使用 `--headless` 标志运行，意味着所有客户端请求均由主节点处理
- **排名计算**：`--data-parallel-start-rank` 应等于之前节点的累计本地 DP 大小
- **负载扩展**：在主节点上调整 `--api-server-count` 以处理更高的请求负载

### 网络配置

!!! important "InfiniBand 集群"
    在 InfiniBand 网络集群上，设置此环境变量以防止初始化挂起：
    ```bash
    export GLOO_SOCKET_IFNAME=eth0
    ```
    这确保 torch 分布式组发现使用以太网而非 InfiniBand 进行初始设置。

## 专家并行负载均衡器（EPLB）

虽然 MoE 模型通常被训练为每个专家接收相似数量的 token，但在实践中，token 在专家之间的分布可能高度不均。vLLM 提供了专家并行负载均衡器（Expert Parallel Load Balancer, EPLB），用于在 EP 排名之间重新分配专家映射，从而平衡专家间的负载。

### 配置

通过 `--enable-eplb` 标志启用 EPLB。

启用后，vLLM 在每次前向传播时收集负载统计信息，并定期重新平衡专家分布。

### EPLB 参数

通过 `--eplb-config` 参数配置 EPLB，该参数接受 JSON 字符串。可用键及其描述如下：

| 参数 | 描述 | 默认值 |
|-----------|-------------|---------|
| `window_size`| 用于重平衡决策的引擎步数窗口大小 | 1000 |
| `step_interval`| 重平衡频率（每 N 个引擎步数） | 3000 |
| `log_balancedness` | 记录平衡度指标（平均每专家 tokens ÷ 最大每专家 tokens） | `false` |
| `num_redundant_experts` | 除均衡分布外每 EP 排名的额外全局专家数 | `0` |
| `use_async` | 使用非阻塞 EPLB 以降低延迟开销 | `false` |
| `policy` | 专家并行负载均衡的策略类型 | `"default"` |

例如：

```bash
vllm serve Qwen/Qwen3-30B-A3B \
  --enable-eplb \
  --eplb-config '{"window_size":1000,"step_interval":3000,"num_redundant_experts":2,"log_balancedness":true}'
```

??? tip "更推荐使用单独参数而不是 JSON？"

    ```bash
    vllm serve Qwen/Qwen3-30B-A3B \
            --enable-eplb \
            --eplb-config.window_size 1000 \
            --eplb-config.step_interval 3000 \
            --eplb-config.num_redundant_experts 2 \
            --eplb-config.log_balancedness true
    ```

### 专家分布公式

- **默认**：每个 EP 排名拥有 `NUM_TOTAL_EXPERTS ÷ NUM_EP_RANKS` 个专家
- **带冗余**：每个 EP 排名拥有 `(NUM_TOTAL_EXPERTS + NUM_REDUNDANT_EXPERTS) ÷ NUM_EP_RANKS` 个专家

### 内存占用开销

EPLB 使用冗余专家，这些专家需要占用 GPU 内存。这意味着在内存受限环境或 KV 缓存空间紧张时，EPLB 可能不是最佳选择。

此开销等于 `NUM_MOE_LAYERS * BYTES_PER_EXPERT * (NUM_TOTAL_EXPERTS + NUM_REDUNDANT_EXPERTS) ÷ NUM_EP_RANKS`。
对于 DeepSeekV3，每 EP 排名一个冗余专家大约为 `2.4 GB`。

### 示例命令

启用 EPLB 的单节点部署：

```bash
# 单节点 EPLB 负载均衡
vllm serve deepseek-ai/DeepSeek-V3-0324 \
    --tensor-parallel-size 1 \       # 张量并行
    --data-parallel-size 8 \         # 数据并行
    --enable-expert-parallel \       # 启用 EP
    --all2all-backend pplx \         # 使用 pplx 通信后端
    --enable-eplb \                  # 启用负载均衡器
    --eplb-config '{"window_size":1000,"step_interval":3000,"num_redundant_experts":2,"log_balancedness":true}'
```

对于多节点部署，在每个节点的命令中添加这些 EPLB 标志。我们建议在大规模使用场景中将 `--eplb-config '{"num_redundant_experts":32}'` 设置为 32，以确保最受欢迎的专家始终可用。

## 高级配置

### 性能优化

- **DeepEP 内核**：`high_throughput` 和 `low_latency` 内核针对解耦服务进行了优化，可能在混合工作负载中表现不佳
- **双批重叠**：使用 `--enable-dbo` 将所有到所有通信与计算重叠。详情请参阅 [双批重叠](../design/dbo.md)
- **异步调度（实验性）**：尝试 `--async-scheduling` 将调度与模型执行重叠。

### 故障排除

- **`non-zero status: 7 cannot register cq buf`**：使用 Infiniband/RoCE 时，请确保主机虚拟机和 Pod 显示 `ulimit -l` 为“unlimited”
- **`init failed for transport: IBGDA`**：缺少 InfiniBand GDA 内核模块。在每个 GPU 节点上运行 `tools/ep_kernels/configure_system_drivers.sh` 并重启。同时修复错误 `NVSHMEM API called before NVSHMEM initialization has completed`
- **NVSHMEM 对等断开连接**：通常是网络配置错误。如果通过 Kubernetes 部署，请验证每个 Pod 都以 `hostNetwork: true`、`securityContext.privileged: true` 运行以访问 InfiniBand

### 性能测试

- 使用模拟标志 `VLLM_MOE_ROUTING_SIMULATION_STRATEGY=uniform_random` 和 `VLLM_RANDOMIZE_DP_DUMMY_INPUTS=1`，使令牌路由在 EP 排名之间均衡分布
- 增大 `VLLM_MOE_DP_CHUNK_SIZE` 可能通过增加跨排名令牌传输的最大批大小来提高吞吐量。这可能导致 DeepEP 抛出 `assert self.nvshmem_qp_depth >= (num_max_dispatch_tokens_per_rank + 1) * 2` 错误，可通过增加环境变量 `NVSHMEM_QP_DEPTH` 来解决

## 解耦服务（预填充/解码分离）

对于需要对首令牌时间和令牌间延迟提供严格 SLA 保证的生产部署，解耦服务允许独立扩展预填充和解码操作。

### 架构概览

- **预填充实例**：使用 `deepep_high_throughput` 后端以获得最佳预填充性能
- **解码实例**：使用 `deepep_low_latency` 后端以实现最小解码延迟
- **KV 缓存传输**：通过 NIXL 或其他 KV 连接器连接实例

### 设置步骤

1. **安装 gdrcopy/ucx/nixl**：为了获得最佳性能，运行 [install_gdrcopy.sh](../../tools/install_gdrcopy.sh) 脚本安装 `gdrcopy`（例如 `install_gdrcopy.sh "${GDRCOPY_OS_VERSION}" "12.8" "x64"`）。您可以在 [此处](https://developer.download.nvidia.com/compute/redist/gdrcopy/CUDA%2012.8/) 查找可用的操作系统版本。如果未安装 `gdrcopy`，仅使用 `pip install nixl` 仍可正常工作，但性能较低。`nixl` 和 `ucx` 通过 pip 安装为依赖项。对于非 CUDA 平台，要使用非 CUDA UCX 构建安装 nixl，请运行 [install_nixl_from_source_ubuntu.py](../../tools/install_nixl_from_source_ubuntu.py) 脚本

2. **配置两个实例**：在预填充和解码实例中都添加此标志 `--kv-transfer-config '{"kv_connector":"NixlConnector","kv_role":"kv_both"}`。注意，您也可以指定一个或多个 NIXL_Backend，例如：`--kv-transfer-config '{"kv_connector":"NixlConnector","kv_role":"kv_both", "kv_connector_extra_config":{"backends":["UCX", "GDS"]}}'`

3. **客户端编排**：使用下面的客户端脚本协调预填充/解码操作。我们正在积极开发路由解决方案

### 客户端编排示例

```python
from openai import OpenAI
import uuid

try:
    # 1: 为预填充和解码实例设置客户端
    openai_api_key = "EMPTY"  # vLLM 不需要真实的 API 密钥
    
    # 用实际的实例地址替换这些 IP 地址
    prefill_client = OpenAI(
        api_key=openai_api_key,
        base_url="http://192.168.1.100:8000/v1",  # 预填充实例 URL
    )
    decode_client = OpenAI(
        api_key=openai_api_key,
        base_url="http://192.168.1.101:8001/v1",  # 解码实例 URL  
    )
    
    # 从预填充实例获取模型名称
    models = prefill_client.models.list()
    model = models.data[0].id
    print(f"使用模型: {model}")

# 2: 预填充阶段
# 生成唯一请求 ID 以关联预填充和解码操作
request_id = str(uuid.uuid4())
print(f"请求 ID: {request_id}")

prefill_response = prefill_client.completions.create(
    model=model,
    # 提示词必须超过 vLLM 的块大小（16 个 token）才能使 PD 正常工作
    prompt="Write a detailed explanation of Paged Attention for Transformers works including the management of KV cache for multi-turn conversations",
    max_tokens=1,  # 强制仅预填充操作
    extra_body={
        "kv_transfer_params": {
            "do_remote_decode": True,     # 启用远程解码
            "do_remote_prefill": False,   # 这是预填充实例
            "remote_engine_id": None,     # 将由 vLLM 填充
            "remote_block_ids": None,     # 将由 vLLM 填充
            "remote_host": None,          # 将由 vLLM 填充
            "remote_port": None,          # 将由 vLLM 填充
        }
    },
    extra_headers={"X-Request-Id": request_id},
)

print("-" * 50)
print("✓ 预填充完成")
print(f"预填充响应: {prefill_response.choices[0].text}")

# 3: 解码阶段
# 将预填充的 KV 缓存参数传递给解码实例
decode_response = decode_client.completions.create(
    model=model,
    prompt="This prompt is ignored during decode",  # 解码期间不需要原始提示词
    max_tokens=150,  # 最多生成 150 个 token
    extra_body={
        "kv_transfer_params": prefill_response.kv_transfer_params  # 传递 KV 缓存信息
    },
    extra_headers={"X-Request-Id": request_id},  # 相同的请求 ID
)

print("-" * 50)
print("✓ 解码完成")
print(f"最终响应: {decode_response.choices[0].text}")

except Exception as e:
    print(f"❌ 解耦服务过程中出错: {e}")
    print("请确认预填充和解码实例都在运行且可访问")
```

### 性能测试

- 要模拟解耦服务的解码部署，请向 `vllm serve` 调用传递 `--kv-transfer-config '{"kv_connector":"DecodeBenchConnector","kv_role":"kv_both"}'`。该连接器用随机值填充 KV 缓存，以便在隔离环境中对解码进行性能分析。

- **CUDAGraph 捕获**: 使用 `--compilation_config '{"cudagraph_mode": "FULL_DECODE_ONLY"}'` 仅对解码启用 CUDA 图捕获并保存 KV 缓存。