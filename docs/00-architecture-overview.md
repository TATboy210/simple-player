# Simple Player Flutter -- 全架构概览

> 基于 fvp (MDK/FFmpeg) 的 Flutter 桌面媒体播放器，约 10,800 行 Dart 代码。

---

## 1. 目录结构

```
lib/
├── main.dart                          # 入口 (fvp注册, 窗口初始化)
├── app.dart                           # MaterialApp 壳, 异步初始化
├── kernel/                            # 核心业务逻辑层 (无UI依赖)
│   ├── engine/                        # 媒体引擎抽象 + fvp实现
│   │   ├── media_engine.dart          # 抽象接口 (11个ValueNotifier)
│   │   ├── fvp_engine.dart            # fvp/MDK 具体实现
│   │   ├── fvp_callback_handler.dart  # 原生回调 -> ValueNotifier
│   │   ├── position_poller.dart       # 250ms 位置轮询器
│   │   ├── track_manager.dart         # 音轨/字幕轨管理
│   │   └── engine_prewarm.dart        # 冷启动预热
│   ├── bridge/
│   │   └── window_bridge.dart         # 窗口操作抽象接口
│   ├── models/                        # 数据模型 (纯数据, 零依赖)
│   │   ├── media_state.dart           # 9态播放状态机
│   │   ├── media_error_type.dart      # 错误分类 (4类)
│   │   ├── player_error.dart          # 结构化错误 (11码)
│   │   ├── validation_error.dart      # 路径验证错误 (5类)
│   │   ├── media_info.dart            # 媒体元数据
│   │   ├── aspect_ratio_mode.dart     # 画面比例枚举 (6种)
│   │   ├── play_mode.dart             # 播放模式枚举 (4种)
│   │   ├── video_effect_type.dart     # 视频效果枚举
│   │   └── playlist_item.dart         # 播放列表项
│   ├── persistence/                   # 持久化层
│   │   ├── playlist_store.dart        # 播放列表 JSON (300ms防抖)
│   │   └── settings_store.dart        # SharedPreferences 设置
│   ├── playlist/
│   │   └── playlist.dart              # 播放列表数据模型
│   ├── services/                      # 业务服务层
│   │   ├── playback_controller.dart   # 核心编排器 (3个mixin组合)
│   │   ├── playback_contract.dart     # mixin共享依赖契约
│   │   ├── playback_navigator.dart    # 播放导航 + 世代锁
│   │   ├── file_operations.dart       # 文件打开/批量添加
│   │   ├── state_monitor.dart         # 生命周期/自动续播
│   │   ├── platform_service.dart      # 窗口操作代理
│   │   ├── path_validator.dart        # 路径安全验证
│   │   ├── subtitle_service.dart      # 外挂字幕检测
│   │   └── video_processing_service.dart # 视频处理状态
│   ├── ui/                            # 内核UI组件
│   │   ├── theme/tokens.dart          # 50个设计令牌
│   │   ├── theme/app_theme.dart       # ThemeData 桥接
│   │   └── window/custom_title_bar.dart # 自定义标题栏
│   └── utils/                         # 工具类
│       ├── log.dart                   # 日志 (logger包)
│       ├── motion_utils.dart          # 无障碍动画适配
│       ├── path_utils.dart            # 路径解析
│       └── time_utils.dart            # 时间格式化
├── window/                            # 窗口管理系统
│   ├── bootstrap.dart                 # 启动编排
│   ├── window_service.dart            # 核心窗口服务 (Win32 FFI)
│   ├── geometry_store.dart            # 窗口几何持久化
│   └── aspect_ratio_service.dart      # 画面比例约束
├── ui/                                # Widget层
│   ├── player/                        # 播放器UI
│   │   ├── player_screen.dart         # 主屏幕 (Stack组合)
│   │   ├── control_bar.dart           # 底部毛玻璃控制栏
│   │   ├── controls_overlay.dart      # 手势/动画叠加层
│   │   ├── auto_hide_controller.dart  # 自动隐藏状态机
│   │   ├── center_controls.dart       # 居中播放控制组
│   │   ├── video_surface.dart         # 纹理渲染器
│   │   ├── osd_overlay.dart           # OSD浮动通知
│   │   ├── volume_controls.dart       # 音量按钮
│   │   ├── time_range_display.dart    # 时间显示
│   │   └── playback_speed_button.dart # 倍速按钮 (内嵌control_bar)
│   ├── playlist/                      # 播放列表UI
│   │   ├── playlist_panel.dart        # 右侧面板 (拖拽排序)
│   │   └── recent_files_panel.dart    # 最近播放面板
│   ├── dialogs/                       # 对话框
│   │   ├── settings_dialog.dart       # 设置 (EQ/音轨/视频处理)
│   │   └── media_info_dialog.dart     # 媒体属性
│   └── shared/                        # 共享组件
│       ├── glass_container.dart       # 毛玻璃容器 (3级模糊)
│       ├── glass_icon_button.dart     # 毛玻璃图标按钮
│       ├── aurora_background.dart     # 极光动画背景
│       ├── empty_state.dart           # 空状态品牌页
│       └── app_dialog.dart            # 统一对话框壳
├── l10n/                              # 国际化
│   ├── app_localizations.dart         # 生成的基类
│   ├── app_localizations_en.dart      # 英文
│   └── app_localizations_zh.dart      # 中文
├── models/                            # 遗留兼容模型
│   └── playlist_item.dart             # 旧版播放列表项
└── utils/
    └── time_utils.dart                # 遗留时间工具
```

---

## 2. 分层架构

```
┌─────────────────────────────────────────────────────────┐
│                    App Shell Layer                       │
│  main.dart → App → PlayerScreen                         │
│  初始化顺序: fvp注册 → SharedPreferences → 窗口启动 → runApp │
└───────────────────────┬─────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────┐
│                    Widget Layer (ui/)                     │
│  PlayerScreen (Stack组合)                                │
│  ├── ControlsOverlay (手势 + 自动隐藏)                    │
│  │   ├── ControlBar (进度条, 音量, 倍速, AB循环)           │
│  │   └── CenterGroup (播放/暂停/上下首)                   │
│  ├── VideoSurface (Texture渲染)                          │
│  ├── OsdOverlay (浮动通知)                               │
│  ├── PlaylistPanel (拖拽排序)                             │
│  ├── EmptyState + AuroraBackground (品牌空状态)            │
│  └── CustomTitleBar (毛玻璃标题栏)                        │
└───────────────────────┬─────────────────────────────────┘
                        │ ValueListenableBuilder / Callbacks
┌───────────────────────▼─────────────────────────────────┐
│                 Kernel Services Layer                     │
│  PlaybackController (mixin组合编排器)                     │
│  ├── FileOperations   (文件打开/批量)                     │
│  ├── PlaybackNavigator(导航 + 世代锁)                    │
│  └── StateMonitor     (生命周期/自动续播/持久化)            │
│  VideoProcessingService (7个ValueNotifier)                │
│  SubtitleService      (外挂字幕检测)                      │
│  (UI 直接使用 WindowBridge.I — 无需代理层)                │
│  PathValidator        (路径安全验证)                      │
└───────────────────────┬─────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────┐
│               Kernel Engine/Models Layer                  │
│  MediaEngine (抽象接口: 11个ValueNotifier)                 │
│  FvpEngine   (fvp/MDK实现, 组合3个helper)                 │
│  ├── FvpCallbackHandler (原生回调→ValueNotifier)           │
│  ├── PositionPoller     (250ms轮询)                      │
│  └── TrackManager       (音轨/字幕管理)                   │
│  Models: MediaState, MediaInfo, PlayMode, PlaylistItem... │
└───────────────────────┬─────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────┐
│               Persistence/Window Layer                    │
│  PlaylistStore  (JSON防抖写入 + 原子文件操作)              │
│  SettingsStore  (SharedPreferences, 21个设置字段)          │
│  WindowService  (Win32 FFI, 无边框全屏, 几何持久化)        │
│  AspectRatioService (MethodChannel画面比例约束)            │
│  WindowBridge   (抽象接口 + NoopWindowBridge回退)          │
└─────────────────────────────────────────────────────────┘
```

---

## 3. 核心设计模式

| 模式 | 应用位置 | 说明 |
|------|---------|------|
| **Strategy** | `MediaEngine` / `FvpEngine` | 抽象接口 + 具体实现，支持替换后端 |
| **Mixin Composition** | `PlaybackController` | 3个mixin (FileOperations, Navigator, StateMonitor) 组合编排 |
| **Contract Pattern** | `PlaybackContract` | mixin共享依赖的编译时契约 |
| **Generation Guard** | `PlaybackNavigator` | 世代计数器防止异步竞态 |
| **CQS** | `Playlist.peekNext/Previous` | 命令/查询分离，查询不修改状态 |
| **Debounce** | `PlaylistStore`/`SettingsStore`/`WindowGeometry` | 防抖写入合并快速状态变更 |
| **Atomic Write** | `PlaylistStore._flush` | 先写.tmp再rename，防止损坏 |
| **Null Object** | `NoopWindowBridge` | 空实现回退，避免空指针 |
| **Dependency Injection** | `WindowBridge.inject` | 运行时注入具体实现 |
| **Reactive State** | 全局 `ValueNotifier` | 无Provider/Riverpod/Bloc，纯ValueNotifier |
| **RepaintBoundary** | VideoSurface/ControlsOverlay/Aurora | 重绘隔离，防止GPU浪费 |
| **Optimistic UI + Rollback** | 全屏/画面比例切换 | 先更新UI，失败时回滚 |

---

## 4. 状态管理策略

**全局统一使用 `ValueNotifier` + `ValueListenableBuilder`**，无第三方状态管理库。

### 内核层 ValueNotifier 分布

| 组件 | ValueNotifier 数量 | 说明 |
|------|-------------------|------|
| `MediaEngine` | 11 | textureId, state, position, duration, volume, isMuted, isBuffering, buffered, aspectRatio, errorMessage, playbackSpeed |
| `VideoProcessingService` | 7 | brightness, contrast, saturation, hue, deinterlace, rotation, aspectRatioMode |
| `PlaybackController` | 2 | currentFileName, validationError |
| `AspectRatioService` | 1 | ratioNotifier |
| `WindowBridge/Service` | 4 | mode, isAlwaysOnTop, isMaximized, isResizing |
| `OsdService` | 2 | message, _visible |
| `App._locale` | 1 | locale |

**总计约 28 个 ValueNotifier** 驱动整个应用的响应式UI。

---

## 5. 初始化序列

```
main()
  ├── WidgetsFlutterBinding.ensureInitialized()
  ├── fvp.registerWith()                    // FFmpeg/MDK 平台注册
  ├── SharedPreferences.getInstance()       // 获取持久化单例
  ├── SettingsStore.prewarm(prefs)          // 同步缓存预热
  ├── WindowBootstrap.init(prefs)           // 窗口系统初始化
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
```

---

## 6. 测试覆盖

```
test/
├── helpers/
│   └── fake_engine.dart              # Mock MediaEngine
├── kernel/                           # 内核层单元测试
│   ├── bridge/window_bridge_test.dart
│   ├── engine/
│   │   ├── fvp_callback_handler_test.dart
│   │   ├── position_poller_test.dart
│   │   └── track_manager_test.dart
│   ├── models/
│   │   ├── aspect_ratio_mode_test.dart
│   │   ├── media_info_test.dart
│   │   ├── player_error_test.dart
│   │   └── playlist_item_test.dart
│   ├── persistence/
│   │   ├── playlist_store_test.dart
│   │   └── settings_store_test.dart
│   ├── playlist/playlist_test.dart
│   ├── services/
│   │   ├── external_subtitle_test.dart
│   │   ├── file_operations_test.dart
│   │   ├── path_validator_test.dart
│   │   ├── playback_controller_test.dart
│   │   ├── playback_navigator_test.dart
│   │   ├── state_monitor_test.dart
│   │   └── video_processing_service_test.dart
│   ├── utils/path_utils_test.dart
│   └── window/aspect_ratio_service_test.dart
├── unit/                             # 单元测试
│   ├── kernel/engine/media_engine_extension_test.dart
│   ├── perf/startup_parallel_init_test.dart
│   └── platform_service_test.dart
├── widget/                           # Widget测试
│   ├── player/
│   │   ├── auto_hide_controller_test.dart
│   │   ├── control_bar_test.dart
│   │   ├── controls_overlay_test.dart
│   │   ├── osd_overlay_test.dart
│   │   ├── speed_button_test.dart
│   │   ├── video_surface_test.dart
│   │   └── volume_controls_test.dart
│   └── window/custom_title_bar_test.dart
└── window/                           # 窗口层测试
    ├── aspect_ratio_service_test.dart
    ├── geometry_store_test.dart
    ├── window_service_test.dart
    └── window_shell_test.dart
```

---

## 7. 依赖关系

```yaml
dependencies:
  fvp: ^0.36.2              # FFmpeg/MDK 媒体引擎
  window_manager: ^0.5.1     # 窗口管理
  shared_preferences: ^2.5.5 # 键值持久化
  path_provider: ^2.1.5      # 文件路径
  file_picker: ^11.0.2       # 文件选择器
  desktop_drop: ^0.7.1       # 拖放支持
  logger: ^2.5.0             # 日志
  dynamic_color: ^1.8.1      # 动态色彩
  widgets_easier: ^0.0.10    # UI工具库
  flutter_easy_animations: ^0.0.2 # 动画库
```

---

## 8. 文档索引

| 文档 | 内容 |
|------|------|
| [00-architecture-overview.md](00-architecture-overview.md) | 本文档 - 全架构概览 |
| [01-kernel-engine.md](01-kernel-engine.md) | 内核引擎层: Engine/Bridge/Models |
| [02-kernel-services.md](02-kernel-services.md) | 内核服务层: Services/Persistence/Utils |
| [03-ui-widgets.md](03-ui-widgets.md) | UI层: Widget/Theme/Shared组件 |
| [04-app-window.md](04-app-window.md) | 应用壳层: App/Window/Localization |
| [kernel-architecture.md](kernel-architecture.md) | 早期内核架构文档 |
