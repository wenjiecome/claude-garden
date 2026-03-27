# Claude Garden

连接 Obsidian 知识库与代码库，支持双向引用和同步。

## 功能

- 在代码中使用 `[[笔记名]]` 引用知识库笔记
- 同步设计文档到知识库
- 统一搜索代码库和知识库
- 解析代码中的 wiki-link 引用

## 安装

```bash
# 添加 marketplace
/plugin marketplace add wenjiecome/claude-garden

# 安装 plugin
/plugin install claude-garden@claude-garden
```

## 使用

### 配置知识库连接

```bash
/claude-garden:setup
```

### 可用脚本

| 脚本 | 功能 |
|------|------|
| `scripts/setup.sh` | 交互式配置知识库软链接 |
| `scripts/kb_search.sh` | 统一搜索知识库和代码库 |
| `scripts/sync_to_kb.sh` | 同步文档到知识库 |
| `scripts/parse_refs.py` | 解析代码中的 [[]] 引用 |

### 示例

```bash
# 搜索关键词
./scripts/kb_search.sh "认证流程"

# 同步文档到知识库
./scripts/sync_to_kb.sh docs/design.md

# 解析代码中的引用
python3 scripts/parse_refs.py ./src
```

## 目录结构

```
claude-garden/
├── .claude-plugin/
│   ├── plugin.json       # 插件配置
│   └── marketplace.json  # 市场配置
├── commands/
│   └── setup.md          # /claude-garden:setup 命令
├── scripts/
│   ├── setup.sh          # 配置脚本
│   ├── kb_search.sh      # 搜索脚本
│   ├── sync_to_kb.sh     # 同步脚本
│   └── parse_refs.py     # 引用解析
├── LICENSE
└── README.md
```

## License

MIT
