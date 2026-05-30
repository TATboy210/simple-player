# Roadmap: Simple Player Flutter

## Milestones

- **v1.0 Window Management & UI Unification** — Phases 1-5 (shipped 2026-05-29)
- **v1.1 Testing, Quality & Code Optimization** — Phases 6-8 (shipped 2026-05-30)
- **v1.2 Security, Architecture & Kernel** — Phases 9-12 (in progress)

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
- [ ] **Phase 10: Window Optimization** - Window management and UX continued improvement (WIN-04)
- [ ] **Phase 11: Performance Optimization** - Player performance tuning and rendering pipeline audit (PERF-04)
- [ ] **Phase 12: Debug Tooling** - Structured logging, named loggers, and performance tracing (DBG-01)

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

**Plans**: 3 plans (2 Wave 1 parallel + 1 Wave 2)

Plans:
**Wave 1**

- [ ] 10-01: WindowBootstrap 启动几何恢复 + 多显示器验证 (TDD)
- [ ] 10-02: WindowService onWindowClose 即时几何保存

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 10-03: 启动流程集成 + 双重 WindowService 修复

### Phase 11: Performance Optimization

**Goal**: Reduce CPU overhead, optimize rendering pipeline, and improve responsiveness on high-refresh-rate displays
**Depends on**: Phase 9 (security hardening may touch same files)
**Requirements**: PERF-04
**Success Criteria** (what must be TRUE):

  1. PositionPoller polling strategy is optimized (reduced frequency or callback-based where possible)
  2. ThumbnailService LRU cache uses O(1) operations (LinkedHashMap replaces List)
  3. D3D11 sync mode intelligently switches based on display refresh rate (async on 120Hz+)
  4. Rendering pipeline audit completed with documented findings and mitigations

**Plans**: TBD

Plans:

- [ ] 11-01: TBD

### Phase 12: Debug Tooling

**Goal**: Developers can diagnose issues with structured, module-scoped logs and performance traces
**Depends on**: Nothing (independent)
**Requirements**: DBG-01
**Success Criteria** (what must be TRUE):

  1. Log output is structured JSON format (parseable by log aggregation tools)
  2. Each module uses a named logger instance (engine, bridge, services, UI are distinguishable in logs)
  3. Key performance-sensitive methods (3-5 paths) emit `dart:developer` Timeline events for DevTools profiling

**Plans**: TBD

Plans:

- [ ] 12-01: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 9 -> 10 -> 11 -> 12

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
| 10. Window Optimization | v1.2 | 1/3 | In Progress|  |
| 11. Performance Optimization | v1.2 | 0/TBD | Not started | - |
| 12. Debug Tooling | v1.2 | 0/TBD | Not started | - |

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
| PERF-04 | 11 | TBD |
| DBG-01 | 12 | TBD |

---
*Last updated: 2026-05-30 — Phase 10 planning complete: 3 plans (10-01 WindowBootstrap TDD, 10-02 onWindowClose save, 10-03 startup wiring + singleton fix)*
