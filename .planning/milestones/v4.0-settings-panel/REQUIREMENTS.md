# Requirements: Settings Panel Framework Refactoring (v4.0)

**Defined:** 2026-07-21
**Core Value:** 以 Kodi + Steam 混合导航范式重建设置面板框架，支持 D-pad/手柄/键鼠三模态交互，保持毛玻璃设计语言一致性，先框架后功能。

> **范围约定：** 本里程碑聚焦框架骨架（窗口绘制 + 导航系统 + 交互模式），**不实现**具体设置项的功能逻辑。所有 tab 页仅渲染占位内容（SettingRow 骨架），实际功能在后续里程碑填充。

## Design Decisions (Frozen)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| 面板位置 | 居中覆盖层，可拖拽（限窗口内） | 不创建独立窗口，复用现有 overlay 架构 |
| 视频行为 | 打开设置时暂停，关闭时恢复 | 避免用户调整时视频跳帧干扰 |
| 基础尺寸 | 500×400 (1080p)，全屏等比缩放 | 主流播放器设置面板尺寸参考 |
| 圆角 | 8dp | 匹配 control bar 圆角 |
| 遮罩 | 毛玻璃模糊 (BackdropFilter) | 匹配设计语言 |
| 标题栏 | 左 "设置" + 右 × 关闭按钮 | 简洁清晰 |
| 侧边栏 | 固定展开 200px，图标+文字 | 游戏手柄友好，不需要折叠判断 |
| Tab 页 | 7 个完整 tab | General/EQ/Audio/Video/Shortcuts/About/Performance |
| 关闭方式 | 点击遮罩 + ESC + B 键 | 三模态统一退出 |
| 按钮栏 | OK/Cancel/Apply | 延迟应用模式（locale/theme/shortcuts） |
| 描述文本 | 内联（每项下方） | 信息密度适中 |
| 导入导出 | 暂不实现 | 后续里程碑 |
| Tab 动画 | Fade in/out 200ms | 平滑切换 |
| 面板动画 | Scale + Fade in/out | 打开/关闭动效 |
| 导航范式 | Kodi + Steam 混合 | D-pad ↑↓ 选项, ←→ 调值, LB/RB 切 tab, A 确认, B 返回 |

## Framework Requirements

### PANEL — Overlay Shell & State Model

- [ ] **PANEL-01**: `SettingsPanelState` 状态模型 — `ValueNotifier<bool> isOpen`、`ValueNotifier<int> selectedTab`、`ValueNotifier<Offset> dragOffset`；视频暂停/恢复由 `PlaybackController` 协调
- [ ] **PANEL-02**: `SettingsPanelController` — `open()`/`close()`/`toggle()` 方法，打开时暂停视频并记录先前播放状态（`wasPlaying`），关闭时恢复到先前状态
- [ ] **PANEL-03**: 毛玻璃覆盖层壳 — `BackdropFilter(sigmaX/Y)` + `bgGlass` + `borderHighlight`，居中定位（`Alignment.center`），拖拽约束在播放器窗口内
- [ ] **PANEL-04**: 标题栏 — 左侧 "设置" 文字 + 右侧 × 关闭按钮（`GlassIconButton`），拖拽区域仅标题栏
- [ ] **PANEL-05**: 遮罩层 — 半透明遮罩覆盖整个播放器，点击遮罩关闭面板，`AnimatedOpacity` + `AnimatedScale` 开关动效
- [ ] **PANEL-06**: 键盘关闭 — `ESC` 和 `B` 键关闭面板（`FocusTraversalGroup` 内 `LogicalKeySet` 处理）
- [ ] **PANEL-07**: 面板尺寸 — 500×400 基础尺寸，全屏时按窗口比例缩放（`MediaQuery.size` 计算），最大不超过窗口 80%

### SIDEBAR — Sidebar Navigation

- [ ] **SIDEBAR-01**: 固定 200px 侧边栏 — 左侧垂直导航，每个 tab 项含图标 + 文字标签，选中态高亮（`accent` 色背景 + 白色文字）
- [ ] **SIDEBAR-02**: Tab 列表 — 7 个完整 tab（General/EQ/Audio/Video/Shortcuts/About/Performance），每项 48px 高度，垂直排列
- [ ] **SIDEBAR-03**: Tab 切换 — 点击切换 + `FadeTransition` 200ms 过渡动画，内容区淡入淡出
- [ ] **SIDEBAR-04**: LB/RB 快捷键 — 手柄 LB/RB 键循环切换 tab（左减右增，循环），与点击切换共享同一 `selectedTab` notifier

### TABS — Tab Content Framework

- [ ] **TABS-01**: 7 个 tab 页壳 — 每个 tab 为独立 `StatelessWidget`，接收当前 tab 索引，渲染 `SettingRow` 骨架列表（占位内容）
- [ ] **TABS-02**: `SettingRow` 组件 — 标签 + 控件布局，支持 `Switch`/`Slider`/`SpinControl`/`Dropdown` 控件类型，内联描述文本（标签下方灰色小字）
- [ ] **TABS-03**: OK/Cancel/Apply 按钮栏 — 底部固定，OK 应用所有待定更改并关闭，Cancel 丢弃并关闭，Apply 应用但不关闭
- [ ] **TABS-04**: 延迟应用模式 — locale/theme/shortcuts 更改存入 `_pending*` 状态，仅 OK/Apply 时提交，Cancel 恢复原始值

### NAV — Gamepad & Keyboard Navigation

- [ ] **NAV-01**: `FocusTraversalGroup` 包裹整个面板 — 侧边栏和内容区各为独立 `FocusTraversalGroup`，D-pad ↑↓ 在当前组内移动焦点
- [ ] **NAV-02**: `FocusableActionDetector` 在每个 `SettingRow` — 焦点态显示高亮边框（`borderHighlight`），hover 态显示 `bgHover` 背景
- [ ] **NAV-03**: `SpinControl` 组件 — 左右方向键循环切换选项值（替代 Dropdown，手柄友好），显示当前值 + 左右箭头指示器
- [ ] **NAV-04**: D-pad ←→ 调整值 — 在 SpinControl/Switch/Slider 上，左右方向键调整当前值（Slider 步进 5%）
- [ ] **NAV-05**: A 键确认 — 在可交互控件上，A 键触发确认（Switch 切换、SpinControl 选择、Button 点击）
- [ ] **NAV-06**: B 键关闭 — 任何时候 B 键关闭设置面板（与 ESC 等效），若焦点在控件上则先退回侧边栏

### SCALE — Responsive Scaling

- [ ] **SCALE-01**: 窗口尺寸检测 — `MediaQuery.size` 检测播放器窗口尺寸，面板尺寸按比例缩放
- [ ] **SCALE-02**: 全屏适配 — 全屏模式下面板放大到 600×480（保持 5:4 比例），侧边栏保持 200px
- [ ] **SCALE-03**: 小窗口适配 — 窗口 < 800px 宽时，面板缩小到 400×320，侧边栏缩到 160px

## Out of Scope

| Feature | Reason | Deferred To |
|---------|--------|-------------|
| 具体设置功能逻辑 | 本里程碑只建框架 | v4.1+ |
| 导入导出 | 非核心框架功能 | v4.2+ |
| 独立窗口模式 | 当前使用覆盖层 | 若需求驱动再评估 |
| 自定义快捷键编辑 | Shortcuts tab 仅占位 | v4.1+ |
| 音频均衡器可视化 | EQ tab 仅占位 | v4.1+ |
| 手柄输入适配层 | Steam Input API 自动映射 | N/A |
| 设置持久化 | 复用现有 SettingsStore | 集成阶段 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| PANEL-01 | Phase 23 | Pending |
| PANEL-02 | Phase 23 | Pending |
| PANEL-03 | Phase 23 | Pending |
| PANEL-04 | Phase 23 | Pending |
| PANEL-05 | Phase 23 | Pending |
| PANEL-06 | Phase 23 | Pending |
| PANEL-07 | Phase 23 | Pending |
| SIDEBAR-01 | Phase 24 | Pending |
| SIDEBAR-02 | Phase 24 | Pending |
| SIDEBAR-03 | Phase 24 | Pending |
| SIDEBAR-04 | Phase 24 | Pending |
| TABS-01 | Phase 25 | Pending |
| TABS-02 | Phase 25 | Pending |
| TABS-03 | Phase 25 | Pending |
| TABS-04 | Phase 25 | Pending |
| NAV-01 | Phase 26 | Pending |
| NAV-02 | Phase 26 | Pending |
| NAV-03 | Phase 26 | Pending |
| NAV-04 | Phase 26 | Pending |
| NAV-05 | Phase 26 | Pending |
| NAV-06 | Phase 26 | Pending |
| SCALE-01 | Phase 27 | Pending |
| SCALE-02 | Phase 27 | Pending |
| SCALE-03 | Phase 27 | Pending |

**Coverage:** 24 requirements, all mapped to phases.

---
*Created: 2026-07-21 — v4.0 settings panel framework refactoring*
