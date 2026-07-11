# Fullscreen Reverse Analysis — 2026-07-11

## Overview

对全屏系统 15 个源文件进行完整逆向分析，发现架构质量优秀但存在 6 个需要修复的问题。

## Architecture Stats

- **Source files:** 15 (lib/)
- **Test files:** 19 (test/)
- **Test count:** ~172
- **Estimated coverage:** ~85-90%

## Issues Found

### BUG-01: F 键快捷键未接线 🔴 CRITICAL

**File:** `lib/ui/player/player_screen.dart` ~line 163-189

`KeyboardHandler` 的 `onToggleFullscreen` 参数从未被 PlayerScreen 传入。F 键按下时 `onToggleFullscreen?.call()` 为 null，无反应。

### BUG-02: isFs 混淆全屏和最大化 🟡 HIGH

**File:** `lib/ui/player/player_screen.dart` ~line 161

`isFs = m.isFullscreen || m.isMaximized` — 最大化窗口也禁用拖拽和改光标。

### BUG-03: setMode 未处理错误 🟡 HIGH

**File:** `lib/ui/player/player_screen.dart` ~line 190-193, 318-319

`setMode()` 返回的 Future 未 await 未 catchError。

### ARCH-01: 抽象泄漏 — is WindowsFullscreenDriver 🟠 MEDIUM

**File:** `lib/kernel/bridge/desktop_fullscreen_adapter.dart`

Adapter 直接检查 `_driver is WindowsFullscreenDriver` 决定快速路径。

### ARCH-02: WindowService 遗留直连 🟠 MEDIUM

**File:** `lib/kernel/bridge/window_service.dart` ~line 298-299, 319-320

`fullScreenWindow.setFullScreen()` 直连调用绕过 FullscreenAdapter。

### ARCH-03: Windows 缺少原生状态回调 🟢 LOW

**File:** `lib/kernel/bridge/platform/windows_fullscreen_driver.dart`

`onNativeStateChanged` setter 空实现，外部状态变化只能轮询检测。

## Test Coverage Gaps

1. BusyTransition 从未被 adapter 测试触发
2. ForcedChange/SyncCorrected 事件路径未覆盖
3. Win32 Display Enumerator 无测试
4. DesktopFullscreenDriver (fallback) 无独立测试

## Recommendations

Priority: BUG-01 → BUG-02 → BUG-03 → ARCH-01 → ARCH-02 → ARCH-03

Added as Phase 8 to ROADMAP.md (2-3 plans, ~6 requirements).

---
*Analysis: 2026-07-11 — 5 Agent parallel exploration*
