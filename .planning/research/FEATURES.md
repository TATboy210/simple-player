# Feature Landscape: 播放内核重构强化

**Domain:** Flutter 桌面媒体播放器内核
**Researched:** 2026-07-14
**Source:** Codebase analysis of 24 engine files, 7 service files, 7 model files, 39 test files

---

## Table Stakes

内核重构必须实现的功能。缺失任何一项，内核质量无法达标。

### T1. EngineState 接口契约强化

**Why Expected:** 当前 EngineState 是 mixin，12 个 ValueNotifier 字段由 FvpEngine 用 `@override` 逐个重新声明（`fvp_engine.dart:143-186`），导致每个引擎实现都必须手动维护完全相同的字段列表。FakeEngine 也需同样重复（`fake_engine.dart:17-54`）。接口契约不清晰，新增字段时所有实现都必须同步修改。

**Complexity:** Medium

**Notes:**
- 当前 mixin 方式允许默认实现，但实际使用中每个实现都必须 override 所有字段（因为 ValueNotifier 不可共享）
- 应改为 abstract interface class，字段用 getter 声明，实现类自行创建 ValueNotifier
- 参考 `PlayerProxy`（`player_proxy.dart`）的纯接口模式 — 已有先例
- 迁移路径: mixin EngineState → abstract class EngineState（保持 ValueNotifier 作为实现细节）

### T2. FvpEngine 职责拆分与瘦身

**Why Expected:** FvpEngine 当前 641 行，组合了 6 个 helper（FvpCallbackHandler/PositionPoller/TrackManager/VolumeController/SubtitleConfigurator/D3D11Configurator），但 FvpEngine 自身仍承担状态转换守卫（`_safeSetState`）、错误恢复（codec 降级）、生命周期管理、纹理 ID 监听等大量职责。工厂构造函数 45 行（`fvp_engine.dart:52-97`）暴露了构造复杂度。

**Complexity:** High

**Notes:**
- 状态转换守卫 `_safeSetState` 应提取为独立类（如 `StateTransitionGuard`），可复用于其他引擎实现
- 错误恢复逻辑（codec 降级，`fvp_engine.dart:283-293`）应提取为 `ErrorRecoveryStrategy`
- 工厂构造函数中 helper 的创建顺序有隐式依赖（callbackHandler 需要 engine.state），应显式化
- `_guardedAction` 通用守卫模式（`fvp_engine.dart:220-229`）是好模式，但应提升到引擎基类

### T3. 状态模型增强 — MediaState + PlayerError 统一

**Why Expected:** 当前有两套并行的错误体系:
- `MediaErrorType`（`media_error_type.dart`）: 5 个枚举值（file/codec/playback/network/unknown），用于 MediaState.error 时的分类
- `PlayerErrorCode`（`player_error.dart`）: 11 个枚举值（pathEmpty/fileNotFound/pathTraversal/...），更精细但未被引擎层使用

FvpEngine 同时维护 `_errorType`（MediaErrorType）和 `errorMessage`（String），但 PlayerError 是独立的结构化错误类，两者未关联。UI 层无法获得结构化错误信息。

**Complexity:** Medium

**Notes:**
- 应统一为单一错误模型: `PlayerError` 携带 `PlayerErrorCode` + message + cause
- EngineState 暴露 `ValueNotifier<PlayerError?> error` 替代 `errorMessage` + `errorType`
- MediaErrorType 保留为 EngineState 的便捷 getter（从 PlayerError.code 映射）
- `MediaStateTransition` 守卫（`media_state.dart:46-106`）已验证可用，保持不变

### T4. PositionPoller 策略模式重构

**Why Expected:** PositionPoller 当前硬编码 3 种轮询间隔（100ms/250ms/500ms）和切换逻辑（`position_poller.dart:17-29`）。倍速播放时手动调整间隔（`setPlaybackRate`，line 106-109），拖拽时降到 16ms（`setDragMode`，line 98-99）。这些策略交织在一起，新增轮询模式（如网络流缓冲感知轮询）需要修改核心类。

**Complexity:** Low-Medium

**Notes:**
- 已有良好基础: 自适应间隔、seek 后快速轮询、静默降频
- 应提取 `PollStrategy` 接口: `int getIntervalMs(PollContext context)`
- Context 包含: 当前状态、播放速率、是否 seek 后、是否拖拽中、是否 URL
- 现有逻辑可直接迁移为 `DefaultPollStrategy`

### T5. PlaybackController 层级归属修正

**Why Expected:** PlaybackController 当前位于 `lib/features/player/services/`（feature 层），但它管理的是内核级播放逻辑: 播放列表 CRUD、播放导航、状态监控、文件操作。这些不属于任何特定 UI feature，而是播放器核心能力。

**Complexity:** Low

**Notes:**
- 应移至 `lib/kernel/services/`（与 PathValidator 同层）
- PlaybackNavigator/FileOperations/StateMonitor 同步迁移
- UI 层通过 PlaybackController 门面访问，不直接依赖 services 子模块
- SubtitleService 可留在 feature 层（它是 UI 级功能）

### T6. EngineMetrics 结构化 + ValueNotifier 暴露

**Why Expected:** EngineMetrics 当前是纯数据类（`engine_metrics.dart`），手动累加计数器。没有 ValueNotifier 暴露，UI 层只能通过 `engine.metrics` 直接读取（非响应式）。丢帧计数 `framesDropped` 从未被引擎实际更新（FvpEngine 没有调用 `recordFrameDrop`）。

**Complexity:** Low

**Notes:**
- 将关键指标（丢帧率、缓冲次数、平均 seek 耗时）暴露为 ValueNotifier
- 与 FvpCallbackHandler 的 onMediaStatus 回调关联，自动记录 buffer underrun
- `toJson()` 已有，可直接用于调试面板

### T7. open() 流程防御性增强

**Why Expected:** MediaOpener 当前有超时处理（10s prepare + 5s texture），但 FvpEngine.open() 中的错误恢复逻辑（codec 降级重试，`fvp_engine.dart:283-293`）与 MediaOpener 的职责重叠。open() 的 `_isOpening` 守卫是简单的 bool，不处理取消场景。

**Complexity:** Medium

**Notes:**
- `_isOpening` 应升级为 `CancellationToken` 模式: 新 open() 自动取消前一个
- MediaOpener 的 codec 降级应内化（当前由 FvpEngine 外部调用 `_d3d11Configurator.setHardwareDecoding(false)` 后重试）
- 网络流 open() 应支持重试策略（当前 NetworkConfigurator 只配置参数，不处理重连）

---

## Differentiators

提升内核质量的差异化特性。不是必须有的，但能显著提升架构健壮性和可扩展性。

### D1. 引擎能力查询接口（Capability Discovery）

**Value Proposition:** 当前 TrackControl/VideoEffects/RendererConfig 三个 mixin 是空标记（`track_control.dart:16` / `video_effects.dart:14` / `renderer_config.dart:17`），仅用于 Dart 3 pattern matching（`if (engine case TrackControl tc)`）。但所有方法实际定义在 EngineState 上，所有引擎都必须实现所有方法。未来如果有简化引擎（如纯音频播放器），无法省略不支持的功能。

**Complexity:** Medium

**Notes:**
- 将 mixin 从空标记变为真正的接口: `TrackControl` 声明 `switchAudioTrack` 等方法
- EngineState 只保留核心播放控制（open/play/pause/stop/seek/volume）
- 轨道、视频效果、渲染配置作为可选能力，由具体引擎选择性实现
- UI 层通过 pattern matching 检查能力: `if (engine case TrackControl tc) { ... }`
- 已有先例: `PlayerProxy` 就是能力子集接口

### D2. 播放列表持久化与运行时解耦

**Value Proposition:** Playlist 当前同时承担运行时数据结构和序列化逻辑（`playlist.dart:239-278`）。fromJson 有逐项 try-catch 防御（line 258-263），但 mergeHistory（line 156-186）是一次性迁移代码，不应长期存在于核心类中。

**Complexity:** Low-Medium

**Notes:**
- 提取 `PlaylistSerializer` / `PlaylistMigrator`
- Playlist 只保留运行时逻辑: items/currentIndex/mode/navigation
- 序列化格式版本化（当前无版本号，未来迁移困难）
- mergeHistory 迁移到独立迁移脚本或 PlaylistStore

### D3. 引擎生命周期状态机

**Value Proposition:** 当前 MediaState 覆盖播放状态（idle/loading/playing/paused/stopped/completed/error/seeking/buffering），但不覆盖引擎生命周期（created/initializing/ready/disposed）。`_disposed` 是 bool 标志（`fvp_engine.dart:130`），dispose 后的所有操作靠 `if (_disposed) return` 守卫（分散在 20+ 方法中）。

**Complexity:** Medium

**Notes:**
- 新增 `EnginePhase` 枚举: `created → initializing → ready → disposing → disposed`
- 与 MediaState 正交: phase 描述引擎生命周期，state 描述播放状态
- dispose 时自动注销所有 ValueNotifier listeners（当前靠 assert 检查泄漏）
- 为多实例场景打基础: 每个引擎实例有独立的 phase

### D4. TrackManager 增强 — 偏好记忆与多轨支持

**Value Proposition:** TrackManager 当前是薄封装（`track_manager.dart`），只做索引校验 + 委托 mdk。不记忆用户的轨道偏好（每次打开新文件都回到默认轨道），不支持多音轨同时激活（MDK 支持但未暴露）。

**Complexity:** Medium

**Notes:**
- 轨道偏好持久化: 按语言代码记忆（如 "永远优先选择 chi 音轨"）
- 与 SettingsStore 集成，新增 `preferredAudioLanguage` / `preferredSubtitleLanguage`
- 多音轨激活: MDK 的 `activeAudioTracks` 接受 `List<int>`，当前只传 `[trackIndex]`
- 字幕轨道循环切换: 当前 toggleSubtitle 只在第一个和关闭间切换（`track_manager.dart:78-87`），应支持循环所有轨道

### D5. NetworkConfigurator 自适应策略

**Value Proposition:** NetworkConfigurator 当前硬编码每种协议的参数（`network_configurator.dart`）。`configureAdaptive` 方法（line 96-105）只有简单的延迟阈值判断（>500ms → 5MB buffer）。不跟踪实际网络质量，不根据播放卡顿动态调整。

**Complexity:** Medium-High

**Notes:**
- 监听 `isBuffering` ValueNotifier 的频率来评估网络质量
- 卡顿频率过高时自动降低视频质量（如果有多码率源）
- 与 EngineMetrics 的 `bufferUnderruns` 联动
- 为未来 HLS ABR 打基础（参考 `project_hls_abr_plan.md`）

### D6. EngineEventLog 增强 — 结构化诊断导出

**Value Proposition:** EngineEventLog 当前是环形缓冲（`engine_event_log.dart`），100 条容量，不持久化。调试时只能在内存中查看最近事件。无法导出给用户反馈，无法关联到具体播放会话。

**Complexity:** Low

**Notes:**
- 新增 `exportToJson()` → 文件写入（已有 `toJson()` 基础）
- 事件关联 sessionId（每次 open() 生成新 sessionId）
- 与 DebugProbe 联动（`playback_controller.dart:77` 已有 probe）
- 用户反馈场景: "播放卡顿" → 导出最近事件日志

---

## Anti-Features

明确不应在本次重构中实现的功能。每项都有 "为什么不做" 和 "应该怎么做"。

### A1. 更换底层引擎

**Why Avoid:** PROJECT.md 明确约束: "继续使用 fvp (MDK/FFmpeg)，不更换底层"。mpv/libmpv 虽然功能更强（参考 `reference_mpv_architecture.md`），但迁移成本高（FFI 绑定重写、渲染管线重建、测试全部重写），收益不确定。

**What to Do Instead:** 保持 fvp，通过 EngineState 接口抽象隔离引擎细节。如果未来需要换引擎，只需实现新的 EngineState，UI 层零改动。

### A2. 引入 Provider/Riverpod/Bloc 状态管理

**Why Avoid:** PROJECT.md 约束: "继续使用 ValueNotifier + ValueListenableBuilder"。当前项目已有成熟的 ValueNotifier 模式（12 个 ValueNotifier + mixin 组合），引入新框架增加学习成本和迁移风险。

**What to Do Instead:** 保持 ValueNotifier，但强化接口契约（见 T1）。如果需要跨组件状态共享，用 InheritedWidget 注入 EngineState 实例。

### A3. 抽象播放器 UI 组件库

**Why Avoid:** 本次重构专注内核，不涉及 UI 层。PlayerScreen/ControlBar/PlaylistPanel 等组件保持不变。抽象 UI 库会扩大重构范围，增加回归风险。

**What to Do Instead:** 只重构内核层（engine/services/models），UI 层通过 EngineState 接口访问内核。重构完成后 UI 层无需修改（接口不变）。

### A4. 多引擎实例管理

**Why Avoid:** 项目当前是单实例播放器（一个窗口一个引擎）。多实例（画中画、预览窗口）是未来功能，不在本次内核重构范围内。过早引入多实例管理器会增加不必要的复杂度。

**What to Do Instead:** 通过 EnginePhase 生命周期状态机（D3）为多实例打基础，但不实现管理器。每个 FvpEngine 实例已通过工厂构造函数保证独立性。

### A5. HLS ABR 自适应码率

**Why Avoid:** ABR 需要 FFmpeg HLS 解析器 + 码率切换逻辑 + 缓冲区管理，是独立的大型功能（参考 `project_hls_abr_plan.md` 的 6 阶段计划）。与内核重构正交。

**What to Do Instead:** NetworkConfigurator 自适应策略（D5）为 ABR 打基础，但不实现码率切换。MediaOpener 的 open() 流程保持通用，不绑定特定流媒体协议。

### A6. 自定义 FFmpeg 滤镜链编辑器

**Why Avoid:** SubtitleConfigurator 的 setEqualizer 已暴露 FFmpeg 滤镜语法接口（`subtitle_configurator.dart:45-47`）。自定义滤镜链编辑器是 UI 层功能，不是内核需求。

**What to Do Instead:** 保持 `setEqualizer(String afFilter)` 接口，UI 层可以在此基础上构建滤镜选择器。

### A7. 播放列表云端同步

**Why Avoid:** PlaylistStore 当前是本地 JSON 文件持久化。云端同步涉及认证、冲突解决、增量同步等复杂逻辑，与内核重构无关。

**What to Do Instead:** 保持本地持久化，Playlist 的序列化格式版本化（D2）为未来云同步预留扩展点。

---

## Feature Dependencies

```
T1 (EngineState 接口) ──→ T2 (FvpEngine 瘦身) ──→ D1 (能力查询接口)
                 │                                    │
                 └──→ T5 (PlaybackController 迁移)    └──→ D3 (生命周期状态机)
                          │
                          └──→ T7 (open() 防御增强)

T3 (状态模型统一) ──→ T6 (EngineMetrics 暴露) ──→ D6 (EventLog 导出)
       │
       └──→ T4 (PositionPoller 策略)

D2 (Playlist 解耦) ──独立，无前置依赖

D4 (TrackManager 增强) ──依赖 T1 完成后（接口稳定）

D5 (NetworkConfigurator) ──依赖 T7 完成后（open() 流程稳定）
```

**关键路径:** T1 → T2 → D1 → D3

T1 是所有后续工作的基础: 接口不稳，helper 拆分、能力查询、生命周期状态机都无法确定边界。

---

## MVP Recommendation

### 优先实现（Phase 1-2）

1. **T1 EngineState 接口契约强化** — 所有后续工作的基础
2. **T3 状态模型统一** — PlayerError 统一错误体系，消除双轨并行
3. **T5 PlaybackController 层级归属修正** — 低风险，立即改善架构清晰度
4. **T7 open() 流程防御增强** — CancellationToken + 错误恢复内化

### 次优先（Phase 3-4）

5. **T2 FvpEngine 职责拆分** — 依赖 T1 完成
6. **T4 PositionPoller 策略模式** — 独立性好，可并行
7. **T6 EngineMetrics 结构化** — 依赖 T3 完成
8. **D2 Playlist 解耦** — 独立性好，可并行

### 延后（Phase 5+）

9. **D1 引擎能力查询** — 依赖 T2 完成
10. **D3 引擎生命周期状态机** — 依赖 D1
11. **D4 TrackManager 增强** — 接口稳定后再做
12. **D5 NetworkConfigurator 自适应** — open() 流程稳定后再做
13. **D6 EventLog 增强** — 低优先级，调试辅助

### 明确不做

- A1-A7: 范围外或为未来预留

---

## 复杂度评估总结

| Feature | Complexity | Risk | Dependencies | Estimated Effort |
|---------|-----------|------|--------------|-----------------|
| T1 EngineState 接口 | Medium | High (影响所有引擎) | 无 | 2-3 天 |
| T2 FvpEngine 瘦身 | High | Medium (内部重构) | T1 | 3-5 天 |
| T3 状态模型统一 | Medium | Low (向后兼容) | 无 | 1-2 天 |
| T4 PositionPoller 策略 | Low-Medium | Low | 无 | 1 天 |
| T5 PlaybackController 迁移 | Low | Low (移动文件) | 无 | 0.5 天 |
| T6 EngineMetrics 暴露 | Low | Low | T3 | 0.5 天 |
| T7 open() 防御增强 | Medium | Medium (async 逻辑) | 无 | 1-2 天 |
| D1 能力查询接口 | Medium | Medium | T2 | 2 天 |
| D2 Playlist 解耦 | Low-Medium | Low | 无 | 1 天 |
| D3 生命周期状态机 | Medium | Medium | D1 | 2 天 |
| D4 TrackManager 增强 | Medium | Low | T1 | 1-2 天 |
| D5 NetworkConfigurator | Medium-High | Medium | T7 | 2-3 天 |
| D6 EventLog 增强 | Low | Low | T3 | 0.5 天 |

---

## Sources

- Codebase analysis: 24 engine files in `lib/kernel/engine/`
- Codebase analysis: 7 service files in `lib/kernel/services/` + `lib/features/player/services/`
- Codebase analysis: 7 model files in `lib/kernel/models/`
- Codebase analysis: 39 test files in `test/kernel/`
- PROJECT.md: 播放内核重构强化项目定义
- MEMORY.md: 历次重构经验（Window Anti-Patterns, Singleton Refactoring Anti-Pattern, ControlBar Glass Checkpoint）
