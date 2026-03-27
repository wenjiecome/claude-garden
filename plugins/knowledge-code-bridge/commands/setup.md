---
description: 交互式配置知识库连接（Obsidian 路径 + 知识库路径）
argument-hint: ""
allowed-tools: Read, Write, Bash, AskUserQuestion
---

# Knowledge-Code Bridge Setup

配置 Obsidian 知识库与代码库的连接。

## 收集信息

本命令需要收集两个信息：
1. **Obsidian 安装位置** - 用于调用 Obsidian CLI
2. **知识库路径** - Obsidian vault 的实际位置

---

## Tasks

### Turn 1 — 询问两个路径

使用 AskUserQuestion 一次性询问：

**问题 1: Obsidian 安装位置**
- 类型: text
- 提示: 请输入 Obsidian 可执行文件路径
- Windows 示例: `C:\Users\<用户名>\AppData\Local\Obsidian\Obsidian.exe`
- macOS 示例: `/Applications/Obsidian.app/Contents/MacOS/Obsidian`
- Linux 示例: `/usr/bin/obsidian`

**问题 2: 知识库路径**
- 类型: text
- 提示: 请输入 Obsidian vault 的完整路径
- Windows 示例: `E:\KB\projects\my-vault`
- WSL 示例: `/mnt/e/KB/projects/my-vault`

### Turn 2 — 验证路径

**验证 Obsidian 路径：**
```bash
# Windows 路径转换
WSL_PATH=$(echo "$OBSIDIAN_PATH" | sed 's|\\|/|g' | sed 's|^\([A-Za-z]\):|/mnt/\L\1|')

# 检查文件是否存在
if [ -f "$WSL_PATH" ]; then
  echo "Obsidian 路径有效"
else
  echo "Obsidian 路径无效"
fi
```

**验证知识库路径：**
```bash
# 转换路径
WSL_KB_PATH=$(echo "$KB_PATH" | sed 's|\\|/|g' | sed 's|^\([A-Za-z]\):|/mnt/\L\1|')

# 检查 .obsidian 目录
if [ -d "$WSL_KB_PATH/.obsidian" ]; then
  echo "知识库路径有效"
else
  echo "知识库路径无效：未找到 .obsidian 目录"
fi
```

### Turn 3 — 验证失败处理

如果任一路径验证失败：
1. 告知用户哪个路径无效
2. 显示错误原因
3. **返回 Turn 1** 重新询问

### Turn 4 — 创建配置

验证通过后，创建配置文件和软链接：

**1. 保存配置到 `~/.claude/skills/knowledge-code-bridge/config.env`：**
```bash
mkdir -p ~/.claude/skills/knowledge-code-bridge
cat > ~/.claude/skills/knowledge-code-bridge/config.env << EOF
OBSIDIAN_PATH=$OBSIDIAN_PATH
KNOWLEDGE_BASE=$WSL_KB_PATH
SYNC_TARGET=$WSL_KB_PATH/从代码库同步
EOF
```

**2. 创建 ~/kb 软链接：**
```bash
# 删除旧链接（如果存在）
rm -f ~/kb

# 创建新链接
ln -s "$WSL_KB_PATH" ~/kb
```

**3. 创建同步目录：**
```bash
mkdir -p "$WSL_KB_PATH/从代码库同步"
```

### Turn 5 — 确认成功

显示配置结果：
```
配置完成！

Obsidian 路径: $OBSIDIAN_PATH
知识库路径: $WSL_KB_PATH
软链接: ~/kb -> $WSL_KB_PATH

现在可以使用：
- kb-search "关键词" - 统一搜索
- sync-docs <path> - 同步文档到知识库
- [[笔记名]] - 在代码中引用知识库
```

---

## Examples

```
/knowledge-code-bridge:setup

# 系统询问:
Q1: Obsidian 安装位置
    用户输入: C:\Users\Admin\AppData\Local\Obsidian\Obsidian.exe

Q2: 知识库路径
    用户输入: E:\KB\projects\my-vault

# 系统验证:
✓ Obsidian 路径有效
✓ 知识库路径有效（找到 .obsidian 目录）

# 配置完成！
```

## Notes

- 路径验证失败会自动返回重新询问
- Windows 路径会自动转换为 WSL 格式
- 旧配置会被覆盖
