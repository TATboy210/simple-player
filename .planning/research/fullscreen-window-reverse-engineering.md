# fullscreen_window 逆向分析

**Package:** fullscreen_window v1.3.0 (本地 fork, 原版 v1.2.1 by jakky1)
**GitHub:** https://github.com/jakky1/fullscreen_window
**License:** Apache 2.0
**Analyzed:** 2026-07-11

---

## 1. 核心发现：这个包做了什么

**一句话：fullscreen_window 只做一件事 —— 把窗口变成全屏，再变回来。**

它不管理窗口装饰、不处理标题栏、不关心控件布局、不做画中画、不处理多显示器边界。就是一个 toggle。

```
fullScreenWindow.setFullScreen(true)   → 窗口变全屏
fullScreenWindow.setFullScreen(false)  → 窗口恢复
fullScreenWindow.getScreenSize(ctx)    → 返回屏幕尺寸
```

---

## 2. API 表面

### 公开 API（Dart 层）

```dart
// 全局单例
final fullScreenWindow = FullScreenWindowPlatform.instance;

// 核心方法
Future<void> setFullScreen(bool isFullScreen)
Future<Size> getScreenSize(BuildContext? context)

// macOS 新增 (v1.3.0)
Stream<bool> get onFullScreenChanged  // NSWindowDelegate 回调
Future<bool> isFullScreen()           // styleMask 查询
```

### 平台接口抽象

```dart
abstract class FullScreenWindowPlatform extends PlatformInterface {
  Future<void> setFullScreen(bool isFullScreen);
  Future<Size> getScreenSize(BuildContext? context);
  Stream<bool> get onFullScreenChanged;  // 默认空流
  Future<bool> isFullScreen();           // 默认 false
}
```

**设计模式：** Federated Plugin（联合插件），通过 `plugin_platform_interface` 做平台分发。

---

## 3. 平台实现对比

### 3.1 Windows (C++ Win32) — 113 行

**核心函数 `setFullScreen(HWND, bool)`:**

```cpp
// 保存窗口状态（只在进入全屏时保存一次）
if (!g_saved_window_info.fullscreen) {
    g_saved_window_info.maximized = !!IsZoomed(hwnd);
    g_saved_window_info.style = GetWindowLong(hwnd, GWL_STYLE);
    g_saved_window_info.ex_style = GetWindowLong(hwnd, GWL_EXSTYLE);
    GetWindowPlacement(hwnd, &g_saved_window_info.placement);
}

if (fullscreen) {
    // 移除标题栏和边框
    SetWindowLong(hwnd, GWL_STYLE, style & ~(WS_CAPTION | WS_THICKFRAME | WS_MAXIMIZE));
    SetWindowLong(hwnd, GWL_EXSTYLE, ex_style | WS_EX_TOPMOST & ~(...));
    // 最大化
    SendMessage(hwnd, WM_SYSCOMMAND, SC_MAXIMIZE, 0);
} else {
    // 恢复原始状态
    if (!maximized) SendMessage(hwnd, WM_SYSCOMMAND, SC_RESTORE, 0);
    SetWindowLong(hwnd, GWL_STYLE, saved_style);
    SetWindowLong(hwnd, GWL_EXSTYLE, saved_ex_style);
    SetWindowPlacement(hwnd, &saved_placement);
    // 强制重新布局（有已知 bug：偶尔布局不正确）
    SetWindowPos(hwnd, 0, left, top, width, height, SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
}
```

**关键细节：**
- 使用全局变量 `g_saved_window_info` 保存/恢复状态
- 用 `SC_MAXIMIZE` 而非 `SetWindowPos` 来实现全屏
- 退出全屏时有 `SWP_FRAMECHANGED` 强制重绘
- **已知 bug:** 代码注释承认 "sometimes it still has layout issues"
- **不处理多显示器** — `getScreenSize` 用 `GetDesktopWindow()` 返回主显示器尺寸
- **不做 WS_THICKFRAME 处理** — 没有不可见边框用于拖拽调整大小

### 3.2 macOS (Objective-C NSWindow) — 80 行

```objc
// 进入/退出全屏
[window toggleFullScreen:nil];

// 查询状态
BOOL isFullScreen = (window.styleMask & NSWindowStyleMaskFullScreen) != 0;

// 屏幕尺寸（物理像素）
NSScreen *screen = [NSScreen mainScreen];
CGFloat scale = [screen backingScaleFactor];
return CGSizeMake(frame.size.width * scale, frame.size.height * scale);
```

**关键细节：**
- 实现 `NSWindowDelegate` 接收全屏动画完成回调
- `windowDidEnterFullScreen:` / `windowDidExitFullScreen:` 通过 MethodChannel 通知 Dart
- 有延迟初始化逻辑（`registerWithRegistrar` 时 mainWindow 可能为 nil）
- `getFullScreenState` 通过 `styleMask` 位检查
- 返回物理像素尺寸（乘以 `backingScaleFactor`）

### 3.3 Linux (C GTK3) — 182 行

```c
// 进入/退出全屏
gtk_window_fullscreen(get_window(self));
gtk_window_unfullscreen(get_window(self));

// 查询状态
GdkWindowState state = gdk_window_get_state(gdk_window);
gboolean is_fullscreen = state & GDK_WINDOW_STATE_FULLSCREEN;
```

**关键细节：**
- 监听 `window-state-event` 信号获取全屏变化回调
- 通过 MethodChannel 将 `onFullScreenChanged` 发送到 Dart
- `getScreenSize` 用 `gdk_monitor_get_geometry` 返回主显示器尺寸
- 额外提供 `getPlatformNotes` 方法（返回 XDG_SESSION_TYPE、XDG_CURRENT_DESKTOP 等）
- 正确释放 GObject 资源（`g_clear_object`）

### 3.4 Web (Dart package:web) — 37 行

```dart
// 进入全屏
web.window.document.documentElement?.requestFullscreen();

// 退出全屏
web.window.document.exitFullscreen();

// 屏幕尺寸
Size(web.window.screen.width.toDouble(), web.window.screen.height.toDouble());
```

### 3.5 Android/iOS (Dart Flutter API) — 32 行

```dart
// 进入全屏
SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

// 退出全屏
SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);

// 屏幕尺寸（需要 context）
MediaQuery.of(context).size
```

---

## 4. 代码量统计

| 层 | 文件 | 行数 |
|----|------|------|
| **Dart (lib/)** | 5 files | 206 |
| **Dart (test/)** | 3 files | 679 |
| **Windows C++** | 4 files | 185 |
| **macOS Obj-C** | 2 files | 93 |
| **Linux C** | 3 files | 218 |
| **总计 (不含 example)** | 17 files | **1,381** |
| **核心代码 (不含 test)** | 14 files | **702** |

---

## 5. 依赖

```yaml
dependencies:
  flutter: sdk
  flutter_web_plugins: sdk
  plugin_platform_interface: ^2.0.2
  web: ^1.0.0
```

**零外部依赖**（除了 Flutter SDK 和 platform_interface 规范）。

---

## 6. 这个包不做什么（局限性）

| 功能 | fullscreen_window | simple_player 需要 |
|------|-------------------|-------------------|
| 全屏 toggle | ✅ 做了 | ✅ 需要 |
| 无边框窗口管理 | ❌ 不做 | ✅ 需要（frameless + glass） |
| 标题栏自定义 | ❌ 不做 | ✅ 需要（custom title bar） |
| 窗口拖拽移动 | ❌ 不做 | ✅ 需要（DragToMoveArea） |
| 窗口调整大小 | ❌ 不做 | ✅ 需要（WS_THICKFRAME） |
| 多显示器边界钳位 | ❌ 不做 | ✅ 需要 |
| 窗口位置记忆 | ❌ 不做 | ✅ 需要 |
| 控件叠加层布局 | ❌ 不做 | ✅ 需要（auto-hide overlay） |
| 全屏时隐藏标题栏 | ✅ 做了 | ✅ 需要 |
| 全屏时置顶 | ✅ 做了（WS_EX_TOPMOST） | ⚠️ 不一定需要 |
| 画中画 | ❌ 不做 | ❌ 不需要 |
| 全屏动画回调 | ✅ macOS only | ✅ 需要（防闪烁） |

---

## 7. 与 simple_player 现有实现对比

### fullscreen_window 的做法（Windows）

```
用户调用 setFullScreen(true)
  → 保存窗口样式
  → 移除 WS_CAPTION | WS_THICKFRAME
  → SendMessage(SC_MAXIMIZE)
  → 完成
```

**总逻辑：~30 行 C++**

### simple_player 的做法（Windows）

```
用户按 F
  → PlaybackController.toggleFullScreen()
  → FullscreenDriver.toggle()
  → WindowService.setFullScreen()
  → DesktopFullscreenDriver (平台特定)
    → 保存状态
    → 移除 WS_CAPTION | WS_THICKFRAME
    → SetWindowPos (精确计算多显示器边界)
    → 等待 WM_SIZE 确认
    → 发送事件到 Dart
  → ControlsOverlay 响应全屏事件
  → Auto-hide timer 启动
  → Title bar 隐藏
  → 键盘 handler 更新
```

**总逻辑：~2000 行，跨 15+ 文件**

### 为什么差这么多？

| 差异点 | fullscreen_window | simple_player |
|--------|-------------------|---------------|
| 状态管理 | 全局 C 变量 | 驱动层 + 服务层 + UI 层 |
| 平台抽象 | 1 个 MethodChannel | 分层驱动架构（Driver → Adapter → Bridge） |
| 多显示器 | 不处理 | EnumDisplayMonitors + 边界钳位 |
| 窗口装饰 | 不管理 | WS_THICKFRAME 不可见边框 + 窗口圆角 |
| 全屏确认 | 不等待 | Completer 等待原生确认 |
| 防闪烁 | 无 | DWM 属性 + 帧同步 |
| 控件联动 | 无 | auto-hide timer + fade animation |
| 错误恢复 | 无 | 状态机 + 超时 + 降级 |
| 跨平台测试 | 39 个 mock 测试 | 多平台单元测试 + 回归测试 |

---

## 8. 关键架构差异

### fullscreen_window: "命令式 toggle"

```
Dart → MethodChannel → Native → 立即返回
```

- 同步思维：发出命令，不关心结果
- 不验证状态：不知道当前是否已全屏
- 不处理竞态：快速连续调用可能状态不一致
- 不通知 UI：Dart 层不知道全屏是否真正完成

### simple_player: "事件驱动状态机"

```
Dart → Driver → Native → 等待确认 → 事件回传 → UI 响应
```

- 异步思维：发出命令，等待确认
- 状态守卫：isOperating 信号防止重入
- 竞态处理：Completer 链 + 超时
- UI 联动：全屏状态变化驱动控件层更新

---

## 9. 可以从 fullscreen_window 学到什么

### 9.1 好的设计

1. **极简 API** — 一个方法 `setFullScreen(bool)` 解决 80% 需求
2. **联合插件架构** — 平台接口抽象干净，易于扩展
3. **平台原生实现** — 每个平台用最合适的 API（Win32/GTK/NSWindow）
4. **macOS delegate 回调** — 通过 NSWindowDelegate 确认动画完成

### 9.2 不足之处

1. **全局变量** — `g_saved_window_info` 不是线程安全的
2. **无状态查询** — Windows/Linux 的 `isFullScreen()` 返回默认 false
3. **无多显示器** — `getScreenSize` 只返回主显示器
4. **布局 bug** — Windows 退出全屏后 "sometimes layout issues"
5. **无错误处理** — 原生层不返回错误信息（macOS 除外）
6. **无并发保护** — 快速 toggle 可能状态混乱

---

## 10. 结论：是否过度工程化？

**不是。** simple_player 的 2000 行全屏实现解决的问题远超 fullscreen_window 的范围。

fullscreen_window 回答的问题是：**"怎么把窗口变全屏？"**
simple_player 回答的问题是：**"怎么在一个无边框媒体播放器中提供流畅、可靠、跨显示器的全屏体验？"**

如果 simple_player 只需要 "视频填满屏幕"，那确实可以用 fullscreen_window 的 30 行代码。但实际需求包括：

- 无边框窗口 + 自定义标题栏 → 需要 WS_THICKFRAME 管理
- 多显示器 → 需要 EnumDisplayMonitors
- 全屏防闪烁 → 需要 DWM 属性 + 帧同步
- 控件自动隐藏 → 需要状态事件驱动
- 可靠的状态恢复 → 需要状态机 + 确认链

**simple_player 的复杂度是需求驱动的，不是架构过度设计。**

但可以借鉴 fullscreen_window 的简洁思路：
- 平台驱动层的核心 toggle 逻辑可以精简到 ~50 行
- 状态保存/恢复模式可以参考（保存一次，恢复时还原）
- macOS 的 delegate 回调模式已在 Phase 8 采用

---

## 11. 文件清单（核心源码）

```
packages/fullscreen_window/
├── lib/
│   ├── fullscreen_window.dart                    # 4 行 — 入口，导出单例
│   ├── fullscreen_window_platform_interface.dart  # 49 行 — 平台接口抽象
│   ├── fullscreen_window_method_channel.dart      # 84 行 — MethodChannel 默认实现
│   ├── fullscreen_window_android.dart             # 32 行 — Android/iOS 实现
│   └── fullscreen_window_web.dart                 # 37 行 — Web 实现
├── windows/
│   ├── fullscreen_window_plugin.cpp               # 113 行 — Win32 全屏实现
│   ├── fullscreen_window_plugin.h                 # 37 行 — 头文件
│   ├── fullscreen_window_plugin_c_api.cpp         # 12 行 — C API 注册
│   └── CMakeLists.txt                             # 54 行
├── macos/Classes/
│   ├── FullscreenWindowPlugin.h                   # 13 行 — NSWindowDelegate 声明
│   └── FullscreenWindowPlugin.m                   # 80 行 — macOS 全屏实现
├── linux/
│   ├── fullscreen_window_plugin.cc                # 182 行 — GTK3 全屏实现
│   ├── include/fullscreen_window/
│   │   └── fullscreen_window_plugin.h             # 26 行
│   └── fullscreen_window_plugin_private.h         # 10 行
├── test/
│   ├── fullscreen_window_test.dart                # 45 行 — 基础 mock 测试
│   ├── fullscreen_window_mock_test.dart           # 349 行 — 平台接口 mock
│   └── method_channel_mock_test.dart              # 285 行 — MethodChannel 级 mock
└── pubspec.yaml                                   # 86 行
```

**核心实现：702 行（不含测试和构建配置）**
