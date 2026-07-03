# Phase 17: Adaptive Control Bar - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-03
**Phase:** 17-Adaptive Control Bar
**Areas discussed:** 过渡动画策略

---

## 过渡动画策略

### Q1: 动画方式

| Option | Description | Selected |
|--------|-------------|----------|
| AnimatedContainer | 用 AnimatedContainer 替换 Container，颜色/边框自动插值。代码改动最小 | ✓ |
| Crossfade 双层 | 两个装饰层叠，AnimatedOpacity 交叉淡入淡出。GPU 开销翻倍 | |
| 保持瞬间切换 | 不加动画，确保切换瞬间无闪烁 | |

**User's choice:** AnimatedContainer（推荐）
**Notes:** 代码改动最小，只需把 static final 改为实例属性 + duration 参数

### Q2: 动画时长

| Option | Description | Selected |
|--------|-------------|----------|
| 150ms | Tokens.durationNormal，快速响应，适合频繁切换 | ✓ |
| 300ms | Tokens.durationFade，更柔和但连续操作时感觉延迟 | |

**User's choice:** 150ms（推荐）

### Q3: 动画属性

| Option | Description | Selected |
|--------|-------------|----------|
| 颜色 + 边框 | 仅 Container 的 color + border 颜色插值，boxShadow 保持 static final | ✓ |
| 全部装饰属性 | 颜色 + 边框 + boxShadow color，需要 Tween<BoxShadow> 或手动 lerp | |
| 仅背景色 | 只动画背景色，边框瞬间切换 | |

**User's choice:** 颜色 + 边框（推荐）
**Notes:** boxShadow 动画需要复杂 Tween 曲线，避免意外中间态

### Q4: 缓动曲线

| Option | Description | Selected |
|--------|-------------|----------|
| easeInOut | Curves.easeInOut，开头和结尾减速，最常用 | ✓ |
| linear | Curves.linear，匀速过渡 | |
| easeOut | Curves.easeOut，快速开始、缓慢结束 | |

**User's choice:** easeInOut（推荐）

### Q5: EdgeGlow 同步

| Option | Description | Selected |
|--------|-------------|----------|
| 同步动画 | glowIntensity 从 0.3→null 也用 AnimatedContainer 的 duration 同步过渡 | ✓ |
| 瞬间切换 | EdgeGlow 保持现有 pulse 动画机制，glowIntensity 瞬间切换 | |

**User's choice:** 同步动画（推荐）
**Notes:** 视觉上发光和背景一起变化，更协调

### Q6: boxShadow 处理

| Option | Description | Selected |
|--------|-------------|----------|
| 保持 static | boxShadow 列表保持 static final，不参与 AnimatedContainer 插值 | ✓ |
| 也参与动画 | boxShadow 也改为实例属性，用 AnimatedContainer 自动插值 | |

**User's choice:** 保持 static（推荐）
**Notes:** boxShadow 的 lerp 行为可能产生意外中间态

### Q7: 实现方式

| Option | Description | Selected |
|--------|-------------|----------|
| getter 动态构建 | 将 static final 改为 getter 或方法，每次 build 时根据 isIdle 构建新 BoxDecoration | ✓ |
| 手动 Tween | 保留两个 static final，但在 build 中手动 tween 颜色值 | |

**User's choice:** getter 动态构建（推荐）

---

## Claude's Discretion

无 — 所有决策均由用户明确选择。

## Deferred Ideas

None — discussion stayed within phase scope
