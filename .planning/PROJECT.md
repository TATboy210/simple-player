# Simple Player Flutter — Cross-Platform Window Management

## What This Is

将 v1 播放器的窗口管理功能从 Windows-only 重构为跨平台架构，支持 Windows、Linux、macOS 三大桌面平台（x86 + ARM）。

## Core Value

**跨平台窗口管理抽象层** — 保持 WindowBridge 接口不变，底层实现按平台特化，参考 mpv/Kodi/VLC 的成熟方案。

## Current State

### v1 窗口框架（Windows-only）

核心组件：
- **WindowBridge**（抽象接口）：4 状态 ValueNotifier + 6 命令 Future
- **WindowService**（薄协调者）：组合 WindowState + FullscreenController + WindowPersistence
- **FullscreenController**：原子全屏（mutex + save/rollback）
- **WindowPersistence**：防抖持久化（500ms debounce + 写入锁）
- **SettingsStore**：SharedPreferences 持久化（26 个键）
- **C++ 原生层**：Win32 runner（main.cpp/win32_window/flutter_window）

### 已解决的问题

- ✅ 移除 WS_CAPTION + WS_THICKFRAME 全屏方案
- ✅ isOperating Completer 防重入
- ✅ 边框缝隙问题、圆角修复、DPI 自适应
- ✅ 500ms debounce 窗口几何持久化

## Cross-Platform Reference (mpv/Kodi/VLC)

### mpv 方案
- **Windows**：移除 WS_THICKFRAME，保留 WS_OVERLAPPED | WS_MINIMIZEBOX
- **macOS**：borderless + NSApp.presentationOptions，NSCondition 防动画重入
- **Linux X11**：_NET_WM_STATE_FULLSCREEN 属性
- **Linux Wayland**：xdg_toplevel_set_fullscreen

### Kodi 方案
- **Windows**：FULLSCREEN_WINDOW_STYLE 移除 WS_CAPTION，支持独占全屏和窗口全屏
- **macOS**：原生 toggleFullScreen API
- **Linux**：_NET_WM_STATE（X11）/ xdg-shell（Wayland）

### 我们当前方案
- **Windows**：移除 WS_CAPTION + WS_THICKFRAME，isOperating Completer 防重入
- 已解决边框缝隙问题、圆角修复、DPI 自适应

## Architecture

```
lib/
├── kernel/bridge/                 ← 窗口管理层（需要跨平台化）
│   ├── window_bridge.dart         ★ 抽象接口（保持不变）
│   ├── window_service.dart        ★ 薄协调者（需要平台分发）
│   ├── window_state.dart          状态容器（纯 Dart，无需改）
│   ├── window_mode.dart           枚举（纯 Dart，无需改）
│   ├── window_persistence.dart    防抖持久化（纯 Dart，无需改）
│   └── fullscreen_controller.dart 原子全屏（需要平台特化）
│
├── kernel/platform/               ← 新增：平台抽象层
│   ├── platform_window.dart       ★ 平台窗口抽象接口
│   ├── platform_registry.dart     平台实现注册
│   ├── windows/
│   │   └── windows_platform_window.dart  Win32 实现
│   ├── linux/
│   │   └── linux_platform_window.dart    GTK/X11/Wayland 实现
│   └── macos/
│       └── macos_platform_window.dart    NSWindow 实现
│
└── windows/runner/                ← C++ 原生层（需要扩展）
    ├── main.cpp                   Win32 入口
    ├── win32_window.h/cpp         Win32 窗口基类
    └── flutter_window.h/cpp       Flutter 窗口子类
```

## Dependencies

### 当前依赖
- window_manager (0.5.1) — 窗口位置/大小/最大化/最小化/置顶/拖拽
- fvp (0.37.2) — MDK/FFmpeg 播放引擎
- shared_preferences (2.5.5) — 键值对持久化

### 跨平台需要
- window_manager — 继续使用，但需要平台特化补充
- 各平台原生 API（Win32/GTK/Cocoa）— 通过 FFI 或 MethodChannel

## Constraints

- 保持 WindowBridge 抽象接口不变（4 状态 + 6 命令）
- 不可变数据模式（AppSettings copyWith）
- ValueNotifier + ValueListenableBuilder 状态管理
- 80%+ 测试覆盖
- 渐进式迁移，不破坏现有 Windows 功能

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 保持 WindowBridge 接口 | 最小化 UI 层改动 | — Pending |
| 平台抽象层独立于 window_manager | 允许精细控制各平台行为 | — Pending |
| 参考 mpv WS_THICKFRAME 方案 | 成熟方案，已验证 | — Pending |
| macOS 用原生 toggleFullScreen | 最简单可靠 | — Pending |

## Requirements

### Validated

- ✓ 自定义无边框标题栏 (32px) — existing
- ✓ 拖拽标题栏移动窗口 — existing
- ✓ 双击标题栏切换最大化 — existing
- ✓ 最小化/最大化/还原/关闭 — existing
- ✓ 置顶 (Always on Top) — existing
- ✓ 全屏切换（原子 + mutex + 回滚）— existing
- ✓ 窗口几何持久化 — existing
- ✓ DragToResizeArea 窗口边缘拖拽缩放 — existing
- ✓ 圆角窗口 (DWMWCP_ROUND) — existing
- ✓ DPI 自适应 — existing

### Active

- [ ] 跨平台窗口抽象层（PlatformWindow 接口）
- [ ] Windows 平台实现（基于现有代码重构）
- [ ] Linux 平台实现（GTK + X11/Wayland）
- [ ] macOS 平台实现（Cocoa + NSWindow）
- [ ] 跨平台全屏（各平台原生方案）
- [ ] 多显示器支持
- [ ] 平台特化圆角/暗色模式/DPI

### Out of Scope

- 移动端（Android/iOS）— 不同窗口模型
- Web 端 — 无窗口管理概念
- 独占全屏（改分辨率）— 复杂度高，用户需求低
- HDR/色彩管理 — 独立功能

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-06-23 after initialization*
