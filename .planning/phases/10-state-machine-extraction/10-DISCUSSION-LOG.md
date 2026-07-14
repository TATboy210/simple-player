# Phase 10 Discussion Log

**Date:** 2026-07-14
**Phase:** 状态机提取 + 引擎瘦身

## Area 1: 状态模型

**Question:** 路线图写的是 9 状态 ~40 条边，但 Phase 9 已将 MediaState 重构为 6 值正交枚举 + 2 个独立 bool 标志。Phase 10 的状态机应该基于哪个模型？

**Options:**
- 6 状态 + 2 标志 (Recommended) — 保持 Phase 9 的正交设计
- 9 状态全枚举 — 将 isSeeking/isBuffering 纳入枚举
- 你决定

**Selection:** 6 状态 + 2 标志 (Recommended)

## Area 2: 非法转换严格程度

**Question:** 非法状态转换（如 Playing → Playing、idle → completed）应该如何处理？

**Options:**
- Debug assert + Release 忽略 (Recommended) — 与当前 _safeSetState 行为一致
- 全模式强制抛异常 — 更严格但需调用方处理
- Debug assert + Release 记录 — 可追踪生产异常

**Selection:** Debug assert + Release 忽略 (Recommended)

## Area 3: 状态机类设计

**Question:** EngineStateMachine 应该是拥有状态的独立类，还是纯逻辑验证类？

**Options:**
- 独立类拥有状态 (Recommended) — 拥有 ValueNotifier，可独立测试
- 纯逻辑类（无状态拥有） — 不拥有 notifier，更简单
- Mixin 模式 — 混入 FvpEngine

**Selection:** 独立类拥有状态 (Recommended)

## Area 4: FvpEngine 瘦身策略

**Question:** FvpEngine 当前 632 行，目标 <350 行。当前有 ~200 行是 track/subtitle/videoEffect/d3d11 的 delegation 方法。如何瘦身？

**Options:**
- Helper 实现接口 + 组合暴露 (Recommended) — 最大瘦身效果，API 改变
- Mixin 提取 — API 不变但可测试性降低
- 只提取状态机 — 最保守，达不到目标

**Selection:** Helper 实现接口 + 组合暴露 (Recommended)

## Area 5: 接口匹配方式

**Question:** FvpEngine 是否还直接 implements TrackControl/SubtitleConfig 等接口？还是暴露为独立 getter？

**Options:**
- FvpEngine 暴露接口 getter (Recommended) — engine.trackControl.switchAudioTrack()
- FvpEngine implements + delegate — API 不变但有薄 delegation 层
- 你决定

**Selection:** FvpEngine 暴露接口 getter (Recommended)

## Area 6: 核心方法保留

**Question:** FvpEngine 瘦身后保留哪些方法？

**Options:**
- 最小核心 (Recommended) — open/play/pause/stop/seekTo + dispose
- 核心 + 便捷方法 — 加上 togglePlayPause/skipForward/skipBack/setRange
- 你决定

**Selection:** 最小核心 (Recommended)

## Area 7: 便捷方法归属

**Question:** togglePlayPause/skipForward/skipBack/setRange 等便捷方法放哪里？

**Options:**
- 状态机 + mixin (Recommended) — togglePlayPause→状态机，skip/setRange→mixin
- 保留在 FvpEngine — 每方法 3-5 行
- 你决定

**Selection:** 状态机 + mixin (Recommended)

## Deferred Ideas

None — discussion stayed within phase scope
