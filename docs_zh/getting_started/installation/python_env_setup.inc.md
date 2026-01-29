推荐使用 [uv](https://docs.astral.sh/uv/)，这是一个非常快速的 Python 环境管理器，用于创建和管理 Python 环境。请按照 [文档](https://docs.astral.sh/uv/#getting-started) 安装 `uv`。安装完 `uv` 后，您可以使用以下命令创建一个新的 Python 环境：

```bash
uv venv --python 3.12 --seed
source .venv/bin/activate
```