# 06 — 测试策略

> 测试体系、FakeEngine 模式、目录结构、覆盖现状与建议。

## 测试文件清单

项目共 33 个测试文件，分布在 4 个目录：

```
test/
├── helpers/                          # 测试替身
│   └── fake_engine.dart              (354 行)
├── kernel/                           # 内核层测试 (17 文件)
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
│   ├── playlist/
│   │   └── playlist_test.dart
│   ├── services/
│   │   ├── external_subtitle_test.dart
│   │   ├── file_operations_test.dart
│   │   ├── path_validator_test.dart
│   │   ├── playback_controller_test.dart
│   │   ├── playback_navigator_test.dart
│   │   ├── state_monitor_test.dart
│   │   └── video_processing_service_test.dart
│   └── window/
│       └── aspect_ratio_service_test.dart
├── unit/                             # 单元测试 (2 文件)
│   ├── kernel/engine/
│   │   └── media_engine_extension_test.dart
│   └── perf/
│       └── startup_parallel_init_test.dart
├── widget/                           # 控件测试 (6 文件)
│   ├── player/
│   │   ├── auto_hide_controller_test.dart
│   │   ├── control_bar_test.dart
│   │   ├── controls_overlay_test.dart
│   │   ├── osd_overlay_test.dart
│   │   ├── video_surface_test.dart
│   │   └── volume_controls_test.dart
│   └── window/
│       └── custom_title_bar_test.dart
└── window/                           # 窗口层测试 (3 文件)
    ├── geometry_store_test.dart      (244 行)
    ├── window_service_test.dart      (195 行)
    └── window_shell_test.dart        (80 行)
```

**统计:**

| 分类 | 文件数 | 说明 |
|------|--------|------|
| 内核层 | 17 | engine/models/persistence/playlist/services/window |
| 单元测试 | 2 | 扩展方法/性能 |
| 控件测试 | 7 | player/window 控件 |
| 窗口测试 | 3 | geometry/window_service/window_shell |
| 测试替身 | 1 | FakeEngine |
| **合计** | **30** | (不含 helpers) |

## FakeEngine 测试替身模式

项目采用**手写 Fake** 而非 Mockito，核心测试替身是 `FakeEngine`：

```dart
/// test/helpers/fake_engine.dart (354 行)
class FakeEngine implements MediaEngine {
  // ─── ValueNotifier 字段 (与 FvpEngine 一致) ───
  final ValueNotifier<int?> textureId = ValueNotifier<int?>(null);
  final ValueNotifier<MediaState> state = ValueNotifier<MediaState>(MediaState.idle);
  final ValueNotifier<int> position = ValueNotifier<int>(0);
  final ValueNotifier<int> duration = ValueNotifier<int>(0);
  final ValueNotifier<double> volume = ValueNotifier<double>(1.0);
  // ... 12 个 ValueNotifier 总计

  // ─── 调用追踪 (测试内省) ───
  int openCallCount = 0;
  int playCallCount = 0;
  int pauseCallCount = 0;
  final List<String> openPaths = [];
  String? failNextOpenWith;  // 模拟失败

  // ─── 测试辅助方法 ───
  void configureMedia({int durationMs = 60000, ...});
  void simulateError(String message);
  void simulateCompleted();
  void simulateBuffering(bool buffering);
}
```

**设计要点:**
- 实现完整 `MediaEngine` 接口 — 无 FFI、无平台插件
- 所有 ValueNotifier 与 FvpEngine 默认值一致
- `openCallCount` / `playCallCount` 等追踪字段支持断言
- `failNextOpenWith` 一次性错误注入
- `configureMedia()` 预配置 duration/tracks

**使用模式:**

```dart
test('playback controller opens file and starts playing', () async {
  final engine = FakeEngine();
  engine.configureMedia(durationMs: 120000);

  final controller = PlaybackController(engine: engine);
  await controller.open('/path/to/video.mp4');

  expect(engine.openCallCount, 1);
  expect(engine.openPaths, ['/path/to/video.mp4']);
  expect(engine.state.value, MediaState.playing);
});
```

## 测试分类

### 内核层测试 (17 文件)

| 测试文件 | 覆盖目标 | 测试类型 |
|----------|---------|---------|
| `fvp_callback_handler_test.dart` | MDK 回调处理 | 单元 |
| `position_poller_test.dart` | 定时轮询器 | 单元 |
| `track_manager_test.dart` | 音轨/字幕轨管理 | 单元 |
| `aspect_ratio_mode_test.dart` | 宽高比枚举 | 单元 |
| `media_info_test.dart` | 媒体信息模型 | 单元 |
| `player_error_test.dart` | 错误类型 | 单元 |
| `playlist_item_test.dart` | 播放列表项 | 单元 |
| `playlist_store_test.dart` | 播放列表持久化 | 集成 |
| `settings_store_test.dart` | 设置持久化 | 集成 |
| `playlist_test.dart` | 播放列表逻辑 | 单元 |
| `external_subtitle_test.dart` | 外挂字幕 | 单元 |
| `file_operations_test.dart` | 文件操作 | 单元 |
| `path_validator_test.dart` | 路径验证 | 单元 |
| `playback_controller_test.dart` | 播放控制器 | 集成 |
| `playback_navigator_test.dart` | 曲目导航 | 单元 |
| `state_monitor_test.dart` | 状态监控 | 单元 |
| `video_processing_service_test.dart` | 视频处理服务 | 单元 |

### 控件测试 (7 文件)

| 测试文件 | 覆盖目标 |
|----------|---------|
| `auto_hide_controller_test.dart` | 自动隐藏定时器 |
| `control_bar_test.dart` | 底部控制栏 |
| `controls_overlay_test.dart` | 控制覆盖层 |
| `osd_overlay_test.dart` | OSD 浮动提示 |
| `video_surface_test.dart` | 纹理渲染表面 |
| `volume_controls_test.dart` | 音量控件 |
| `custom_title_bar_test.dart` | 自定义标题栏 |

### 窗口测试 (3 文件)

| 测试文件 | 行数 | 覆盖目标 |
|----------|------|---------|
| `geometry_store_test.dart` | 244 | 窗口几何持久化 |
| `window_service_test.dart` | 195 | 窗口管理服务 |
| `window_shell_test.dart` | 80 | 窗口 Shell |

## 现状与缺口

### 已有

- FakeEngine 手写替身 (无 Mockito 依赖)
- 内核层覆盖较好 (17 个测试文件)
- 窗口层基本覆盖 (3 个测试文件)
- 控件层覆盖核心交互 (7 个测试文件)

### 缺失

| 缺失项 | 说明 |
|--------|------|
| 集成测试 | 无 `integration_test/` 目录，无端到端测试 |
| Golden 测试 | 无视觉回归测试 |
| 播放列表面板测试 | `playlist_panel.dart` 无对应测试 |
| 对话框测试 | `settings_dialog.dart` / `media_info_dialog.dart` 无测试 |
| 拖放测试 | `drop_handler.dart` 无测试 |
| Aurora 背景测试 | 动画组件无测试 |
| 性能基准测试 | `startup_parallel_init_test.dart` 存在但覆盖面窄 |

## 测试建议

### 短期 (P0)

1. 为 `PlaybackController` 补充更多边界测试 (空播放列表、单曲循环、随机模式)
2. 为 `KeyboardHandler` 添加按键映射测试

### 中期 (P1)

3. 引入 Golden 测试覆盖 GlassContainer、ControlBar 等视觉关键组件
4. 添加 `playlist_panel.dart` 的控件测试

### 长期 (P2)

5. 建立 `integration_test/` 目录，覆盖核心播放流程
6. 设置 CI 覆盖率门槛 (`flutter test --coverage` + lcov 检查)

## 运行测试

```bash
# 运行全部测试
flutter test

# 运行指定文件
flutter test test/kernel/services/playback_controller_test.dart

# 带覆盖率
flutter test --coverage

# 更新 Golden 文件
flutter test --update-goldens
```
