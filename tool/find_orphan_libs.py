#!/usr/bin/env python3
"""Orphan-file scan: lib/**/*.dart files never imported anywhere in lib/ or test/."""
import glob
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

lib_files = [f.replace('\\', '/') for f in glob.glob('lib/**/*.dart', recursive=True)]
basenames = {os.path.basename(f): f for f in lib_files}

referenced = set()
import_re = re.compile(r"import\s+['\"]([^'\"]+)['\"]|export\s+['\"]([^'\"]+)['\"]")
scan_files = lib_files + glob.glob('test/**/*.dart', recursive=True) + \
    glob.glob('integration_test/**/*.dart', recursive=True)
for f in scan_files:
    s = open(f, encoding='utf-8').read()
    for m in import_re.finditer(s):
        uri = m.group(1) or m.group(2)
        if uri.startswith(('dart:', 'package:')):
            continue
        base = os.path.dirname(f)
        target = os.path.normpath(os.path.join(base, uri)).replace('\\', '/')
        referenced.add(target)

entry_points = {os.path.normpath(p) for p in ('lib/main.dart',)}
orphans = [
    f for f in lib_files
    if f not in referenced and f not in entry_points
]
print('孤儿文件候选（lib 内无任何 import/export 引用，main 除外）:')
for f in sorted(orphans):
    print(' ', f)
print('总数:', len(orphans))
