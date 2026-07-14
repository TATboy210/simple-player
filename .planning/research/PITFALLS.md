# Domain Pitfalls: 播放内核重构

**Domain:** Flutter 桌面媒体播放器内核
**Researched:** 2026-07-14
**Overall confidence:** HIGH (基于代码直接分析 + 项目历史经验)

---

## Critical Pitfalls

Mistakes that cause rewrites or major regressions.

### Pitfall 1: 状态机转换矩阵遗漏

**What goes wrong:** MediaState 有 9 种状态，`canTransitionTo()` 定义了 8 组合法转换集合。重构时增删状态或修改转换规则，容易遗漏边界转换，导致播放器卡在某个状态无法恢复。

**Why it happens:** 当前 `media_state.dart` 中 `MediaStateTransition` 扩展使用硬编码的 `Set.contains()` 检查。每个状态有 3-8 个合法目标，总计约 40 条边。新增状态（如 `preparing`、`resuming`）时需要手动更新所有相关状态的出边。

**Consequences:**
- 播放器卡在 `loading` 状态，无法进入 `playing` 或 `error`
- `seeking` 状态无法恢复到 `paused`（用户暂停时 seek 的场景）
- `buffering` 结束后错误地跳到 `idle` 而非恢复原状态

**Prevention:**
- 重构时用 switch expression 替代 `Set.contains()`，编译器会强制穷举
- 写状态转换的矩阵测试：对每对 `(current, next)` 验证 `canTransitionTo` 返回值
- 新增状态时必须同时更新所有可能到达该状态的源状态的出边

**Detection:** debug 模式下 `_safeSetState` 已有非法转换警告日志。监控 `FvpCallbackHandler` 中的 `state.value` 赋值点是否绕过了守卫。

**Phase:** 状态模型重构阶段必须首先解决。任何后续阶段的状态变更都依赖转换矩阵的正确性。

---

### Pitfall 2: 回调线程安全 — SchedulerBinding 时序窗口

**What goes wrong:** `FvpCallbackHandler._scheduleOnMain()` 使用 `SchedulerBinding.addPostFrameCallback` 将 mdk 回调调度到主线程。这是一个异步延迟 — 在调度和执行之间存在时间窗口，期间状态可能已被其他操作改变。

**Why it happens:** mdk 回调来自渲染线程或 FFmpeg 解码线程，不能直接更新 ValueNotifier。当前实现通过 `addPostFrameCallback` 延迟到下一帧执行。但如果在等待期间用户触发了 `open()`（切换视频），回调可能作用于新视频的状态。

**Consequences:**
- 旧视频的 `onMediaStatus(end)` 事件在新视频打开后到达，错误地将状态设为 `completed`
- 缓冲回调作用于已切换的视频，导致 `isBuffering` 状态不一致
- 竞态条件下 ValueNotifier 被连续赋值两次，触发多余的 widget rebuild

**Current mitigation (in code):** `FvpCallbackHandler` 中有防御逻辑：
```dart
// loading 阶段不更新状态 — 这是旧视频的回调
if (state.value == MediaState.loading) return;
```
以及：
```dart
// 只在实际播放中才设 completed — 避免旧视频 end 事件干扰
if (current == MediaState.playing || ...) {
  state.value = MediaState.completed;
}
```

**Prevention:**
- 重构时引入 generation/epoch 计数器（类似 `PlaybackNavigator._openGeneration`），每次 `open()` 递增，回调中检查 generation 是否匹配
- 考虑用 `Completer` 或 `CancelableOperation` 替代裸 `addPostFrameCallback`，使 `open()` 能取消待执行的旧回调
- 保留 `_disposed` 检查，但增加 `_generation` 检查作为更强的隔离

**Detection:** 快速切换视频（连续按 Next）时观察状态是否出现 `loading → completed` 的非法跳转。

**Phase:** 引擎层重构阶段。这是引擎状态一致性的核心保障。

---

### Pitfall 3: ValueNotifier 双重赋值触发冗余 rebuild

**What goes wrong:** 同一个 ValueNotifier 在短时间内被赋值多次（先被回调设为 A，又被主逻辑设为 B），每次赋值都触发所有 listener 的 rebuild。在 12 个 ValueNotifier 的 FvpEngine 中，这会导致帧率抖动。

**Why it happens:** 当前架构中有多个独立的赋值路径：
1. `FvpCallbackHandler` 通过 `addPostFrameCallback` 延迟赋值
2. `FvpEngine` 的 `play()`/`pause()`/`seekTo()` 直接赋值
3. `PositionPoller._poll()` 每 250ms 赋值 `position`

当 `seekTo()` 手动设置 `state = seeking`，然后回调又设置 `state = playing`，中间可能还有 `buffering` 状态。

**Consequences:**
- 一帧内多次 rebuild，浪费 GPU/CPU
- 进度条跳动（position 被 seek 目标值和轮询旧值交替设置）
- `isBuffering` 闪烁（true → false → true 在几帧内交替）

**Prevention:**
- 重构时对 ValueNotifier 赋值做去重：`if (notifier.value != newValue) notifier.value = newValue;`
- 当前 `PositionPoller._poll()` 已做此优化：`if (position.value != newPos) position.value = newPos;`
- 但 `FvpCallbackHandler` 中的状态赋值不完全一致 — `state.value = mapped` 没有去重检查（虽然有 `if (state.value != mapped)` 在 onStateChanged 中，但 onMediaStatus 中的 buffering 分支直接赋值）
- 统一所有 ValueNotifier 写入点，强制使用辅助方法 `_safeSetValue<T>(ValueNotifier<T> n, T v)`

**Detection:** 在 `ValueNotifier` 赋值处添加 `debugPrint`，观察同一帧内是否有重复赋值。

**Phase:** 引擎层重构阶段，与状态模型重构同步进行。

---

### Pitfall 4: disposed 检查遗漏导致 use-after-dispose

**What goes wrong:** `FvpEngine` 有 `_disposed` 标志，每个公开方法开头都有 `if (_disposed) return;`。但 `late` 字段（`_callbackHandler`、`_positionPoller`、`_volumeController`）在工厂构造函数中创建，如果构造过程中抛异常，`dispose()` 可能在这些字段未初始化时被调用。

**Why it happens:** 工厂构造函数模式（`factory FvpEngine()`）分两步：
1. 创建核心字段（`_player`、`_trackManager` 等）通过私有构造函数
2. 创建依赖 engine ValueNotifier 的 helper（`_callbackHandler` 等）

如果步骤 2 中任何 helper 构造失败（如 `mdk.Player` 的 textureId listener 注册失败），`_callbackHandler` 等仍是 `late` 未初始化状态。

**Consequences:**
- `LateInitializationError` 在 dispose 路径上
- mdk.Player 资源泄漏（未调用 `_player.dispose()`）
- Texture ID listener 未移除，导致内存泄漏

**Current mitigation:** 工厂构造函数已将大部分字段移到私有构造函数参数中，只有 3 个 `late` 字段。但 `dispose()` 中直接访问这些 `late` 字段。

**Prevention:**
- 将剩余 3 个 `late` 字段改为 nullable，在 dispose 中用 `?.dispose()` 安全调用
- 或者将所有 helper 创建移到私有构造函数中（需要解决循环引用 — helper 需要 engine 的 ValueNotifier）
- 考虑用 `Completer<bool>` 标记构造完成，dispose 中检查

**Detection:** 在测试中模拟工厂构造函数中途失败，验证 dispose 不崩溃。

**Phase:** 引擎层重构阶段。

---

### Pitfall 5: openGeneration 守卫的边界条件

**What goes wrong:** `PlaybackNavigator` 用 `_openGeneration` 计数器防止快速切歌时的异步竞态。但 `FvpEngine.open()` 内部也有 `_isOpening` 标志做类似守卫。两层守卫的交互可能导致意外行为。

**Why it happens:** 调用链：`PlaybackNavigator.playIndex()` → `engine.open()` → `MediaOpener.open()`。Navigator 层用 generation，Engine 层用 `_isOpening`。两者不共享状态。

**Consequences:**
- Navigator 的 generation 检查在 `await engine.open()` 之后，但 `engine.open()` 内部在 `_isOpening = true` 时直接 return，不抛异常也不返回错误 — Navigator 认为 open 成功（没有异常），继续执行 `engine.play()`
- 如果用户快速按 Next 3 次：第 1 次 open 被 `_isOpening` 拦截（静默返回），Navigator 不知道，继续 play 旧文件

**Current mitigation:** `engine.open()` 在 `_isOpening` 时 `log.w` 并 return，不修改 state。但 Navigator 的后续代码（seekTo、play）仍会执行。

**Prevention:**
- `engine.open()` 在 `_isOpening` 拦截时应返回 `OpenError` 而非静默 return
- 或者 Navigator 在 `await engine.open()` 后检查 state 是否为 `error`（当前已有此检查）
- 统一用一个守卫层（generation）替代两层守卫，减少交互复杂度

**Detection:** 连续快速按 Next 键 5+ 次，观察播放的是否是最后选中的文件。

**Phase:** 播放控制服务重构阶段。

---

### Pitfall 6: EngineState mixin 与 FvpEngine 的字段不同步

**What goes wrong:** `EngineState` mixin 定义了 `final ValueNotifier<...> state = ValueNotifier(...)` 作为默认实现。`FvpEngine` 用 `@override` 重新声明了所有 12 个 ValueNotifier。但如果重构时给 `EngineState` 新增属性，开发者可能忘记在 `FvpEngine` 中 override，导致 mixin 的默认实例和 engine 的实际实例不一致 — UI 监听的是 mixin 的默认 notifier，而 engine 更新的是自己的 notifier。

**Why it happens:** Dart mixin 的 field 会被子类继承，但 `@override` 会创建新实例。两个同名字段在内存中独立存在。ValueListenableBuilder 绑定到其中一个，引擎更新另一个，UI 不刷新。

**Consequences:**
- 新增的 ValueNotifier（如 `bufferHealth`）在 FvpEngine 中没有 override，UI 监听的是 mixin 的默认值（永远为初始值）
- 编译不报错 — mixin 的 field 不是 abstract，有默认值

**Prevention:**
- 将 `EngineState` 从 mixin 改为 abstract class，所有属性为 abstract getter — 编译器强制实现
- 或者在 CI 中添加 lint 规则：mixin 中的 ValueNotifier field 必须被使用它的类 override

**Detection:** 检查 FvpEngine 是否对 EngineState 的每个 field 都有 `@override` 声明。

**Phase:** 引擎抽象重构阶段。

---

## Moderate Pitfalls

### Pitfall 7: PositionPoller Timer 泄漏与重建风暴

**What goes wrong:** `PositionPoller` 管理 3 个 Timer（`_timer`、`_activeTimer`、`_silentTimer`），`_updateInterval()` 每次调用都 cancel + 重建 `_timer`。`setPlaybackRate()` 在倍速变化时调用 `_updateInterval()`，如果 UI 层有滑块连续触发（如拖拽播放速度条），会导致 Timer 频繁重建。

**Prevention:**
- `setPlaybackRate()` 应该只存储 rate 值，不立即重建 Timer — 在下次 `_poll()` 时检查 rate 是否变化再调整
- 或者对 `_updateInterval` 做 debounce（100ms 内只执行一次）
- `dispose()` 中确保所有 3 个 Timer 都被 cancel

---

### Pitfall 8: Playlist JSON 反序列化的静默数据丢失

**What goes wrong:** `Playlist.fromJson()` 对损坏的 item 用 try-catch 跳过，用户不知道哪些文件被跳过了。

**Prevention:**
- 重构时返回 `(Playlist, List<String> errors)` 元组，让 UI 层可以提示用户
- 或者在 Playlist 上暴露 `lastLoadErrors` 属性

---

### Pitfall 9: TrackManager 索引不稳定性

**What goes wrong:** MDK 使用基于 demuxer 报告顺序的索引选择轨道。轨道索引在不同文件间不稳定。`TrackManager` 直接使用存储索引切换轨道，但如果文件的轨道布局变了，切换会失败或选错轨道。

**Prevention:**
- 重构时用语言标签（`language` metadata）而非纯索引做轨道选择的持久化
- `switchAudioTrack` / `switchSubtitleTrack` 应接受语言标签参数，内部做标签到索引映射

---

### Pitfall 10: StateMonitor 的 completed 处理与 openGeneration 竞态

**What goes wrong:** `StateMonitor._onStateChanged()` 在 `completed` 时调用 `_autoAdvance()` → `navigator.playNext()` → `playIndex()`。但如果用户在视频播放完成的瞬间手动点击了下一首，两个 `playIndex()` 并发执行。

**Prevention:**
- `playIndex()` 的 generation 守卫已覆盖此场景 — 后到的 playIndex 会因 generation 不匹配而被丢弃
- 但需要确认 `_autoAdvance` 路径也使用了 `navigator.playNext()`（当前已确认），而非直接调用 `engine.open()`

---

### Pitfall 11: _guardedAction 吞掉异常分类

**What goes wrong:** `FvpEngine._guardedAction()` catch 所有 `Exception`，统一设 `MediaErrorType.playback`。但不同的操作失败原因不同（网络超时 vs 解码失败 vs 文件不存在），统一设为 `playback` 丢失了错误分类信息。

**Prevention:**
- `_guardedAction` 应接受可选的 `MediaErrorType` 参数
- 或者让 action 自己设置 errorType，`_guardedAction` 只做 catch + log

---

### Pitfall 12: VolumeController 自动静音的 UX 陷阱

**What goes wrong:** `VolumeController.setVolume(0)` 自动设置 `isMuted = true`。但用户之后按 M 键取消静音时，音量仍为 0 — 听不到声音但静音图标消失了。

**Prevention:** `setMute(false)` 时检查 `volume.value == 0`，如果是则自动恢复到默认音量（或上次非零音量）。

---

### Pitfall 13: MediaOpener 超时硬编码与网络流场景冲突

**What goes wrong:** `MediaOpener` 有 `_prepareTimeoutSeconds = 10` 和 `_textureTimeoutSeconds = 5`。对于网络流（HLS/DASH），10 秒 prepare 超时可能不够（高延迟网络、慢速 CDN）。对于本地文件，5 秒纹理超时又过于宽松。

**Prevention:**
- 重构时将超时参数化：本地文件用短超时（3s prepare, 2s texture），网络流用长超时（30s prepare, 10s texture）
- 或者暴露为可配置项，让用户在网络设置中调整

---

## Minor Pitfalls

### Pitfall 14: debugPrint 诊断日志在 release 构建中残留

**What goes wrong:** `FvpEngine.play()` 中有 `debugPrint('🔍 play() — state=...')`。虽然 `debugPrint` 在 release 模式下是 no-op，但 emoji 和格式化字符串仍占用二进制空间。

**Prevention:** 重构时用 `log.d()` 替代 `debugPrint()`，统一使用 log facade。

---

### Pitfall 15: EngineEventLog 固定容量预分配

**What goes wrong:** `EngineEventLog` 使用 `List.filled(100, null)` 预分配。空播放器也占用 100 个指针的内存。

**Prevention:** 使用 `List<EngineEvent>` + 环形索引替代预分配 nullable 数组。

---

### Pitfall 16: FvpEngine.dispose() 中的 listener 泄漏检测仅限 debug

**What goes wrong:** `dispose()` 中的 ValueNotifier listener 泄漏检查包裹在 `assert(() { ... }())` 中，release 模式完全跳过。如果生产环境有 listener 泄漏，无法检测。

**Prevention:** 在 `EngineMetrics` 中添加 `listenerLeakCount` 计数器，release 模式下也能报告。

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| **状态模型重构** | 转换矩阵遗漏导致状态卡死 (P1) | switch expression 穷举 + 矩阵测试 |
| **状态模型重构** | ValueNotifier 双重赋值 (P3) | 统一 safeSetValue 辅助方法 |
| **引擎抽象重构** | late 字段 dispose 崩溃 (P4) | nullable 替代 late + safe dispose |
| **引擎抽象重构** | EngineState mixin 字段不同步 (P6) | 改为 abstract class |
| **回调处理器重构** | 旧视频回调干扰新视频 (P2) | generation 计数器 + 取消机制 |
| **PlaybackController 重构** | Facade 子模块间循环依赖 | 通过 PlaybackContract 接口解耦 |
| **PlaybackController 重构** | openGeneration + _isOpening 双守卫冲突 (P5) | 统一为单层守卫 |
| **Playlist 重构** | CQS 破坏（peek 方法副作用） | 保持 pure query + 显式 state 更新 |
| **TrackManager 重构** | 轨道索引不稳定性 (P9) | 语言标签替代纯索引 |
| **PositionPoller 重构** | Timer 重建风暴 (P7) | rate 变化延迟到下次 poll 生效 |
| **MediaOpener 重构** | 超时硬编码 (P13) | 按本地/网络参数化超时 |
| **全栈集成** | StateMonitor completed 竞态 (P10) | generation 守卫已覆盖 |
| **测试补充** | ValueNotifier 测试需要 Flutter binding | 使用 TestWidgetsFlutterBinding |

---

## 预防策略总览

### 1. 重构前：建立回归基线

- 记录当前所有功能的手动测试 checklist（播放/暂停/seek/切歌/音量/字幕/播放模式）
- 用 `EngineEventLog` 和 `EngineMetrics` 记录关键路径的基准行为
- 写集成测试覆盖核心流程：open → play → seek → pause → next → completed → auto-advance

### 2. 重构中：增量验证

- 每次只重构一个组件，重构后立即运行测试
- 保持 `EngineState` mixin 的公开 API 不变（12 个 ValueNotifier + 所有方法签名）
- 用 `PlayerProxy` 接口隔离 mdk 依赖，使 helper 可以纯 Dart 测试

### 3. 重构后：端到端验证

- 快速切歌压力测试（连续按 Next 20+ 次）
- 长时间播放稳定性测试（1+ 小时循环播放）
- 网络流中断恢复测试（断网 → 重连 → 恢复播放）
- 多文件格式兼容性测试（MP4/MKV/AVI/WebM/FLV）

### 4. 架构护栏

- 引擎层不依赖 UI 层（当前已遵守）
- 服务层通过 `EngineState` 接口访问引擎（当前已遵守）
- 不在 kernel 中引入 Flutter widget 依赖（当前已遵守 — `SchedulerBinding` 是 framework 层，不是 widget 层）
- 保持 `PlayerProxy` 抽象，使 mdk 可被 fake 替代

---

## Sources

- 直接代码分析：`fvp_engine.dart` (641行), `fvp_callback_handler.dart` (117行), `media_state.dart` (107行), `playback_controller.dart` (178行), `playback_navigator.dart` (119行), `state_monitor.dart` (164行), `position_poller.dart` (170行), `playlist.dart` (284行), `track_manager.dart` (89行), `media_opener.dart` (189行), `volume_controller.dart` (43行), `player_proxy.dart` (19行), `engine_state.dart` (82行), `engine_metrics.dart` (92行), `engine_event_log.dart` (104行), `engine_constants.dart` (33行)
- 项目历史 memory：`project_window_anti_patterns.md` — kernel coupling, god objects, over-abstraction 反面模式
- 项目历史 memory：`anti_pattern_fullscreen_ffi.md` — fullscreen FFI 绕过 3 个库的反面例子
- 项目历史 memory：`feedback_singleton_refactoring.md` — 删 `_instance` 但留静态方法致构建失败
