# Bridge API

## WindowBridge (abstract class)

**File:** `lib/kernel/bridge/window_bridge.dart`

窗口管理抽象接口 — UI 层依赖此接口，不依赖具体实现。

### Implementations

- `WindowService` — Win32 真实实现
- `FakeWindowService` — 测试替身

### State Properties

| Property | Type | Description |
|----------|------|-------------|
| `mode` | `ValueNotifier<WindowMode>` | 窗口模式 |
| `windowSize` | `ValueNotifier<Size>` | 窗口尺寸 |
| `isResizing` | `ValueNotifier<bool>` | 是否正在调整大小 |
| `isAlwaysOnTop` | `ValueNotifier<bool>` | 是否置顶 |
| `isFullscreen` | `bool` (getter) | 是否全屏（从 mode 派生） |

### Command Methods

| Method | Signature | Description |
|--------|-----------|-------------|
| `init` | `Future<void> init()` | 初始化窗口 |
| `setMode` | `Future<void> setMode(WindowMode target)` | 设置窗口模式 |
| `setAlwaysOnTop` | `Future<void> setAlwaysOnTop(bool value)` | 设置置顶 |
| `setAspectRatio` | `Future<void> setAspectRatio(double ratio)` | 设置窗口宽高比 |
| `minimize` | `Future<void> minimize()` | 最小化窗口 |
| `close` | `Future<void> close()` | 关闭窗口 |
| `startDragging` | `Future<void> startDragging()` | 开始窗口拖拽 |
| `dispose` | `void dispose()` | 释放资源 |

### Usage

```dart
// Toggle fullscreen
if (windowService.isFullscreen) {
  await windowService.setMode(WindowMode.windowed);
} else {
  await windowService.setMode(WindowMode.fullscreen);
}

// Listen to resize state
windowService.isResizing.addListener(() {
  // Skip expensive rendering during resize
});
```

---

## WindowMode (enum)

**File:** `lib/kernel/bridge/window_mode.dart`

| Value | Getter | Description |
|-------|--------|-------------|
| `windowed` | `isWindowed` | 普通窗口 |
| `maximized` | `isMaximized` | 最大化 |
| `fullscreen` | `isFullscreen` | 无边框全屏 |
| `minimized` | `isMinimized` | 最小化 |
