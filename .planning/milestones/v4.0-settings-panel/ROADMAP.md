# Roadmap: Settings Panel Framework Refactoring (v4.0)

**Created:** 2026-07-21
**Mode:** standard
**Granularity:** standard — 5 phases 按框架层递进（壳 → 导航 → 内容 → 手柄 → 缩放），每层独立可测

## Overview

v4.0 是设置面板的**框架层重建**（非功能实现）。以 Kodi + Steam 混合导航范式为核心，先绘制窗口骨架（毛玻璃覆盖层 + 侧边栏 + tab 系统），再接入 D-pad/手柄/键鼠三模态导航，最后做响应式缩放。所有 tab 页仅渲染占位 `SettingRow` 骨架，具体功能在 v4.1+ 填充。

**Phase 编号约定：** 续 v3.0 Phase 22，v4.0 从 **Phase 23** 起至 **Phase 27**（5 phases）。

## Milestones

<details>
<summary>✅ v2.0 沉浸式全屏重构 (Phases 1-8) - SHIPPED 2026-07-13</summary>

Fullscreen cleanup, WindowService simplification, immersive UI, test updates.
</details>

<details>
<summary>✅ v2.1 播放内核重构强化 (Phases 9-14) - SHIPPED 2026-07-15</summary>

引擎 ISP 分解 + 独立状态机 + StateMonitor 拆分 + openGeneration 守卫。
</details>

<details>
<summary>✅ v3.0 内核重写 (Phases 15-22) - SHIPPED 2026-07-20</summary>

兼容式替换 + 诊断内核一等化（KernelLogger/MemoryMonitor/sealed 错误）+ 双语文档。
</details>

### 🚧 v4.0 设置面板框架重构 (Phases 23-27 — Not Started)

**Milestone Goal:** 重建设置面板框架骨架，支持 D-pad/手柄/键鼠三模态交互，毛玻璃设计语言一致，先框架后功能。

**Target features (5):** Overlay Shell & State Model · Sidebar Navigation · Tab Content Framework · Gamepad & Keyboard Navigation · Responsive Scaling.

## Phases

- [ ] **Phase 23: Overlay Shell & State Model** — SettingsPanelState (ValueNotifier 三件套) + SettingsPanelController (open/close/pause/resume) + 毛玻璃覆盖层壳 + 标题栏拖拽 + 遮罩层 + ESC/B 关闭 + 尺寸约束 (PANEL-01~07)
- [ ] **Phase 24: Sidebar Navigation** — 固定 200px 侧边栏 + 7 tab 列表 + 点击/LB/RB 切换 + FadeTransition 200ms 动画 + 选中态高亮 (SIDEBAR-01~04)
- [ ] **Phase 25: Tab Content Framework** — 7 个 tab 页壳 + SettingRow 组件（Switch/Slider/SpinControl/Dropdown）+ 内联描述 + OK/Cancel/Apply 按钮栏 + 延迟应用模式 (TABS-01~04)
- [ ] **Phase 26: Gamepad & Keyboard Navigation** — FocusTraversalGroup 分区 + FocusableActionDetector 焦点/高亮 + SpinControl 组件 + D-pad ←→ 调值 + A 确认 + B 关闭 (NAV-01~06)
- [ ] **Phase 27: Responsive Scaling & Polish** — 窗口尺寸检测 + 全屏/小窗口适配 + 面板 Scale+Fade 动效 + 集成测试 (SCALE-01~03)

## Phase Details

### Phase 23: Overlay Shell & State Model

**Goal**: 绘制设置面板的覆盖层壳（毛玻璃 + 遮罩 + 标题栏），建立状态模型和控制器，实现打开/关闭/暂停/恢复的完整生命周期
**Depends on**: Nothing (first phase of v4.0)
**Requirements**: PANEL-01, PANEL-02, PANEL-03, PANEL-04, PANEL-05, PANEL-06, PANEL-07
**Success Criteria** (what must be TRUE):

  1. `SettingsPanelState` 含 3 个 ValueNotifier（isOpen/selectedTab/dragOffset），无其他状态管理框架
  2. `SettingsPanelController.open()` 暂停视频并记录 wasPlaying，`close()` 恢复先前状态
  3. 毛玻璃覆盖层居中显示，BackdropFilter + bgGlass + borderHighlight 匹配控制栏设计语言
  4. 标题栏可拖拽，拖拽范围限制在播放器窗口内
  5. 点击遮罩 / ESC / B 键均可关闭面板
  6. 面板基础尺寸 500×400，不超过窗口 80%
  7. 打开/关闭动画（Scale + Fade）流畅无卡顿

**Plans**: TBD (via `/gsd-plan-phase`)

### Phase 24: Sidebar Navigation

**Goal**: 建立固定 200px 侧边栏导航系统，支持点击和手柄 LB/RB 切换 tab，FadeTransition 动画过渡
**Depends on**: Phase 23
**Requirements**: SIDEBAR-01, SIDEBAR-02, SIDEBAR-03, SIDEBAR-04
**Success Criteria** (what must be TRUE):

  1. 侧边栏固定 200px 宽，每个 tab 项含 Material Icons + 文字标签
  2. 7 个 tab 完整渲染（General/EQ/Audio/Video/Shortcuts/About/Performance）
  3. 选中态：accent 色背景 + 白色文字，未选中态：透明背景 + 次要文字色
  4. Tab 切换时内容区 FadeTransition 200ms 淡入淡出
  5. LB/RB 键循环切换 tab（← 减，→ 增，首尾循环）

**Plans**: TBD (via `/gsd-plan-phase`)

### Phase 25: Tab Content Framework

**Goal**: 建立 tab 内容框架和通用设置项组件，实现 OK/Cancel/Apply 延迟应用模式
**Depends on**: Phase 24
**Requirements**: TABS-01, TABS-02, TABS-03, TABS-04
**Success Criteria** (what must be TRUE):

  1. 每个 tab 页独立 StatelessWidget，渲染 SettingRow 骨架列表（占位内容）
  2. SettingRow 支持 Switch/Slider/SpinControl/Dropdown 四种控件类型
  3. 内联描述文本在标签下方（灰色小字），不单独占行
  4. OK/Cancel/Apply 按钮栏固定在面板底部
  5. 延迟应用：更改存入 pending 状态，OK/Apply 提交，Cancel 恢复原始值

**Plans**: TBD (via `/gsd-plan-phase`)

### Phase 26: Gamepad & Keyboard Navigation

**Goal**: 实现 D-pad/手柄三模态导航，FocusTraversalGroup 分区管理，SpinControl 手柄友好组件
**Depends on**: Phase 25
**Requirements**: NAV-01, NAV-02, NAV-03, NAV-04, NAV-05, NAV-06
**Success Criteria** (what must be TRUE):

  1. 面板整体和侧边栏/内容区各包裹 FocusTraversalGroup
  2. 每个 SettingRow 有 FocusableActionDetector，焦点态高亮边框，hover 态背景变化
  3. SpinControl 组件：左右方向键循环选项值，显示当前值 + 箭头指示器
  4. D-pad ←→ 在 Switch/Slider/SpinControl 上调整值（Slider 步进 5%）
  5. A 键触发确认（Switch 切换、SpinControl 选择、Button 点击）
  6. B 键关闭面板（与 ESC 等效），焦点在控件上时先退回侧边栏

**Plans**: TBD (via `/gsd-plan-phase`)

### Phase 27: Responsive Scaling & Polish

**Goal**: 实现面板响应式缩放（全屏/小窗口适配），完善动画动效，集成测试覆盖关键路径
**Depends on**: Phase 26
**Requirements**: SCALE-01, SCALE-02, SCALE-03
**Success Criteria** (what must be TRUE):

  1. MediaQuery.size 检测窗口尺寸，面板按比例缩放
  2. 全屏模式：600×480（5:4 比例），侧边栏 200px
  3. 小窗口（<800px 宽）：400×320，侧边栏 160px
  4. 打开/关闭动画 Scale + Fade 流畅（60fps）
  5. 关键路径集成测试：打开/关闭/切换 tab/拖拽/键盘导航

**Plans**: TBD (via `/gsd-plan-phase`)

## Progress

**Execution Order:**
Phases execute in numeric order: 23 → 24 → 25 → 26 → 27

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 23. Overlay Shell & State Model | v4.0 | 0/TBD | Not started | - |
| 24. Sidebar Navigation | v4.0 | 0/TBD | Not started | - |
| 25. Tab Content Framework | v4.0 | 0/TBD | Not started | - |
| 26. Gamepad & Keyboard Navigation | v4.0 | 0/TBD | Not started | - |
| 27. Responsive Scaling & Polish | v4.0 | 0/TBD | Not started | - |

## Build Order Rationale

- **壳先于内容（P23→P25）**：覆盖层壳 + 状态模型是所有后续组件的容器；无壳则无处渲染
- **侧边栏先于 tab 内容（P24→P25）**：tab 切换是内容渲染的前提；无侧边栏则 tab 内容无法切换
- **内容框架先于手柄导航（P25→P26）**：FocusTraversalGroup 需要已存在的 SettingRow 组件树
- **缩放在最后（P27）**：响应式缩放依赖完整的面板结构；先固定尺寸建框架，再做缩放适配

---
*Roadmap created: 2026-07-21 — v4.0 settings panel framework refactoring, 5 phases continuing from Phase 23*
