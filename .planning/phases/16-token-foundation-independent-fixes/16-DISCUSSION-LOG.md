# Phase 16: Token Foundation & Independent Fixes - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-02
**Phase:** 16-Token Foundation & Independent Fixes
**Areas discussed:** Idle token values, EdgeGlow intensity range, WCAG contrast strategy

---

## Idle token values

### Q1: Token 值如何确定？

| Option | Description | Selected |
|--------|-------------|----------|
| 派生自现有 token | 基于现有 token 降低 alpha — 如 bgGlass 的 45% 降到 20%，保持色相一致，视觉上更淡 | ✓ |
| 全新独立定义 | 完全独立的颜色值 — 可以精确控制每个 token，但需要手动确保与现有 token 协调 | |
| You decide | 让我来决定如何派生或定义这些值 | |

**User's choice:** 派生自现有 token (Recommended)
**Notes:** 保持色相一致，通过降低 alpha 实现更淡效果

### Q2: 派生策略？

| Option | Description | Selected |
|--------|-------------|----------|
| 统一比例降低 | 所有 idle token 的 alpha 降低相同比例 — 如现有 alpha * 0.4，保持相对层次一致 | ✓ |
| 逐个独立调整 | 每个 token 单独调整 — 背景可能降更多，边框可能降更少，更精细控制 | |
| You decide | 让我来决定具体的降低比例 | |

**User's choice:** 统一比例降低 (Recommended)
**Notes:** 保持相对层次一致

### Q3: 统一降低到多少？

| Option | Description | Selected |
|--------|-------------|----------|
| 40-50% 降低 | alpha 降低到原来的 40-50% — 如 bgGlass 45% → 18-22%，明显更淡但仍可见 | ✓ |
| 60-70% 降低 | alpha 降低到原来的 60-70% — 如 bgGlass 45% → 27-32%，稍微淡一点，更保守 | |
| You decide | 让我来决定具体比例 | |

**User's choice:** 40-50% 降低 (Recommended)
**Notes:** 明显更淡但仍然可见

### Q4: 命名方式？

| Option | Description | Selected |
|--------|-------------|----------|
| Idle 后缀 | 如 controlBarBgIdle、controlBarBorderIdle — 与现有 controlBarBg、controlBarBorder 对应，语义清晰 | ✓ |
| Dimmed 后缀 | 如 controlBarBgDimmed、controlBarBorderDimmed — 更直观表达"变淡" | |
| You decide | 让我来决定命名方式 | |

**User's choice:** Idle 后缀 (Recommended)
**Notes:** 与现有 token 命名风格一致

### Q5: 具体要添加哪 6 个 idle token？

| Option | Description | Selected |
|--------|-------------|----------|
| REQUIREMENTS.md 的 6 个 | controlBarBgIdle, controlBarBorderIdle, glassBorderIdle, textPrimaryIdle, textSecondaryIdle, controlBarIconIdle — 覆盖背景、边框、文本、图标 | ✓ |
| 只做背景+边框 | 只添加背景和边框的 idle 版本，文本和图标复用现有 token | |
| You decide | 让我来决定具体哪些 token 需要 idle 版本 | |

**User's choice:** REQUIREMENTS.md 的 6 个 (Recommended)
**Notes:** 完整覆盖控制栏所有视觉元素

### Q6: 使用范围？

| Option | Description | Selected |
|--------|-------------|----------|
| 仅 ControlBar | 只在 ControlBar 中使用这些 idle tokens — 最小化影响范围，Phase 17 再扩展到其他组件 | ✓ |
| 所有相关组件 | 同时在 GlassContainer、EdgeGlow 等共享组件中使用 — 一次性完成所有空状态适配 | |
| You decide | 让我来决定使用范围 | |

**User's choice:** 仅 ControlBar (Recommended)
**Notes:** 最小化影响范围，Phase 17 再扩展

---

## EdgeGlow intensity range

### Q1: glowIntensity 参数的有效范围？

| Option | Description | Selected |
|--------|-------------|----------|
| 0.0-1.0 范围 | 0.0 = 无发光，1.0 = 完整发光，null = 保持现有行为 — 与 opacity 语义一致，直觉清晰 | ✓ |
| 0.0-2.0 范围 | 0.0 = 无发光，2.0 = 双倍发光 — 允许增强效果，但可能超出设计预期 | |
| You decide | 让我来决定范围 | |

**User's choice:** 0.0-1.0 范围 (Recommended)
**Notes:** 与 Flutter opacity 语义一致

### Q2: glowIntensity 如何影响现有发光效果？

| Option | Description | Selected |
|--------|-------------|----------|
| 乘以现有 alpha | glowIntensity 乘以每个 BoxShadow 的 alpha — 如 intensity=0.5 时所有 alpha 减半，保持相对层次 | ✓ |
| 直接设置 alpha | glowIntensity 直接设置为所有 BoxShadow 的 alpha — 简单但丢失层次感 | |
| You decide | 让我来决定实现方式 | |

**User's choice:** 乘以现有 alpha (Recommended)
**Notes:** 保持 5 层 BoxShadow 的相对层次

### Q3: pulse 变体的 glowIntensity 行为？

| Option | Description | Selected |
|--------|-------------|----------|
| 乘以脉冲振幅 | glowIntensity 乘以脉冲的振幅 — intensity=0.5 时脉冲范围从 0.03-0.08 变为 0.015-0.04 | ✓ |
| 作为基础强度 | glowIntensity 作为脉冲的基础强度 — intensity=0.5 时脉冲从 0.015 开始，范围 0.015-0.065 | |
| You decide | 让我来决定脉冲行为 | |

**User's choice:** 乘以脉冲振幅 (Recommended)
**Notes:** 保持脉冲的动态范围比例

### Q4: 是否需要动画过渡？

| Option | Description | Selected |
|--------|-------------|----------|
| 动画过渡 | glowIntensity 变化时使用 AnimatedOpacity 或自定义动画 — 视觉更平滑，但增加复杂度 | ✓ |
| 立即生效 | glowIntensity 变化时立即生效 — 简单直接，无额外开销 | |
| You decide | 让我来决定是否需要动画 | |

**User's choice:** 动画过渡 (Recommended)
**Notes:** 视觉更平滑

---

## WCAG contrast strategy

### Q1: 直接修改现有 token 还是新增高对比度版本？

| Option | Description | Selected |
|--------|-------------|----------|
| 修改现有 token alpha | 直接修改 textSecondary alpha 从 45% 到 50% (0x73→0x80)，简单直接，对比度提升到 ~5.3:1 | ✓ |
| 新增高对比度 token | 保留现有 textSecondary，新增 textSecondaryHighContrast token 用于需要 WCAG 合规的场景 | |
| You decide | 让我来决定策略 | |

**User's choice:** 修改现有 token alpha (Recommended)
**Notes:** 简单直接，一次性修复

### Q2: 目标对比度是多少？

| Option | Description | Selected |
|--------|-------------|----------|
| 5.3:1 (alpha 50%) | alpha 50% (0x80FFFFFF) → 对比度 ~5.3:1，满足 WCAG AA 且有余量，推荐 | ✓ |
| 4.8:1 (alpha 48%) | alpha 48% (0x7AFFFFFF) → 对比度 ~4.8:1，刚好满足 WCAG AA 4.5:1，最小改动 | |
| You decide | 让我来决定目标对比度 | |

**User's choice:** 5.3:1 (alpha 50%) (Recommended)
**Notes:** 有余量，更稳健

### Q3: idle 文本是否也需要满足 WCAG AA？

| Option | Description | Selected |
|--------|-------------|----------|
| idle 也满足 WCAG | idle 版本的 textPrimary 和 textSecondary 也满足 WCAG AA — 确保空状态文本可读性 | ✓ |
| 只修复默认状态 | 只修复默认状态的 textSecondary，idle 版本不强制 WCAG 合规 | |
| You decide | 让我来决定 | |

**User's choice:** idle 也满足 WCAG (Recommended)
**Notes:** 确保空状态文本可读性

### Q4: 如何验证 WCAG 合规？

| Option | Description | Selected |
|--------|-------------|----------|
| 自动化对比度测试 | 在 widget test 中计算对比度并断言 >= 4.5:1 — 自动化验证，防止回归 | ✓ |
| 仅 golden test | 只在 golden test 中视觉验证 — 简单但无法自动检测对比度问题 | |
| You decide | 让我来决定测试策略 | |

**User's choice:** 自动化对比度测试 (Recommended)
**Notes:** 自动化验证，防止回归

---

## Claude's Discretion

无 — 所有决策均由用户明确选择。

## Deferred Ideas

None — discussion stayed within phase scope
