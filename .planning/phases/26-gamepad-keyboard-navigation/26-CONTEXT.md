# Phase 26: Gamepad & Keyboard Navigation - Context

**Gathered:** 2026-07-24
**Status:** Ready for planning

<domain>
## Phase Boundary

在已有的 Settings Overlay Shell（Phase 23）+ Tab 导航（Phase 24）+ Tab 内容框架（Phase 25）基础上，实现 D-pad/手柄/键鼠三模态导航。核心是 FocusTraversalGroup 分区管理 + SpinControl 手柄友好组件 + A/B 键交互。

覆盖 6 项需求：NAV-01（FocusTraversalGroup 分区）~ NAV-06（B 键关闭）。

**Carrying forward from earlier phases:**
- Phase 23 D-10: 面板自管 Focus subtree，ESC/B 优先关面板不冒泡
- Phase 24 D-04/D-05/D-06: ← → 和 LB/RB 切换 tab，面板优先消费

</domain>

<decisions>
## Implementation Decisions

### SpinControl 视觉设计

- **D-01:** 视觉形态 — **滑动动画型**。值变化时有滑动动画，类似 Steam 设置风格。与 Kodi 的 SpinControl 概念一致，但视觉更现代。
- **D-02:** 箭头显示 — **始终可见**。左右箭头始终显示，用户一眼可知可操作方向。手柄模式下无需 hover 触发。
- **D-03:** 边界行为 — **停止 + 灰色箭头**。到达边界值时停止，箭头变灰。简单明确，用户知道已到尽头。不循环 wrap-around。
- **D-04:** 适用范围 — **枚举选项 + 小范围数值**。SpinControl 用于语言、主题、播放模式等枚举选项，以及音量 0-100 等小范围数值。Slider 用于连续范围（亮度、对比度等）。Dropdown 保留给长列表（如字幕轨道选择）。
- **D-05:** 布局位置 — **SettingRow 右侧内联**。与 SettingRow 左对齐标签，右侧显示 SpinControl。保持行高一致，紧凑布局。
- **D-06:** 动画效果 — **水平滑入滑出**。值变化时新值从左/右滑入，旧值滑出。类似 iOS picker 的感觉，动画感强。
- **D-07:** 动画时长 — **200ms**。与面板开/关动画（Phase 23 D-07）和 FadeTransition（Phase 24 D-02）节奏一致。
- **D-08:** 数据模型 — **选项列表 + index**。SpinControl 接收 `List<String>` 选项列表 + 当前 index，内部管理循环逻辑。简单直接。
- **D-09:** 值格式化 — **可选 formatValue 回调**。SpinControl 接收可选的 `formatValue` 回调，默认用 `toString()`。简单灵活。
- **D-10:** 键盘行为 — **焦点时直接响应 ← →**。SpinControl 获得焦点后，← → 方向键直接调整值，无需先聚焦。D-pad 操作最直接，符合 Kodi/Steam 范式。

### 焦点高亮样式

- **D-11:** 焦点边框 — **Tokens.borderHighlight 颜色，2px 边框**。与现有 GlassContainer 边框风格统一。圆角与 SettingRow 一致。— **Reversibility:** reversible — 边框样式可随时调整，不影响逻辑。
- **D-12:** hover 态 — **叠加 Tokens.bgHover 背景色**。与焦点态边框叠加，提供双重反馈：边框指示焦点，背景指示可交互。
- **D-13:** 焦点动画 — **立即显示无动画**。焦点边框立即出现/消失，无过渡动画。最直接，手柄操作时无延迟。
- **D-14:** 遍历行为 — **组内顺序移动，边界停止**。D-pad ↑↓ 在当前 FocusTraversalGroup 内按顺序移动焦点，到达边界时停止。不循环，不跨组跳转。
- **D-15:** 禁用控件 — **跳过，不可聚焦**。禁用（disabled）的 SettingRow 不可聚焦，D-pad 跳过它们。最符合直觉，手柄操作时不会卡在禁用项上。
- **D-16:** 控件统一 — **所有控件类型使用相同焦点边框**。Switch、Slider、SpinControl、Button 都使用相同的 2px borderHighlight 焦点边框。统一但可能不够精确。
- **D-17:** 侧边栏 tab — **与 SettingRow 相同焦点样式**。侧边栏 tab 获得焦点时使用与 SettingRow 相同的 2px borderHighlight 边框。
- **D-18:** 关闭按钮 — **可聚焦 + 统一边框**。面板标题栏的关闭按钮（X）可聚焦，使用与 SettingRow 相同的焦点边框。D-pad 可以导航到关闭按钮。

### A/B 键物理映射

- **D-19:** 键类型 — **PhysicalKeyboardKey**。使用物理键码，不依赖键盘布局。手柄 A/B 通常映射到 Enter/Escape 物理键。最可靠。
- **D-20:** 映射方案 — **A=Enter, B=Escape**。手柄 A 按钮映射到 Enter（确认），B 按钮映射到 Escape（关闭/返回）。最符合 Kodi/Steam 范式。
- **D-21:** A 键行为 — **统一确认**。A 键在所有控件上统一触发确认：Switch 切换、SpinControl 选择、Button 点击。简单一致。
- **D-22:** B 键行为 — **先退回侧边栏再关闭**。B 键在内容区时先退回侧边栏（焦点移到侧边栏），再按 B 关闭面板。两步关闭，防止误操作。与 NAV-06 描述一致。
- **D-23:** 长按行为 — **无长按行为**。长按 A/B 键无特殊行为，每次按下只触发一次。简单明确。

### Claude's Discretion

无 — 用户对全部 3 领域均作出明确选择，未出现 "you decide" 延迟。

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 计划/需求
- `.planning/PROJECT.md` — v4.0 milestone 定义、Kodi+Steam 混合导航范式、框架优先策略。
- `.planning/REQUIREMENTS.md` §NAV — NAV-01..06 逐项需求（FocusTraversalGroup / FocusableActionDetector / SpinControl / D-pad / A 键 / B 键）。
- `.planning/ROADMAP.md` §Phase 26 — Goal + 6 条 Success Criteria。
- `CLAUDE.md` — Design System（Tokens.* / GlassContainer）、Coding Conventions、Dart/Flutter Rules（strict 模式 / `!`/`late`/`as` 规避 / ValueNotifier）。

### 前置 Phase 决策（LIVE，须核对）
- `.planning/phases/23-overlay-shell-state-model/23-CONTEXT.md` — D-10（面板自管 Focus subtree，ESC/B 优先关面板不冒泡）。
- `.planning/phases/24-sidebar-navigation/24-CONTEXT.md` — D-04/D-05/D-06（← → 和 LB/RB 切换 tab，面板优先消费）。

### 代码资产（LIVE，须核对）
- `lib/ui/dialogs/settings/settings_overlay_shell.dart`（509 行）— **挂载点**：壳骨架就位，已有 FocusTraversalGroup + _handleKeyEvent。Phase 26 在此基础上扩展焦点管理和 A/B 键处理。
- `lib/ui/dialogs/settings/settings_panel_state.dart`（36 行）— 状态模型，可能需扩展焦点相关状态。
- `lib/ui/dialogs/settings/settings_panel_controller.dart`（102 行）— 控制器，可能需扩展焦点管理逻辑。
- `lib/ui/dialogs/settings/_settings_nav_item.dart`（104 行）— 侧边栏 tab 项，需添加焦点样式（D-17）。
- `lib/ui/dialogs/settings/pending_settings.dart` — 延迟应用状态，SpinControl 可能需要集成。
- `lib/ui/player/keyboard_handler.dart` — 既有 20+ 键 Focus handler，面板打开时事件不冒泡至此（Phase 23 D-10）。

### codebase maps
- `.planning/codebase/CONVENTIONS.md` — Tokens / ValueNotifier / glass-morphism 约定。
- `.planning/codebase/STRUCTURE.md` — `lib/ui/dialogs/settings/` 子目录结构。

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `settings_overlay_shell.dart`（509 行）— 已有 FocusTraversalGroup + _handleKeyEvent，Phase 26 可直接扩展。
- `glass_container.dart`（383 行）— 毛玻璃容器，焦点边框可复用其 borderHighlight 颜色。
- `Tokens.borderHighlight` / `Tokens.bgHover` — 焦点和 hover 样式的设计令牌。

### Established Patterns
- FocusTraversalGroup + Focus + onKeyEvent — 面板自管键盘作用域模式（Phase 23 D-10）。
- ValueNotifier + ValueListenableBuilder — 状态管理模式，SpinControl 值变化可用同一模式。
- 200ms 动画时长 — 面板开/关、FadeTransition、SpinControl 统一节奏。

### Integration Points
- `settings_overlay_shell.dart` `_handleKeyEvent` — A/B 键处理需在此扩展。
- `settings_panel_state.dart` — 可能需添加焦点相关状态（如 focusedTabIndex）。
- `_settings_nav_item.dart` — 需添加焦点样式（D-17）。
- 各 tab 文件（`general_tab.dart` 等）— SettingRow 需添加 FocusableActionDetector（NAV-02）。

</code_context>

<specifics>
## Specific Ideas

- SpinControl 采用滑动动画型，类似 Steam 设置风格（用户明确选择）。
- 焦点边框立即显示无动画，手柄操作时无延迟（用户明确选择）。
- B 键两步关闭：先退回侧边栏再关闭面板，防止误操作（用户明确选择）。

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 26-Gamepad & Keyboard Navigation*
*Context gathered: 2026-07-24*
