# Phase 24: Sidebar Navigation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-23
**Phase:** 24-Sidebar Navigation
**Areas discussed:** Tab content container, LB/RB scope, Sidebar visual style, Tab bar dimensions, Title bar content, Small window behavior, Content area spacing

---

## Tab Content Container

| Option | Description | Selected |
|--------|-------------|----------|
| IndexedStack | 所有 7 个 tab 保持存活,切换时仅改变可见性。pending 值/滚动位置不丢失。 | ✓ |
| AnimatedSwitcher | 切换时销毁旧 tab、重建新 tab。轻量但丢失状态。旧 settings_panel 用此方案。 | |
| IndexedStack + FadeTransition | IndexedStack 常驻 + FadeTransition 叠加在可见 tab 上做淡入淡出。 | |

**User's choice:** IndexedStack
**Notes:** 保状态优先,设置面板场景内存开销微不足道

### FadeTransition 驱动方式

| Option | Description | Selected |
|--------|-------------|----------|
| TweenAnimationBuilder | 每个 tab 包裹 TweenAnimationBuilder<double>,自动触发,无需手动管理 controller。 | ✓ |
| Shared AnimationController | shell State 内持有一个 controller,tab 切换时 forward()。 | |
| Per-tab AnimationController | 每个 tab widget 内部管理自己的 controller。完全解耦但 7 个 controller 常驻。 | |

**User's choice:** TweenAnimationBuilder
**Notes:** 最简实现,dispose 自动处理

### 初始 Tab

| Option | Description | Selected |
|--------|-------------|----------|
| Always reset to General | 面板打开时固定 selectedTab=0,不记忆上次 tab。 | ✓ |
| Remember last tab | 关闭时记住,下次打开恢复。需持久化到 SettingsStore。 | |
| Hybrid | 首次 General,之后 remember。 | |

**User's choice:** Always reset to General
**Notes:** 简单可预测,避免跨会话状态不一致

---

## LB/RB Scope

### 输入范围

| Option | Description | Selected |
|--------|-------------|----------|
| Gamepad only | 仅处理 GamepadButton.leftShoulder / rightShoulder。 | |
| Gamepad + keyboard ([ / ]) | 同时支持键盘括号键。 | |
| All input methods | LB/RB + PageUp/PageDown + [ / ]。 | |

**User's choice:** "先做好键盘适配" — 键盘优先
**Notes:** 用户希望键盘和手柄同步实现

### 键盘按键选择

| Option | Description | Selected |
|--------|-------------|----------|
| [ / ] (括号键) | 旧设置面板兼容,但当前用于字幕延迟。 | |
| PageUp / PageDown | 标准翻页键,无冲突。 | |
| ← → (左右方向键) | 最小按键,与 seek 冲突但面板可优先消费。 | |

**User's choice:** "主流的播放器快捷操作是什么,按照他们的做法"
**Notes:** 确认为 Kodi/Steam 范式 — 方向键 ← → 切换 tab

### 手柄 LB/RB 时机

| Option | Description | Selected |
|--------|-------------|----------|
| Both keyboard + gamepad | Phase 24 同步实现键盘 ← → 和手柄 LB/RB。 | ✓ |
| Keyboard only, gamepad in Phase 26 | Phase 24 只做键盘,手柄留给 Phase 26。 | |

**User's choice:** Both keyboard + gamepad
**Notes:** 一次到位,Phase 26 不需重复

---

## Sidebar Visual Style

### 布局结构

| Option | Description | Selected |
|--------|-------------|----------|
| Left sidebar 200px | Roadmap 原始设计:左侧固定 200px 垂直导航。 | |
| Top: title / Middle: horizontal tabs / Bottom: content | 标题在顶部,tab 横向排列在标题下方,内容区占剩余空间。 | ✓ |
| Top: title / Left: tabs / Right: content | 标题在顶部,左侧 tab 纵向排列,右侧内容区。 | |

**User's choice:** Top: title / Middle: horizontal tabs / Bottom: content
**Notes:** 明确偏离 roadmap 的左侧 200px 设计。用户描述: "做成上中下的布局,上标题 中tab 下详细的设置信息设置面板"

### Tab bar 背景

| Option | Description | Selected |
|--------|-------------|----------|
| Flat bgSurface | 侧边栏背板用 Tokens.bgSurface 平坦深色,与内容区毛玻璃形成层次对比。 | ✓ |
| Glass background | 侧边栏也用 GlassContainer 毛玻璃,与面板统一。 | |
| Transparent | 无独立背板,仅靠 nav items 选中态指示位置。 | |

**User's choice:** Flat bgSurface
**Notes:** "中间的tab用 Tokens.bgSurface 平坦深色,与内容区的毛玻璃形成层次对比 简洁,不与内容区竞争视觉注意力"

---

## Tab Bar Dimensions

| Option | Description | Selected |
|--------|-------------|----------|
| 48px | 与旧 nav item 48px 一致。 | |
| 40px | 更紧凑,节省垂直空间。 | ✓ |
| 56px | 更宽松,触控友好。 | |

**User's choice:** 40px
**Notes:** 桌面场景无需触控友好尺寸

---

## Title Bar Content

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse existing shell title bar | 复用 Phase 23 标题栏:"Settings" + 关闭按钮 + 拖拽。 | ✓ |
| Minimal: close button only | 仅保留关闭按钮,"Settings" 放 tab bar 左侧。 | |
| No title bar | 去掉标题栏,tab bar 就是顶部。 | |

**User's choice:** Reuse existing shell title bar
**Notes:** Phase 23 已实现,不重复造轮子

---

## Small Window Behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Equal width + ellipsis | 7 tab 等宽分配,小窗口时自动缩小,文字过长省略号。 | ✓ |
| Fixed width + scroll | 每个 tab 固定宽度,超出时横向滚动。 | |
| Icon-only on small window | 小窗口时隐藏文字标签,仅显示图标。 | |

**User's choice:** Equal width + ellipsis
**Notes:** 最简单,符合 SIDEBAR-02 "7 tab 全部可见" 要求

---

## Content Area Spacing

| Option | Description | Selected |
|--------|-------------|----------|
| 16dp padding, no divider | 内容区四周 16dp padding,靠背景区分。 | ✓ |
| 16dp padding + divider | 内容区 16dp + 1px 分隔线。 | |
| No padding (tab-controlled) | 内容区无 padding,各 tab 自行控制。 | |

**User's choice:** 16dp padding, no divider
**Notes:** 简洁,毛玻璃 vs bgSurface 自然区分

---

## Claude's Discretion

无 — 用户对所有问题均作出明确选择。

## Deferred Ideas

- **继续优化窗口设计** — 用户提及,属新能力,建议安排专门 phase。
- **Gamepad 完整导航(D-pad + A/B + SpinControl)** — Phase 26 scope。
- **Tab 记忆(恢复上次 tab)** — 当前 Always reset to General,未来可加 SettingsStore 持久化。
