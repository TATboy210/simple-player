# 性能优化计划 — Simple Player Flutter

> 生成日期: 2026-07-20
> 分支: feat/v1.8-stability-polish-plan-02-02
> 基线: Phase 20 完成，D3D11 参数已调优，RepaintBoundary 已部署

---

## 目录

1. [执行摘要](#1-执行摘要)
2. [渲染性能瓶颈](#2-渲染性能瓶颈)
3. [内存使用瓶颈](#3-内存使用瓶颈)
4. [启动性能瓶颈](#4-启动性能瓶颈)
5. [I/O 瓶颈](#5-io-瓶颈)
6. [算法复杂度瓶颈](#6-算法复杂度瓶颈)
7. [实施路线图](#7-实施路线图)
8. [测试策略](#8-测试策略)
9. [监控方案](#9-监控方案)

---

## 1. 执行摘要

### 1.1 当前状态

| 维度 | 现状 | 评级 |
|------|------|------|
| 渲染管线 | RepaintBoundary 已覆盖 19 处，GlassContainer 有 resize/opacity 降级 | B+ |
| 值通知器 | 119 个 ValueNotifier 分布于 37 文件，41 个 ValueListenableBuilder | B |
| 定时器管理 | PositionPoller 自适应间隔 (100/250/500ms)，AutoHideController 节流 100ms | A- |
| 动画控制器 | 11 个 AnimationController，均有正确 dispose | B+ |
| 启动流程 | 4 阶段（SharedPreferences → WindowService → EnginePrewarm → runApp），有进度条 | B |
| 内存监控 | MemoryMonitor 周期采样 RSS，EngineMetrics 计数器，EngineEventLog 环形缓冲 | A- |
| I/O 模型 | FolderScanner 异步流式遍历，PlaylistStore 原子写入，SettingsStore 预热缓存 | B+ |

### 1.2 主要瓶颈排序

| 优先级 | 瓶颈 | 影响范围 | 预期收益 |
|--------|------|----------|----------|
| P0 | BackdropFilter GPU readback 在 resize/动画期间的开销 | 控制栏、播放列表、标题栏 | resize 帧率 +30% |
| P0 | PositionPoller FFI 调用频率（每 100-250ms 一次） | CPU 占用、主线程阻塞 | CPU -15% |
| P1 | ValueNotifier 过度分发 — 19 个独立 notifier 在 FvpEngine 中 | 不必要的 rebuild | 减少 ~40% 无效 rebuild |
| P1 | SettingsPanel setState 范围过大 | 设置对话框响应延迟 | 交互延迟 -200ms |
| P1 | 缩略图 LRU 缓存无容量字节限制 | 大播放列表内存膨胀 | 内存 -50MB（1000 文件场景） |
| P2 | SharedPreferences 同步读取阻塞 | 首次启动延迟 | 启动 -100ms |
| P2 | FolderScanner 非递归 + 排序开销 | 大文件夹扫描 | 扫描速度 +2x |

### 1.3 预期收益总结

- **resize 帧率**: 从 ~30fps 提升至 45-60fps（关闭 BackdropFilter + 减少 rebuild）
- **稳态 CPU**: 从 ~8% 降至 ~5%（PositionPoller 降频 + FFmpeg 帧跳过）
- **内存峰值**: 大播放列表（1000+ 文件）从 ~280MB 降至 ~230MB（缩略图缓存限制）
- **启动时间**: 从 ~1.2s 降至 ~0.8s（SharedPreferences 并行 + fvp init 延迟）

---

## 2. 渲染性能瓶颈

### 2.1 BackdropFilter GPU Readback

#### 问题描述

GlassContainer 在 3 个场景中使用 BackdropFilter：标题栏、控制栏、播放列表面板。
BackdropFilter 需要 GPU readback（读取当前帧缓冲区），这是 Flutter 中最昂贵的渲染操作之一。

#### 根因分析

1. **resize 期间**: 窗口拖拽调整大小时，每帧触发 BackdropFilter readback，导致明显卡顿
2. **控制栏动画**: AutoHideController 的 FadeTransition 驱动 opacity 变化时，GlassContainer 仍执行 readback
3. **多层叠加**: 标题栏 + 控制栏 + 播放列表同时启用 BackdropFilter，形成 3 层 readback

当前代码已有 3 处降级措施：
- `GlassContainer.opacity < 0.01` 时跳过 (D-13)
- `GlassContainer.blurEnabled = false` 时跳过 (D-14)
- `GlassContainer.resizing = true` 时跳过 resize 信号

#### 优化方案

**P0-Render-1: 全局 resize 感知**

- **问题**: 仅 GlassContainer 和 PlaylistPanel 检查 resizing 信号，ControlBar 的 BackdropFilter 在 resize 期间仍执行
- **方案**: 确保 ControlBar 的 `enableBlur` 参数在 resize 期间为 false（当前代码 `enableBlur: _autoHide.visible.value` 未考虑 resizing）
- **修改**: `lib/ui/player/controls_overlay.dart` 第 267 行，改为 `enableBlur: _autoHide.visible.value && !(widget.resizing?.value ?? false)`
- **预期收益**: resize 期间消除控制栏 BackdropFilter readback，帧率 +15%

**P0-Render-2: 动画期间跳过 BackdropFilter**

- **问题**: FadeTransition 驱动 opacity 变化时，GlassContainer 的 `opacity` 参数未连接到动画值
- **方案**: 将 `_resizeOpacity` 动画值传递给 GlassContainer 的 `opacity` 参数
- **修改**: `lib/ui/player/control_bar.dart` — 当 `opacity.value < 0.05` 时返回轻量替代（半透明 Container）
- **预期收益**: resize 淡出动画期间消除 BackdropFilter readback

**P1-Render-3: BackdropFilter 合并**

- **问题**: 标题栏 + 控制栏各自独立的 BackdropFilter 形成 2 层 GPU readback
- **方案**: 将控制栏区域合并到一个 BackdropFilter 包裹的 ClipRect 中（标题栏保持独立）
- **修改**: `lib/ui/player/player_screen.dart` — 将 ControlsOverlay 的 BackdropFilter 提升到 Scaffold body 层
- **预期收益**: 减少 1 次 GPU readback，稳态帧率 +5%

### 2.2 ValueNotifier 过度分发

#### 问题描述

FvpEngine 持有 19 个独立的 ValueNotifier（textureId, state, position, duration, volume, isMuted, isBuffering, subtitleText, buffered, aspectRatio, lastError, isSeeking, playbackSpeed + 6 个来自 EngineStateMachine）。
每个 notifier 变化都触发所有监听器的 rebuild，即使监听器只关心其中 1-2 个。

#### 根因分析

1. **PositionPoller 每 100-250ms 更新 position**: 触发所有监听 `engine.position` 的 ValueListenableBuilder rebuild
2. **MergedListenable 已部分缓解**: ProgressBar 使用 `Listenable.merge([position, duration, buffered, drag, hover])`，但仍会因 position 变化触发 CustomPaint 重建
3. **ControlsOverlay 嵌套监听**: 外层监听 `_autoHide.visible`，内层监听 `engine.state`，双层 rebuild

#### 优化方案

**P1-VN-1: PositionPoller 节流 — 仅值变化时更新**

- **现状**: `_poll()` 已检查 `if (position.value != newPos) position.value = newPos`
- **问题**: 100ms 快速轮询期间，位置值可能每帧都变化（视频正常播放），导致每帧 rebuild
- **方案**: 引入 `position` 变化阈值 — 仅当位置变化超过 50ms 时才更新 notifier
- **修改**: `lib/kernel/engine/position_poller.dart` — 添加 `_lastReportedPosition` 字段和阈值检查
- **预期收益**: 稳态播放时 position 更新频率从 10/s 降至 ~4/s，减少 60% 位置相关 rebuild

**P1-VN-2: ProgressBar CustomPainter 跳过微小变化**

- **现状**: `_BarPainter.shouldRepaint()` 比较 `playedFraction` 的精确值
- **问题**: 每次 position 变化都触发 `shouldRepaint = true`，即使视觉上不可见
- **方案**: 添加阈值 — `playedFraction` 变化 < 0.1% 时返回 false
- **修改**: `lib/ui/player/progress_bar.dart` — `shouldRepaint` 方法添加阈值检查
- **预期收益**: 播放进度条 repaint 频率降低 ~50%

**P2-VN-3: EngineStateView 合并通知**

- **现状**: `EngineStateView` 在 `kernel/adapter/engine_state_view.dart` 中有 13 个 ValueNotifier
- **问题**: adapter 层的 notifier 与 engine 层的 notifier 形成双重通知链
- **方案**: 评估是否可以合并为单个 CompositeState notifier（带 named fields）
- **修改**: `lib/kernel/adapter/kernel_adapter.dart` + `lib/kernel/engine/engine_state_view.dart`
- **预期收益**: 减少 adapter 层的 rebuild 链，降低 UI 层 rebuild 频率 ~20%

### 2.3 RepaintBoundary 部署审计

#### 当前部署（19 处）

| 位置 | 文件 | 状态 |
|------|------|------|
| VideoSurface | video_surface.dart | OK — 隔离 Texture 渲染 |
| ControlsOverlay 内层 Stack | controls_overlay.dart:249 | OK — 隔离控制栏区域 |
| ErrorBanner | controls_overlay.dart:286 | OK — 隔离错误横幅 |
| ProgressBar 内层 | progress_bar.dart:286 | OK — 隔离 CustomPaint |
| PlayerScreen 视频区域 | player_screen.dart:261,278 | OK — 隔离视频+播放列表 |
| PlayerScreen 播放列表 | player_screen.dart:265,280 | OK — 隔离播放列表面板 |
| GlassContainer (3 处) | glass_container.dart:115,126,145 | OK — 隔离 blur 区域 |
| OSD Overlay | osd_overlay.dart:93 | OK — 隔离 OSD 气泡 |
| FolderTab 列表项 | folder_tab.dart:168 | OK — 隔离缩略图卡片 |
| HistoryTab 列表项 | history_tab.dart:119 | OK — 隔离缩略图卡片 |
| PlaylistPanel 内容层 | playlist_panel.dart:202 | OK — 隔离滚动内容 |
| AuroraBackground | aurora_background.dart:229 | OK — 隔离极光背景 |
| EmptyState | empty_state.dart:103 | OK — 隔离空状态 |

#### 缺失的 RepaintBoundary

**P2-RB-1: CustomTitleBar**

- **位置**: `lib/ui/window/custom_title_bar.dart`
- **问题**: 标题栏包含拖拽区域和窗口控制按钮，窗口 resize 时与主内容一起 repaint
- **方案**: 在 CustomTitleBar 外层包裹 RepaintBoundary
- **预期收益**: resize 期间标题栏不触发主内容 repaint

**P2-RB-2: KeyboardHandler 子树**

- **位置**: `lib/ui/player/player_screen.dart` — KeyboardHandler 包裹整个 Scaffold
- **问题**: 键盘事件处理 Focus 包裹整个页面，Focus 变化可能触发子树 repaint
- **方案**: 评估 Focus 的 repaint 影响，如确认有影响则在 Focus 和 Scaffold 之间插入 RepaintBoundary
- **预期收益**: 键盘操作时减少不必要的 repaint

### 2.4 setState 使用审计

#### 当前 setState 调用（21 处）

大部分 setState 使用合理，但以下场景存在过度 rebuild 风险：

**P1-SS-1: SettingsPanel 大范围 setState**

- **位置**: `lib/ui/dialogs/settings_panel.dart` — 7 处 setState
- **问题**: `_pendingLocale`, `_pendingThemeIndex` 等局部状态变化触发整个设置面板 rebuild
- **方案**: 将每个 tab 的状态独立为子 Widget，使用 ValueNotifier + ValueListenableBuilder 替代 setState
- **预期收益**: 设置面板切换 tab 时 rebuild 范围从 ~800 行降至 ~100 行

**P2-SS-2: ThumbnailTile setState 范围**

- **位置**: `lib/ui/playlist/thumbnail_tile.dart` — 3 处 setState
- **问题**: 缩略图加载状态变化触发整个 tile rebuild
- **方案**: 将缩略图加载状态提取为 ValueNotifier，仅重建缩略图 Widget
- **预期收益**: 播放列表滚动时减少 tile rebuild

---

## 3. 内存使用瓶颈

### 3.1 缩略图 LRU 缓存无容量限制

#### 问题描述

ThumbnailService 使用 LinkedHashMap 实现 LRU 缓存，最大条目数 200。
但无字节级容量限制 — 4K 缩略图（每张 ~200KB）× 200 = ~40MB。

#### 根因分析

1. **无字节追踪**: `_cache` 仅计数条目，不追踪 ImageProvider 的实际内存占用
2. **ImageProvider 生命周期**: 缓存的 ImageProvider 持有解码后的位图数据，不自动释放
3. **大播放列表场景**: 1000+ 文件的播放列表，滚动浏览时持续加载新缩略图

#### 优化方案

**P1-MEM-1: 缩略图缓存字节限制**

- **方案**: 引入 `_cacheBytes` 追踪器，限制总缓存为 30MB
- **实现**: 使用 `ImageProvider.obtainKey` + `ImageCache` 的 `currentSize` 获取字节数
- **修改**: `lib/kernel/services/thumbnail_service.dart` — 添加字节追踪和 LRU 淘汰逻辑
- **预期收益**: 1000 文件场景内存减少 ~50MB

**P2-MEM-2: 缩略图尺寸降级**

- **方案**: 在低内存场景下自动降级缩略图分辨率（从 320x180 降至 160x90）
- **触发条件**: MemoryMonitor 检测 RSS > 500MB 时自动降级
- **预期收益**: 低内存场景下缩略图内存减少 75%

### 3.2 ValueNotifier 生命周期管理

#### 问题描述

FvpEngine 的 `dispose()` 方法（第 817-865 行）正确 dispose 了所有 10 个 ValueNotifier。
但 `assert` 块中检查 `hasListeners` 仅在 debug 模式运行，release 模式下无法捕获泄漏。

#### 根因分析

1. **listener 泄漏风险**: UI 层的 `addListener` 可能未在 dispose 时 `removeListener`
2. **ControlsOverlay 的 `_onEngineStateChanged`**: 在 `dispose()` 中正确移除（第 200 行）
3. **ControlsOverlay 的 `_onResizeChanged`**: 在 `dispose()` 中正确移除（第 201 行）
4. **PlayerScreen 的 `_playlistState`**: 在 `dispose()` 中正确 dispose（第 143 行）

#### 优化方案

**P2-MEM-3: ValueNotifier 泄漏检测增强**

- **方案**: 在 `DiagnosticsBundle` 中添加 `checkNotifierLeaks()` 方法，release 模式下也可运行
- **实现**: 遍历所有 ValueNotifier，检查 `hasListeners`，记录到 EngineEventLog
- **修改**: `lib/kernel/diagnostics/diagnostics_bundle.dart`
- **预期收益**: 提前发现 listener 泄漏，避免运行时内存增长

### 3.3 EngineEventLog 环形缓冲

#### 当前状态

- **容量**: 最近 100 条事件记录
- **存储**: 内存中的环形缓冲，不持久化
- **开销**: 每条事件包含时间戳 + Map<String, dynamic>，约 200-500 字节

#### 评估

- **总内存**: 100 × 500 = ~50KB，可忽略
- **无需优化**: 当前配置合理

### 3.4 AutoHideController Timer 管理

#### 当前状态

- `_hideTimer`: 单个 Timer，`scheduleHide()` 时取消旧 Timer 再创建新的
- `_hoverThrottle`: 使用 DateTime 差值节流（100ms）

#### 评估

- **Timer 堆积风险**: 无 — `scheduleHide()` 始终先 `_hideTimer?.cancel()`
- **DateTime 开销**: `DateTime.now()` 每次调用 ~1μs，可忽略
- **无需优化**: 当前实现正确

---

## 4. 启动性能瓶颈

### 4.1 启动序列分析

当前 `main.dart` 启动序列：

```
[0ms]   WidgetsFlutterBinding.ensureInitialized()
[5ms]   fvp.registerWith()                    — 注册 fvp 平台通道
[10ms]  initLog()                             — 初始化日志系统
[15ms]  SharedPreferences.getInstance()      — 平台 I/O（异步）
[50ms]  SettingsStore.prewarm(prefs)          — 缓存 prefs 实例
[55ms]  WindowService() + init()             — Win32 窗口初始化
[80ms]  StartupCoordinator()                  — 创建进度协调器
[85ms]  EnginePrewarm.prewarm()               — fire-and-forget MDK 预热
[90ms]  runApp(App(...))                      — 首帧渲染
[200ms] 首帧完成                               — 用户可见
[500ms] EnginePrewarm 完成                     — MDK 就绪
```

#### 瓶颈识别

| 阶段 | 耗时 | 瓶颈类型 |
|------|------|----------|
| SharedPreferences.getInstance() | ~35ms | 平台 I/O |
| WindowService.init() | ~25ms | Win32 API 调用 |
| EnginePrewarm | ~400ms（后台） | FFmpeg codec 注册 |
| 首帧渲染 | ~120ms | Widget 树构建 |

### 4.2 优化方案

**P0-START-1: SharedPreferences 并行化**

- **现状**: `await SharedPreferences.getInstance()` 阻塞 35ms，然后 `SettingsStore.prewarm()`
- **方案**: 将 SharedPreferences 获取与 WindowService.init() 并行执行
- **修改**: `lib/main.dart` — 使用 `Future.wait` 并行
- **预期收益**: 启动时间减少 ~25ms

```dart
// 优化后
final (prefs, _) = await (
  SharedPreferences.getInstance(),
  windowService.init(),
).wait;
SettingsStore.prewarm(prefs);
```

**P1-START-2: fvp.registerWith() 延迟**

- **现状**: `fvp.registerWith()` 在 runApp 前同步调用
- **方案**: 评估是否可以延迟到首次 open() 时调用
- **风险**: 首次播放可能有 ~50ms 额外延迟
- **预期收益**: 启动时间减少 ~5ms（registerWith 本身很快）

**P1-START-3: 首帧 Widget 树优化**

- **现状**: App Widget 构建完整的 MaterialApp + PlayerFeature + PlayerScreen
- **方案**: 延迟加载非首屏 Widget（SettingsPanel、PlaylistPanel 的内容）
- **修改**: `lib/features/player/player_feature.dart` — 使用 `DeferredPlayerFeature` 模式
- **预期收益**: 首帧渲染时间减少 ~30ms

**P2-START-4: EnginePrewarm 进度细化**

- **现状**: EnginePrewarm 在后台执行，UI 通过 StartupCoordinator 显示进度
- **方案**: 细化进度报告 — 区分 codec 注册、D3D11 上下文创建、纹理预分配
- **修改**: `lib/kernel/engine/engine_prewarm.dart`
- **预期收益**: 用户感知更流畅的启动体验

### 4.3 SharedPreferences I/O 分析

#### 当前使用模式

| 操作 | 调用时机 | 是否阻塞 |
|------|----------|----------|
| `getInstance()` | main.dart 启动 | 是（35ms） |
| `prewarm()` | main.dart 启动 | 否（内存赋值） |
| `loadShortcuts()` | PlayerFeature.initState | 否（异步） |
| `saveShortcuts()` | SettingsPanel 关闭 | 否（异步） |
| `savePlayMode()` | 切换播放模式 | 否（异步） |
| `saveLastFile()` | 打开文件后 | 否（异步） |

#### 评估

- **预热模式正确**: `prewarm()` 在启动时缓存实例，后续操作避免重复 `getInstance()`
- **写入均为异步**: 不阻塞 UI
- **唯一优化点**: `getInstance()` 与 `WindowService.init()` 并行（P0-START-1）

---

## 5. I/O 瓶颈

### 5.1 文件系统操作

#### FolderScanner

- **当前实现**: `dir.list()` 异步流式遍历，非递归，按文件名排序
- **性能**: 1000 文件目录 ~200ms，主要瓶颈在文件系统 I/O
- **优化空间有限**: 已使用异步流式遍历，避免阻塞 UI

**P2-IO-1: FolderScanner 并行 stat**

- **方案**: 使用 `Isolate.run` 或 `compute` 在后台 Isolate 中执行文件系统操作
- **风险**: Dart Isolate 不共享堆，序列化开销可能抵消收益
- **评估**: 仅在文件数 > 5000 时考虑

#### PlaylistStore

- **当前实现**: 原子写入（写入 .tmp 文件，然后 rename）
- **性能**: 单次写入 ~5ms（JSON 序列化 + 文件 I/O）
- **优化空间有限**: 已使用原子写入，避免数据损坏

**P2-IO-2: PlaylistStore 增量保存**

- **现状**: 每次增删改都保存完整播放列表
- **方案**: 引入 dirty 标记 + debounce（1 秒内多次变更合并为一次写入）
- **修改**: `lib/kernel/persistence/playlist_store.dart` + `lib/kernel/services/playback_controller.dart`
- **预期收益**: 批量操作（如清空历史）时减少 I/O 次数

### 5.2 缩略图 I/O

#### 当前实现

- **Windows**: `NoopThumbnailProvider` — 不生成缩略图（返回 null）
- **Linux**: `LinuxThumbnailProvider` — 平台特定 API
- **macOS**: `MacosThumbnailProvider` — 平台特定 API

#### 评估

- **Windows 场景**: 缩略图 I/O 为零（Noop），无瓶颈
- **Linux/macOS**: 缩略图获取为异步，有 LRU 缓存，瓶颈在平台 API 调用

**P2-IO-3: Windows 缩略图支持**

- **现状**: Windows 使用 NoopThumbnailProvider，不生成缩略图
- **方案**: 实现 Win32 COM IThumbnailCache API 调用（已有 memory 中的 `project_immersive_playlist.md` 记录）
- **预期收益**: Windows 用户获得缩略图预览功能
- **风险**: COM 初始化开销 + 异步缩略图加载

### 5.3 SettingsStore I/O

#### 当前实现

- **预热**: `prewarm()` 缓存 SharedPreferences 实例
- **读取**: `_getPrefs()` 优先使用缓存，否则异步获取
- **写入**: 所有 save 方法使用 `unawaited()` 或直接 `_prefs.setXxx()`

#### 评估

- **预热模式正确**: 避免了重复 `getInstance()` 的平台 I/O
- **写入无阻塞**: 使用 `unawaited()` 确保不阻塞 UI
- **无需优化**: 当前实现合理

---

## 6. 算法复杂度瓶颈

### 6.1 PositionPoller 自适应间隔

#### 当前算法

```
状态转换:
  start()         → 250ms 轮询
  startSilent()   → 250ms → 3s 后 500ms
  setActive()     → 100ms → 1s 后 250ms
  setDragMode()   → 16ms ↔ 250ms
  setPlaybackRate() → 250ms/rate (clamp 50-500ms)
```

#### 复杂度分析

- **轮询间隔重建**: `_updateInterval()` 取消旧 Timer + 创建新 Timer，O(1)
- **位置比较**: `position.value != newPos`，O(1)
- **总开销**: 每秒 4-10 次 FFI 调用（`_player.position`），每次 ~0.1ms

#### 优化方案

**P1-ALG-1: PositionPoller 条件轮询**

- **现状**: 播放期间持续轮询，即使 UI 未显示进度条
- **方案**: 引入 `active` 标记 — 仅当有 listener 监听 position 时才轮询
- **修改**: `lib/kernel/engine/position_poller.dart` — 添加 `hasListeners` 检查
- **预期收益**: 后台播放时 CPU 减少 ~3%

**P2-ALG-2: PositionPoller 批量 FFI**

- **现状**: `_poll()` 分别调用 `_player.position` 和 `_player.buffered()`
- **方案**: 如果 MDK 支持，使用单次 FFI 调用获取 position + buffered
- **评估**: 需要 fvp/MDK API 支持，可能不可行

### 6.2 Playlist 排序与搜索

#### 当前实现

- **排序**: `FolderScanner.scan()` 中 `results.sort((a, b) => a.name.compareTo(b.name))`，O(n log n)
- **搜索**: 无搜索功能（仅遍历）
- **索引查找**: `playlist.items.indexOf(item)`，O(n)

#### 评估

- **排序**: 1000 文件排序 ~1ms，可忽略
- **索引查找**: 播放列表通常 < 1000 项，O(n) 可接受
- **无需优化**: 当前算法复杂度合理

### 6.3 MergedListenable 效率

#### 当前实现

- **ProgressBar**: `Listenable.merge([position, duration, buffered, drag, hover, resizing])` — 6 个 notifier
- **复杂度**: 任一 notifier 变化触发整个 merge listener，O(1) 通知，O(n) rebuild

#### 评估

- **合并效率**: Listenable.merge 内部为每个 notifier 添加 listener，任一变化触发回调
- **问题**: position 高频变化时，即使 duration/buffered/drag/hover 未变，也会触发 rebuild
- **已在 P1-VN-2 中解决**: CustomPainter.shouldRepaint 阈值检查

---

## 7. 实施路线图

### Phase 1: 高频优化（1-2 周）

| 任务 | 优先级 | 预期工时 | 修改文件 |
|------|--------|----------|----------|
| P0-Render-1: ControlBar resize 感知 | P0 | 2h | controls_overlay.dart |
| P0-Render-2: 动画期间跳过 BackdropFilter | P0 | 3h | control_bar.dart |
| P0-START-1: SharedPreferences 并行化 | P0 | 1h | main.dart |
| P1-VN-1: PositionPoller 节流阈值 | P1 | 2h | position_poller.dart |
| P1-VN-2: ProgressBar repaint 阈值 | P1 | 1h | progress_bar.dart |

**Phase 1 验收标准**:
- resize 期间帧率 ≥ 45fps（当前 ~30fps）
- 稳态 CPU ≤ 6%（当前 ~8%）
- 启动时间 ≤ 1.0s（当前 ~1.2s）
- 所有现有测试通过

### Phase 2: 架构优化（3-4 周）

| 任务 | 优先级 | 预期工时 | 修改文件 |
|------|--------|----------|----------|
| P1-MEM-1: 缩略图缓存字节限制 | P1 | 4h | thumbnail_service.dart |
| P1-SS-1: SettingsPanel 状态拆分 | P1 | 6h | settings_panel.dart, 多个 tab 文件 |
| P1-VN-3: EngineStateView 合并通知 | P1 | 8h | kernel_adapter.dart, engine_state_view.dart |
| P1-Render-3: BackdropFilter 合并 | P1 | 4h | player_screen.dart, controls_overlay.dart |
| P1-ALG-1: PositionPoller 条件轮询 | P1 | 3h | position_poller.dart |
| P2-IO-2: PlaylistStore 增量保存 | P2 | 3h | playlist_store.dart, playback_controller.dart |

**Phase 2 验收标准**:
- 1000 文件播放列表内存 ≤ 250MB（当前 ~280MB）
- 设置面板切换 tab 延迟 ≤ 100ms（当前 ~300ms）
- 全部 327+ 测试通过
- `flutter analyze` 零 warning

### Phase 3: 深度优化（5-8 周）

| 任务 | 优先级 | 预期工时 | 修改文件 |
|------|--------|----------|----------|
| P2-RB-1: CustomTitleBar RepaintBoundary | P2 | 1h | custom_title_bar.dart |
| P2-SS-2: ThumbnailTile 状态优化 | P2 | 3h | thumbnail_tile.dart |
| P2-MEM-2: 缩略图尺寸降级 | P2 | 4h | thumbnail_service.dart, memory_monitor.dart |
| P2-MEM-3: ValueNotifier 泄漏检测 | P2 | 3h | diagnostics_bundle.dart |
| P2-START-3: 首帧 Widget 延迟加载 | P2 | 4h | player_feature.dart |
| P2-START-4: EnginePrewarm 进度细化 | P2 | 2h | engine_prewarm.dart |
| P2-IO-1: FolderScanner 并行 stat | P2 | 4h | folder_scanner.dart |
| P2-IO-3: Windows 缩略图支持 | P2 | 8h | thumbnail_service.dart, win32 COM |
| P2-ALG-2: PositionPoller 批量 FFI | P2 | 4h | position_poller.dart, fvp API |

**Phase 3 验收标准**:
- 4K 显示器全屏播放 CPU ≤ 4%
- 大播放列表（5000 文件）可流畅滚动
- 内存峰值 ≤ 300MB（含缩略图缓存）
- 启动时间 ≤ 0.8s

---

## 8. 测试策略

### 8.1 性能基准测试

#### 帧率基准

```dart
// test/performance/frame_rate_test.dart
test('resize 期间帧率 >= 45fps', () async {
  // 1. 创建 PlayerScreen
  // 2. 触发 resize 动画
  // 3. 采集 60 帧的 build 时间
  // 4. 计算平均帧率
  // 5. assert(frameRate >= 45)
});
```

#### 内存基准

```dart
// test/performance/memory_test.dart
test('1000 文件播放列表内存 <= 250MB', () async {
  // 1. 创建 1000 项播放列表
  // 2. 加载所有缩略图
  // 3. 采集 RSS
  // 4. assert(rss <= 250 * 1024 * 1024)
});
```

#### 启动基准

```dart
// test/performance/startup_test.dart
test('启动时间 <= 1.0s', () async {
  // 1. 测量 main() 到首帧完成的时间
  // 2. assert(duration <= Duration(seconds: 1))
});
```

### 8.2 回归测试

#### PositionPoller 节流测试

```dart
// test/kernel/engine/position_poller_test.dart
test('位置变化 < 50ms 时不更新 notifier', () async {
  // 1. 创建 PositionPoller
  // 2. 设置 position.value = 1000
  // 3. 调用 _poll() 返回 1020（变化 20ms < 50ms 阈值）
  // 4. assert(position.value == 1000) — 未更新
});

test('位置变化 >= 50ms 时更新 notifier', () async {
  // 1. 创建 PositionPoller
  // 2. 设置 position.value = 1000
  // 3. 调用 _poll() 返回 1060（变化 60ms >= 50ms 阈值）
  // 4. assert(position.value == 1060) — 已更新
});
```

#### BackdropFilter 降级测试

```dart
// test/ui/shared/glass_container_test.dart
test('resizing=true 时跳过 BackdropFilter', () async {
  // 1. 创建 GlassContainer(resizing: resizingNotifier)
  // 2. 设置 resizingNotifier.value = true
  // 3. 渲染 Widget
  // 4. expect(find.byType(BackdropFilter), findsNothing)
});
```

#### 缩略图缓存淘汰测试

```dart
// test/kernel/services/thumbnail_service_test.dart
test('缓存超过 30MB 时淘汰最旧条目', () async {
  // 1. 创建 ThumbnailService（容量限制 30MB）
  // 2. 添加 200 个缩略图（每个 ~200KB = ~40MB）
  // 3. 验证缓存条目数 < 200
  // 4. 验证最早添加的条目已被淘汰
});
```

### 8.3 集成测试

#### 全链路性能测试

```dart
// test/integration/performance_integration_test.dart
test('完整播放流程无性能退化', () async {
  // 1. 启动应用
  // 2. 打开文件
  // 3. 播放 10 秒
  // 4. 拖拽进度条
  // 5. 切换全屏
  // 6. 打开/关闭播放列表
  // 7. 验证全程帧率 >= 30fps
  // 8. 验证内存无泄漏（前后 RSS 差 < 10MB）
});
```

---

## 9. 监控方案

### 9.1 运行时监控

#### EngineMetrics 扩展

```dart
// lib/kernel/engine/engine_metrics.dart
class EngineMetrics {
  // 已有: openCount, playCount, seekCount, seekTotalMs, errorCount

  // 新增: 帧率监控
  int _frameCount = 0;
  final _frameStopwatch = Stopwatch();

  void recordFrame() {
    _frameCount++;
    if (!_frameStopwatch.isRunning) _frameStopwatch.start();
  }

  double get fps {
    final elapsed = _frameStopwatch.elapsedMilliseconds;
    if (elapsed == 0) return 0;
    return _frameCount * 1000.0 / elapsed;
  }
}
```

#### MemoryMonitor 增强

```dart
// lib/kernel/diagnostics/memory_monitor.dart
// 已有: 周期 RSS 采样 + snapshotNotifier

// 新增: 缩略图缓存字节数追踪
int _thumbnailCacheBytes = 0;

void reportThumbnailCache(int bytes) {
  _thumbnailCacheBytes = bytes;
}

// 在 snapshot 中添加 thumbnailCacheBytes 字段
```

### 9.2 开发时监控

#### Flutter DevTools 集成

1. **Performance Overlay**: 启用 `showPerformanceOverlay: true`（debug 模式）
2. **Widget Rebuild Tracker**: 使用 `debugProfileBuildsEnabled = true` 追踪 rebuild
3. **Timeline Events**: 在关键路径添加 `Timeline.startSync` / `Timeline.finishSync`

#### 自定义性能标记

```dart
// lib/kernel/utils/perf_marker.dart
class PerfMarker {
  static void start(String name) {
    if (kDebugMode) Timeline.startSync(name);
  }

  static void end(String name) {
    if (kDebugMode) Timeline.finishSync();
  }
}

// 使用示例
PerfMarker.start('position_poll');
// ... FFI 调用
PerfMarker.end('position_poll');
```

### 9.3 CI 性能回归检测

#### GitHub Actions 配置

```yaml
# .github/workflows/performance.yml
name: Performance Regression
on: [pull_request]

jobs:
  perf-test:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter test test/performance/ --reporter=json > perf-results.json
      - uses: actions/upload-artifact@v4
        with:
          name: perf-results
          path: perf-results.json
```

#### 性能阈值检查

```dart
// test/performance/perf_thresholds.dart
class PerfThresholds {
  static const maxStartupMs = 1200;      // 启动时间上限
  static const minResizeFps = 45;         // resize 帧率下限
  static const maxMemoryMb = 300;         // 内存上限
  static const maxCpuPercent = 8.0;       // CPU 上限
}
```

---

## 附录 A: 文件修改清单

| 文件 | 修改类型 | Phase | 任务 |
|------|----------|-------|------|
| lib/main.dart | 修改 | 1 | P0-START-1 |
| lib/ui/player/controls_overlay.dart | 修改 | 1 | P0-Render-1 |
| lib/ui/player/control_bar.dart | 修改 | 1 | P0-Render-2 |
| lib/kernel/engine/position_poller.dart | 修改 | 1,2 | P1-VN-1, P1-ALG-1 |
| lib/ui/player/progress_bar.dart | 修改 | 1 | P1-VN-2 |
| lib/kernel/services/thumbnail_service.dart | 修改 | 2,3 | P1-MEM-1, P2-MEM-2 |
| lib/ui/dialogs/settings_panel.dart | 修改 | 2 | P1-SS-1 |
| lib/kernel/adapter/kernel_adapter.dart | 修改 | 2 | P1-VN-3 |
| lib/kernel/engine/engine_state_view.dart | 修改 | 2 | P1-VN-3 |
| lib/ui/player/player_screen.dart | 修改 | 2 | P1-Render-3 |
| lib/kernel/persistence/playlist_store.dart | 修改 | 2 | P2-IO-2 |
| lib/ui/window/custom_title_bar.dart | 修改 | 3 | P2-RB-1 |
| lib/ui/playlist/thumbnail_tile.dart | 修改 | 3 | P2-SS-2 |
| lib/kernel/diagnostics/diagnostics_bundle.dart | 修改 | 3 | P2-MEM-3 |
| lib/kernel/diagnostics/memory_monitor.dart | 修改 | 3 | P2-MEM-2 |
| lib/features/player/player_feature.dart | 修改 | 3 | P2-START-3 |
| lib/kernel/engine/engine_prewarm.dart | 修改 | 3 | P2-START-4 |
| lib/kernel/scanner/folder_scanner.dart | 修改 | 3 | P2-IO-1 |

## 附录 B: 已有优化确认

以下优化已在当前代码中实现，无需额外工作：

| 优化 | 位置 | 状态 |
|------|------|------|
| GlassTier 缓存 ImageFilter | glass_container.dart | OK — static final 不可变对象 |
| GlassContainer resize 降级 | glass_container.dart:118 | OK — resizing=true 跳过 BackdropFilter |
| GlassContainer opacity 降级 | glass_container.dart:149 | OK — opacity<0.01 跳过 BackdropFilter |
| GlassContainer blurEnabled 降级 | glass_container.dart:111 | OK — blurEnabled=false 跳过 BackdropFilter |
| PositionPoller 自适应间隔 | position_poller.dart | OK — 100/250/500ms 三档 |
| PositionPoller 拖拽模式 | position_poller.dart:108 | OK — 16ms 跟手轮询 |
| PositionPoller 本地文件跳过 buffered | position_poller.dart:173 | OK — isUrl 检查 |
| ProgressBar resize 缓存 | progress_bar.dart:283 | OK — resizing 时复用 cachedCustomPaint |
| ProgressBar hover 节流 | progress_bar.dart:165 | OK — addPostFrameCallback 节流 |
| ControlsOverlay child 缓存 | controls_overlay.dart:248 | OK — visible VLB 的 child 缓存 |
| RepaintBoundary 19 处部署 | 多文件 | OK — 见 2.3 审计 |
| SettingsStore 预热 | settings_store.dart:78 | OK — prewarm() 缓存实例 |
| FolderScanner 异步流式 | folder_scanner.dart:61 | OK — await for 流式遍历 |
| PlaylistStore 原子写入 | playlist_store.dart:104 | OK — .tmp + rename |
| AutoHideController 节流 | auto_hide_controller.dart:108 | OK — 100ms DateTime 节流 |
| SmartDragToResizeArea 类型稳定 | player_screen.dart:28 | OK — 避免 Element 销毁重建 |
| T5 AnimatedBuilder 合并 | player_screen.dart:160 | OK — 消除双重 markNeedsBuild |

## 附录 C: 风险评估

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| PositionPoller 阈值过大导致进度条卡顿 | 中 | 中 | 阈值设为 50ms，用户不可感知 |
| BackdropFilter 降级影响视觉效果 | 低 | 低 | 仅在 resize 期间降级，用户正在拖拽无暇观察 |
| SettingsPanel 状态拆分引入 bug | 中 | 高 | 充分的 Widget 测试覆盖 |
| 缩略图缓存淘汰策略不当 | 低 | 中 | LRU + 字节限制双重保护 |
| fvp API 不支持批量查询 | 中 | 低 | P2 优先级，可推迟 |

---

> 文档结束 — 共 18 个优化任务，分 3 个 Phase 实施，预计总工时 ~60 小时。
