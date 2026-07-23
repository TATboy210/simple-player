# Phase 24: Sidebar Navigation - Context

**Gathered:** 2026-07-23
**Status:** Ready for planning

<domain>
## Phase Boundary

在已有的 `SettingsOverlayShell`(Phase 23) 内构建 tab 导航系统: 水平 tab bar + 7 tab 点击/键盘/手柄切换 + FadeTransition 内容过渡。**壳已就位**(291 lines),本 phase 只加导航 + 内容区骨架,不填 tab 内容(属 Phase 25)。

覆盖 4 项需求:SIDEBAR-01(tab 导航) ~ SIDEBAR-04(LB/RB 循环)。

### ⚠️ Layout Design Override

**Roadmap 原定义:** "固定 200px 侧边栏 — 左侧垂直导航"(SIDEBAR-01)
**用户决策:** 改为 **Top/Middle/Bottom 三段式水平布局**:
- **Top:** 标题栏(复用 Phase 23 shell 已有: "Settings" + 关闭按钮 + 拖拽)
- **Middle:** 水平 tab bar(7 tab 等宽单行, bgSurface 平坦深色背板, 40px 高)
- **Bottom:** 内容区(毛玻璃, 16dp padding, 无分隔线)

SIDEBAR-01 的 "200px 侧边栏" 语义变更为 "水平 tab bar", 其余 SIDEBAR-02~04 行为不变。

</domain>

<decisions>
## Implementation Decisions

### Tab 内容容器

- **D-01:** 容器选型 — **IndexedStack**。所有 7 个 tab 常驻存活,切换时仅改变可见性。pending 值/滚动位置不丢失。旧 `settings_panel.dart` 用 AnimatedSwitcher(每次销毁重建),IndexedStack 更适合设置面板场景。
- **D-02:** 动画驱动 — **TweenAnimationBuilder<double>** 包裹每个 tab, selectedTab 变化时自动触发 200ms opacity 动画。无需手动管理 AnimationController, dispose 自动处理。与 D-07(Phase 23, 200ms 统一时长)一致。
- **D-03:** 初始 tab — **面板打开时固定重置为 index 0 (General)**。不记忆上次 tab。简单可预测,避免跨会话状态不一致。

### LB/RB 输入范围

- **D-04:** 键盘方案 — **← → 方向键**切换 tab。面板打开时优先消费(不触发 seek ±5s)。沿用 Kodi/Steam 范式。与 Phase 23 D-10(面板自管 Focus subtree)一致。
- **D-05:** 手柄方案 — **GamepadButton.leftShoulder / rightShoulder** 循环切换 tab(← 减,→ 增,首尾循环)。Phase 24 同步实现,不推迟到 Phase 26。与键盘共享同一 `selectedTab` notifier。
- **D-06:** 优先级 — 面板打开时 ← → 和 LB/RB 由面板 Focus subtree 消费,不冒泡到 `keyboard_handler.dart`。面板关闭后恢复全局行为。承袭 D-10(modal overlay 优先消费惯例)。

### 视觉样式

- **D-07:** 布局结构 — **Top/Middle/Bottom 三段式**。标题栏(复用 shell 已有) → 水平 tab bar(40px 高, bgSurface) → 内容区(毛玻璃, 16dp padding)。取代 roadmap 的左侧 200px 垂直导航。
- **D-08:** Tab bar 背板 — **Tokens.bgSurface 平坦深色**,与内容区毛玻璃形成层次对比。不与内容区竞争视觉注意力。选中态:accent 色背景 + 白色文字;未选中态:透明背景 + textSecondary。
- **D-09:** Tab 排列 — **7 tab 等宽单行水平排列**。小窗口时每个 tab 自动缩小宽度,文字过长时省略号截断。固定宽度 + 均分策略。
- **D-10:** 内容区间距 — **四周 16dp padding (Tokens.spMd)**,tab bar 与内容区之间无分隔线,靠背景区分(毛玻璃 vs bgSurface)。

### `_settings_nav_item.dart` 适配

- **D-11:** 现有 `SettingsNavItem`(98 lines, 80px 宽垂直布局)需重构为水平等宽 tab 项。保留 hover/selected 交互逻辑,调整布局方向(Vertical → Horizontal)和尺寸(80px → Expanded equal-width)。

### Claude's Discretion

无 — 用户对全部 4 领域均作出明确选择。

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 计划/需求
- `.planning/PROJECT.md` — v4.0 milestone 定义、Kodi+Steam 混合导航范式、框架优先策略。
- `.planning/REQUIREMENTS.md` §SIDEBAR — SIDEBAR-01..04 逐项需求(注意 SIDEBAR-01 语义已变更为水平 tab bar)。
- `.planning/ROADMAP.md` §Phase 24 — Goal + 5 条 Success Criteria(需按 layout override 更新理解)。
- `CLAUDE.md` — Design System(Tokens.* / GlassContainer)、Coding Conventions、Dart/Flutter Rules。

### 重写对象与类比代码(LIVE,须核对)
- `lib/ui/dialogs/settings/_settings_nav_item.dart`(98 lines) — **重构对象**:垂直 80px → 水平等宽 tab 项(D-11)。
- `lib/ui/dialogs/settings/settings_overlay_shell.dart`(291 lines) — **挂载点**:壳骨架就位,需插入 tab bar + IndexedStack 内容区。
- `lib/ui/dialogs/settings/settings_panel_state.dart`(36 lines) — `selectedTab` notifier(D-03 初始值 0, D-04/D-05 切换目标)。
- `lib/ui/dialogs/settings/settings_panel_controller.dart`(68 lines) — 控制器,tab 切换逻辑可能扩展至此。
- `lib/ui/dialogs/settings_panel.dart`(945 lines) — **旧实现参考**:IndexedStack + AnimatedSwitcher 模式(line 600-701),tab 索引 0-6 映射。
- `lib/ui/playlist/playlist_panel.dart`(357 lines) — overlay+动画模式参考(Phase 23 D-05 类比)。
- `lib/ui/player/keyboard_handler.dart` — 既有 ← → seek 绑定(D-06 面板优先消费,不冒泡至此)。

### codebase maps
- `.planning/codebase/CONVENTIONS.md` — Tokens / ValueNotifier / glass-morphism 约定。
- `.planning/codebase/STRUCTURE.md` — `lib/ui/dialogs/settings/` 子目录结构。

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `settings_overlay_shell.dart`(291 lines) — Phase 23 壳骨架:毛玻璃 + 遮罩 + 标题栏 + 拖拽 + 键盘。**直接扩展**,不重写。
- `settings_panel_state.dart`(36 lines) — `selectedTab` ValueNotifier 已就位,初始值 0。
- `_settings_nav_item.dart`(98 lines) — hover/selected 交互逻辑可复用,布局需重构(D-11)。
- 7 个 tab 文件(`general_tab.dart` 等) — Phase 25 填内容,Phase 24 只放占位 widget。

### Established Patterns
- ValueNotifier + ValueListenableBuilder — `selectedTab` 经 shell 的 `ValueListenableBuilder` 响应切换。
- Tokens.* — 所有视觉值经 Tokens,无硬编码(bgSurface / accent / textSecondary / spMd / durationFast)。
- in-tree Stack compositing — shell 作为 PlayerScreen Stack 一层,tab bar 在 shell 内部。

### Integration Points
- `SettingsPanelState.selectedTab` — tab 切换的核心状态(D-03/D-04/D-05 共享)。
- `keyboard_handler.dart` ← → seek — 面板打开时需拦截(D-06),面板关闭后恢复。
- Phase 23 shell 的 `FocusTraversalGroup` — LB/RB 和 ← → 事件在此 scope 内消费。

</code_context>

<specifics>
## Specific Ideas

- 用户反馈"先做好键盘适配" — 键盘 ← → 与手柄 LB/RB 同步实现(D-04/D-05),不推迟到 Phase 26。
- 用户偏好"主流播放器做法" — Kodi/Steam 方向键切换 tab 范式(D-04)。
- 用户反馈"按钮不要动画效果"(历史) — tab 按钮保持 InkWell hover/press 反馈,不做额外动画。但 tab 内容区 FadeTransition 是面板级动画(D-02),不受此限。

</specifics>

<deferred>
## Deferred Ideas

- **继续优化窗口设计** — 用户提及但属新能力,非 Phase 24 范围。建议在 roadmap 中安排专门 phase。
- **Gamepad 完整导航(D-pad + A/B + SpinControl)** — Phase 26 scope,Phase 24 仅处理 LB/RB。
- **Tab 记忆(恢复上次 tab)** — 当前 Always reset to General(D-03),未来可加 SettingsStore 持久化。

</deferred>

---

*Phase: 24-Sidebar Navigation*
*Context gathered: 2026-07-23*
