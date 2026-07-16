# Phase 9: 接口分解 + 状态模型统一 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-14
**Phase:** 9-接口分解 + 状态模型统一
**Areas discussed:** ValueNotifier 分配策略, 错误模型统一, PlaybackController 迁移范围, MediaState 枚举重构

---

## ValueNotifier 分配策略

### Q1: 12 个 ValueNotifier 怎么分配？

| Option | Description | Selected |
|--------|-------------|----------|
| A: mixin 不变 + 接口只约束方法 | 万能工具箱保留不动，方法按职责拆到不同接口 | |
| B: EngineStateView 只读接口 | 把 ValueNotifier 变成只读"仪表盘"接口 | ✓ |
| C: 按职责分组拆分 | ValueNotifier 按职责分到不同接口 | |

**User's choice:** B — EngineStateView 只读接口

### Q2: EngineStateView 实现方式？

| Option | Description | Selected |
|--------|-------------|----------|
| abstract class 只有 getter | 12 个 getter，不含 setter 和操作方法 | ✓ |
| mixin + implements 双重约束 | 保留 mixin + 新增 abstract class | |

**User's choice:** abstract class 只有 getter

### Q3: 12 个 getter 放哪里？

| Option | Description | Selected |
|--------|-------------|----------|
| A: 全部放 EngineStateView | 总仪表盘，所有状态一目了然 | ✓ |
| B: 按职责分组到能力接口 | 主状态放 EngineStateView，字幕/画面分到能力接口 | |

**User's choice:** A — 全部放 EngineStateView

### Q4: 迁移策略？

| Option | Description | Selected |
|--------|-------------|----------|
| A: 渐进迁移（保留旧 mixin） | 旧 mixin 标记 @Deprecated，逐步迁移 | |
| B: 一步到位（删除旧 mixin） | 直接删除 EngineState mixin，干净利落 | ✓ |

**User's choice:** B — 一步到位

### Q5: 是否需要 PlaybackControl 接口？

| Option | Description | Selected |
|--------|-------------|----------|
| A: 独立 PlaybackControl 接口 | 遥控器（操作）和仪表盘（状态）分开 | ✓ |
| B: 不需要 PlaybackControl 接口 | 操作方法直接放 FvpEngine 类里 | |

**User's choice:** A — 独立 PlaybackControl 接口

### Q6: 能力接口数量？

| Option | Description | Selected |
|--------|-------------|----------|
| A: 按 REQUIREMENTS.md 的 4 个接口 | TrackControl/SubtitleConfig/VideoEffectControl/RendererControl | ✓ |
| B: 合并为 2 个接口 | TrackControl+SubtitleConfig, VideoEffectControl+RendererControl | |

**User's choice:** A — 按 REQUIREMENTS.md 的 4 个接口

### Q7: 能力接口类型？

| Option | Description | Selected |
|--------|-------------|----------|
| A: abstract class | 与 EngineStateView 风格一致 | ✓ |
| B: mixin | 保留当前模式，加方法签名 | |

**User's choice:** A — abstract class（与 EngineStateView 一致）

---

## 错误模型统一

### Q1: PlayerError 层级结构？

| Option | Description | Selected |
|--------|-------------|----------|
| A: 嵌套层级（大类 + 细分码） | 文件夹分类：大类→细分错误码 | ✓ |
| B: 扁平 11 子类 | 11 个 sealed class 子类，简单粗暴 | |
| C: 粗分类 5 子类 | 只保留 5 个大类，细分放 message | |

**User's choice:** A — 嵌套层级

### Q2: OpenResult 处理？

| Option | Description | Selected |
|--------|-------------|----------|
| A: OpenResult 适配 PlayerError | OpenError(PlayerError error) 替代旧形式 | ✓ |
| B: OpenResult 不变 | 两条路并存 | |

**User's choice:** A — OpenResult 适配 PlayerError

### Q3: 错误暴露方式？

| Option | Description | Selected |
|--------|-------------|----------|
| A: ValueNotifier<PlayerError?> | 和现有模式一致，仪表盘加"故障指示灯" | ✓ |
| B: Stream<PlayerError> | 一次性消费，与现有模式不一致 | |
| C: 两者结合 | ValueNotifier + Stream 各司其职 | |

**User's choice:** A — ValueNotifier<PlayerError?>

### Q4: 旧字段处理？

| Option | Description | Selected |
|--------|-------------|----------|
| A: 删除旧字段，完全替换 | 删除 errorMessage + errorType，统一用 lastError | ✓ |
| B: 旧字段保留 @Deprecated | 渐进迁移 | |

**User's choice:** A — 删除旧字段，完全替换

---

## PlaybackController 迁移范围

### Q1: 迁移范围？

| Option | Description | Selected |
|--------|-------------|----------|
| A: 核心 4 个一起迁 | Controller + Navigator + FileOps + StateMonitor | |
| B: 只迁 PlaybackController | 子模块留在 features/ | |
| C: 全部 5 个一起迁 | 核心 4 个 + SubtitleService | ✓ |

**User's choice:** C — 全部 5 个一起迁

### Q2: PlayerServices DI 容器？

| Option | Description | Selected |
|--------|-------------|----------|
| A: PlayerServices 不动，只改 import | 最小改动 | |
| B: PlayerServices 也迁到 kernel | 更彻底的分层 | ✓ |

**User's choice:** B — PlayerServices 也迁到 kernel

### Q3: PlaybackContract 接口？

| Option | Description | Selected |
|--------|-------------|----------|
| A: 保留 PlaybackContract，迁到 kernel | 接口保留，位置变更 | |
| B: 删除 PlaybackContract | 减少一层间接 | ✓ |

**User's choice:** B — 删除 PlaybackContract

### Q4: import 路径更新？

| Option | Description | Selected |
|--------|-------------|----------|
| A: 全局自动替换 import | 干净利落 | ✓ |
| B: 旧路径 re-export 过渡 | 过渡期用 | |

**User's choice:** A — 全局自动替换 import

### Q5: features/ 残留？

| Option | Description | Selected |
|--------|-------------|----------|
| A: features/ 只留 UI | 只保留 player_feature.dart 等 UI 文件 | ✓ |
| B: 删除 features/ 目录 | 彻底消除 features 层 | |

**User's choice:** A — features/ 只留 UI

---

## MediaState 枚举重构

### Q1: 状态模型怎么改？

| Option | Description | Selected |
|--------|-------------|----------|
| A: 拆为正交状态 | 主状态 + 瞬态标志，像速度表+转向灯 | ✓ |
| B: 增加组合枚举值 | 枚举值膨胀（27 种可能） | |
| C: 延迟到 Phase 10 | Phase 9 不动状态模型 | |

**User's choice:** A — 拆为正交状态

### Q2: 状态转换守卫？

| Option | Description | Selected |
|--------|-------------|----------|
| A: Phase 9 只拆状态，守卫留给 Phase 10 | 先造仪表盘，再装保护盖 | ✓ |
| B: Phase 9 同时做守卫 | 一步到位 | |

**User's choice:** A — Phase 9 只拆状态，守卫留给 Phase 10

### Q3: 瞬态标志实现？

| Option | Description | Selected |
|--------|-------------|----------|
| A: 两个 ValueNotifier<bool> | isSeeking + isBuffering，独立指示灯 | ✓ |
| B: ValueNotifier<Set<TransientState>> | 可扩展但需 .contains() 检查 | |

**User's choice:** A — 两个 ValueNotifier<bool>

### Q4: 主状态值？

| Option | Description | Selected |
|--------|-------------|----------|
| A: 保留现有 6 个主状态 | idle/opening/playing/paused/completed/error | ✓ |
| B: 增加 stopped 状态 | idle vs stopped 语义区分 | |

**User's choice:** A — 保留现有 6 个主状态

### Q5: 状态暴露方式？

| Option | Description | Selected |
|--------|-------------|----------|
| A: 3 个独立 getter | state + isSeeking + isBuffering 分别监听 | ✓ |
| B: PlaybackSnapshot 聚合对象 | 不可变快照对象 | |

**User's choice:** A — 3 个独立 getter

### Q6: 旧 transition guard？

| Option | Description | Selected |
|--------|-------------|----------|
| A: 删除旧守卫，Phase 10 重建 | 拆掉旧保护盖 | ✓ |
| B: 保留旧守卫 @Deprecated | 过渡期用 | |

**User's choice:** A — 删除旧守卫，Phase 10 重建

---

## Claude's Discretion

无 — 所有决策均用户明确选择。

## Deferred Ideas

None — discussion stayed within phase scope
