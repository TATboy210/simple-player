---
phase: 01-unified-capture-contract
verified: 2026-08-30T08:53:21Z
status: human_needed
score: 4/4 must-haves verified
behavior_unverified: 1
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 2/4
  gaps_closed:
    - "CAP-04-SEMANTIC-DEDUPE-IDENTITY (selection): queue matching now scans newest-to-oldest with the time-window check fused into the same pass (_newestInWindowIndex, error_reporter.dart:296-312); the t=0/t=11/t=15 recurrence merges into the t=11 report and is covered by the active test 'merges a recurrence into the newest in-window occurrence' (error_reporter_test.dart:474-492)."
    - "CAP-04-SEMANTIC-DEDUPE-IDENTITY (serialization): the raw pipe-delimited _fingerprint was replaced by a 7-field record _ReportIdentity with structural per-field equality (_identity, error_reporter.dart:333-343 and typedef :457-465); pipe-bearing message/mediaPath pairs cannot collide and are covered by the active test 'keeps pipe-boundary message and media path pairs distinct' (error_reporter_test.dart:494-533)."
    - "Booted-Windows runtime behavior (previous behavior_unverified truth #2): UAT Tests 14 and 15 (01-UAT.md, 2026-08-30, manual, user-confirmed) exercised the real process-global callbacks from a debug Windows run — framework diagnostic visible, exactly one report per source, in-window merge, out-of-window re-queue, app never interrupted."
  gaps_remaining: []
  regressions: []
behavior_unverified_items:
  - truth: "A handled WindowService initialization failure preserves the existing App windowInitError state and reaches the reporter exactly once rather than being rethrown or reported by two paths (01-02 plan must-have)."
    test: "Force windowService.init() to throw during a real debug boot (e.g. temporarily throw inside WindowService.init) and observe app startup."
    expected: "App still starts with windowInitError populated, KernelLogger logs once, ErrorReporterImpl.reportBootstrapSafely is invoked exactly once, and the exception is not rethrown into the guarded zone."
    why_human: "main.dart:41-52 contains the only production path that can exercise this; no test injects a failing WindowService (the global_error_hooks_test.dart:41-50 check is source-text only), and UAT 14/15 covered only the success path."
human_verification:
  - test: "Window-init failure containment on a real Windows debug boot: make windowService.init() throw once (temporary throw or fault-injected build), then start the app."
    expected: "App reaches the player UI in a degraded-but-alive state, windowInitError reaches App, exactly one bootstrap report is enqueued, and no unhandled exception propagates out of the guarded zone."
    why_human: "Requires a booted Windows process with a deliberately failing platform channel; the automated suite has no seam that injects a real WindowService init failure."
coincidental_reliance_items:
  - truth: "CAP-03 failure containment"
    reason: fixture-only
    harden: "The public reporter is covered with injected throwing collaborators, but production bridge containment relies on the concrete reporter's internal fallback; an alternate ErrorReporter implementation would be silently swallowed by PlayerErrorReportBridge (player_error_report_bridge.dart:57-60 broad catch remains, warning-level, unchanged this round)."
---

# Phase 1: 统一捕获与报告契约 Verification Report

**Phase Goal:** 应用可将四类错误来源安全归一化为可追踪、可去重、可按序处理的报告，而不会因报告自身失败造成新的应用故障。
**Verified:** 2026-08-30T08:53:21Z
**Status:** human_needed
**Re-verification:** Yes — after commit d0abf62c (CAP-04 dedupe fix) and UAT completion (9d9e671b)

## MVP Mode Guard

Phase 1 is marked `mvp`, but its roadmap goal is not a valid `As a ..., I want ..., so that ....` User Story (known metadata noise carried from the previous verification). Per the re-verification instruction, this does not block the technical evidence audit below.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | 框架异常、未捕获异步异常、启动期异常和播放引擎异常都可产生同一种含事件 ID、时间、严重级、错误、调用栈及当时媒体路径的不可变报告。 | VERIFIED | `ErrorReport` immutable (`error_report.dart`); four adapters in `error_reporter.dart:130-181`; globals installed from `main.dart:31-32`; bridge owned by `player_services.dart:148-156`. Whitespace-redaction and throwing-provider gaps remain closed with active passing tests (quick regression this round). |
| 2 | 应用启动后，框架错误仍保留开发调试输出，异步未捕获错误被应用接管而不会作为未处理错误继续冒泡。 | VERIFIED | Previously PRESENT_BEHAVIOR_UNVERIFIED. UAT Test 15 (`01-UAT.md`, manual, user-confirmed) triggered both real paths from a booted Windows debug run via the temporary trigger panel: console diagnostic visible, exactly one report per source (occurrenceCount 1), in-window repeats merged, out-of-window recurrence re-queued (1→2→2→4), app never interrupted. UAT Test 14 covers the clean cold boot. |
| 3 | 连续发生的相同错误会在当前报告中合并重复次数；不同错误按发生顺序等待用户处理，关闭当前项会展示下一项而不丢失已记录证据。 | VERIFIED | Both d0abf62c fixes verified in current source: `_newestInWindowIndex` (`error_reporter.dart:296-312`) scans newest→oldest with the `elapsed >= 0 && elapsed <= 10s` check fused into the same pass — the t=0/t=11/t=15 sequence compares against t=11 (elapsed 4s) and merges, never against the stale t=0 entry. `_identity` (`:333-343`) returns a 7-field record with structural equality — no delimiter serialization, so `|`-bearing message/mediaPath values cannot collide. Deterministic FakeClock regressions for both exact scenarios are active and passing (`error_reporter_test.dart:474-533`). |
| 4 | 报告服务、其任一副作用或错误处理重入发生故障时，播放器不会因错误反馈链再次崩溃。 | VERIFIED (coincidental-reliance) | `_reportSafely`/`_publishSafely`/per-effect `_notifyEffects`/terminal `_emitLastResort` containment unchanged (`error_reporter.dart:201-237,392-426`); fault-injection tests pass. Fixture-only reliance on the concrete reporter's internal fallback inside the bridge remains a warning (see coincidental_reliance_items). |

**Score:** 4/4 truths verified (1 behavior-unverified plan-level item remains below truth level — see Human Verification)

## Re-verification Results

| Previous residual gap | Independent current-code evidence | Result |
| --- | --- | --- |
| CAP-04-SEMANTIC-DEDUPE-IDENTITY (oldest-match selection) | `_newestInWindowIndex` iterates `index = _queue.length - 1 … 0`, checks identity then elapsed-window per entry, returns the newest in-window match (`error_reporter.dart:296-312`). Doc comment explicitly references the 01-VERIFICATION t=0/t=11/t=15 gap. Active test 'merges a recurrence into the newest in-window occurrence' asserts queue length 2 with counts [1, 2] and `lastOccurredAt == t=15` (`error_reporter_test.dart:474-492`). | CLOSED |
| CAP-04-SEMANTIC-DEDUPE-IDENTITY (delimiter collision) | `_fingerprint` string join is gone; `_identity` builds a `_ReportIdentity` record (source, severity, errorType, playerErrorCode, message, mediaPath, topFrame) compared with structural `!=` (`error_reporter.dart:300, 333-343, 457-465`). Active test 'keeps pipe-boundary message and media path pairs distinct' reproduces the exact prior collision pair ('open failed\|segment' + 'clip.mp4' vs 'open failed' + 'segment\|clip.mp4') and asserts two FIFO entries with counts [1, 1] (`error_reporter_test.dart:494-533`). | CLOSED |
| Booted-Windows runtime behavior (previous behavior_unverified item) | UAT Tests 14–15 in `01-UAT.md` (2026-08-30, source: manual, evidence: debugPrint queue-count sequence 1→2→2→4, user-confirmed). The temporary debug trigger panel (`c8cd7ff9`) exercised the real process-global `FlutterError.onError` and root-isolate dispatcher paths and was cleanly removed afterward (`a47ab879` deletes only `lib/ui/player/debug_error_triggers.dart` + its PlayerScreen mount — verified in commit diff, no stubs left). | CLOSED |

## Post-Fix Commit Audit (spot-check)

Commits after d0abf62c up to HEAD are UAT/docs-only as claimed:

| Commit | Diff | Production impact |
| --- | --- | --- |
| c8cd7ff9, c37b81cb, e00aa2aa | debug trigger panel + log wording | Debug-only scaffolding (removed later) |
| 9d9e671b, 6a97a1c1 | 01-UAT.md / COVERAGE.md | Docs |
| a47ab879 | deletes debug_error_triggers.dart (-97 lines) + PlayerScreen mount (-10 lines) | Removal only; `lib/` delta vs d0abf62c is one blank line in player_screen.dart imports |
| Working tree | pubspec/l10n/integration-test local modifications, uncommitted | Unrelated to phase 01 diagnostics |

## Detailed Plan Must-Have Audit

| Plan | Must-have group | Status | Evidence |
| --- | --- | --- | --- |
| 01-01 | Four adapter APIs make immutable bounded reports; stack policy retained. | VERIFIED | Adapter/snapshot tests pass (quick regression). |
| 01-01 | Non-throwing fan-in, isolated effects, terminating reentrancy. | VERIFIED | Fault-injection tests pass (quick regression). |
| 01-01 | Capacity five; sixth distinct evicts head; dismiss/flush preserve FIFO. | VERIFIED | Queue-policy tests pass (quick regression). |
| 01-01 | Matching report within 10s merges; after 10s distinct. | VERIFIED (was FAILED) | Newest-in-window selection fixes the retained-duplicate case; boundary test (0s/10s/21s) and recurrence test (0s/11s/15s) both pass. |
| 01-01 | Pre-ready reports queued; idempotent flush presents original head. | VERIFIED | Queue/flush tests pass (quick regression). |
| 01-02 | Framework hook presents then forwards; dispatcher returns true. | VERIFIED | Injected-seam tests pass; real-runtime proof supplied by UAT 15. |
| 01-02 | One guarded bootstrap owns bindings/init/hooks/runApp; fallback returns normally. | VERIFIED | Source-order tests + BootstrapErrorFallback tests pass. |
| 01-02 | Window-init failure preserves App state, reports exactly once. | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Production path exists (`main.dart:41-52`), source-text test asserts structure, but no test injects a real failing WindowService init; UAT 14/15 cover the success path only. Routed to Human Verification. |
| 01-03 | Validation/OpenError dual ingress/disposal via one bridge. | VERIFIED | Bridge and PlayerServices tests pass (quick regression). |
| 01-03 | Path material redacted before queue/effects/presentation. | VERIFIED | Table-driven redaction tests pass (quick regression). |
| 01-03 | Merge only for nonnegative elapsed ≤ 10s; rollback appends. | VERIFIED (was FAILED) | Same fused-selection fix; rollback test (`:429-452`) and boundary test pass. |
| 01-04 | Whitespace-bearing paths expose basename only through all fan-out. | VERIFIED | End-to-end redaction tests pass (quick regression). |
| 01-04 | Severity/PlayerError code/sanitized path separations. | VERIFIED | Semantic-separation tests pass (quick regression). |
| 01-04 | Every fully equal report merges only within inclusive 0–10s; capacity five. | VERIFIED (was FAILED) | Both blockers fixed and regression-locked; capacity eviction unchanged. |
| 01-04 | PlayerError identity frozen at intake; throwing bridge provider forwards once with null. | VERIFIED | Mutation and throwing-provider tests pass (quick regression). |
| 01-04 | D-01/D-02/D-03/CAP-03 unchanged. | VERIFIED | No Wave-4 production changes touch bootstrap/presentation; suites green. |

## Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/kernel/diagnostics/error_report.dart` | Immutable report/presentation contracts | VERIFIED | 129 lines; final fields; contract test passes. |
| `lib/kernel/diagnostics/error_reporting_dependencies.dart` | Injected seams | VERIFIED | Substantive; consumed by reporter/hooks/bridge. |
| `lib/kernel/diagnostics/error_reporter.dart` | Four-source fan-in, bounded FIFO, dedupe, containment | VERIFIED | 465 lines; both dedupe blockers gone; production-wired via `ErrorReporterImpl.init()` + `GlobalErrorHooks.install` (`main.dart:31-32`). |
| `lib/kernel/diagnostics/diagnostic_redactor.dart` | Pre-fan-out path redaction | VERIFIED | 203 lines; called in `_createReport` and `_sanitizeMediaPath`. |
| `lib/kernel/diagnostics/global_error_hooks.dart` | Framework/dispatcher callbacks | VERIFIED | 127 lines; installed from main; UAT-proven on real runtime. |
| `lib/main.dart` | Same-zone bootstrap | VERIFIED | runZonedGuarded first; init precedes hook install. |
| `lib/kernel/diagnostics/player_error_report_bridge.dart` | Sole player ingress bridge | VERIFIED with warning | Wiring and exactly-once metadata fallback tested; broad `on Object` catch at `:57-60` unchanged (warning). |
| `lib/kernel/player_services.dart` | Bridge composition/teardown | VERIFIED | Single bridge, detached before controller/engine disposal. |
| `test/diagnostics/error_reporter_test.dart` | Queue/dedupe/redaction regression proof | VERIFIED | Now includes the 0/11/15 recurrence test and the `\|` boundary-collision test that the previous verification required. |
| `test/diagnostics/global_error_hooks_test.dart` | Hook/fallback proof | VERIFIED | Tests pass; real-runtime coverage supplied by UAT 15. |
| `test/diagnostics/player_error_report_bridge_test.dart` | Player ingress/metadata fault proof | VERIFIED | Tests pass. |

## Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `GlobalErrorHooks.install` | Flutter/dispatcher globals | sync setter assignment | WIRED | `main.dart:32`; `global_error_hooks.dart` setters. |
| guarded-zone callback | bootstrap reporter intake | `BootstrapErrorFallback` | WIRED | Fallback tests pass. |
| `PlayerServices` | `PlaybackController.onError` + `MediaEngine.lastError` | one `PlayerErrorReportBridge` | WIRED | `player_services.dart:148-156`; bridge listener at `player_error_report_bridge.dart:22,57`. |
| `_createReport` | redactor → immutable queue → effects/presentation | sanitize → bound → `_accept` → publish/effect | WIRED | Suites green; dedupe identity now correct. |
| `ErrorReport.copyWith` | retained FIFO merge slot | replacement at matching index | WIRED | `_replaceAt` rebuilds the queue with the merged report at the newest in-window index. |

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Diagnostics + player_services suites | `flutter test test/diagnostics/ test/kernel/player_services_test.dart` | 152 tests passed, 0 failures | PASS |
| Newest-in-window recurrence (0s/11s/15s) | test 'merges a recurrence into the newest in-window occurrence' (in suite above) | counts [1,2], merges into t=11 | PASS |
| `\|` boundary collision | test 'keeps pipe-boundary message and media path pairs distinct' (in suite above) | 2 distinct entries, counts [1,1] | PASS |
| Static analysis | `flutter analyze` | 58 issues: 0 warnings, 1 error — `integration_test/progress_bar_real_runtime_diagnosis_test.dart:110` (unrelated locally-modified progress-bar integration test, not phase 01 diagnostics, not production code); 57 infos | PASS with note |
| Real Windows global hooks | UAT Tests 14–15 (`01-UAT.md`, manual) | queue 1→2→(merge)→4, diagnostics visible, app intact | PASS |
| Window-init failure containment | no seam exists; requires fault-injected boot | not exercised | SKIP → Human Verification |

## Requirements Coverage

| Requirement | Source plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| CAP-01 | 01-01, 01-02, 01-03, 01-04 | Four sources share immutable report contract | SATISFIED | Code + focused tests + UAT 14/15 real-runtime evidence. |
| CAP-02 | 01-02, 01-04 | Three global hooks in one guarded zone; presentation retained; dispatcher returns true | SATISFIED | Injected-seam tests + UAT 15 real process-global dispatch on Windows. |
| CAP-03 | 01-01, 01-02, 01-04 | Sole non-throwing reentrancy-safe fan-in with isolated effects | SATISFIED | Fault injection passes; bridge broad-catch warning remains non-blocking. |
| CAP-04 | 01-01, 01-03, 01-04 | Bounded FIFO + correct fingerprint dedupe/count/dismissal | SATISFIED | Both d0abf62c fixes verified in source, regression-locked by two new tests, 152-test suite green. |

All four plan-declared IDs are accounted for; no orphaned Phase 1 requirements in `REQUIREMENTS.md`. Note: the REQUIREMENTS.md tracking table (rows 79–82) still reads "Gaps Found"/"Pending" — stale metadata for the orchestrator to refresh.

## Prohibition Checks (non-authoritative LLM judgment)

| Prohibition | Method | Result |
| --- | --- | --- |
| MUST NOT send errors/stacks/paths to remote telemetry | grep over all capture-chain files for http/dio/WebSocket/telemetry | No matches — process-local only. Non-authoritative. |
| MUST NOT make capture contingent on mounted UI/modal/user ack | Source review of hooks/reporter/bridge | All intake paths are synchronous, UI-free; pre-ready reports remain queued. Non-authoritative. |
| MUST NOT let feedback effect/listener/recursive intake kill the player or loop unbounded | Fault-injection tests + source review | Reentrancy terminates via non-recursive fallback; effects isolated. Non-authoritative. |

These judgment-tier prohibitions are flagged-unverified in the PLAN frontmatter; the static judgments above are advisory and do not substitute for human review.

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | ---: | --- | --- | --- |
| `lib/kernel/diagnostics/player_error_report_bridge.dart` | 57-60 | Broad silent reporter-failure catch | WARNING | Alternate ErrorReporter implementations would lose evidence without terminal output; does not crash the player; pre-existing, unchanged this round. |
| `lib/kernel/player_services.dart` | 163-171, 194-201 | Broad cleanup catches | WARNING | Pre-existing disposal behavior, not a phase-01 regression. |
| `integration_test/progress_bar_real_runtime_diagnosis_test.dart` | 110 | `flutter analyze` error (static_access_to_instance_member) | INFO | Locally-modified, uncommitted file unrelated to phase 01; outside this phase's must-haves but violates the milestone "analyze 0 error" red line until fixed. |

No `TBD`/`FIXME`/`XXX` debt markers exist in any phase-01 diagnostics production file (grep verified).

## Human Verification Required

### 1. Window-init failure containment (sole remaining item)

**Test:** On a real Windows debug boot, force `windowService.init()` to throw once (temporary throw or fault-injected build).
**Expected:** App still reaches the player UI in a degraded-but-alive state; `windowInitError` reaches `App`; exactly one bootstrap report is enqueued via `reportBootstrapSafely`; no unhandled exception escapes the guarded zone.
**Why human:** The failure path lives only in `main.dart:41-52`; no test seam injects a failing `WindowService`, and UAT 14/15 covered only the success path.

## Gaps Summary

Both CAP-04 blockers from the previous verification are closed in the current source and locked by deterministic regression tests: (1) `_newestInWindowIndex` selects the newest in-window equal-identity entry with the time check fused into the scan, so the 0s/11s/15s recurrence merges into the t=11 report; (2) the identity is now a 7-field record with structural equality, eliminating delimiter-collision merging entirely. The previous behavior-unverified truth (real Windows global-hook dispatch) is now covered by user-confirmed UAT evidence. All 152 diagnostics/player_services tests pass; `flutter analyze` has 0 warnings and no error inside phase-01 scope (one pre-existing/unrelated error in a locally-modified integration test is noted).

No automated gaps remain. The single outstanding item is a below-truth-level plan must-have (01-02 window-init failure exactly-once reporting) that no automated seam can exercise — routed to human verification. Once confirmed, the phase is complete.

---

_Verified: 2026-08-30T08:53:21Z_
_Verifier: Claude (gsd-verifier)_
