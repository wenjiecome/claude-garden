#!/bin/bash
# setup.sh - 交互式配置知识库软链接

set -e

# 颜色
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

KB_LINK="$HOME/kb"
CONFIG_FILE="$HOME/.claude/skills/knowledge-code-bridge/config.env"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_step() { echo -e "\n${BOLD}${BLUE}==>${NC} $1"; }

# 检查当前配置
check_current() {
    log_step "检查当前配置"

    if [[ -L "$KB_LINK" ]]; then
        local target=$(readlink -f "$KB_LINK")
        log_info "已有软链接: $KB_LINK -> $target"

        if [[ -d "$target" ]]; then
            log_info "目标目录存在 ✓"
            return 0
        else
            log_warn "目标目录不存在: $target"
            return 1
        fi
    elif [[ -d "$KB_LINK" ]]; then
        log_warn "$KB_LINK 是一个目录，不是软链接"
        return 1
    else
        log_info "未配置知识库软链接"
        return 1
    fi
}

# 推测可能的 Windows 知识库位置
suggest_locations() {
    local suggestions=()

    # 常见的 Obsidian vault 位置
    local possible_paths=(
        "/mnt/c/Users/*/Obsidian"
        "/mnt/c/Users/*/Documents/Obsidian"
        "/mnt/c/Users/*/Documents/Notes"
        "/mnt/c/Users/*/OneDrive/Obsidian"
        "/mnt/c/Users/*/OneDrive/Documents/Obsidian"
        "/mnt/d/Obsidian"
        "/mnt/d/Notes"
        "/mnt/e/KB/KB-*"
    )

    for pattern in "${possible_paths[@]}"; do
        for path in $pattern; do
            if [[ -d "$path" ]]; then
                suggestions+=("$path")
            fi
        done
    done

    echo "${suggestions[@]}"
}

# 检测 Obsidian CLI
detect_obsidian_cli() {
    local possible_paths=(
        "/mnt/c/Program Files/Obsidian/Obsidian.com"
        "/mnt/c/Users/*/AppData/Local/Obsidian/Obsidian.com"
    )

    for pattern in "${possible_paths[@]}"; do
        for path in $pattern; do
            if [[ -x "$path" ]]; then
                echo "$path"
                return 0
            fi
        done
    done

    return 1
}

# 交互式配置
interactive_setup() {
    log_step "配置知识库位置"

    echo "请输入 Obsidian vault 的实际路径"
    echo "（Windows 路径需要转换为 WSL 格式，如 C:\\Users\\xxx -> /mnt/c/Users/xxx）"
    echo

    # 显示建议
    local suggestions=$(suggest_locations)
    if [[ -n "$suggestions" ]]; then
        echo "检测到以下可能的知识库位置："
        local i=1
        for path in $suggestions; do
            echo "  $i) $path"
            ((i++))
        done
        echo "  0) 手动输入"
        echo

        read -p "请选择 [0-$((i-1))]: " choice

        if [[ "$choice" =~ ^[1-9]$ ]] && [[ "$choice" -lt "$i" ]]; then
            local selected=$(echo "$suggestions" | cut -d' ' -f"$choice")
            KB_PATH="$selected"
        else
            read -p "请输入知识库路径: " KB_PATH
        fi
    else
        read -p "请输入知识库路径: " KB_PATH
    fi

    # 验证路径
    if [[ ! -d "$KB_PATH" ]]; then
        log_warn "路径不存在: $KB_PATH"
        read -p "是否创建此目录？[y/N]: " create
        if [[ "$create" =~ ^[Yy]$ ]]; then
            mkdir -p "$KB_PATH"
            log_info "已创建目录: $KB_PATH"
        else
            echo "设置已取消"
            exit 1
        fi
    fi

    # 检查是否是 Obsidian vault
    if [[ ! -f "$KB_PATH/.obsidian/app.json" ]] && [[ ! -d "$KB_PATH/.obsidian" ]]; then
        log_warn "未检测到 .obsidian 目录，这可能不是 Obsidian vault"
        read -p "是否继续？[y/N]: " continue
        if [[ ! "$continue" =~ ^[Yy]$ ]]; then
            echo "设置已取消"
            exit 1
        fi
    fi

    # 创建软链接
    create_link "$KB_PATH"

    # 检测 Obsidian CLI
    local obsidian_cli=$(detect_obsidian_cli)
    if [[ -n "$obsidian_cli" ]]; then
        log_info "检测到 Obsidian CLI: $obsidian_cli"
        echo
        read -p "是否配置 Obsidian CLI 用于搜索？[Y/n]: " use_cli
        if [[ ! "$use_cli" =~ ^[Nn]$ ]]; then
            save_config "$KB_PATH" "$obsidian_cli"
        else
            save_config "$KB_PATH" ""
        fi
    else
        echo
        log_info "未检测到 Obsidian CLI"
        read -p "请输入 Obsidian CLI 路径（留空跳过）: " manual_cli
        if [[ -n "$manual_cli" ]]; then
            if [[ -x "$manual_cli" ]]; then
                save_config "$KB_PATH" "$manual_cli"
            else
                log_warn "路径不可执行: $manual_cli"
                save_config "$KB_PATH" ""
            fi
        else
            save_config "$KB_PATH" ""
        fi
    fi
}

# 创建软链接
create_link() {
    local target="$1"

    log_step "创建软链接"

    # 如果已存在，先备份或删除
    if [[ -L "$KB_LINK" ]] || [[ -e "$KB_LINK" ]]; then
        log_warn "$KB_LINK 已存在"
        read -p "是否覆盖？[y/N]: " overwrite
        if [[ "$overwrite" =~ ^[Yy]$ ]]; then
            rm -rf "$KB_LINK"
            log_info "已删除旧的链接/目录"
        else
            echo "设置已取消"
            exit 1
        fi
    fi

    # 创建软链接
    ln -s "$target" "$KB_LINK"
    log_info "已创建软链接: $KB_LINK -> $target"

    # 创建同步目标目录
    local sync_dir="$KB_LINK/从代码库同步"
    if [[ ! -d "$sync_dir" ]]; then
        mkdir -p "$sync_dir"
        log_info "已创建同步目录: $sync_dir"
    fi

    # 验证
    echo
    log_step "验证配置"
    log_info "知识库路径: $(readlink -f "$KB_LINK")"
    log_info "软链接: $KB_LINK -> $(readlink "$KB_LINK")"
    log_info "同步目录: $sync_dir"
    echo
    log_info "设置完成！"
    echo
    echo "现在你可以："
    echo "  - 在 Obsidian 中打开 $target"
    echo "  - 使用 sync_to_kb.sh 同步文档"
    echo "  - 使用 kb_search.sh 统一搜索"
    echo "  - 使用 parse_refs.py 解析引用"
}

# 保存配置
save_config() {
    local target="$1"
    local obsidian_cli="$2"

    mkdir -p "$(dirname "$CONFIG_FILE")"

    cat > "$CONFIG_FILE" << EOF
# Knowledge-Code Bridge 配置
# 生成时间: $(date -Iseconds)

# 知识库路径
KNOWLEDGE_BASE=$KB_LINK

# 实际目标（用于记录）
KB_ACTUAL_PATH=$target

# 同步目标
SYNC_TARGET=$KB_LINK/从代码库同步

# Obsidian CLI 路径
OBSIDIAN_CLI=$obsidian_cli
EOF

    log_info "配置已保存到: $CONFIG_FILE"
}

# 显示状态
show_status() {
    log_step "当前配置状态"

    if [[ -f "$CONFIG_FILE" ]]; then
        echo "配置文件: $CONFIG_FILE"
        cat "$CONFIG_FILE"
        echo
    fi

    if [[ -L "$KB_LINK" ]]; then
        echo "软链接: $KB_LINK -> $(readlink "$KB_LINK")"
        if [[ -d "$(readlink -f "$KB_LINK")" ]]; then
            echo "状态: ✓ 正常"
        else
            echo "状态: ✗ 目标目录不存在"
        fi
    else
        echo "软链接: 未配置"
    fi
}

# 用法
usage() {
    cat << EOF
用法: setup.sh [命令]

命令:
    setup       交互式配置知识库软链接（默认）
    status      显示当前配置状态
    check       检查配置是否有效
    unlink      删除软链接（不删除实际目录）
    -h, --help  显示帮助

示例:
    setup.sh            # 交互式配置
    setup.sh status     # 查看状态
    setup.sh check      # 检查配置
EOF
    exit 0
}

# 删除软链接
unlink_kb() {
    if [[ -L "$KB_LINK" ]]; then
        rm "$KB_LINK"
        log_info "已删除软链接: $KB_LINK"
        log_info "知识库目录未被删除"
    else
        log_warn "$KB_LINK 不是软链接或不存在"
    fi
}

# 主函数
main() {
    local command="${1:-setup}"

    case "$command" in
        setup|"")
            check_current || interactive_setup
            ;;
        status)
            show_status
            ;;
        check)
            check_current
            ;;
        unlink)
            unlink_kb
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "未知命令: $command"
            usage
            ;;
    esac
}

main "$@"
