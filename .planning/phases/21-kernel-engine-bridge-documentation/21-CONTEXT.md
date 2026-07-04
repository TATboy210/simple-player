# Phase 21: Kernel Engine & Bridge Documentation - Context

**Gathered:** 2026-07-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Engine 层（12 文件）和 Bridge 层（4 文件）的代码注释补全。目标是让新开发者不运行代码就能理解每个文件的职责和关键逻辑。

范围：DOC-01 ~ DOC-16（见 REQUIREMENTS.md v1.5）
- Engine: d3d11_configurator, subtitle_configurator, volume_controller, track_manager, fvp_callback_handler, video_effect_controller, engine_prewarm, network_configurator, renderer_config, track_control, video_effects, open_result
- Bridge: display_config, window_persistence, display_enumerator, win32_display_enumerator

</domain>

<decisions>
## Implementation Decisions

### MDK/Win32 领域知识深度

- **D-01:** 注释深度为 **what + why** — 解释参数含义 AND 为什么这样配置
- **D-02:** D3D11 参数示例：`sync.cpu=true: 强制 CPU 同步，避免 D3D11 异步拷贝导致撕裂。性能换稳定性。`
- **D-03:** FFmpeg 滤镜语法示例：解释滤镜链的每个参数含义和选择原因
- **D-04:** Win32 API 示例：解释 API 调用的目的和平台特定行为

### 注释语言与格式

- **D-05:** **混合语言** — `///` doc comment 用英文（国际化友好），行内 `//` why 注释用中文（现有代码库惯例）
- **D-06:** doc comment 格式：`/// Brief English description of purpose.` + 可选 `///` 续行说明参数/行为
- **D-07:** 行内注释格式：`// 中文解释为什么这样做`
- **D-08:** 不使用 `@see` 引用外部文档 — MDK/mpv 文档链接不稳定，直接在注释中解释

### 魔法数字处理策略

- **D-09:** **保留原始值 + 行内 why 注释** — 不提取为命名常量
- **D-10:** 示例：`setProperty('sync.cpu', true); // 强制同步避免撕裂` 而非 `const _syncCpuEnabled = true;`
- **D-11:** 例外：如果同一个魔法数字在同一文件中出现 3+ 次，提取为文件级私有常量

### 现有注释质量审计

- **D-12:** **先审计再动手** — 先快速扫描 16 个文件的现有注释质量，标记哪些需要重写、哪些只需补充，然后分批处理
- **D-13:** 审计维度：类级 doc comment 是否存在、关键方法是否有文档、魔法数字是否有解释、非显而易见逻辑是否有 why 注释
- **D-14:** 分类处理：A 类（无注释/极差）→ 重写，B 类（有框架但不完整）→ 补充，C 类（已达标）→ 跳过

### Claude's Discretion

- 审计后的具体分批策略（哪些文件先处理）由 Claude 决定
- 行内注释的具体措辞由 Claude 决定，遵循 D-05/D-07 语言规范

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 需求定义
- `.planning/REQUIREMENTS.md` §v1.5 — DOC-01 ~ DOC-16 需求定义和验收标准
- `.planning/ROADMAP.md` §Phase 21 — 成功标准（4 条）

### 代码库约定
- `.planning/codebase/CONVENTIONS.md` §Comments — 注释规范（when to comment, 中文可接受, why not what）
- `.planning/codebase/STRUCTURE.md` §lib/kernel/engine/ 和 §lib/kernel/bridge/ — 目录结构和文件职责

### 前置阶段
- `.planning/phases/20-control-bar-subtraction/20-CONTEXT.md` — Phase 20 决策（代码清理模式）

### 目标文件（Engine 层 12 个）
- `lib/kernel/engine/d3d11_configurator.dart` — DOC-01
- `lib/kernel/engine/subtitle_configurator.dart` — DOC-02
- `lib/kernel/engine/volume_controller.dart` — DOC-03
- `lib/kernel/engine/track_manager.dart` — DOC-04
- `lib/kernel/engine/fvp_callback_handler.dart` — DOC-05
- `lib/kernel/engine/video_effect_controller.dart` — DOC-06
- `lib/kernel/engine/engine_prewarm.dart` — DOC-07
- `lib/kernel/engine/network_configurator.dart` — DOC-08
- `lib/kernel/engine/renderer_config.dart` — DOC-09
- `lib/kernel/engine/track_control.dart` — DOC-10
- `lib/kernel/engine/video_effects.dart` — DOC-11
- `lib/kernel/engine/open_result.dart` — DOC-12

### 目标文件（Bridge 层 4 个）
- `lib/kernel/bridge/display_config.dart` — DOC-13
- `lib/kernel/bridge/window_persistence.dart` — DOC-14
- `lib/kernel/bridge/display_enumerator.dart` — DOC-15
- `lib/kernel/bridge/win32/win32_display_enumerator.dart` — DOC-16

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/kernel/utils/log.dart` — 模块化 logger（logEngine, logBridge），注释中可引用日志前缀说明调试方法
- `.planning/codebase/CONVENTIONS.md` — 已有的注释规范和代码风格约定，作为注释质量的基准

### Established Patterns
- `///` doc comment 用于公开 API（类、mixin、枚举、非平凡函数）
- `//` 行内注释用于解释 why（非 what）
- `// D-XX:` 标签引用设计决策文档
- 中文注释在代码库中被接受和使用

### Integration Points
- Engine 层文件通过 `engine_state.dart` barrel 导出 — doc comment 会出现在 IDE 提示中
- Bridge 层文件通过 `window_bridge.dart` 接口定义 — 平台特定实现需要解释 Win32 行为
- 所有文件都使用 fvp/mdk API — 注释需要解释 MDK 特有的参数和行为

</code_context>

<specifics>
## Specific Ideas

- D3D11 的 `sync.cpu`、`video.decoders` 等参数是 fvp 继承自 mpv 的属性系统，需要用 mpv 的概念来解释
- FFmpeg 滤镜语法（如均衡器 `af` 参数）需要解释滤镜链的结构和每个参数的含义
- Win32 `EnumDisplayMonitors` 回调模式需要解释 COM 回调的生命周期管理
- 先审计再动手 — 避免在已有良好注释的文件上浪费精力

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 21-Kernel Engine & Bridge Documentation*
*Context gathered: 2026-07-04*
