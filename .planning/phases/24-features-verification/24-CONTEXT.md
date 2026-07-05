# Phase 24: Features & Verification - Context

**Gathered:** 2026-07-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Features 层全部 15 个文件的代码注释补全 + 全量验证（60 个 DOC requirement 确认完成）。

范围：
- 5 个目标文件（DOC-46 ~ DOC-50）：deferred_player_feature, state_monitor, auto_advance_policy, player_error_bus, playback_contract
- 10 个非目标文件（新增 DOC-51 ~ DOC-60）：player_feature, player_view_model, player_services, video_processing_state, playback_controller, playback_navigator, breakpoint_saver, file_operations, subtitle_service, video_processing_service
- 全量审计：所有 60 个 DOC requirement 的注释质量检查
- 工具验证：flutter analyze 0 errors/warnings + flutter test 905+ tests passing

</domain>

<decisions>
## Implementation Decisions

### 验证范围

- **D-01:** **全量重新审计** — 对所有 60 个 DOC requirement 对应的文件进行完整质量检查，不是抽查
- **D-02:** **审计 + 生成修复计划** — 发现质量问题的文件生成修复计划但不修复（留给后续 phase）
- **D-03:** **全量质量检查** — 每个文件都检查注释深度（doc comment、why 注释、魔法数字解释等）
- **D-04:** **工具验证优先** — 先跑 flutter analyze + test 确保基线健康，再做文档和审计
- **D-05:** **沿用 Phase 21 标准** — 4 维度审计：类级 doc comment、关键方法文档、魔法数字解释、非显而易见逻辑 why 注释
- **D-06:** **Markdown 报告** — 审计结果生成 markdown 表格：文件名、DOC 编号、当前等级（A/B/C）、主要问题、修复建议

### 验证顺序

- **D-07:** **工具 → 文档 → 审计** — 先跑 flutter analyze + test，再写 15 个文件的文档，最后统一审计全部 60 个文件
- **D-08:** **修复后再继续** — flutter analyze 有 error/warning 时，全部修复后再继续文档工作
- **D-09:** **修复后再继续** — flutter test 有失败时，诊断并修复后再继续
- **D-10:** **统一审计** — 先写完 15 个文件的文档，然后统一审计全部 60 个文件（包括刚写的 15 个）

### 非目标文件处理

- **D-11:** **全部 15 个文件** — 范围从 5 个目标文件扩大到 features/ 层全部 15 个文件
- **D-12:** **统一标准** — 15 个文件用相同的注释标准和深度处理，不区分目标/非目标
- **D-13:** **添加新 DOC requirement** — 在 REQUIREMENTS.md 中添加 DOC-51 ~ DOC-60 覆盖 10 个非目标文件
- **D-14:** **架构层级顺序** — 按架构层级处理：先核心 MVVM（player_feature/player_view_model/player_services），再 models，再 services 子模块

### 模式文档深度

- **D-15:** **完整模式文档** — what + why + 架构位置 + 使用示例 + 替代方案对比
- **D-16:** **模块级概述** — 每个文件顶部添加模块级概述，解释该模式解决什么问题、为什么选择这个模式、在整体架构中的位置
- **D-17:** **组件交互关系** — 解释每个类/方法在模式中的角色，以及与其他组件的交互方式
- **D-18:** **替代方案对比** — 在注释中简要说明为什么选择这个模式而非替代方案

### 注释语言与格式（继承 Phase 21/22/23）

- **D-19:** **混合语言** — `///` doc comment 用英文（国际化友好），行内 `//` why 注释用中文（现有代码库惯例）
- **D-20:** doc comment 格式：`/// Brief English description of purpose.` + 可选 `///` 续行说明参数/行为
- **D-21:** 行内注释格式：`// 中文解释为什么这样做`

### 魔法数字处理策略（继承 Phase 21/22/23）

- **D-22:** **保留原始值 + 行内 why 注释** — 不提取为命名常量
- **D-23:** 例外：如果同一个魔法数字在同一文件中出现 3+ 次，提取为文件级私有常量

### Claude's Discretion

- 15 个文件的具体分批策略由 Claude 决定（遵循 D-14 架构层级顺序）
- 行内注释的具体措辞由 Claude 决定，遵循 D-19/D-21 语言规范
- 审计后的修复计划格式由 Claude 决定

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 需求定义
- `.planning/REQUIREMENTS.md` §v1.5 — DOC-46 ~ DOC-60 需求定义和验收标准（DOC-51~60 待添加）
- `.planning/ROADMAP.md` §Phase 24 — 成功标准（4 条）

### 代码库约定
- `.planning/codebase/CONVENTIONS.md` §Comments — 注释规范
- `.planning/codebase/STRUCTURE.md` §lib/features/ — 目录结构和文件职责

### 前置阶段（注释规范继承）
- `.planning/phases/21-kernel-engine-bridge-documentation/21-CONTEXT.md` — Phase 21 决策（注释规范、语言规则、魔法数字处理、审计策略）
- `.planning/phases/22-kernel-models-utils-services-docs/22-CONTEXT.md` — Phase 22 决策（继承 Phase 21，样板方法处理、文件路径修正）
- `.planning/phases/23-ui-layer-documentation/23-CONTEXT.md` — Phase 23 决策（继承 Phase 21/22，FFmpeg 滤镜注释深度、Settings Dialog 参数文档）

### 目标文件（Features 层 15 个）
- `lib/features/player/deferred_player_feature.dart` — DOC-46 (延迟加载特性模式)
- `lib/features/player/services/state_monitor.dart` — DOC-47 (状态监控服务)
- `lib/features/player/services/auto_advance_policy.dart` — DOC-48 (自动跳转策略)
- `lib/features/player/services/player_error_bus.dart` — DOC-49 (错误总线模式)
- `lib/features/player/services/playback_contract.dart` — DOC-50 (播放契约接口)
- `lib/features/player/player_feature.dart` — DOC-51 (待添加)
- `lib/features/player/player_view_model.dart` — DOC-52 (待添加)
- `lib/features/player/player_services.dart` — DOC-53 (待添加)
- `lib/features/player/models/video_processing_state.dart` — DOC-54 (待添加)
- `lib/features/player/services/playback_controller.dart` — DOC-55 (待添加)
- `lib/features/player/services/playback_navigator.dart` — DOC-56 (待添加)
- `lib/features/player/services/breakpoint_saver.dart` — DOC-57 (待添加)
- `lib/features/player/services/file_operations.dart` — DOC-58 (待添加)
- `lib/features/player/services/subtitle_service.dart` — DOC-59 (待添加)
- `lib/features/player/services/video_processing_service.dart` — DOC-60 (待添加)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Phase 21/22/23 注释规范** — 已建立的混合语言规范（英文 doc comment + 中文 why 注释）可直接复用
- **Phase 21 审计标准** — A/B/C 分类标准和 4 维度审计方法可直接复用
- **PlaybackController** — 已有完整的编排逻辑，文档化时需解释其与 PlaybackContract/PlaybackNavigator 的关系

### Established Patterns
- **MVVM 模式** — PlayerFeature (View) + PlayerViewModel (ViewModel) + PlayerServices (DI) 三层架构
- **ErrorBus 模式** — 集中式错误分发，替代 try-catch 传播
- **PlaybackContract** — 接口约束，解耦 PlaybackController 与具体实现
- **AutoAdvancePolicy** — 策略模式，控制自动跳转行为
- **StateMonitor** — 观察者模式，监控播放状态变化

### Integration Points
- **PlayerServices** — DI 容器，所有 services 通过它注入
- **PlaybackController** — 主编排器，连接 Engine 层和 UI 层
- **PlayerFeature** — UI 入口，组合 PlayerScreen 和 ControlsOverlay

</code_context>

<specifics>
## Specific Ideas

- 15 个文件按架构层级顺序处理：核心 MVVM → models → services
- 审计报告保存到 `.planning/phases/24-features-verification/` 目录
- 完整模式文档：what + why + 架构位置 + 使用示例 + 替代方案对比

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 24-Features & Verification*
*Context gathered: 2026-07-05*
