# Phase 27: Responsive Scaling & Polish - Context

**Gathered:** 2026-07-25
**Status:** Ready for planning

<domain>
## Phase Boundary

在已完成的设置面板框架（Phase 23 壳 + Phase 24 tab 导航 + Phase 25 内容框架 + Phase 26 手柄导航）基础上，实现面板响应式缩放（全屏/小窗口适配）、优化动画动效至 60fps、集成测试覆盖关键路径。

覆盖 3 项需求：SCALE-01（响应式尺寸）~ SCALE-03（集成测试）。

**Carrying forward from earlier phases:**
- Phase 23 D-05: Stack in-tree 挂载方式
- Phase 23 D-07/D-08: AnimatedOpacity+AnimatedScale 200ms + apple_curves
- Phase 23 D-10: 面板自管 Focus subtree
- Phase 24 D-07/D-08/D-09: Top/Middle/Bottom 三段式水平布局（取代 Roadmap 原定义的左侧 200px 垂直导航）
- Phase 26: SpinControl、焦点边框、A/B 键映射

</domain>

<decisions>
## Implementation Decisions

### Tab Bar 适配

- **D-01:** 断点策略 — **800px 断点切换**。≥800px 正常模式，<800px 压缩模式。与 ROADMAP Success Criteria 的 800px 断点完全对齐。两档固定，简单明确。— **Reversibility:** reversible — 断点值和模式参数可随时调整。
- **D-02:** 正常模式样式 — **14px 字体 + 16px 间距**。7 tab 等宽均分，文字过长时省略号截断（承袭 Phase 24 D-09）。— **Reversibility:** reversible
- **D-03:** 压缩模式样式 — **12px 字体 + 8px 间距**。400px 面板下 7 tab 仍全部可见，不滚动、不隐藏。保持可读性同时节省空间。— **Reversibility:** reversible
- **D-04:** 面板宽度 — **连续比例缩放 `clamp(windowWidth * 0.8, 400, 600)`**。面板始终居中，随窗口平滑缩放。与 PANEL-07（≤窗口 80%）一致。高度按 5:4 比例跟随。— **Reversibility:** reversible — clamp 参数可随时调整。
- **D-05:** Tokens 新增 — 在 `tokens.dart` 中新增 responsive 相关常量（tabBarFontNormal、tabBarFontCompact、tabBarSpacingNormal、tabBarSpacingCompact、panelMinWidth、panelMaxWidth、breakpointResponsive）。— **Reversibility:** reversible

### 动效完善

- **D-06:** 动画基础 — **保持 Phase 23 现有动画**（AnimatedOpacity + AnimatedScale，200ms，apple_curves）。不引入新动画框架或弹性动画。— **Reversibility:** reversible
- **D-07:** 60fps 优化 — **RepaintBoundary 隔离面板重绘区域**。面板外层包裹 RepaintBoundary，动画期间只重绘面板，不触发 PlayerScreen 整体重绘。— **Reversibility:** reversible — 添加/移除 RepaintBoundary 无副作用。
- **D-08:** BackdropFilter — **动画期间保持模糊不变**。依赖 RepaintBoundary 隔离保障 60fps，不临时禁用或降低模糊强度。视觉一致性优先。— **Reversibility:** reversible
- **D-09:** 断点切换动效 — **无过渡动画，立即切换**。窗口跨越 800px 断点时面板尺寸立即变化，不做 AnimatedContainer 或 Tween 过渡。简单直接。— **Reversibility:** reversible

### Claude's Discretion

无 — 用户对全部 2 个领域均作出明确选择，未出现 "you decide" 延迟。

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 计划/需求
- `.planning/PROJECT.md` — v4.0 milestone 定义、Kodi+Steam 混合导航范式、框架优先策略。
- `.planning/REQUIREMENTS.md` §v4.0 — SCALE-01..03 逐项需求（响应式尺寸 / 动画流畅 / 集成测试）。
- `.planning/ROADMAP.md` §Phase 27 — Goal + 5 条 Success Criteria（MediaQuery 检测、全屏 600×480、小窗口 400×320、60fps 动画、关键路径集成测试）。
- `CLAUDE.md` — Design System（Tokens.* / GlassContainer）、Coding Conventions、Dart/Flutter Rules。

### 前置 Phase 决策（LIVE，须核对）
- `.planning/phases/23-overlay-shell-state-model/23-CONTEXT.md` — D-05（Stack in-tree 挂载）、D-07/D-08（200ms 动画 + apple_curves）、D-10（面板自管 Focus subtree）。
- `.planning/phases/24-sidebar-navigation/24-CONTEXT.md` — D-07/D-08/D-09（Top/Middle/Bottom 三段式布局，取代左侧 200px 侧边栏）。
- `.planning/phases/26-gamepad-keyboard-navigation/26-CONTEXT.md` — D-01~D-23（SpinControl、焦点边框、A/B 键映射）。

### 代码资产（LIVE，须核对）
- `lib/ui/dialogs/settings/settings_overlay_shell.dart`（638 行）— **挂载点**：Phase 23-26 壳骨架已完成，Phase 27 在此基础上添加 RepaintBoundary + 响应式尺寸逻辑。
- `lib/ui/dialogs/settings/settings_panel_state.dart` — 状态模型，可能需扩展响应式相关状态。
- `lib/ui/theme/tokens.dart` — 设计令牌，需新增 responsive 相关常量（D-05）。
- `lib/ui/shared/glass_container.dart` — 毛玻璃容器，RepaintBoundary 需包裹其外层。
- `lib/ui/player/player_screen.dart` — Stack 组合根，面板作为其中一层。

### codebase maps
- `.planning/codebase/CONVENTIONS.md` — Tokens / ValueNotifier / glass-morphism 约定。
- `.planning/codebase/STRUCTURE.md` — `lib/ui/dialogs/settings/` 子目录结构。
- `.planning/codebase/STACK.md` — Flutter desktop + fvp + window_manager 技术栈。

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `settings_overlay_shell.dart`（638 行）— Phase 23-26 壳骨架已完成（毛玻璃 + 遮罩 + 标题栏 + tab bar + IndexedStack + 焦点管理 + A/B 键）。**直接扩展**，不重写。
- `glass_container.dart`（383 行）— 毛玻璃容器，RepaintBoundary 包裹其外层。
- `tokens.dart` — 设计令牌系统，新增 responsive 常量的自然落点。
- `apple_curves.dart` — 动画曲线，Phase 23 已采用（D-08），Phase 27 复用。

### Established Patterns
- ValueNotifier + ValueListenableBuilder — 状态管理模式，响应式断点可通过 ValueNotifier<bool> isCompact 暴露。
- Tokens.* — 所有视觉值经 Tokens，responsive 常量也应遵循此约定。
- AnimatedOpacity + AnimatedScale 200ms — 面板开/关动画统一节奏。
- 800px 断点 — 与 ROADMAP Success Criteria 对齐，作为 responsive 唯一断点。

### Integration Points
- `settings_overlay_shell.dart` — 添加 RepaintBoundary + 响应式尺寸计算。
- `settings_panel_state.dart` — 可能需添加 `isCompact` notifier（基于 MediaQuery.width < 800）。
- `tokens.dart` — 新增 responsive 常量。
- `player_screen.dart` — Stack 中面板层的尺寸约束可能需调整。

</code_context>

<specifics>
## Specific Ideas

- 用户选择"自适应压缩字体/间距"而非滚动或隐藏 — 7 tab 始终全部可见是核心约束。
- 用户选择"保持现有+性能优化"而非新动画框架 — 稳妥路线，不改变已验证的动画行为。
- 面板宽度连续比例缩放（clamp 策略）与 PANEL-07（≤窗口 80%）自然对齐。

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 27-Responsive Scaling & Polish*
*Context gathered: 2026-07-25*
