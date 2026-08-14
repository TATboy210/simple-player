# Widget 重建与绘制性能优化计划（P0→P3）

## 目标

基于 Flutter VM Service/DevTools 的 `rebuild stats`、`frame analysis`，结合项目已有 `ResizeFrameMetrics`，减少无效 widget rebuild 与重复 paint/raster，优先优化窗口 resize 和播放器控制栏高频路径，同时保持 media_kit fullscreen route、Video Element identity、文件拖放和窗口 resize 行为不变。

## 当前基线与约束

- VM Service 已连接：`ws://127.0.0.1:52416/TPAmzG9pr0E=/ws`。
- Marionette 当前没有自定义 VM Service extension，无法直接读取 DevTools 面板统计；需要通过 DevTools `rebuild stats`/`frame analysis` 手动采样，并以 `ResizeFrameMetrics` 的结构化日志作为可重复的代码侧基线。
- 当前运行时为空闲态，主要可见 widget 是标题栏和 `SmartDragToResizeArea` 热区；不能据此判断播放控制层冗余。
- `ResizeFrameMetrics` 已记录 build、raster、totalSpan 的 avg/P50/P95/P99/max 及 60/30fps jank 比例，不新增并行诊断体系。
- 不修改 media_kit 基础能力，不替换 `Video.controls` 全屏复制机制，不破坏测试注入 `videoSurfaceBuilder`/`testVideoControls`。

## 阶段实施

### P0：删除确定性零收益节点，固定高层 rebuild 边界

1. 删除 `lib/ui/player/player_screen.dart` 中 Stack 内仅作为暂时设置入口占位的 `const SizedBox.shrink()`。
2. 核查并在不改变约束传播的前提下简化 `_buildVideoContent` 的单子节点 `Row → Expanded`；暂不盲删 `DropHandler` 内部用于拖放 overlay 的 Stack。
3. 评估 `_buildVideoContent` 的单子节点 `Stack(fit: StackFit.expand)`，只有在 widget/resize/fullscreen 测试证明约束和 Element identity 不变时才删除。
4. 保留 `AnimatedBuilder(mode)`、`RepaintBoundary(video)`、`SmartDragToResizeArea`，因为它们分别承担窗口状态监听、重绘隔离和平台 resize 交互。

验证：

- `flutter analyze`
- PlayerScreen 相关 widget tests、identity/source replacement、accessibility/resize tests
- DevTools 记录空闲、窗口模式切换、resize 三组 rebuild stats
- `ResizeFrameMetrics` 比较 build/raster P95/P99 和 jank 比例

### P1：优化 resize 高频路径

1. 根据 `rebuild stats` 确认 `isResizing` 变化时实际高频重建的 subtree。
2. 保留 `Video.filterQuality` 的局部监听；不把 resize 状态提升到会重建整页的 `setState`。
3. 检查 `PlayerVideoControls`、OSD、ErrorBanner、ControlBar 在 resize 期间是否重复构建；将只需改变绘制策略的节点改成稳定 child + 局部 listenable builder。
4. 维持 resize 期间 BackdropFilter/动画隐藏策略以及 `Video` key/Element identity。

验证：

- resize drag+settle 至少三次，比较 build/raster/total 的 avg/P95/P99、60fps 和 30fps jank ratio。
- DevTools frame analysis 确认 build、raster、shader/BackdropFilter 尖峰没有转移到别的阶段。
- 运行 resize、fullscreen、window bridge replacement 相关测试并实机验证。

### P2：收窄播放期间高频状态监听

1. 对 `PlayerVideoControls` 的 position、buffer、duration、playing、volume、rate 等 stream/listenable 按刷新频率分组。
2. 确保 position 高频更新只重建进度条/时间文本，不触发标题、按钮、OSD 或整个控制栏。
3. 合并真正同频且共享生命周期的 builder；不把低频状态绑定到 position stream。
4. 复用现有 `ValueListenableBuilder2`、`PlayerControlsState` 和 `AutoHideController` 的监听边界，避免新增重复订阅。

验证：

- 播放、暂停、seek、buffering、音量和倍速场景分别采样 rebuild stats。
- 检查 stream 订阅次数、controls state 生命周期和 fullscreen route 复制测试。
- 运行 `player_video_controls_test.dart`、lifecycle/interaction 相关测试。

### P3：清理生产孤儿与低收益 wrapper

1. 确认 `lib/ui/shared/splash_screen.dart` 无生产入口、外部依赖或保留测试职责后删除。
2. 确认 `PlaybackStatusOverlay` 已完全由 `OsdOverlay`/`ErrorBanner` 替代后，连同过期测试一起清理或迁移。
3. 确认 `VideoSurface` 仅是旧渲染路径/测试 seam；若测试仍依赖则保留或明确标注，不直接删除。
4. 最后评估 `_IndeterminateProgress` 等低收益私有 wrapper 是否值得内联；只有能减少实际 rebuild/paint 或显著简化结构时才处理。

验证：

- 全量 `flutter analyze` 与 `flutter test`。
- 检查生产引用、测试引用和编译产物。
- 对比 P0 前后及最终阶段的 DevTools rebuild/frame 指标，避免以代码行数减少冒充性能收益。

## 风险控制

- 每阶段保持小 diff，阶段完成后单独运行验证；不将 P0-P3 混成一次大重构。
- 修改前后保持当前未提交用户改动，不覆盖 `.planning`、性能截图或其他工作文件。
- 所有性能结论必须同时有：源码理由、运行时 rebuild/frame 数据、行为测试结果。
- 如果指标显示 build 已低于预算但 raster/纹理或平台窗口事件占主导，则停止继续做 widget wrapper 清理，转为记录结论而不是过度重构。
