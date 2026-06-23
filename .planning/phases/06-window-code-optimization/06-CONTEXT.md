# Phase 6: Window Code Optimization - Context

**Gathered:** 2026-05-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Window layer小改动优化 — 修复全屏交互问题、标题栏布局、DragToResizeArea 配置、16:9 视频匹配。保持 window_manager 依赖和现有功能不变，仅修复用户反馈的具体问题。

</domain>

<decisions>
## Implementation Decisions

### 全屏功能完善 (D-01 ~ D-03)
- **D-01:** 全屏按钮代码存在但需验证可见性 — `_RightButtonGroup` (control_bar.dart:278-283) 渲染条件 `onToggleFullscreen != null` 已满足。需排查按钮是否被裁剪或遮挡
- **D-02:** 全屏后无法退出 — `AutoHideController` 隐藏控制栏时 `IgnorePointer(ignoring: true)` 阻止点击。需确保鼠标移动时控制栏可靠显示，且全屏退出按钮始终可点击
- **D-03:** 全屏时标题栏仍可见 — `CustomTitleBar` 通过 `windowService.isFullscreen` 控制显隐，需验证 `isFullscreen` ValueNotifier 在全屏切换时正确更新

### DragToResizeArea 配置 (D-04)
- **D-04:** `resizeEdgeSize=11px` 判定区域太小 — app.dart:153 中 `DragToResizeArea(resizeEdgeSize: 11)` 需增大。建议 5-8px（太大会影响内容区域点击）。全屏时需禁用拖拽调整大小

### 标题栏布局层级 (D-05)
- **D-05:** 标题栏不应遮住视频 — 当前 CustomTitleBar 在 Column 中占用 `Tokens.titleBarHeight` 空间，视频在 Expanded 中。全屏时标题栏隐藏。用户确认此布局可接受，只需确保全屏时正确隐藏

### 16:9 视频完美匹配 (D-06)
- **D-06:** 16:9 视频应与 16:9 窗口完美匹配 — 窗口默认 960x540 (16:9)，VideoSurface 使用 `FittedBox` 或 `AspectRatio` 渲染。需验证 16:9 视频无黑边、无裁剪

### Claude's Discretion
- DragToResizeArea 具体数值由 Claude 根据用户体验决定
- 全屏退出的具体交互方案（单击显示控制栏 vs 始终可点击 ESC 退出）由 Claude 决定
- VideoSurface 渲染逻辑优化方案由 Claude 决定

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 窗口管理
- `lib/kernel/bridge/window_service.dart` — WindowService 包装器，4个 ValueNotifier (isFullscreen, isAlwaysOnTop, isMaximized, windowSize)
- `lib/ui/player/custom_title_bar.dart` — 标题栏 UI，全屏隐藏逻辑 (line 25-27)
- `lib/main.dart` — window_manager 初始化 (line 17-29)
- `lib/app.dart` — DragToResizeArea 包裹 (line 152-153)

### 控制栏
- `lib/ui/player/controls_overlay.dart` — AutoHideController 控制显隐，IgnorePointer 逻辑
- `lib/ui/player/control_bar.dart` — _RightButtonGroup 全屏按钮 (line 278-283)
- `lib/ui/player/auto_hide_controller.dart` — 自动隐藏逻辑

### 视频渲染
- `lib/ui/player/video_surface.dart` — Texture 渲染器
- `lib/ui/player/player_screen.dart` — 组合层，WindowService 传递链

### 设计令牌
- `lib/ui/theme/tokens.dart` — titleBarHeight, controlBarHeight, controlBarMarginBottom 等

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `WindowService` — 已有 isFullscreen ValueNotifier，可直接用于条件渲染
- `AutoHideController` — 已处理全屏/非全屏的自动隐藏行为
- `GlassButton.iconOnly` — 全屏按钮已使用此组件

### Established Patterns
- ValueNotifier + ValueListenableBuilder 响应式模式
- WindowListener mixin 接收窗口事件
- DragToResizeArea 包裹整个 Scaffold

### Integration Points
- `main.dart` → window_manager 初始化
- `app.dart` → DragToResizeArea + DeferredPlayerFeature
- `player_screen.dart` → WindowService 传递给 CustomTitleBar 和 ControlsOverlay
- `controls_overlay.dart` → onToggleFullscreen 回调传递给 ControlBar

</code_context>

<specifics>
## Specific Ideas

用户明确要求：
1. "全屏按钮功能需要完善" — 全屏按钮必须可见且可点击
2. "画面占据全屏幕之后无法再次点击按钮无法缩小" — 全屏后必须能退出
3. "画面全屏之后上面的标题还在" — 全屏时标题栏必须隐藏
4. "16比9比例的电影视频应该与16:9比例完美匹配" — 16:9 视频无黑边
5. "窗口优化只需要做小小的改动就行了" — 最小改动，不重构架构

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. WindowService 传递方式优化（InheritedWidget）用户未选择，保持构造函数传递。

</deferred>

---

*Phase: 6-Window Code Optimization*
*Context gathered: 2026-05-29*
