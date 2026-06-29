# Phase 1: 依赖清理 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-29
**Phase:** 1-依赖清理
**Areas discussed:** Import 路径策略, 迁移范围确认, Barrel 导出验证, 迁移验证策略

---

## Import 路径策略

### Q1: 45 个文件的 import 从 `package:player_engine/player_engine.dart` 改为什么？

| Option | Description | Selected |
|--------|-------------|----------|
| 真·相对路径（推荐） | 每个文件用相对路径 import '../../kernel/engine/player_engine.dart'。pubspec.yaml 中 player_engine 条目完全删除。这是 ROADMAP 成功标准要求的方式。 | ✓ |
| 本地 path 包（不符合标准） | pubspec.yaml 中改为 player_engine: path: lib/kernel/engine，保持 package:player_engine 语法不变。但 ROADMAP 成功标准明确说 'pubspec.yaml 中不存在 player_engine path 依赖'，此选项不满足标准。 | |

**User's choice:** 真·相对路径（推荐）
**Notes:** 完全符合 ROADMAP 成功标准

### Q2: engine 内部 7 个文件如何互相引用？

| Option | Description | Selected |
|--------|-------------|----------|
| 直接文件 import（推荐） | fvp_engine.dart 等 7 个 engine 内部文件改用 import 'player_engine_base.dart'（直接引用同目录下的具体文件）。更精确，不经过 barrel。 | ✓ |
| 走 barrel | engine 内部文件也用相对路径 import '../engine/player_engine.dart' 走 barrel。统一但绕路。 | |

**User's choice:** 直接文件 import（推荐）
**Notes:** 按需引用具体文件，避免不必要的依赖

---

## 迁移范围确认

### Q1: REQUIREMENTS 说 37 个文件，实际 grep 显示 45 个源文件。如何处理？

| Option | Description | Selected |
|--------|-------------|----------|
| 全部 45 个文件（推荐） | 45 个文件全部迁移（25 lib/ + 20 test/）。只改 lib/ 不改 test/ 会导致测试编译失败。 | ✓ |
| 仅 lib/ 25 个文件 | 只改 lib/ 的 25 个文件，test/ 文件单独处理。风险：测试无法编译。 | |

**User's choice:** 全部 45 个文件（推荐）
**Notes:** REQUIREMENTS.md 中的 37 需更新为 45

### Q2: .planning/ 和 docs 文件中也有 19 处引用。是否同步清理？

| Option | Description | Selected |
|--------|-------------|----------|
| 同步更新（推荐） | 更新 .planning/ 和 docs 中对 package:player_engine 的引用，保持文档准确性。 | ✓ |
| 不改 docs | docs 中的引用是历史记录，不改。后续 phase 自然会更新。 | |

**User's choice:** 同步更新（推荐）

---

## Barrel 导出验证

### Q1: 如何验证 barrel 导出完整性？

| Option | Description | Selected |
|--------|-------------|----------|
| 对比验证 + 补齐（推荐） | 对比外部包的 barrel 和本地 barrel，确认 8 个符号完全一致。如果有遗漏就补上。这是 ROADMAP 成功标准 #5。 | ✓ |
| 仅 analyze 验证 | 信任现状，只跑 flutter analyze 确认无错误。 | |

**User's choice:** 对比验证 + 补齐（推荐）

### Q2: engine 内部文件应该 import 哪些文件？

| Option | Description | Selected |
|--------|-------------|----------|
| 按需引用具体文件（推荐） | engine 内部文件只 import 它们实际需要的具体文件（player_engine_base.dart, media_state.dart 等），不经过 barrel。更精确、避免循环依赖风险。 | ✓ |
| 统一走 barrel | engine 内部文件统一 import barrel。简单但可能引入不必要的依赖。 | |

**User's choice:** 按需引用具体文件（推荐）

---

## 迁移验证策略

### Q1: 除了基本的 analyze + test，还需要哪些验证？

| Option | Description | Selected |
|--------|-------------|----------|
| analyze + test | 运行 flutter analyze + flutter test，确认零错误零警告。这是 ROADMAP 基本要求。 | ✓ |
| grep 残留检查 | grep -r 'package:player_engine' lib/ test/ 确认零结果。确认外部目录不再被引用。 | ✓ |
| 循环导入检查 | 检查 engine 内部文件是否有循环 import（A import B, B import A）。直接文件 import 比 barrel 更容易暴露循环依赖。 | ✓ |
| 外部目录断开确认 | 迁移完成后删除 ../widget_tree_flutter/player_engine 的引用，确认 pubspec.lock 中无残留。 | ✓ |

**User's choice:** 全部选中

---

## Claude's Discretion

无 — 所有决策均由用户明确选择

## Deferred Ideas

None — discussion stayed within phase scope
