#!/bin/bash
# kb_search.sh - 统一搜索知识库和代码库

set -e

# 加载配置
CONFIG_FILE="$HOME/.claude/skills/knowledge-code-bridge/config.env"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# 配置
KB_DIR="${KNOWLEDGE_BASE:-$HOME/kb}"
CODE_DIR="${CODE_DIR:-$(pwd)}"
OBSIDIAN_CLI="${OBSIDIAN_CLI:-}"

# 颜色
BOLD='\033[1m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 用法
usage() {
    cat << EOF
用法: kb_search.sh <查询> [选项]

选项:
    --kb-only        只搜索知识库
    --code-only      只搜索代码库
    --use-obsidian   使用 Obsidian CLI 搜索（需要 Obsidian 运行中）
    -t, --type TYPE  限制文件类型 (md, py, ts, etc.)
    -c, --context N  显示匹配前后 N 行上下文 (默认: 2)
    -h, --help       显示帮助

示例:
    kb_search.sh "认证流程"
    kb_search.sh "API 设计" --kb-only
    kb_search.sh "class User" --code-only -t py
    kb_search.sh "关键词" --use-obsidian
EOF
    exit 0
}

# 解析参数
QUERY=""
KB_ONLY=false
CODE_ONLY=false
USE_OBSIDIAN=false
FILE_TYPE=""
CONTEXT=2

while [[ $# -gt 0 ]]; do
    case $1 in
        --kb-only)
            KB_ONLY=true
            shift
            ;;
        --code-only)
            CODE_ONLY=true
            shift
            ;;
        --use-obsidian)
            USE_OBSIDIAN=true
            shift
            ;;
        -t|--type)
            FILE_TYPE="$2"
            shift 2
            ;;
        -c|--context)
            CONTEXT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            QUERY="$1"
            shift
            ;;
    esac
done

if [[ -z "$QUERY" ]]; then
    usage
fi

# 使用 Obsidian CLI 搜索
# 文档: obsidian search query=<text> format=json|text
search_with_obsidian() {
    if [[ -z "$OBSIDIAN_CLI" ]] || [[ ! -x "$OBSIDIAN_CLI" ]]; then
        echo -e "${YELLOW}Obsidian CLI 未配置或不可用${NC}"
        echo "请运行 setup.sh 配置 Obsidian CLI"
        return 1
    fi

    echo -e "\n${BOLD}${BLUE}📚 知识库 (Obsidian CLI)${NC}\n"

    # 使用 Obsidian CLI 的 search 命令
    # 正确格式: obsidian search query="<text>" format=json
    # 注意: 需要 Obsidian 正在运行
    local result
    result=$("$OBSIDIAN_CLI" search query="$QUERY" format=json 2>/dev/null)

    if [[ -z "$result" ]]; then
        echo "  未找到匹配或 Obsidian 未运行"
        echo "  提示: Obsidian CLI 需要 Obsidian 应用程序正在运行"
        return 0
    fi

    # 解析 JSON 输出
    # Obsidian search format=json 返回匹配的文件路径列表
    echo "$result" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    # Obsidian search 返回文件路径列表
    if isinstance(data, list):
        for item in data[:20]:  # 限制显示前 20 个结果
            if isinstance(item, str):
                print(f'  {item}')
            elif isinstance(item, dict):
                path = item.get('path', item.get('filename', item.get('file', '')))
                print(f'  {path}')
        if len(data) > 20:
            print(f'  ... 还有 {len(data) - 20} 个结果')
    elif isinstance(data, dict) and 'results' in data:
        for item in data['results'][:20]:
            path = item.get('path', item.get('filename', item.get('file', '')))
            print(f'  {path}')
    else:
        print('  未找到匹配')
except json.JSONDecodeError:
    # 如果不是 JSON，直接显示原始输出（可能是 text 格式）
    for line in sys.stdin.read().split('\n')[:20]:
        if line.strip():
            print(f'  {line}')
except Exception as e:
    print(f'  解析结果时出错: {e}')
" || echo "  搜索失败"
}

# 使用 ripgrep 搜索
search_with_rg() {
    local search_dir="$1"

    # 检查是否有 ripgrep
    if ! command -v rg &> /dev/null; then
        # 回退到 grep
        search_with_grep "$search_dir"
        return
    fi

    local RG_ARGS=(
        --context "$CONTEXT"
        --color=always
        --heading
        --smart-case
        --hidden
        --glob='!.git'
        --glob='!node_modules'
        --glob='!.obsidian'
    )

    if [[ -n "$FILE_TYPE" ]]; then
        RG_ARGS+=(--type "$FILE_TYPE")
    fi

    rg "${RG_ARGS[@]}" "$QUERY" "$search_dir" 2>/dev/null || echo "  未找到匹配"
}

# 使用 grep 作为后备
search_with_grep() {
    local search_dir="$1"

    grep -rn --color=always --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.obsidian \
        "$QUERY" "$search_dir" 2>/dev/null | head -50 || echo "  未找到匹配"
}

# 搜索函数
search_kb() {
    if [[ ! -d "$KB_DIR" ]]; then
        echo -e "${YELLOW}警告: 知识库目录不存在: $KB_DIR${NC}"
        return 1
    fi

    echo -e "\n${BOLD}${BLUE}📚 知识库 ($KB_DIR)${NC}\n"

    if [[ "$USE_OBSIDIAN" == "true" ]] && [[ -n "$OBSIDIAN_CLI" ]]; then
        search_with_obsidian
    else
        search_with_rg "$KB_DIR"
    fi
}

search_code() {
    echo -e "\n${BOLD}${GREEN}💻 代码库 ($CODE_DIR)${NC}\n"
    search_with_rg "$CODE_DIR"
}

# 执行搜索
if [[ "$KB_ONLY" == "true" ]]; then
    search_kb
elif [[ "$CODE_ONLY" == "true" ]]; then
    search_code
else
    search_kb
    search_code
fi

echo
