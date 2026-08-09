# Widget 重建优化实施计划

## 目标
在不改变现有功能、交互和视觉结构的前提下，降低 `AuroraBackground` 与 `ProgressBar` 的无效 Widget rebuild，重点处理：
- `lib/ui/shared/aurora_background.dart:237`
- `lib/ui/player/progress_bar.dart:329`
- `lib/ui/player/progress_bar.dart:339`
- `lib/ui/player/progress_bar.dart:377`

## 现状与问题
1. `AuroraBackground` 的 ticker 通过 `AnimatedBuilder` 每帧执行 builder，并重新创建 `CustomPaint`；该刷新只需要触发 painter 的 paint，不需要重建 Widget 子树。
2. `ProgressBar` 外层 `AnimatedBuilder` 同时监听 `_barHeightAnimation`，其 builder 会连带重新创建 tooltip subtree；tooltip 不依赖 bar height。
3. `ProgressBar` 的 bar painter 与 tooltip 都读取 `_barListenable`，但 bar painter还依赖高度动画，因此监听边界可以进一步拆开。

## 实施步骤
1. **Aurora painter 直接 repaint**
   - 移除 `AnimatedBuilder` 包裹。
   - 为 `_AuroraPainter` 增加 `repaint` 监听源，并通过 getter/只读回调在 `paint` 时读取最新 `_time`。
   - 在 `CustomPaint` 中保留现有 blob image、noise picture、RepaintBoundary 和 LayoutBuilder 行为。
   - 保持 `_generateBlobImages`、engineState ticker 暂停逻辑及资源释放不变。

2. **ProgressBar 缩小动画监听范围**
   - 用合并监听源让 bar painter 同时响应 `_barListenable` 与 `_barHeightAnimation`。
   - 删除包裹整个 `Stack` 的高度 `AnimatedBuilder`。
   - 保留 tooltip 独立的 `_barListenable` `AnimatedBuilder`，使 hover/drag/position 更新仍即时生效，但 bar height 动画不再重建 tooltip。
   - 保持 `_buildBarLayers` 的 resize cache、seek hold、hover、drag、tooltip 文案和回调行为。
   - 必要时在 `didUpdateWidget` 中同步重建合并监听器并正确 dispose，避免监听旧 notifier 或泄漏。

3. **测试与验证**
   - 先运行现有 Aurora、ProgressBar、ControlBar golden/widget 测试作为回归基线。
   - 为 painter/listener 优化补充或调整 rebuild/paint 断言（只验证减少无效 builder 调用，不改变现有交互断言）。
   - 运行 `flutter analyze`、相关 `flutter test` 和 `git diff --check`。
   - 使用 flutter-code-reviewer、dart-testing 进行独立检查；如分析或测试失败，先修复再结束。

## 风险与约束
- 不恢复或重新接入 `ControlsOverlay`。
- 不改变 `Video.controls → PlayerVideoControls` route。
- 不修改 media_kit 基础能力。
- 不把工作树中的预存修改纳入本次变更。
- 若 `CustomPainter` 的 repaint 回调与图片异步更新存在生命周期边界，必须在 dispose 前停止 ticker，并继续释放现有 `ui.Image`/`ui.Picture` 资源。
