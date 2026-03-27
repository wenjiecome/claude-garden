#!/usr/bin/env python3
"""
parse_refs.py - 解析代码中的 [[]] 知识库引用
"""

import argparse
import os
import re
import sys
from pathlib import Path
from collections import defaultdict
from typing import Dict, List, Tuple

# [[]] 引用正则
WIKI_LINK_PATTERN = re.compile(r'\[\[([^\]]+)\]\]')

# 配置
KB_DIR = Path(os.environ.get('KNOWLEDGE_BASE', '~/kb')).expanduser()


def parse_file(file_path: Path) -> List[Tuple[int, str]]:
    """解析文件中的所有 [[]] 引用，返回 (行号, 引用内容) 列表"""
    refs = []
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            for line_num, line in enumerate(f, 1):
                matches = WIKI_LINK_PATTERN.findall(line)
                for match in matches:
                    refs.append((line_num, match))
    except Exception as e:
        print(f"警告: 无法读取 {file_path}: {e}", file=sys.stderr)
    return refs


def scan_directory(directory: Path) -> Dict[Path, List[Tuple[int, str]]]:
    """扫描目录中所有文件，返回文件到引用列表的映射"""
    result = defaultdict(list)

    for file_path in directory.rglob('*'):
        # 只处理文本文件
        if file_path.is_file() and not is_binary(file_path):
            refs = parse_file(file_path)
            if refs:
                result[file_path] = refs

    return result


def is_binary(file_path: Path) -> bool:
    """检查文件是否为二进制文件"""
    try:
        with open(file_path, 'rb') as f:
            chunk = f.read(8192)
            return b'\x00' in chunk
    except:
        return True


def find_ref_sources(ref: str, directory: Path) -> List[Path]:
    """查找引用特定笔记的所有文件"""
    sources = []

    for file_path in directory.rglob('*'):
        if file_path.is_file() and not is_binary(file_path):
            content = file_path.read_text(encoding='utf-8', errors='ignore')
            if f'[[{ref}]]' in content:
                sources.append(file_path)

    return sources


def check_kb_exists(ref: str) -> bool:
    """检查知识库中是否存在对应的笔记"""
    # 尝试多种可能的路径
    possible_paths = [
        KB_DIR / f"{ref}.md",
        KB_DIR / f"{ref}.markdown",
        KB_DIR / ref / "index.md",
    ]

    # 处理 Obsidian 的子目录路径
    if '/' in ref:
        possible_paths.append(KB_DIR / f"{ref}.md")

    return any(p.exists() for p in possible_paths)


def format_output(results: Dict[Path, List[Tuple[int, str]]], show_status: bool = False):
    """格式化输出结果"""
    if not results:
        print("未找到任何 [[]] 引用")
        return

    total_refs = sum(len(refs) for refs in results.values())
    unique_refs = set()
    for refs in results.values():
        for _, ref in refs:
            unique_refs.add(ref)

    print(f"找到 {len(results)} 个文件，{total_refs} 个引用，{len(unique_refs)} 个唯一引用\n")

    for file_path, refs in sorted(results.items()):
        print(f"\n📄 {file_path}")
        for line_num, ref in refs:
            status = ""
            if show_status:
                exists = "✓" if check_kb_exists(ref) else "✗"
                status = f" [{exists}]"
            print(f"  L{line_num}: [[{ref}]]{status}")

    if show_status:
        print(f"\n[✓] 笔记存在  [✗] 笔记不存在")


def main():
    parser = argparse.ArgumentParser(description='解析代码中的 [[]] 知识库引用')
    parser.add_argument('path', nargs='?', default='.', help='要扫描的路径')
    parser.add_argument('-f', '--find', metavar='REF', help='查找引用特定笔记的文件')
    parser.add_argument('-s', '--status', action='store_true', help='检查笔记是否存在于知识库')
    parser.add_argument('-j', '--json', action='store_true', help='JSON 格式输出')

    args = parser.parse_args()
    directory = Path(args.path).resolve()

    if args.find:
        # 查找特定引用的来源
        sources = find_ref_sources(args.find, directory)
        if sources:
            print(f"引用 [[{args.find}]] 的文件:")
            for s in sources:
                print(f"  {s}")
        else:
            print(f"未找到引用 [[{args.find}]] 的文件")
        return

    # 扫描所有引用
    results = scan_directory(directory)

    if args.json:
        import json
        output = {}
        for file_path, refs in results.items():
            output[str(file_path)] = [{"line": ln, "ref": ref} for ln, ref in refs]
        print(json.dumps(output, indent=2, ensure_ascii=False))
    else:
        format_output(results, args.status)


if __name__ == '__main__':
    main()
