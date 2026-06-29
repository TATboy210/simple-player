# Milestones — Simple Player Flutter

## v1.0: Window Management & UI Unification

**Shipped:** 2026-05-29
**Phases:** 5 | **Plans:** 10 + 3 ad-hoc waves
**Tests:** 564 passing | **Coverage:** 80.0%

### What Was Built

- C++ WindowChannel + Dart WindowService (MethodChannel, EventChannel, Win32 FFI)
- Frameless window with WM_NCHITTEST resize/drag + CustomTitleBar
- Unified GlassWidget library (barrel file, merged constructors)
- D3D11 performance tuning (hardware-first decoders, ring buffer PerfMonitor)
- Test coverage 64% → 80% (564 tests, 24 kernel test files)
- Technical debt cleanup (immutable AppSettings, typed callbacks, singleton reset)

### Key Decisions

- Self-built MethodChannel (no third-party window packages)
- ValueNotifier pattern preserved (no state management migration)
- D3D11 sync safe default (d3d11.sync.cpu=1, user-tunable)
- PLATFORM-02 (macOS/Linux stubs) deferred to v2

### Known Gaps

- PERF-01: Multi-GPU D3D11 testing deferred (code done, validation missing)
- Phase 1/4/5: Missing formal VERIFICATION.md artifacts

### Archive

- Milestone: `.planning/milestones/v1.0-ROADMAP.md`
- Requirements: `.planning/milestones/v1.0-REQUIREMENTS.md`
- Audit: `.planning/v1.0-MILESTONE-AUDIT.md`

## v1.1: Testing, Quality & Code Optimization

**Shipped:** 2026-05-30
**Phases:** 3 | **Plans:** 6
**Tests:** 596 passing | **Coverage:** 80%+

### What Was Built

- Integration tests for critical user flows (E2E)
- Golden tests for glassmorphism components
- Architecture optimization (Context7-guided)
- Dead code cleanup and code quality improvements
- Window layer code optimization

### Key Decisions

- BoxFit.contain for video rendering
- Custom FFI maximize using rcWork

## v1.2: Security, Architecture & Kernel

**Shipped:** 2026-05-31
**Phases:** 4 | **Plans:** 14
**Tests:** 596 passing | **Coverage:** 80%+

### What Was Built

- FFI memory safety (dispose leak fix, try/finally, fullscreen timeout)
- Input validation (URL structure, path length, null bytes)
- Window management continued optimization
- Performance optimization (LRU, polling, D3D11 sync)
- Debug tooling (structured logging, Timeline tracing)

### Key Decisions

- SEC-01 + SEC-02 combined in Phase 9 (overlapping files)
- LRU cache uses LinkedHashMap for O(1) operations
- PositionPoller adaptive: 100ms/250ms/1s intervals
- D3D11 sync mode: async for 120Hz+, sync for 60Hz

## v1.2.1: Window Polish & Architecture Simplification

**Started:** 2026-05-31
**Phases:** 3 | **Plans:** TBD

### Goals

- 窗口丝滑化: C++ WM_NCCALCSIZE 同步帧无边框，启动零闪烁
- Window 层精简: 725 行 → 50%
- SettingsStore 简化: 25+ save 方法 → 泛型模式
- 单例迁移: 6 个 static 单例 → 构造函数注入
- 平台抽象层: PlatformService 接口定义
- HLS ABR: 基于吞吐量的自适应码率流媒体

### Phase Structure

- Phase 13: Window Foundation (WIN-05, WIN-06) — 最高风险，需要 spike
- Phase 14: HLS ABR (HLS-01) — 独立，可与 Phase 13 并行
- Phase 15: Architecture Simplification (ARCH-02, ARCH-03, PLATFORM-03) — 依赖 Phase 13
