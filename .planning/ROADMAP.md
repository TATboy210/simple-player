# Roadmap: Simple Player Flutter — Performance Optimization

## Overview

Eliminate frame drops and rendering bottlenecks through a "measure first, fix cheap, refactor clean" strategy. Start with zero-risk fvp configuration fixes, profile to establish baselines, apply targeted optimizations, then clean up architecture debt and add test coverage. Each phase delivers a verifiable capability — either measurable performance improvement or structural cleanup that unblocks testing.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Zero-Risk Rendering Fixes** - fvp config tuning + dead code removal (no profiling needed)
- [ ] **Phase 2: Profile and Measure** - Establish frame-level baselines with DevTools before optimizing
- [ ] **Phase 3: fvp D3D11 Hardware Tuning** - d3d11.sync.cpu=0 with multi-config hardware validation
- [ ] **Phase 4: BackdropFilter and ValueNotifier Optimization** - Targeted widget-layer fixes guided by profiling data
- [ ] **Phase 5: Window Service Deduplication** - Extract mixin from 3 triplicated platform services (~600 lines removed)
- [ ] **Phase 6: Singleton Cleanup and Test Coverage** - Instance-based services + unit tests for window/settings layers

## Phase Details

### Phase 1: Zero-Risk Rendering Fixes
**Goal**: Apply fvp configuration fixes that eliminate known rendering inefficiencies with zero risk of regression
**Depends on**: Nothing (first phase)
**Requirements**: PERF-02, ARCH-03
**Success Criteria** (what must be TRUE):
  1. fvp uses D3D11 hardware decoding (MFT:d3d=11) instead of D3D9-to-D3D11 surface copy
  2. GPU-accelerated YUV-to-RGB conversion is enabled (shader_resource=1)
  3. Debug string formatting overhead is eliminated (log=warning)
  4. Dead code file `lib/models/playlist_item.dart` no longer exists in the codebase
**Plans**: 1 plan

Plans:
- [ ] 01-01-PLAN.md — fvp配置修复：D3D11解码器 + 日志级别 + 死代码清理

### Phase 2: Profile and Measure
**Goal**: Establish frame-level performance baselines and identify the exact bottleneck causing title bar frame drops
**Depends on**: Phase 1
**Requirements**: PERF-01
**Success Criteria** (what must be TRUE):
  1. DevTools Timeline profile captured in profile mode (`flutter run --profile -d windows`) showing UI thread, raster thread, and GPU thread activity
  2. Root cause of title bar jitter identified (BackdropFilter GPU readback vs ValueNotifier rebuild storm vs other)
  3. Ranked list of worst rebuild offenders (which widgets rebuild most, which notifiers trigger them)
**Plans**: TBD

Plans:
- [ ] 02-01: TBD

### Phase 3: fvp D3D11 Hardware Tuning
**Goal**: Validate and ship the highest-impact single optimization (d3d11.sync.cpu=0) across hardware configurations
**Depends on**: Phase 2
**Requirements**: PERF-03
**Success Criteria** (what must be TRUE):
  1. d3d11.sync.cpu=0 tested on at least 3 hardware configs (dedicated GPU, Intel iGPU, AMD iGPU)
  2. No visible tearing on any tested configuration, OR tearing documented with fallback strategy
  3. Measurable frame time improvement (2-5ms/frame savings confirmed via DevTools)
**Plans**: TBD

Plans:
- [ ] 03-01: TBD

### Phase 4: BackdropFilter and ValueNotifier Optimization
**Goal**: Apply targeted widget-layer optimizations that reduce GPU readback and unnecessary rebuilds
**Depends on**: Phase 2
**Requirements**: PERF-04, PERF-05, PERF-06
**Success Criteria** (what must be TRUE):
  1. All 6 BackdropFilter usages verified to have ClipRect wrappers; resize-aware degradation active in playlist_panel.dart and empty_state.dart
  2. All 35 ValueListenableBuilder instances audited — static subtrees cached via `child` parameter where applicable
  3. MergedListenable implemented for position+duration, halving rebuild count for time display widgets
  4. Measurable reduction in raster thread jank compared to Phase 2 baseline
**Plans**: TBD

Plans:
- [ ] 04-01: TBD

### Phase 5: Window Service Deduplication
**Goal**: Eliminate 90%+ code duplication across 3 platform window services by extracting a shared mixin
**Depends on**: Nothing (independent of performance work)
**Requirements**: ARCH-01
**Success Criteria** (what must be TRUE):
  1. WindowServiceBase mixin exists with shared logic extracted from all 3 platform services
  2. Each platform service (Windows, macOS, Linux) reduced to 40-60 lines of platform-specific code
  3. All existing window functionality preserved (fullscreen, resize, drag, always-on-top, persistence)
  4. Approximately 600 lines of duplicated code eliminated
**Plans**: TBD

Plans:
- [ ] 05-01: TBD

### Phase 6: Singleton Cleanup and Test Coverage
**Goal**: Make services testable by converting static singletons to instance-based, then add unit test coverage for untested layers
**Depends on**: Phase 5 (window services deduplicated before testing them)
**Requirements**: ARCH-02, ARCH-04, TEST-01, TEST-02, TEST-03, TEST-04
**Success Criteria** (what must be TRUE):
  1. ThumbnailService is instance-based with constructor-injected ThumbnailProvider (not static singleton)
  2. OsdService is instance-based (enables mock injection for testing)
  3. Unit tests pass for WindowStateService, WindowPersistenceService, and FullscreenController
  4. Unit tests pass for ThumbnailService (after instance-based refactor)
  5. Unit tests pass for SettingsStore covering all preference types and default values
  6. Test coverage for window + settings layers reaches 80%+
**Plans**: TBD

Plans:
- [ ] 06-01: TBD

## Requirement Traceability

| Requirement | Phase | Plan |
|-------------|-------|------|
| PERF-01 | 2 | TBD |
| PERF-02 | 1 | 01-01 |
| PERF-03 | 3 | TBD |
| PERF-04 | 4 | TBD |
| PERF-05 | 4 | TBD |
| PERF-06 | 4 | TBD |
| ARCH-01 | 5 | TBD |
| ARCH-02 | 6 | TBD |
| ARCH-03 | 1 | 01-01 |
| ARCH-04 | 6 | TBD |
| TEST-01 | 6 | TBD |
| TEST-02 | 6 | TBD |
| TEST-03 | 6 | TBD |
| TEST-04 | 6 | TBD |
