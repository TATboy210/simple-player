# Services API

## PlaybackController (class)

**File:** `lib/kernel/services/playback_controller.dart`

播放控制器 — 播放器全部运行时能力的统一门面入口（Facade 模式）。

### Constructor

```dart
PlaybackController({
  required MediaEngine engine,
  required Playlist playlist,
  required VoidCallback onNeedRebuild,
  void Function(PlayerError error)? onError,
  SubtitleService? subtitleService,
  TrackPreferenceService? trackPreferenceService,
})
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `engine` | `MediaEngine` | 视频渲染引擎实例 |
| `playlist` | `Playlist` | 播放列表管理器 |
| `navigator` | `PlaybackNavigator` | 播放导航子模块 |
| `fileOps` | `FileOperations` | 文件操作子模块 |
| `stateManager` | `PlaybackStateManager` | 状态管理子模块 |
| `autoAdvance` | `AutoAdvancePolicy` | 自动连播策略 |
| `currentFileName` | `ValueNotifier<String>` | 当前播放文件名 |
| `validationError` | `ValueNotifier<String?>` | 最近一次路径校验错误 |

### Playback Methods

| Method | Signature | Description |
|--------|-----------|-------------|
| `playIndex` | `Future<void> playIndex(int i)` | 播放指定索引 |
| `playNext` | `Future<void> playNext()` | 播放下一首 |
| `playPrevious` | `Future<void> playPrevious()` | 播放上一首 |
| `openAndPlay` | `Future<bool> openAndPlay(String p)` | 打开并播放文件 |
| `addFiles` | `Future<int> addFiles(List<String> p)` | 批量添加文件 |

### Playlist CRUD

| Method | Signature | Description |
|--------|-----------|-------------|
| `removeAt` | `Future<void> removeAt(int index)` | 移除指定索引（自动处理当前播放项） |
| `reorder` | `void reorder(int oldIndex, int newIndex)` | 拖拽排序 |
| `clearPlaylist` | `void clearPlaylist()` | 清空播放列表 |
| `togglePlayMode` | `void togglePlayMode()` | 切换播放模式 |
| `savePlaylist` | `void savePlaylist()` | 持久化播放列表 |

### Lifecycle

| Method | Signature | Description |
|--------|-----------|-------------|
| `init` | `Future<void> init({AppSettings? settings})` | 初始化（恢复设置 + 连播策略） |
| `dispose` | `void dispose()` | 释放资源 |

### Usage

```dart
final controller = PlaybackController(
  engine: engine,
  playlist: playlist,
  onNeedRebuild: () => setState(() {}),
  onError: (error) => showErrorSnackBar(error.message),
);

await controller.init(settings: savedSettings);
await controller.openAndPlay('C:/Videos/movie.mp4');
await controller.playNext();
controller.togglePlayMode();
controller.dispose();
```

---

## PlaybackNavigator (class)

**File:** `lib/kernel/services/playback_navigator.dart`

播放导航 — 索引跳转、上一首/下一首、并发 open() 守卫。

### openGeneration 守卫

用户快速切歌时，多个异步 open() 调用重叠。每次调用 `playIndex` 递增 generation，异步完成后检查 generation 是否仍匹配。不匹配则丢弃旧请求。

### Methods

| Method | Signature | Description |
|--------|-----------|-------------|
| `playIndex` | `Future<void> playIndex(int index)` | 播放指定索引（完整打开流程） |
| `playNext` | `Future<void> playNext()` | 播放下一首 |
| `playPrevious` | `Future<void> playPrevious()` | 播放上一首 |

### playIndex 流程

1. 校验索引范围
2. 递增 generation
3. 路径安全检查（PathValidator）
4. 打开引擎（engine.open）
5. 检查 generation 是否匹配（丢弃过期请求）
6. 恢复断点位置（> 1s 阈值）
7. 自动检测外部字幕
8. 恢复轨道偏好
9. 开始播放（engine.play）
10. 更新文件名和历史

---

## FileOperations (class)

**File:** `lib/kernel/services/file_operations.dart`

文件操作服务 — 文件打开和批量添加。

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `validationError` | `ValueNotifier<String?>` | 最近一次校验失败的错误消息 |

### Methods

| Method | Signature | Description |
|--------|-----------|-------------|
| `openAndPlay` | `Future<bool> openAndPlay(String path)` | 打开单个文件：路径验证 → 查找/添加 → 播放 |
| `addFiles` | `Future<int> addFiles(List<String> paths)` | 批量添加：路径验证 → 去重 → 自动播放第一个 |

---

## ThumbnailService (class)

**File:** `lib/kernel/services/thumbnail_service.dart`

平台感知的缩略图服务门面。LRU 内存缓存（最大 200 条）。

### Static Methods

| Method | Signature | Description |
|--------|-----------|-------------|
| `getThumbnail` | `Future<ImageProvider?> getThumbnail(String filePath)` | 获取文件的系统缩略图 |
| `evict` | `void evict(String filePath)` | 移除单个缓存条目 |
| `clearCache` | `void clearCache()` | 清空全部缓存 |

### Platform Support

- **Windows:** NoopThumbnailProvider（当前无实现）
- **Linux:** LinuxThumbnailProvider
- **macOS:** MacosThumbnailProvider

---

## PathValidator (class)

**File:** `lib/kernel/services/path_validator.dart`

路径安全校验工具。

### Static Properties

| Property | Type | Description |
|----------|------|-------------|
| `supportedExtensions` | `List<String>` | 支持的扩展名列表（不含点号，小写） |
| `allowedExtensions` | `Set<String>` | 允许的扩展名集合 |

### Static Methods

| Method | Signature | Description |
|--------|-----------|-------------|
| `isUrl` | `bool isUrl(String path)` | 检查是否为 URL |
| `isAllowedMedia` | `bool isAllowedMedia(String path)` | 检查扩展名是否允许 |
| `isPathTraversal` | `bool isPathTraversal(String path)` | 检查路径遍历攻击 |
| `validate` | `String? validate(String path)` | 完整校验，null = 合法 |
| `filterValid` | `List<String> filterValid(List<String> paths)` | 批量校验，返回通过的路径 |

### Supported Extensions

mp4, mkv, avi, mov, flv, m4v, wmv, webm, ts, mpeg, mpg, 3gp, ogv, vob, rmvb, mp3, flac, wav, aac, ogg, opus, m4a, wma, ape, alac, aiff

### URL Schemes

http://, https://, rtmp://, rtsp://, srt://, udp://, tcp://
