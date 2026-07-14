# Architecture Patterns — 播放内核重构

**Domain:** Flutter 桌面媒体播放器内核
**Researched:** 2026-07-14
**Confidence:** HIGH (基于完整源码分析)

---

## 1. 当前架构分析

### 1.1 现有分层

```
┌─────────────────────────────────────────────────────────────┐
│  UI Layer (lib/ui/)                                         │
│  PlayerScreen → ControlsOverlay → ValueListenableBuilder    │
└──────────────────────────┬──────────────────────────────────┘
                           │ 依赖 EngineState (mixin)
┌──────────────────────────▼──────────────────────────────────┐
│  Service Layer (lib/features/player/services/)              │
│  PlaybackController (Facade)                                │
│  ├── PlaybackNavigator (openGeneration 守卫)                │
│  ├── FileOperations (路径验证 + 去重)                        │
│  └── StateMonitor (断点保存 + 设置恢复 + 自动连播)            │
│  + SubtitleService (外挂字幕检测)                            │
└──────────────────────────┬──────────────────────────────────┘
                           │ 依赖 EngineState
┌──────────────────────────▼──────────────────────────────────┐
│  Engine Layer (lib/kernel/engine/)                          │
│  FvpEngine (641行, 6个helper组合)                            │
│  ├── FvpCallbackHandler (mdk回调→ValueNotifier映射)         │
│  ├── PositionPoller (自适应间隔轮询)                         │
│  ├── TrackManager (音轨/字幕轨切换)                          │
│  ├── VolumeController (音量/静音)                            │
│  ├── SubtitleConfigurator (外挂字幕/延迟/均衡器)             │
│  ├── D3D11Configurator (D3D11渲染管线)                      │
│  ├── VideoEffectController (亮度/对比度/旋转/去隔行)         │
│  ├── MediaOpener (打开流程编排)                              │
│  └── NetworkConfigurator (网络流协议配置)                    │
│  + EngineState mixin (12个ValueNotifier + 抽象方法)          │
│  + Capability mixins: TrackControl/VideoEffects/RendererConfig│
│  + EngineMetrics + EngineEventLog (可观测性)                 │
└──────────────────────────┬──────────────────────────────────┘
                           │ FFI / Stream
┌──────────────────────────▼──────────────────────────────────┐
│  Native Layer                                               │
│  fvp (MDK/FFmpeg) → D3D11 Texture                          │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 当前优点

| 优点 | 具体体现 |
|------|----------|
| **工厂构造函数** | FvpEngine 用 factory 消除 late 初始化风险，编译期保证完整性 |
| **helper 组合模式** | 6 个 helper 职责清晰：VolumeController、PositionPoller 等可独立测试 |
| **PlayerProxy 抽象** | VolumeController/SubtitleConfigurator/D3D11Configurator 通过 PlayerProxy 接口解耦 mdk，支持纯 Dart 测试 |
| **CQS 设计** | Playlist.peekNext/peekPrevious 只返回索引不修改状态，调用方显式更新 |
| **openGeneration 守卫** | PlaybackNavigator 的并发 open() 防护，快速切歌时丢弃过期请求 |
| **状态转换守卫** | MediaStateTransition extension 防止非法状态跳转，debug 模式警告 |
| **OpenResult sealed class** | 打开结果用 Dart 3 sealed class，switch 穷尽匹配 |
| **EngineEventLog 环形缓冲** | 轻量级 100 条事件日志，不持久化，调试友好 |
| **NetworkConfigurator** | 协议级低延迟配置（RTSP/RTMP/SRT/UDP/TCP/HTTP），专业级 |

### 1.3 当前问题

| 问题 | 严重度 | 位置 | 描述 |
|------|--------|------|------|
| **EngineState mixin 过大** | HIGH | engine_state.dart | 12 个 ValueNotifier + 30+ 抽象方法全在一个 mixin，违反 ISP |
| **Capability mixins 是空壳** | HIGH | track_control.dart 等 | TrackControl/VideoEffects/RendererConfig 只是 marker，无实际逻辑分离 |
| **FvpEngine 仍 641 行** | MEDIUM | fvp_engine.dart | 虽有 helper，但 open/play/pause/seek + 状态守卫 + dispose 仍在主类 |
| **Service 层位置错误** | MEDIUM | features/player/services/ | PlaybackController 等应在 kernel/ 下，不应在 features/ |
| **StateMonitor 职责混合** | MEDIUM | state_monitor.dart | 设置恢复 + 断点保存 + 自动连播三个不相关职责混在一起 |
| **错误恢复不完善** | MEDIUM | fvp_engine.dart | 仅 codec 错误有软解降级，其他错误无自动恢复 |
| **无状态机实现** | MEDIUM | media_state.dart | 有转换守卫但非强制，_safeSetState debug 模式下仍执行非法转换 |
| **PositionPoller 耦合 mdk** | LOW | position_poller.dart | 直接访问 _player.position，无法独立测试 |
| **缺少多引擎支持** | LOW | — | EngineState 是单例设计，无 multi-instance 考虑 |

---

## 2. 建议的目标架构

### 2.1 分层原则

**依赖方向：UI → Service → Engine → Native（单向，无循环依赖）**

- **Engine 层**：纯播放能力，不关心播放列表、UI 状态、持久化
- **Service 层**：编排 Engine + Playlist + Persistence，不含 UI
- **UI 层**：监听 ValueNotifier，不持有 Engine 引用（通过 Service 间接访问）

### 2.2 目标架构图

```
┌─────────────────────────────────────────────────────────────┐
│  UI Layer                                                   │
│  PlayerScreen ← ValueListenableBuilder(EngineStateView)     │
│  通过 PlaybackController 调用操作，不直接访问 Engine         │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│  Service Layer (lib/kernel/services/)                       │
│  PlaybackController (Facade — 播放列表 CRUD + 生命周期)      │
│  ├── PlaybackNavigator (索引跳转 + openGeneration)          │
│  ├── FileOperations (路径验证 + 去重)                        │
│  ├── PlaybackStateManager (断点保存 + 设置恢复)             │
│  └── AutoAdvancePolicy (自动连播策略 — 从 StateMonitor 提取) │
│  + SubtitleService (外挂字幕检测)                            │
└──────────────────────────┬──────────────────────────────────┘
                           │ 依赖 EngineStateView + PlaybackControl
┌──────────────────────────▼──────────────────────────────────┐
│  Engine Layer (lib/kernel/engine/)                          │
│                                                              │
│  ┌─ EngineStateView (接口，只暴露 ValueNotifier + 读属性) ──┐│
│  │  12 ValueNotifier + mediaInfo + errorType               ││
│  └─────────────────────────────────────────────────────────┘│
│                                                              │
│  ┌─ PlaybackControl (核心播放控制接口) ─────────────────────┐│
│  │  open / play / pause / stop / seekTo / togglePlayPause  ││
│  │  setVolume / setMute / setPlaybackRate / setRange       ││
│  └─────────────────────────────────────────────────────────┘│
│                                                              │
│  ┌─ Capability Interfaces (ISP 拆分) ──────────────────────┐│
│  │  TrackControl: switchAudio/subtitle, toggleSubtitle     ││
│  │  SubtitleConfig: setExternalSubtitle, setSubtitleDelay  ││
│  │  VideoEffectControl: setEffect, rotate, setAspectRatio  ││
│  │  RendererControl: setSyncEnabled, setHardwareDecoding   ││
│  └─────────────────────────────────────────────────────────┘│
│                                                              │
│  ┌─ FullEngine (组合接口) ─────────────────────────────────┐│
│  │  = EngineStateView + PlaybackControl + 所有 Capability  ││
│  └─────────────────────────────────────────────────────────┘│
│                                                              │
│  ┌─ EngineStateMachine (独立状态机) ───────────────────────┐│
│  │  强制状态转换守卫，release 模式也拒绝非法跳转            ││
│  └─────────────────────────────────────────────────────────┘│
│                                                              │
│  ┌─ FvpEngine (具体实现) ──────────────────────────────────┐│
│  │  组合: CallbackHandler + PositionPoller + TrackManager  ││
│  │        VolumeController + MediaOpener + ...             ││
│  │  实现: FullEngine                                       ││
│  └─────────────────────────────────────────────────────────┘│
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│  Native Layer                                               │
│  fvp (MDK/FFmpeg) → D3D11 Texture                          │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. 分层详细设计

### 3.1 EngineStateView — 响应式状态接口

**问题**：当前 EngineState mixin 定义了 12 个 ValueNotifier + 30+ 抽象方法，所有消费者被迫依赖全部接口。

**方案**：拆分为状态接口 + 播放控制接口 + 能力接口。

```dart
// ── 状态暴露（只读观察） ──
/// UI 层和 Service 层通过此接口监听播放状态，不包含任何控制方法。
abstract interface class EngineStateView {
  ValueNotifier<int?> get textureId;
  ValueNotifier<MediaState> get state;
  ValueNotifier<int> get position;
  ValueNotifier<int> get duration;
  ValueNotifier<double> get volume;
  ValueNotifier<bool> get isMuted;
  ValueNotifier<bool> get isBuffering;
  ValueNotifier<String> get subtitleText;
  ValueNotifier<int> get buffered;
  ValueNotifier<double> get aspectRatio;
  ValueNotifier<String?> get errorMessage;
  ValueNotifier<double> get playbackSpeed;

  // 只读属性
  MediaErrorType get errorType;
  MediaInfo get mediaInfo;
  int get subtitleDelay;
}

// ── 播放控制（操作命令） ──
/// Service 层通过此接口控制播放，不含状态暴露。
abstract interface class PlaybackControl {
  Future<void> open(String path);
  void play();
  void pause();
  void stop();
  void togglePlayPause();
  Future<void> seekTo(int ms);
  void setVolume(double volume);
  void setMute(bool mute);
  void setPlaybackRate(double rate);
  void setRange({required int from, int to = -1});
  void skipForward([int ms = 10000]);
  void skipBack([int ms = 10000]);
  void dispose();
}

// ── 能力接口（ISP 拆分） ──
abstract interface class TrackControl {
  List<AudioTrackInfo> getAudioTracks();
  void switchAudioTrack(int trackId);
  List<int> get activeAudioTracks;
  List<SubtitleTrackInfo> getSubtitleTracks();
  void switchSubtitleTrack(int trackId);
  void toggleSubtitle();
}

abstract interface class SubtitleConfig {
  void setExternalSubtitle(String path);
  void setSubtitleDelay(int delay);
  void setEqualizer(String preset);
}

abstract interface class VideoEffectControl {
  void setVideoEffect(VideoEffectType effectType, double value);
  void rotate(int degrees);
  void setAspectRatio(double ratio);
  void setDeinterlace(bool enable);
}

abstract interface class RendererControl {
  void setD3d11SyncEnabled(bool enabled);
  void setHardwareDecoding(bool enabled);
}
```

**组合接口**（方便 Service 层使用）：

```dart
/// 完整引擎能力 — 组合所有子接口。
/// FvpEngine 实现此接口，Service 层依赖此接口。
abstract interface class FullEngine
    implements
        EngineStateView,
        PlaybackControl,
        TrackControl,
        SubtitleConfig,
        VideoEffectControl,
        RendererControl {}
```

### 3.2 EngineStateMachine — 独立状态机

**问题**：当前 `_safeSetState` 在 debug 模式下仍执行非法转换（只打印警告），release 模式下静默忽略但不一致。

**方案**：提取独立状态机类，强制守卫。

```dart
/// 播放状态机 — 强制合法状态转换
///
/// 职责:
///   - 维护当前 MediaState
///   - 验证所有状态转换的合法性
///   - 拒绝非法转换（debug 报错，release 静默拒绝）
///   - 发射状态变更事件
class EngineStateMachine {
  final ValueNotifier<MediaState> _state;

  EngineStateMachine(this._state);

  MediaState get current => _state.value;

  /// 尝试转换状态 — 返回是否成功
  ///
  /// debug 模式下非法转换抛出 AssertionError（测试可捕获）
  /// release 模式下非法转换返回 false，状态不变
  bool tryTransition(MediaState next, String caller) {
    if (!current.canTransitionTo(next)) {
      assert(() {
        debugPrint('Illegal: $caller: $current -> $next');
        return true;
      }());
      return false;
    }
    _state.value = next;
    return true;
  }

  /// 强制设置状态 — 跳过守卫（仅用于错误恢复等特殊场景）
  void forceSet(MediaState next, String reason) {
    debugPrint('Force state: $current -> $next ($reason)');
    _state.value = next;
  }
}
```

### 3.3 Service 层重构

**问题 1**：PlaybackController 等在 `features/player/services/`，不在 `kernel/` 下，边界不清。

**方案**：Service 层移入 `kernel/services/`，features/ 只放 UI 相关代码。

**问题 2**：StateMonitor 混合了三个不相关职责。

**方案**：拆分为 PlaybackStateManager + AutoAdvancePolicy。

```
lib/kernel/services/
├── playback_controller.dart      # Facade — 不变
├── playback_navigator.dart       # 索引跳转 — 不变
├── file_operations.dart          # 文件操作 — 不变
├── playback_state_manager.dart   # 从 StateMonitor 提取: 设置恢复 + 断点保存
└── auto_advance_policy.dart      # 从 StateMonitor 提取: 自动连播策略
```

```dart
/// 自动连播策略 — 从 StateMonitor 独立出来
///
/// 为后续 ABR 多实例做准备：每个实例可有独立的连播策略。
class AutoAdvancePolicy {
  AutoAdvancePolicy(this._playlist, this._navigator);

  final Playlist _playlist;
  final PlaybackNavigator _navigator;

  /// 播放完成时的处理逻辑
  Future<void> onCompleted() async {
    if (_playlist.mode == PlayMode.loopSingle) {
      final idx = _playlist.currentIndex;
      if (idx >= 0) await _navigator.playIndex(idx);
    } else {
      await _navigator.playNext();
    }
  }
}
```

### 3.4 PositionPoller 解耦

**问题**：PositionPoller 直接访问 `mdk.Player.position`，无法独立测试。

**方案**：引入 PositionSource 接口。

```dart
/// 位置数据源 — 抽象 mdk 依赖
abstract interface class PositionSource {
  int get position;
  int buffered();
}

/// mdk 实现
class MdkPositionSource implements PositionSource {
  MdkPositionSource(this._player);
  final mdk.Player _player;

  @override
  int get position => _player.position;

  @override
  int buffered() => _player.buffered();
}
```

---

## 4. 数据流设计

### 4.1 命令流（UI → Engine）

```
UI (Button tap)
  │
  ▼
PlaybackController.playIndex(5)
  │
  ▼
PlaybackNavigator.playIndex(5)
  ├── PathValidator.validate(path)
  ├── engine.open(path)
  │     ├── MediaOpener.open(path)
  │     │     ├── mdk.Player.prepare()
  │     │     ├── _parseMetadata()
  │     │     └── mdk.Player.updateTexture()
  │     └── EngineStateMachine.tryTransition(loading → idle)
  ├── engine.seekTo(savedPosition)
  ├── subtitleService.detectAndLoad(path)
  └── engine.play()
        ├── mdk.Player.state = playing
        └── EngineStateMachine.tryTransition(idle → playing)
```

### 4.2 状态通知流（Engine → UI）

```
mdk.Player (native callbacks)
  │
  ▼
FvpCallbackHandler
  ├── onStateChanged → mapMdkState() → state.value = mapped
  └── onMediaStatus → isBuffering.value / state.value (buffering/completed)
  │
  ▼ (ValueNotifier notifies listeners)
  │
StateMonitor (onStateChange)
  ├── paused → save breakpoint
  └── completed → AutoAdvancePolicy.onCompleted()
  │
  ▼
UI (ValueListenableBuilder)
  └── PlayerScreen rebuilds based on state/position/volume
```

### 4.3 数据一致性保证

| 机制 | 位置 | 作用 |
|------|------|------|
| **openGeneration** | PlaybackNavigator | 快速切歌时丢弃过期异步 open() |
| **canTransitionTo** | MediaStateTransition | 防止非法状态跳转 |
| **_disposed 守卫** | FvpEngine | dispose 后所有操作 no-op |
| **isOpening 守卫** | FvpEngine.open | 防止并发 open() |
| **CQS 分离** | Playlist.peekNext | 查询不修改状态 |
| **seeking 标志** | PositionPoller | seek 期间暂停轮询 |

---

## 5. 为后续功能的架构准备

### 5.1 ABR (自适应码率)

**当前阻碍**：MediaOpener 只处理单文件打开，无流切换能力。

**架构准备**：
- `MediaOpener` 提取 `MediaOpenStrategy` 接口：`LocalFileStrategy` / `NetworkStreamStrategy` / `AbrStreamStrategy`
- `NetworkConfigurator.configureAdaptive()` 已有延迟自适应基础
- `PositionPoller` 的 buffered 轮询已支持网络流

```dart
/// 媒体打开策略 — 为 ABR 做准备
abstract interface class MediaOpenStrategy {
  Future<OpenResult> open(mdk.Player player, String path);
}

class LocalFileStrategy implements MediaOpenStrategy { ... }
class NetworkStreamStrategy implements MediaOpenStrategy { ... }
// 未来: class AbrStreamStrategy implements MediaOpenStrategy { ... }
```

### 5.2 多实例播放

**当前阻碍**：EngineState 是单例设计，FvpEngine.factory 创建全局唯一实例。

**架构准备**：
- `EngineStateView` 接口化，UI 不依赖具体实例
- `PlaybackController` 接受 `FullEngine` 注入，不创建实例
- `AutoAdvancePolicy` 独立于 PlaybackController，每个实例可有独立策略

```dart
// 未来多实例示例
final mainEngine = FvpEngine();      // 主播放器
final previewEngine = FvpEngine();   // 预览窗口

final mainController = PlaybackController(engine: mainEngine, playlist: mainPlaylist);
final previewController = PlaybackController(engine: previewEngine, playlist: previewPlaylist);
```

### 5.3 插件化引擎

**当前阻碍**：FvpEngine 硬编码 mdk 依赖。

**架构准备**：
- `FullEngine` 接口 + `PlayerProxy` 已有抽象层
- 新引擎只需实现 `FullEngine` 接口
- `PlaybackController` 依赖 `FullEngine` 接口，不依赖具体实现

### 5.4 错误恢复增强

**当前**：仅 codec 错误有软解降级。

**架构准备**：
- `EngineStateMachine.forceSet()` 用于错误恢复场景
- `MediaOpener` 返回 `OpenResult` sealed class，错误类型明确
- 可在 PlaybackNavigator 层添加重试策略：

```dart
/// 重试策略 — 为错误恢复做准备
class RetryPolicy {
  static const maxRetries = 3;
  static const retryDelay = Duration(seconds: 1);

  /// 判断是否应该重试
  static bool shouldRetry(MediaErrorType type, int attempt) {
    if (attempt >= maxRetries) return false;
    // 网络错误和 codec 错误可重试，文件错误不重试
    return type == MediaErrorType.network || type == MediaErrorType.codec;
  }
}
```

---

## 6. 建议的重构顺序

### Phase 1: 接口拆分（ISP）

**目标**：将 EngineState mixin 拆分为 EngineStateView + PlaybackControl + 能力接口

| 步骤 | 内容 | 风险 | 估计 |
|------|------|------|------|
| 1.1 | 定义 EngineStateView 接口 | 低 | 2h |
| 1.2 | 定义 PlaybackControl 接口 | 低 | 1h |
| 1.3 | 定义 TrackControl/SubtitleConfig/VideoEffectControl/RendererControl 接口 | 低 | 2h |
| 1.4 | FvpEngine 实现 FullEngine 组合接口 | 中 | 3h |
| 1.5 | UI 层改为依赖 EngineStateView（而非完整 Engine） | 中 | 2h |
| 1.6 | 移除空壳 capability mixins | 低 | 1h |

**产出**：接口清晰，UI 只依赖状态观察，Service 依赖控制接口

### Phase 2: 状态机提取

**目标**：将状态管理从 FvpEngine 提取到独立 EngineStateMachine

| 步骤 | 内容 | 风险 | 估计 |
|------|------|------|------|
| 2.1 | 实现 EngineStateMachine 类 | 低 | 2h |
| 2.2 | FvpEngine 使用 EngineStateMachine 替代 _safeSetState | 中 | 3h |
| 2.3 | 添加强制状态机测试 | 低 | 2h |

**产出**：状态转换强制守卫，可独立测试

### Phase 3: Service 层重组

**目标**：Service 层移入 kernel/，StateMonitor 拆分

| 步骤 | 内容 | 风险 | 估计 |
|------|------|------|------|
| 3.1 | 将 features/player/services/ 移入 kernel/services/ | 中 | 2h |
| 3.2 | 从 StateMonitor 提取 PlaybackStateManager | 低 | 2h |
| 3.3 | 从 StateMonitor 提取 AutoAdvancePolicy | 低 | 1h |
| 3.4 | 更新所有 import 路径 | 中 | 1h |

**产出**：职责边界清晰，Service 层在正确位置

### Phase 4: Engine 解耦

**目标**：PositionPoller/MediaOpener 解耦 mdk 依赖

| 步骤 | 内容 | 风险 | 估计 |
|------|------|------|------|
| 4.1 | 定义 PositionSource 接口 | 低 | 1h |
| 4.2 | PositionPoller 使用 PositionSource | 中 | 2h |
| 4.3 | 定义 MediaOpenStrategy 接口 | 低 | 1h |
| 4.4 | MediaOpener 拆分为 LocalFileStrategy + NetworkStreamStrategy | 中 | 3h |
| 4.5 | FvpEngine 组合注入策略 | 中 | 2h |

**产出**：引擎组件可独立测试，ABR 架构准备就绪

### Phase 5: 错误恢复 + 清理

**目标**：增强错误恢复，清理技术债

| 步骤 | 内容 | 风险 | 估计 |
|------|------|------|------|
| 5.1 | 实现 RetryPolicy | 低 | 2h |
| 5.2 | PlaybackNavigator 集成重试 | 中 | 2h |
| 5.3 | FvpEngine 行数优化（目标 < 400 行） | 中 | 3h |
| 5.4 | 更新测试覆盖 | 低 | 3h |

**产出**：错误恢复可靠，代码质量达标

---

## 7. 关键设计决策

| 决策 | 选择 | 理由 | 备选方案 |
|------|------|------|----------|
| **接口 vs 继承** | abstract interface class | Dart 3 原生支持，类型安全，多重实现 | mixin（已有，ISP 差） |
| **状态管理模式** | 保持 ValueNotifier | 项目约定，不引入新框架 | ChangeNotifier（类似） |
| **Service 层位置** | kernel/services/ | 与 kernel/engine/ 平级，边界清晰 | 保持 features/（当前位置） |
| **状态机实现** | 独立 EngineStateMachine 类 | 可测试，职责单一 | 保留 mixin 内（当前） |
| **策略模式** | MediaOpenStrategy | 为 ABR 做准备，开闭原则 | 修改 MediaOpener（侵入式） |
| **错误恢复** | RetryPolicy 独立类 | 可配置，可测试 | 内联在 Navigator（当前） |

---

## Sources

- 源码分析: `lib/kernel/engine/fvp_engine.dart` (641行)
- 源码分析: `lib/kernel/engine/engine_state.dart` (82行)
- 源码分析: `lib/features/player/services/playback_controller.dart` (177行)
- 源码分析: `lib/features/player/services/playback_navigator.dart` (118行)
- 源码分析: `lib/features/player/services/state_monitor.dart` (163行)
- 源码分析: `lib/features/player/services/file_operations.dart` (93行)
- 源码分析: `lib/kernel/engine/position_poller.dart` (169行)
- 源码分析: `lib/kernel/engine/media_opener.dart` (188行)
- 源码分析: `lib/kernel/engine/fvp_callback_handler.dart` (116行)
- 源码分析: `lib/kernel/engine/track_manager.dart` (88行)
- 源码分析: `lib/kernel/playlist/playlist.dart` (283行)
- 源码分析: `lib/kernel/models/media_state.dart` (106行)
- 源码分析: 所有 capability mixins (track_control/video_effects/renderer_config)
- 源码分析: PlayerProxy + MdkPlayerProxy
- 源码分析: EngineMetrics + EngineEventLog
- 源码分析: NetworkConfigurator + D3D11Configurator
- 源码分析: VolumeController + SubtitleConfigurator + VideoEffectController
