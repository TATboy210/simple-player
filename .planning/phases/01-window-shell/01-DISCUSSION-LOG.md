# Phase 1: Window Shell - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-09
**Phase:** 1-Window Shell
**Areas discussed:** Title bar 按钮细节

---

## Title bar 按钮细节

### Close 按钮 hover 样式

| Option | Description | Selected |
|--------|-------------|----------|
| Win11 红色高亮 | Hover 时背景变红色 (#E81123)，图标变白 — Windows 11 原生体验 | |
| Subtle 半透明 | Hover 时背景半透明，无特殊颜色 — 更简洁但不原生 | |
| 跟随系统主题 | 根据系统主题自适应颜色 | ✓ |

**User's choice:** 跟随系统主题
**Notes:** 用户不希望硬编码红色，选择跟随系统 accent color

### Hover 状态管理方式

| Option | Description | Selected |
|--------|-------------|----------|
| StatefulWidget local state | 每个按钮独立管理 hover 状态，简单直接，无全局 rebuild | ✓ |
| ValueNotifier 全局状态 | 全局 ValueNotifier<bool> isAnyButtonHovered，用于守卫重建 | |
| MouseRegion 共享 | MouseRegion + ValueNotifier 按钮组共享 | |

**User's choice:** StatefulWidget local state
**Notes:** 用户要求解释三种方案后选择。hover 是纯粹的局部 UI 状态，每个按钮自己管理最简洁，和 WIN-03 的 resize 稳定性目标完全一致

### 图标风格

| Option | Description | Selected |
|--------|-------------|----------|
| Windows 11 风格 | CustomPainter 绘制，像素级匹配 Win11，工作量适中 | ✓ |
| Material Icons | Flutter Icons 内置，零成本但风格偏 Material | |
| 自定义 Path 绘制 | 完全自定义 SVG 或 Path 绘制 | |

**User's choice:** Windows 11 风格
**Notes:** 用户要求解释后选择。用 CustomPainter 画简单几何图形（线、方框、叉），工作量不大但视觉效果最接近原生

### 按钮尺寸

| Option | Description | Selected |
|--------|-------------|----------|
| 46×32 Win11 标准 | 每个按钮 46×32px，和 Win11 原生一致 | |
| 36×36 正方形 | 每个按钮 36×36px，正方形，和标题栏等高 | ✓ |
| 自定义 | 自定义尺寸 | |

**User's choice:** 36×36 正方形
**Notes:** 用户选择正方形按钮，和 36px 标题栏等高

### Hover 动画

| Option | Description | Selected |
|--------|-------------|----------|
| 简单颜色过渡 | 背景色 150ms ease 过渡，无其他动效 — 简洁高效 | ✓ |
| 无动画 | 无动画，hover 状态立即切换 — 最省性能 | |
| 丰富动效 | 颜色 + 缩放 + 图标旋转 — 过度设计 | |

**User's choice:** 简单颜色过渡

### Tooltip

| Option | Description | Selected |
|--------|-------------|----------|
| 显示 Tooltip | 鼠标悬停 300ms 后显示 Tooltip (最小化/最大化/关闭/置顶) | ✓ |
| 不显示 | 无 tooltip，依赖图标自解释 | |

**User's choice:** 显示 Tooltip

### Pin 按钮位置

| Option | Description | Selected |
|--------|-------------|----------|
| 右侧紧邻 close | Pin 按钮在标题栏右侧，和 min/max/close 相邻 | |
| 左侧 app name 旁 | Pin 按钮在标题栏左侧（app name 旁边） | ✓ |
| 中间区域 | Pin 按钮在标题栏中间区域 | |

**User's choice:** 左侧 app name 旁
**Notes:** Pin 按钮和 min/max/close 分开布局

---

## Claude's Discretion

- 文件结构：WindowManagerService 和 AspectRatioService 放 `lib/kernel/window/`
- 测试策略：抽象接口 + FakeWindowManager 测试逻辑
- 按钮间距：按钮之间无间距（紧挨着），Pin 按钮和 app name 之间有 8px 间距

## Deferred Ideas

None — discussion stayed within phase scope.
