# Simple Player Flutter -- 内核服务层 (Services/Persistence/Utils)

> 播放控制器、服务层、持久化、播放列表、工具类的完整技术分析。

---

## 1. Service Layer Architecture (服务层架构)

### 1.1 PlaybackContract -- Mixin共享依赖契约

**文件:** `lib/kernel/services/playback_contract.dart`

**职责:** 正式化三个 mixin 共享的依赖关系。纯粹作为文档和编译时强制 -- 新 mixin 作者读此文件了解所有前置条件。

**关键 API:**
```dart
abstract class PlaybackContract {
  MediaEngine get engine;
  Playlist get playlist;
  ValueNotifier<String> get currentFileName;
  VoidCallback get onNeedRebuild;
  void Function(Object error)? get onError;
  Future<void> playIndex(int index);
  Future<void> playNext();
  void savePlaylist();
}
```

**设计模式:** 契约 / 接口隔离。

---

### 1.2 PlaybackController -- 核心编排器

**文件:** `lib/kernel/services/playback_controller.dart`

**职责:** 中央编排器类。通过 `with FileOperations, PlaybackNavigator, StateMonitor` 组合三个 mixin。持有共享状态 (engine, playlist, currentFileName, onNeedRebuild, onError) 并实现 `savePlaylist()` 委托给 `PlaylistStore.save()`。

**设计模式:** Mixin 组合 (编排器模式)。类本身极简 -- 所有行为在 mixin 中。这是经典的 "钻石" mixin 模式，具体类提供状态，mixin 提供行为。

---

### 1.3 FileOperations -- 文件操作 Mixin

**文件:** `lib/kernel/services/file_operations.dart`

**职责:** 文件打开和批量添加 mixin。处理单文件打开播放和带验证的批量文件添加。

**关键 API:**
```dart
mixin FileOperations on PlaybackContract {
  ValueNotifier<String?> validationError;  // 最后验证错误
  Future<bool> openAndPlay(String path);   // 验证路径 → 添加到列表 → 播放
  Future<int> addFiles(List<String> paths); // 批量添加，去重，自动播放
}
```

**错误处理:** `openAndPlay` 捕获 `playIndex()` 异常并写入 `validationError`。`addFiles` 捕获并记录自动播放首项时的失败。

---

### 1.4 PlaybackNavigator -- 播放导航 Mixin

**文件:** `lib/kernel/services/playback_navigator.dart`

**职责:** 播放列表导航 mixin -- 索引跳转、下一首/上一首、并发打开守卫。

**关键 API:**
```dart
mixin PlaybackNavigator on PlaybackContract {
  int openGeneration;           // 世代计数器
  int get currentGeneration;    // 暴露给UI用于异步回调过时检查
  Future<void> playIndex(int index); // 完整播放周期
  Future<void> playNext();
  Future<void> playPrevious();
}
```

**设计模式 -- 世代并发守卫:**

每次调用 `playIndex` 递增 `openGeneration`。异步 `engine.open()` 后检查世代是否仍匹配 -- 不匹配则丢弃结果。防止快速切歌时的过时异步完成污染状态。

```
playIndex(0) → generation=1 → open() → [等待]
playIndex(1) → generation=2 → open() → [等待]
[generation=1完成] → 1 != 2 → 丢弃 ✓
[generation=2完成] → 2 == 2 → 接受 ✓
```

**安全:** 每个路径通过 `PathValidator.validate()` 验证后才传给引擎，防止播放列表注入的路径遍历攻击。

**功能集成:**
- FEAT-01: 从保存位置恢复 (阈值 > 1秒)
- FEAT-03: 自动检测同目录外挂字幕文件

---

### 1.5 StateMonitor -- 生命周期 Mixin

**文件:** `lib/kernel/services/state_monitor.dart`

**职责:** 生命周期和响应式行为 mixin -- 完成后自动续播、暂停时断点保存、初始化时设置恢复、播放列表管理操作。

**关键 API:**
```dart
mixin StateMonitor on PlaybackContract {
  Future<void> init();           // 恢复设置 (音量, 静音)
  void dispose();                // 保存断点位置、音量、静音、播放模式
  Future<void> removeAt(int index); // 移除轨道，自动续播
  void reorder(int oldIndex, int newIndex); // 拖拽重排
  void clearPlaylist();          // 停止引擎，清空列表
  void togglePlayMode();         // 循环播放模式
}
```

**状态管理:**
- 监听 `engine.state` ValueNotifier
- `MediaState.playing`: 锁定画面比例到视频原始比例
- `MediaState.stopped/idle/completed/error`: 解锁画面比例
- `MediaState.paused`: 保存断点位置 (positionMs + durationMs)
- `MediaState.completed`: 根据播放模式自动续播

---

## 2. Platform Integration (平台集成)

### 2.1 WindowService -- 窗口操作

**文件:** `lib/window/window_service.dart`

**职责:** 窗口管理操作的 singleton。UI 代码通过 `WindowService.instance` 访问窗口状态和操作。

**关键 API:**
```dart
// 窗口操作
minimize(), toggleMaximize(), restore(), close(), startDragging()
setAlwaysOnTop(bool)

// 响应式状态 (WindowState)
ValueNotifier<bool> maximized, alwaysOnTop, focused

// 事件流
Stream<bool> onResize, onMove
```

---

### 2.2 PathValidator -- 路径安全验证

**文件:** `lib/kernel/services/path_validator.dart`

**职责:** 统一的路径安全验证 -- 扩展名白名单和路径遍历检测。所有文件打开入口 (FilePicker, 拖放, 历史) 必须通过此验证器。

**关键 API:**
```dart
static const supportedExtensions;  // 25种媒体扩展名
static bool isUrl(String path);           // http/https/rtmp/rtsp
static bool isAllowedMedia(String path);  // 扩展名白名单
static bool isPathTraversal(String path); // 路径遍历检测
static String? validate(String path);     // 完整验证
static List<String> filterValid(List<String> paths); // 批量过滤
```

**安全:** 全面的路径遍历保护。检测 `../`, `..\\`, 空字节, UNC路径, `~` 扩展。故意不标记裸 `..` 以避免合法文件名的误报。

---

## 3. Media Services (媒体服务)

### 3.1 SubtitleService -- 外挂字幕检测

**文件:** `lib/kernel/services/subtitle_service.dart`

**职责:** 外挂字幕自动检测和管理。从 PlaybackNavigator 提取以提高可扩展性。

**支持格式 (7种):** `.srt`, `.ass`, `.ssa`, `.sub`, `.vtt`, `.idx`, `.sup`

**匹配逻辑:** 匹配与媒体文件同名的文件，包括语言标记变体 (如 `movie.en.srt` 匹配 `movie.mp4`)。

---

### 3.2 VideoProcessingService -- 视频处理状态管理器

**文件:** `lib/kernel/services/video_processing_service.dart`

**职责:** 响应式视频处理状态管理器。持有 7 个 `ValueNotifier` 实例用于视频效果，委托变更给 `MediaEngine`。

**ValueNotifier:**
```dart
brightness [-1.0, 1.0], default 0.0
contrast   [-1.0, 1.0], default 0.0
saturation [-1.0, 1.0], default 0.0
hue        [-1.0, 1.0], default 0.0
deinterlaceEnabled (bool), default false
rotation   (0/90/180/270), default 0
aspectRatioMode (AspectRatioMode), default keepOriginal
```

**设计模式:** 响应式委托 + 防抖持久化。每个 ValueNotifier 有两个监听器:
1. 引擎委托监听器 -- 调用对应的 `MediaEngine` 方法
2. 持久化监听器 -- 50ms 防抖保存到 `SettingsStore`

---

## 4. Persistence Layer (持久化层)

### 4.1 PlaylistStore -- 播放列表 JSON 持久化

**文件:** `lib/kernel/persistence/playlist_store.dart`

**职责:** 播放列表 JSON 持久化，带防抖写入和原子文件操作。

**关键 API:**
```dart
static void save(Playlist playlist);          // 300ms防抖
static Future<Playlist?> load();              // 加载 + 自动迁移旧history.json
static Future<void> clear();                  // 删除文件
static Future<void> dispose();                // 刷新待处理写入
```

**设计模式:**

| 模式 | 说明 |
|------|------|
| **防抖写入** | 300ms debounce 合并快速 save() 调用 |
| **JSON快照** | save() 时立即序列化为字符串快照 |
| **原子写入** | 先写 `.tmp` 文件，再原子 rename |
| **写入序列化** | `_writeInFlight` Future 防止并发 `_flush()` |
| **历史迁移** | 一次性合并旧 `history.json` 数据 |

---

### 4.2 SettingsStore -- 应用设置持久化

**文件:** `lib/kernel/persistence/settings_store.dart`

**职责:** 通过 `shared_preferences` 持久化应用设置。覆盖窗口几何、播放状态、字幕偏好、视频处理设置和语言。

**关键 API:**
```dart
static void prewarm(SharedPreferences prefs);  // 缓存实例
static Future<AppSettings> load();             // 加载全部设置
// 个别保存方法:
saveVolume(), saveLastFile(), saveWindowGeometry(), savePlayMode()
saveIsMuted(), saveIsAlwaysOnTop()
saveSubtitleFontSize(), saveSubtitleColorIndex(), saveSubtitleBottomOffset()
saveVideoBrightness/Contrast/Saturation/Hue/Rotation/AspectRatioIndex/Deinterlace()
saveLocale()
static Future<void> saveAll(AppSettings s);    // 批量保存
```

**AppSettings 数据类 (20个字段):**
```
volume, lastFile, windowWidth/Height/X/Y, isMaximized,
playMode, isMuted, isAlwaysOnTop,
subtitleFontSize, subtitleColorIndex, subtitleBottomOffset,
videoBrightness/Contrast/Saturation/Hue/Rotation/AspectRatioIndex/Deinterlace,
locale
```

**设计模式:**
- **预热缓存:** `SharedPreferences` 实例通过 `prewarm()` 缓存
- **通用保存助手:** `_save` 泛型方法消除 try-catch 样板
- **输入净化:** `_sanitizeDimension()` 和 `_sanitizeCoordinate()` 防止 NaN/Infinity/负值
- **顺序写入:** `saveWindowGeometry()` 使用顺序 `await` 保证数据一致性

---

## 5. Playlist Management (播放列表管理)

### 5.1 Playlist -- 核心数据模型

**文件:** `lib/kernel/playlist/playlist.dart`

**职责:** 有序项目列表、当前索引追踪、4种播放模式导航、JSON序列化。

**关键 API:**
```dart
// 查询
List<PlaylistItem> get items;        // List.unmodifiable (防御性副本)
PlaylistItem? get current;           // 当前项
bool get hasNext/hasPrevious;        // 模式感知导航可用性
int peekNext() / peekPrevious();     // 纯查询，不修改状态 (CQS)

// 命令
int add(String path);                // 添加路径，返回新索引
int addItem(PlaylistItem item);      // 添加完整项 (持久化恢复)
void addAll(List<String> paths);     // 批量添加
bool removeAt(int index);            // 移除 + 索引调整
void reorder(int old, int new);      // 拖拽重排
void clear();                        // 重置为空

// 历史
void updateHistory(int index, {positionMs, durationMs}); // 设置时间戳+位置
void updatePosition(int index, positionMs, durationMs);  // 断点保存

// 序列化
toJson() / Playlist.fromJson()
```

**4种播放模式:**

| 模式 | 行为 |
|------|------|
| `normal` | 顺序播放，到末尾停止 |
| `loopAll` | 到达两端时环绕 |
| `loopSingle` | 重播当前轨道 |
| `shuffle` | 随机选择，排除当前轨道 |

**CQS 设计决策:** `peekNext()` 和 `peekPrevious()` 是纯查询，返回索引但不修改 `_currentIndex`。调用者显式设置 `currentIndex`。这是从早期 `next()/previous()` 同时返回值和修改状态的设计中有意重构的。

**removeAt 索引调整规则:**
- 删除当前之前: `currentIndex--`
- 删除当前: 钳位到下一个 (或最后一个)
- 列表为空: `currentIndex = -1`

---

## 6. Utilities (工具类)

### 6.1 Log -- 日志

**文件:** `lib/kernel/utils/log.dart`

`PrettyPrinter` 配置: `methodCount: 0`, `errorMethodCount: 4`, `lineLength: 100`, 无emoji, 仅时间格式。仅在 debug 模式记录。

### 6.2 MotionUtils -- 无障碍动画适配

**文件:** `lib/kernel/utils/motion_utils.dart`

当系统启用 `AccessibilityFeatures.disableAnimations` 时，返回零时长/线性曲线值。

```dart
static void update(bool disableAnimations);
static Duration duration(Duration original);   // reduced motion → Duration.zero
static Curve curve(Curve original);            // reduced motion → Curves.linear
static bool get isReducedMotion;
```

### 6.3 PathUtils -- 路径工具

**文件:** `lib/kernel/utils/path_utils.dart`

统一文件路径工具函数，替代4个不一致的 split 实现。

```dart
static String basename(String path);  // 提取文件名，支持 Unix/Windows/混合分隔符
static String dirname(String path);   // 提取目录路径
```

**实现:** 单次反向扫描使用 `codeUnitAt()` 检测分隔符 (0x2F=`/`, 0x5C=`\`)。避免基于 split 的中间列表分配。

### 6.4 TimeUtils -- 时间格式化

**文件:** `lib/kernel/utils/time_utils.dart`

```dart
String formatMs(int ms);  // HH:MM:SS (有小时时) 或 MM:SS
```

---

## 7. Window Services (窗口服务)

### 7.1 AspectRatioService -- 窗口画面比例约束

**文件:** `lib/kernel/window/aspect_ratio_service.dart`

通过原生 MethodChannel (`WM_SIZING` on Windows) 管理窗口画面比例约束。

```dart
static final AspectRatioService I;  // 单例
double get current;                  // 当前比例 (0=无约束)
ValueNotifier<double> ratioNotifier; // UI重建通知器
Future<void> setAspectRatio(double ratio);
Future<void> lock16x9() / lock4x3();
Future<void> matchVideo(double ratio);
Future<void> unlock();
Future<void> cycleRatio();           // 16:9 → 4:3 → 21:9 → free → 16:9
String get currentLabel;
```

**错误处理 (RC-6):** MethodChannel 失败时，回滚到之前的比例值。

---

## 8. 服务依赖图

```
PlaybackController (编排器)
  ├── with FileOperations
  │     ├── PathValidator (验证)
  │     ├── MediaEngine (播放)
  │     └── Playlist (数据)
  │
  ├── with PlaybackNavigator
  │     ├── PathValidator (安全)
  │     ├── PathUtils (basename)
  │     ├── MediaEngine (open/play/seek)
  │     └── Playlist (导航)
  │
  ├── with StateMonitor
  │     ├── MediaEngine (状态监听)
  │     ├── Playlist (修改)
  │     ├── PlaylistStore (持久化)
  │     ├── SettingsStore (设置恢复/保存)
  │     └── AspectRatioService (窗口比例)
  │
  └── PlaylistStore.save() ← savePlaylist()

VideoProcessingService
  ├── MediaEngine (视频效果)
  └── SettingsStore (持久化)

SubtitleService
  ├── MediaEngine (字幕加载)
  └── PathUtils (路径解析)

AspectRatioService
  ├── MethodChannel (原生窗口)
  └── AspectRatioMode (枚举)

SettingsStore
  ├── SharedPreferences (平台存储)
  └── PlayMode, AspectRatioMode (枚举)

PlaylistStore
  ├── Playlist (序列化)
  └── path_provider (文件系统)

WindowService (窗口操作, singleton)
  ├── window_manager (平台窗口)
  ├── AspectRatioService (画面比例)
  └── WindowLifecycleBus (事件总线)
```

---

## 9. 关键设计模式汇总

| 模式 | 组件 | 说明 |
|------|------|------|
| Mixin组合 | PlaybackController | 3个mixin (FileOperations, Navigator, StateMonitor) 分解关注点 |
| 契约模式 | PlaybackContract | mixin共享依赖的编译时契约 |
| 世代并发守卫 | PlaybackNavigator | 整数世代计数器处理快速切歌 |
| CQS | Playlist | peekNext/Previous 纯查询不修改状态 |
| 防抖持久化 | PlaylistStore(300ms), VideoProcessing(50ms) | 合并快速状态变更为单次磁盘写入 |
| 原子文件写入 | PlaylistStore._flush | 先写.tmp再rename |
| Singleton 窗口服务 | WindowService.instance | 直接访问，无 DI 桥接 |
| 响应式ValueNotifier | 全局 | 无外部状态管理包 |
| 防御性序列化 | Playlist.fromJson, SettingsStore.load | 钳位索引、跳过损坏项、回退默认值 |
| 输入安全 | PathValidator | 扩展名白名单 + 路径遍历防护 |
