# Phase 1: 动画体验优化 - Context

**Gathered:** 2026-07-08
**Status:** Ready for planning

<domain>
## Phase Boundary

优化控制栏 fade 动画的时长、曲线和触发行为，使播放视频时控制栏的显示/隐藏更平滑自然。包括：fade 时长调整、动画曲线更换、底部区域触发显示、点击画面立即隐藏。

**不包括：** 毛玻璃强度调整（Phase 2）、按钮 hover 优化（Phase 3）、布局压缩（Phase 4）、底部辉光移除（Phase 5）。

</domain>

<decisions>
## Implementation Decisions

### Fade 动画参数
- **D-01:** `durationFade` 从 300ms 调整为 **400ms**（tokens.dart）
- **D-02:** 动画曲线从 `Curves.easeOut` 改为 **`Curves.easeInOut`**（auto_hide_controller.dart）— 对称感，出现和消失速度一致

### 触发行为
- **D-03:** 控制栏显示触发改为**仅底部区域** — 鼠标移动到视频区域底部（控制栏附近）才显示，其他位置移动不触发
- **D-04:** 鼠标移开控制栏后，**点击视频画面立即隐藏**控制栏（不等待延迟定时器）
- **D-05:** 鼠标悬停在控制栏上时**不隐藏**（已有 `_hovering` 机制，无需改动）

### 隐藏延迟
- **D-06:** 隐藏延迟**不变** — 窗口 5s / 全屏 3s

### 状态切换
- **D-07:** idle→playing 状态切换时，控制栏**复用同一个 fade 动画**，不特殊处理

### Claude's Discretion
- 底部区域触发的具体像素范围（距底部多少 px）由 Claude 实现时确定
- 点击隐藏的具体实现方式（GestureDetector 位置）由 Claude 决定
- 现有 `onMouseMove` 节流 100ms 机制保留

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目定义
- `.planning/PROJECT.md` — 项目背景、核心价值、需求列表
- `.planning/REQUIREMENTS.md` — CB-01a/b/c 需求定义
- `.planning/ROADMAP.md` — Phase 1 成功标准和交付物

### 代码结构
- `.planning/codebase/CONVENTIONS.md` — 编码规范、设计系统、状态管理模式
- `.planning/codebase/STRUCTURE.md` — 目录布局、文件位置

### 关键源文件
- `lib/ui/player/auto_hide_controller.dart` — 自动隐藏状态机（show/hide/scheduleHide/onMouseMove）
- `lib/ui/player/controls_overlay.dart` — 控制栏叠加层（使用 AutoHideController）
- `lib/ui/theme/tokens.dart` — 设计令牌（durationFade=300, hideDelayWindowed=5, hideDelayFullscreen=3）

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `AutoHideController` — 完整的状态机，支持 show/hide/scheduleHide/hover/resize，只需调整参数和触发逻辑
- `_hovering` 标志 — 已实现"悬停不隐藏"逻辑，无需新增机制
- `Tokens.durationFade` — 集中管理的动画时长常量

### Established Patterns
- `AnimationController` + `CurvedAnimation` + `FadeTransition` — 标准 Flutter 动画模式
- `Timer` 延迟隐藏 + 节流 100ms — 防抖机制已完善
- `ValueNotifier<bool> visible` — 可见性通知器驱动 UI 重建

### Integration Points
- `ControlsOverlay` 创建 `AutoHideController` 并监听其 `opacity` 和 `visible`
- `PlayerScreen` 通过 `MouseRegion` 捕获鼠标事件传递给 `ControlsOverlay`
- `onMouseMove` 当前在 `ControlsOverlay` 的 `MouseRegion` 中触发

</code_context>

<specifics>
## Specific Ideas

用户明确描述了期望行为：
1. 鼠标移动到控制栏区域 → 控制栏显现
2. 鼠标移开控制栏 + 点击画面 → 控制栏立即隐藏
3. 鼠标悬停在控制栏上不动 → 延长隐藏时间（不冲突，`_hovering` 已处理）

参考：VLC 默认 fade 500ms，mpv OSC 采用类似自动隐藏策略。

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 1-动画体验优化*
*Context gathered: 2026-07-08*
