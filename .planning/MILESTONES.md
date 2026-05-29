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
