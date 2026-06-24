# Simple Player Flutter -- 应用壳层 (App/Window/Localization)

> 应用入口、初始化流程、窗口管理、国际化、遗留兼容层的完整技术分析。

---

## 1. Application Startup Flow (应用启动流程)

### 1.1 入口 (`lib/main.dart`)

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 并行启动三个独立的 async 操作
  final rustFuture = RustLib.init()...;
  final prefsFuture = SharedPreferences.getInstance();
  final windowFuture = WindowService.instance.initialize();

  unawaited(EnginePrewarm.prewarm());  // fire-and-forget: 预热 MDK 引擎

  final prefs = await prefsFuture;
  SettingsStore.prewarm(prefs);

  await Future.wait([rustFuture, windowFuture]);
  runApp(const App());
}
```

**初始化序列 (并行优化):**

| 阶段 | 操作 | 说明 |
|------|------|------|
| 1 | `WidgetsFlutterBinding.ensureInitialized()` | 创建 `runApp` 前异步操作所需的绑定 |
| 2a | `RustLib.init()` | Rust FFI 桥接初始化 (并行) |
| 2b | `SharedPreferences.getInstance()` | 获取键值持久化单例 (并行) |
| 2c | `WindowService.instance.initialize()` | 窗口系统初始化 (并行) |
| 2d | `EnginePrewarm.prewarm()` | MDK 引擎预热 (fire-and-forget) |
| 3 | `SettingsStore.prewarm(prefs)` | 同步缓存设置到内存 |
| 4 | `await Future.wait(...)` | 等待并行任务完成 |
| 5 | `runApp(App())` | 启动 widget 树 |

---

### 1.2 App Shell (`lib/app.dart`)

`App` 是 `StatefulWidget`，其 `_AppState` 在 widget 树挂载后执行第二波异步初始化。

**关键字段:**

| 字段 | 类型 | 用途 |
|------|------|------|
| `_engine` | `FvpEngine` | 具体媒体引擎 (FFmpeg/MDK包装器) |
| `_playlist` | `Playlist` | 播放列表模型 |
| `_controller` | `PlaybackController` | 编排器 (引擎 + 列表 + 导航) |
| `_locale` | `ValueNotifier<Locale>` | 响应式语言，默认 `zh` |
| `_videoProcessing` | `VideoProcessingService` | 色彩校正、旋转、去隔行 |
| `_playlistGeneration` | `ValueNotifier<int>` | 播放列表UI重建触发计数器 |
| `_ready` | `bool` | 显示加载spinner vs 完整UI的门控 |
| `_isDragHovering` | `bool` | 拖放悬停状态 |

**异步初始化 (`_init()` 方法):**

```dart
Future<void> _init() async {
  final results = await Future.wait([
    _controller.init(),                    // 引擎 + 播放列表加载
    SettingsStore.loadLocale().then(...),  // 语言偏好
    SettingsStore.load(),                  // AppSettings
  ]);
  _videoProcessing = VideoProcessingService(_engine, initialSettings: settings);
  setState(() => _ready = true);
}
```

三个并行 Future 并发执行:
1. `PlaybackController.init()` -- 初始化引擎，加载持久化播放列表状态
2. `SettingsStore.loadLocale()` -- 加载语言偏好 (默认 `zh`)
3. `SettingsStore.load()` -- 加载 `AppSettings` (视频处理参数等)

全部完成后，`VideoProcessingService` 使用加载的设置构建，`_ready` 设为 `true` 触发重建显示完整播放器UI。

**Build方法:**
- `!_ready`: 返回黑色 `Scaffold` + `CircularProgressIndicator`
- `ready`: 返回 `MaterialApp` (暗色主题、locale响应式) + `PlayerScreen` 作为 home

**Dispose顺序 (创建的逆序):**
```
_playlistGeneration → _locale → _videoProcessing → _controller → _engine
```

**文件选择器集成:** `_openFile()` 使用 `FilePicker.pickFiles`，硬编码14种支持扩展名。

**拖放:** `_onFilesDropped` 委托给 `_controller.addFiles(paths)`。`_isDragHovering` 状态通过 PlayerScreen 回调追踪。

---

## 2. Window Management System (窗口管理系统)

窗口管理是 `lib/window/` 中的四组件架构，以 `window_manager` 包为中心，针对 Windows 无边框媒体播放器进行了大量定制。

### 2.1 架构概览

```
main.dart
    │
    ▼
WindowService.instance.initialize()  ← 直接初始化 (并行)
    │
    ├──→ WindowService               ← 核心服务 (singleton)
    │         │
    │         ├──→ AspectRatioService    ← 画面比例约束
    │         ├──→ window_manager        ← 平台窗口操作
    │         └──→ WindowLifecycleBus    ← 窗口事件总线
    │
    └──→ WindowState                 ← 响应式状态 (fullscreen/maximized/focused)
```

---

### 2.2 WindowService (`lib/window/window_service.dart`)

中央窗口管理类 (singleton)。通过 `window_manager` 包操作平台窗口。

**响应式状态 (WindowState):**

| Notifier | 类型 | 用途 |
|----------|------|------|
| `fullscreen` | `ValueNotifier<bool>` | 全屏状态 |
| `alwaysOnTop` | `ValueNotifier<bool>` | 置顶状态 |
| `maximized` | `ValueNotifier<bool>` | 最大化状态 |
| `focused` | `ValueNotifier<bool>` | 焦点状态 |

**事件流:**

| Stream | 类型 | 用途 |
|--------|------|------|
| `onResize` | `Stream<bool>` | resize 开始/结束 |
| `onMove` | `Stream<bool>` | 窗口移动开始/结束 |

**常量 (WindowConstants):**
- `minSize = Size(800, 450)` -- 最小窗口尺寸
- `defaultWidth = 1280` / `defaultHeight = 720` -- 默认窗口尺寸

#### 初始化序列 (`initialize()`)

```
1. windowManager.ensureInitialized()
2. 配置 WindowOptions (尺寸, 居中, 黑色背景, 隐藏标题栏)
3. waitUntilReadyToShow 回调:
     ├── setMinimumSize(800, 450)
     ├── setPreventClose(true) ← 拦截关闭以优雅关闭
     ├── setAsFrameless() ← 移除原生标题栏
     ├── show() + focus()
     └── 注册 _WindowListener
```

#### 全屏管理

通过 `WindowService.setFullscreen(bool)` 调用 `windowManager.setFullScreen()`。
状态由 `_WindowListener.onWindowEnterFullScreen/onWindowLeaveFullScreen` 驱动。

#### 关闭处理

1. `setPreventClose(false)` 允许实际关闭
2. `windowManager.close()`

#### 窗口事件 (WindowLifecycleBus)

resize/move 事件通过 `WindowLifecycleBus` 统一广播:
- `isOperating` notifier: resize 或 move 期间为 true (暂停 BackdropFilter/动画)
- `events` stream: 按类型过滤 (resizeStart/resizeEnd/moveStart/moveEnd)

#### `_WindowListener` 适配器

路由 `window_manager` 回调到 `WindowService` 方法:

| 回调 | 路由到 |
|------|--------|
| `onWindowClose` | `close()` |
| `onWindowResize/Resized` | `_resizeController` + `WindowLifecycleBus` |
| `onWindowMove/Moved` | `_moveController` + `WindowLifecycleBus` |
| `onWindowMaximize/Unmaximize` | `state.maximized` |
| `onWindowEnter/LeaveFullScreen` | `state.fullscreen` |
| `onWindowFocus/Blur` | `state.focused` |
| `onWindowEnter/LeaveFullScreen` | 更新 `mode` + 保存全屏标志 |

---

### 2.3 AspectRatioService (`lib/window/aspect_ratio_service.dart`)

单例服务，通过 `MethodChannel` 到原生 `WM_SIZING` 处理管理窗口画面比例约束。

**MethodChannel:** `com.simple_player/aspect_ratio`

**画面比例值:**

| 值 | 含义 |
|----|------|
| `0.0` | 无约束 (自由调整) |
| `16/9` | 16:9 (默认idle比例) |
| `4/3` | 4:3 |
| `21/9` | 21:9 超宽 |

**关键方法:**

| 方法 | 用途 |
|------|------|
| `setAspectRatio(ratio)` | 通过 MethodChannel 设置约束，乐观更新+失败回滚 |
| `lock16x9()` / `lock4x3()` | 预设比例快捷方式 |
| `matchVideo(ratio)` | 匹配视频原始比例 |
| `unlock()` | 移除约束 (设为0) |
| `currentLabel` | 返回人类可读标签 |

**错误处理:** 原生侧失败时，回滚 `_current` 和 `ratioNotifier.value` 到之前状态。

---

## 3. Localization Architecture (国际化架构)

### 3.1 方式

使用 Flutter 官方 `gen-l10n` 代码生成方式 + ARB 文件。

**生成文件:**
- `lib/l10n/app_localizations.dart` -- 抽象基类 + delegate + lookup
- `lib/l10n/app_localizations_en.dart` -- 英文翻译
- `lib/l10n/app_localizations_zh.dart` -- 中文翻译

**支持语言:** `en` (英文), `zh` (中文)

### 3.2 字符串目录 (~80个键)

| 类别 | 示例键 |
|------|--------|
| 应用标识 | `appTitle`, `brandName`, `emptyStateSubtitle` |
| 文件操作 | `openFile`, `dragHint`, `dragHintIdle` |
| 播放模式 | `playModeNormal`, `playModeLoopAll`, `playModeLoopSingle`, `playModeShuffle` |
| 键盘快捷键 | `shortcutPlayPause`, `shortcutSeek`, `shortcutVolume`, `shortcutFullscreen` |
| 设置 | `settings`, `equalizer`, `audioTrack`, `videoTab` |
| 视频处理 | `brightness`, `contrast`, `saturation`, `hue`, `rotation`, `deinterlace` |
| 传输控制 | `play`, `pause`, `stop`, `rewind10`, `forward10` |
| 窗口控制 | `fullscreen`, `pin`, `unpin`, `minimize`, `maximize` |
| 播放列表 | `playlist`, `playlistEmpty`, `clear`, `playAction`, `properties`, `remove` |
| 媒体信息 | `filePath`, `fileName`, `resolution`, `codec`, `duration` |
| 参数化字符串 | `audioTrackN(int)`, `breakpointAt(String)`, `volumePercent(String)`, `speedLabel(num)`, `minutesAgo(int)` |
| 音量/静音 | `mute`, `unmute`, `volume` |
| 画面比例 | `aspectRatioOriginal`, `aspectRatioStretch`, `aspectRatioCropFill`, `aspectRatioFree` |
| 无障碍 | `progressBar` |

### 3.3 语言切换

在 `_AppState` 中，语言作为 `ValueNotifier<Locale>` 管理 (默认 `zh`)。`MaterialApp` 将内容包装在 `ValueListenableBuilder<Locale>` 中，语言变更响应式传播而无需重建整个 `_AppState`。

---

## 4. Legacy/Compatibility Layer (遗留/兼容层)

### 4.1 旧版 PlaylistItem (`lib/models/playlist_item.dart`)

最小 26 行类，仅两个字段:
- `path` (String, required)
- `name` (String, 从路径通过 `/` 和 `\` 分割派生)

功能: `toJson()`/`fromJson()`，基于 `path` 的相等性。

### 4.2 内核版 PlaylistItem (`lib/kernel/models/playlist_item.dart`)

规范模型 (72行)，显著更丰富:
- `path` (String, required)
- `name` (通过 `PathUtils.basename` 派生)
- `timestamp` (int?, 毫秒时间戳 -- 最后播放时间)
- `positionMs` (int?, 断点位置)
- `durationMs` (int?, 视频总时长)

额外功能: `copyWith()` 不可变历史元数据更新、条件JSON序列化、类型安全 `fromJson`。

内核版将 `PlaylistItem` 和 `HistoryEntry` 概念合并为统一模型。

---

## 5. 完整初始化序列总结

```
main()
  ├── WidgetsFlutterBinding.ensureInitialized()
  ├── 并行启动:
  │     ├── RustLib.init()                   // Rust FFI 桥接
  │     ├── SharedPreferences.getInstance()  // 持久化单例
  │     └── WindowService.instance.initialize() // 窗口系统
  ├── EnginePrewarm.prewarm()               // MDK 预热 (fire-and-forget)
  ├── SettingsStore.prewarm(prefs)          // 同步缓存预热
  ├── await Future.wait([rust, window])
  └── runApp(App())
        └── _AppState._init() [异步]
              ├── Future.wait([
              │     controller.init(),
              │     SettingsStore.loadLocale(),
              │     SettingsStore.load(),
              │   ])
              ├── VideoProcessingService(engine, settings)
              └── setState(_ready = true)
                    └── build() → MaterialApp → PlayerScreen
```

---

## 6. 关键设计决策

| # | 决策 | 原因 |
|---|------|------|
| 1 | 两阶段初始化 | `main()` 处理平台级设置；`_AppState._init()` 处理应用级设置。 |
| 2 | 并行启动 | Rust/SharedPreferences/WindowService 三者并行，总延迟从 Σ→max。 |
| 3 | singleton 窗口服务 | `WindowService.instance` 直接访问，无需 DI 桥接。 |
| 4 | ValueNotifier响应式 | 所有窗口状态使用 ValueNotifier，避免更重的状态管理方案。 |
| 5 | WindowLifecycleBus | 统一 resize/move 事件总线，`isOperating` 驱动 BackdropFilter 暂停。 |
