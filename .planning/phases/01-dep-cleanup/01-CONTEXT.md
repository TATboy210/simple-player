# Phase 1: 依赖清理 - Context

**Gathered:** 2026-06-29
**Status:** Ready for planning

<domain>
## Phase Boundary

移除外部 `player_engine` path 依赖（`../widget_tree_flutter/player_engine`），将所有 import 统一为本地 `lib/kernel/engine/` 下的相对路径引用。验证 barrel 导出完整性，确认 engine 内部自引用正确解析。

**不包括：** FvpEngine 内部重构（Phase 2）、接口拆分（Phase 3）、新增测试（Phase 4）。

</domain>

<decisions>
## Implementation Decisions

### Import 路径策略
- **D-01:** 使用真·相对路径（如 `import '../../kernel/engine/player_engine.dart'`），不用 `package:` 语法
- **D-02:** pubspec.yaml 中 `player_engine` 条目完全删除（不改为本地 path）
- **D-03:** Engine 内部 7 个文件（fvp_engine, fvp_callback_handler, track_manager, media_opener, video_effect_controller, open_result, mock_engine）使用直接文件 import（如 `import 'player_engine_base.dart'`），不经过 barrel

### 迁移范围
- **D-04:** 全部 45 个源文件迁移（25 lib/ + 20 test/），不跳过 test/ 文件
- **D-05:** .planning/ 和 docs 中的 19 处引用同步更新，保持文档准确性
- **D-06:** REQUIREMENTS.md 中的 "37 个文件" 需更新为实际的 45 个

### Barrel 导出验证
- **D-07:** 对比外部包 `../widget_tree_flutter/player_engine/lib/player_engine.dart` 和本地 `lib/kernel/engine/player_engine.dart` 的导出列表，确认 8 个符号完全一致
- **D-08:** 如有遗漏符号，补齐到本地 barrel

### Engine 内部引用策略
- **D-09:** Engine 内部文件按需引用具体文件（如 `import 'player_engine_base.dart'`、`import 'media_state.dart'`），不走 barrel
- **D-10:** 每个 engine 内部文件需明确其实际依赖的具体文件，避免不必要的 import

### 迁移执行顺序
- **D-11:** 先迁移所有 import（保持 player_engine 依赖可用），再从 pubspec.yaml 删除依赖
- **D-12:** 最后运行验证，确认一切正常

### Claude's Discretion
- Import 重写的精确相对路径由 Claude 根据文件位置计算
- Engine 内部文件的具体依赖分析由 Claude 在实现时确定
- 验证步骤的执行顺序由 Claude 自行安排

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目定义
- `.planning/PROJECT.md` — 项目背景、架构现状、关键决策
- `.planning/REQUIREMENTS.md` — 22 个 v1 需求，Phase 1 对应 DEP-01 到 DEP-04
- `.planning/ROADMAP.md` — 4 阶段路线图，Phase 1 成功标准

### 代码结构
- `.planning/codebase/STRUCTURE.md` — 完整目录布局、文件统计、命名规范
- `.planning/codebase/STACK.md` — 技术栈、依赖列表、平台目标

### 关键源文件
- `lib/kernel/engine/player_engine.dart` — barrel 导出文件（8 个符号）
- `lib/kernel/engine/player_engine_base.dart` — PlayerEngine 抽象类定义
- `pubspec.yaml` — 当前包含 `player_engine: path: ../widget_tree_flutter/player_engine`
- `../widget_tree_flutter/player_engine/lib/player_engine.dart` — 外部 barrel（用于对比验证）

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/kernel/engine/player_engine.dart` — barrel 文件已存在，导出 8 个符号，可直接使用
- `lib/kernel/engine/player_engine_base.dart` — PlayerEngine 抽象类（12 ValueNotifiers, 30 methods），engine 内部文件直接引用此文件
- `lib/kernel/engine/media_state.dart` / `media_error_type.dart` / `video_effect_type.dart` — 枚举类型，engine 内部文件按需引用

### Established Patterns
- Engine 目录下 18 个文件，结构清晰：1 barrel + 1 abstract + 3 enums + 4 models + 9 helpers
- 外部包与本地代码 1:1 对应，迁移是纯机械操作
- Test 文件通过 `test/helpers/fake_engine.dart` (FakePlayerEngine) 进行测试

### Integration Points
- `lib/` 下 25 个文件通过 barrel 引用 engine 类型
- `test/` 下 20 个文件通过 barrel 引用 engine 类型
- Engine 内部 7 个文件互相引用（当前通过 barrel，迁移后改为直接文件 import）

</code_context>

<specifics>
## Specific Ideas

无特殊要求 — 使用标准的相对路径 import 方式，遵循 Dart/Flutter 社区惯例。

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 1-依赖清理*
*Context gathered: 2026-06-29*
