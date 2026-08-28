---
phase: 01-unified-capture-contract
verified: 2026-08-28T14:30:00Z
status: gaps_found
score: 1/4 must-haves verified
behavior_unverified: 1
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 2/4
  gaps_closed:
    - "GAP-1 production reachability: PlayerServices now owns one PlayerErrorReportBridge wired to PlaybackController.onError and MediaEngine.lastError."
    - "GAP-2 rollback handling: negative elapsed wall-clock intervals now append instead of merging."
  gaps_remaining:
    - "CAP-01 path sanitization is incomplete for local paths containing whitespace."
  regressions:
    - "Dedupe identity omits severity and mediaPath, allowing semantically distinct player reports to merge."
gaps:
  - truth: "框架异常、未捕获异步异常、启动期异常和播放引擎异常都可产生同一种含事件 ID、时间、严重级、错误、调用栈及当时媒体路径的不可变报告。"
    status: failed
    reason: "The PlayerError bridge is now production-wired, but DiagnosticRedactor stops embedded local-path matches at whitespace. Reports can retain sensitive directory components in message and stack snapshots, so the safety requirement is not met for all valid local paths."
    artifacts:
      - path: "lib/kernel/diagnostics/diagnostic_redactor.dart"
        issue: "Lines 24-38 use path regexes whose [^\\s...] tails stop at whitespace; e.g. C:\\Users\\alice\\Private Videos\\incident.mp4 is reduced only to Private Videos\\incident.mp4."
      - path: "test/diagnostics/error_reporter_test.dart"
        issue: "Lines 218-276 cover only path values with no whitespace, parentheses, or brackets and therefore do not prove the stated all-local-path safety contract."
    missing:
      - "Replace whitespace-terminated matching with a local-path token parser or delimiter-aware matcher that consumes quoted/unquoted paths containing spaces, parentheses, and brackets."
      - "Add Windows and POSIX regression tests asserting that only incident.mp4 remains in mediaPath, message, rawStackTrace, effects, and presentation."
  - truth: "连续发生的相同错误会在当前报告中合并重复次数；不同错误按发生顺序等待用户处理，关闭当前项会展示下一项而不丢失已记录证据。"
    status: failed
    reason: "The fingerprint includes only source, runtime type, sanitized message, and top frame. It omits severity, structured PlayerError code, and mediaPath, so a later fatal error or an error for another media target can merge into an earlier recoverable report and retain the earlier severity/path."
    artifacts:
      - path: "lib/kernel/diagnostics/error_reporter.dart"
        issue: "Lines 268-283 merge any matching fingerprint, while lines 316-318 construct that fingerprint without severity, PlayerError code, or mediaPath."
      - path: "test/diagnostics/player_error_report_bridge_test.dart"
        issue: "Lines 76-89 call a same-message but distinct error and assert occurrenceCount 2. This demonstrates bridge identity correlation but leaves the reporter's incorrect semantic merge unchallenged."
    missing:
      - "Include severity and sanitized mediaPath in the dedupe identity; retain a structured PlayerError discriminator/code in ErrorReport and fingerprint it as well."
      - "Add active regression tests proving same text/frame errors with different severity, PlayerError code, or media path remain separate FIFO reports."
behavior_unverified_items:
  - truth: "应用启动后，框架错误仍保留开发调试输出，异步未捕获错误被应用接管而不会作为未处理错误继续冒泡。"
    test: "In a Windows debug build, trigger one Flutter framework exception and one root-isolate uncaught asynchronous exception after startup."
    expected: "Flutter's normal development diagnostic is still presented and exactly one framework report is captured; the dispatcher error produces one report, PlatformDispatcher.onError handles it by returning true, and the player remains usable."
    why_human: "Injected callback tests establish adapter ordering and the literal true return, but do not exercise Flutter Windows process-global callbacks inside the booted app's real guarded zone."
human_verification:
  - test: "Windows debug global-hook smoke"
    expected: "A framework error retains Flutter development output and yields one report; a root-isolate asynchronous error is handled without terminating the player."
    why_human: "The current tests invoke setter-injected callbacks rather than the actual Windows Flutter runtime boundary."
---

# Phase 1: 统一捕获与报告契约 Verification Report

**Phase Goal:** 应用可将四类错误来源安全归一化为可追踪、可去重、可按序处理的报告，而不会因报告自身失败造成新的应用故障。  
**Verified:** 2026-08-28T14:30:00Z  
**Status:** gaps_found  
**Re-verification:** Yes — after 01-03 gap-closure execution

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | 框架异常、未捕获异步异常、启动期异常和播放引擎异常都可产生同一种含事件 ID、时间、严重级、错误、调用栈及当时媒体路径的不可变报告。 | ✗ FAILED | The original missing production PlayerError route is fixed: `PlayerServices` constructs the bridge at `lib/kernel/player_services.dart:148-156`; bridge listener/callback wiring reaches the sole production `reportPlayerError` call at `lib/kernel/diagnostics/player_error_report_bridge.dart:22, 31-57`. However, `DiagnosticRedactor.redactDiagnosticText` at lines 24-38 terminates every local-path match at whitespace, leaking e.g. `Private Videos\\incident.mp4` in reports. This contradicts CAP-01's safe unified-report contract. |
| 2 | 应用启动后，框架错误仍保留开发调试输出，异步未捕获错误被应用接管而不会作为未处理错误继续冒泡。 | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | `lib/main.dart:22-62` creates the guarded bootstrap then initializes/report-installs hooks; `global_error_hooks.dart:69-93` presents framework errors first and returns literal `true` for dispatcher errors. The focused injected-seam tests pass, but no test exercises those process-global callbacks in a booted Windows app. |
| 3 | 连续发生的相同错误会在当前报告中合并重复次数；不同错误按发生顺序等待用户处理，关闭当前项会展示下一项而不丢失已记录证据。 | ✗ FAILED | FIFO, dismissal, capacity, and rollback handling are implemented and tested, but `_fingerprint` in `error_reporter.dart:316-318` omits severity, code, and mediaPath. Thus distinct fatal/recoverable events or different media targets can be treated as the same error. `_accept` retains the first report's immutable severity/path at lines 268-283, hiding the later event's semantics. |
| 4 | 报告服务、其任一副作用或错误处理重入发生故障时，播放器不会因错误反馈链再次崩溃。 | ✓ VERIFIED | `ErrorReporterImpl._reportSafely`, `_publishSafely`, `_notifyEffects`, and terminal `_emitLastResort` contain failures (`error_reporter.dart:200-235, 356-390`). Focused tests exercise throwing collaborators, effect, notifier listener, reentrant intake, hooks, and fallback output; all passed. The bridge's silent metadata-failure drop is a warning because it can lose a report but does not create a new app fault. |

**Score:** 1/4 truths verified (1 present, behavior-unverified)

### Re-verification Results

The two named previous failures were checked against current code rather than accepting the 01-03 summary:

| Previous gap | Current evidence | Result |
| --- | --- | --- |
| GAP-1: PlayerError was not production-reachable | One bridge is created by `PlayerServices`, receives `PlaybackController.onError`, listens to `MediaEngine.lastError`, and detaches before controller/engine teardown. Focused bridge and service tests passed. | Production wiring closed; safe redaction remains incomplete (new residual blocker). |
| GAP-2: Wall-clock rollback merged stale reports | `_accept` requires `elapsed >= Duration.zero && elapsed <= _dedupeWindow` at `error_reporter.dart:275-283`; test at `error_reporter_test.dart:297-320` passes. | Closed. |

## Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/kernel/diagnostics/error_report.dart` | Immutable report and presentation contracts | ✓ VERIFIED | `ErrorReport` and `ErrorPresentationState` have final snapshot fields; `copyWith` preserves identity fields (`:36-121`). Contract test passed. |
| `lib/kernel/diagnostics/error_reporting_dependencies.dart` | Injectable reporting seams | ✓ VERIFIED | Typed ID, path, effect, terminal fallback seams plus reused `Clock` alias are substantive (`:9-49`) and consumed by reporter/hooks/bridge. |
| `lib/kernel/diagnostics/error_reporter.dart` | Sole safe fan-in, FIFO, dedupe, effects | ⚠️ PARTIAL | All four APIs and containment paths are substantive and wired, but semantic dedupe can merge different severity/code/media reports. |
| `lib/kernel/diagnostics/diagnostic_redactor.dart` | Redact every local path before fan-out | ✗ FAILED | Substantive implementation is called before bounds/queue, but whitespace-delimited regexes at `:24-38` leak directory components. |
| `lib/kernel/diagnostics/player_error_report_bridge.dart` | Single PlayerError ingress bridge and cleanup | ✓ VERIFIED | Subscribes only to project-owned `lastError`, accepts controller callback, correlates by object identity, and removes exact listener (`:15-61`). |
| `lib/kernel/player_services.dart` | Production bridge composition and disposal ownership | ✓ VERIFIED | Creates one bridge then injects callback (`:148-157`); removes bridge before controller/engine disposal (`:181-191`). |
| `lib/kernel/diagnostics/global_error_hooks.dart` | Framework and dispatcher adapters | ✓ VERIFIED | Production global setters at `:104-114`; framework presentation precedes report at `:69-80`; dispatcher returns `true` at `:83-94`. |
| `lib/main.dart` | Same-zone bootstrap and early reporter initialization | ✓ VERIFIED | `runZonedGuarded` is the first executable operation (`:22-23`), and logger/reporter initialize before hook registration (`:30-34`). |
| `test/diagnostics/error_reporter_test.dart` | Reporter policy and redaction regressions | ⚠️ PARTIAL | Active and passing, but local-path samples omit whitespace and no semantic-fingerprint separation test exists. |
| `test/diagnostics/player_error_report_bridge_test.dart` | Production ingress/lifecycle behavior | ⚠️ PARTIAL | Active and passing; its distinct-instance test intentionally observes a merge, so it does not prove semantically distinct reports remain separate. |

## Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `GlobalErrorHooks.install` | Flutter framework / platform dispatcher callbacks | Production setter callbacks | ✓ WIRED | `main.dart:32` calls install after reporter init; setters assign both Flutter global callbacks in `global_error_hooks.dart:104-114`. |
| guarded zone handler | `ErrorReporterImpl.reportBootstrapSafely` | lifecycle-probed `BootstrapErrorFallback` | ✓ WIRED | `main.dart:61` supplies fallback; `:69-118` avoids unsafe singleton access and contains terminal-output failure. |
| Player failure boundaries | `ErrorReporter.reportPlayerError` | `PlaybackController.onError` plus `MediaEngine.lastError` through one bridge | ✓ WIRED | Composition and bridge calls at `player_services.dart:148-156` and `player_error_report_bridge.dart:22, 31-57`; no other production player ingress invokes reporter. |
| Reporter normalization | FIFO, `presentation`, effects | `_createReport` then `_accept`, publish, notify | ⚠️ PARTIAL | Fan-out wiring is correct, but redaction feeds unsafe residual local path text and dedupe identity omits semantic fields. |

## Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `global_error_hooks.dart` / `main.dart` | framework, dispatcher, bootstrap error inputs | Live Flutter callbacks and guarded startup path | Yes | ✓ FLOWING |
| `player_error_report_bridge.dart` | `PlayerError` / current media path | Live controller callback and `MediaEngine.lastError` notifier | Yes | ✓ FLOWING |
| `error_reporter.dart` | immutable report snapshots | `_createReport` normalizes real ingress values before queue/effect/presentation | Yes, but unsafe for paths with whitespace | ⚠️ UNSAFE_FLOW |
| `error_reporter.dart` | dedupe selection | Retained FIFO reports and injected clock | Yes, but semantically incomplete | ⚠️ COLLIDING_FLOW |

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Immutable reports, all adapters, FIFO/dedupe, fault containment, global hooks, player bridge/lifecycle | `D:/flutter/bin/flutter test test/diagnostics/error_report_test.dart test/diagnostics/error_reporter_test.dart test/diagnostics/global_error_hooks_test.dart test/diagnostics/player_error_report_bridge_test.dart test/kernel/player_services_test.dart test/kernel/services/playback_controller_test.dart` | 46 tests passed | ✓ PASS |
| Static analysis | `flutter analyze` | Orchestrator-confirmed: `No issues found` | ✓ PASS |
| Full workspace regression suite | `flutter test` | Orchestrator-confirmed: 1,254 passed | ✓ PASS |
| Real Windows global-hook behavior | Application not started by verifier | Requires interactive runtime injection | ? SKIP |

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| CAP-01 | 01-01, 01-02, 01-03 | Four source types normalize to one immutable report with timestamp, severity, error, stack, media snapshot, and event ID | ✗ BLOCKED | Four code paths and current production player bridge exist, but the report safety boundary leaks directory fragments for whitespace-containing local paths. A bridge metadata lookup failure is also silently dropped rather than falling back to a null media path (`player_error_report_bridge.dart:53-60`). |
| CAP-02 | 01-02 | Same guarded-zone hook installation, framework development presentation, dispatcher returns true | ⚠️ NEEDS HUMAN | Static composition and injected callback tests prove intended behavior. Actual Windows global runtime behavior has not been exercised. |
| CAP-03 | 01-01, 01-02 | Single non-throwing fan-in/fan-out, isolated effects, reentrancy safety | ✓ SATISFIED | Reporter/hook fault-injection tests prove all named public paths return normally after collaborator/effect/listener/reentrant failures. |
| CAP-04 | 01-01, 01-03 | Bounded FIFO, correct dedupe/count, and dismissal preservation | ✗ BLOCKED | Capacity/FIFO/dismissal/rollback tests pass, but identity excludes severity, structured code, and media target. Reports that are observably different can be merged and lose their fatal/path meaning. |

All plan-declared IDs are accounted for: CAP-01, CAP-02, CAP-03, CAP-04. No additional Phase 1 IDs are orphaned in `D:/simple_player_flutter/.planning/REQUIREMENTS.md`. Its traceability table currently marks CAP-01 and CAP-04 `Complete`, which is stale relative to this code-based verdict.

## Test Quality Audit

| Test File | Linked Req | Active | Skipped | Circular | Assertion Level | Verdict |
| --- | --- | ---: | ---: | --- | --- | --- |
| `test/diagnostics/error_report_test.dart` | CAP-01 | 1 | 0 | No | Value | Valid immutable-value contract. |
| `test/diagnostics/error_reporter_test.dart` | CAP-01, CAP-03, CAP-04 | 15 | 0 | No | Behavioral | Valid normal-path/fault coverage; insufficient for whitespace paths and semantic dedupe identity. |
| `test/diagnostics/global_error_hooks_test.dart` | CAP-01, CAP-02, CAP-03 | 9 | 0 | No | Behavioral/source-order | Valid injected seam checks; not a real Windows global-hook proof. |
| `test/diagnostics/player_error_report_bridge_test.dart` | CAP-01, CAP-04 | 5 | 0 | No | Behavioral | Valid bridge ingress/cleanup coverage; the same-message-distinct-instance test asserts merge count 2, so it cannot prove correct semantic deduplication. |
| `test/kernel/player_services_test.dart` | CAP-01 | 3 | 0 | No | Behavioral | Valid composition/lifecycle seam coverage. |

**Disabled tests on requirements:** 0  
**Circular patterns detected:** 0  
**Insufficient assertions:** 2 gaps — missing whitespace-path redaction cases and missing severity/code/media fingerprint separation cases.

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | ---: | --- | --- | --- |
| `lib/kernel/diagnostics/diagnostic_redactor.dart` | 24-38 | Whitespace-terminated regex path matching | BLOCKER | Leaks local directory names in retained message/stack fields. |
| `lib/kernel/diagnostics/error_reporter.dart` | 268-283, 316-318 | Dedupe fingerprint lacks semantic identity fields | BLOCKER | A fatal/different-media player error can be represented as the earlier recoverable report. |
| `lib/kernel/diagnostics/player_error_report_bridge.dart` | 53-60 | Catch-all silently drops a player report if media metadata lookup fails | WARNING | Optional metadata failure prevents unified capture instead of reporting with a null media path. |
| `lib/kernel/diagnostics/diagnostic_redactor.dart` | 32-35 | Drive-style matching can alter remote URL paths containing `X:/` | WARNING | Can remove useful network stream diagnostic context. |

No `TBD`, `FIXME`, or `XXX` debt markers were found in the phase diagnostic implementation files. No remote telemetry sender or endpoint is present in the phase reporting path. The bridge is not UI/modal-dependent, and diagnostic listeners are detached on service disposal.

### Decision Coverage

All four trackable `01-CONTEXT.md` decisions remain represented: a single guarded startup zone (`main.dart`), main-owned reporter initialization, readiness-gated FIFO presentation, and capacity-five/time-window queue policy. This is non-blocking coverage information.

## Human Verification Required

### 1. Windows debug global-hook smoke

**Test:** Run `D:/flutter/bin/flutter run -d windows` in debug mode. Trigger a controlled Flutter framework exception and a controlled root-isolate unhandled asynchronous exception after application startup.

**Expected:** The framework exception retains normal Flutter developer diagnostics and creates one report. The asynchronous exception creates one report, is treated as handled by dispatcher return `true`, and the player remains usable.

**Why human:** Existing tests use setter-injected callbacks; they do not invoke Flutter Windows' process-global callback dispatch in the real startup zone.

## Gaps Summary

The 01-03 closure genuinely repaired the original missing player bridge and wall-clock rollback behavior, and the focused code/test evidence proves those repairs. The phase nevertheless still fails its goal contract.

First, local diagnostic capture is not safe for valid local filenames containing spaces: the redactor leaves directory fragments in report message and stack text. Second, dedupe treats reports with different severity, PlayerError code, or media target as equivalent. That can hide a later fatal event as an earlier recoverable event and therefore violates both the safe traceability and distinct-error FIFO portions of the Phase 1 goal.

These are Phase 1 requirements, not deferred Phase 2/3 work: CAP-01 explicitly requires safe four-source immutable reports and CAP-04 requires correct fingerprint deduplication. No later roadmap criterion specifically schedules repair of these two defects, so neither is deferred.

---

_Verified: 2026-08-28T14:30:00Z_  
_Verifier: Claude (gsd-verifier)_
