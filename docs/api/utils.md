# Utils API

## formatMs (function)

**File:** `lib/kernel/utils/time_utils.dart`

毫秒格式化为 HH:MM:SS 或 MM:SS。

```dart
String formatMs(int ms)
```

### Examples

```dart
formatMs(0)        // '00:00'
formatMs(61000)    // '01:01'
formatMs(3661000)  // '1:01:01'
```

---

## PathUtils (class)

**File:** `lib/kernel/utils/path_utils.dart`

路径工具函数。

### Static Methods

| Method | Signature | Description |
|--------|-----------|-------------|
| `basename` | `static String basename(String path)` | 提取文件名 |
| `dirname` | `static String dirname(String path)` | 提取目录路径 |
| `openFileLocation` | `static void openFileLocation(String path, {Future<void> Function(String, List<String>)? runner})` | 打开文件所在目录 |

### Examples

```dart
PathUtils.basename('C:/Videos/movie.mkv')  // 'movie.mkv'
PathUtils.basename('/home/user/video.mp4')  // 'video.mp4'
PathUtils.basename('song.mp3')              // 'song.mp3'

PathUtils.dirname('C:/Videos/movie.mkv')   // 'C:/Videos'
PathUtils.dirname('song.mp3')              // '.'

// Open in file explorer (platform-aware)
PathUtils.openFileLocation('C:/Videos/movie.mkv');
```

---

## FolderScanner (class)

**File:** `lib/kernel/scanner/folder_scanner.dart`

扫描目录中的视频文件（非递归）。

### Static Methods

| Method | Signature | Description |
|--------|-----------|-------------|
| `scan` | `static Future<List<VideoFile>> scan(String directory)` | 扫描目录 |
| `directoryOf` | `static String directoryOf(String filePath)` | 获取父目录 |

### VideoFile

| Property | Type | Description |
|----------|------|-------------|
| `path` | `String` | 绝对路径 |
| `name` | `String` | 文件名（含扩展名） |
| `folderPath` | `String` | 父目录路径 |

### Supported Extensions

mp4, mkv, avi, mov, wmv, flv, webm, m4v, ts, rmvb, mpg, mpeg, 3gp, vob

### Usage

```dart
final videos = await FolderScanner.scan('C:/Videos');
for (final video in videos) {
  debugPrint('${video.name} at ${video.path}');
}
```

---

## DebugProbe

**File:** `lib/kernel/utils/debug_probe.dart`

调试探针 — 记录操作耗时和事件（编译时开关 kDebugMode）。

### Usage

```dart
final probe = DebugProbeRegistry.register('playback');
await probe.measureAsync('init', () async {
  // ... expensive operation
});
```

---

## PerfMonitor

**File:** `lib/kernel/utils/perf_monitor.dart`

性能监控 — 帧计时、卡顿检测。
