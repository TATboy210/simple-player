# Phase 3: 接口优化 - Context

**Gathered:** 2026-06-29
**Status:** Ready for planning

<domain>
## Phase Boundary

通过 mixin 拆分 PlayerEngine 的 30 个成员为能力组（TrackControl / VideoEffects / RendererConfig），实现 UI 层的能力隔离检查（`engine is TrackControl`），保持 57 个 UI 文件零修改。

**Requirements:** IFACE-01 ~ IFACE-05
</domain>

<decisions>
## Implementation Decisions

### Dart Mixin 机制
- **D-01:** 使用 `mixin TrackControl on PlayerEngine` 形式，限定在 PlayerEngine 体系内使用
- **D-02:** mixin 内部只有 abstract 方法签名（纯接口），不提供默认实现
- **D-03:** FvpEngine 现有委托模式不变（`_guardedAction` → helper 类）

### Mixin 方法边界
- **D-04:** TrackControl (9 方法): `getAudioTracks`, `switchAudioTrack`, `activeAudioTracks`, `getSubtitleTracks`, `switchSubtitleTrack`, `toggleSubtitle`, `setExternalSubtitle`, `setSubtitleDelay`, `setEqualizer`
- **D-05:** VideoEffects (4 方法): `setVideoEffect`, `rotate`, `setAspectRatio`, `setDeinterlace`
- **D-06:** RendererConfig (2 方法): `setD3d11SyncEnabled`, `setHardwareDecoding`
- **D-07:** 基类保留: 12 ValueNotifiers + 3 getters + 核心播放方法 + dispose (15 成员)
- **D-08:** 所有 12 个 ValueNotifier 留在 PlayerEngine 基类，mixin 不包含状态

### MockEngine 适配
- **D-09:** MockEngine `with TrackControl, VideoEffects, RendererConfig`
- **D-10:** mixin 方法已有 MockEngine 的 stub 实现（MockEngine 已实现完整 PlayerEngine 接口）
- **D-11:** 测试中 `engine is TrackControl` == true

### 向后兼容策略
- **D-12:** PlayerEngine abstract class 不变
- **D-13:** FvpEngine 签名改为 `class FvpEngine extends PlayerEngine with TrackControl, VideoEffects, RendererConfig`
- **D-14:** 57 个 UI 文件的 PlayerEngine import 和类型声明零修改
- **D-15:** UI 层用 Dart 3 pattern matching 做能力检查: `if (engine case TrackControl tc) { ... }`

### Claude's Discretion
- mixin 文件组织方式（一个文件 vs 每个 mixin 一个文件）留给 Planner 决定
- 具体哪些 UI 文件需要加能力检查留给 Planner 分析

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 架构与结构
- `.planning/PROJECT.md` — 项目全局上下文、技术发现、关键决策
- `.planning/REQUIREMENTS.md` — IFACE-01 ~ IFACE-05 需求定义
- `.planning/ROADMAP.md` — Phase 3 成功标准
- `.planning/codebase/ARCHITECTURE.md` — 4 层架构、设计模式、数据流
- `.planning/codebase/STRUCTURE.md` — 目录布局、命名规范、最大文件列表

### 前序 Phase 决策
- `.planning/phases/02-engine-composition/02-CONTEXT.md` — Phase 2 委托模式、ValueNotifier 所有权、helper 类结构

### 引擎接口
- `lib/kernel/engine/player_engine_base.dart` — PlayerEngine 抽象接口（12 ValueNotifiers + 3 getters + 15 方法）
- `lib/kernel/engine/player_engine.dart` — barrel export 文件（8 个导出符号）
- `lib/kernel/engine/fvp_engine.dart` — FvpEngine 具体实现（724 行，8 个 helper）

### 测试
- `test/helpers/fake_engine.dart` — MockEngine 测试替身（438 行）

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `TrackManager` helper: 音频/字幕轨道选择与切换逻辑已封装
- `VideoEffectController` helper: 视频特效控制已封装
- `D3D11Configurator` helper: D3D11 配置已封装（Phase 2 已委托）
- `VolumeController` / `SubtitleConfigurator`: 音量/字幕配置已委托

### Established Patterns
- 委托模式: FvpEngine `_guardedAction` → helper.method()
- ValueNotifier 所有权: `final` 字段在 FvpEngine，helper 通过构造函数接收引用
- barrel export: `player_engine.dart` 导出 8 个符号

### Integration Points
- UI 层通过 `PlayerEngine` 类型访问引擎（57 个文件）
- `PlaybackController` 持有 `PlayerEngine` 引用
- `PlayerServices` 创建 `FvpEngine` 实例
- `settings_panel.dart` / `audio_tab.dart` / `video_tab.dart` 可能需要能力检查

</code_context>

<specifics>
## Specific Ideas

- 使用 Dart 3 pattern matching (`if (engine case TrackControl tc)`) 而非 `is` + `as` cast
- mixin 文件组织建议: 每个 mixin 独立文件（`track_control.dart`, `video_effects.dart`, `renderer_config.dart`）
- PlayerEngine 来源确认: 从 `widget_tree_flutter/player_engine` 1:1 复制，Phase 1 已本地化

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 3-接口优化*
*Context gathered: 2026-06-29*
