# Phase 22: Kernel Models, Utils & Services Documentation - Context

**Gathered:** 2026-07-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Models 层（枚举/数据类）、Utils 层（工具文件）、Services 层及其他（启动/扫描/持久化）的代码注释补全。目标是让新开发者不运行代码就能理解每个文件的职责和关键逻辑。

范围：DOC-17 ~ DOC-32（见 REQUIREMENTS.md v1.5）
- Models: aspect_ratio_mode, validation_error, app_settings, player_error
- Utils: perf_monitor, debug_probe, memory_monitor, debug_exporter, screen_utils
- Services: global_hotkey_service, locale_service, thumbnail_service
- Startup: startup_coordinator, startup_state
- Scanner: folder_scanner
- Persistence: settings_validator

</domain>

<decisions>
## Implementation Decisions

### 注释语言与格式（继承 Phase 21）

- **D-01:** **混合语言** — `///` doc comment 用英文（国际化友好），行内 `//` why 注释用中文（现有代码库惯例）
- **D-02:** doc comment 格式：`/// Brief English description of purpose.` + 可选 `///` 续行说明参数/行为
- **D-03:** 行内注释格式：`// 中文解释为什么这样做`

### 魔法数字处理策略（继承 Phase 21）

- **D-04:** **保留原始值 + 行内 why 注释** — 不提取为命名常量
- **D-05:** 例外：如果同一个魔法数字在同一文件中出现 3+ 次，提取为文件级私有常量

### app_settings.dart 字段文档

- **D-06:** **每个字段都加 doc comment** — 25+ 字段全部添加 `///` 注释
- **D-07:** 注释内容：用途 + 取值范围/单位（如 `/// Volume level, 0-100.`）
- **D-08:** 默认值说明：在构造函数或字段注释中解释为什么选择该默认值

### 样板方法处理

- **D-09:** **跳过样板方法** — `copyWith()`、`operator ==`、`hashCode` 不加 doc comment
- **D-10:** 理由：语义由签名自解释，Phase 21 对类似情况也跳过

### 文件路径修正

- **D-11:** 使用实际文件路径（audit 发现 4 个路径与 REQUIREMENTS.md 不一致）
  - DOC-29: `lib/kernel/startup/startup_coordinator.dart`（非 services/）
  - DOC-30: `lib/kernel/startup/startup_state.dart`（非 services/）
  - DOC-32: `lib/kernel/persistence/settings_validator.dart`（非 services/）

### Claude's Discretion

- 行内注释的具体措辞由 Claude 决定，遵循 D-01/D-03 语言规范
- C 类文件（7 个）跳过不动，只处理 A 类（1 个）和 B 类（8 个）

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 需求定义
- `.planning/REQUIREMENTS.md` §v1.5 — DOC-17 ~ DOC-32 需求定义和验收标准
- `.planning/ROADMAP.md` §Phase 22 — 成功标准（4 条）

### 代码库约定
- `.planning/codebase/CONVENTIONS.md` §Comments — 注释规范
- `.planning/codebase/STRUCTURE.md` §lib/kernel/ — 目录结构和文件职责

### 前置阶段
- `.planning/phases/21-kernel-engine-bridge-documentation/21-CONTEXT.md` — Phase 21 决策（注释规范、语言规则、魔法数字处理）

### 审计结果
- `.planning/phases/22-kernel-models-utils-services-docs/22-DISCUSSION-LOG.md` — 审计分级和决策记录

### 目标文件（Models 层 4 个）
- `lib/kernel/models/aspect_ratio_mode.dart` — DOC-17 (B)
- `lib/kernel/models/validation_error.dart` — DOC-18 (B)
- `lib/kernel/models/app_settings.dart` — DOC-19 (A)
- `lib/kernel/models/player_error.dart` — DOC-20 (B)

### 目标文件（Utils 层 5 个）
- `lib/kernel/utils/perf_monitor.dart` — DOC-21 (B)
- `lib/kernel/utils/debug_probe.dart` — DOC-22 (C, skip)
- `lib/kernel/utils/memory_monitor.dart` — DOC-23 (C, skip)
- `lib/kernel/utils/debug_exporter.dart` — DOC-24 (C, skip)
- `lib/kernel/utils/screen_utils.dart` — DOC-25 (C, skip)

### 目标文件（Services + Others 7 个）
- `lib/kernel/services/global_hotkey_service.dart` — DOC-26 (C, skip)
- `lib/kernel/services/locale_service.dart` — DOC-27 (B)
- `lib/kernel/services/thumbnail_service.dart` — DOC-28 (C, skip)
- `lib/kernel/startup/startup_coordinator.dart` — DOC-29 (B)
- `lib/kernel/startup/startup_state.dart` — DOC-30 (B)
- `lib/kernel/scanner/folder_scanner.dart` — DOC-31 (B)
- `lib/kernel/persistence/settings_validator.dart` — DOC-32 (C, skip)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Phase 21 的注释规范（D-01~D-14）可直接继承
- `lib/kernel/utils/log.dart` — 模块化 logger，注释中可引用日志前缀

### Established Patterns
- `///` doc comment 用于公开 API（类、mixin、枚举、非平凡函数）
- `//` 行内注释用于解释 why（非 what）
- 中文注释在代码库中被接受和使用
- 样板方法（copyWith, ==, hashCode）不加 doc comment

### Integration Points
- Models 层通过 barrel 文件导出 — doc comment 会出现在 IDE 提示中
- app_settings.dart 是所有服务的配置来源 — 字段文档对整个代码库有价值
- startup_state.dart 是启动流程的核心状态 — 文档有助于理解启动顺序

</code_context>

<specifics>
## Specific Ideas

- app_settings.dart 是重点 — 25+ 字段需要逐一文档化，建议按功能分组（音频、窗口、视频、通用）
- perf_monitor.dart 的 16ms 慢帧阈值需要解释（1000/60 ≈ 16.67ms，即 60fps 下一帧的时间）
- locale_service.dart 的 `'zh'` 硬编码应引用 `SettingsValidator.defaultLocale` 常量
- folder_scanner.dart 的 VideoFile 字段（path/name/folderPath）需要解释与 PlaylistItem 的关系
- startup_state.dart 的 StartupPhase 枚举已有良好文档，但 StartupState 类的 5 个成员缺失

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 22-Kernel Models, Utils & Services Documentation*
*Context gathered: 2026-07-05*
