# Project Research Summary — 播放内核重构强化

**Project:** Simple Player Flutter — 播放内核重构强化
**Researched:** 2026-07-14
**Confidence:** HIGH

## Executive Summary

Simple Player Flutter 是基于 fvp (MDK/FFmpeg) 的桌面播放器。内核积累了架构债务：EngineState mixin 模式强制跨实现手动 `@override` 12 个 ValueNotifier 字段，FvpEngine 641 行职责混合，Service 层位于错误目录（features/ 而非 kernel/），错误恢复/状态转换守卫不完整。四个研究维度一致结论：**纯架构重构，零新依赖** — 问题在代码组织，不在技术选型。

核心转换路径：EngineState 从 mixin-with-fields 转为 abstract interface class（ISP 分解），引入独立 EngineStateMachine 强制状态转换守卫，将 PlaybackController 等迁移到 kernel/services/，深化 FvpEngine 现有 helper 组合模式。关键路径：T1（接口契约）→ T2（引擎瘦身）→ D1（能力发现）→ D3（生命周期状态机）。所有下游工作依赖 T1 的接口稳定性。

最大风险：状态机转换矩阵遗漏（9 状态 ~40 条边）、mdk 回调线程安全时序窗口。预防：switch expression 穷举匹配、generation 计数器隔离过期回调、每阶段增量测试 + 快速切歌压力测试。总估算：15-20 工作日，5 个渐进阶段。

## Key Findings

### Stack: 零新依赖

所有现有技术保持不变：fvp 0.37.3、ValueNotifier、shared_preferences、freezed、ffi、window_manager。

**明确不添加:** riverpod/bloc/provider、rxdart、get_it/injectable、audio_service/just_audio。

**核心结论:** 重构是纯架构层面的改进，不需要技术栈变更。

### Features (13 项，3 层)

**Table Stakes (T1-T7):**
- T1: EngineState 接口重构 — mixin → abstract interface class
- T2: FvpEngine 分解 — 641 行 → <350 行
- T3: 统一错误模型 — sealed class PlayerError
- T4: PositionPoller 策略模式
- T5: PlaybackController 迁移 — features/ → kernel/
- T6: 结构化 EngineMetrics
- T7: open() 防御增强

**Differentiators (D1-D6):**
- D1: 引擎能力查询接口
- D2: 播放列表序列化解耦
- D3: 引擎生命周期状态机
- D4: TrackManager 偏好记忆
- D5: NetworkConfigurator 自适应策略
- D6: EngineEventLog 结构化导出

**Anti-features (A1-A7):**
- A1: 不更换引擎
- A2: 不引入状态管理框架
- A3: 不做 UI 抽象
- A4: 不做多实例
- A5: 不做 ABR
- A6: 不做滤镜编辑器
- A7: 不做云同步

### Architecture: ISP 分解 + 独立状态机

**当前问题:**
- EngineState mixin 过大 — 12 个 ValueNotifier + 30+ 抽象方法全在一个 mixin
- Capability mixins 是空壳 — TrackControl/VideoEffects/RendererConfig 只是 marker mixin
- Service 层位置错误 — PlaybackController 在 features/player/services/
- 状态机非强制 — _safeSetState 在 debug 模式下仍执行非法转换

**目标设计:**
- EngineStateView（只读状态）+ PlaybackControl（操作命令）+ 4 个能力接口
- FullEngine 组合接口
- EngineStateMachine 强制状态转换守卫
- Service 层迁移到 kernel/services/
- StateMonitor 拆分为 PlaybackStateManager + AutoAdvancePolicy

**数据流不变:** mdk callbacks → FvpCallbackHandler → ValueNotifier → ValueListenableBuilder

### Top 5 Pitfalls

1. **状态机转换矩阵遗漏 (CRITICAL)** — 9 状态 ~40 条边，switch expression + 矩阵测试
2. **回调线程安全时序窗口 (CRITICAL)** — generation 计数器 + CancelableOperation
3. **ValueNotifier 双赋值 rebuild 风暴 (HIGH)** — 统一 safeSetValue helper
4. **disposed 检查缺口 (HIGH)** — late → nullable
5. **openGeneration + _isOpening 双守卫冲突 (HIGH)** — 统一为单守卫层

## Roadmap Implications

### 建议 5 阶段

| Phase | 名称 | 关键需求 | 依赖 |
|-------|------|----------|------|
| 1 | 接口分解 + 状态模型统一 | T1/T3/T5 | 无（基础） |
| 2 | 状态机提取 + 引擎瘦身 | T2/D3 | Phase 1 |
| 3 | 引擎解耦 + 防御增强 | T4/T7 | Phase 1 |
| 4 | 差异化功能 | D1/D2/D3 | Phase 2 |
| 5 | 增强 + 清理 | D4/D5/D6/T6 | Phase 4 |

### 阶段排序理由

- T1 是关键路径根节点 — 没有接口稳定性，所有下游工作边界不确定
- T3/T5 与 T1 并行无依赖，缩短总时间线
- 状态机（Phase 2）在引擎分解之前，防止 CRITICAL 陷阱回归
- 策略接口（Phase 3）需要稳定接口层作为基础
- 差异化功能（Phase 4-5）在核心稳定之后，避免返工

## Open Questions

- fvp 是否支持多 Player 实例同时运行（多实例播放的前提）
- ABR 是否需要 MDK 层面的 buffer 策略支持
- Service 层迁移后 import 路径变更的影响范围
- mdk 回调的实际线程模型（是否所有回调都在同一后台线程？）
- EngineStateMachine forceSet() 在所有错误恢复场景的行为
- CancellationToken 模式是否需要关联到 openGeneration

## Sources

- `.planning/research/STACK.md` — 技术栈评估
- `.planning/research/FEATURES.md` — 功能特性分析
- `.planning/research/ARCHITECTURE.md` — 架构设计
- `.planning/research/PITFALLS.md` — 陷阱和风险

---
*Research completed: 2026-07-14*
