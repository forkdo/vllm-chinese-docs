# vLLM 每日构建的 Wheels

vLLM 在 `https://wheels.vllm.ai` 维护一个每次提交对应的 wheel 仓库（通常称为 "nightly"），为自 `v0.5.3` 以来 `main` 分支上的每次提交提供预构建的 wheels。本文档解释了 nightly wheel 索引机制的工作原理。

## CI 上的构建和上传流程

### Wheel 构建

Wheels 在 PR 合并到主分支后，在 `Release` 流水线（`.buildkite/release-pipeline.yaml`）中构建，包含多个变体：

- **后端变体**：`cpu` 和 `cuXXX`（例如 `cu129`、`cu130`）。
- **架构变体**：`x86_64` 和 `aarch64`。

每个构建步骤：

1. 在 Docker 容器中构建 wheel。
2. 重命名 wheel 文件名，使用正确的 manylinux 标签（当前为 `manylinux_2_31`）以符合 PEP 600 规范。
3. 将 wheel 上传到 S3 存储桶 `vllm-wheels` 下的 `/{commit_hash}/` 目录。

### 索引生成

上传每个 wheel 后，`.buildkite/scripts/upload-wheels.sh` 脚本会：

1. **列出提交目录中所有现有的 wheels**（从 S3）
2. **生成索引**，使用 `.buildkite/scripts/generate-nightly-index.py`：
    - 解析 wheel 文件名以提取元数据（版本、变体、平台标签）。
    - 创建 HTML 索引文件（`index.html`）以兼容 PyPI。
    - 生成机器可读的 `metadata.json` 文件。
3. **上传索引**到多个位置（覆盖现有索引）：
    - `/{commit_hash}/` - 始终上传，用于特定提交的访问。
    - `/nightly/` - 仅针对 `main` 分支上的提交（非 PR）。
    - `/{version}/` - 仅针对发布版本的 wheels（其版本中不含 `dev`）。

!!! tip "处理并发构建"
    索引生成脚本通过始终在生成索引前列出提交目录中的所有 wheels，可以处理多个变体并发构建的情况，从而避免竞态条件。

## 目录结构

S3 存储桶结构遵循以下模式：

```text
s3://vllm-wheels/
├── {commit_hash}/              # 特定提交的 wheels 和索引
│   ├── vllm-*.whl              # 所有 wheel 文件
│   ├── index.html              # 项目列表（默认变体）
│   ├── vllm/
│   │   ├── index.html          # 包索引（默认变体）
│   │   └── metadata.json       # 元数据（默认变体）
│   ├── cu129/                  # 变体子目录
│   │   ├── index.html          # 项目列表（cu129 变体）
│   │   └── vllm/
│   │       ├── index.html      # 包索引（cu129 变体）
│   │       └── metadata.json   # 元数据（cu129 变体）
│   ├── cu130/                  # 变体子目录
│   ├── cpu/                    # 变体子目录
│   └── .../                    # 更多变体子目录
├── nightly/                    # 最新的主分支 wheels（最新提交的镜像）
└── {version}/                  # 发布版本索引（例如 0.11.2）
```

所有构建的 wheels 都存储在 `/{commit_hash}/` 中，而生成的不同索引会引用它们。这避免了 wheel 文件的重复。

例如，你可以指定以下 URL 来使用不同的索引：

- `https://wheels.vllm.ai/nightly/cu130` 用于使用 CUDA 13.0 构建的最新主分支 wheels。
- `https://wheels.vllm.ai/{commit_hash}` 用于特定提交构建的 wheels（默认变体）。
- `https://wheels.vllm.ai/0.12.0/cpu` 用于 0.12.0 发布版本的 CPU 变体 wheels。

请注意，并非每次提交都包含所有变体。可用的变体可能会随时间变化，例如从 cu130 变为 cu131。

### 变体组织

索引按变体组织：

- **默认变体**：没有变体后缀的 wheels（即使用当前的 `VLLM_MAIN_CUDA_VERSION` 构建）放在根目录。
- **变体子目录**：带有变体后缀的 wheels（例如 `+cu130`、`.cpu`）组织在子目录中。
- **默认变体的别名**：默认变体可以有一个别名（例如 `cu129`），以保持一致性并方便使用。

变体从 wheel 文件名中提取（如[文件名约定](https://packaging.python.org/en/latest/specifications/binary-distribution-format/#file-name-convention)所述）：

- 变体编码在本地版本标识符中（例如 `+cu129` 或 `dev<N>+g<hash>.cu130`）。
- 示例：
    - `vllm-0.11.2.dev278+gdbc3d9991-cp38-abi3-manylinux1_x86_64.whl` → 默认变体
    - `vllm-0.10.2rc2+cu129-cp38-abi3-manylinux2014_aarch64.whl` → `cu129` 变体
    - `vllm-0.11.1rc8.dev14+gaa384b3c0.cu130-cp38-abi3-manylinux1_x86_64.whl` → `cu130` 变体

## 索引生成详情

`generate-nightly-index.py` 脚本执行以下操作：

1. **解析 wheel 文件名**，使用正则表达式提取：
    - 包名
    - 版本（提取变体）
    - Python 标签、ABI 标签、平台标签
    - 构建标签（如果存在）
2. **按变体分组 wheels**，然后按包名分组：
    - 当前只构建 `vllm`，但该结构支持未来多个包。
3. **生成 HTML 索引**（符合[简单仓库 API](https://packaging.python.org/en/latest/specifications/simple-repository-api/#simple-repository-api)）：
    - 顶级 `index.html`：列出所有包和变体子目录
    - 包级 `index.html`：列出该包的所有 wheel 文件
    - 使用 wheel 文件的相对路径以确保可移植性
4. **生成 metadata.json**：
    - 包含所有 wheel 元数据的机器可读 JSON
    - 包括带有 wheel 文件 URL 编码相对路径的 `path` 字段
    - 在仅 Python 构建期间，`setup.py` 使用它来定位兼容的预编译 wheels

### AWS 服务的特殊处理

Wheels 和索引直接存储在 AWS S3 上，我们使用 AWS CloudFront 作为 S3 存储桶前面的 CDN。

由于 S3 不提供正确的目录列表，为了支持与 PyPI 兼容的简单仓库 API 行为，我们部署了一个 CloudFront 函数，该函数：

- 将任何不以 `/` 结尾且看起来不像文件（即最后一个路径段中不包含点 `.`）的 URL 重定向到带有尾部 `/` 的相同 URL
- 为任何以 `/` 结尾的 URL 附加 `/index.html`

例如，以下请求将按如下方式处理：

- `/nightly` -> `/nightly/index.html`
- `/nightly/cu130/` -> `/nightly/cu130/index.html`
- `/nightly/index.html` 或 `/nightly/vllm.whl` -> 保持不变

!!! note "AWS S3 文件名转义"

    根据其[命名规则](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-keys.html)，S3 会在上传时自动转义文件名。对 vllm 的直接影响是文件名中的 `+` 会被转换为 `%2B`。我们在索引生成脚本中特别注意在生成 HTML 索引和 JSON 元数据时正确转义文件名，以确保 URL 正确且可以直接使用。

## 在 `setup.py` 中使用预编译 wheels {#precompiled-wheels-usage}

当使用 `VLLM_USE_PRECOMPILED=1` 安装 vLLM 时，`setup.py` 脚本会：

1. **通过 `precompiled_wheel_utils.determine_wheel_url()` 确定 wheel 位置**：
    - 环境变量 `VLLM_PRECOMPILED_WHEEL_LOCATION`（用户指定的 URL/路径）始终优先，并跳过所有其他步骤。
    - 从 `VLLM_MAIN_CUDA_VERSION` 确定变体（可以使用环境变量 `VLLM_PRECOMPILED_WHEEL_VARIANT` 覆盖）；默认变体也将作为后备尝试。
    - 确定此分支的*基础提交*（稍后解释）（可以使用环境变量 `VLLM_PRECOMPILED_WHEEL_COMMIT` 覆盖）。
2. **从 `https://wheels.vllm.ai/{commit}/vllm/metadata.json`（默认变体）或 `https://wheels.vllm.ai/{commit}/{variant}/vllm/metadata.json`（特定变体）获取元数据**。
3. **根据以下条件选择兼容的 wheel**：
    - 包名（`vllm`）
    - 平台标签（架构匹配）
4. **从 wheel 下载并提取预编译的二进制文件**：
    - C++ 扩展模块（`.so` 文件）
    - Flash Attention Python 模块
    - Triton 内核 Python 文件
5. **修补 package_data** 以在安装中包含提取的文件

!!! note "什么是基准提交？"

    基准提交是通过查找当前分支与上游 `main` 分支之间的合并基础（merge-base）来确定的，以确保源代码与预编译二进制文件之间的兼容性。

_注意：在使用预编译的 wheel 文件之前，用户有责任确保没有本地代码（例如 C++ 或 CUDA）的更改。_

## 实现文件

夜间 wheel 机制涉及的关键文件：

- **`.buildkite/release-pipeline.yaml`**：构建 wheel 的 CI 流水线
- **`.buildkite/scripts/upload-wheels.sh`**：上传 wheel 并生成索引的脚本
- **`.buildkite/scripts/generate-nightly-index.py`**：生成与 PyPI 兼容的索引的 Python 脚本
- **`setup.py`**：包含用于获取和使用预编译 wheel 的 `precompiled_wheel_utils` 类