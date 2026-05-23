# 08 — 键盘系统

> 快捷键绑定、KeyboardHandler 实现、自定义绑定、EditableText 防冲突、媒体键。

## 快捷键总表

| 按键 | 动作 ID | 回调 | 说明 |
|------|---------|------|------|
| `Space` | `playPause` | `onPlayPause` | 播放/暂停 |
| `←` | `seekBackward` | `onSeekBackward` | 后退 5s |
| `→` | `seekForward` | `onSeekForward` | 前进 5s |
| `↑` | `volumeUp` | `onVolumeUp` | 音量 +5% |
| `↓` | `volumeDown` | `onVolumeDown` | 音量 -5% |
| `F` | `fullscreen` | `onToggleFullscreen` | 切换全屏 |
| `M` | `mute` | `onToggleMute` | 切换静音 |
| `N` | `next` | `onNext` | 下一首 |
| `P` | `previous` | `onPrevious` | 上一首 |
| `O` | `openFile` | `onOpenFile` | 打开文件 |
| `S` | `subtitle` | `onToggleSubtitle` | 字幕开关 |
| `ESC` | `exitFullscreen` | `onExitFullscreen` | 退出全屏/关闭面板 |
| `F1` / `?` | `help` | `onShowHelp` | 快捷键帮助 |
| `]` | `subtitleDelayForward` | `onSubtitleDelayForward` | 字幕延迟 +500ms |
| `[` | `subtitleDelayBackward` | `onSubtitleDelayBackward` | 字幕延迟 -500ms |
| `A` | `aspectCycle` | `onCycleAspectRatio` | 循环宽高比 |
| `MediaPlayPause` | — | `onMediaPlayPause` | 媒体键: 播放/暂停 |
| `MediaTrackNext` | — | `onMediaNext` | 媒体键: 下一首 |
| `MediaTrackPrevious` | — | `onMediaPrevious` | 媒体键: 上一首 |

## 架构

```
KeyboardHandler (StatelessWidget)
  ├── Focus (autofocus: true, onKeyEvent: _handleKeyEvent)
  │     └── child
  └── shortcutDefinitions() — 帮助对话框数据源
```

`lib/ui/player/keyboard_handler.dart` — 199 行

### 核心设计

1. **单一数据源:** `shortcutDefinitions()` 函数同时为 KeyboardHandler 和帮助对话框提供数据
2. **回调注入:** 所有动作通过 `VoidCallback?` 注入，KeyboardHandler 不持有业务状态
3. **自定义绑定:** `Map<String, String> customBindings` 支持运行时重映射

### 自定义绑定机制

```dart
// customBindings 格式: { actionId → keyId 字符串 }
{'playPause': '32', 'seekForward': '39'}  // Space → 32, ArrowRight → 39

// 匹配逻辑
bool _keyMatches(LogicalKeyboardKey key, String action,
    LogicalKeyboardKey defaultKey) {
  if (customBindings.isEmpty) return key == defaultKey;
  final bound = customBindings[action];
  if (bound == null) return key == defaultKey;
  return key.keyId.toString() == bound;  // keyId 字符串比较
}
```

**设计选择:** 使用 `LogicalKeyboardKey.keyId` 的字符串表示而非枚举比较，允许绑定任意物理按键。

## EditableText 防冲突

```dart
KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
  if (event is! KeyDownEvent) return KeyEventResult.ignored;

  // 不拦截文本输入框的按键事件
  final focused = FocusManager.instance.primaryFocus;
  if (focused != null && focused.context != null) {
    final widget = focused.context!.widget;
    if (widget is EditableText) return KeyEventResult.ignored;
  }
  // ...
}
```

**原理:** 检查当前焦点是否在 `EditableText` 上 (如设置面板的文本输入框)。如果是，跳过所有快捷键处理，避免在输入时触发播放/暂停等操作。

## 媒体键

媒体键硬编码，不参与自定义绑定：

```dart
if (key == LogicalKeyboardKey.mediaPlayPause) {
  onMediaPlayPause?.call();
  return KeyEventResult.handled;
}
if (key == LogicalKeyboardKey.mediaTrackNext) { ... }
if (key == LogicalKeyboardKey.mediaTrackPrevious) { ... }
```

**原因:** 媒体键是硬件键，用户通常不会重映射。

## 帮助对话框

`shortcutDefinitions()` 返回 `List<(String, String)>`，每个条目是 `(按键显示文本, 功能描述)`：

```dart
List<(String, String)> shortcutDefinitions(AppLocalizations l10n) => [
  ('Space', l10n.shortcutPlayPause),
  ('← / →', l10n.shortcutSeek),
  ('↑ / ↓', l10n.shortcutVolume),
  ('F', l10n.shortcutFullscreen),
  // ... 14 条总表
];
```

**约定:** 新增快捷键必须同时更新 `shortcutDefinitions` 和 `_handleKeyEvent`。

## 集成位置

`lib/ui/player/player_screen.dart` 中 KeyboardHandler 包裹整个播放器：

```dart
KeyboardHandler(
  onPlayPause: controller.togglePlayPause,
  onSeekForward: () => engine.skipForward(5),
  onSeekBackward: () => engine.skipBack(5),
  onVolumeUp: () => engine.setVolume(engine.volume.value + 0.05),
  onToggleFullscreen: windowService.toggleFullscreen,
  onExitFullscreen: () {
    if (isFullscreen) windowService.exitFullscreen();
    else if (playlistVisible) togglePlaylist();
  },
  // ... 所有回调
  child: Stack([...]),
)
```

## 设计决策

| 决策 | 理由 |
|------|------|
| `StatelessWidget` + `Focus` | 无内部状态，所有状态在回调链上层 |
| `KeyDownEvent` only | 忽略 KeyUp/KeyRepeat，避免重复触发 |
| `keyId` 字符串比较 | 跨平台兼容，序列化友好 |
| 媒体键硬编码 | 硬件键无需重映射 |
| EditableText 检测 | 设置面板文本框输入时不触发快捷键 |
