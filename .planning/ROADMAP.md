# Cross-Platform Window Management — Roadmap

## Overview

**5 phases** | **22 requirements mapped** | All v1 requirements covered ✓

| # | Phase | Goal | Requirements | Success Criteria |
|---|-------|------|--------------|------------------|
| 1 | Platform Abstraction | 定义跨平台窗口接口 + 注册机制 | PLATFORM-01, PLATFORM-02, PLATFORM-03, INT-01 | 3 |
| 2 | Windows Refactor | 基于 PlatformWindow 重构 Windows 实现 | WIN-01~04, INT-02~04 | 4 |
| 3 | Linux Implementation | 实现 Linux 窗口管理（X11 + Wayland） | LINUX-01~05 | 5 |
| 4 | macOS Implementation | 实现 macOS 窗口管理（NSWindow） | MACOS-01~05 | 5 |
| 5 | Multi-Monitor & Polish | 多显示器支持 + 跨平台测试 | MULTI-01~03 | 3 |

---

### Phase 1: Platform Abstraction

**Goal:** 定义跨平台窗口抽象接口，建立平台注册机制，WindowService 通过接口分发命令

**Mode:** mvp

**Requirements:**
- PLATFORM-01: 定义 PlatformWindow 抽象接口
- PLATFORM-02: 平台注册机制（PlatformRegistry）
- PLATFORM-03: WindowService 通过 PlatformWindow 接口分发命令
- INT-01: WindowBridge 接口零改动

**Success Criteria:**
1. PlatformWindow 接口定义完成，包含所有窗口操作方法
2. PlatformRegistry 能根据 Platform.operatingSystem 自动选择正确实现
3. WindowBridge 接口保持不变，UI 层零改动

**Key Files:**
- `lib/kernel/platform/platform_window.dart` — 新建
- `lib/kernel/platform/platform_registry.dart` — 新建
- `lib/kernel/bridge/window_service.dart` — 修改（注入 PlatformWindow）

---

### Phase 2: Windows Refactor

**Goal:** 将现有 Windows 窗口管理代码重构为 PlatformWindow 实现，确保零回归

**Mode:** mvp

**Requirements:**
- WIN-01: 基于现有代码重构 WindowsPlatformWindow
- WIN-02: 保留 isOperating Completer 防重入机制
- WIN-03: 保留圆角修复（DWMWCP_ROUND）
- WIN-04: 保留 DPI 自适应（PerMonitor V1）
- INT-02: WindowState 4 个 ValueNotifier 正常工作
- INT-03: WindowPersistence 防抖持久化跨平台兼容
- INT-04: SettingsStore 读写跨平台兼容

**Success Criteria:**
1. WindowsPlatformWindow 实现 PlatformWindow 接口
2. 现有全屏/最大化/最小化/置顶功能零回归
3. 圆角、DPI、防重入机制正常工作
4. 窗口几何持久化正常工作

**Key Files:**
- `lib/kernel/platform/windows/windows_platform_window.dart` — 新建
- `lib/kernel/bridge/fullscreen_controller.dart` — 修改（使用 PlatformWindow）
- `lib/kernel/bridge/window_persistence.dart` — 验证跨平台兼容

---

### Phase 3: Linux Implementation

**Goal:** 实现 Linux 窗口管理，支持 X11 和 Wayland 两种显示服务器

**Mode:** mvp

**Requirements:**
- LINUX-01: LinuxPlatformWindow 实现（GTK 窗口管理）
- LINUX-02: X11 全屏（_NET_WM_STATE_FULLSCREEN）
- LINUX-03: Wayland 全屏（xdg_toplevel_set_fullscreen）
- LINUX-04: 圆角支持（GTK CSS 或 DRI3）
- LINUX-05: DPI 自适应（GTK scale factor）

**Success Criteria:**
1. LinuxPlatformWindow 实现 PlatformWindow 接口
2. X11 全屏切换正常工作，无边框缝隙
3. Wayland 全屏切换正常工作
4. 圆角和 DPI 自适应正常工作

**Key Files:**
- `lib/kernel/platform/linux/linux_platform_window.dart` — 新建
- `linux/runner/` — 可能需要扩展原生层

---

### Phase 4: macOS Implementation

**Goal:** 实现 macOS 窗口管理，使用 NSWindow 原生 API

**Mode:** mvp

**Requirements:**
- MACOS-01: MacOSPlatformWindow 实现（NSWindow）
- MACOS-02: 原生 toggleFullScreen（NSWindow.toggleFullScreen:）
- MACOS-03: NSCondition 防动画重入
- MACOS-04: 圆角支持（NSWindow.styleMask）
- MACOS-05: DPI 自适应（Retina scale factor）

**Success Criteria:**
1. MacOSPlatformWindow 实现 PlatformWindow 接口
2. 全屏切换使用原生动画，无卡顿
3. 圆角和 DPI 自适应正常工作
4. 防动画重入机制正常工作

**Key Files:**
- `lib/kernel/platform/macos/macos_platform_window.dart` — 新建
- `macos/runner/` — 可能需要扩展原生层

---

### Phase 5: Multi-Monitor & Polish

**Goal:** 实现多显示器支持，完成跨平台测试和文档

**Mode:** mvp

**Requirements:**
- MULTI-01: 获取所有显示器信息（尺寸/位置/DPI）
- MULTI-02: 全屏时指定目标显示器
- MULTI-03: 窗口位置防越界（跨显示器边界）

**Success Criteria:**
1. 能获取所有显示器信息
2. 全屏时能指定目标显示器
3. 窗口位置防越界正常工作

**Key Files:**
- `lib/kernel/platform/platform_window.dart` — 扩展显示器相关方法
- 各平台实现 — 添加显示器枚举和全屏目标指定

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| PLATFORM-01 | 1 | Pending |
| PLATFORM-02 | 1 | Pending |
| PLATFORM-03 | 1 | Pending |
| INT-01 | 1 | Pending |
| WIN-01 | 2 | Pending |
| WIN-02 | 2 | Pending |
| WIN-03 | 2 | Pending |
| WIN-04 | 2 | Pending |
| INT-02 | 2 | Pending |
| INT-03 | 2 | Pending |
| INT-04 | 2 | Pending |
| LINUX-01 | 3 | Pending |
| LINUX-02 | 3 | Pending |
| LINUX-03 | 3 | Pending |
| LINUX-04 | 3 | Pending |
| LINUX-05 | 3 | Pending |
| MACOS-01 | 4 | Pending |
| MACOS-02 | 4 | Pending |
| MACOS-03 | 4 | Pending |
| MACOS-04 | 4 | Pending |
| MACOS-05 | 4 | Pending |
| MULTI-01 | 5 | Pending |
| MULTI-02 | 5 | Pending |
| MULTI-03 | 5 | Pending |

---
*Last updated: 2026-06-23 after initialization*
