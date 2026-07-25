# Models API

## PlaylistItem

**File:** `lib/kernel/models/playlist_item.dart`

播放列表项 — 统一数据模型。

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `path` | `String` | 文件路径（唯一标识） |
| `name` | `String` (getter) | 文件名，由 path 派生 |
| `timestamp` | `int?` | 最后播放时间（millisecondsSinceEpoch），null = 从未播放 |
| `positionMs` | `int?` | 断点位置（毫秒），null = 0 |
| `durationMs` | `int?` | 视频总时长（毫秒），null = 未知 |

### Constructor

```dart
PlaylistItem({
  required this.path,
  this.timestamp,
  this.positionMs,
  this.durationMs,
})
```

### Methods

| Method | Signature | Description |
|--------|-----------|-------------|
| `copyWith` | `PlaylistItem copyWith({int? timestamp, int? positionMs, int? durationMs})` | 不可变更新 |
| `toJson` | `Map<String, dynamic> toJson()` | 序列化 |
| `fromJson` | `factory PlaylistItem.fromJson(Map<String, dynamic> json)` | 反序列化 |

### Usage

```dart
final item = PlaylistItem(path: 'C:/Videos/movie.mp4');

// Update breakpoint position
final updated = item.copyWith(positionMs: 60000, durationMs: 7200000);

// Serialize
final json = item.toJson();
```

---

## PlayMode (enum)

**File:** `lib/kernel/models/play_mode.dart`

| Value | Description |
|-------|-------------|
| `loopAll` | 顺序播放（列表循环） |
| `loopSingle` | 单曲循环 |
| `shuffle` | 随机播放 |

---

## AppSettings

**File:** `lib/kernel/models/app_settings.dart`

不可变的应用设置容器。通过 `SettingsStore` 持久化。

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `volume` | `double` | — | 音量（0.0 ~ 100.0） |
| `lastFile` | `String` | — | 最后打开的文件路径 |
| `windowWidth` | `double` | — | 窗口宽度（逻辑像素） |
| `windowHeight` | `double` | — | 窗口高度（逻辑像素） |
| `windowX` | `double?` | `null` | 窗口 X 位置，null = 居中 |
| `windowY` | `double?` | `null` | 窗口 Y 位置，null = 居中 |
| `isMaximized` | `bool` | `false` | 是否最大化 |
| `playMode` | `int` | — | 播放模式索引（映射 PlayMode 枚举） |
| `isMuted` | `bool` | — | 是否静音 |
| `isAlwaysOnTop` | `bool` | `false` | 是否置顶 |
| `subtitleFontSize` | `double` | `17.0` | 字幕字体大小 |
| `subtitleColorIndex` | `int` | `0` | 字幕颜色预设索引 |
| `subtitleBottomOffset` | `double` | `80.0` | 字幕距底部偏移 |
| `videoBrightness` | `double` | `0.0` | 亮度调节（-1.0 ~ 1.0） |
| `videoContrast` | `double` | `0.0` | 对比度调节（-1.0 ~ 1.0） |
| `videoSaturation` | `double` | `0.0` | 饱和度调节（-1.0 ~ 1.0） |
| `videoHue` | `double` | `0.0` | 色调调节（-180 ~ 180） |
| `videoRotation` | `int` | `0` | 视频旋转（0/90/180/270） |
| `videoAspectRatioIndex` | `int` | `0` | 宽高比模式索引 |
| `videoDeinterlace` | `bool` | `false` | 是否启用反交错 |
| `playbackSpeed` | `double` | `1.0` | 播放速度倍率 |
| `d3d11Sync` | `bool` | `true` | D3D11 CPU 同步 |
| `hardwareDecoding` | `bool` | `true` | 硬件解码 |

### Methods

```dart
AppSettings copyWith({...})  // 不可变更新（支持显式 null 传递）
```

> `copyWith` 使用 `_sentinel` 模式区分"未提供"和"显式 null"。

---

## PlayerError (sealed class)

**File:** `lib/kernel/models/player_error.dart`

播放器结构化错误 — sealed class 层级，支持穷举模式匹配。

### Subtypes

| Type | Code Enum | Description |
|------|-----------|-------------|
| `FileError` | `FileErrorCode` | 文件相关错误 |
| `CodecError` | `CodecErrorCode` | 编解码错误 |
| `PlaybackError` | `PlaybackErrorCode` | 播放控制错误 |
| `NetworkError` | `NetworkErrorCode` | 网络错误 |
| `UnknownError` | — | 未分类错误（始终可恢复） |

### Common Properties

| Property | Type | Description |
|----------|------|-------------|
| `message` | `String` | 人类可读的错误消息 |
| `cause` | `Object?` | 原始异常 |
| `context` | `ErrorContext?` | 结构化上下文 |
| `isFatal` | `bool` | 是否为致命错误 |
| `l10nKey` | `String` | UI 翻译键 |

### Error Codes

**FileErrorCode:** `pathEmpty`, `fileNotFound`, `pathTraversal`

**CodecErrorCode:** `unsupportedFormat`, `decodeFailed`, `codecUnsupported`

**PlaybackErrorCode:** `playFailed`, `seekFailed`, `textureFailed`, `openTimeout`

**NetworkErrorCode:** `timeout`, `connectionLost`

### Usage

```dart
switch (error) {
  case FileError(:final code):
    debugPrint('File error: $code');
  case CodecError(:final code):
    debugPrint('Codec error: $code');
  case PlaybackError(:final code):
    debugPrint('Playback error: $code');
  case NetworkError(:final code):
    debugPrint('Network error: $code');
  case UnknownError(:final message):
    debugPrint('Unknown: $message');
}
```

---

## ErrorContext

**File:** `lib/kernel/models/player_error.dart`

错误结构化上下文。

| Property | Type | Description |
|----------|------|-------------|
| `action` | `String?` | 操作名称（e.g., 'open', 'play'） |
| `generation` | `int?` | open() 递增计数器 |
| `path` | `String?` | 文件路径或 URL |
| `timestamp` | `DateTime` | 错误发生时间 |
| `module` | `String?` | 模块名称 |
| `callbackStackTrace` | `StackTrace?` | mdk 回调线程栈 |

---

## TrackPreferences

**File:** `lib/kernel/models/track_preferences.dart`

轨道偏好设置。

| Property | Type | Description |
|----------|------|-------------|
| `audioTrackIndex` | `int?` | 偏好音轨索引 |
| `subtitleTrackIndex` | `int?` | 偏好字幕轨道索引 |
| `subtitleDelay` | `int` | 字幕延迟（毫秒） |
| `empty` | `TrackPreferences` (static) | 默认空偏好 |

---

## ExportData

**File:** `lib/kernel/models/export_data.dart`

设置导入/导出数据格式。
