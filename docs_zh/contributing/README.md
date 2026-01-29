# 为 vLLM 贡献代码

感谢您有兴趣为 vLLM 贡献代码！我们的社区对所有人开放，欢迎各种形式的贡献，无论大小。您可以通过以下几种方式为项目做出贡献：

- 发现并报告任何问题或 bug。
- 请求或添加对新模型的支持。
- 建议或实现新功能。
- 改进文档或贡献操作指南。

我们也相信社区支持的力量；因此，回答问题、提供 PR 审查以及帮助他人同样是备受重视且有益的贡献。

最后，支持我们最有效的方式之一是提高人们对 vLLM 的认知。在您的博客文章中谈论它，并强调它如何推动您的出色项目。如果您正在使用 vLLM，请在社交媒体上表达您的支持，或者只需通过给我们的仓库点星来表达您的赞赏！

## 任务看板

不知道从哪里开始？请查看以下链接，了解可以处理的任务：

- [适合初学者的任务](https://github.com/vllm-project/vllm/issues?q=is%3Aissue%20state%3Aopen%20label%3A%22good%20first%20issue%22)
    - [精选入门任务](https://github.com/orgs/vllm-project/projects/6)
- [新模型请求](https://github.com/vllm-project/vllm/issues?q=is%3Aissue%20state%3Aopen%20label%3A%22new-model%22)
    - [支持多模态能力的模型](https://github.com/orgs/vllm-project/projects/10)

## 许可证

请参阅 [LICENSE](../../LICENSE)。

## 开发

为 vLLM 贡献代码的第一步是克隆 GitHub 仓库：

```bash
git clone https://github.com/vllm-project/vllm.git
cd vllm
```

然后，配置您的 Python 虚拟环境。

--8<-- "docs/getting_started/installation/python_env_setup.inc.md"

如果您只开发 vLLM 的 Python 代码，请使用以下命令安装 vLLM：

```bash
VLLM_USE_PRECOMPILED=1 uv pip install -e .
```

如果您要开发 vLLM 的 Python 和 CUDA/C++ 代码，请先安装 PyTorch：

```bash
uv pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu129
```

然后使用以下命令安装 vLLM：

```bash
uv pip install -e . --no-build-isolation
```

有关从源代码安装以及为其他硬件安装的更多详细信息，请查看适用于您硬件的[安装说明](../getting_started/installation/README.md)，并转到“从源代码构建 wheel”部分。

有关在迭代 C++/CUDA 内核时的优化工作流程，请参阅[增量编译工作流程](./incremental_build.md)以获取建议。

!!! tip
    vLLM 兼容 Python 3.10 至 3.13 版本。但是，vLLM 的默认 [Dockerfile](../../docker/Dockerfile) 使用的是 Python 3.12，并且 CI 中的测试（除了 `mypy`）也是在 Python 3.12 上运行的。

    因此，我们建议使用 Python 3.12 进行开发，以最大程度地减少您的本地环境与 CI 环境冲突的可能性。

### 代码检查

vLLM 使用 `pre-commit` 来对代码库进行 lint 和格式化。如果您不熟悉 `pre-commit`，请参阅 <https://pre-commit.com/#usage>。设置 `pre-commit` 非常简单：

```bash
uv pip install pre-commit
pre-commit install
```

现在，vLLM 的 `pre-commit` 钩子将在您每次提交时自动运行。

!!! tip "提示"
    您可以手动运行 `pre-commit` 钩子：

    ```bash
    pre-commit run     # 对暂存的文件运行
    pre-commit run -a  # 对所有文件运行（--all-files 的简写）
    ```

    ---

    某些 `pre-commit` 钩子仅在 CI 中运行。如果需要，您可以使用以下命令在本地运行它们：

    ```bash
    pre-commit run --hook-stage manual markdownlint
    pre-commit run --hook-stage manual mypy-3.10
    ```

### 文档

MkDocs 是一个快速、简单且非常出色的静态网站生成器，专为构建项目文档而设计。文档源文件使用 Markdown 编写，并通过单个 YAML 配置文件 [mkdocs.yaml](../../mkdocs.yaml) 进行配置。

开始使用：

```bash
uv pip install -r requirements/docs.txt
```

!!! tip
    确保您的 Python 版本与插件兼容
    （例如，`mkdocs-awesome-nav` 需要 Python 3.10+）

MkDocs 自带一个内置的开发服务器，可让您在编辑文档时预览效果。
从仓库根目录运行：

```bash
mkdocs serve                           # 包含 API 参考（约 10 分钟）
API_AUTONAV_EXCLUDE=vllm mkdocs serve  # 关闭 API 参考（约 15 秒）
```

当您在日志中看到 `Serving on http://127.0.0.1:8000/` 时，实时预览就准备好了！
在浏览器中打开 <http://127.0.0.1:8000/> 即可查看。

有关其他功能和高级配置，请参阅：

- [MkDocs 文档](https://www.mkdocs.org/)
- [Material for MkDocs 文档](https://squidfunk.github.io/mkdocs-material/)（我们使用的 MkDocs 主题）

### 测试

vLLM 使用 `pytest` 来测试代码库。

```bash
# 安装 CI 中使用的测试依赖项（仅限 CUDA）
uv pip install -r requirements/common.txt -r requirements/dev.txt --torch-backend=auto

# 安装一些常见的测试依赖项（与硬件无关）
uv pip install pytest pytest-asyncio

# 运行所有测试
pytest tests/

# 使用详细输出运行单个测试文件的测试
pytest -s -v tests/test_logger.py
```

!!! tip "如果缺少 Python.h，请安装 python3-dev"
    如果上述任何命令因 `Python.h: No such file or directory` 而失败，请使用 `sudo apt install python3-dev` 安装 `python3-dev`。

!!! warning "警告"
    目前，仓库并未完全通过 `mypy` 检查。

    ---

    目前，并非所有单元测试都能在 CPU 平台上通过。如果您无法访问 GPU 平台来本地运行单元测试，请暂时依赖持续集成系统来运行测试。

## 问题反馈

如果您遇到 bug 或有功能请求，请先[搜索现有问题](https://github.com/vllm-project/vllm/issues?q=is%3Aissue)，查看是否已有相关报告。如果没有，请[提交新问题](https://github.com/vllm-project/vllm/issues/new/choose)，并提供尽可能多的相关信息。

!!! important
    如果您发现安全漏洞，请按照[此处](../../SECURITY.md)的说明进行操作。

## 拉取请求与代码审查

感谢您为 vLLM 做出的贡献！在提交拉取请求之前，
请确保 PR 满足以下标准。这有助于 vLLM 维护代码质量并提高审查流程的效率。

### DCO 和 Signed-off-by

在向本项目贡献更改时，您必须同意 [DCO](../../DCO)。
提交必须包含 `Signed-off-by:` 标头，以证明您同意 DCO 的条款。

在 `git commit` 时使用 `-s` 选项将自动添加此标头。

!!! tip
    您可以通过 IDE 启用自动签名：

    - **PyCharm**：单击“提交”窗口中“提交并推送...”按钮右侧的“显示提交选项”图标。
      这将弹出一个 `git` 窗口，您可以在其中修改“作者”并启用“签名提交”。
    - **VSCode**：打开[设置编辑器](https://code.visualstudio.com/docs/configure/settings)
      并启用“Git: 始终签名”（`git.alwaysSignOff`）字段。

### PR 标题和分类

只有特定类型的 PR 才会被审查。PR 标题应带有适当的前缀，以指示更改的类型。请使用以下之一：

- `[Bugfix]` 用于 bug 修复。
- `[CI/Build]` 用于构建或持续集成改进。
- `[Doc]` 用于文档修复和改进。
- `[Model]` 用于添加新模型或改进现有模型。模型名称应出现在标题中。
- `[Frontend]` 用于 vLLM 前端的更改（例如，OpenAI API 服务器、`LLM` 类等）
- `[Kernel]` 用于影响 CUDA 内核或其他计算内核的更改。
- `[Core]` 用于核心 vLLM 逻辑的更改（例如，`LLMEngine`、`AsyncLLMEngine`、`Scheduler` 等）
- `[Hardware][Vendor]` 用于特定硬件的更改。供应商名称应出现在前缀中（例如，`[Hardware][AMD]`）。
- `[Misc]` 用于不符合上述类别的 PR。请谨慎使用此类别。

!!! note
    如果 PR 涉及多个类别，请包含所有相关前缀。

### 代码质量

PR 需要满足以下代码质量标准：

- 我们遵循 [Google Python 风格指南](https://google.github.io/styleguide/pyguide.html) 和 [Google C++ 风格指南](https://google.github.io/styleguide/cppguide.html)。
- 通过所有 linter 检查。
- 代码需要有良好的文档，以确保未来的贡献者能够轻松理解代码。
- 包含充分的测试，以确保项目保持正确和健壮。这包括单元测试和集成测试。
- 如果 PR 修改了 vLLM 的用户界面行为，请在 `docs/` 中添加文档。这有助于 vLLM 用户理解并利用新功能或更改。

### 添加或更改内核

在积极开发或修改内核时，强烈建议使用[增量编译工作流](./incremental_build.md)以加快构建时间。每个自定义内核都需要一个 schema 和一个或多个实现，以便在 PyTorch 中注册。

- 确保按照 PyTorch 指南注册自定义操作：[Custom C++ and CUDA Operators](https://pytorch.org/tutorials/advanced/cpp_custom_ops.html#cpp-custom-ops-tutorial) 和 [The Custom Operators Manual](https://docs.google.com/document/d/1_W62p8WJOQQUzPsJYa7s701JXt0qf2OfLub2sbkHOaU)。
- 返回 `Tensors` 的自定义操作需要元函数。元函数应该在 Python 中实现并注册，以便自动处理动态维度。有关元函数的描述，请参阅上述文档。
- 使用 [torch.library.opcheck()](https://pytorch.org/docs/stable/library.html#torch.library.opcheck) 测试任何已注册操作的函数注册和元函数。有关示例，请参阅 `tests/kernels`。
- 更改现有操作的 C++ 签名时，必须更新 schema 以反映更改。
- 如果需要新的自定义类型，请参阅以下文档：[Custom Class Support in PT2](https://docs.google.com/document/d/18fBMPuOJ0fY5ZQ6YyrHUppw9FA332CpNtgB6SOIgyuA)。

### 大型更改的注意事项

请尽量保持更改简洁。对于重大架构更改（>500 行代码，不包括内核/数据/配置/测试），我们期望有一个 GitHub issue (RFC) 讨论技术设计和理由。否则，我们将为其添加 `rfc-required` 标签，并且可能不会处理该 PR。

### 审查期望

vLLM 团队的目标是成为一个*透明的审查机器*。我们希望使审查过程透明高效，并确保没有贡献者感到困惑或沮丧。然而，vLLM 团队规模较小，因此我们需要优先处理一些 PR。以下是您可以从审查过程中期望的内容：

- PR 提交后，将分配给审查者。每个审查者将根据其专业知识和可用性选择 PR。
- PR 分配后，审查者将每 2-3 天提供状态更新。如果 PR 在 7 天内未得到审查，请随时联系审查者或 vLLM 团队。
- 审查后，如果需要更改，审查者将在 PR 上添加 `action-required` 标签。贡献者应解决评论并联系审查者重新审查 PR。
- 请在合理的时间内回复所有评论。如果评论不清楚或您不同意建议，请随时要求澄清或讨论建议。
- 请注意，由于计算资源有限，并非所有 CI 检查都会执行。当 PR 准备好合并或需要完整 CI 运行时，审查者将添加 `ready` 标签。

## 谢谢

最后，感谢您花时间阅读这些指南，并感谢您为 vLLM 做出贡献的兴趣。您的所有贡献都有助于使 vLLM 成为每个人都能使用的优秀工具和社区！