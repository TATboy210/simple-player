# Phase 5: 全屏与设置面板交互规范化 - Context

**Gathered:** 2026-07-13
**Status:** Ready for planning

<domain>
## Phase Boundary

规范化全屏与设置面板的交互行为：进入全屏时面板不遮挡视频、退出全屏时面板状态保持、全屏下打开/关闭面板正常、面板位置自适应。设置面板需要感知 WindowService 的全屏状态并做出响应。不涉及设置面板内部功能改动，不涉及全屏代码本身的改动。

</domain>

<decisions>
## Implementation Decisions

### 全屏进入行为
- **D-01:** 用户在设置面板打开时进入全屏，面板保持打开并自动重定位到屏幕中心。不自动关闭，不丢失用户正在编辑的状态。
- **D-02:** 进入全屏时，面板中未保存的修改（pending 状态）不触发保存，保持 pending。用户关闭面板时仍按 OK/Cancel 决定是否保存。
- **D-03:** 面板从当前位置重定位到屏幕中心时使用平滑动画过渡（如 AnimatedSlide），视觉连续性好。
- **D-04:** 全屏下设置面板打开时，ESC 键先关闭设置面板，再按 ESC 退出全屏。符合"最近打开的先关闭"原则。

### 面板位置策略
- **D-05:** 全屏下面板定位为屏幕居中（水平+垂直居中）。不保持窗口模式的 topLeft + (80, 48) 偏移，因为全屏下没有标题栏需要避让。
- **D-06:** 窗口模式下保持现有定位逻辑不变（topLeft + 80px left, 48px top，可拖拽）。

### 背景样式
- **D-07:** 全屏下面板的半透明背景保持 Colors.black54 不变，不加深。保持一致性，用户仍能看到视频。

### 退出全屏恢复
- **D-08:** 退出全屏时，如果设置面板是打开的，面板平滑滑动回窗口模式的默认位置 (topLeft + 80, 48)。不关闭面板，不打断用户操作流。
- **D-09:** 退出全屏时面板的 offset（用户拖拽产生的偏移量）需要重置为 Offset.zero，因为窗口模式和全屏的参考坐标系不同。

### 技术实现方向
- **D-10:** 设置面板需要接收 WindowService（或 WindowBridge）引用，通过监听 `windowService.mode` ValueNotifier 感知全屏状态变化。
- **D-11:** 面板内部根据 `isFullscreen` 状态切换定位策略：窗口模式用 topLeft 偏移，全屏模式用居中对齐。
- **D-12:** ESC 键拦截逻辑需要在设置面板的 KeyboardHandler 中添加：全屏下 ESC 先关闭面板，不传递给外层的全屏退出逻辑。

### Claude's Discretion
无 — 所有决策均用户明确选择。

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目规划
- `.planning/ROADMAP.md` — Phase 5 目标、成功标准、依赖关系（依赖 Phase 1）
- `.planning/REQUIREMENTS.md` — SUI-03 需求定义（设置面板在全屏进入/退出时行为规范化）
- `.planning/PROJECT.md` — 项目约束、技术环境

### 全屏架构
- `.planning/phases/01-fullscreen-simplification/01-CONTEXT.md` — Phase 1 决策：WindowService 为 isFullscreen 唯一 owner，ValueNotifier 暴露模式
- `lib/kernel/bridge/window_service.dart` — 全屏状态管理核心，`mode` ValueNotifier，`isFullscreen` getter
- `lib/kernel/bridge/window_bridge.dart` — 抽象接口，4 states + 7 commands
- `lib/kernel/bridge/window_mode.dart` — WindowMode enum (windowed/maximized/fullscreen/minimized)

### 设置面板 UI
- `lib/ui/dialogs/settings_panel.dart` — 主面板，当前 600x480 固定尺寸，topLeft + (80, 48) 定位，showDialog 路由
- `lib/app.dart` — `_showSettingsPanel()` 方法，showDialog 调用入口

### 设计系统
- `lib/ui/theme/tokens.dart` — Tokens.* 设计令牌（颜色、间距、圆角）
- `lib/ui/shared/glass_container.dart` — 毛玻璃容器组件

### 控制层
- `lib/ui/player/player_screen.dart` — ESC 键处理、全屏切换入口
- `lib/ui/player/controls_overlay.dart` — 控制层自动隐藏，`_isFullscreenTransition` 标志

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `WindowService.mode` (ValueNotifier<WindowMode>) — 面板可通过监听此 notifier 感知全屏状态变化
- `WindowService.isFullscreen` — 便捷 getter，直接判断是否全屏
- `AnimatedSlide` / `AnimatedPositioned` — Flutter 内置动画组件，可用于面板平滑重定位
- `MediaQuery.sizeOf(context)` — 获取屏幕尺寸，用于全屏居中计算
- `showDialog` + `barrierColor: transparent` — 现有对话框模式，可复用

### Established Patterns
- ValueNotifier + ValueListenableBuilder — 设置面板已大量使用此模式，全屏状态监听可保持一致
- showDialog 路由 — 设置面板通过 showDialog 打开，全屏状态变化不影响 Navigator 栈
- ESC 键处理 — player_screen.dart 的 KeyboardHandler 已有 ESC 处理逻辑，需要协调

### Integration Points
- `SettingsPanel` 构造函数 — 需要添加 `WindowService` 参数
- `App._showSettingsPanel()` — 需要传递 WindowService 引用
- `SettingsPanel.build()` — 需要根据 isFullscreen 切换定位策略
- `PlayerScreen` 的 ESC 处理 — 需要感知设置面板是否打开

</code_context>

<specifics>
## Specific Ideas

- 全屏下面板居中是核心行为，不是简单的偏移调整，而是切换定位模式（Alignment.topLeft → Alignment.center）
- ESC 键的"先关面板再退全屏"需要在面板和外层之间协调，不能让 ESC 事件穿透
- 退出全屏时的平滑恢复动画与进入全屏时的居中动画应该使用相同的动画曲线和时长

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 5-全屏与设置面板交互规范化*
*Context gathered: 2026-07-13*
