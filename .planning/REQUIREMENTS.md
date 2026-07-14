# Requirements — 播放内核重构强化 (v2.1 expanded)

**Defined:** 2026-07-14
**Last updated:** 2026-07-14 — expanded with Widget↔Kernel optimization requirements
**Core Value:** 播放内核的健壮性与可扩展性 — 引擎抽象清晰、状态一致、错误恢复可靠、新功能易于接入。Widget↔Kernel 边界清晰、API 统一、可测试。

## v2.1 Requirements

### A. 引擎层重构 (Phase 9 scope — DONE)

- [x] **ENG-01**: EngineState 接口重构 — 将 mixin 拆分为 abstract interface class：EngineStateView（只读状态）+ PlaybackControl（操作命令）+ 4 个能力接口（TrackControl/SubtitleConfig/VideoEffectControl/RendererControl） ✓ Phase 9
- [x] **ENG-03**: 统一错误模型 — 用 sealed class PlayerError 替代 MediaErrorType + PlayerErrorCode 双体系，支持 exhaustive pattern matching ✓ Phase 9
- [x] **SVC-01**: PlaybackController 迁移 — 从 features/player/services/ 迁移到 kernel/services/，修正架构边界 ✓ Phase 9

### B. 状态机提取 + 引擎瘦身 (Phase 10 scope)

- [ ] **ENG-02**: FvpEngine 分解 — 从 641 行优化至 <350 行，深化 helper 组合模式，提取状态转换守卫到独立类
- [ ] **SVC-02**: 引擎生命周期状态机 — 独立 EngineStateMachine 类，用 switch expression 穷举 9 状态 ~40 条边的转换矩阵，release 模式强制守卫

### C. 引擎解耦 + 防御增强 (Phase 11 scope)

- [ ] **ENG-04**: open() 防御增强 — 引入 generation 计数器 + CancelableOperation，防止过期回调干扰新视频，统一 openGeneration + _isOpening 双守卫
- [ ] **SVC-03**: StateMonitor 职责拆分 — 拆分为 PlaybackStateManager（设置恢复 + 断点保存）+ AutoAdvancePolicy（自动连播逻辑）

### D. 轨道管理统一 (Phase 12 scope)

- [ ] **TRK-01**: 轨道管理统一接口 — 合并 TrackManager + SubtitleConfigurator + VideoEffectController 为统一的 MediaControl 接口
- [ ] **TRK-02**: 轨道偏好记忆 — 记住用户最后选择的音频/字幕轨道，下次打开文件时自动应用

### E. Widget API 统一 (NEW)

- [ ] **WGT-01**: 所有 PlayerScreen 子 widget 通过统一接口访问内核 — 不直接依赖 FvpEngine 具体类型，构造函数接收 EngineStateView + PlaybackControl
- [ ] **WGT-02**: ControlBar/VolumeControls/SpeedButton 等控制组件使用 PlaybackControl 接口调用命令 — 不混合状态读取和命令调用
- [ ] **WGT-03**: PlayerScreen 作为唯一内核接入点 — 子 widget 通过构造函数注入依赖，不通过 InheritedWidget 或全局访问
- [ ] **WGT-04**: `flutter analyze` 无错误，现有测试全部通过

### F. 状态通知优化 (NEW)

- [ ] **NOTIF-01**: ValueListenableBuilder 粒度与实际消费匹配 — 只读取单个 ValueNotifier 的 widget 不 rebuild on unrelated changes
- [ ] **NOTIF-02**: 控制栏 auto-hide 逻辑不因 position 更新触发 rebuild — 使用独立的 ValueNotifier
- [ ] **NOTIF-03**: 进度条 seek preview 不触发整个 ControlBar rebuild — 局部状态隔离
- [ ] **NOTIF-04**: `flutter analyze` 无错误，现有测试全部通过

### G. 可测试性提升 (NEW)

- [ ] **TEST-01**: Widget 测试可通过 FakeEngine + FakeWindowService 完整 mock 内核行为 — 不需要真实的 fvp Player
- [ ] **TEST-02**: 每个 PlayerScreen 子 widget 可独立测试 — 不依赖 PlayerScreen 的 context 或 InheritedWidget
- [ ] **TEST-03**: PlaybackController 可通过构造函数注入 mock 依赖 — 不硬编码 FvpEngine
- [ ] **TEST-04**: 测试覆盖率达到 80%+ — 核心路径（播放/暂停/seek/切歌/错误恢复）全部有测试

### H. 数据流清晰化 (NEW)

- [ ] **FLOW-01**: Widget→Kernel 命令流单向 — widget 调用 PlaybackControl 方法，不直接修改 ValueNotifier
- [ ] **FLOW-02**: Kernel→Widget 状态流单向 — ValueNotifier 变更触发 widget rebuild，widget 不反向写入
- [ ] **FLOW-03**: 错误传播路径清晰 — FvpEngine → PlaybackController → ErrorBanner，每层有明确的错误转换
- [ ] **FLOW-04**: `flutter analyze` 无错误，现有测试全部通过

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
| UI 视觉改动 | 本次专注接口和数据流，不改播放器外观 |
| 状态管理模式更换 | 继续使用 ValueNotifier + ValueListenableBuilder，项目已有成熟模式 |
| 多实例播放 | 不在本次范围内，需验证 fvp 多实例能力 |
| ABR 自适应码率 | 架构准备但不实现，属于长期计划 |
| 滤镜编辑器 | 不在本次范围内 |
| 云同步 | 不在本次范围内 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ENG-01 | Phase 9 | ✅ Done |
| ENG-03 | Phase 9 | ✅ Done |
| SVC-01 | Phase 9 | ✅ Done |
| ENG-02 | TBD | Pending |
| SVC-02 | TBD | Pending |
| ENG-04 | TBD | Pending |
| SVC-03 | TBD | Pending |
| TRK-01 | TBD | Pending |
| TRK-02 | TBD | Pending |
| WGT-01 ~ WGT-04 | TBD | Pending |
| NOTIF-01 ~ NOTIF-04 | TBD | Pending |
| TEST-01 ~ TEST-04 | TBD | Pending |
| FLOW-01 ~ FLOW-04 | TBD | Pending |

**Coverage:**
- v2.1 requirements: 25 total (9 existing + 16 new)
- Completed: 3 (ENG-01, ENG-03, SVC-01)
- Remaining: 22
- Mapped to phases: TBD (roadmap pending)

---
*Requirements defined: 2026-07-14*
*Last updated: 2026-07-14 — expanded with Widget↔Kernel optimization requirements*
