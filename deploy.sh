#!/usr/bin/env bash

#============================================================
# File: deploy.sh
# Description: 部署中文文档
# URL: 
# Author: Jetsung Chan <i@jetsung.com>
# Version: 0.2.0
# CreatedAt: 2025-12-16
# UpdatedAt: 2026-01-29
#============================================================


if [[ -n "${DEBUG:-}" ]]; then
    set -eux
else
    set -euo pipefail
fi

DEFAULT_BRANCH="${BRANCH:-main}"
HUGO_VERSION=${HUGO:-0.154.2}

DELETE_FILE="deleted_docs.txt"
ADD_FILE="new_docs.txt"
MODIFIED_FILE="modified_docs.txt"
TRANSLATE_LIST="translate_list.txt"

UPSTREAM_URL="${UPSTREAM_URL:-}"
UPSTREAM_NAME="upstream"

# 命令行参数
CUSTOM_BRANCH=""
CUSTOM_UPSTREAM=""

install_hugo() {
    echo "======================================"
    echo "📦 开始安装 Hugo"
    echo "======================================"
    echo "→ 目标版本: $HUGO_VERSION"
    echo "→ 正在下载并安装..."
    curl -L https://fx4.cn/hugo | bash -s -- -v "$HUGO_VERSION" -w
    echo "✓ Hugo 安装完成"
    hugo version
    echo "======================================"
}

setup_config() {
    echo "======================================"
    echo "⚙️  开始设置配置文件"
    echo "======================================"
    if [[ -f config.example.toml ]]; then
        echo "→ 从 config.example.toml 提取基础配置..."
        sed '/providers/,$d' ./config.example.toml | tee config.toml > /dev/null
        echo "✓ 基础配置提取完成"
    else
        echo "⚠️  config.example.toml 不存在，跳过基础配置"
    fi

    if [[ -f aitr.toml ]]; then
        echo "→ 从 aitr.toml 追加日志配置..."
        sed -n '/logging/,$p' aitr.toml | tee -a config.toml > /dev/null
        echo "✓ 日志配置追加完成"
    else
        echo "⚠️  aitr.toml 不存在，跳过日志配置"
    fi
    echo "✓ 配置文件设置完成"
    echo "======================================"
}

sync_source() {
    echo "======================================"
    echo "📚 开始同步源文档"
    echo "======================================"
    echo "→ 准备工作目录..."
    [[ -d docsite ]] || mkdir docsite

    pushd docsite > /dev/null
    if [[ ! -d .git ]]; then
        echo "→ 初始化 git 仓库..."
        git init
        echo "→ 添加 upstream remote: ${UPSTREAM_URL}"
        git remote add "${UPSTREAM_NAME}" "${UPSTREAM_URL}"
    else
        # 检查是否已经存在 upstream
        if ! git remote get-url "${UPSTREAM_NAME}" >/dev/null 2>&1; then
            echo "→ 添加 upstream remote..."
            git remote add "${UPSTREAM_NAME}" "${UPSTREAM_URL}"
        else
            current_url=$(git remote get-url "${UPSTREAM_NAME}")
            if [[ "${current_url}" != "${UPSTREAM_URL}" ]]; then
                echo "→ 更新 upstream URL"
                echo "  旧 URL: ${current_url}"
                echo "  新 URL: ${UPSTREAM_URL}"
                git remote set-url "${UPSTREAM_NAME}" "${UPSTREAM_URL}"
            fi
        fi
    fi
    echo "→ 正在拉取最新代码..."
    echo "  分支: $DEFAULT_BRANCH"
    echo "  Remote: ${UPSTREAM_NAME}"
    git reset --hard
    git fetch "${UPSTREAM_NAME}" "${DEFAULT_BRANCH}"
    git merge "${UPSTREAM_NAME}"/"${DEFAULT_BRANCH}"
    COMMIT_SHA=$(git rev-parse --short HEAD)
    echo "$COMMIT_SHA" > ../commit.txt
    echo "✓ 代码同步完成 (commit: $COMMIT_SHA)"
    popd > /dev/null

    echo "→ 清理旧文档目录..."
    rm -rf docs
    echo "→ 复制源文档..."
    if [[ -d docsite/content ]]; then
        cp -r docsite/content .
        mv content docs
        echo "✓ 已从 docsite/content 复制文档"
    elif [[ -d docsite/docs ]]; then
        cp -r docsite/docs .
        echo "✓ 已从 docsite/docs 复制文档"
    else
        echo "❌ docsite 目录下没有 content 或 docs 目录，无法同步文档。" >&2
        exit 1
    fi
    echo "✓ 源文档同步完成"
    echo "======================================"
}

# 增量更新
update_incremental() {
    echo "======================================"
    echo "🔄 开始增量更新流程"
    echo "======================================"
    if [[ -z "$UPSTREAM_URL" ]]; then
        echo "❌ UPSTREAM_URL 未设置，无法进行增量更新。" >&2
        exit 1
    fi

    echo "→ 步骤 1/6: 同步源文档"
    sync_source

    # 记录删除的文件
    echo "→ 步骤 2/6: 检测已删除的文件"
    echo "  正在扫描已删除的文档..."
    git ls-files --deleted docs/ | tee "$DELETE_FILE"
    ROOT_DIR=$(grep root_dir config.toml | cut -d'"' -f 2 | sed 's|^\./||')
    export ROOT_DIR
    OUTPUT_DIR=$(grep output_dir config.toml | cut -d'"' -f 2 | sed 's|^\./||')
    export OUTPUT_DIR
    echo "  根目录: $ROOT_DIR"
    echo "  输出目录: $OUTPUT_DIR"
    # sed -i "s|^$ROOT_DIR/|$OUTPUT_DIR/|g" "$DELETE_FILE"
    # 删除对应的输出文件
    echo "  正在清理对应的输出文件..."
    while read -r file; do
        new_file="${file/$ROOT_DIR/$OUTPUT_DIR}"
        echo "    删除: $new_file"
        rm -rf "$new_file" || true
    done < "$DELETE_FILE"
    echo "✓ 已清理删除的文件"

    # 更新 git 索引
    echo "→ 步骤 3/6: 更新 git 索引"
    git add .
    # 记录新增和修改的文件
    echo "  正在检测新增的文件..."
    git diff --cached --name-only --diff-filter=A docs/ | tee "$ADD_FILE"
    echo "  正在检测修改的文件..."
    git diff --cached --name-only --diff-filter=M docs/ | tee "$MODIFIED_FILE"

    echo "→ 步骤 4/6: 生成待翻译文件列表"
    cat "$ADD_FILE" "$MODIFIED_FILE" | tee "$TRANSLATE_LIST"

    # 移除以 .png .jpg .jpeg .gif .svg 结尾的文件
    echo "  过滤图片文件..."
    sed -i '/\.\(png\|jpg\|jpeg\|gif\|svg\)$/d' "$TRANSLATE_LIST"
    echo "✓ 已生成待翻译文件列表: $TRANSLATE_LIST"

    echo "→ 步骤 5/6: 设置配置文件"
    setup_config

    # # 翻译增量文件
    # if ! command -v aitr &> /dev/null; then
    #     echo "正在安装 aitr ..."
    #     curl -L https://fx4.cn/aitr | bash
    # fi

    # 调用 aitr 进行翻译
    echo "→ 步骤 6/6: 执行翻译"
    if command -v aitr &> /dev/null; then
        echo "  正在调用 aitr 翻译文件..."
        aitr --input "$TRANSLATE_LIST" --list --output translated
        echo "  正在复制翻译结果到输出目录..."
        cp -r "translated/${ROOT_DIR}/"* "${OUTPUT_DIR}"/
        echo "✓ 翻译完成"
    else
        echo "⚠️  aitr 未安装，跳过翻译步骤。"
    fi
    echo "======================================"
    echo "✓ 增量更新完成"
    echo "======================================"
}

# 部署 docs_zh 到 docsite
deploy_docs_zh() {
    echo "======================================"
    echo "📋 开始部署 docs_zh 到 docsite"
    echo "======================================"
    if [[ ! -d docsite ]]; then
        if [[ -z "$UPSTREAM_URL" ]]; then
            echo "❌ UPSTREAM_URL 未设置，无法克隆文档站点。" >&2
            exit 1
        fi
        echo "→ docsite 目录不存在，正在克隆..."
        git clone "$UPSTREAM_URL" docsite
        echo "✓ 克隆完成"
    fi

    if [[ -d "translated/docs" ]]; then
        echo "→ 检测到 translated/docs，正在覆盖 docs_zh..."
        cp -r translated/docs/* docs_zh/
        echo "✓ 已覆盖 docs_zh"
    fi

    if [[ ! -d docs_zh ]]; then
        echo "❌ docs_zh 目录不存在，无法部署。" >&2
        exit 1
    fi

    echo "→ 正在部署 docs_zh 到 docsite..."
    if [[ -d docsite/content ]]; then
        cp -r docs_zh/* ./docsite/content/
        echo "✓ 已部署到 docsite/content/"
    elif [[ -d docsite/docs ]]; then
        cp -r docs_zh/* ./docsite/docs/
        echo "✓ 已部署到 docsite/docs/"
    else
        echo "❌ docsite 目录下没有 content 或 docs 目录，无法部署。" >&2
        exit 1
    fi
    echo "======================================"
    echo "✓ 文档部署完成"
    echo "======================================"
}

# 更新项目信息
update_info() {
    local repo_url="${1:-}"
    local title="${2:-}"

    if [[ -z "$repo_url" ]]; then
        echo "❌ 缺少参数: repo_url" >&2
        echo "示例: $0 --init https://github.com/user/repo.git [\"我的文档\"]"
        exit 1
    fi

    echo "======================================"
    echo "📝 开始更新项目信息"
    echo "======================================"
    echo "→ 仓库地址: $repo_url"
    if [[ -n "$title" ]]; then
        echo "→ 文档标题: $title 中文文档"
    fi

    if [[ -f README.md ]]; then
        sed -i "s#https://github.com/xxx/docs.git#$repo_url#g" README.md
        if [[ -n "$title" ]]; then
            sed -i "s/^# 中文文档/# $title 中文文档/g" README.md
        fi
        echo "✓ README.md 已更新"
    else
        echo "⚠️  README.md 不存在，跳过"
    fi

    # 同步更新 docs.yml
    if [[ -f .github/workflows/docs.yml ]]; then
        sed -i "s#https://github.com/xxx/docs.git#$repo_url#g" .github/workflows/docs.yml
        echo "✓ .github/workflows/docs.yml 已更新"
    fi
    
    echo "======================================"
    echo "✓ 项目信息更新完成"
    echo "======================================"
}

# 调用翻译脚本
translate() {
    echo "======================================"
    echo "🌐 开始执行翻译"
    echo "======================================"
    if ! command -v aitr &> /dev/null; then
        echo "❌ aitr 未安装，请先安装 aitr。" >&2
        exit 1
    fi
    echo "→ 正在调用 aitr 翻译工具..."
    aitr
    echo "======================================"
    echo "✓ 翻译完成"
    echo "======================================"
}

usage() {
    cat << EOF
用法: $0 [选项]

选项:
  -i --init         初始化项目信息 (替换仓库地址和标题)
  -d --deploy       部署 docs_zh 到 docsite
  -c --config       设置配置文件
  -s --sync         同步源文档
  -u --update       增量更新（同步+翻译）
  -t --translate    执行翻译
  -b --branch       指定分支 (默认: main)
  -U --upstream     指定上游 URL
  -h --help         显示此帮助信息

示例:
  $0 --init https://github.com/user/repo.git "我的文档"
  $0 --translate
  $0 --update
  $0 --sync --branch develop
  $0 --update --upstream https://github.com/user/repo.git
EOF
}

main() {
    echo "======================================"
    echo "🚀 部署脚本启动"
    echo "======================================"

    if [[ $# -eq 0 ]]; then
        echo "❌ 未指定任何操作" >&2
        usage
        exit 1
    fi

    # 先解析所有参数
    local actions=()
    local INIT_REPO=""
    local INIT_TITLE=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--init)
                INIT_REPO="$2"
                # 检查 $3 是否存在且不是一个选项 (以 - 开头)
                if [[ -n "${3:-}" && "${3:-}" != -* ]]; then
                    INIT_TITLE="$3"
                    shift 3
                else
                    shift 2
                fi
                actions+=("init")
                ;;
            -b|--branch)
                CUSTOM_BRANCH="$2"
                shift 2
                ;;
            -U|--upstream)
                CUSTOM_UPSTREAM="$2"
                shift 2
                ;;
            -d|--deploy)
                actions+=("deploy")
                shift
                ;;
            -c|--config)
                actions+=("config")
                shift
                ;;
            -s|--sync)
                actions+=("sync")
                shift
                ;;
            -u|--update)
                actions+=("update")
                shift
                ;;
            -t|--translate)
                actions+=("translate")
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                echo "❌ 未知参数: $1" >&2
                usage
                exit 1
                ;;
        esac
    done

    # 应用自定义参数
    if [[ -n "$CUSTOM_BRANCH" ]]; then
        DEFAULT_BRANCH="$CUSTOM_BRANCH"
    fi
    if [[ -n "$CUSTOM_UPSTREAM" ]]; then
        UPSTREAM_URL="$CUSTOM_UPSTREAM"
    fi

    echo "当前分支: $DEFAULT_BRANCH"
    echo "Hugo 版本: $HUGO_VERSION"
    if [[ -n "$UPSTREAM_URL" ]]; then
        echo "Upstream URL: $UPSTREAM_URL"
    else
        echo "Upstream URL: (未设置)"
    fi
    echo "======================================"

    # 执行操作
    for action in "${actions[@]}"; do
        case $action in
            init)
                echo "→ 执行操作: 初始化项目信息"
                update_info "$INIT_REPO" "$INIT_TITLE"
                ;;
            deploy)
                echo "→ 执行操作: 部署 docs_zh"
                deploy_docs_zh
                ;;
            config)
                echo "→ 执行操作: 设置配置文件"
                setup_config
                ;;
            sync)
                echo "→ 执行操作: 同步源文档"
                sync_source
                ;;
            update)
                echo "→ 执行操作: 增量更新"
                update_incremental
                ;;
            translate)
                echo "→ 执行操作: 执行翻译"
                translate
                ;;
        esac
    done

    echo "======================================"
    echo "✓ 部署脚本执行完成"
    echo "======================================"
}

main "$@"