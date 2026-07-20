# MediaEngine 迁移顺序

> Phase 21 VERIFY-03: 迁移顺序由依赖图推导，非主观判断。
> Generated: 2026-07-20 via codegraph dependency analysis.

---

## 1. 依赖图摘要

MediaEngine 是 7 个 ISP 子接口的组合类型。FvpEngine implements MediaEngine，KernelAdapter
routes per-method via DelegationPolicy. UI widgets consume EngineStateView (read-only) while
services consume MediaEngine (read-only + control).

```
┌─────────────────────────────────────────────────────────────────────┐
│                        UI Binding Layer                             │
│  PlayerScreen · ControlsOverlay · ProgressBar · VolumeControls      │
│  SpeedButton · MediaInfoDialog · KeyboardHandler                    │
│  ↕ ValueNotifier listen + control method calls                      │
├─────────────────────────────────────────────────────────────────────┤
│                     State Management Layer                           │
│  EngineStateView (11 ValueNotifiers + mediaInfo + stateMachine)     │
│  ← EngineStateMachine · PositionPoller · VolumeController           │
├─────────────────────────────────────────────────────────────────────┤
│                      Orchestrator Layer                              │
│  PlaybackControl (open/play/pause/seekTo/stop/togglePlayPause/...)  │
│  ← depends on: VolumeController · EngineStateMachine · MediaOpener  │
│  ← consumed by: PlaybackNavigator · FileOperations · ProgressBar    │
│                 · PlayerScreen · StateMonitor                        │
├─────────────────────────────────────────────────────────────────────┤
│                         Leaf Layer                                   │
│  VideoEffectControl · RendererControl · TrackControl                │
│  SubtitleConfig · VolumeControl                                     │
│  ← delegates to: VideoEffectController · D3D11Configurator          │
│                  · TrackManager · SubtitleConfigurator · VolumeCtrl  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. 组件清单（按层）

### Layer 1: Leaf (无下游依赖)

| ISP 接口 | 成员数 | 委托目标 | 生产调用者 |
|----------|--------|----------|-----------|
| **VideoEffectControl** | 4 methods | VideoEffectController | SettingsDialog |
| **RendererControl** | 2 methods | D3D11Configurator | SettingsDialog, open() fallback |
| **TrackControl** | 3 members | TrackManager | SettingsDialog, TrackPreferenceService |
| **SubtitleConfig** | 8 members | TrackManager + SubtitleConfigurator | SettingsDialog, SubtitleService |
| **VolumeControl** | 4 members | VolumeController | VolumeControls, PlayerScreen, StateMonitor |

Leaf 层合计: **21 members** — 所有方法通过 `_guardedAction` 包裹，不修改播放状态机，
不触发状态转换，失败仅写 lastError。

### Layer 2: Orchestrator (依赖 Leaf 层 helpers)

| ISP 接口 | 成员数 | 核心调用者 | 风险 |
|----------|--------|-----------|------|
| **PlaybackControl** | 12 methods | PlaybackNavigator, PlayerScreen, ProgressBar | HIGH |

方法明细:
- `open()` — 最复杂，涉及 async + generation guard + codec fallback + state transitions
- `play()` / `pause()` / `stop()` — 状态转换 + position poller 控制
- `seekTo()` — async + isSeeking flag + position clamp
- `togglePlayPause()` — 委托状态机
- `setVolume()` / `setMute()` — 委托 VolumeController（与 VolumeControl 共享实现）
- `setPlaybackRate()` / `setRange()` / `skipForward()` / `skipBack()` — 直接委托 mdk

### Layer 3: State Management (依赖编排器状态转换)

| ISP 接口 | 成员数 | 消费者 | 约束 |
|----------|--------|--------|------|
| **EngineStateView** | 14 members | 所有 UI widgets | ADAPT-03: identity-preserving forwarding |

关键约束 (Blocking Constraint #6):
- ValueNotifier 实例必须是引擎自身的（不能包装新 notifier），否则 UI listeners 脱钩。
- KernelAdapter 已通过 `_legacy.xxx` / `_migrated.xxx` 实现 identity-preserving forwarding。

### Layer 4: UI Binding (依赖状态管理)

| 组件 | 依赖的状态 | 调用的控制方法 |
|------|-----------|---------------|
| **PlayerScreen** | state, position, duration, volume, isMuted, isBuffering | togglePlayPause, seekTo, setVolume, setMute, skipForward, skipBack |
| **ProgressBar** | position, duration, buffered | seekTo |
| **ControlsOverlay** | state, isBuffering, playbackSpeed | (间接 via ControlBar) |
| **VolumeControls** | volume, isMuted | setVolume, setMute |
| **SpeedButton** | playbackSpeed | setPlaybackRate |
| **MediaInfoDialog** | mediaInfo | (read-only) |
| **KeyboardHandler** | (varies) | All PlaybackControl methods |

---

## 3. 推荐迁移顺序

### 策略: 叶子优先 (Dependency-Graph-Driven)

从依赖图推导: 先迁移无下游依赖的叶子层，确保底层稳定后再迁移上层。
每层内按成员数从小到大排列（小改动先验证基础设施，大改动后做）。

| 顺序 | 层 | 接口/组件 | 成员数 | 理由 |
|------|-----|----------|--------|------|
| 1 | Leaf | RendererControl | 2 | 最小接口，仅 2 个 setter |
| 2 | Leaf | VideoEffectControl | 4 | 纯 setter，无状态副作用 |
| 3 | Leaf | TrackControl | 3 | 查询+切换，无状态转换 |
| 4 | Leaf | VolumeControl | 4 | setter + ValueNotifier，被 PlaybackControl 共享 |
| 5 | Leaf | SubtitleConfig | 8 | 最大叶子，含延迟+均衡器 |
| 6 | Orchestrator | PlaybackControl (非 open) | 11 | play/pause/seek 等，不含 open |
| 7 | Orchestrator | PlaybackControl.open | 1 | 最复杂方法，单独迁移 |
| 8 | State | EngineStateView | 14 | ValueNotifier 身份转发，Blocking #6 |
| 9 | UI | UI widgets | ~7 | 最后迁移，依赖状态层稳定 |

---

## 4. Phase 20 实际翻转顺序对比

Phase 20 D11 采用**核心优先**策略: 先翻转最关键路径建立信心。

| 翻转序 | Phase 20 D11 (核心优先) | 依赖图推荐 (叶子优先) | 差异分析 |
|--------|------------------------|----------------------|----------|
| 1 | **open()** | RendererControl (2) | D11 先攻最高风险；依赖图先铺底 |
| 2 | **play()** | VideoEffectControl (4) | — |
| 3 | **pause()** | TrackControl (3) | — |
| 4 | **seek()** | VolumeControl (4) | — |
| 5 | **volume()** | SubtitleConfig (8) | — |
| 6 | **mute()** | PlaybackControl 非 open (11) | — |
| 7 | ...其他叶子方法 | PlaybackControl.open (1) | — |
| 8 | — | EngineStateView (14) | D11 未明确分层 |
| 9 | — | UI widgets | D11 未涉及 UI |

**两种策略对比:**
- **核心优先 (D11):** 先验证 open→play→pause→seek 等关键路径，早期暴露状态机问题。
  适合首次重构（Phase 20），目标是建立对新引擎的信心。
- **叶子优先 (依赖图):** 先迁移无副作用的 setter 方法，每步影响最小。
  适合渐进验证（Phase 21 回归），目标是零风险逐层翻转。

**结论:** 两种策略互补。Phase 20 核心优先验证了新引擎正确性；
Phase 21 回归验证应按依赖图分层确认每层行为一致。

---

## 5. 风险评估

### 高风险 (CRITICAL)

| 组件 | 风险因素 | 影响范围 | 缓解措施 |
|------|----------|----------|----------|
| **open()** | async + generation guard + codec fallback + 4 种错误类型 | 全链路 | Phase 20 已翻转验证 |
| **EngineStateView** | ValueNotifier 身份转发 (Blocking #6) | 所有 UI widgets | identity-preserving forwarding 已实现 |
| **seekTo()** | async + isSeeking flag + position restore on error | ProgressBar, PlayerScreen | Phase 20 已翻转验证 |

### 中等风险 (HIGH)

| 组件 | 风险因素 | 影响范围 |
|------|----------|----------|
| **play() / pause()** | 状态转换 + position poller 控制 | PlaybackNavigator, EngineStateMachine |
| **VolumeControl** | 被 PlaybackControl 共享实现 | VolumeControls, StateMonitor, PlayerScreen |

### 低风险 (MEDIUM)

| 组件 | 风险因素 | 影响范围 |
|------|----------|----------|
| **SubtitleConfig** | 8 个成员，委托链较长 | SettingsDialog |
| **VideoEffectControl** | 纯 setter，无状态副作用 | SettingsDialog |
| **RendererControl** | 最小接口，仅 2 个 setter | SettingsDialog |

### 最低风险 (LOW)

| 组件 | 风险因素 |
|------|----------|
| **TrackControl** | 查询+切换，无状态转换 |
| **setPlaybackRate / setRange / skipForward / skipBack** | 直接委托 mdk，无状态机交互 |

---

## 6. 方法级调用者矩阵

下表记录每个 MediaEngine 方法的生产代码调用者（不含测试），用于迁移影响评估。

| 方法 | 调用者 (production) |
|------|---------------------|
| `open()` | PlaybackNavigator |
| `play()` | PlaybackNavigator, EngineStateMachine.onPlay |
| `pause()` | EngineStateMachine.onPause |
| `stop()` | PlaybackController.removeAt, PlaybackController.clearPlaylist |
| `togglePlayPause()` | PlayerScreen (keyboard Space) |
| `seekTo()` | PlaybackNavigator, ProgressBar (drag/tap), PlayerScreen (keyboard) |
| `setVolume()` | StateMonitor, PlayerScreen (keyboard Up/Down), VolumeControls |
| `setMute()` | PlayerScreen (keyboard M), VolumeControls |
| `setPlaybackRate()` | SpeedButton |
| `setRange()` | (none found in production callers) |
| `skipForward()` | PlayerScreen (keyboard Right) |
| `skipBack()` | PlayerScreen (keyboard Left) |
| `getAudioTracks()` | SettingsDialog |
| `switchAudioTrack()` | SettingsDialog, TrackPreferenceService |
| `getSubtitleTracks()` | SettingsDialog |
| `switchSubtitleTrack()` | SettingsDialog |
| `toggleSubtitle()` | PlayerScreen (keyboard S) |
| `setExternalSubtitle()` | SettingsDialog |
| `setSubtitleDelay()` | PlayerScreen (keyboard \[ /\]) |
| `setEqualizer()` | SettingsDialog |
| `setVideoEffect()` | SettingsDialog |
| `rotate()` | SettingsDialog |
| `setAspectRatio()` | PlayerScreen (keyboard A) |
| `setDeinterlace()` | SettingsDialog |
| `setD3d11SyncEnabled()` | SettingsDialog |
| `setHardwareDecoding()` | SettingsDialog (or open() codec fallback internally) |
| `volume` (notifier) | ProgressBar, PlayerScreen, VolumeControls, ControlsOverlay |
| `isMuted` (notifier) | VolumeControls |
| `state` (notifier) | PlayerScreen, ControlsOverlay, PlaybackNavigator |
| `position` (notifier) | ProgressBar, PlayerScreen |
| `duration` (notifier) | ProgressBar, PlayerScreen |
| `isBuffering` (notifier) | ControlsOverlay, PlayerScreen |
| `isSeeking` (notifier) | ProgressBar |
| `playbackSpeed` (notifier) | SpeedButton |
| `buffered` (notifier) | ProgressBar |
| `aspectRatio` (notifier) | PlayerScreen |
| `lastError` (notifier) | PlayerScreen |
| `subtitleText` (notifier) | PlayerScreen |
| `textureId` (notifier) | VideoSurface |
