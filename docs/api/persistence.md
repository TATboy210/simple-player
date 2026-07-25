# Persistence API

## PlaylistStore (class)

**File:** `lib/kernel/persistence/playlist_store.dart`

播放列表 JSON 持久化。300ms 防抖写入，原子写入（.tmp + rename），指数退避重试。

### Static Methods

| Method | Signature | Description |
|--------|-----------|-------------|
| `save` | `void save(Playlist playlist)` | 保存播放列表（300ms 防抖） |
| `load` | `Future<Playlist?> load()` | 加载播放列表 |
| `loadInBackground` | `Future<Playlist?> loadInBackground()` | 后台 Isolate 加载 |
| `clear` | `Future<void> clear()` | 清空存储 |
| `dispose` | `Future<void> dispose()` | 释放资源（flush 未写入数据） |

### Constructor

```dart
PlaylistStore({String? storagePath})
```

- `storagePath` — 自定义存储路径（测试注入临时目录）

### Features

- **防抖写入** — 快速操作合并为一次磁盘写入
- **原子写入** — 先写 .tmp 再 rename，防止文件损坏
- **指数退避重试** — 最多 3 次重试
- **后台加载** — Isolate 中执行文件 I/O + JSON 解析
- **历史迁移** — 自动迁移旧 history.json 数据

### Usage

```dart
// Save (debounced)
PlaylistStore.save(playlist);

// Load
final playlist = await PlaylistStore.load();

// Background load (non-blocking UI)
final playlist = await PlaylistStore.loadInBackground();

// Cleanup
await PlaylistStore.dispose();
```

---

## SettingsStore (class)

**File:** `lib/kernel/persistence/settings_store.dart`

应用设置持久化（shared_preferences）。所有 save 方法 try-catch 防御。

### Lifecycle

```dart
// Pre-warm in main.dart (avoids repeated getInstance() calls)
SettingsStore.prewarm(prefs);

// Load settings
final settings = await SettingsStore.load();

// Save individual values
await SettingsStore.saveVolume(0.8);
await SettingsStore.saveLastFile(path);

// Save all at once
await SettingsStore.saveAll(settings);
```

### Load Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `load()` | `Future<AppSettings>` | 加载所有设置（失败返回安全默认值） |
| `loadLocale()` | `Future<String>` | 加载语言偏好（默认 'zh'） |
| `loadThemeIndex()` | `Future<int>` | 加载主题索引（默认 0） |
| `loadShortcuts()` | `Future<Map<String, String>>` | 加载自定义快捷键 |
| `loadPlaybackSpeed()` | `Future<double>` | 加载播放速度 |
| `loadD3d11SyncEnabled()` | `Future<bool>` | 加载 D3D11 同步设置 |
| `loadHardwareDecoding()` | `Future<bool>` | 加载硬件解码设置 |
| `loadTrackPreferences()` | `Future<TrackPreferences>` | 加载轨道偏好 |

### Save Methods

| Method | Description |
|--------|-------------|
| `saveVolume(double)` | 保存音量 |
| `saveLastFile(String)` | 保存最后打开的文件 |
| `saveWindowGeometry(...)` | 保存窗口几何（位置+大小+最大化） |
| `savePlayMode(int)` | 保存播放模式 |
| `saveIsMuted(bool)` | 保存静音状态 |
| `saveIsAlwaysOnTop(bool)` | 保存置顶状态 |
| `saveLocale(String)` | 保存语言偏好 |
| `saveThemeIndex(int)` | 保存主题索引 |
| `saveShortcuts(Map)` | 保存自定义快捷键 |
| `saveSubtitleFontSize(double)` | 保存字幕字体大小 |
| `saveSubtitleColorIndex(int)` | 保存字幕颜色 |
| `saveSubtitleBottomOffset(double)` | 保存字幕偏移 |
| `saveVideoBrightness(double)` | 保存亮度 |
| `saveVideoContrast(double)` | 保存对比度 |
| `saveVideoSaturation(double)` | 保存饱和度 |
| `saveVideoHue(double)` | 保存色调 |
| `saveVideoRotation(int)` | 保存旋转 |
| `saveVideoAspectRatioIndex(int)` | 保存宽高比 |
| `saveVideoDeinterlace(bool)` | 保存反交错 |
| `saveD3d11SyncEnabled(bool)` | 保存 D3D11 同步 |
| `saveHardwareDecoding(bool)` | 保存硬件解码 |
| `savePlaybackSpeed(double)` | 保存播放速度 |
| `saveTrackPreferences(TrackPreferences)` | 保存轨道偏好 |

### Import/Export

| Method | Signature | Description |
|--------|-----------|-------------|
| `exportSettings` | `Future<String> exportSettings()` | 导出所有设置为 JSON |
| `importSettings` | `Future<ImportResult> importSettings(String json)` | 从 JSON 导入设置 |
| `applyImportedSettings` | `Future<void> applyImportedSettings(ImportSuccess result)` | 持久化导入的设置 |

### ImportResult (sealed class)

```dart
sealed class ImportResult {}

final class ImportSuccess extends ImportResult {
  final AppSettings settings;
  final String locale;
  final int themeIndex;
  final Map<String, String> shortcuts;
}

final class ImportFailure extends ImportResult {
  final String error;
}
```

### Usage

```dart
// Export
final json = await SettingsStore.exportSettings();

// Import
final result = await SettingsStore.importSettings(jsonString);
switch (result) {
  case ImportSuccess(:final settings, :final locale):
    await SettingsStore.applyImportedSettings(result);
  case ImportFailure(:final error):
    showError(error);
}
```
