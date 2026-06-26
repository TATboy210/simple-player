# Phase 2: 渲染管线优化 — 执行计划

**目标**: 减少非关键更新对渲染管线的干扰
**依赖**: Phase 16（RepaintBoundary 隔离、VLB 扁平化）
**需求**: R2-1, R2-2, R2-3, R2-4
**风险**: 中（涉及 kernel 层轮询 + UI 层信号传递）

## 成功标准

| 需求 | 标准 | 验证方式 |
|------|------|----------|
| R2-1 | PositionPoller 静默模式 500ms + resize 暂停 | 单元测试 + 代码审查 |
| R2-2 | Snapshot Debounce 与 resize 无耦合 | 代码审查（验证任务） |
| R2-3 | Texture 零拷贝路径确认 | 代码审查（验证任务） |
| R2-4 | resize 期间 ProgressBar/OsdOverlay 跳过 rebuild | Widget 测试 + DevTools |
| 总体 | resize 期间 CPU 占用下降 >30% | DevTools CPU Profiler |

## R2-2 已验证（跳过）

Snapshot Debounce 在 `SettingsStore`/`PlaylistStore` 的 Timer 逻辑中，与 resize 事件完全无关。无需改动。

## R2-3 已验证（跳过）

fvp 使用 DXGI_SHARED_HANDLE 共享纹理，`CopyResource` 是 GPU-to-GPU 拷贝（非 CPU 拷贝）。Flutter 通过 shared handle 读取纹理，无 CPU 参与。当前路径已是零 CPU 拷贝，无需改动。

## 架构决策

**D-01: PositionPoller 自适应策略**
- 静默模式: 正常播放无交互时降频到 500ms（当前固定 250ms）
- seek 后快速轮询 100ms 保持不变
- 新增 `startSilent()` 方法，3 秒后自动进入静默模式
- resize 期间完全暂停轮询（复用 seeking setter 模式）

**D-02: UI 层冻结而非 Poller 暂停**
- resize 期间不暂停 PositionPoller（避免进度条冻结/跳变）
- ProgressBar/OsdOverlay/TimeRangeDisplay 在 `isResizing=true` 时跳过 rebuild
- PositionPoller 继续更新 ValueNotifier（低成本），UI 层忽略更新
- resize 结束后自然读取最新位置，无跳变

**D-03: 扩展已有 isResizing 信号链**
- 不新建 resize 检测机制，复用 `WindowService.isResizing`
- 信号路径: WindowService → PlayerScreen → FvpEngine(pausePolling) + ControlsOverlay → ProgressBar/OsdOverlay
- 现有 ControlBar/GlassContainer 的 resize 优化保持不变

---

## Task 1: PositionPoller 自适应轮询 + resize 暂停

**文件**:
- `lib/kernel/engine/position_poller.dart` (119 行) — 主改动
- `lib/kernel/engine/fvp_engine.dart` (724 行) — 暴露 pausePolling/resumePolling

**改动详情**:

### position_poller.dart

1. 新增常量 `_silentPollMs = 500`（静默模式轮询间隔）
2. 新增状态 `_resizing = false`
3. 新增 `set resizing(bool value)` — 复用 seeking setter 模式:
   - `true` → 取消定时器，暂停轮询
   - false → 恢复轮询（使用 `_currentIntervalMs`）
4. 新增 `startSilent()` — 启动轮询 + 延迟 3 秒进入静默模式:
   - 调用 `start()` 启动 250ms 轮询
   - 设置 Timer 3 秒后调用 `_updateInterval(_silentPollMs)`
5. 修改 `_poll()` — 添加 `if (_resizing) return` 守卫（第 105 行）
6. 修改 `seeking` setter — seek 完成后重置静默模式 Timer:
   - 在 `setActive()` 调用后，取消静默 Timer 并重新设置 3 秒延迟

### fvp_engine.dart

1. 新增 `void pausePolling()` — 调用 `_positionPoller.resizing = true`
2. 新增 `void resumePolling()` — 调用 `_positionPoller.resizing = false`
3. 修改 `play()` 方法（第 413-424 行）— 使用 `_positionPoller.startSilent()` 替代 `_positionPoller.start()`:
   - 视频播放时自动进入静默模式（500ms），减少 FFI 调用
   - seek 后自动恢复快速轮询（已有逻辑）

**测试**:
- `test/kernel/engine/position_poller_test.dart` — 新增测试:
  - `resizing=true` 时 `_poll()` 不执行
  - `resizing=false` 后轮询恢复
  - `startSilent()` 启动后 3 秒切换到 500ms 间隔
  - seeking 期间 resizing 不冲突

**验证**: `flutter test test/kernel/engine/position_poller_test.dart`

---

## Task 2: UI 层 resize 期间冻结非关键 rebuild

**文件**:
- `lib/ui/player/progress_bar.dart` (434 行) — 添加 resizing 参数
- `lib/ui/shared/osd_overlay.dart` (155 行) — 添加 resizing 参数
- `lib/ui/player/controls_overlay.dart` (195 行) — 传递 resizing 到 OsdOverlay
- `lib/ui/player/player_screen.dart` — 监听 isResizing，调用 engine.pausePolling/resumePolling

**改动详情**:

### progress_bar.dart

1. 添加 `final ValueListenable<bool>? resizing` 参数到 ProgressBar 构造函数
2. 在 `_buildBarLayers()` 方法中（第 276-299 行），用 `AnimatedBuilder` 包裹:
   - 监听 `resizing` notifier
   - `resizing.value == true` 时返回缓存的上一帧（不 rebuild AnimatedBuilder 内部）
   - `resizing.value == false` 时正常 rebuild
3. 实现方式: 将现有的 `AnimatedBuilder(animation: _barListenable, ...)` 包裹在 `AnimatedBuilder(animation: resizing, ...)` 中，resizing 时跳过内部 rebuild

### osd_overlay.dart

1. OsdOverlay 改为 `StatefulWidget`（当前是 StatelessWidget）
2. 添加 `final ValueListenable<bool>? resizing` 参数
3. 在 `build()` 中监听 resizing:
   - `resizing.value == true` 时返回缓存的上一帧（不 rebuild ValueListenableBuilder）
   - `resizing.value == false` 时正常 rebuild
4. 实现方式: 用 `AnimatedBuilder` 包裹现有 `ValueListenableBuilder`，resizing 时返回 child 缓存

### controls_overlay.dart

1. 在 `build()` 方法中（第 112-195 行），将 `widget.resizing` 传递给 OsdOverlay:
   - `OsdOverlay(resizing: widget.resizing)`（当前第 153 行无 resizing 参数）

### player_screen.dart

1. 在 `initState()` 中监听 `widget.windowService.isResizing`:
   - `isResizing.value == true` → `widget.engine.pausePolling()`
   - `isResizing.value == false` → `widget.engine.resumePolling()`
2. 在 `dispose()` 中移除监听
3. 确保 ControlsOverlay 已传递 resizing（当前第 279 行已有）

**测试**:
- `test/widget/player/progress_bar_test.dart` — 新增测试:
  - `resizing=true` 时不触发 CustomPaint rebuild
  - `resizing=false` 后恢复正常 rebuild
- `test/widget/player/osd_overlay_test.dart` — 新增测试:
  - `resizing=true` 时 OsdOverlay 保持上一帧
  - `resizing=false` 后显示最新 message

**验证**:
```bash
flutter test test/widget/player/progress_bar_test.dart test/widget/player/osd_overlay_test.dart
```

---

## 执行顺序

```
Task 1 (kernel 层) ──→ Task 2 (UI 层)
```

Task 1 先完成（PositionPoller 新增 API），Task 2 依赖 Task 1 的 `pausePolling`/`resumePolling` API。

---

## 风险缓解

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| PositionPoller 暂停导致 mdk 内部状态异常 | 低 | 高 | 暂停只取消 Timer，不修改 mdk.Player 状态。resume 后立即 `_poll()` 一次获取最新位置 |
| UI 冻结导致进度条跳变 | 低 | 中 | D-02 策略: PositionPoller 继续更新 ValueNotifier，UI 层跳过 rebuild。resize 结束后自然读取最新值 |
| OSD 消息丢失 | 低 | 低 | 只冻结 UI rebuild，不冻结 OsdService Timer。resize 结束后 OsdOverlay 读取当前 message |
| 静默模式影响 seek 响应 | 低 | 低 | seek 完成后自动切换到 100ms 快速轮询（已有逻辑），不受静默模式影响 |

---

## 验证计划

### 自动化验证

```bash
# 单元测试
flutter test test/kernel/engine/position_poller_test.dart

# Widget 测试
flutter test test/widget/player/progress_bar_test.dart test/widget/player/osd_overlay_test.dart

# 全量回归
flutter test
```

### 手动验证

1. 打开 4K 视频播放
2. 持续拖拽窗口边缘 10 秒
3. DevTools CPU Profiler 对比:
   - 优化前: 记录 resize 期间 CPU baseline
   - 优化后: 确认 CPU 下降 >30%
4. 验证 resize 结束后进度条位置正确（无跳变）
5. 验证 resize 期间按音量键，resize 结束后 OSD 显示

---

## 输出

完成后创建 `.planning/phases/2-rendering-pipeline/SUMMARY.md`
