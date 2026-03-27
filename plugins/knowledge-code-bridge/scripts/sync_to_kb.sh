#!/bin/bash
# sync_to_kb.sh - 同步代码库文档到知识库

set -e

# 配置
KB_DIR="${KNOWLEDGE_BASE:-$HOME/kb}"
SYNC_DIR="${SYNC_TARGET:-$KB_DIR/从代码库同步}"
PROJECT_NAME="${PROJECT_NAME:-$(basename $(pwd))}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 用法
usage() {
    cat << EOF
用法: sync_to_kb.sh <源文件或目录> [选项]

选项:
    -d, --dry-run    预览将要同步的文件，不实际执行
    -f, --force      强制覆盖已存在的文件
    -h, --help       显示帮助信息

示例:
    sync_to_kb.sh docs/design/auth.md
    sync_to_kb.sh docs/design/ -f
EOF
    exit 0
}

# 检查知识库是否存在
check_kb() {
    if [[ ! -d "$KB_DIR" ]]; then
        log_error "知识库目录不存在: $KB_DIR"
        log_info "请确保 ~/kb 软链接正确指向 Obsidian vault"
        exit 1
    fi
}

# 生成前置元数据
generate_frontmatter() {
    local source_file="$1"
    local relative_path="${source_file#$(pwd)/}"

    cat << EOF
---
source: $(pwd)/$relative_path
synced_at: $(date -Iseconds)
project: $PROJECT_NAME
synced_by: knowledge-code-bridge
---

EOF
}

# 生成页脚
generate_footer() {
    cat << 'EOF'

---
> 此文件从代码库自动同步，请勿在此编辑。
> 修改请到源文件，然后重新同步。
EOF
}

# 同步单个文件
sync_file() {
    local source_file="$1"
    local force="$2"
    local dry_run="$3"

    # 获取相对路径
    local relative_path="${source_file#$(pwd)/}"
    local target_file="$SYNC_DIR/$PROJECT_NAME/$relative_path"

    # 检查源文件
    if [[ ! -f "$source_file" ]]; then
        log_error "源文件不存在: $source_file"
        return 1
    fi

    # 检查目标文件是否已存在
    if [[ -f "$target_file" ]] && [[ "$force" != "true" ]]; then
        log_warn "目标文件已存在: $target_file"
        log_info "使用 -f 选项强制覆盖"
        return 1
    fi

    if [[ "$dry_run" == "true" ]]; then
        log_info "[DRY-RUN] 将同步: $source_file -> $target_file"
        return 0
    fi

    # 创建目标目录
    mkdir -p "$(dirname "$target_file")"

    # 合并内容
    {
        generate_frontmatter "$source_file"
        cat "$source_file"
        generate_footer
    } > "$target_file"

    log_info "已同步: $source_file -> $target_file"
}

# 同步目录
sync_directory() {
    local source_dir="$1"
    local force="$2"
    local dry_run="$3"
    local count=0

    # 查找所有 markdown 文件
    while IFS= read -r -d '' file; do
        sync_file "$file" "$force" "$dry_run" && ((count++))
    done < <(find "$source_dir" -name "*.md" -type f -print0)

    if [[ "$dry_run" == "true" ]]; then
        log_info "[DRY-RUN] 将同步 $count 个文件"
    else
        log_info "已同步 $count 个文件到 $SYNC_DIR/$PROJECT_NAME/"
    fi
}

# 解析参数
DRY_RUN="false"
FORCE="false"
SOURCE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dry-run)
            DRY_RUN="true"
            shift
            ;;
        -f|--force)
            FORCE="true"
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            SOURCE="$1"
            shift
            ;;
    esac
done

# 执行
if [[ -z "$SOURCE" ]]; then
    usage
fi

check_kb

if [[ -d "$SOURCE" ]]; then
    sync_directory "$SOURCE" "$FORCE" "$DRY_RUN"
elif [[ -f "$SOURCE" ]]; then
    sync_file "$SOURCE" "$FORCE" "$DRY_RUN"
else
    log_error "源不存在: $SOURCE"
    exit 1
fi
