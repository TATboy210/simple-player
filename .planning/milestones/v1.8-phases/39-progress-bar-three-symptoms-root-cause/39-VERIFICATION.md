---
phase: 39-progress-bar-three-symptoms-root-cause
verified: 2026-08-22T16:41:56Z
status: human_needed
score: 4/6 must-haves verified
behavior_unverified: 1
behavior_unverified_items:
  - truth: "Tap/drag seek holds the thumb against an old active-source position until the target arrives, then clears on arrival or the configured timeout."
    test: "Drag to a target, emit an older position from the same active notifier after release, then separately emit target-arrival and advance past `Tokens.progressSeekHoldTimeoutMs`."
    expected: "Semantics/thumb remains at the target after the older event; it follows the stream after target arrival, and the timeout independently releases the hold."
    why_human: "The implementation contains the arrival/timer branches and focused tests cover active replacement plus arrival, but no named test exercises the same-source old-position rollback and timeout branches required by the phase contract."
overrides_applied: 0
human_verification:
  - test: "On a Windows desktop, open a real video with `D:/flutter/bin/flutter run -d windows`, move the mouse from roughly 25% to 75% across the visible progress bar, then leave the bar and repeat while dragging."
    expected: "A self-drawn preview bubble is visibly rendered, changes from about 00:15 to 00:45 for a 60-second video, moves right with the pointer, disappears on ordinary pointer exit, and remains coherent during drag. Static action tooltips remain independent."
    why_human: "The PROG-03 roadmap behavior is explicitly a visual Windows mouse-hover backstop. Widget tests prove text/geometry and the real-runtime test proves the data chain, but neither observes actual desktop rendering or pointer hit behavior in a user session."
  - test: "Drag to a new time in the real Windows app while playback is still reporting an older position, then wait for the seek to settle and repeat with a delayed/failed seek if practical."
    expected: "The thumb does not jump back to the old position after release; it releases only when the active position reaches the target tolerance or after the configured timeout backstop."
    why_human: "This is a state-transition invariant. Presence inspection and the current test corpus do not exercise the old-active-position and timeout paths together."
---

# Phase 39: 进度条三症状根因诊断与修复 Verification Report

**Phase Goal:** 用日志/断点证据定位 duration/position 链路断点，修复三症状。  
**Verified:** 2026-08-22T16:41:56Z  
**Status:** human_needed  
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Evidence identifies the precise first duration/position-chain break rather than guessing. | VERIFIED | `39-DIAGNOSIS.md` preserves ordered raw Player → port → state → intended widget evidence, identifies `ControlBarLayout._buildLayout` as the first failed production edge, and separately records the post-repair trace. The independently rerun Windows gate reported `production.timeline.insertion observed` and `diagnosis.firstBrokenBoundary=none-post-repair`. |
| 2 | After a video loads, `durationMs` becomes the real duration and playback position reaches the visible progress bar. | VERIFIED | Production composition now inserts `ControlBarTimeline` in `control_bar_layout.dart:82-111`; it forwards the stable ViewModel listenables through `control_bar_timeline.dart:32-47`. The focused suite passed 83 tests, including shell semantics at 25% after a 60,000/15,000 ms fake stream emission. The independently rerun Windows test observed raw/port/state/widget duration = 10026 ms and non-zero state/widget positions. |
| 3 | Tap and drag seek against the active port, with a drag thumb held until the active position arrives or the configured timeout fires. | PRESENT_BEHAVIOR_UNVERIFIED | `progress_bar.dart:190-243` implements event-driven hold using `Tokens.progressSeekArriveToleranceMs` and `Tokens.progressSeekHoldTimeoutMs`; focused replacement coverage proves active-source target arrival can finish a hold. However, no named test emits a stale position from the same active source after release and separately advances the timeout branch, so the no-rollback/timeout state invariant is not behaviorally proven. |
| 4 | Hover preview bubble displays the correct time and follows pointer x without replacing static `AppTooltip` behavior. | UNCERTAIN — human backstop required | `progress_bar.dart:251-275, 369-470` implements direct hover updates and a self-drawn `Positioned` bubble; it contains no `AppTooltip` import/use. The active widget test asserts `00:15` at 25%, `00:45` at 75%, and increasing `Positioned.left`. This cannot prove visible real-Windows hover rendering. |
| 5 | The repair does not modify media_kit, Pub cache, or vendored libmpv files. | VERIFIED | `git diff --name-only ccaae0ba^..c9d9aa1c` contains only project UI/tests/diagnostics; independent protected-path scan returned `forbidden=[]`. |
| 6 | Source replacement keeps duration/position notifier identity, rejects stale source events, and releases listeners/timers. | VERIFIED | `PlayerControlsState.updateSources()` reuses its notifier fields while cancelling/replacing all eight port subscriptions (`player_video_controls.dart:154-201`). `ProgressBar` owns and disposes merged listener registrations (`progress_bar.dart:141-175, 474-493`). Focused replacement/lifecycle tests passed. |

**Score:** 4/6 truths verified (1 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `.planning/milestones/v1.8-phases/39-progress-bar-three-symptoms-root-cause/39-DIAGNOSIS.md` | Ordered diagnosis and post-repair trace | VERIFIED | Substantive evidence matrix, first-break rationale, preserved pre-repair trace, and separately labelled post-repair trace exist. |
| `lib/ui/player/control_bar_layout.dart` | Production composition of timeline | VERIFIED | `ControlBarTimeline` is in the actual `ControlBarLayout` content column, not only in a diagnostic tree. |
| `lib/ui/player/player_video_controls.dart` | Stable source-to-ViewModel state bridge | VERIFIED | Eight stream subscriptions populate stable `durationMs`/`positionMs`; cached ViewModel receives those identical notifiers. |
| `lib/ui/player/control_bar_timeline.dart` | ViewModel-to-ProgressBar forwarding | VERIFIED | Wires `vm.position`, `vm.duration`, and `vm.onSeek` directly to `ProgressBar`. |
| `lib/ui/player/progress_bar.dart` | Interactive seek hold and self-drawn hover bubble | VERIFIED | Substantive input handling, event-driven hold lifecycle, explicit merged-listener ownership, semantics, and self-drawn `Positioned` preview. |
| `test/widget/player/progress_bar_data_chain_diagnosis_test.dart` | Fake end-to-end stream/controls regression | VERIFIED | Active, non-skipped tests exercise production shell composition, delayed data, stale-source isolation, seek, and pointer interactions. |
| `test/widget/player/progress_bar_test.dart` | Progress interaction and hover regression | VERIFIED | Active widget tests assert proportional seek and exact `00:15`/`00:45` hover values plus geometry movement. |
| `test/widget/player/progress_bar_source_replacement_test.dart` | Listener ownership during replacement | VERIFIED | Tracks old/new listener counts and verifies only the active source can finish hold. |
| `integration_test/progress_bar_real_runtime_diagnosis_test.dart` | Real Windows raw-to-widget gate | VERIFIED | Independently executed with `P39_POST_REPAIR=true`; exited 0 after opening `tiny_valid.mp4`, tracing raw/port/state/widget values, insertion, and disposal. |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | ---- | --- | ------ | ------- |
| `MediaKitPlayerPort` | `PlayerControlsState` | Current port snapshots and duration/position subscriptions | WIRED | `PlayerControlsState.init()` reads snapshots then installs `_durationSub` and `_positionSub`; replacement calls cancellation before reinitialization. |
| `PlayerControlsState` | `ControlBarViewModel` | Stable `durationMs` / `positionMs` identities | WIRED | `_createControlBarViewModel()` passes the original two notifiers at `player_video_controls.dart:767-781`. |
| `ControlBarTimeline` | `ProgressBar` | Position, duration, seek callback | WIRED | Direct properties at `control_bar_timeline.dart:35-42`; production `ControlBarLayout` now instantiates this widget. |
| `ProgressBar` | `PlayerControlsState.seek` | Pointer fraction → milliseconds → `vm.onSeek` | WIRED | Tap/drag calculate a clamped fraction against current duration and call `onSeek`; ViewModel binds it to `state.seek`. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| `PlayerControlsState` | `durationMs`, `positionMs` | `PlayerPort` snapshots and streams | Windows gate observed raw Player duration 10026 → port 10026 → state 10026, plus non-zero position. | FLOWING |
| `ControlBarViewModel` / `ControlBarTimeline` | `vm.duration`, `vm.position` | Same state notifier objects | Identity is logged by the runtime gate and direct forwarding is in production source. | FLOWING |
| `ProgressBar` | Slider semantics, seek target, hover time | ViewModel listenables and local pointer coordinates | Focused tests prove 25% semantics, proportional seeks, and 25%/75% formatted preview values; Windows gate observes populated widget state. | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Focused progress/controls regressions | `D:/flutter/bin/flutter test test/widget/player/progress_bar_data_chain_diagnosis_test.dart test/widget/player/progress_bar_test.dart test/widget/player/progress_bar_source_replacement_test.dart test/widget/player/player_video_controls_test.dart test/widget/player/player_video_controls_lifecycle_test.dart --reporter expanded` | 83 tests passed | PASS |
| Actual Windows Player raw-to-widget chain | `P39_POST_REPAIR=true D:/flutter/bin/flutter test integration_test/progress_bar_real_runtime_diagnosis_test.dart -d windows --reporter expanded` | Passed. Raw/port/state/widget duration 10026; production timeline observed; real position witnesses, and `postRepair.playerDisposed=true` emitted. | PASS |
| Static correctness | `D:/flutter/bin/flutter analyze` | `No issues found!` | PASS |
| Phase diff whitespace / supply-chain red line | `git diff --check ccaae0ba^..c9d9aa1c` plus protected-path scan | Clean; `forbidden=[]` | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| PROG-01 | 39-01, 39-02 | Loaded video exposes real duration/progress through the repaired chain. | SATISFIED | Production timeline insertion, focused shell semantics at 25%, and independent Windows raw→port→state→widget trace. |
| PROG-02 | 39-01, 39-02 | Tap/drag seek works and thumb does not roll back during active seek hold. | NEEDS HUMAN | The implementation and focused tests establish proportional seek, active-source target arrival, and replacement isolation. Same-source stale-position and timeout paths are not exercised by a named behavioral test. |
| PROG-03 | 39-01, 39-02 | Hover time bubble displays and follows pointer. | NEEDS HUMAN | Widget tests prove time text/geometry and source code proves self-drawn ownership. A live Windows pointer/rendering confirmation remains explicitly required. |

All requirement IDs declared by both plan frontmatters (`PROG-01`, `PROG-02`, `PROG-03`) are accounted for. No additional Phase 39 requirements are mapped in `REQUIREMENTS.md`.

### Test Quality Audit

| Test File | Linked Req | Active | Skipped | Circular | Assertion Level | Verdict |
| --------- | ---------- | ------ | ------- | -------- | --------------- | ------- |
| `progress_bar_data_chain_diagnosis_test.dart` | PROG-01, PROG-02, PROG-03 | 4 | 0 | No | Behavioral/value | PASS |
| `progress_bar_test.dart` | PROG-02, PROG-03 | 44+ | 0 | No | Value/behavioral | WARNING — no same-source rollback/timeout assertion |
| `progress_bar_source_replacement_test.dart` | PROG-02 | 1 | 0 | No | Behavioral | PASS for replacement, incomplete for ordinary old-position rollback/timeout |
| `player_video_controls_test.dart` / lifecycle test | PROG-01, PROG-02 | Active | 0 | No | Behavioral | PASS |
| `progress_bar_real_runtime_diagnosis_test.dart` | PROG-01 | 1 | 0 | No | Runtime behavioral | PASS with note |

**Disabled requirement tests:** 0.  
**Circular patterns:** 0.  
**Insufficient behavioral assertion:** 1 warning — no test creates a same-source old position after drag-end and separately proves the timeout release; this supports the behavior-unverified classification rather than a blocker because implementation and wiring exist.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| — | — | No `TBD`, `FIXME`, `XXX`, placeholder, or incomplete implementation markers in phase-modified production/diagnostic files. | Info | No blocker found. |

### Decision Coverage

No `CONTEXT.md` exists for this phase; the non-blocking decision-coverage check was skipped.

## Human Verification Required

### 1. Real Windows hover-preview visual backstop

**Test:** Open a real video through `D:/flutter/bin/flutter run -d windows`. Hover the pointer at approximately one-quarter and three-quarters of the visible progress bar, move it out, then repeat while dragging.

**Expected:** The preview bubble is visibly present, tracks pointer x, shows the corresponding changing time, hides after ordinary exit, remains stable during drag, and is not replaced or duplicated by a static `AppTooltip`.

**Why human:** Headless widget geometry/text assertions and the real runtime data trace cannot observe actual Windows desktop compositing or mouse hit behavior.

### 2. Seek-hold no-rollback and timeout invariant

**Test:** Drag to a new time while the active player still emits its pre-seek position; observe the bar until the target position arrives. If feasible, delay/fail a seek long enough to exercise the 2-second timeout backstop.

**Expected:** The thumb does not roll back to the old position after release. It only follows stream position after the target reaches tolerance, or releases after the configured timeout.

**Why human:** `ProgressBar` contains the intended listener/timer logic, but the current automated corpus does not exercise both state-transition branches specified in the phase contract.

## Gaps Summary

No implementation blocker was found. Two human checkpoints remain: the roadmap's explicit PROG-03 real-Windows visual backstop, and the behavior-dependent PROG-02 no-rollback/timeout invariant that lacks complete named-test evidence. Therefore the phase cannot receive a `passed` verdict despite clean analyzer, focused tests, protected diff, and independently rerun Windows runtime gate.

---

_Verified: 2026-08-22T16:41:56Z_  
_Verifier: Claude (gsd-verifier)_
