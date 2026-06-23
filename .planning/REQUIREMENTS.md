# Cross-Platform Window Management — Requirements

## User Stories

**As a** 播放器用户, **I want** 在 Windows/Linux/macOS 上获得一致的窗口管理体验, **so that** 我可以在任何桌面平台上使用相同的快捷键和窗口操作。

## v1 Requirements

### Platform Abstraction (PLATFORM)

- [ ] **PLATFORM-01**: 定义 PlatformWindow 抽象接口（全屏/最大化/最小化/置顶/拖拽/几何管理）
- [ ] **PLATFORM-02**: 平台注册机制（PlatformRegistry 根据 Platform.operatingSystem 自动选择实现）
- [ ] **PLATFORM-03**: WindowService 通过 PlatformWindow 接口分发命令，不再直接调用 window_manager

### Windows Implementation (WIN)

- [ ] **WIN-01**: 基于现有代码重构 WindowsPlatformWindow（保持 WS_CAPTION+WS_THICKFRAME 全屏方案）
- [ ] **WIN-02**: 保留 isOperating Completer 防重入机制
- [ ] **WIN-03**: 保留圆角修复（DWMWCP_ROUND + snap/maximize 后修复）
- [ ] **WIN-04**: 保留 DPI 自适应（PerMonitor V1）

### Linux Implementation (LINUX)

- [ ] **LINUX-01**: LinuxPlatformWindow 实现（GTK 窗口管理）
- [ ] **LINUX-02**: X11 全屏（_NET_WM_STATE_FULLSCREEN）
- [ ] **LINUX-03**: Wayland 全屏（xdg_toplevel_set_fullscreen）
- [ ] **LINUX-04**: 圆角支持（GTK CSS 或 DRI3）
- [ ] **LINUX-05**: DPI 自适应（GTK scale factor）

### macOS Implementation (MACOS)

- [ ] **MACOS-01**: MacOSPlatformWindow 实现（NSWindow）
- [ ] **MACOS-02**: 原生 toggleFullScreen（NSWindow.toggleFullScreen:）
- [ ] **MACOS-03**: NSCondition 防动画重入（参考 mpv）
- [ ] **MACOS-04**: 圆角支持（NSWindow.styleMask）
- [ ] **MACOS-05**: DPI 自适应（Retina scale factor）

### Multi-Monitor (MULTI)

- [ ] **MULTI-01**: 获取所有显示器信息（尺寸/位置/DPI）
- [ ] **MULTI-02**: 全屏时指定目标显示器
- [ ] **MULTI-03**: 窗口位置防越界（跨显示器边界）

### Integration (INT)

- [ ] **INT-01**: WindowBridge 接口零改动（UI 层无感知）
- [ ] **INT-02**: WindowState 4 个 ValueNotifier 正常工作
- [ ] **INT-03**: WindowPersistence 防抖持久化跨平台兼容
- [ ] **INT-04**: SettingsStore 读写跨平台兼容

## v2 Requirements (Deferred)

- [ ] 独占全屏（改分辨率）— 复杂度高，用户需求低
- [ ] 多显示器黑屏其他屏幕（Kodi BlankOtherDisplays 模式）
- [ ] HDR/色彩管理 — 独立功能
- [ ] 移动端窗口管理 — 不同窗口模型

## Out of Scope

- **Android/iOS** — 移动端无窗口管理概念，使用系统原生行为
- **Web** — 浏览器全屏 API 完全不同
- **独占全屏** — ChangeDisplaySettingsEx 复杂度高，窗口全屏已满足需求

## Acceptance Criteria

1. 在 Windows 上，现有全屏/最大化/最小化/置顶功能零回归
2. 在 Linux (X11) 上，全屏切换正常工作，无边框缝隙
3. 在 Linux (Wayland) 上，全屏切换正常工作
4. 在 macOS 上，全屏切换使用原生动画，无卡顿
5. 所有平台上，窗口几何持久化正常工作
6. 所有平台上，DPI 自适应正常工作
7. WindowBridge 接口零改动，UI 层无需修改

## Definition of Done

- [ ] 所有 PLATFORM-* 需求完成
- [ ] 至少一个平台实现完成（Windows）
- [ ] 单元测试覆盖 ≥ 80%
- [ ] 集成测试覆盖关键路径（全屏切换、窗口几何持久化）
- [ ] 文档更新（README、架构文档）
- [ ] 零回归（现有 Windows 功能正常）

---
*Last updated: 2026-06-23 after initialization*
