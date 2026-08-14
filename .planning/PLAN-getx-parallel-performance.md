# GetX 安装与 P0-P3 并行性能优化计划

## 目标

1. 安装 `get`（GetX 官方 Dart 包），但不把现有 `ValueNotifier + ValueListenableBuilder` 架构整体迁移到 GetX。
2. 按 P0 → P3 逐阶段处理 widget rebuild、paint/raster 和 resize/playback 高频路径。
3. 通过 DevTools rebuild stats、frame analysis 与项目现有 `ResizeFrameMetrics` 建立前后可比较证据。
4. 保持 media_kit/libmpv、Video Element identity、fullscreen route、DropHandler、窗口 resize 行为不变。

## 阶段 0：依赖安装

- 使用 `flutter pub add get` 解析当前 Dart/Flutter SDK 兼容的稳定版本。
- 仅修改 `pubspec.yaml` 与 `pubspec.lock`，不在本阶段引入 `GetMaterialApp`、`Obx` 或 GetX controller。
- 记录依赖版本，运行 `flutter analyze` 和最小测试确认安装不会改变现有行为。
- GetX 后续只能作为新增功能的可选 DI/局部响应式工具；现有核心状态不迁移，避免双重响应式系统扩大 rebuild 面。

## Wave 1：可并行的只读与测试准备

### P0-A：PlayerScreen 包装层审计

- 审计 `Row → Expanded → DropHandler` 和单子节点 `Stack` 是否改变约束、拖放命中区域或 Element identity。
- 已删除的 `const SizedBox.shrink()` 作为独立 P0 变更保留，不与其他重构混合。

### P0-B：PlayerScreen 行为基线

- 运行 identity、窗口桥替换、resize accessibility、stop/empty-state 相关测试。
- 确认 `_videoKey`、Video surface、controls 和窗口 resize 热区不被重新挂载。

### P1-A：resize rebuild/frame 采样

- 记录空闲、mode 切换、连续 resize、settle 的 rebuild stats 与 frame analysis。
- 对照 `ResizeFrameMetrics` 的 build/raster/totalSpan P95/P99、jank60/jank30 ratio。

### P2-A：播放状态消费者盘点

- 盘点 position、buffer、duration、playing、volume、mute、rate 的订阅者。
- 识别是否有 position 高频更新扩散到整个 `PlayerVideoControls` 或 ControlBar。

### P3-A/B/C：生产孤儿引用审计

- 审计 `SplashScreen`、`PlaybackStatusOverlay`、`VideoSurface` 及相关测试 seam 的全仓引用。
- 只读阶段不删除文件。

## Wave 2：根据证据运行测试并定位热点

- P1：验证 `isResizing` 是否已局部监听；确认 `Video.filterQuality` 变化不重建 Video identity。
- P2：运行 ControlBar rebuild boundary、ProgressBar source replacement、PlayerVideoControls lifecycle 测试。
- 发现问题时先添加回归测试，再改最小生产代码。
- 若 DevTools 不可直接导出 rebuild stats，则使用可复现操作记录和 `ResizeFrameMetrics`，不伪造指标。

## Wave 3：生产修复，按文件冲突串行

1. P0：仅删除有测试和指标证据支持的零收益包装层。
2. P1：把 resize-only 状态限制在 filterQuality、BackdropFilter/ControlBar 等必要局部节点；不提升为整页 `setState`。
3. P2：缩小 position/buffer/duration/playing/volume/rate 的监听边界；检查 `didUpdateWidget`、deactivate、dispose 的订阅对称性。
4. P3：仅删除确认无生产引用、无测试 seam、无构建引用的孤儿；否则保留并标注文档用途。
5. 额外审查：`PlayerVideoControls` 缓存的 `_controlBarViewModel` 是否在 `widget.actions` 更换后仍引用旧回调；若确认，先补测试再修复。

## 验证门

每个阶段：

```bash
flutter analyze
git diff --check
```

相关测试：

```bash
flutter test test/widget/player/player_screen_stop_empty_state_test.dart
flutter test test/widget/player/player_screen_accessibility_resize_test.dart
flutter test test/widget/player/player_screen_window_bridge_replacement_test.dart
flutter test test/widget/player/player_screen_identity_source_replacement_test.dart
flutter test test/widget/player/player_video_controls_test.dart
flutter test test/widget/player/player_video_controls_lifecycle_test.dart
flutter test test/widget/player/control_bar_rebuild_boundary_test.dart
flutter test test/widget/player/progress_bar_source_replacement_test.dart
```

最终才运行全量 `flutter test`，并区分既有 mdk.dll/FFI headless 失败与本次回归。完成代码修改后执行 Flutter code review；不自动 commit，等待用户明确要求。
