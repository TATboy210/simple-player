# Roadmap: Simple Player Flutter

## Milestones

- **v1.0 Window Management & UI Unification** — Phases 1-5 (shipped 2026-05-29)
- **v1.1 Testing, Quality & Code Optimization** — Phases 6-8 (shipped 2026-05-30)
- **v1.2 Security, Architecture & Kernel** — Phases 9-12 (shipped 2026-05-31)
- **v1.2.1 Window Polish & Architecture Simplification** — Phases 13-15 (in progress)

## Phases

**Phase Numbering:**

- Integer phases (9, 10, 11, 12): Planned milestone work
- Decimal phases (9.1, 9.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

<details>
<summary>v1.0 Window Management & UI Unification (Phases 1-5) — SHIPPED 2026-05-29</summary>

- [x] Phase 1: Window Management Foundation (4/4 plans) — completed 2026-05-28
- [x] Phase 2: Widget Unification (2/2 plans) — completed 2026-05-28
- [x] Phase 3: Performance Optimization (4/4 plans) — completed 2026-05-28
- [x] Phase 4: Test Coverage (1/1 plan) — completed 2026-05-29
- [x] Phase 5: Technical Debt Cleanup (3 waves) — completed 2026-05-29

</details>

<details>
<summary>v1.1 Testing, Quality & Code Optimization (Phases 6-8) — SHIPPED 2026-05-30</summary>

- [x] Phase 6: Window Code Optimization — completed 2026-05-29
- [x] Phase 7: Integration & Golden Tests — completed 2026-05-30
- [x] Phase 8: Architecture & Dead Code — completed 2026-05-30

</details>

### v1.2 Security, Architecture & Kernel (In Progress)

**Milestone Goal:** Security hardening + window continued improvement + performance optimization + debug tooling

- [x] **Phase 9: Security Hardening** - FFI memory safety and input validation (SEC-01, SEC-02)
- [x] **Phase 10: Window Optimization** - Window management and UX continued improvement (WIN-04)
- [x] **Phase 11: Performance Optimization** - Player performance tuning and rendering pipeline audit (PERF-04)
- [x] **Phase 12: Debug Tooling** - Structured logging, named loggers, and performance tracing (DBG-01) — completed 2026-05-31

## Phase Details

### Phase 9: Security Hardening

**Goal**: FFI pointers are safely managed and user input is properly validated
**Depends on**: Phase 8 (v1.1 final)
**Requirements**: SEC-01, SEC-02
**Success Criteria** (what must be TRUE):

  1. No memory leaks from undisposed `calloc` pointers across all code paths (including error/exception paths)
  2. Fullscreen transition cannot permanently lock (`_fullscreenTransitioning` has timeout protection)
  3. HTTP/HTTPS URLs are validated with `Uri.tryParse()` and rejected if structurally invalid
  4. File paths containing control characters are filtered before reaching the engine

**Plans**: 3 plans (2 Wave 1 parallel + 1 Wave 2 checkpoint)

Plans:

- [x] 09-01: FFI 指针生命周期安全加固 (Arena + try/finally + dispose 补全 + fullscreen 超时)
- [x] 09-02: 输入验证强化 (HTTP/HTTPS Uri.tryParse + 控制字符过滤)
- [x] 09-03: 安全加固端到端验证 (checkpoint)

### Phase 10: Window Optimization

**Goal**: Window startup, fullscreen transitions, and multi-monitor behavior are smooth and reliable
**Depends on**: Phase 9
**Requirements**: WIN-04
**Success Criteria** (what must be TRUE):

  1. Window restores to correct position and size on startup across single and multi-monitor setups
  2. Fullscreen enter/exit animations are smooth with no visual glitches or compositing artifacts
  3. Window geometry state persists reliably (no lost/corrupt values after crash or force-quit)

**Plans**: 5 plans (2 Wave 1 original + 1 Wave 2 + 2 Gap Closure Wave 1)

Plans:
**Wave 1**

- [x] 10-01: WindowBootstrap 启动几何恢复 + 多显示器验证 (TDD)
- [x] 10-02: WindowService onWindowClose 即时几何保存

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 10-03: 启动流程集成 + 双重 WindowService 修复

**Gap Closure** *(Wave 1 — closing worktree losses)*

- [x] 10-01-GAP: WindowBootstrap tests (6+ test cases)
- [x] 10-02-GAP: onWindowClose + _saveGeometryImmediate re-implementation

### Phase 11: Performance Optimization

**Goal**: Reduce CPU overhead, optimize rendering pipeline, and improve responsiveness on high-refresh-rate displays
**Depends on**: Phase 9 (security hardening may touch same files)
**Requirements**: PERF-04
**Success Criteria** (what must be TRUE):

  1. PositionPoller polling strategy is optimized (reduced frequency or callback-based where possible)
  2. ThumbnailService LRU cache uses O(1) operations (LinkedHashMap replaces List)
  3. D3D11 sync mode intelligently switches based on display refresh rate (async on 120Hz+)
  4. Rendering pipeline audit completed with documented findings and mitigations

**Plans**: 4 plans (2 Wave 1 parallel + 1 Wave 2 + 1 Wave 3 checkpoint)

Plans:

- [x] 11-01: ThumbnailService LRU O(1) with LinkedHashMap
- [x] 11-02: PositionPoller adaptive polling intervals
- [x] 11-03: D3D11 refresh-rate-aware sync mode
- [x] 11-04: Rendering pipeline audit + Phase 11 verification

### Phase 12: Debug Tooling

**Goal**: Developers can diagnose issues with structured, module-scoped logs and performance traces
**Depends on**: Nothing (independent)
**Requirements**: DBG-01
**Success Criteria** (what must be TRUE):

  1. Each module uses a named logger instance (engine, bridge, services, UI are distinguishable in logs)
  2. Release mode filters to warning+ only; debug mode preserves current behavior
  3. Key performance-sensitive methods (4 paths) emit `dart:developer` Timeline events for DevTools profiling

**Plans**: 2 plans (2 Wave 1 parallel)

Plans:

- [x] 12-01: PrefixPrinter + 模块 logger + initLog 更新 (log.dart)
- [x] 12-02: Timeline 追踪 FvpEngine.open/seek + WindowService fullscreen (4 方法)

### Phase 13: Window Foundation

**Goal**: 窗口从第一帧起即为无边框，启动零闪烁；Window 层代码精简至 50% 行数
**Depends on**: Phase 12
**Requirements**: WIN-05, WIN-06
**Success Criteria** (what must be TRUE):

  1. C++ `WM_NCCALCSIZE` 在 `HandleTopLevelWindowProc` 之前拦截，非客户区折叠为零
  2. `WS_CAPTION` 保留以维持 DWM 最大化/还原动画
  3. 启动时无边框闪烁（第一帧即为无边框状态）
  4. Dart 端三重异步边框移除路径合并为单一同步路径
  5. Window 层代码行数减少 50%+

**Spike**: WM_NCCALCSIZE 拦截验证（0.5 天）— `OutputDebugString` 确认消息顺序

**Plans**: TBD（待 /gsd:plan-phase 13 规划）

### Phase 14: HLS ABR

**Goal**: HLS 流媒体自适应码率播放，带宽波动时自动切换质量
**Depends on**: Nothing（独立于 Phase 13）
**Requirements**: HLS-01
**Success Criteria** (what must be TRUE):

  1. EWMA 吞吐量估计覆盖 80%+ 桌面场景
  2. `.m3u8` URL 自动启用 ABR 配置（移除低延迟标志）
  3. 非 HLS URL 保持现有低延迟配置
  4. 带宽波动时自动降级/升级画质，无卡顿

**Spike**: MDK MediaInfo 比特率/缓冲指标可用性验证（0.5 天）

**Plans**: TBD（待 /gsd:plan-phase 14 规划）

### Phase 15: Architecture Simplification

**Goal**: SettingsStore 样板代码减少 80%，单例消除，平台抽象层接口就绪
**Depends on**: Phase 13（窗口层 DI 需要 Phase 13 决策）
**Requirements**: ARCH-02, ARCH-03, PLATFORM-03
**Success Criteria** (what must be TRUE):

  1. SettingsStore 使用 `_get<T>`/`_set<T>` 泛型模式，25+ 方法减至 5 个核心方法
  2. 6 个 static mutable 单例全部迁移至构造函数注入
  3. `PlatformService` 抽象接口定义完成，`WindowsPlatformService` 委托现有实现
  4. 所有现有测试通过，无功能回归

**Plans**: TBD（待 /gsd:plan-phase 15 规划）

### v1.2.1 Window Polish & Architecture Simplification (In Progress)

**Milestone Goal:** 消除边框闪烁，达到 Apple 级窗口动效流畅度，同时精简架构

- [ ] **Phase 13: Window Foundation** - C++ WM_NCCALCSIZE 同步帧无边框 + Window 层精简 (WIN-05, WIN-06)
- [ ] **Phase 14: HLS ABR** - 基于吞吐量的自适应码率流媒体 (HLS-01)
- [ ] **Phase 15: Architecture Simplification** - SettingsStore + 单例迁移 + 平台抽象层 (ARCH-02, ARCH-03, PLATFORM-03)

## Progress

**Execution Order:**
Phases execute in numeric order: 9 -> 10 -> 11 -> 12 -> 13 -> 14 -> 15

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Window Management | v1.0 | 4/4 | Complete | 2026-05-28 |
| 2. Widget Unification | v1.0 | 2/2 | Complete | 2026-05-28 |
| 3. Performance Optimization | v1.0 | 4/4 | Complete | 2026-05-28 |
| 4. Test Coverage | v1.0 | 1/1 | Complete | 2026-05-29 |
| 5. Technical Debt Cleanup | v1.0 | 3 waves | Complete | 2026-05-29 |
| 6. Window Code Optimization | v1.1 | 1/1 | Complete | 2026-05-29 |
| 7. Integration & Golden Tests | v1.1 | 3/3 | Complete | 2026-05-30 |
| 8. Architecture & Dead Code | v1.1 | 2/2 | Complete | 2026-05-30 |
| 9. Security Hardening | v1.2 | 3/3 | Complete | 2026-05-30 |
| 10. Window Optimization | v1.2 | 5/5 | Complete | 2026-05-30 |
| 11. Performance Optimization | v1.2 | 4/4 | Complete | 2026-05-30 |
| 12. Debug Tooling | v1.2 | 2/2 | Complete | 2026-05-31 |
| 13. Window Foundation | v1.2.1 | 0/TBD | Pending | - |
| 14. HLS ABR | v1.2.1 | 0/TBD | Pending | - |
| 15. Architecture Simplification | v1.2.1 | 0/TBD | Pending | - |

## Requirement Traceability

| Requirement | Phase | Plan |
|-------------|-------|------|
| OPT-01 | 6 | 06-01 |
| OPT-02 | 7 | 07-03 |
| TEST-05 | 7 | 07-01 |
| TEST-06 | 7 | 07-02 |
| QUAL-01 | 8 | TBD |
| QUAL-02 | 8 | TBD |
| QUAL-03 | 8 | TBD |
| SEC-01 | 9 | 09-01 |
| SEC-02 | 9 | 09-02 |
| WIN-04 | 10 | 10-01, 10-02, 10-03 |
| PERF-04 | 11 | 11-01, 11-02, 11-03, 11-04 |
| DBG-01 | 12 | 12-01, 12-02 |
| WIN-05 | 13 | TBD |
| WIN-06 | 13 | TBD |
| HLS-01 | 14 | TBD |
| ARCH-02 | 15 | TBD |
| ARCH-03 | 15 | TBD |
| PLATFORM-03 | 15 | TBD |

---
*Last updated: 2026-05-31 — v1.2.1 milestone: Phase 13 (Window Foundation), Phase 14 (HLS ABR), Phase 15 (Architecture Simplification)*
