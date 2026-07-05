# Phase 23: UI Layer Documentation - Context

**Gathered:** 2026-07-05
**Status:** Ready for planning

<domain>
## Phase Boundary

UI 层 13 个文件的代码注释补全（DOC-33 ~ DOC-45）。目标是让新开发者不运行代码就能理解每个文件的职责和关键逻辑。

范围：
- Dialogs (5): equalizer_tab, audio_tab, video_tab, settings_tab_performance, media_info_dialog
- Player (4): drop_handler, player_actions, error_banner, time_range_display
- Shared (4): app_dialog, context_menu_row, merged_listenable, splash_screen

附带：settings_panel.dart（主入口，不在 DOC 范围内但用户要求解释导航模式）

</domain>

<decisions>
## Implementation Decisions

### 注释语言与格式（继承 Phase 21/22）

- **D-01:** **混合语言** — `///` doc comment 用英文（国际化友好），行内 `//` why 注释用中文（现有代码库惯例）
- **D-02:** doc comment 格式：`/// Brief English description of purpose.` + 可选 `///` 续行说明参数/行为
- **D-03:** 行内注释格式：`// 中文解释为什么这样做`

### 魔法数字处理策略（继承 Phase 21/22）

- **D-04:** **保留原始值 + 行内 why 注释** — 不提取为命名常量
- **D-05:** 例外：如果同一个魔法数字在同一文件中出现 3+ 次，提取为文件级私有常量

### 审计策略（继承 Phase 21/22）

- **D-06:** **先审计再动手** — 先快速扫描 13 个文件的现有注释质量，标记 A/B/C 类，然后分批处理
- **D-07:** 审计维度：类级 doc comment 是否存在、关键方法是否有文档、魔法数字是否有解释、非显而易见逻辑是否有 why 注释
- **D-08:** 分类处理：A 类（无注释/极差）→ 重写，B 类（有框架但不完整）→ 补充，C 类（已达标）→ 跳过

### FFmpeg 滤镜注释深度（equalizer_tab.dart）

- **D-09:** **详细模式** — 解释 FFmpeg 滤镜链结构 + 每个参数的音频含义，与 Phase 21 Engine 层保持一致
- **D-10:** 每个预设加效果说明（听感目标），如 'Bass Boost: 增强低频，适合流行/嘻哈音乐'
- **D-11:** 内联解释（不引用外部文档）— Phase 21 D-08: MDK/mpv 文档链接不稳定
- **D-12:** 只注释现有代码（不扩展到未使用参数）
- **D-13:** 解释滤镜链格式：`filter_name=param1=value1,param2=value2`
- **D-14:** 解释设置流程：通过 `EngineState.setProperty('af', ...)` 设置 FFmpeg 音频滤镜
- **D-15:** 解释 dB 单位和增益方向（正数增强、负数衰减）
- **D-16:** 解释多滤镜组合语法（逗号分隔多个滤镜按顺序应用）
- **D-17:** 解释空字符串 `''` 含义（禁用均衡器，原始音频直通）
- **D-18:** 添加修改指南（如何添加新预设、参数范围）
- **D-19:** 解释实时切换机制（滤镜链热切换，不需要重新打开文件）
- **D-20:** 添加增益范围警告（-20dB ~ +20dB，过高可能导致削波失真）
- **D-21:** 添加文件顶部模块级概述

### Settings Dialog 参数文档

- **D-22:** **完整解释** — Dialog 层也完整解释每个参数的技术细节，与 Engine 层保持一致（用户明确选择）
- **D-23:** 每个色彩校正参数都解释（亮度/对比度/饱和度/色调）— 参数含义、取值范围、默认值
- **D-24:** 解释 sync.cpu 含义（强制 CPU 同步，避免 D3D11 异步拷贝导致撕裂，性能换稳定性）
- **D-25:** 解释硬件解码优缺点（GPU 加速降低 CPU 使用率 vs 兼容性/驱动问题）和提供开关的原因
- **D-26:** 解释音轨选择逻辑（如何列出可用音轨、切换音轨的 API 调用）
- **D-27:** 解释每个媒体信息字段含义（编解码器、分辨率、比特率、帧率、像素格式、色彩空间等）
- **D-28:** 每个 settings tab 文件都添加模块级概述

### Player 交互逻辑文档

- **D-29:** 详细解释拖放机制（desktop_drop 平台通道监听 OS 级 Drop 事件、Flutter 原生 DragTarget 不支持）
- **D-30:** 解释 PlayerActions 设计意图（替代散落回调参数，简化构造函数）
- **D-31:** 解释 ErrorBanner 显示条件（MediaState.error + errorMessage != null）和交互（重试/打开文件按钮）
- **D-32:** 解释 MergedListenable 使用原因（避免分别监听 position/duration 导致多次 rebuild）
- **D-33:** 解释 PathValidator 过滤逻辑（路径长度、空字节、合法字符等安全考虑）
- **D-34:** 解释 desktop_drop 技术选型原因（Flutter 原生不支持 OS 级文件拖放）
- **D-35:** 每个 Player 文件都添加模块级概述

### Shared 组件模式文档

- **D-36:** 详细解释 MergedListenable 合并原理（监听两个 ValueNotifier，合并为 TimePair）和使用场景
- **D-37:** 解释 MergedListenable 通用设计意图（可复用于任何两个 ValueNotifier<int>，不限于时间显示）
- **D-38:** 解释 AppDialog 响应式设计（LayoutBuilder 根据屏幕宽度调整尺寸）和视觉规范（bgElevated + radiusLarge）
- **D-39:** 解释 AppDialog LayoutBuilder 逻辑（宽屏用指定尺寸，窄屏自适应）
- **D-40:** 解释 ContextMenuRow 提取来源（从 folder_tab 和 thumbnail_tile 提取的共享组件）和使用场景
- **D-41:** 每个 Shared 文件都添加模块级概述

### 附带文件（不在 DOC 范围内）

- **D-42:** settings_panel.dart 添加注释，解释侧边栏导航模式、tab 切换逻辑、各 tab 功能概述

### 样板方法处理（继承 Phase 22）

- **D-43:** **跳过样板方法** — `copyWith()`、`operator ==`、`hashCode` 不加 doc comment

### Phase 20 精简后注释

- **D-44:** 在相关文件中添加注释，说明 Phase 20 精简后的设计意图（如 EdgeGlow 只保留 gradient 变体、断点从 3 级减到 2 级等）

### Claude's Discretion

- 行内注释的具体措辞由 Claude 决定，遵循 D-01/D-03 语言规范
- 审计后的具体分批策略由 Claude 决定

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 需求定义
- `.planning/REQUIREMENTS.md` §v1.5 — DOC-33 ~ DOC-45 需求定义和验收标准
- `.planning/ROADMAP.md` §Phase 23 — 成功标准（4 条）

### 代码库约定
- `.planning/codebase/CONVENTIONS.md` §Comments — 注释规范
- `.planning/codebase/STRUCTURE.md` §lib/ui/ — UI 层目录结构和文件职责

### 前置阶段
- `.planning/phases/21-kernel-engine-bridge-documentation/21-CONTEXT.md` — Phase 21 决策（注释规范、语言规则、魔法数字处理、FFmpeg 详细模式）
- `.planning/phases/22-kernel-models-utils-services-docs/22-CONTEXT.md` — Phase 22 决策（审计策略、样板方法跳过）

### 目标文件（Dialogs 层 5 个 + 1 个附带）
- `lib/ui/dialogs/settings/equalizer_tab.dart` — DOC-33 (FFmpeg 滤镜语法)
- `lib/ui/dialogs/settings/audio_tab.dart` — DOC-34 (音轨选择)
- `lib/ui/dialogs/settings/video_tab.dart` — DOC-35 (色彩校正/旋转/去隔行)
- `lib/ui/dialogs/settings/settings_tab_performance.dart` — DOC-36 (D3D11/硬件解码)
- `lib/ui/dialogs/media_info_dialog.dart` — DOC-37 (媒体信息字段)
- `lib/ui/dialogs/settings_panel.dart` — 附带（导航模式，不在 DOC 范围）

### 目标文件（Player 层 4 个）
- `lib/ui/player/drop_handler.dart` — DOC-38 (desktop_drop 拖放)
- `lib/ui/player/player_actions.dart` — DOC-39 (回调集合)
- `lib/ui/player/error_banner.dart` — DOC-40 (错误状态机)
- `lib/ui/player/time_range_display.dart` — DOC-41 (MergedListenable)

### 目标文件（Shared 层 4 个）
- `lib/ui/shared/app_dialog.dart` — DOC-42 (响应式对话框)
- `lib/ui/shared/context_menu_row.dart` — DOC-43 (右键菜单行)
- `lib/ui/shared/merged_listenable.dart` — DOC-44 (ValueNotifier 合并)
- `lib/ui/shared/splash_screen.dart` — DOC-45 (启动画面)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Phase 21 的注释规范（D-01~D-14）可直接继承
- Phase 22 的审计策略（A/B/C 分类）可直接继承
- `lib/kernel/utils/log.dart` — 模块化 logger，注释中可引用日志前缀

### Established Patterns
- `///` doc comment 用于公开 API（类、mixin、枚举、非平凡函数）
- `//` 行内注释用于解释 why（非 what）
- 中文注释在代码库中被接受和使用
- 样板方法（copyWith, ==, hashCode）不加 doc comment
- 先审计再动手 — 避免在已有良好注释的文件上浪费精力

### Integration Points
- equalizer_tab.dart 通过 EngineState.setProperty('af', ...) 设置 FFmpeg 滤镜 — 注释需要解释 MDK 属性系统
- video_tab.dart 通过 VideoProcessingService 控制色彩校正 — 注释需要解释服务接口
- drop_handler.dart 使用 desktop_drop 包 — 注释需要解释平台通道机制
- merged_listenable.dart 是通用工具 — 注释需要强调可复用性

</code_context>

<specifics>
## Specific Ideas

- FFmpeg 滤镜语法需要详细解释（与 Phase 21 Engine 层保持一致），包括滤镜链格式、dB 单位、多滤镜组合、增益范围警告
- Settings Dialog 参数需要完整解释（用户明确选择与 Engine 层一致），不简要引用
- desktop_drop 技术选型需要解释（为什么不用 Flutter 原生 DragTarget）
- MergedListenable 需要强调通用设计（可复用于任何两个 ValueNotifier<int>）
- Phase 20 精简后的设计意图需要在相关文件中说明

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 23-UI Layer Documentation*
*Context gathered: 2026-07-05*
