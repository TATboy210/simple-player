# Phase C: 平台适配与深化 - Research

**Researched:** 2026-07-10
**Domain:** Flutter 桌面端三端全屏原生驱动 (Win32 FFI / macOS NSWindow / Linux GTK)
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-P01:** 混合策略 — Windows 自写 FFI 驱动（主路径），macOS/Linux 用 fullscreen_window 插件 + Adapter 叠加层
- **D-P02:** 每平台一个 Driver 文件 + `desktop_fullscreen_driver_factory.dart` 统一创建入口
- **D-P03:** 编译时二选一 — `USE_NEW_FULLSCREEN=true` + `USE_WINDOWS_NATIVE_FULLSCREEN=true`，运行时不混合、不降级、不自动回退
- **D-P04:** Driver 3 方法接口 — `enterFullscreen()` / `leaveFullscreen()` / `queryState()`，恢复逻辑留给 Adapter 层
- **D-P05:** 扩展现有 win32_fullscreen.dart 为 `WindowsFullscreenDriver`，复用已验证的 WS_THICKFRAME 处理逻辑，不重写
- **D-P06:** WS_THICKFRAME 处理 — 进入全屏时剥离 WS_THICKFRAME 样式，退出时恢复
- **D-P07:** 主动焦点恢复 — 退出全屏后 `SetForegroundWindow` + `SetFocus`，安全护栏：只在本应用触发的退出后执行、先判定窗口可见且未最小化、失败只报日志
- **D-P08:** TopMost 残留清理 — 退出全屏时 `SetWindowPos(HWND_NOTOPMOST)` 清理置顶状态
- **D-P09:** macOS 插件 + 回调确认 — fullscreen_window 插件做基础进出，Driver 监听 NSWindow delegate 回调确认后才设 stable，超时 2.5s 报 PlatformFailure
- **D-P10:** macOS 原生全屏动画 — 使用绿色按钮效果，不用无边框绕过
- **D-P11:** 统一确认链 — 回调未到 → 500ms 等待 → 100ms 轮询到 2.5s → 超时按 PlatformFailure + 一次 queryState() 校正
- **D-P12:** Linux 插件 + 三级确认 — fullscreen_window 插件做基础进出，Driver 严格执行三级确认
- **D-P13:** WM 检测 + 文档化 — 运行时检测 WM 类型记录到 platformNotes + 日志，不做逐 WM 特殊处理

### Claude's Discretion
- Driver 内部的 FFI 调用细节（如具体 Win32 API 参数）留给实现阶段
- macOS delegate 回调的具体桥接方式（MethodChannel vs FFI）留给实现阶段
- Linux WM 检测的具体环境变量列表留给实现阶段
- 能力矩阵的具体数值（如超时时间微调）留给实现阶段

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PLAT-01 | Windows — WS_THICKFRAME 样式正确剥离和恢复，焦点恢复，TopMost 残留清理 | Win32 FFI API: SetWindowLong/GWL_STYLE, SetForegroundWindow, SetWindowPos(HWND_NOTOPMOST) |
| PLAT-02 | macOS — 等待系统 fullscreen 生命周期回调确认状态，不乐观更新 | NSWindow delegate: windowDidEnterFullScreen/windowDidExitFullScreen + MethodChannel 回调 |
| PLAT-03 | Linux — GTK/WM 差异下的状态回读与兜底同步 | GTK gtk_window_fullscreen/unfullscreen + GdkWindow state-changed 信号 + 轮询兜底 |
| PLAT-04 | FullscreenCapability 查询每平台支持的能力 | 每平台 driver 的 capabilities() 返回真实值，运行时 WM 检测 |
</phase_requirements>

## Summary

Phase C 的核心任务是将 Phase A/B 建立的 `FullscreenAdapter` → `FullscreenCommandQueue` → `FullscreenDriver` 架构在 Windows/macOS/Linux 三端落地为生产级实现。

**Windows 端**已有坚实基础：`win32_display_enumerator.dart` 展示了完整的 Win32 FFI 模式（`DynamicLibrary.open('user32.dll')` + `lookupFunction` + `NativeCallable.isolateLocal`），`fullscreen_window_plugin.cpp` 的 C++ 实现已验证 WS_THICKFRAME 剥离方案。Phase C 只需将 C++ 逻辑移植到 Dart FFI 层，扩展为 `WindowsFullscreenDriver`，额外处理焦点恢复和 TopMost 清理。

**macOS 端**的 fullscreen_window 插件使用 `[window toggleFullScreen:nil]` 触发系统原生全屏动画。关键挑战是状态确认：`toggleFullScreen` 是异步的，动画完成后系统调用 `windowDidEnterFullScreen:` delegate 方法。Phase C 需要在 Dart 端监听此回调（通过 MethodChannel 或 NSNotification），实现三级确认链。

**Linux 端**的 fullscreen_window 插件使用 `gtk_window_fullscreen()` / `gtk_window_unfullscreen()`。GTK 的 `GdkWindow` 会发出 `state-changed` 信号，但不同 WM（GNOME/KDE/XFCE）对全屏状态的报告时机和可靠性差异较大。Phase C 采用三级确认（回调→轮询→超时）+ WM 类型检测文档化的务实策略。

**Primary recommendation:** 三个平台 driver 各自独立实现，共享 Phase B 的 `FullscreenDriver` 接口和三级确认策略。Windows 走 FFI 直通路径（最高可靠性），macOS/Linux 走插件 + 回调确认路径（覆盖 WM 差异）。

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Windows 全屏进出 | Win32 FFI (Dart) | — | 已有 FFI 基础设施，不依赖 C++ 插件层 |
| macOS 全屏进出 | fullscreen_window 插件 (ObjC) | NSWindow delegate 回调 | 原生 toggleFullScreen 需要 Cocoa 运行时 |
| Linux 全屏进出 | fullscreen_window 插件 (GTK) | GdkWindow state-changed | GTK API 需要 GLib 事件循环 |
| 状态确认 (三端) | Dart (DesktopFullscreenAdapter) | — | 三级确认逻辑在 Adapter 层统一 |
| 焦点恢复 | Win32 FFI (Dart) | — | Windows 特有需求，SetForegroundWindow |
| TopMost 清理 | Win32 FFI (Dart) | — | Windows 特有需求，HWND_NOTOPMOST |
| WM 检测 | Dart (环境变量读取) | — | 运行时检测，记录到 platformNotes |
| 能力查询 | Dart (每平台 Driver) | — | capabilities() 在 Driver 层实现 |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| dart:ffi | SDK | Win32 FFI 调用 | 项目已深度使用 (win32_display_enumerator.dart) |
| package:ffi | SDK | UTF-16 字符串转换 + calloc 内存管理 | 项目已集成，与 dart:ffi 配套 |
| fullscreen_window | local package | macOS/Linux 原生全屏 | 项目本地包，已有三端实现 |
| window_manager | 0.5.0 (locked) | 跨平台窗口管理 API | 项目已集成，queryFullscreen 等辅助查询 |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| dart:async | SDK | Completer, Timer, StreamController | 三级确认链的超时和轮询 |
| dart:ui | SDK | Offset, Size | 窗口几何操作 |
| PlatformDispatcher | SDK | devicePixelRatio | Win32 物理像素→逻辑像素转换 |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Dart FFI 直调 user32.dll | win32 包 | 用户已确认 win32 包导致全屏一帧卡顿 (anti_pattern_fullscreen_ffi.md) |
| fullscreen_window 插件 (macOS) | 自写 FFI 调 NSWindow | ObjC runtime FFI 复杂度极高，插件已验证 |
| GTK state-changed 信号 (Linux) | 仅轮询 | 信号是主路径，轮询是兜底；纯轮询延迟过高 |

**Installation:**
```bash
# 无新依赖 — 所有所需库已集成
flutter pub get
```

## Package Legitimacy Audit

> Phase C 不安装新外部包。所有依赖已在项目中验证。

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| window_manager | npm/n/a | 3+ yrs | 500K+ pub.dev | github.com/leanflutter/window_manager | [VERIFIED: pub.dev] | Already integrated |
| fullscreen_window | local | — | — | local package | [VERIFIED: codebase] | Already integrated |
| ffi | SDK | — | — | dart-lang/sdk | [VERIFIED: SDK] | Built-in |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
用户按键 (F) / UI 按钮
    │
    ▼
FullscreenAdapter.toggle() / .setFullscreen()
    │
    ▼
FullscreenCommandQueue.enqueue(request)    ← Phase B: per-windowId 串行化 + 合并
    │
    ▼
DesktopFullscreenAdapter._executeCommand()
    │
    ├── snapshot.phase = entering/leaving
    ├── _captureRestoreSnapshot() (enter only)
    │
    ▼
FullscreenDriver.enterFullscreen() / .leaveFullscreen()
    │
    ├── Windows: WindowsFullscreenDriver
    │   ├── FFI: SetWindowLong(GWL_STYLE) 剥离 WS_THICKFRAME
    │   ├── FFI: SetWindowPos(SWP_FRAMECHANGED) 触发重绘
    │   └── FFI: SetForegroundWindow + SetFocus (退出时)
    │
    ├── macOS: MacosFullscreenDriver
    │   ├── MethodChannel → [window toggleFullScreen:nil]
    │   └── NSWindow delegate 回调 → MethodChannel → Dart
    │
    └── Linux: LinuxFullscreenDriver
        ├── MethodChannel → gtk_window_fullscreen()
        └── GdkWindow state-changed → MethodChannel → Dart
    │
    ▼
DesktopFullscreenAdapter._waitForConfirmation()    ← 三级确认链
    │
    ├── Level 1: 原生回调确认 (500ms timeout)
    ├── Level 2: driver.queryFullscreen() 轮询 (100ms × 20 = 2s)
    └── Level 3: 超时 → StateDesync + queryState() 校正
    │
    ▼
snapshot 更新 (stable + effectiveMode) + events 广播
```

### Recommended Project Structure

```
lib/kernel/bridge/
├── fullscreen_adapter.dart              # 抽象接口 (Phase A 已有)
├── fullscreen_command_queue.dart        # 命令队列 (Phase B 已有)
├── fullscreen_driver.dart               # Driver 抽象接口 (Phase B 已有)
├── desktop_fullscreen_adapter.dart      # Adapter 实现 (Phase B 已有)
├── desktop_fullscreen_driver.dart       # 默认 window_manager 驱动 (Phase B 已有)
├── platform/                            # Phase C: 平台特定驱动
│   ├── windows_fullscreen_driver.dart   # Win32 FFI 驱动
│   ├── macos_fullscreen_driver.dart     # macOS 原生驱动
│   └── linux_fullscreen_driver.dart     # Linux GTK 驱动
├── desktop_fullscreen_driver_factory.dart  # 工厂: Platform.isXXX → 具体 Driver
├── win32/
│   ├── win32_display_enumerator.dart    # 已有: 显示器枚举 FFI
│   └── win32_fullscreen_ffi.dart        # 新: Win32 全屏 FFI 绑定
└── window_service.dart                  # 已有: 委托给 FullscreenAdapter
```

### Pattern 1: WindowsFullscreenDriver — Win32 FFI 全屏

**What:** 通过 Dart FFI 直调 user32.dll 实现 WS_THICKFRAME 样式操作、焦点恢复和 TopMost 清理。

**When to use:** `Platform.isWindows` + `USE_WINDOWS_NATIVE_FULLSCREEN=true`。

**关键 API 调用链:**

```dart
// 进入全屏:
// 1. 保存当前窗口样式和位置 (D-06 前快照)
final style = GetWindowLong(hwnd, GWL_STYLE);
final exStyle = GetWindowLong(hwnd, GWL_EXSTYLE);
GetWindowPlacement(hwnd, placementPtr);

// 2. 剥离 WS_THICKFRAME + WS_CAPTION (D-06: 解决 7px 缝隙)
SetWindowLong(hwnd, GWL_STYLE, style & ~(WS_CAPTION | WS_THICKFRAME));

// 3. 设置 WS_EX_TOPMOST
SetWindowLong(hwnd, GWL_EXSTYLE, exStyle | WS_EX_TOPMOST);

// 4. 覆盖整个显示器区域
final monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
GetMonitorInfoW(monitor, monitorInfoPtr);
final rc = monitorInfo.rcMonitor;
SetWindowPos(hwnd, HWND_TOPMOST, rc.left, rc.top,
    rc.right - rc.left, rc.bottom - rc.top,
    SWP_NOOWNERZORDER | SWP_FRAMECHANGED);

// 退出全屏:
// 1. 恢复窗口样式 (D-06)
SetWindowLong(hwnd, GWL_STYLE, savedStyle);
SetWindowLong(hwnd, GWL_EXSTYLE, savedExStyle);

// 2. 清理 TopMost (D-08)
SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0,
    SWP_NOMOVE | SWP_NOSIZE | SWP_NOOWNERZORDER | SWP_FRAMECHANGED);

// 3. 恢复窗口位置
SetWindowPlacement(hwnd, savedPlacement);

// 4. 焦点恢复 (D-07)
if (IsWindowVisible(hwnd) && !IsIconic(hwnd)) {
    SetForegroundWindow(hwnd);
    SetFocus(hwnd);
}
```

**与现有 fullscreen_window_plugin.cpp 的差异:**

| Aspect | fullscreen_window_plugin.cpp | WindowsFullscreenDriver (Dart FFI) |
|--------|------------------------------|-------------------------------------|
| 语言 | C++ | Dart FFI |
| 全屏方式 | SC_MAXIMIZE 消息 | SetWindowPos 直接设置几何 |
| WS_THICKFRAME | 剥离 (已解决 7px) | 剥离 (复用逻辑) |
| 焦点恢复 | 无 | SetForegroundWindow + SetFocus |
| TopMost 清理 | 无 (保留 WS_EX_TOPMOST) | SetWindowPos(HWND_NOTOPMOST) |
| 状态查询 | 无 | IsZoomed + 样式检查 |
| 显示器信息 | 无 | MonitorFromWindow + GetMonitorInfoW |

**Source:** 参考 `packages/fullscreen_window/windows/fullscreen_window_plugin.cpp` 第 25-57 行的 `setFullScreen()` 函数，以及 `lib/kernel/bridge/win32/win32_display_enumerator.dart` 的 FFI 模式。

### Pattern 2: MacosFullscreenDriver — macOS 原生全屏

**What:** 通过 fullscreen_window 插件触发 `[window toggleFullScreen:nil]`，监听 NSWindow delegate 回调确认状态。

**When to use:** `Platform.isMacOS`。

**回调确认架构:**

```
macOS 原生层                           Dart 层
─────────────                          ────────
[window toggleFullScreen:nil]
    │
    ▼ (系统动画 ~0.7s)
windowDidEnterFullScreen:
    │
    ▼
FlutterMethodChannel → "onFullScreenChanged"
    │
    ▼
MacosFullscreenDriver._onNativeCallback()
    │
    ▼
DesktopFullscreenAdapter.onNativeFullScreenChanged()
    │
    ▼
_confirmByWindowId[windowId].complete(true)
```

**NSWindow delegate 回调桥接方案:**

macOS fullscreen_window 插件当前只暴露 `setFullScreen(bool)` 方法，没有回调。Phase C 需要扩展插件以支持状态回调。

方案 A (推荐): 在 fullscreen_window 的 macOS 实现中添加 `NSWindowDelegate` 方法:
```objc
// FullscreenWindowPlugin.m 中实现 delegate 方法
- (void)windowDidEnterFullScreen:(NSNotification *)notification {
    [_channel invokeMethod:@"onFullScreenChanged" arguments:@{@@"isFullScreen": @YES}];
}

- (void)windowDidExitFullScreen:(NSNotification *)notification {
    [_channel invokeMethod:@"onFullScreenChanged" arguments:@{@@"isFullScreen": @NO}];
}
```

Dart 端在 `MacosFullscreenDriver` 中设置 MethodCallHandler 接收回调。

方案 B (降级): 不修改插件，依赖三级确认链的 Level 2 轮询。可靠性略低但无需改插件代码。

**macOS 特有注意事项:**
- `toggleFullScreen:` 是异步动画，约 0.7s 完成
- 动画期间窗口处于 "transitioning" 状态，`styleMask & NSWindowStyleMaskFullScreen` 不可靠
- 用户可通过系统快捷键 (Ctrl+Cmd+F) 或绿色按钮触发全屏，产生 ForcedChange 事件
- macOS 全屏会创建新的 Space，窗口在 Mission Control 中独立显示

**Source:** `packages/fullscreen_window/macos/Classes/FullscreenWindowPlugin.m` — 当前实现 43 行，仅 `toggleFullScreen:` + `getScreenSize`。

### Pattern 3: LinuxFullscreenDriver — Linux GTK 全屏

**What:** 通过 fullscreen_window 插件调用 `gtk_window_fullscreen()`，监听 GdkWindow state-changed 信号确认状态。

**When to use:** `Platform.isLinux`。

**GTK 全屏状态确认:**

```c
// fullscreen_window_plugin.cc 中添加信号监听
g_signal_connect(G_OBJECT(window), "window-state-event",
    G_CALLBACK(on_window_state_changed), plugin);

static gboolean on_window_state_changed(GtkWidget *widget,
    GdkEventWindowState *event, gpointer user_data) {
    if (event->changed_mask & GDK_WINDOW_STATE_FULLSCREEN) {
        gboolean is_fullscreen = event->new_window_state & GDK_WINDOW_STATE_FULLSCREEN;
        // 通过 MethodChannel 通知 Dart 层
        g_autoptr(FlValue) args = fl_value_new_map();
        fl_value_set_string_take(args, "isFullScreen",
            fl_value_new_bool(is_fullscreen));
        fl_method_channel_invoke_method(channel, "onFullScreenChanged", args,
            NULL, NULL, NULL);
    }
    return FALSE;
}
```

**Linux WM 差异性分析:**

| WM | 全屏回调可靠性 | 已知问题 |
|----|--------------|----------|
| GNOME (Mutter) | HIGH | 标准 EWMH，回调及时 |
| KDE (KWin) | HIGH | 标准 EWMH，回调及时 |
| XFCE (Xfwm) | MEDIUM | 偶有延迟，轮询兜底有效 |
| Sway (Wayland) | MEDIUM | wl_shell 全屏语义不同，需测试 |
| i3 (X11) | LOW | 手动平铺 WM，全屏行为非标准 |
| Hyprland | MEDIUM | Wayland，支持 wlr-layer-shell |

**WM 检测方案:**

```dart
/// 检测当前窗口管理器类型，记录到 platformNotes。
String _detectWindowManager() {
  // XDG_SESSION_TYPE: "x11" 或 "wayland"
  final sessionType = Platform.environment['XDG_SESSION_TYPE'] ?? 'unknown';

  // 桌面环境检测
  final desktop = Platform.environment['XDG_CURRENT_DESKTOP'] ?? '';
  final wmName = Platform.environment['GDMSESSION'] ?? '';

  return 'session=$sessionType, desktop=$desktop, wm=$wmName';
}
```

**Source:** `packages/fullscreen_window/linux/fullscreen_window_plugin.cc` — 当前实现 112 行，使用 `gtk_window_fullscreen()` / `gtk_window_unfullscreen()`。

### Anti-Patterns to Avoid

- **win32 包依赖:** 用户已确认导致全屏一帧卡顿。必须使用 dart:ffi 直调 user32.dll (anti_pattern_fullscreen_ffi.md)
- **乐观状态更新:** 不等回调就设 stable — macOS/Linux 动画期间状态不可靠
- **单一确认路径:** 只靠回调或只靠轮询 — 不同 WM 回调可靠性不同，必须三级确认
- **C++ 层过重逻辑:** fullscreen_window 插件应保持薄封装，复杂逻辑在 Dart 层

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Win32 API 调用 | 手写 FFI typedef | 参考 win32_display_enumerator.dart 模式 | 已有验证的 FFI 模式 (DynamicLibrary.open + lookupFunction) |
| 显示器信息获取 | 自写 EnumDisplayMonitors | Win32DisplayEnumerator 已实现 | 副屏恢复直接复用 |
| macOS 全屏动画 | 自写 NSWindow 操作 | fullscreen_window 插件 toggleFullScreen: | Cocoa runtime 复杂，插件已验证 |
| Linux 全屏 | 自写 GTK 调用 | fullscreen_window 插件 gtk_window_fullscreen() | 需要 GLib 事件循环集成 |
| 状态确认链 | 自写确认逻辑 | DesktopFullscreenAdapter._waitForConfirmation() | Phase B 已实现三级确认 |

**Key insight:** Phase C 的核心工作是"平台原生调用"层，不是"状态管理/命令队列"层。后者已在 Phase B 完成。

## Common Pitfalls

### Pitfall 1: WS_THICKFRAME 剥离后 Flutter 布局不刷新
**What goes wrong:** SetWindowLong 修改样式后，Flutter 引擎不知道窗口边界变了，布局仍然按旧尺寸计算。
**Why it happens:** Flutter 引擎缓存了窗口尺寸，仅修改 Win32 样式不触发 Flutter 侧 resize 事件。
**How to avoid:** 调用 `SetWindowPos(hwnd, 0, ..., SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED)` 强制触发 WM_SIZE 消息。fullscreen_window_plugin.cpp 第 55 行已有此模式。
**Warning signs:** 全屏后内容仍按窗口尺寸渲染，四周有黑边或裁剪。

### Pitfall 2: macOS toggleFullScreen: 动画期间查询状态
**What goes wrong:** 在 `toggleFullScreen:` 调用后立即查询 `styleMask & NSWindowStyleMaskFullScreen`，返回旧状态。
**Why it happens:** 全屏动画约 0.7s，动画期间 styleMask 处于中间态。
**How to avoid:** 不查询 styleMask，等待 `windowDidEnterFullScreen:` delegate 回调。三级确认链的 Level 1 就是为此设计的。
**Warning signs:** macOS 全屏后 snapshot 显示 windowed（状态不一致）。

### Pitfall 3: Linux 不同 WM 的全屏语义差异
**What goes wrong:** 在 i3/Sway 等平铺 WM 中，`gtk_window_fullscreen()` 行为与 GNOME/KDE 不同 — 可能不触发 window-state-event 信号。
**Why it happens:** 平铺 WM 自行管理窗口布局，GTK 的全屏请求可能被 WM 忽略或延迟处理。
**How to avoid:** 三级确认链的 Level 2 轮询兜底。如果 2.5s 内仍未确认，按 StateDesync 处理。WM 类型记录到 platformNotes 用于诊断。
**Warning signs:** Linux 全屏操作"无反应"或延迟 2s+ 才生效。

### Pitfall 4: 焦点恢复导致窗口闪烁
**What goes wrong:** 退出全屏后立即调用 `SetForegroundWindow`，窗口在恢复过程中闪烁。
**Why it happens:** 窗口样式和位置恢复需要多步 Win32 调用，焦点切换在中间态发生。
**How to avoid:** 先完成所有样式恢复（SetWindowLong + SetWindowPlacement），最后再调用焦点恢复。且只在窗口可见且未最小化时执行 (D-07 安全护栏)。
**Warning signs:** 退出全屏时窗口短暂闪烁或跳动。

### Pitfall 5: TopMost 残留导致窗口始终置顶
**What goes wrong:** 退出全屏后窗口仍然在所有窗口之上。
**Why it happens:** 进入全屏时设置了 `WS_EX_TOPMOST`，退出时没有清理。
**How to avoid:** 退出全屏时 `SetWindowPos(hwnd, HWND_NOTOPMOST, ...)` 显式清理 (D-08)。
**Warning signs:** 退出全屏后播放器窗口覆盖其他应用窗口。

## Code Examples

### Win32 FFI 绑定定义

```dart
// Source: 参考 lib/kernel/bridge/win32/win32_display_enumerator.dart 模式
import 'dart:ffi';
import 'package:ffi/ffi.dart';

// ─── Win32 常量 ───
const int _gwlStyle = -16;
const int _gwlExStyle = -20;
const int _wsCaption = 0x00C00000;
const int _wsThickframe = 0x00040000;
const int _wsExTopmost = 0x00000008;
const int _hwndTopmost = -1;
const int _hwndNotopmost = -2;
const int _swpNomove = 0x0002;
const int _swpNosize = 0x0001;
const int _swpNoownerzorder = 0x0200;
const int _swpFramechanged = 0x0020;
const int _monitorDefaultToNearest = 2;

// ─── Win32 结构体 ───
final class _RECT extends Struct {
  @Int32()
  external int left;
  @Int32()
  external int top;
  @Int32()
  external int right;
  @Int32()
  external int bottom;
}

final class _WINDOWPLACEMENT extends Struct {
  @Uint32()
  external int length;
  @Uint32()
  external int flags;
  @Uint32()
  external int showCmd;
  external _POINT ptMinPosition;
  external _POINT ptMaxPosition;
  external _RECT rcNormalPosition;
}

final class _POINT extends Struct {
  @Int32()
  external int x;
  @Int32()
  external int y;
}

// ─── Win32 函数签名 ───
typedef _GetWindowLongNative = Int32 Function(IntPtr hWnd, Int32 nIndex);
typedef _GetWindowLongDart = int Function(int hWnd, int nIndex);

typedef _SetWindowLongNative = Int32 Function(IntPtr hWnd, Int32 nIndex, Int32 dwNewLong);
typedef _SetWindowLongDart = int Function(int hWnd, int nIndex, int dwNewLong);

typedef _SetWindowPosNative = Int32 Function(
    IntPtr hWnd, IntPtr hWndInsertAfter, Int32 X, Int32 Y,
    Int32 cx, Int32 cy, Uint32 uFlags);
typedef _SetWindowPosDart = int Function(
    int hWnd, int hWndInsertAfter, int X, int Y,
    int cx, int cy, int uFlags);

typedef _SetForegroundWindowNative = Int32 Function(IntPtr hWnd);
typedef _SetForegroundWindowDart = int Function(int hWnd);

typedef _SetFocusNative = IntPtr Function(IntPtr hWnd);
typedef _SetFocusDart = int Function(int hWnd);

typedef _IsWindowVisibleNative = Int32 Function(IntPtr hWnd);
typedef _IsWindowVisibleDart = int Function(int hWnd);

typedef _IsIconicNative = Int32 Function(IntPtr hWnd);
typedef _IsIconicDart = int Function(int hWnd);

typedef _MonitorFromWindowNative = IntPtr Function(IntPtr hwnd, Uint32 dwFlags);
typedef _MonitorFromWindowDart = int Function(int hwnd, int dwFlags);

// ─── DLL 加载 ───
final DynamicLibrary _user32 = DynamicLibrary.open('user32.dll');

final _GetWindowLongDart _getWindowLong = _user32
    .lookupFunction<_GetWindowLongNative, _GetWindowLongDart>('GetWindowLongW');

final _SetWindowLongDart _setWindowLong = _user32
    .lookupFunction<_SetWindowLongNative, _SetWindowLongDart>('SetWindowLongW');

final _SetWindowPosDart _setWindowPos = _user32
    .lookupFunction<_SetWindowPosNative, _SetWindowPosDart>('SetWindowPos');

final _SetForegroundWindowDart _setForegroundWindow = _user32
    .lookupFunction<_SetForegroundWindowNative, _SetForegroundWindowDart>(
        'SetForegroundWindow');

final _SetFocusDart _setFocus = _user32
    .lookupFunction<_SetFocusNative, _SetFocusDart>('SetFocus');

final _IsWindowVisibleDart _isWindowVisible = _user32
    .lookupFunction<_IsWindowVisibleNative, _IsWindowVisibleDart>('IsWindowVisible');

final _IsIconicDart _isIconic = _user32
    .lookupFunction<_IsIconicNative, _IsIconicDart>('IsIconic');

final _MonitorFromWindowDart _monitorFromWindow = _user32
    .lookupFunction<_MonitorFromWindowNative, _MonitorFromWindowDart>(
        'MonitorFromWindow');
```

### WindowsFullscreenDriver 核心方法

```dart
/// Windows 原生全屏驱动 — Win32 FFI 直调。
///
/// 复用 fullscreen_window_plugin.cpp 的 WS_THICKFRAME 剥离逻辑 (D-05)，
/// 增加焦点恢复 (D-07) 和 TopMost 清理 (D-08)。
class WindowsFullscreenDriver implements FullscreenDriver {
  WindowsFullscreenDriver();

  /// 保存的窗口样式 — 进入全屏前快照。
  int _savedStyle = 0;
  int _savedExStyle = 0;
  bool _isFullscreen = false;

  @override
  Future<void> enterFullscreen({int displayId = 0}) async {
    final hwnd = _getFlutterHwnd();
    if (hwnd == 0) return;

    // 保存当前样式 (D-06 前快照)
    _savedStyle = _getWindowLong(hwnd, _gwlStyle);
    _savedExStyle = _getWindowLong(hwnd, _gwlExStyle);

    // 剥离 WS_THICKFRAME + WS_CAPTION (D-06: 解决 7px 缝隙)
    _setWindowLong(hwnd, _gwlStyle,
        _savedStyle & ~(_wsCaption | _wsThickframe));

    // 设置 WS_EX_TOPMOST
    _setWindowLong(hwnd, _gwlExStyle,
        _savedExStyle | _wsExTopmost);

    // 覆盖整个显示器区域
    final monitor = _monitorFromWindow(hwnd, _monitorDefaultToNearest);
    final rect = _getMonitorRect(monitor);
    _setWindowPos(
      hwnd, _hwndTopmost,
      rect.left, rect.top,
      rect.right - rect.left, rect.bottom - rect.top,
      _swpNoownerzorder | _swpFramechanged,
    );

    _isFullscreen = true;
  }

  @override
  Future<void> leaveFullscreen() async {
    final hwnd = _getFlutterHwnd();
    if (hwnd == 0) return;

    // 恢复窗口样式 (D-06)
    _setWindowLong(hwnd, _gwlStyle, _savedStyle);
    _setWindowLong(hwnd, _gwlExStyle, _savedExStyle);

    // 清理 TopMost (D-08)
    _setWindowPos(
      hwnd, _hwndNotopmost,
      0, 0, 0, 0,
      _swpNomove | _swpNosize | _swpNoownerzorder | _swpFramechanged,
    );

    // 恢复窗口位置
    _restoreWindowPlacement(hwnd);

    // 焦点恢复 (D-07): 安全护栏
    if (_isWindowVisible(hwnd) && !_isIconic(hwnd)) {
      _setForegroundWindow(hwnd);
      _setFocus(hwnd);
    }

    _isFullscreen = false;
  }

  @override
  Future<bool> queryFullscreen() async {
    return _isFullscreen;
  }
}
```

### FullscreenDriverFactory 工厂

```dart
/// 平台驱动工厂 — 根据 Platform.isXXX 选择具体 Driver (D-P02)。
///
/// 编译时 flag 控制是否启用新驱动:
/// - USE_NEW_FULLSCREEN=true: 使用 FullscreenAdapter 体系
/// - USE_WINDOWS_NATIVE_FULLSCREEN=true: Windows 使用 FFI 驱动
class FullscreenDriverFactory {
  /// 创建当前平台的 FullscreenDriver。
  ///
  /// Windows: WindowsFullscreenDriver (FFI) 或 DesktopFullscreenDriver (window_manager)
  /// macOS: MacosFullscreenDriver (fullscreen_window 插件 + delegate 回调)
  /// Linux: LinuxFullscreenDriver (fullscreen_window 插件 + state-changed 信号)
  static FullscreenDriver create() {
    if (Platform.isWindows) {
      // D-P03: USE_WINDOWS_NATIVE_FULLSCREEN 控制 Windows 驱动选择
      const useNative = bool.fromEnvironment(
        'USE_WINDOWS_NATIVE_FULLSCREEN',
        defaultValue: false,
      );
      if (useNative) {
        return WindowsFullscreenDriver();
      }
      return DesktopFullscreenDriver(); // fallback: window_manager
    }

    if (Platform.isMacOS) {
      return MacosFullscreenDriver();
    }

    if (Platform.isLinux) {
      return LinuxFullscreenDriver();
    }

    // 未知平台: 降级到 window_manager
    return DesktopFullscreenDriver();
  }
}
```

### FullscreenCapability 每平台返回值

```dart
// WindowsFullscreenDriver.capabilities()
const FullscreenCapability(
  supportsFullscreen: true,
  supportsMultiWindow: false,    // v2: per-window 需要独立 HWND
  supportsMultiDisplay: true,    // MonitorFromWindow + GetMonitorInfoW
  supportsExclusive: false,      // v2: 独占全屏预留
  requiresUserGesture: false,
  platformNotes: 'Win32 FFI: WS_THICKFRAME removal, focus recovery, TopMost cleanup',
);

// MacosFullscreenDriver.capabilities()
const FullscreenCapability(
  supportsFullscreen: true,
  supportsMultiWindow: false,    // macOS 全屏创建独立 Space
  supportsMultiDisplay: true,    // 系统处理多显示器
  supportsExclusive: false,      // macOS 无独占全屏概念
  requiresUserGesture: false,
  platformNotes: 'Native macOS fullscreen animation (green button). '
      'Confirmation via NSWindow delegate callback. '
      'Transition time ~700ms.',
);

// LinuxFullscreenDriver.capabilities()
FullscreenCapability(
  supportsFullscreen: true,
  supportsMultiWindow: false,
  supportsMultiDisplay: true,    // GTK 处理多显示器
  supportsExclusive: false,
  requiresUserGesture: false,
  platformNotes: 'GTK fullscreen via fullscreen_window plugin. '
      'WM: ${_detectWindowManager()}. '
      'Three-tier confirmation (callback → poll → timeout). '
      'Tiling WMs (i3, Sway) may have non-standard behavior.',
);
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| fullscreen_window C++ 直接调用 | Dart FFI 直调 user32.dll | Phase C (本阶段) | 焦点恢复 + TopMost 清理 + 状态查询 |
| window_manager setFullScreen (跨平台) | 平台特定 Driver | Phase C (本阶段) | 每端取最优方案，不强制统一 |
| 无状态确认 (乐观更新) | 三级确认链 | Phase B (已完成) | macOS/Linux 动画延迟不再导致状态错位 |
| WindowService 直调插件 | FullscreenAdapter → Queue → Driver | Phase A+B (已完成) | 命令串行化 + 状态回读 + 错误模型 |

**Deprecated/outdated:**
- `DesktopFullscreenDriver` (window_manager 包装): Phase C 后仅作为 fallback，不再是主路径
- fullscreen_window 插件的 Windows 实现 (C++): 被 WindowsFullscreenDriver (Dart FFI) 替代

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | macOS fullscreen_window 插件可以通过添加 NSWindowDelegate 接收回调 | Pattern 2 | 需要修改 ObjC 插件代码，增加约 30 行。如果不修改，降级到轮询确认 |
| A2 | Linux fullscreen_window 插件可以通过 g_signal_connect(window-state-event) 接收状态变化 | Pattern 3 | 需要修改 C++ 插件代码。如果不修改，降级到轮询确认 |
| A3 | Win32 SetWindowPos + SWP_FRAMECHANGED 会触发 Flutter 引擎的 resize 事件 | Pitfall 1 | 已在 fullscreen_window_plugin.cpp 验证 (第 55 行) |
| A4 | macOS 全屏动画时间约 0.7s | Pattern 2 | 影响 Level 1 超时设置，500ms 可能不够。三级确认链已有 Level 2 兜底 |
| A5 | Linux XDG_CURRENT_DESKTOP 环境变量在主流发行版上可靠 | Pattern 3 | 不可靠时 platformNotes 为空，不影响功能 |

## Open Questions

1. **macOS delegate 回调桥接方式**
   - What we know: fullscreen_window 插件当前无回调，需要扩展
   - What's unclear: 是修改插件添加 delegate (方案 A) 还是不改插件仅靠轮询 (方案 B)
   - Recommendation: 优先方案 A (修改插件)，代码量小 (~30 行 ObjC)，可靠性高

2. **Linux window-state-event 信号在 Wayland 下的行为**
   - What we know: X11 下 GdkWindow state-changed 信号可靠
   - What's unclear: Wayland (GNOME/KDE Wayland session) 下信号是否同样触发
   - Recommendation: 三级确认链的 Level 2 轮询兜底，Wayland 行为差异通过 platformNotes 记录

3. **Win32 FindWindowW 的 Flutter 窗口类名**
   - What we know: `FLUTTER_RUNNER_WIN32_WINDOW` 是 Flutter 注册的窗口类名 (win32_display_enumerator.dart 第 226 行)
   - What's unclear: 不同 Flutter 版本是否变更此类名
   - Recommendation: 使用已验证的常量，如果 FindWindow 失败降级到 window_manager

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| user32.dll | WindowsFullscreenDriver | ✓ | Windows 11 | — |
| Flutter SDK | 全部 | ✓ | 3.x | — |
| window_manager | DesktopFullscreenDriver (fallback) | ✓ | 0.5.0 (locked) | — |
| fullscreen_window | macOS/Linux Driver | ✓ | local package | — |
| dart:ffi + package:ffi | Win32 FFI | ✓ | SDK | — |

**Missing dependencies with no fallback:** none
**Missing dependencies with fallback:** none

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) |
| Quick run | `flutter test test/platform/` |
| Full suite | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command |
|--------|----------|-----------|-------------------|
| PLAT-01 | Windows WS_THICKFRAME 剥离/恢复 + 焦点 + TopMost | unit + integration | `flutter test test/platform/windows_fullscreen_driver_test.dart` |
| PLAT-02 | macOS delegate 回调确认 + 三级确认链 | unit | `flutter test test/platform/macos_fullscreen_driver_test.dart` |
| PLAT-03 | Linux state-changed 信号 + WM 检测 + 三级确认 | unit | `flutter test test/platform/linux_fullscreen_driver_test.dart` |
| PLAT-04 | capabilities() 每平台返回真实值 | unit | `flutter test test/platform/fullscreen_capability_test.dart` |

### Sampling Rate
- Per task commit: `flutter test test/platform/`
- Per wave merge: `flutter test`
- Phase gate: Full suite green + `flutter run -d windows` 手动验证全屏

### Wave 0 Gaps
- [ ] `test/platform/windows_fullscreen_driver_test.dart` — covers PLAT-01
- [ ] `test/platform/macos_fullscreen_driver_test.dart` — covers PLAT-02
- [ ] `test/platform/linux_fullscreen_driver_test.dart` — covers PLAT-03
- [ ] `test/platform/fullscreen_capability_test.dart` — covers PLAT-04

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | yes | Win32 HWND 句柄验证 (IsWindow) |
| V6 Cryptography | no | — |

### Known Threat Patterns for Win32 FFI

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| 无效 HWND 句柄 | Denial of Service | 调用前 IsWindow() 检查 |
| FFI 内存泄漏 | Information Disclosure | finally 块中 calloc.free() |
| SetForegroundWindow 失败 | Denial of Service | 失败只报日志，不循环重试 (D-07 安全护栏) |

## Sources

### Primary (HIGH confidence)
- `lib/kernel/bridge/win32/win32_display_enumerator.dart` — Win32 FFI 模式 (DynamicLibrary + lookupFunction + NativeCallable)
- `packages/fullscreen_window/windows/fullscreen_window_plugin.cpp` — Windows C++ 全屏实现 (WS_THICKFRAME 剥离)
- `packages/fullscreen_window/macos/Classes/FullscreenWindowPlugin.m` — macOS ObjC 全屏实现 (toggleFullScreen:)
- `packages/fullscreen_window/linux/fullscreen_window_plugin.cc` — Linux GTK 全屏实现 (gtk_window_fullscreen)
- `lib/kernel/bridge/fullscreen_driver.dart` — FullscreenDriver 抽象接口 (Phase B)
- `lib/kernel/bridge/desktop_fullscreen_adapter.dart` — 三级确认链实现 (Phase B)
- `lib/kernel/bridge/fullscreen_command_queue.dart` — 命令队列 (Phase B)

### Secondary (MEDIUM confidence)
- MEMORY: project_fullscreen_win32_fix.md — Win32 FFI 重写方案 (WS_THICKFRAME 解决方案)
- MEMORY: anti_pattern_fullscreen_ffi.md — 禁止 win32 包的反面教训

### Tertiary (LOW confidence)
- Linux WM 差异性分析基于训练知识，未在目标机器验证

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — 所有库已在项目中验证
- Architecture: HIGH — Phase A/B 架构已冻结，Phase C 只扩展 Driver 层
- Pitfalls: MEDIUM — Win32 pitfalls 已有项目经验，macOS/Linux 基于训练知识

**Research date:** 2026-07-10
**Valid until:** 2026-08-10 (30 days — 桌面端全屏 API 稳定)
