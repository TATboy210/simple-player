# Phase 10: 状态机提取 + 引擎瘦身 - Research

**Researched:** 2026-07-14
**Domain:** Dart 状态机模式、ISP 接口组合、FvpEngine 瘦身
**Confidence:** HIGH

## Summary

本阶段从 FvpEngine 中提取独立 `EngineStateMachine` 类（拥有状态 + 强制转换守卫），并将 FvpEngine 从 632 行精简至 <350 行。核心工作：(1) 新建 EngineStateMachine 管理 6 状态 + 2 bool 标志，用 switch expression 穷举合法转换；(2) Helper 类实现已有 ISP 接口，FvpEngine 暴露接口 getter 替代 delegation 方法；(3) 便捷方法（togglePlayPause/skipForward 等）移至状态机和 mixin。

技术方案清晰：Dart 3 的 switch expression 对 enum 的穷举检查是编译期保证的，与现有 `MediaStateTransition` extension 的运行时检查相比，安全性更高。ValueNotifier 组合模式在项目中已成熟使用，状态机只需将现有的 `_safeSetState` 逻辑封装为独立类。

**Primary recommendation:** EngineStateMachine 作为独立类注入 FvpEngine，拥有 3 个 ValueNotifier（state/isSeeking/isBuffering），`transitionTo` 方法用 switch expression 穷举守卫。FvpEngine 删除 ~200 行 delegation 方法，改为接口 getter 暴露。

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**状态模型（SVC-02）：**
- **D-01:** 使用 Phase 9 确定的 6 状态正交枚举（idle/opening/playing/paused/completed/error）+ 2 个独立 bool 标志（isSeeking/isBuffering）。路线图的"9 状态 ~40 条边"描述已过时，不采用。
- **D-02:** EngineStateMachine 为独立类，拥有 `ValueNotifier<MediaState>` + `ValueNotifier<bool> isSeeking` + `ValueNotifier<bool> isBuffering`。提供 `transitionTo(MediaState, String caller)` 方法。
- **D-03:** 非法状态转换处理：debug 模式 assert 报错（不崩溃），release 模式静默忽略。与当前 `_safeSetState` 行为一致。
- **D-04:** 删除现有 `MediaStateTransition` extension（`canTransitionTo`），用 EngineStateMachine 内部的 switch expression 穷举替代。
- **D-05:** 状态机的 `transitionTo` 返回 `bool`（成功/被忽略），调用方可选择是否检查结果。

**FvpEngine 瘦身（ENG-02）：**
- **D-06:** TrackManager 实现 TrackControl 接口，SubtitleConfigurator 实现 SubtitleConfig 接口，VideoEffectController 实现 VideoEffectControl 接口，D3D11Configurator 实现 RendererControl 接口。
- **D-07:** FvpEngine 暴露接口 getter：`TrackControl get trackControl => _trackManager`、`SubtitleConfig get subtitleConfig => _subtitleConfigurator` 等。删除所有 ~200 行 delegation 方法。调用者从 `engine.switchAudioTrack()` 改为 `engine.trackControl.switchAudioTrack()`。
- **D-08:** FvpEngine 最小核心保留：open/play/pause/stop/seekTo + 状态转换调用 + dispose + ValueNotifier 字段 + 工厂构造函数。
- **D-09:** `togglePlayPause` 移至 EngineStateMachine（依赖状态判断调 play 还是 pause）。
- **D-10:** `skipForward`/`skipBack`/`setRange` 移至 PlaybackControl 的 default mixin（纯计算 + 委托 seekTo）。
- **D-11:** `setVolume`/`setMute` 移至 VolumeController helper（实现 VolumeControl 接口或通过 engine getter 暴露）。
- **D-12:** `setPlaybackRate` 移至独立方法或保留在 FvpEngine（需要同时设置 player.playbackRate + ValueNotifier + positionPoller）。

### Claude's Discretion

- D-10 中 skipForward/skipBack/setRange 的 mixin 命名和位置由 Claude 决定
- D-11/D-12 中 volume/playbackRate 的具体归属由 Claude 决定（取决于 helper 接口设计）

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ENG-02 | FvpEngine 从 641 行减至 <350 行，helper 实现对应接口，暴露接口 getter | Dart implements 关键字 + 接口 getter 模式已验证；delegation 方法 ~200 行可安全删除 |
| SVC-02 | 独立状态机强制转换守卫，switch expression 穷举 6 状态 + 2 bool 标志 | Dart 3 switch expression 对 enum 的穷举检查是编译期保证；ValueNotifier 组合模式已成熟 |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| 状态转换守卫 | EngineStateMachine (新类) | — | 独立类拥有状态，强制穷举守卫 |
| 播放控制核心 | FvpEngine | — | open/play/pause/stop/seekTo 保留 |
| 轨道管理 | TrackManager (implements TrackControl) | FvpEngine getter 暴露 | helper 实现接口，engine 暴露 getter |
| 字幕配置 | SubtitleConfigurator (implements SubtitleConfig) | FvpEngine getter 暴露 | 同上 |
| 视频效果 | VideoEffectController (implements VideoEffectControl) | FvpEngine getter 暴露 | 同上 |
| 渲染器配置 | D3D11Configurator (implements RendererControl) | FvpEngine getter 暴露 | 同上 |
| 音量控制 | VolumeController (implements VolumeControl) | FvpEngine getter 暴露 | 需新建 VolumeControl 接口 |
| 便捷播放方法 | PlaybackSkipMixin (新 mixin) | — | skipForward/skipBack/setRange 纯计算 |
| 便捷播放速率 | FvpEngine | — | 需要同时设置 player + ValueNotifier + poller |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Dart 3 switch expression | SDK 3.12.2 | enum 穷举检查 | 编译期保证所有 case 覆盖 |
| ValueNotifier | Flutter SDK | 响应式状态 | 项目已统一使用此模式 |
| abstract class (ISP) | Dart 3 | 接口分离 | Phase 9 已建立此模式 |
| implements | Dart 3 | 接口实现 | 替代 mixin-with-fields 模式 |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| assert() | Dart SDK | debug 模式检查 | 非法状态转换的 debug 警告 |
| kDebugMode | Flutter SDK | 环境判断 | debug vs release 行为差异 |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| switch expression enum | sealed class 层级 | enum 更简单，6 值足够；sealed class 适合有数据的变体 |
| 独立 EngineStateMachine | FvpEngine 内部私有方法 | 独立类可测试，但增加一个类 |
| mixin PlaybackSkipMixin | 独立工具函数 | mixin 可以访问 seekTo/position/duration，工具函数需要传参 |

## Package Legitimacy Audit

> 本阶段不安装新外部包，纯架构重构。

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| (none) | — | — | — | — | — | No new packages |

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────┐
│                    FvpEngine                         │
│  ┌──────────────┐  ┌──────────────────────────────┐ │
│  │  Core Only   │  │  Interface Getters           │ │
│  │  open/play   │  │  trackControl => _trackMgr   │ │
│  │  pause/stop  │  │  subtitleConfig => _subtitle │ │
│  │  seekTo      │  │  videoEffect => _videoEffect │ │
│  │  dispose     │  │  rendererControl => _d3d11   │ │
│  │  ValueNotif  │  │  volumeControl => _volume    │ │
│  └──────┬───────┘  └──────────────────────────────┘ │
│         │                                           │
│         ▼                                           │
│  ┌──────────────────┐                               │
│  │ EngineStateMachine│ ← transitionTo() 守卫        │
│  │  state (Notifier) │ ← switch expression 穷举     │
│  │  isSeeking        │                               │
│  │  isBuffering      │                               │
│  │  togglePlayPause()│                               │
│  └──────────────────┘                               │
│         │                                           │
│         ▼                                           │
│  ┌──────────────────┐                               │
│  │ FvpCallbackHandler│ ← mdk 回调 → stateMachine    │
│  └──────────────────┘                               │
└─────────────────────────────────────────────────────┘

Helpers (implement ISP interfaces):
┌──────────────┐ ┌───────────────┐ ┌──────────────────┐
│ TrackManager │ │SubtitleConfig │ │VideoEffectCtrl   │
│ implements   │ │implements     │ │implements         │
│ TrackControl │ │SubtitleConfig │ │VideoEffectControl │
└──────────────┘ └───────────────┘ └──────────────────┘

┌──────────────────┐ ┌──────────────────┐ ┌─────────────────┐
│ D3D11Configurator│ │ VolumeController │ │PlaybackSkipMixin│
│ implements       │ │ implements       │ │ (mixin on       │
│ RendererControl  │ │ VolumeControl    │ │  PlaybackControl)│
└──────────────────┘ └──────────────────┘ └─────────────────┘
```

### Recommended Project Structure

```
lib/kernel/engine/
├── engine_state_machine.dart    # 新: 独立状态机
├── volume_control.dart          # 新: 音量控制接口
├── playback_skip_mixin.dart     # 新: skipForward/skipBack/setRange mixin
├── fvp_engine.dart              # 瘦身: <350 行核心
├── media_state.dart             # 修改: 删除 MediaStateTransition extension
├── engine_state.dart            # 不变: barrel export
├── engine_state_view.dart       # 不变
├── playback_control.dart        # 不变
├── track_control.dart           # 不变
├── subtitle_config.dart         # 不变
├── video_effect_control.dart    # 不变
├── renderer_control.dart        # 不变
├── media_engine.dart            # 可能修改: 添加 VolumeControl
├── track_manager.dart           # 修改: implements TrackControl
├── subtitle_configurator.dart   # 修改: implements SubtitleConfig
├── video_effect_controller.dart # 修改: implements VideoEffectControl
├── d3d11_configurator.dart      # 修改: implements RendererControl
├── volume_controller.dart       # 修改: implements VolumeControl
├── fvp_callback_handler.dart    # 修改: 使用 stateMachine.transitionTo
├── position_poller.dart         # 不变
├── media_opener.dart            # 不变
└── ...                          # 其他不变
```

### Pattern 1: EngineStateMachine — 独立状态机

**What:** 独立类拥有 3 个 ValueNotifier（state/isSeeking/isBuffering），用 switch expression 穷举合法转换
**When to use:** 任何需要状态转换守卫的场景
**Example:**

```dart
/// Source: 项目内部 — 基于 Dart 3 switch expression (CITED: dart-lang/site-www)
class EngineStateMachine {
  EngineStateMachine();

  final ValueNotifier<MediaState> state = ValueNotifier(MediaState.idle);
  final ValueNotifier<bool> isSeeking = ValueNotifier(false);
  final ValueNotifier<bool> isBuffering = ValueNotifier(false);

  /// 尝试转换到目标状态，返回是否成功
  ///
  /// debug 模式: 非法转换 assert 警告（不崩溃）
  /// release 模式: 非法转换静默忽略
  bool transitionTo(MediaState next, String caller) {
    final current = state.value;
    if (!_canTransitionTo(current, next)) {
      assert(() {
        debugPrint('⚠️ EngineStateMachine.$caller: illegal $current → $next');
        return true;
      }());
      if (!kDebugMode) return false;
    }
    state.value = next;
    return true;
  }

  /// switch expression 穷举 — 编译期保证所有 case 覆盖
  static bool _canTransitionTo(MediaState current, MediaState next) {
    return switch (current) {
      MediaState.idle => next == MediaState.opening || next == MediaState.error,
      MediaState.opening => next == MediaState.idle || next == MediaState.playing || next == MediaState.error,
      MediaState.playing => next == MediaState.paused || next == MediaState.completed || next == MediaState.error || next == MediaState.idle,
      MediaState.paused => next == MediaState.playing || next == MediaState.error || next == MediaState.idle,
      MediaState.completed => next == MediaState.opening || next == MediaState.error || next == MediaState.idle,
      MediaState.error => next == MediaState.opening || next == MediaState.idle,
    };
  }
}
```

### Pattern 2: Helper implements Interface + Engine exposes getter

**What:** Helper 类实现 Phase 9 定义的 ISP 接口，FvpEngine 暴露 getter 而非 delegation 方法
**When to use:** 已有 ISP 接口 + 已有 helper 类的场景
**Example:**

```dart
/// Source: 项目内部 — 基于 Phase 9 ISP 接口模式
// TrackManager 实现 TrackControl 接口
class TrackManager implements TrackControl {
  // ... 现有实现不变 ...
  @override
  List<AudioTrackInfo> getAudioTracks() => _mediaInfo.audioTracks;

  @override
  void switchAudioTrack(int trackIndex) { /* 现有逻辑 */ }

  @override
  List<int> get activeAudioTracks => _player.activeAudioTracks;
}

// FvpEngine 暴露 getter，删除 delegation
class FvpEngine implements MediaEngine {
  // ...
  @override
  TrackControl get trackControl => _trackManager;

  @override
  SubtitleConfig get subtitleConfig => _subtitleConfigurator;

  @override
  VideoEffectControl get videoEffectControl => _videoEffectController;

  @override
  RendererControl get rendererControl => _d3d11Configurator;

  @override
  VolumeControl get volumeControl => _volumeController;
}
```

### Pattern 3: PlaybackSkipMixin — 便捷方法 mixin

**What:** 将 skipForward/skipBack/setRange 封装为 PlaybackControl 的 default mixin
**When to use:** 方法是纯计算 + 委托，不需要访问引擎内部状态
**Example:**

```dart
/// Source: 项目内部 — 基于 Dart mixin 模式
/// skipForward/skipBack/setRange 的默认实现
/// 纯计算 + 委托 seekTo，不依赖引擎内部状态
mixin PlaybackSkipMixin implements PlaybackControl {
  @override
  void skipForward([int ms = EngineConstants.defaultSkipMs]) {
    // 需要访问 position 和 duration — 通过 EngineStateView
    seekTo((position.value + ms).clamp(0, duration.value));
  }

  @override
  void skipBack([int ms = EngineConstants.defaultSkipMs]) {
    seekTo((position.value - ms).clamp(0, duration.value));
  }

  @override
  void setRange({required int from, int to = -1}) {
    // setRange 需要访问 player — 保留在 FvpEngine 或移到专门的 helper
  }
}
```

### Anti-Patterns to Avoid

- **在状态机中持有 FvpEngine 引用:** 状态机应独立于引擎，只管理状态转换。togglePlayPause 需要回调引擎的 play/pause，通过函数注入而非持有引用。
- **在 FvpEngine 中保留 delegation 方法:** 既然 helper 实现了接口，delegation 方法是冗余代码。调用者应通过 getter 访问。
- **mixin 中直接访问 _player:** mixin 应通过抽象方法或 getter 访问依赖，不直接持有 mdk.Player。

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| 状态转换矩阵 | 手写 if/else 链 | switch expression 穷举 | 编译期保证覆盖所有 case |
| 接口实现检查 | 运行时 type check | implements 关键字 | 编译期类型安全 |
| 状态变更通知 | 自定义事件系统 | ValueNotifier | Flutter 标准模式，已统一使用 |

**Key insight:** 状态机的核心价值是编译期穷举保证。用 switch expression 替代运行时 canTransitionTo 检查，新增状态时编译器会强制更新所有转换路径。

## Common Pitfalls

### Pitfall 1: togglePlayPause 的依赖注入

**What goes wrong:** togglePlayPause 需要调用 FvpEngine 的 play/pause 方法，但状态机不应持有引擎引用
**Why it happens:** 循环依赖 — 状态机需要引擎，引擎需要状态机
**How to avoid:** 通过函数回调注入：`EngineStateMachine({required this.onPlay, required this.onPause})`
**Warning signs:** 状态机 import 了 fvp_engine.dart

### Pitfall 2: PlaybackControl 接口签名变化

**What goes wrong:** 删除 togglePlayPause/skipForward/skipBack/setRange 后，PlaybackControl 接口签名变化，所有实现者需要更新
**Why it happens:** mixin 可以提供默认实现，但接口定义了方法签名
**How to avoid:** 保留 PlaybackControl 中的方法签名，mixin 提供 default 实现。或者将这些方法从 PlaybackControl 移除，让调用者直接使用 mixin。
**Warning signs:** 编译错误 "Class X doesn't implement PlaybackControl.Y"

### Pitfall 3: FvpCallbackHandler 的状态转换路径

**What goes wrong:** FvpCallbackHandler 直接设置 `state.value = MediaState.completed`，绕过状态机守卫
**Why it happens:** 旧代码直接操作 ValueNotifier，不经过 transitionTo
**How to avoid:** FvpCallbackHandler 注入 EngineStateMachine，所有状态变更通过 `stateMachine.transitionTo()`
**Warning signs:** 状态转换绕过守卫，debug 日志不打印

### Pitfall 4: interface getter 的 disposed 检查

**What goes wrong:** 调用者通过 `engine.trackControl.switchAudioTrack()` 访问时，引擎已 disposed
**Why it happens:** getter 直接返回 helper，没有 disposed 检查
**How to avoid:** 在 FvpEngine 的 getter 中检查 disposed 状态，或在 helper 中自行检查
**Warning signs:** disposed 后调用 helper 方法导致崩溃

## Code Examples

Verified patterns from official sources:

### Switch expression exhaustive check on enum

```dart
/// Source: CITED: dart-lang/site-www (Dart 3 branches)
/// enum 的 switch expression 是穷举的 — 编译器保证所有值都被处理
enum MediaState { idle, opening, playing, paused, completed, error }

bool canTransitionTo(MediaState current, MediaState next) {
  return switch (current) {
    MediaState.idle => next == MediaState.opening || next == MediaState.error,
    MediaState.opening => next == MediaState.idle || next == MediaState.playing || next == MediaState.error,
    MediaState.playing => next == MediaState.paused || next == MediaState.completed || next == MediaState.error || next == MediaState.idle,
    MediaState.paused => next == MediaState.playing || next == MediaState.error || next == MediaState.idle,
    MediaState.completed => next == MediaState.opening || next == MediaState.error || next == MediaState.idle,
    MediaState.error => next == MediaState.opening || next == MediaState.idle,
  };
}
```

### implements vs with

```dart
/// Source: CITED: dart-lang/site-www (class modifiers)
/// implements: 必须实现所有方法，不继承实现
/// with: 继承实现，可以覆盖
class TrackManager implements TrackControl {
  // 必须实现 TrackControl 的所有方法
  @override
  List<AudioTrackInfo> getAudioTracks() => _mediaInfo.audioTracks;
  // ...
}
```

### ValueNotifier composition

```dart
/// Source: CITED: api.flutter.dev
/// 多个 ValueNotifier 可以独立监听，widget 只 rebuild 关心的 notifier
class EngineStateMachine {
  final ValueNotifier<MediaState> state = ValueNotifier(MediaState.idle);
  final ValueNotifier<bool> isSeeking = ValueNotifier(false);
  final ValueNotifier<bool> isBuffering = ValueNotifier(false);

  void dispose() {
    state.dispose();
    isSeeking.dispose();
    isBuffering.dispose();
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| MediaStateTransition extension (运行时) | switch expression 穷举 (编译期) | Phase 10 | 新增状态时编译器强制更新 |
| _safeSetState 在 FvpEngine 内部 | EngineStateMachine.transitionTo 独立类 | Phase 10 | 状态机可独立测试 |
| FvpEngine 实现所有方法 | helper implements 接口 + getter 暴露 | Phase 10 | FvpEngine 从 632 行减至 <350 行 |
| delegation 方法 ~200 行 | 接口 getter ~5 行 | Phase 10 | 调用者 API 变化 |

**Deprecated/outdated:**
- MediaStateTransition extension: 用 EngineStateMachine 内部的 switch expression 替代
- FvpEngine 中的 delegation 方法: 用接口 getter 替代
- 路线图中"9 状态 ~40 条边": 已修正为 6 状态 + 2 bool 标志

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | VolumeControl 接口需要新建（当前不存在） | Standard Stack | 可能改为直接暴露 VolumeController 实例 |
| A2 | PlaybackSkipMixin 可以在 mixin 中调用 seekTo/position/duration | Pattern 3 | mixin 可能无法访问这些方法，需要改为独立类 |
| A3 | MediaEngine 接口需要添加 VolumeControl | Architecture | 可能改为单独 getter 而非修改 MediaEngine |

## Open Questions (RESOLVED)

1. **PlaybackControl 接口是否保留 togglePlayPause/skipForward/skipBack/setRange 的方法签名？**
   - RESOLVED: 保留签名。Plan 10-01 Task 1 将 togglePlayPause 移至 EngineStateMachine (per D-09)，skipForward/skipBack 通过 PlaybackSkipMixin 提供 default 实现 (per D-10)。setRange 保留在 FvpEngine 中 (per D-10 decision)。调用者通过 PlaybackControl 接口访问，代码无需改。

2. **VolumeControl 接口是否加入 MediaEngine 组合接口？**
   - RESOLVED: 是。Plan 10-02 Task 1 添加 `VolumeControl get volumeControl` getter 到 MediaEngine 组合接口 (per D-11)，保持与 TrackControl/SubtitleConfig/VideoEffectControl/RendererControl 一致的 getter 暴露模式。

3. **setRange 的归属？**
   - RESOLVED: setRange 保留在 FvpEngine。需要 _player.setRange + _guardedAction，mixin 无法访问这些依赖。PlaybackSkipMixin 只提供 skipForward/skipBack 的 default 实现 (per D-10 decision in Plan 10-01 Task 2)。

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Dart SDK | switch expression | ✓ | 3.12.2 | — |
| Flutter SDK | ValueNotifier | ✓ | 3.44.6 | — |
| flutter_test | 单元测试 | ✓ | SDK 内置 | — |

**Missing dependencies with no fallback:**
- (none)

**Missing dependencies with fallback:**
- (none)

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK 内置) |
| Config file | analysis_options.yaml |
| Quick run command | `flutter test test/kernel/engine/engine_state_machine_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ENG-02 | FvpEngine < 350 行 | 静态检查 | `wc -l lib/kernel/engine/fvp_engine.dart` | N/A |
| ENG-02 | helper implements 接口 | 单元测试 | `flutter test test/kernel/engine/` | 部分存在 |
| SVC-02 | 非法转换被拦截 | 单元测试 | `flutter test test/kernel/engine/engine_state_machine_test.dart` | ❌ Wave 0 |
| SVC-02 | transitionTo 返回 bool | 单元测试 | 同上 | ❌ Wave 0 |
| SVC-02 | debug 模式 assert 警告 | 单元测试 | 同上 | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `flutter test test/kernel/engine/`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/kernel/engine/engine_state_machine_test.dart` — 覆盖 SVC-02（状态转换矩阵、transitionTo 返回值、debug 警告）
- [ ] `test/kernel/engine/playback_skip_mixin_test.dart` — 覆盖 skipForward/skipBack/setRange
- [ ] 更新 `test/helpers/fake_engine.dart` — 添加 interface getter + stateMachine
- [ ] 更新 `test/kernel/engine/fvp_callback_handler_test.dart` — 使用 stateMachine.transitionTo

## Security Domain

> 本阶段是纯架构重构，不涉及新的安全面。现有安全属性（输入验证、错误处理）保持不变。

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | no | — 不涉及新的用户输入 |
| V6 Cryptography | no | — |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| (none applicable) | — | — |

## Sources

### Primary (HIGH confidence)

- 项目源码 `lib/engine/fvp_engine.dart` — 当前 632 行实现，6 helper 组合，43 个 @override
- 项目源码 `lib/engine/media_state.dart` — 6 值枚举 + MediaStateTransition extension
- 项目源码 `lib/engine/engine_state.dart` — Phase 9 ISP 接口 barrel export
- 项目源码 `lib/engine/track_manager.dart` — 88 行，已有方法签名匹配 TrackControl
- 项目源码 `lib/engine/subtitle_configurator.dart` — 48 行，方法签名匹配 SubtitleConfig
- 项目源码 `lib/engine/video_effect_controller.dart` — 64 行，方法签名匹配 VideoEffectControl
- 项目源码 `lib/engine/d3d11_configurator.dart` — 69 行，方法签名匹配 RendererControl
- 项目源码 `lib/engine/volume_controller.dart` — 42 行，需新建 VolumeControl 接口
- 项目源码 `lib/engine/fvp_callback_handler.dart` — 108 行，直接设置 state.value 需改为 transitionTo
- Phase 9 CONTEXT.md — D-01~D-19 决策记录

### Secondary (MEDIUM confidence)

- [CITED: dart-lang/site-www] — switch expression 穷举检查、sealed class、implements vs with
- [CITED: api.flutter.dev] — ValueNotifier/ValueListenableBuilder 模式

### Tertiary (LOW confidence)

- (none — 所有关键决策来自项目内部和官方文档)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — 纯 Dart/Flutter 内置功能，无新依赖
- Architecture: HIGH — 基于 Phase 9 已验证的 ISP 模式
- Pitfalls: MEDIUM — togglePlayPause 依赖注入和 mixin 访问权限需要实现时验证

**Research date:** 2026-07-14
**Valid until:** 2026-08-14 (30 days — 稳定技术栈)
