# Player UI Widgets

## PlayerScreen (StatefulWidget)

**File:** `lib/ui/player/player_screen.dart`

播放器主屏幕 — 组合层，接线键盘 + 控制层。

### Constructor

```dart
const PlayerScreen({
  required MediaEngine engine,
  required PlaybackController controller,
  required Playlist playlist,
  required ValueNotifier<int> playlistGeneration,
  required WindowBridge windowService,
  Map<String, String> customBindings = const {},
  VoidCallback? onTogglePlaylist,
  VoidCallback? onSettings,
  void Function(BuildContext, TapUpDetails)? onSettingsSecondary,
  VoidCallback? onOpenFile,
  VoidCallback? onTogglePlayMode,
  void Function(List<String>)? onFilesDropped,
  void Function(bool)? onDragHoverChanged,
  Widget? emptyState,
  void Function(String, List<PlaylistItem>)? onFolderScanned,
  VoidCallback? onClearHistory,
  void Function(String)? onShowProperties,
})
```

### Layout

- **宽屏 (>=600dp):** Row 布局，面板在右侧
- **窄屏 (<600dp):** 面板叠加为 overlay

---

## ControlBar (StatelessWidget)

**File:** `lib/ui/player/control_bar.dart`

底部毛玻璃控制栏。深色毛玻璃 + 蓝色微光边框。

### Features

- 播放/暂停/上一首/下一首按钮
- 进度条
- 音量控制
- 倍速选择
- 时间显示

---

## ProgressBar (StatefulWidget)

**File:** `lib/ui/player/progress_bar.dart`

进度条 — 已播放/已缓冲/未播放三层圆角矩形。

### Constructor

```dart
const ProgressBar({
  required MediaEngine engine,
  ValueListenable<bool>? resizing,
})
```

### Features

- 拖拽 seek（节流 + 阈值）
- 悬停展开动画（3dp → 5dp）
- Tooltip 淡入淡出
- 滚轮 seek
- 悬停 thumb
- 缓冲指示器

---

## VideoSurface (StatelessWidget)

**File:** `lib/ui/player/video_surface.dart`

视频纹理渲染 — 根据引擎 textureId 和 aspectRatio 显示视频。

### Constructor

```dart
const VideoSurface({required EngineStateView engine})
```

### Features

- FittedBox 自适应宽高比
- RepaintBoundary 隔离重绘
- textureId 为 null 时显示空

---

## VolumeButton (StatefulWidget)

**File:** `lib/ui/player/volume_controls.dart`

音量按钮 — 单击静音，带音量滑块。

### Constructor

```dart
const VolumeButton({required MediaEngine engine})
```

---

## SpeedButton

**File:** `lib/ui/player/speed_button.dart`

播放速度选择器。

---

## KeyboardHandler

**File:** `lib/ui/player/keyboard_handler.dart`

键盘快捷键处理 — 20+ 键 Focus handler。

| Key | Action |
|-----|--------|
| Space | Play/Pause |
| Left/Right | Seek ±5s |
| Up/Down | Volume ±5% |
| M | Toggle mute |
| N | Previous track |
| P | Next track |
| O | Open file |
| A | Cycle aspect ratio |
| S | Toggle subtitle |
| [ / ] | Subtitle delay ±500ms |
| ESC | Exit fullscreen / Close playlist |

---

## ControlsOverlay (StatefulWidget)

**File:** `lib/ui/player/controls_overlay.dart`

自动隐藏控制层 — 鼠标移动时显示，静止时隐藏。

---

## AutoHideController

**File:** `lib/ui/player/auto_hide_controller.dart`

自动隐藏控制器 — 管理控制栏显示/隐藏定时器。

---

## DropHandler

**File:** `lib/ui/player/drop_handler.dart`

拖放文件处理。

---

## ErrorBanner

**File:** `lib/ui/player/error_banner.dart`

错误横幅 — 显示 PlayerError 的 UI 组件。
