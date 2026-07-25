---
phase: 15-contract-freeze-baseline-audit
plan: 02
subsystem: kernel/engine (MediaEngine ISP contracts)
tags: [contracts, doc-comments, state-machine, D2, D3, D4, lifecycle]
status: complete
dependency-graph:
  requires: []
  provides:
    - "Frozen D2 behavioral contracts (requires/ensures/states/modifies/throws) on all 7 MediaEngine ISP interfaces"
    - "open()->idle->play()->playing handoff frozen as testable contract boundary"
    - "P20 Lifecycle-Gap list (D18) appended to 15-CONTEXT.md — 6-state-vs-9-state verdict frozen"
    - "Thin D4 implementation notes on fvp_engine.dart (open/dispose/codec-fallback/_guardedAction)"
  affects:
    - "Phase 15 Plan 03 (contract tests) — mirrors the frozen states:/throws: tags as test assertions"
    - "Phase 16 (adapter layer) — implements against frozen contracts, not guesswork"
    - "Phase 20 (lifecycle implementation) — consumes P20 Lifecycle-Gap TODO list"
tech-stack:
  added: []
  patterns:
    - "D2 bilingual contract tags (Chinese intent line + blank line + English-labeled requires/ensures/states/modifies/throws)"
    - "D3 class-level group contract for read-only getter interfaces (EngineStateView)"
    - "D4 thin implementation-mechanism notes (contract authority stays on interface, not FvpEngine)"
key-files:
  created: []
  modified:
    - lib/kernel/engine/media_engine.dart
    - lib/kernel/engine/engine_state_view.dart
    - lib/kernel/engine/playback_control.dart
    - lib/kernel/engine/track_control.dart
    - lib/kernel/engine/subtitle_config.dart
    - lib/kernel/engine/video_effect_control.dart
    - lib/kernel/engine/renderer_control.dart
    - lib/kernel/engine/volume_control.dart
    - lib/kernel/engine/fvp_engine.dart
    - .planning/phases/15-contract-freeze-baseline-audit/15-CONTEXT.md
decisions:
  - "media_engine.dart's class doc corrected from '6 个 ISP 接口' to accurate '7 个 implements' (RESEARCH Pitfall 4)"
  - "EngineStateView's 14 getter-type members (13 ValueNotifier + mediaInfo) share ONE D3 class-level group contract; each getter keeps its existing one-line Chinese comment unchanged"
  - "open()->idle->play() handoff frozen explicitly in PlaybackControl.open's ensures: tag — successful open() never auto-transitions to playing"
  - "Every states: tag hand-verified against engine_state_machine.dart's _canTransitionTo switch; none touch the error source-state row, so the recover() exit (error->{idle,opening}) stays fully reachable and unmodified"
  - "9-vs-6 state reconciliation frozen in 15-CONTEXT.md: 6 orthogonal MediaState + orthogonal LifecyclePhase{alive,disposing,disposed}; stale 9-state PROJECT.md model retired (promoted, not add-alongside)"
  - "fvp_engine.dart carries zero contract tags (requires:/ensures:/states:) — only 4 thin D4 implementation-mechanism notes added (open(), codec-fallback block, _guardedAction, dispose())"
metrics:
  duration: "~36 minutes"
  completed: 2026-07-16
---

# Phase 15 Plan 02: Contract Freeze on MediaEngine ISP Interfaces Summary

Froze bilingual D2 behavioral contracts (`requires:`/`ensures:`/`states:`/`modifies:`/`throws:`) on all 7 `MediaEngine` ISP interfaces, explicitly documented the `open()->idle->play()->playing` handoff as a testable contract boundary, added thin D4 implementation-mechanism notes to `fvp_engine.dart`, and appended the P20 Lifecycle-Gap list to `15-CONTEXT.md` freezing the 6-state-vs-9-state verdict.

## What Was Built

**Task 1 — EngineStateView group contract + MediaEngine ISP-count fix (commit `bbec3e9`)**

Added a D3 class-level group contract above `abstract class EngineStateView` covering all 14 getter-type members (13 `ValueNotifier` getters + `mediaInfo`) with a single shared contract block (`requires: 无` / `ensures:` disposed-safe-default semantics / `modifies: 无`). Each individual getter retained its existing one-line Chinese comment unchanged, per D3's "share group contract, don't repeat per-getter" rule.

Corrected `media_engine.dart`'s class doc from the inaccurate "将 6 个 ISP 接口聚合为单一类型" to "将 EngineStateView 只读状态视图与 6 个控制类 ISP 接口（共 7 个 implements）聚合为单一类型" — fixing RESEARCH.md's flagged Pitfall 4 (the `implements` clause lists 7 interfaces, not 6).

**Task 2 — D2 contracts on PlaybackControl + 5 control interfaces (commit `f0a2a3f`)**

Added full D2 contract tags to all 12 `PlaybackControl` methods, with the `open()`/`play()` contracts explicitly freezing the handoff semantics: `open()`'s `ensures:` states "成功时 state == idle...调用者须随后 play() 才进入 playing" — turning the live "loads video but won't play" regression boundary into a documented, testable contract line. Added D2 tags to all members of `TrackControl` (3), `SubtitleConfig` (8), `VideoEffectControl` (4), `RendererControl` (2), and `VolumeControl` (4).

Every `states:` tag was hand-verified against `engine_state_machine.dart`'s `_canTransitionTo` switch (D7 deliberate cross-check). None of the written `states:` tags touch the `error` source-state row, so the `recover()` exit (`error -> {idle, opening}`) remains fully reachable — T-15-05 (DoS risk from closing the recover() exit) is confirmed not triggered.

**Task 3 — D4 thin notes on fvp_engine.dart + P20 Lifecycle-Gap list (commit `e3a7817`)**

Added 4 thin D4-style implementation-mechanism notes to `fvp_engine.dart` (mirroring the existing `_openGeneration` doc precedent at lines 190-194): above `open()` (generation guard + codec fallback + handoff mechanism), inside the codec-fallback branch (single-retry mechanism, local-file-only scope), above `_guardedAction` (exception-absorption mechanism), and above `dispose()` (current `_disposed` bool baseline vs. future `LifecyclePhase` enum). Zero `requires:`/`ensures:`/`states:` tags were added to this file — contract authority stays exclusively on the interfaces (D4).

Appended a `## P20 Lifecycle-Gap 清单（D18）` section to `15-CONTEXT.md` recording the frozen verdict: 6 orthogonal `MediaState` values + orthogonal `LifecyclePhase{alive,disposing,disposed}` (not yet implemented); the stale 9-state `PROJECT.md` model is retired (promoted, not kept alongside). The section lists the full transition table, the current `_disposed`-bool baseline, and 6 concrete Phase-20 TODO items.

## Deviations from Plan

### Auto-fixed Issues

None — plan executed exactly as written for all 3 tasks. No Rule 1/2/3 auto-fixes were needed; this was a pure documentation-freeze plan with no bugs, missing functionality, or blockers encountered.

### Observations Documented In-Contract (not code fixes — DOC-ONLY discipline)

While hand-verifying each `states:` tag against `_canTransitionTo` (per D7's mandatory cross-check), 3 real contract-vs-implementation gaps were discovered in the existing (unmodified) `fvp_engine.dart` behavior. Per DOC-ONLY scope, these were **not fixed** (fixing would require changing `_canTransitionTo` or method guards — an architectural change, Rule 4 territory) — instead they were **accurately documented as observed discrepancies** directly in the affected contract tags, and cross-referenced in the P20 Lifecycle-Gap list for Phase 20/22 attention:

1. **`open()` called from `playing`/`paused` source states.** `open()` unconditionally calls `_stateMachine.transitionTo(MediaState.opening, 'open')` regardless of current state, but `_canTransitionTo`'s table does not include a `playing->opening` or `paused->opening` edge. In release mode, `transitionTo` returns `false` silently and `state` does not change, while the rest of `open()`'s body (which does not check the return value) continues executing anyway. Documented in `playback_control.dart`'s `open()` `states:` tag and in the P20 list.
2. **`play()` called from `completed` source state.** Same pattern — `play()` unconditionally calls `transitionTo(playing, 'play')`, but `completed->playing` is not in the transition table (only `completed->{opening,error,idle}` is legal). Documented in `playback_control.dart`'s `play()` `states:` tag and in the P20 list.
3. **`VideoEffectControl.setAspectRatio()` does not write back to `EngineStateView.aspectRatio`.** Verified via `video_effect_controller.dart:54-56` — the method only calls `_player.setAspectRatio(ratio)` on the underlying MDK player; it never touches the `aspectRatio` `ValueNotifier` (which is only written inside `open()`'s success path at `fvp_engine.dart:267`). A caller invoking `setAspectRatio()` will not see the change reflected in `EngineStateView.aspectRatio`. Documented in `video_effect_control.dart`'s `setAspectRatio` `modifies:` tag and in the P20 list.

These are exactly the class of finding the contract-freeze process is designed to surface (T-15-03: contract-vs-transition-table drift) — they were captured faithfully rather than silently smoothed over or silently fixed, preserving the DOC-ONLY constraint of this plan.

### Method/Getter Count Observations (informational, no CONTEXT.md correction — out of scope per D18 deferred-items)

- `PlaybackControl` has 12 methods by direct file count (plan prose said "13 方法"). Proceeded using the actual file structure as authoritative, per RESEARCH.md's Pitfall-3 guidance to derive counts dynamically rather than trust prose numbers.
- `EngineStateView` has 13 `ValueNotifier` getters + 1 `mediaInfo` getter = 14 getter-type members + `dispose()` = 15 total members (D3 decision text said "12"; plan's Task-1 done-criterion said "14 getters"). All 14 getter-type members were verified to retain their one-line Chinese comment per the D3 group-contract structure.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes were introduced. All edits are `///`/`//` doc-comment additions only.

## Self-Check: PASSED

All 10 modified files verified present on disk. All 3 task commits (`bbec3e9`, `f0a2a3f`, `e3a7817`) verified present in `git log --oneline --all`. `flutter analyze` on all 9 edited `.dart` files reports "No issues found!" (ran 3 times: after Task 1, Task 2, and Task 3 respectively). Diff inspection confirms all changes across all 3 commits are pure insertions (`git diff --stat` shows only `+` counts, zero `-` deletions) and every non-comment-context line matches `///` or `//` comment syntax — no method signatures, logic, or Token values were altered. No `!`/`late`/`as` introduced (verified via grep across the full 3-commit diff range). No forbidden files (`media_opener.dart`, `main.dart`, `player_screen.dart`, `video_surface.dart`, `playback_status_overlay.dart`, `lib/l10n/*`, `.planning/debug/*`, `15-PLAN-PHASE-CHECKPOINT.md`) were touched by this agent.
