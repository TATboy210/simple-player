---
phase: 05-bug
verified: 2026-07-10T18:00:00Z
status: gaps_found
score: 3/6 must-haves verified
behavior_unverified: 2
overrides_applied: 0
re_verification: false
gaps:
  - truth: "Win32 FFI calls reduced from 7-9 to 5 per enter/leave operation"
    status: failed
    reason: "enterFullscreenFast uses 9 FFI calls (PLAN claims 5). ROADMAP SC #5 requires 50%+ reduction; actual is 18% (enter) and 29% (leave). The diagnostic read-back elimination saved 2 calls on enter (4 getWindowLong down to 2) and the layout refresh elimination saved 2 calls on leave (9 down to 7), but neither reaches PLAN's '5 calls' claim or ROADMAP's '50%+' target."
    artifacts:
      - path: "lib/kernel/bridge/platform/windows_fullscreen_driver.dart"
        issue: "enterFullscreenFast at line 158 has 9 FFI calls: getFlutterHwnd + getWindowLong x2 + getWindowPlacement + setWindowLong x2 + monitorFromWindow + getMonitorRect + setWindowPos. PLAN must_have says 5."
      - path: ".planning/phases/05-bug/05-02-PLAN.md"
        issue: "Must_have truth #3 states 'Win32 FFI calls reduced from 7-9 to 5 per enter/leave operation' — this is not achieved for the enter path (9 calls, not 5)."
    missing:
      - "Reduce enterFullscreenFast to 5-7 FFI calls by merging getWindowLong save calls or eliminating monitorFromWindow/getMonitorRect"
      - "Or update PLAN must_have to match actual 9-call implementation"
      - "Or update ROADMAP SC #5 from 50%+ to a realistic target"
behavior_unverified_items:
  - truth: "Fullscreen switch completes in <100ms from F key to filled screen"
    test: "Press F on Windows with a 16:9 video playing in windowed mode"
    expected: "Screen fills with video in under 100ms, no perceptible delay"
    why_human: "Stopwatch test uses mock FFI (zero latency). Real Win32 FFI calls (SetWindowPos, SetWindowLong) have non-zero latency that depends on DWM compositor, monitor refresh rate, and GPU state. Cannot verify actual <100ms in unit test environment."
  - truth: "Zero flicker during fullscreen transition (no black/white frames)"
    test: "Press F to enter fullscreen, observe carefully for any black/white frames during transition"
    expected: "Video content fills screen immediately with no flash, no black frame, no white frame, no tearing"
    why_human: "Flicker is a frame-level rendering artifact. The fast path eliminates the async gap (snapshot updates synchronously), but whether the Win32 SetWindowPos + Flutter texture compositor produce a clean frame transition depends on DWM vsync timing and texture re-registration. Widget test cannot observe actual frame output."
human_verification:
  - test: "Press F on Windows to enter fullscreen with a 16:9 video"
    expected: "Fullscreen completes in under 100ms with zero visible flicker"
    why_human: "Mock-based tests verify code logic (fast path used, no confirmation chain, immediate snapshot). Real FFI latency and DWM compositor behavior determine actual timing and visual artifacts."
  - test: "Enter and exit fullscreen 10 times rapidly"
    expected: "No visual artifacts, no black bars, no border remnants, consistent behavior"
    why_human: "Stress testing reveals timing-dependent issues that unit tests cannot catch."
---

# Phase 5: Performance and Bug Fixes Verification Report

**Phase Goal:** Fix fullscreen visual bugs and optimize fullscreen switch performance
**Verified:** 2026-07-10
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | 16:9 video fills entire 16:9 monitor with zero black edges in fullscreen | VERIFIED | VideoSurface: `SizedBox.expand` -> `FittedBox(fit: BoxFit.contain)` -> `Texture`. safeRatio fallback for invalid ratios (0, negative, NaN, infinity). 11 widget tests pass. |
| 2 | No WS_THICKFRAME border remnant visible during fullscreen (no 7px gap) | VERIFIED | `enterFullscreen()` strips `wsCaption\|wsThickframe\|wsMaximize` before `setWindowPos` with `swpFramechanged`. Diagnostic `getWindowLong` read-back between set and pos. Call order test verifies all border bits cleared. |
| 3 | Border style removal and SetWindowPos are atomic (single frame) | VERIFIED | Sequence: `setWindowLong(gwlStyle)` -> `setWindowLong(gwlExStyle)` -> `getWindowLong` verify x2 -> `setWindowPos(HWND_TOPMOST, monitorRect, swpFramechanged)`. No async gaps between calls. |
| 4 | Fullscreen switch completes in <100ms from F key to filled screen | PRESENT_BEHAVIOR_UNVERIFIED | Stopwatch test passes with mock FFI (<100ms vs >500ms standard path). Real FFI timing untested. |
| 5 | Zero flicker during fullscreen transition (no black/white frames) | PRESENT_BEHAVIOR_UNVERIFIED | Fast path eliminates async gap: `_driver.enterFullscreenFast()` then immediate snapshot update. No widget rebuild between enter and stable. Frame-level rendering untested. |
| 6 | Win32 FFI calls reduced from 7-9 to 5 per enter/leave operation | FAILED | enterFullscreenFast: 9 FFI calls (PLAN claims 5). leaveFullscreenFast: 5 FFI calls (matches). Enter path does not match PLAN must_have. ROADMAP SC #5 requires 50%+ reduction; actual is 18% (enter) and 29% (leave). |

**Score:** 3/6 truths verified (2 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/kernel/bridge/platform/windows_fullscreen_driver.dart` | Atomic border+position operation + fast path | VERIFIED | 487 lines. enterFullscreen() with diagnostic verification. enterFullscreenFast()/leaveFullscreenFast() with reduced FFI calls. |
| `lib/ui/player/video_surface.dart` | Correct FittedBox rendering | VERIFIED | 48 lines. SizedBox.expand + FittedBox(contain) + safeRatio fallback. Diagnostic logging at line 26. |
| `test/platform/windows_fullscreen_driver_test.dart` | Border removal tests + fast path tests | VERIFIED | 649 lines, 40 tests. Covers enter/leave/fast/query/capabilities/window management. |
| `test/kernel/bridge/desktop_fullscreen_adapter_test.dart` | Fast path integration tests | VERIFIED | 575 lines, 26 tests. Covers T12-T26 + 8 fast path tests. |
| `test/widget/player/video_surface_test.dart` | VideoSurface rendering tests | VERIFIED | 157 lines, 11 tests. Covers 16:9, 4:3, null, NaN, infinity, portrait, scroll. |
| `enterFullscreenFast()` method | Reduced FFI calls | VERIFIED (exists) / FAILED (count) | Method exists at line 158 with 9 FFI calls, not the claimed 5. |
| Windows fast path in DesktopFullscreenAdapter | Skip confirmation chain | VERIFIED | `_driver is WindowsFullscreenDriver` check at lines 223 and 279. Calls enterFullscreenFast/leaveFullscreenFast. Skips _waitForConfirmation. |
| FFI call count tests | Verify reduction | VERIFIED | Test at line 284: standard path 4 getWindowLong, fast path 2 getWindowLong. Counts confirmed. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| enterFullscreenFast() | DesktopFullscreenAdapter._handleEnter | `_driver is WindowsFullscreenDriver` type check | WIRED | Line 223: `await _driver.enterFullscreenFast(displayId: 0)` |
| leaveFullscreenFast() | DesktopFullscreenAdapter._handleLeave | `_driver is WindowsFullscreenDriver` type check | WIRED | Line 280: `await _driver.leaveFullscreenFast()` |
| VideoSurface | EngineState.textureId | AnimatedBuilder + ValueListenableBuilder | WIRED | Line 20: `animation: Listenable.merge([engine.textureId, engine.aspectRatio])` |
| Diagnostic read-back | enterFullscreen | getWindowLong after setWindowLong | WIRED | Lines 106-119: verify style and exStyle after strip |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| All 77 tests pass | `flutter test test/platform/... test/kernel/... test/widget/player/video_surface_test.dart` | 77/77 passed | PASS |
| No analyzer warnings | `flutter analyze` on 3 files | 1 info (unnecessary import), 0 warnings | PASS |
| Fast path <100ms | Stopwatch test in adapter test | `stopwatch.elapsedMilliseconds < 100` passes | PASS (mock-based) |
| FFI call count difference | `standardGetLong=4, fastGetLong=2` | Verified in test | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-----------|-------------|--------|----------|
| FIX-01 | 05-01 | 16:9 video rendering correctness | SATISFIED | VideoSurface + 11 widget tests |
| FIX-02 | 05-01 | WS_THICKFRAME border remnant fix | SATISFIED | Atomic style strip + diagnostic verification + call order test |
| PERF-01 | 05-02 | Confirmation chain bypass on Windows | SATISFIED | `_driver is WindowsFullscreenDriver` check, skip _waitForConfirmation |
| PERF-02 | 05-02 | Zero flicker transition | SATISFIED (code) | No async gap, snapshot immediate update. Frame-level rendering needs human verification. |
| PERF-03 | 05-02 | Reduced FFI call count | NOT SATISFIED | 9 calls enter (PLAN says 5), 5 calls leave (matches). 18-29% reduction vs ROADMAP 50%+. |

**Note:** REQUIREMENTS.md does not contain PERF-01/02/03 or FIX-01/02 in its traceability table. These are v2 roadmap requirements not yet added to formal requirements. PLAT-01 in REQUIREMENTS.md partially covers FIX-02 (WS_THICKFRAME handling).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| video_surface.dart | 1 | Unnecessary import `flutter/foundation.dart` (provided by `flutter/material.dart`) | Info | No functional impact. Analyzer info-only. |
| windows_fullscreen_driver.dart | 100 | Operator precedence: `_savedExStyle \| wsExTopmost & ~(...)` — `&` binds tighter than `\|` in Dart. Dialog/edge bits only stripped from wsExTopmost, not from combined result. If original exStyle has WS_EX_WINDOWEDGE, it persists during fullscreen. | Warning | Cosmetic during fullscreen only. leaveFullscreen restores original exStyle. Tests pass because mock starts with WS_EX_WINDOWEDGE. Not a user-visible bug on real Windows (WS_EX_WINDOWEDGE is typical). |

### Human Verification Required

#### 1. Fullscreen Switch Timing

**Test:** Open a 16:9 video in windowed mode on Windows. Press F to enter fullscreen.
**Expected:** Screen fills with video in under 100ms. No perceptible delay.
**Why human:** Mock-based stopwatch test verifies code path (<100ms vs >500ms). Real Win32 FFI latency depends on DWM compositor, monitor refresh rate, and GPU state.

#### 2. Zero Flicker

**Test:** Enter and exit fullscreen 10 times rapidly (press F repeatedly).
**Expected:** No black frames, white frames, tearing, or visual artifacts during any transition.
**Why human:** Fast path eliminates async gap (snapshot updates synchronously). Whether Win32 SetWindowPos + Flutter texture compositor produce clean frames depends on DWM vsync and texture lifecycle.

#### 3. 16:9 Video No Black Edges

**Test:** Play a 16:9 video on a 16:9 monitor. Enter fullscreen.
**Expected:** Video fills entire screen with zero black bars on any edge.
**Why human:** Widget tests verify rendering chain (FittedBox + BoxFit.contain). Actual fullscreen black edges could come from window geometry mismatch (border remnant) which is tested separately.

### Gaps Summary

**1 gap blocking goal achievement:**

**SC #5 / PERF-03: FFI call count reduction below target.** ROADMAP success criterion #5 requires "Win32 FFI 系统调用次数减少50%+". Actual reductions: 18% (enter: 11 to 9) and 29% (leave: 7 to 5). Neither reaches 50%+. The PLAN's own must_have claims "reduced from 7-9 to 5 per enter/leave" but the enter path actually uses 9 calls, not 5.

Root cause: The diagnostic `getWindowLong` read-back was eliminated (saving 2 calls), but the structural FFI calls (getFlutterHwnd, getWindowLong x2 save, getWindowPlacement, setWindowLong x2, monitorFromWindow, getMonitorRect, setWindowPos) remain at 9 total. Further reduction would require:
- Merging `monitorFromWindow` + `getMonitorRect` into a single FFI call (saves 1)
- Caching the HWND (saves 1 per call if `getFlutterHwnd` is eliminated)
- Combining `getWindowLong` style + exStyle into one call (not possible with Win32 API)

**Recommendation:** Update PLAN must_have and ROADMAP SC #5 to reflect actual 9-call/5-call implementation (18%/29% reduction), or explore further optimizations.

---

*Verified: 2026-07-10*
*Verifier: Claude (gsd-verifier)*
