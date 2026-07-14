# Simple Player — 播放内核重构强化

## What This Is

对 Simple Player Flutter 桌面播放器的核心内核进行全面重构强化。覆盖从播放引擎抽象（MediaEngine/FvpEngine）到服务编排层（PlaybackController/Playlist/TrackManager）的完整内核栈，目标是提升代码质量、修复稳定性问题、为后续功能（ABR、多实例、插件化等）打下架构基础。

## Core Value

播放内核的健壮性与可扩展性 — 引擎抽象清晰、状态一致、错误恢复可靠、新功能易于接入。

## Requirements

### Validated

- ✓ 播放核心功能（播放/暂停/seek/音量/播放模式）— 现有
- ✓ fvp (MDK/FFmpeg) 播放引擎集成 — 现有
- ✓ ValueNotifier + ValueListenableBuilder 状态管理 — 现有
- ✓ 键盘快捷键系统（20+ 快捷键）— 现有
- ✓ 毛玻璃设计语言（GlassContainer、Tokens.*）— 现有
- ✓ 沉浸式全屏功能 — v2.0 已完成

### Active

- [ ] 播放引擎抽象重构 — MediaEngine/FvpEngine 接口设计、状态机、错误恢复、生命周期管理
- [ ] 播放控制服务重构 — PlaybackController 编排逻辑、Playlist 管理、PlayMode 实现
- [ ] 轨道管理重构 — Audio/Subtitle track 选择、切换、延迟同步
- [ ] 状态模型重构 — MediaState 状态模型、状态变更通知、状态一致性保证

### Out of Scope

- 底层引擎更换 — 继续使用 fvp (MDK/FFmpeg)
- UI 层改动 — 本次专注内核，不改播放器界面
- 状态管理模式更换 — 继续使用 ValueNotifier + ValueListenableBuilder
- 新增播放功能 — 本次只重构现有功能的内核实现

## Context

**技术环境：**
- Flutter 桌面播放器，Windows 为主平台
- fvp (MDK/FFmpeg) 作为播放引擎
- ValueNotifier + ValueListenableBuilder 状态管理
- 毛玻璃设计语言（GlassContainer + Tokens.*）

**当前内核结构：**
- `lib/kernel/engine/media_engine.dart` — 抽象引擎接口
- `lib/kernel/engine/fvp_engine.dart` — fvp 具体实现
- `lib/kernel/engine/position_poller.dart` — Timer-based 位置更新
- `lib/kernel/engine/track_manager.dart` — 音频/字幕轨道管理
- `lib/kernel/services/playback_controller.dart` — 播放编排器
- `lib/kernel/services/playback_navigator.dart` — 曲目推进逻辑
- `lib/kernel/playlist/playlist.dart` — 播放列表模型
- `lib/kernel/models/media_state.dart` — 播放状态枚举

**已知问题：**
- 引擎抽象层职责不够清晰，状态管理分散
- PlaybackController 过于庞大，职责混合
- 错误恢复机制不完善，边界情况处理差
- 状态变更通知缺乏一致性保证
- 为后续功能扩展（ABR、多实例等）缺乏架构准备

## Constraints

- **引擎绑定**: 继续使用 fvp (MDK/FFmpeg)，不更换底层
- **状态管理**: 继续使用 ValueNotifier + ValueListenableBuilder，不引入新状态管理框架
- **UI 不动**: 本次重构不涉及播放器界面改动
- **平台**: 以 Windows 为主，macOS/Linux 次要

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 保持 fvp 引擎 | MDK/FFmpeg 能力足够，更换成本高 | — Pending |
| ValueNotifier 不变 | 项目已有成熟模式，引入新框架增加复杂度 | — Pending |
| 内核与 UI 解耦重构 | 允许独立演进，降低回归风险 | — Pending |
| 为 ABR/多实例做架构准备 | 不实现但确保接口可扩展 | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-07-14 after v2.1 milestone initialization*
