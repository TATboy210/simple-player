# Requirements — 播放内核重构强化 (v2.1)

**Defined:** 2026-07-14
**Core Value:** 播放内核的健壮性与可扩展性 — 引擎抽象清晰、状态一致、错误恢复可靠、新功能易于接入。

## v2.1 Requirements

### 引擎层重构

- [ ] **ENG-01**: EngineState 接口重构 — 将 mixin 拆分为 abstract interface class：EngineStateView（只读状态）+ PlaybackControl（操作命令）+ 4 个能力接口（TrackControl/SubtitleConfig/VideoEffectControl/RendererControl），组合为 FullEngine 接口
- [ ] **ENG-02**: FvpEngine 分解 — 从 641 行优化至 <350 行，深化 helper 组合模式，提取状态转换守卫到独立类
- [ ] **ENG-03**: 统一错误模型 — 用 sealed class PlayerError 替代 MediaErrorType + PlayerErrorCode 双体系，支持 exhaustive pattern matching
- [ ] **ENG-04**: open() 防御增强 — 引入 generation 计数器 + CancelableOperation，防止过期回调干扰新视频，统一 openGeneration + _isOpening 双守卫

### 服务层重构

- [ ] **SVC-01**: PlaybackController 迁移 — 从 features/player/services/ 迁移到 kernel/services/，修正架构边界
- [ ] **SVC-02**: 引擎生命周期状态机 — 独立 EngineStateMachine 类，用 switch expression 穷举 9 状态 ~40 条边的转换矩阵，release 模式强制守卫
- [ ] **SVC-03**: StateMonitor 职责拆分 — 拆分为 PlaybackStateManager（设置恢复 + 断点保存）+ AutoAdvancePolicy（自动连播逻辑）

### 轨道管理重构

- [ ] **TRK-01**: 轨道管理统一接口 — 合并 TrackManager + SubtitleConfigurator + VideoEffectController 为统一的 MediaControl 接口
- [ ] **TRK-02**: 轨道偏好记忆 — 记住用户最后选择的音频/字幕轨道，下次打开文件时自动应用

## Future Requirements

- D1: 引擎能力查询接口 — 查询引擎支持的功能（硬件解码、字幕渲染等）
- D2: 播放列表序列化解耦 — 版本化 JSON 格式，支持迁移
- D5: NetworkConfigurator 自适应策略 — 网络流缓冲参数动态调整
- D6: EngineEventLog 结构化导出 — JSON 格式导出事件日志
- T4: PositionPoller 策略模式 — 可配置的轮询间隔策略
- T6: 结构化 EngineMetrics — ValueNotifier 暴露指标，便于 UI 展示

## Out of Scope

| Feature | Reason |
|---------|--------|
| 底层引擎更换 | 继续使用 fvp (MDK/FFmpeg)，更换成本高且无必要 |
| UI 层改动 | 本次专注内核，不改播放器界面 |
| 状态管理模式更换 | 继续使用 ValueNotifier + ValueListenableBuilder，项目已有成熟模式 |
| 多实例播放 | 不在本次范围内，需验证 fvp 多实例能力 |
| ABR 自适应码率 | 架构准备但不实现，属于长期计划 |
| 滤镜编辑器 | 不在本次范围内 |
| 云同步 | 不在本次范围内 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ENG-01 | — | Pending |
| ENG-02 | — | Pending |
| ENG-03 | — | Pending |
| ENG-04 | — | Pending |
| SVC-01 | — | Pending |
| SVC-02 | — | Pending |
| SVC-03 | — | Pending |
| TRK-01 | — | Pending |
| TRK-02 | — | Pending |

**Coverage:**
- v2.1 requirements: 9 total
- Mapped to phases: 0 (pending roadmap)
- Unmapped: 9

---
*Requirements defined: 2026-07-14*
*Last updated: 2026-07-14 after research synthesis*
