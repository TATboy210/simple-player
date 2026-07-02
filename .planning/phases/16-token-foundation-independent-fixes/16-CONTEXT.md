# Phase 16: Token Foundation & Independent Fixes - Context

**Gathered:** 2026-07-02
**Status:** Ready for planning

<domain>
## Phase Boundary

为播放器控制栏添加空状态视觉 tokens，调整 EdgeGlow 发光强度参数，修复文本对比度以满足 WCAG AA 标准。

**成功标准：**
1. 六个空状态常量存在于 tokens.dart 中且编译无错误
2. EdgeGlow widget 接受可选的 glowIntensity 参数（默认 null 保持现有行为）
3. 次要文本达到 WCAG AA 对比度比率（>= 4.5:1，目标 5.3:1）
4. 所有现有 golden 和 widget 测试通过且无回归

</domain>

<decisions>
## Implementation Decisions

### Idle Token Values (UI-01)
- **D-01:** 空状态 token 值从现有 token 派生（不是全新定义）
- **D-02:** 统一降低比例：现有 alpha 的 40-50%
- **D-03:** 命名约定：使用 `Idle` 后缀（如 `controlBarBgIdle`）
- **D-04:** 具体 token 列表：`controlBarBgIdle`, `controlBarBorderIdle`, `glassBorderIdle`, `controlBarTextPrimaryIdle`, `controlBarTextSecondaryIdle`, `controlBarIconIdle`
- **D-05:** 使用范围：仅 ControlBar（Phase 17 再扩展到其他组件）

### EdgeGlow Intensity Range (UI-04)
- **D-06:** 参数范围：0.0-1.0，null 时保持现有行为
- **D-07:** 实现方式：glowIntensity 乘以现有 BoxShadow 的 alpha 值（保持相对层次）
- **D-08:** pulse 变体行为：glowIntensity 乘以脉冲振幅
- **D-09:** 动画过渡：glowIntensity 变化时使用动画过渡

### WCAG Contrast Strategy (UI-05)
- **D-10:** 修复方式：直接修改现有 `textSecondary` token 的 alpha
- **D-11:** 目标对比度：5.3:1（alpha 50%，即 `0x80FFFFFF`）
- **D-12:** idle 文本也需要满足 WCAG AA 标准
- **D-13:** 测试策略：自动化对比度测试（计算并断言 >= 4.5:1）

### Claude's Discretion
无 — 所有决策均由用户明确选择。

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Design System
- `lib/ui/theme/tokens.dart` — 所有设计 token 的定义位置，新增 idle token 在此文件
- `.planning/codebase/CONVENTIONS.md` — 设计 token 使用规范、Glass-morphism 模式

### UI Components
- `lib/ui/shared/edge_glow.dart` — EdgeGlow widget 实现，需添加 glowIntensity 参数
- `lib/ui/player/control_bar.dart` — ControlBar 组件，需适配 idle tokens
- `lib/ui/shared/glass_container.dart` — GlassContainer 组件，理解 glass-morphism 模式

### Requirements
- `.planning/REQUIREMENTS.md` — UI-01, UI-04, UI-05 需求定义

### Codebase Structure
- `.planning/codebase/STRUCTURE.md` — 文件组织和命名约定
- `.planning/codebase/STACK.md` — 技术栈和依赖

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Tokens` 类：所有视觉常量通过 `Tokens.*` 访问（519 处使用），新增 idle token 遵循相同模式
- `EdgeGlow` widget：3 种变体（gradient/omni/pulse），pulse 已有动画机制可复用
- `GlassContainer` widget：59 处使用，理解 glass-morphism 模式

### Established Patterns
- 常量命名：`static const` 在 `Tokens` 类中，使用 camelCase
- 颜色格式：`Color(0xAARRGGBB)` 或 `Color.fromARGB(a, r, g, b)`
- 动画：`AnimationController` + `AnimatedBuilder` 模式（见 EdgeGlow pulse 变体）

### Integration Points
- `ControlBar._buildDecoration()`：当前使用 `static final _decoration`，需改为 `_buildDecoration(isIdle)` 方法
- `EdgeGlow` 构造函数：需添加 `double? glowIntensity` 参数
- `Tokens` 类：在控制栏 tokens 区域（第 139-144 行）后添加 idle tokens

</code_context>

<specifics>
## Specific Ideas

- 空状态效果应该明显更淡但仍然可见（不是完全透明）
- EdgeGlow 的 glowIntensity 应该平滑过渡，避免视觉跳变
- WCAG 合规是硬性要求，不是可选优化

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 16-Token Foundation & Independent Fixes*
*Context gathered: 2026-07-02*
