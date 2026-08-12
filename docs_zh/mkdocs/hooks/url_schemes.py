<!-- FILE: mkdocs/hooks/url_schemes.py -->

```python
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Copyright contributors to the vLLM project
"""
MkDocs 钩子 + markdown 扩展，用于正确渲染以下链接，
包括通过 pymdownx.snippets 包含的内容内部：

- 指向 `docs/` 目录外的相对文件链接，例如：
    - [文本](../some_file.py)
- GitHub issue、PR 和项目链接，例如：
    - #123 或 [#123](.../issues/123)
    - pull/123 -> [Pull Request #123](.../pull/123)
    - 通过在链接标题中包含 `owner/repo` 也适用于外部仓库

目标是在项目文档中简化对常见 GitHub 资源的交叉引用。

链接替换作为 markdown 预处理器（优先级 25）运行，以便在
pymdownx.snippets（优先级 32）展开所有包含内容后执行。
on_page_markdown 钩子在每个页面转换前将当前页面上下文传递给预处理器。
"""

import posixpath
from pathlib import Path

import regex as re
from markdown import Extension
from markdown.preprocessors import Preprocessor
from mkdocs.config.defaults import MkDocsConfig
from mkdocs.structure.files import Files
from mkdocs.structure.pages import Page

ROOT_DIR = Path(__file__).parent.parent.parent.parent.resolve()
DOC_DIR = ROOT_DIR / "docs"

gh_icon = ":octicons-mark-github-16:"

# 正则表达式片段
TITLE = r"(?P<title>[^\[\]<>]+?)"
REPO = r"(?P<repo>.+?/.+?)"
TYPE = r"(?P<type>issues|pull|projects)"
NUMBER = r"(?P<number>\d+)"
VERSION = r"[^/\s]+"
PATH = r"(?P<path>[^\s]+?)"
FRAGMENT = r"(?P<fragment>#[^\s]+)?"
URL_GITHUB = f"https://github.com/{REPO}/{TYPE}/{NUMBER}{FRAGMENT}"
RELATIVE = rf"(?!(https?|ftp)://|#){PATH}{FRAGMENT}"
URL_DOCS = f"https://docs.vllm.ai/en/{VERSION}/{PATH}{FRAGMENT}"

# 当链接未提供标题时使用的常见标题。
TITLES = {"issues": "Issue ", "pull": "Pull Request ", "projects": "Project "}

# 匹配 GitHub issue、PR 和项目链接的正则表达式（可选标题）。
github_link = re.compile(rf"(\[{TITLE}\]\(|<){URL_GITHUB}(\)|>)")
# 匹配相对文件链接的正则表达式（可选标题）。
relative_link = re.compile(rf"\[{TITLE}\]\({RELATIVE}\)")
# 匹配绝对 docs.vllm.ai 链接的正则表达式（仅存在于 CLI 中）。
docs_link = re.compile(rf"\[{TITLE}\]\({URL_DOCS}\)")


class UrlSchemesPreprocessor(Preprocessor):
    """在 pymdownx.snippets 之后运行的预处理器，用于处理所有链接。"""

    def __init__(self, md, ext):
        super().__init__(md)
        self.ext = ext

    def run(self, lines):
        page = self.ext.page
        files = self.ext.files
        if page is None:
            return lines

        def replace_relative_link(match: re.Match) -> str:
            """
            如果相对文件链接指向 docs 目录外，则替换为 URL。
            """
            title = match.group("title")
            path = match.group("path")
            path = ((DOC_DIR / page.file.src_uri).parent / path).resolve()
            fragment = match.group("fragment") or ""

            # 检查路径是否存在且位于 docs 目录外
            if not path.exists() or path.is_relative_to(DOC_DIR):
                return match.group(0)

            # 文件和目录在 GitHub 上有不同的 URL 方案
            slug = "tree/main" if path.is_dir() else "blob/main"

            path = path.relative_to(ROOT_DIR)
            url = f"https://github.com/vllm-project/vllm/{slug}/{path}{fragment}"
            return f"[{gh_icon} {title}]({url})"

        def replace_github_link(match: re.Match) -> str:
            """
            将 GitHub issue、PR 和项目链接替换为增强的 Markdown 链接。
            """
            repo = match.group("repo")
            type = match.group("type")
            number = match.group("number")
            # 标题和片段可能为 None
            title = match.group("title") or ""
            fragment = match.group("fragment") or ""

            # 为原始链接使用默认标题
            if not title:
                title = TITLES[type]
                if "vllm-project" not in repo:
                    title += repo
                title += f"#{number}"

            url = f"https://github.com/{repo}/{type}/{number}{fragment}"
            return f"[{gh_icon} {title}]({url})"

        def replace_docs_link(match: re.Match) -> str:
            """将绝对 docs.vllm.ai 链接重写为文档相对链接。"""
            title = match.group("title")
            path = match.group("path").rstrip("/")
            fragment = match.group("fragment") or ""

            # vllm.config.<Class> API 参考 -> mkdocstrings 交叉引用
            if path == "api/vllm/config" and re.fullmatch(
                r"#vllm\.config\.\w+", fragment
            ):
                ident = fragment[1:]
                return f"[`{ident}`][{ident}]"

            # 其他文档页面 -> 相对于当前页面的链接，但仅当
            # 目标是已知文档页面（真实或生成）时；未知/外部 URL 保持不变。
            # 即使相同的 docstring 也在其 API 参考页面上渲染时这也是正确的。
            src = f"{path.removesuffix('.html')}.md"
            if files.get_file_from_path(src) is None:
                return match.group(0)
            rel = posixpath.relpath(src, posixpath.dirname(page.file.src_uri))
            # 自动包装的裸 URL 使用 URL 作为其标题；使其可读。
            if title.startswith("http"):
                title = path.removesuffix(".html")
            return f"[{title}]({rel}{fragment})"

        markdown = "\n".join(lines)
        markdown = github_link.sub(replace_github_link, markdown)
        markdown = relative_link.sub(replace_relative_link, markdown)
        markdown = docs_link.sub(replace_docs_link, markdown)
        return markdown.split("\n")


class UrlSchemesExtension(Extension):
    """注册 URL 方案预处理器的 Markdown 扩展。"""

    def __init__(self, **kwargs):
        self.page = None
        self.files = None
        super().__init__(**kwargs)

    def extendMarkdown(self, md):
        # 优先级 25 在 pymdownx.snippets（优先级 32）之后运行
        md.preprocessors.register(UrlSchemesPreprocessor(md, self), "url_schemes", 25)


# 在钩子和预处理器之间共享的单例扩展实例。
_ext = UrlSchemesExtension()


def on_config(config: MkDocsConfig) -> MkDocsConfig:
    """注册 URL 方案的 markdown 扩展。"""
    config["markdown_extensions"].append(_ext)
    return config


def on_page_markdown(
    markdown: str, *, page: Page, config: MkDocsConfig, files: Files
) -> str:
    """将当前页面上下文传递给预处理器。"""
    _ext.page = page
    _ext.files = files
    return markdown