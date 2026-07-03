# Phase 17: Adaptive Control Bar - Context

**Gathered:** 2026-07-03
**Status:** Ready for planning

<domain>
## Phase Boundary

ControlBar 在 idle↔playing 状态间切换时，使用 AnimatedContainer 实现平滑的颜色/边框过渡动画。GlassContainer 的 `backgroundColor` 参数和 ControlBar 的 `_decorationIdle`/`_decorationPlaying` 已在 Phase 16 完成，本阶段聚焦过渡动画的实现。

**成功标准（来自 ROADMAP.md）：**
1. GlassContainer 接受可选 backgroundColor 参数（默认 Tokens.bgGlass，向后兼容）— ✅ Phase 16 已完成
2. ControlBar 空闲状态显示不同的装饰（更淡、更透明）
3. ControlBar 播放状态保持现有装饰不变
4. idle↔playing 状态过渡视觉平滑（无闪烁或跳变）
5. GlassContainer 和 ControlBar 的现有调用点零修改

</domain>

<decisions>
## Implementation Decisions

### 过渡动画策略

- **D-01:** 动画方式 — 使用 `AnimatedContainer` 替换当前的 `Container`，颜色/边框自动插值。代码改动最小，只需把 `static final` 装饰改为 getter + duration 参数
- **D-02:** 动画时长 — `Tokens.durationNormal`（150ms），快速响应，适合频繁切换场景
- **D-03:** 动画属性 — 仅 Container 的 `color` + `border` 颜色参与插值。boxShadow 保持 `static final` 不参与动画（避免复杂 Tween 曲线和意外中间态）
- **D-04:** 缓动曲线 — `Curves.easeInOut`，开头和结尾减速，最常用的平滑过渡曲线
- **D-05:** EdgeGlow 同步 — `glowIntensity`（idle=0.3, playing=null）也同步动画过渡，与背景变化协调一致
- **D-06:** boxShadow 处理 — 保持 `static final`，idle 时用精简阴影（无外层投影），playing 时用完整 4 层阴影，不参与 AnimatedContainer 插值
- **D-07:** 实现方式 — 将 `_decorationIdle` 和 `_decorationPlaying` 从 `static final` 改为 getter 或方法，每次 build 时根据 `isIdle` 构建新 `BoxDecoration`。AnimatedContainer 负责插值

### Claude's Discretion
无 — 所有决策均由用户明确选择。

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 设计系统
- `lib/ui/theme/tokens.dart` — 所有设计 token 定义位置，idle tokens 在第 62-69 行和第 86 行
- `.planning/codebase/CONVENTIONS.md` — 设计 token 使用规范、Glass-morphism 模式、动画常量

### UI 组件
- `lib/ui/player/control_bar.dart` — ControlBar 组件，需将 static final 装饰改为 AnimatedContainer + getter
- `lib/ui/shared/glass_container.dart` — GlassContainer 组件，已有 backgroundColor 参数
- `lib/ui/shared/edge_glow.dart` — EdgeGlow widget，glowIntensity 需同步动画

### 需求
- `.planning/REQUIREMENTS.md` — UI-02、UI-03 需求定义

### 前置阶段
- `.planning/phases/16-token-foundation-independent-fixes/16-CONTEXT.md` — Phase 16 决策（idle token 命名/派生比例/EdgeGlow 参数范围/WCAG 策略）

### 代码库结构
- `.planning/codebase/STRUCTURE.md` — 文件组织和命名约定

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Tokens` 类：idle tokens 已定义（`controlBarBgIdle`, `controlBarBorderIdle`, `glassBorderIdle`, `controlBarTextPrimaryIdle`, `controlBarTextSecondaryIdle`, `controlBarIconIdle`）
- `AnimatedContainer`：Flutter 内置 widget，自动对 `color`、`border` 等属性做隐式动画
- `Tokens.durationNormal`（150ms）和 `Tokens.durationFade`（300ms）：现有动画常量
- `Curves.easeInOut`：Flutter 内置缓动曲线

### Established Patterns
- ControlBar 当前使用 `static final _decorationIdle` / `_decorationPlaying`，需改为 getter 动态构建
- EdgeGlow 的 `glowIntensity` 参数接受 `double?`，null 时保持现有行为
- BackdropFilter 通过 `_buildBlur` 方法封装，opacity < 0.01 时跳过（D-13）

### Integration Points
- `ControlBar.build()` 方法：第 169 行 `final decoration = isIdle ? _decorationIdle : _decorationPlaying;` — 需改为 AnimatedContainer
- `ControlBar` 第 176 行 `EdgeGlow(glowIntensity: isIdle ? 0.3 : null)` — 需改为动画过渡
- `ControlBar` 构造函数的 `isIdle` 参数：由外部传入，决定状态

</code_context>

<specifics>
## Specific Ideas

- 过渡应该平滑但不拖沓 — 150ms 是"能感知但不干扰"的时长
- boxShadow 不参与动画 — 保持 static final 避免复杂 Tween 和意外中间态
- EdgeGlow 发光强度与背景同步变化 — 视觉协调一致

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 17-Adaptive Control Bar*
*Context gathered: 2026-07-03*
