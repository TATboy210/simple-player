# Phase 1: Window Shell - Context

**Gathered:** 2026-05-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Stable, flicker-free frameless window with custom title bar, aspect ratio management, fullscreen toggle, and state persistence. This phase delivers the visual container — everything else (video, content, security) sits inside it.

</domain>

<decisions>
## Implementation Decisions

### Title Bar Button Style
- **D-01:** Close 按钮 hover 跟随系统主题色 — 不硬编码红色，使用 `dynamic_color` 包获取系统 accent color
- **D-02:** Hover 状态用 StatefulWidget local state — 每个按钮独立管理 `_isHovered`，不使用全局 ValueNotifier，确保 resize 期间无额外 rebuild
- **D-03:** 图标使用 Windows 11 风格 — CustomPainter 绘制最小化(─)、最大化(□)、关闭(✕)、置顶(📌)
- **D-04:** 按钮尺寸 36×36px — 正方形，和标题栏等高
- **D-05:** Hover 动画简单颜色过渡 — 背景色 150ms ease，无缩放/旋转动效
- **D-06:** 显示 Tooltip — 鼠标悬停 300ms 后显示按钮名称（最小化/最大化/关闭/置顶）
- **D-07:** Pin 按钮在标题栏左侧（app name 旁边） — 和 min/max/close 分开布局

### Claude's Discretion
- 文件结构：WindowManagerService 和 AspectRatioService 放 `lib/kernel/window/`（从 D:\player_flutter 参考项目结构）
- 测试策略：window_manager 难以 mock，优先用抽象接口 + FakeWindowManager 测试逻辑，widget 测试用 `tester.pumpWidget` 验证渲染
- 按钮间距：参考 Win11 原生，按钮之间无间距（紧挨着），Pin 按钮和 app name 之间有 8px 间距

### Folded Todos
None — no todos matched this phase.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Reference Project (D:\player_flutter)
- `D:\player_flutter\lib\kernel\window\window_manager_service.dart` — 516 行单例：500ms debounce 持久化、fullscreen reentry guard、bounds check、safe close
- `D:\player_flutter\lib\kernel\window\aspect_ratio_service.dart` — MethodChannel `com.simple_player/aspect_ratio` 到 native WM_SIZING，ratio cycling
- `D:\player_flutter\lib\kernel\ui\window\custom_title_bar.dart` — 36px 标题栏、GestureDetector (drag + double-tap)、TitleBarControls
- `D:\player_flutter\lib\app.dart` — FvpEngine + Playlist + PlaybackController wiring、aspectRatio listener
- `D:\player_flutter\windows\runner\main.cpp` — C++ runner: frameless first frame prep、forceRedraw channel

### Current Project
- `.planning/PROJECT.md` — 项目上下文、架构决策、约束
- `.planning/REQUIREMENTS.md` — 24 个 v1 需求，WIN-01 到 WIN-15 为本阶段范围
- `.planning/codebase/STACK.md` — 技术栈详情（fvp 0.36.2、window_manager 0.5.1、shared_preferences 2.5.5）
- `.planning/codebase/CONVENTIONS.md` — 编码规范（ValueNotifier 模式、错误处理、命名约定）
- `.planning/codebase/STRUCTURE.md` — 目录结构和模块职责

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/kernel/platform/windows_platform_service.dart` — 已有 WindowsPlatformService，需要扩展为委托到 WindowManagerService
- `lib/kernel/persistence/settings_store.dart` — 已有 SharedPreferences 持久化，可复用存储窗口几何状态
- `lib/kernel/ui/theme/tokens.dart` — 50 个 compile-time const tokens，标题栏应使用 DesignTokens.* 引用
- `lib/main.dart` — 已有 fvp 初始化和 PlatformService 注册流程

### Established Patterns
- ValueNotifier + ValueListenableBuilder — 所有状态管理都用此模式，窗口状态也应遵循
- Singleton pattern — PlatformService.I 使用 factory singleton，WindowManagerService 也应使用相同模式
- Guard clause + try-catch + log.d() — 所有公共方法检查 `_disposed`，用 `on Exception catch (e)` 捕获错误
- 500ms debounce — 参考项目中窗口几何持久化使用 500ms debounce

### Integration Points
- `lib/app.dart` — 需要创建 WindowManagerService 并注入到 app shell
- `lib/main.dart` — 需要在 `main()` 中初始化 WindowManagerService
- `lib/kernel/platform/windows_platform_service.dart` — 需要委托窗口操作到 WindowManagerService

</code_context>

<specifics>
## Specific Ideas

- 用户强调"先把窗口做出来" — 标题栏是首要优先级
- 用户担心 resize 期间按钮重新绘制 — 已通过 D-02 (StatefulWidget local state) 解决
- 用户选择跟随系统主题色而非硬编码红色 — 需要 `dynamic_color` 包支持
- Pin 按钮放左侧，和 min/max/close 分开 — 布局上需要 Row 分两组

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 1-Window Shell*
*Context gathered: 2026-05-09*
