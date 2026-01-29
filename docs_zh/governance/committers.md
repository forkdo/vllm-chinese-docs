# 提交者

本文档列出了 vLLM 项目的当前提交者及其维护的核心领域。
提交者拥有对 vLLM 仓库的写入权限，负责审查和合并 PR。
您也可以参考 [CODEOWNERS](https://github.com/vllm-project/vllm/blob/main/.github/CODEOWNERS) 文件以了解具体的文件级所有权和审查者。本文档和 CODEOWNERS 文件都是动态文档，互为补充。

## 活跃提交者

我们尝试用几句话总结每位提交者在 vLLM 中的角色。通常，vLLM 提交者涵盖广泛的领域，并在维护过程中相互协作。
有关具体组件所有权的详细信息，请参阅后文的“领域负责人”部分。
按 GitHub 用户名按字母顺序排序：

- [@22quinn](https://github.com/22quinn)：RL API
- [@aarnphm](https://github.com/aarnphm)：结构化输出
- [@alexm-redhat](https://github.com/alexm-redhat)：性能
- [@ApostaC](https://github.com/ApostaC)：连接器、卸载
- [@benchislett](https://github.com/benchislett)：引擎核心和推测解码
- [@bigPYJ1151](https://github.com/bigPYJ1151)：Intel CPU/XPU 集成
- [@chaunceyjiang](https://github.com/chaunceyjiang)：工具使用和推理解析器
- [@DarkLight1337](https://github.com/DarkLight1337)：多模态、API 服务器
- [@esmeetu](https://github.com/esmeetu)：开发者营销、社区
- [@gshtras](https://github.com/gshtras)：AMD 集成
- [@heheda12345](https://github.com/heheda12345)：混合内存分配器
- [@hmellor](https://github.com/hmellor)：Hugging Face 集成、文档
- [@houseroad](https://github.com/houseroad)：引擎核心和 Llama 模型
- [@Isotr0py](https://github.com/Isotr0py)：多模态、新模型支持
- [@jeejeelee](https://github.com/jeejeelee)：LoRA、新模型支持
- [@jikunshang](https://github.com/jikunshang)：Intel CPU/XPU 集成
- [@khluu](https://github.com/khluu)：CI 基础设施
- [@KuntaiDu](https://github.com/KuntaiDu)：KV 连接器
- [@LucasWilkinson](https://github.com/LucasWilkinson)：内核和性能
- [@luccafong](https://github.com/luccafong)：Llama 模型、推测解码、分布式
- [@markmc](https://github.com/markmc)：可观测性
- [@mgoin](https://github.com/mgoin)：量化和性能
- [@NickLucche](https://github.com/NickLucche)：KV 连接器
- [@njhill](https://github.com/njhill)：分布式、API 服务器、引擎核心
- [@noooop](https://github.com/noooop)：池化模型
- [@patrickvonplaten](https://github.com/patrickvonplaten)：Mistral 模型、新模型支持
- [@pavanimajety](https://github.com/pavanimajety)：NVIDIA GPU 集成
- [@ProExpertProg](https://github.com/ProExpertProg)：编译、启动用户体验
- [@robertgshaw2-redhat](https://github.com/robertgshaw2-redhat)：核心、分布式、解耦
- [@ruisearch42](https://github.com/ruisearch42)：流水线并行、Ray 支持
- [@russellb](https://github.com/russellb)：结构化输出、引擎核心、安全
- [@sighingnow](https://github.com/sighingnow)：Qwen 模型、新模型支持
- [@simon-mo](https://github.com/simon-mo)：项目负责人、API 入口点、社区
- [@tdoublep](https://github.com/tdoublep)：状态空间模型
- [@tjtanaa](https://github.com/tjtanaa)：AMD GPU 集成
- [@tlrmchlsmth](https://github.com/tlrmchlsmth)：内核和性能、分布式、解耦
- [@WoosukKwon](https://github.com/WoosukKwon)：项目负责人、引擎核心
- [@yaochengji](https://github.com/yaochengji)：TPU 集成
- [@yeqcharlotte](https://github.com/yeqcharlotte)：基准测试、Llama 模型
- [@yewentao256](https://github.com/yewentao256)：内核和性能
- [@Yikun](https://github.com/Yikun)：可插拔硬件接口
- [@youkaichao](https://github.com/youkaichao)：项目负责人、分布式、编译、社区
- [@ywang96](https://github.com/ywang96)：多模态、基准测试
- [@zhuohan123](https://github.com/zhuohan123)：项目负责人、RL 集成、数值计算
- [@zou3519](https://github.com/zou3519)：编译

### 荣誉提交者

过去对 vLLM 做出重大贡献（感谢！）但目前已不再活跃的提交者：

- [@andoorve](https://github.com/andoorve)：流水线并行
- [@cadedaniel](https://github.com/cadedaniel)：推测解码
- [@comaniac](https://github.com/comaniac)：KV 缓存管理、流水线并行
- [@LiuXiaoxuanPKU](https://github.com/LiuXiaoxuanPKU)：推测解码
- [@pcmoritz](https://github.com/pcmoritz)：MoE
- [@rkooo567](https://github.com/rkooo567)：分块预填充
- [@sroy745](https://github.com/sroy745)：推测解码
- [@Yard1](https://github.com/Yard1)：内核和性能
- [@zhisbug](https://github.com/zhisbug)：Arctic 模型、分布式

## 领域负责人

本节按 vLLM 组件细分活跃提交者，并列出领域负责人。
如果您提交的 PR 涉及该领域，请随时联系领域负责人进行审查。

### 引擎核心

- 调度器：vLLM 引擎核心循环，负责将请求调度到下一批次
    - @WoosukKwon, @robertgshaw2-redhat, @njhill, @heheda12345
- KV 缓存管理器：调度器内的内存管理层，维护 KV 缓存逻辑块数据
    - @heheda12345, @WoosukKwon
- AsyncLLM：基于 zmq 的协议，托管引擎核心并使其对入口点可访问
    - @robertgshaw2-redhat, @njhill, @russellb
- ModelRunner、Executor、Worker：引擎包装模型实现的抽象
    - @WoosukKwon, @tlrmchlsmth, @heheda12345, @LucasWilkinson, @ProExpertProg
- KV 连接器：KV 缓存卸载和传输的连接器接口和实现
    - @robertgshaw2-redhat, @njhill, @KuntaiDu, @NickLucche, @ApostaC
- 分布式、并行、进程管理：进程启动器，管理每个工作进程并将其分配到正确的 DP/TP/PP/EP 等级
    - @youkaichao, @njhill, @WoosukKwon, @ruisearch42
- 集合操作：nccl 和其他通信库/内核的使用
    - @tlrmchlsmth, @youkaichao
- 多模态引擎和内存管理：涉及视觉、音频和视频输入的核心调度和内存管理。
    - @ywang96, @DarkLight1337

### 模型实现

- 模型接口：各种模型的 `nn.Module` 接口和实现
    - @zhuohan123, @mgoin, @simon-mo, @houseroad, @ywang96 (多模态), @jeejeelee (LoRA)
- Logits 处理器 / 采样器：提供的采样器类和可插拔的 logits 处理器
    - @njhill, @houseroad, @22quinn
- 自定义层：vLLM 中的实用层，例如旋转嵌入和 RMS 范数
    - @ProExpertProg
- 注意力：paged attention 的注意力接口
    - @WoosukKwon, @LucasWilkinson, @heheda12345
- FusedMoE：FusedMoE 内核、模块化内核框架、EPLB
    - @tlrmchlsmth
- 量化：各种量化配置、权重加载和内核。
    - @mgoin, @Isotr0py, @yewentao256
- 自定义量化 GEMM 内核 (cutlass_scaled_mm, marlin, machete)
    - @tlrmchlsmth, @LucasWilkinson
- 多模态输入处理：将图像/视频/音频数据加载并处理为特征张量的组件
    - @DarkLight1337, @ywang96, @Isotr0py
- torch compile：vLLM 中的 torch.compile 集成、自定义传递和转换
    - @ProExpertProg, @zou3519, @youkaichao
- 状态空间模型：vLLM 中的状态空间模型实现
    - @tdoublep, @tlrmchlsmth
- 推理和工具调用解析器
    - @chaunceyjiang, @aarnphm

### 入口点

- LLM 类：用于离线推理的 LLM 类
    - @DarkLight1337
- API 服务器：OpenAI 兼容的 API 服务器
    - @DarkLight1337, @njhill, @aarnphm, @simon-mo, @heheda12345 (Responses API)
- 批处理运行器：OpenAI 兼容的批处理运行器
    - @simon-mo

### 特性

- Spec Decode：涵盖与 n-gram、EAGLE 和 MTP 相关的模型定义、注意力机制、采样器和调度器
    - @WoosukKwon、@benchislett、@luccafong
- 结构化输出：结构化输出功能的实现
    - @russellb、@aarnphm
- 强化学习（RL）：与强化学习相关的功能，例如集体 RPC、休眠模式等
    - @youkaichao、@zhuohan123、@22quinn
- LoRA：@jeejeelee
- 可观测性：指标与日志记录
    - @markmc、@robertgshaw2-redhat、@simon-mo

### 代码库

- 配置：配置注册与解析
    - @hmellor
- 文档：@hmellor、@DarkLight1337、@simon-mo
- 基准测试：@ywang96、@simon-mo
- CI、构建与发布流程：@khluu、@njhill、@simon-mo
- 安全性：@russellb

### 外部内核集成

- FlashAttention：@LucasWilkinson
- FlashInfer：@LucasWilkinson、@mgoin、@WoosukKwon
- Blackwell 内核：@mgoin、@yewentao256
- DeepEP/DeepGEMM/pplx：@mgoin、@yewentao256

### 集成

- Hugging Face：@hmellor、@Isotr0py
- Ray：@ruisearch42
- NIXL：@robertgshaw2-redhat、@NickLucche

### 与模型供应商的合作

- gpt-oss：@heheda12345、@simon-mo、@zhuohan123
- Llama：@luccafong
- Qwen：@sighingnow
- Mistral：@patrickvonplaten

### 硬件

- 插件接口：@youkaichao、@Yikun
- NVIDIA GPU：@pavanimajety
- AMD GPU：@gshtras、@tjtanaa
- Intel CPU/GPU：@jikunshang、@bigPYJ1151
- Google TPU：@yaochengji

### 生态系统项目

- Ascend NPU：[@wangxiyuan](https://github.com/wangxiyuan) 及[更多详细信息](https://vllm-ascend.readthedocs.io/en/latest/community/contributors.html#maintainers)
- Intel Gaudi HPU：[@xuechendi](https://github.com/xuechendi) 和 [@kzawora-intel](https://github.com/kzawora-intel)
- Semantic Router：[@xunzhuo](https://github.com/xunzhuo)、[@rootfs](https://github.com/rootfs) 及[更多详细信息](https://vllm-semantic-router.com/community/team)