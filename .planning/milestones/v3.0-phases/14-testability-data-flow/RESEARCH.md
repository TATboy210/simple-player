# Phase 14 Research: 可测试性提升 + 数据流清晰化

**Date:** 2026-07-14
**Status:** Complete

## Current State Assessment

### Test Infrastructure (ALREADY STRONG)

| Component | Status | Lines | Notes |
|-----------|--------|-------|-------|
| FakeEngine | ✅ Complete | 390 | Implements all ISP interfaces (MediaEngine, SubtitleConfig, TrackControl, VideoEffectControl, RendererControl, VolumeControl). Uses EngineStateMachine. Has call tracking, error simulation, media configuration. |
| FakeWindowService | ✅ Complete | 84 | Implements WindowBridge. Call tracking for all operations. ValueNotifiers for mode/size/resize/alwaysOnTop. |
| Test count | 1131 passing, 4 failing | — | 4 pre-existing failures in shortcuts_tab_test.dart |
| flutter analyze | 17 issues (0 errors) | — | All warnings/infos: strict_raw_type, prefer_const_constructors, unawaited_futures |

### Widget Test Coverage (GAPS EXIST)

**Already tested with FakeEngine + FakeWindowService:**
- PlayerScreen (25+ test cases, 741 lines) — keyboard seek/volume/mute, fullscreen toggle, playlist toggle, empty state, responsive layout
- ControlBar (renders, sub-components exist)
- VolumeControls (volume slider throttle)
- ProgressBar, SpeedButton, KeyboardHandler, DropHandler
- OSD overlay, ErrorBanner, VideoSurface, ControlsOverlay, AutoHideController

**NOT yet tested (gap):**
- ControlsOverlay auto-hide timer behavior (only existence test)
- VolumeSlider drag interaction (only throttle test)
- SpeedButton popup interaction (only renders test)
- ProgressBar seek preview interaction
- ErrorBanner error display lifecycle
- PlaylistPanel (exists in integration tests only)
- Cross-widget state propagation (engine state → multiple widgets rebuild)

### Data Flow Analysis

**Widget → Kernel (Commands):** All widgets call methods on `MediaEngine` directly — UNIDIRECTIONAL ✅
**Kernel → Widget (State):** All state flows via `ValueNotifier<T>` on MediaEngine — `ValueListenableBuilder` — UNIDIRECTIONAL ✅
**Error Propagation:** `MediaEngine.lastError` → ErrorBanner; `PlaybackController.onError` → service errors; `FileOperations.validationError` → UI

### Architecture Maturity

The codebase is **more mature than the roadmap anticipated**:
- Phase 13 goals (Widget API unified, state notification optimization) were largely completed during Phases 9-11
- FakeEngine already implements ALL ISP interfaces
- PlaybackController already uses constructor injection
- Data flows are already unidirectional

## Gap Analysis (What Phase 14 Actually Needs)

| Requirement | Status | Action |
|-------------|--------|--------|
| TEST-01: FakeEngine/FakeWindowService mock | ✅ Complete | Minor enhancements only |
| TEST-02: Independent widget testability | ✅ Mostly complete | Fill remaining test gaps |
| TEST-03: PlaybackController constructor injection | ✅ Already done | None needed |
| TEST-04: 80%+ test coverage | ⚠️ Need measurement | Run coverage, fill gaps |
| FLOW-01: Widget→Kernel unidirectional | ✅ Already done | Document pattern |
| FLOW-02: Kernel→Widget unidirectional | ✅ Already done | Document pattern |
| FLOW-03: Error propagation clear | ⚠️ Partially tested | Write integration test |

## Pre-existing Issues to Fix

1. **4 test failures** in `shortcuts_tab_test.dart` — need investigation and fix
2. **17 analysis warnings/infos** — prefer_const_constructors, unawaited_futures, strict_raw_type

## Recommended Phase 14 Scope

1. Fix 4 pre-existing test failures (shortcuts_tab_test.dart)
2. Fix 17 analysis issues (warnings/infos → 0 issues)
3. Fill widget test coverage gaps — write tests for untested interactions
4. Error propagation integration test — verify full error path
5. Measure and achieve 80%+ coverage
6. Document data flow patterns — verify and codify unidirectional flows
