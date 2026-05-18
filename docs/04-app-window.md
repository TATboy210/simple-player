# Simple Player Flutter -- 应用壳层 (App/Window/Localization)

> 应用入口、初始化流程、窗口管理、国际化、遗留兼容层的完整技术分析。

---

## 1. Application Bootstrap Flow (应用启动流程)

### 1.1 入口 (`lib/main.dart`)

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();   // Step 1: Flutter绑定
  fvp.registerWith();                          // Step 2: FVP引擎注册
  final prefs = await SharedPreferences.getInstance();  // Step 3: 持久化
  SettingsStore.prewarm(prefs);                         // Step 4: 设置缓存
  await WindowBootstrap.init(prefs);           // Step 5: 窗口系统
  runApp(App(sharedPreferences: prefs));       // Step 6: Widget树
}
```

**初始化序列 (6步):**

| 步骤 | 操作 | 说明 |
|------|------|------|
| 1 | `WidgetsFlutterBinding.ensureInitialized()` | 创建 `runApp` 前异步操作所需的绑定 |
| 2 | `fvp.registerWith()` | 注册 FVP (FFmpeg-based Video Player) 作为平台视频播放器实现 |
| 3 | `SharedPreferences.getInstance()` | 获取键值持久化单例 |
| 4 | `SettingsStore.prewarm(prefs)` | 同步缓存设置到内存，后续读取零延迟 |
| 5 | `WindowBootstrap.init(prefs)` | 初始化整个窗口管理子系统 |
| 6 | `runApp(App(prefs))` | 启动 widget 树 |

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
_playlistGeneration → _locale → _videoProcessing → _controller → _engine → WindowBridge.I
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
WindowBootstrap.init(prefs)          ← 编排器
    │
    ├──→ WindowService(prefs)        ← 核心服务 (实现 WindowBridge)
    │         │
    │         ├──→ WindowGeometryStore   ← 几何持久化
    │         ├──→ AspectRatioService    ← 画面比例约束
    │         ├──→ window_manager        ← 平台窗口操作
    │         └──→ Win32 FFI             ← WS_THICKFRAME 恢复
    │
    └──→ WindowBridge.inject(service)    ← 内核层桥接
```

---

### 2.2 WindowBootstrap (`lib/window/bootstrap.dart`)

无状态工具类，私有构造函数 (不可实例化)。唯一静态方法 `init(SharedPreferences)` 执行三个操作:

1. 创建 `WindowService(prefs)` 实例
2. 通过 `WindowBridge.inject(service)` 注入到 WindowBridge -- 使窗口服务通过抽象桥接接口对内核层可访问
3. 调用 `service.init()` 执行实际窗口设置

**时序契约:** 必须在 `SharedPreferences.getInstance()` 之后、`runApp()` 之前调用。

---

### 2.3 WindowService (`lib/window/window_service.dart`, ~482行)

中央窗口管理类。实现 `WindowBridge` (来自 `lib/kernel/bridge/window_bridge.dart` 的抽象接口)。

**响应式状态:**

| Notifier | 类型 | 用途 |
|----------|------|------|
| `mode` | `ValueNotifier<WindowMode>` | `windowed` 或 `fullscreen` |
| `isAlwaysOnTop` | `ValueNotifier<bool>` | 置顶状态 |
| `isMaximized` | `ValueNotifier<bool>` | 最大化状态 |
| `isResizing` | `ValueNotifier<bool>` | 调整大小防抖标志 |

**常量:**
- `_minSize = Size(800, 450)` -- 最小窗口尺寸
- `_resizeDebounceMs = 500` -- 调整大小结束事件防抖延迟
- `_channel = MethodChannel('com.simple_player/window')` -- C++原生事件统一通道

#### Win32 FFI 层

文件在顶层打开 `user32.dll` 并查找三个 Win32 函数:
- `GetWindowLongPtrW` -- 读取窗口样式位
- `SetWindowLongPtrW` -- 写入窗口样式位
- `GetForegroundWindow` -- 获取当前 HWND

`_restoreThickFrame()` 函数在 `setAsFrameless()` 剥离后恢复 `WS_THICKFRAME` (0x00040000)。没有这个，Windows 上的 `WM_NCHITTEST` 调整大小边框将不工作。

#### 初始化序列 (`init()`)

```
1. 设置 MethodChannel 处理器 (C++ → Dart 事件)
2. 创建 WindowGeometryStore + 加载保存的几何
3. 钳位几何到可见屏幕范围
4. windowManager.ensureInitialized()
5. 配置 WindowOptions (尺寸, 居中, 黑色背景, 隐藏标题栏, 隐藏窗口按钮)
6. waitUntilReadyToShow 回调:
     ├── setMinimumSize(800, 450)
     ├── setPosition (恢复位置/居中)
     ├── 恢复最大化状态
     ├── setPreventClose(true) ← 拦截关闭以优雅关闭
     ├── setAsFrameless() ← 移除原生标题栏
     ├── _restoreThickFrame() ← Win32 FFI 恢复调整大小边框
     ├── 强制布局重绘 (workaround)
     ├── show() + focus()
     ├── 恢复全屏状态 (如果上次关闭时是全屏)
     └── 注册 _WindowListener
```

#### 全屏管理

使用手动无边框方式 (非 `windowManager.setFullScreen()`，因为对无边框窗口不工作):

**进入全屏:**
1. 保存当前画面比例，解锁约束
2. 缓存窗口模式尺寸和位置
3. 乐观UI更新: `mode.value = WindowMode.fullscreen`
4. 移除阴影，通过 `PlatformDispatcher.instance.views.first` 获取屏幕尺寸
5. 设置位置到 `Offset.zero`，尺寸到屏幕尺寸
6. 持久化全屏状态
7. 失败时: 回滚模式，恢复画面比例

**退出全屏:**
1. 乐观更新: `mode.value = WindowMode.windowed`
2. 恢复缓存的窗口模式尺寸和位置
3. 恢复阴影
4. 恢复保存的画面比例
5. 失败时: 回滚到全屏模式

#### 关闭处理

1. 刷新待处理的几何写入
2. `setPreventClose(false)` 允许实际关闭
3. `windowManager.close()`

#### 调整大小/移动防抖

- `_onResizeStart()` 立即设置 `isResizing = true`
- `_onResizeEnd()` 启动 500ms 防抖计时器，然后设置 `isResizing = false`
- resize-end 和 move 事件都调度持久化

#### C++ → Dart 事件处理

处理来自原生代码的 `onMaximizeChanged` 事件，更新 `isMaximized` 并触发持久化。

#### `_WindowListener` 适配器

路由 `window_manager` 回调到 `WindowService` 方法:

| 回调 | 路由到 |
|------|--------|
| `onWindowClose` | `close()` |
| `onWindowResize` | `_onResizeStart()` |
| `onWindowResized` | `_onResizeEnd()` |
| `onWindowMove/Moved` | `_onMove()` |
| `onWindowMaximize/Unmaximize` | 更新 `isMaximized` + 持久化 |
| `onWindowEnter/LeaveFullScreen` | 更新 `mode` + 保存全屏标志 |

---

### 2.4 WindowGeometryStore (`lib/window/geometry_store.dart`, ~179行)

持久化窗口几何到 `SharedPreferences`，带防抖写入。

**数据类 `WindowGeometry`:**
```
Fields: width, height, x, y, isMaximized, isFullscreen
Computed: position (Offset), size (Size)
```

**SharedPreferences 键:** `windowWidth`, `windowHeight`, `windowX`, `windowY`, `windowIsMaximized`, `windowIsFullscreen`

**默认值:** 1280x720, 位置 (10, 10), 非最大化, 非全屏

**关键方法:**

| 方法 | 行为 |
|------|------|
| `load()` | 从 prefs 返回 `WindowGeometry`，缺失键使用默认值 |
| `hasSavedPosition` | `true` 如果 `windowX` 键存在 (决定首次启动是否居中) |
| `saveDebounced()` | 500ms 防抖，合并快速 resize/move 事件 |
| `saveImmediate()` | 取消防抖，立即写入 (用于离散状态变更如最大化) |
| `saveFullscreen()` | 仅写入全屏布尔值 |
| `flush()` | 取消防抖，等待进行中写入完成 |
| `clampToVisibleBounds()` | 确保窗口至少100px可见；屏幕外则重新居中 |

**并发控制:** 使用 `Completer<void>` 序列化写入。如果写入进行中，`_saveNow` 等待它完成。

---

### 2.5 AspectRatioService (`lib/kernel/window/aspect_ratio_service.dart`)

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
| `cycleRatio()` | 循环: 16:9 → 4:3 → 21:9 → free |
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
  ├── fvp.registerWith()                    // FFmpeg/MDK 平台注册
  ├── SharedPreferences.getInstance()       // 持久化单例
  ├── SettingsStore.prewarm(prefs)          // 同步缓存预热
  ├── WindowBootstrap.init(prefs)           // 窗口系统
  │     ├── WindowService(prefs)
  │     ├── WindowBridge.inject(service)
  │     └── service.init()
  │           ├── WindowGeometryStore → load + clamp
  │           ├── windowManager.ensureInitialized()
  │           └── waitUntilReadyToShow:
  │                 ├── setMinimumSize(800, 450)
  │                 ├── setPosition (恢复/居中)
  │                 ├── setAsFrameless() → _restoreThickFrame()
  │                 ├── show() + focus()
  │                 └── 恢复全屏状态
  └── runApp(App(prefs))
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
| 1 | 两阶段初始化 | `main()` 处理平台级设置；`_AppState._init()` 处理应用级设置。窗口可在引擎完全就绪前显示。 |
| 2 | Bridge模式窗口访问 | 内核层通过 `WindowBridge` 抽象接口访问窗口操作，与 `window/` 实现解耦。 |
| 3 | Win32 FFI无边框窗口 | `setAsFrameless()` 剥离 `WS_THICKFRAME`，FFI调用恢复它。Windows特定workaround。 |
| 4 | 手动无边框全屏 | `windowManager.setFullScreen()` 对无边框窗口不工作，手动设置位置和尺寸。 |
| 5 | 乐观UI+回滚 | 全屏切换和画面比例变更立即更新UI，失败时回滚。 |
| 6 | 防抖持久化 | 窗口几何写入500ms防抖，`Completer` 序列化进行中写入。 |
| 7 | ValueNotifier响应式 | 所有窗口状态使用 ValueNotifier，避免更重的状态管理方案。 |
| 8 | 统一MethodChannel | 单通道 `com.simple_player/window` 处理 C++ ↔ Dart 双向通信。 |
