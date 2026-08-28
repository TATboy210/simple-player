---
phase: 01-unified-capture-contract
verified: 2026-08-28T16:10:00Z
status: gaps_found
score: 2/4 must-haves verified
behavior_unverified: 1
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 1/4
  gaps_closed:
    - "CAP-01-WHITESPACE-PATH-REDACTION: delimiter-aware redaction now removes Windows/POSIX directory prefixes containing whitespace, parentheses, and brackets before queue, effects, and presentation."
    - "CAP-01-BRIDGE-METADATA-CONTAINMENT: a throwing media-path provider now degrades to null while the original PlayerError is forwarded once."
  gaps_remaining:
    - "CAP-04-SEMANTIC-DEDUPE-IDENTITY remains incomplete: the queue chooses the oldest equal fingerprint instead of the newest in-window occurrence, and delimiter-based fingerprint serialization permits distinct reports to collide."
  regressions: []
gaps:
  - truth: "Matching reports received within the inclusive zero-through-ten-second window merge with the applicable retained report while post-window reports remain distinct."
    status: failed
    reason: "_findMatchingIndex scans FIFO from oldest to newest and returns the first equal fingerprint. After equal reports at t=0 and t=11, an equal report at t=15 is compared only to t=0, fails the window check, and is appended instead of merging into the t=11 report."
    artifacts:
      - path: "lib/kernel/diagnostics/error_reporter.dart"
        issue: "Lines 274-288 apply the time check only after _findMatchingIndex; lines 297-304 return the oldest equal fingerprint."
      - path: "test/diagnostics/error_reporter_test.dart"
        issue: "No active regression covers occurrences at 0s, 11s, and 15s."
    missing:
      - "Select the newest same-fingerprint retained report that has a nonnegative elapsed duration no greater than 10 seconds, rather than selecting the first FIFO match."
      - "Add a deterministic FakeClock regression for t=0, t=11, and t=15 proving the final occurrence merges into the t=11 report."
  - truth: "Reports merge only when every semantic fingerprint field matches; reports with a different sanitized message or sanitized media path remain distinct."
    status: failed
    reason: "_fingerprint joins untrusted variable-length fields with an unescaped | delimiter, so distinct field boundaries can serialize identically and merge."
    artifacts:
      - path: "lib/kernel/diagnostics/error_reporter.dart"
        issue: "Line 323 concatenates message, mediaPath, and top frame with raw | separators. For example message 'open failed|segment' plus mediaPath 'clip.mp4' collides with message 'open failed' plus mediaPath 'segment|clip.mp4' when all other fields match."
      - path: "test/diagnostics/error_reporter_test.dart"
        issue: "No active test includes a | boundary-collision pair."
    missing:
      - "Use a typed equality key/record or direct field comparison; do not serialize unescaped variable-length fields with delimiters."
      - "Add a regression proving the two | boundary-collision reports remain two FIFO entries."
behavior_unverified_items:
  - truth: "After the real Windows application starts, framework errors retain Flutter development presentation and root-isolate asynchronous errors are handled by PlatformDispatcher without terminating the player."
    test: "Run a Windows debug build, trigger one Flutter framework exception and one root-isolate uncaught asynchronous exception after startup."
    expected: "Flutter's normal development diagnostic remains visible; each source produces exactly one report; dispatcher handling returns true and the player remains usable."
    why_human: "The focused tests invoke setter-injected callback seams. They do not exercise Flutter Windows process-global dispatch from a booted application in its real guarded zone."
coincidental_reliance_items:
  - truth: "CAP-03 failure containment"
    reason: fixture-only
    harden: "The public reporter is covered with injected throwing collaborators, but production bridge containment relies on the concrete reporter's internal fallback; an alternate ErrorReporter implementation would be silently swallowed by PlayerErrorReportBridge."
---

# Phase 1: 统一捕获与报告契约 Verification Report

**Phase Goal:** 应用可将四类错误来源安全归一化为可追踪、可去重、可按序处理的报告，而不会因报告自身失败造成新的应用故障。  
**Verified:** 2026-08-28T16:10:00Z  
**Status:** gaps_found  
**Re-verification:** Yes — after 01-04 gap-closure execution

## MVP Mode Guard

Phase 1 is marked `mvp`, but its roadmap goal is not a valid required User Story (`As a ..., I want to ..., so that ....`). The centralized validation query returned `false`. Therefore a formal MVP user-flow/UAT verdict cannot be produced until the phase goal is reformatted. The technical evidence audit below was completed because the phase has independently observable roadmap criteria and the user explicitly requested re-verification; it found blocking implementation defects regardless of the metadata discrepancy.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | 框架异常、未捕获异步异常、启动期异常和播放引擎异常都可产生同一种含事件 ID、时间、严重级、错误、调用栈及当时媒体路径的不可变报告。 | VERIFIED | `ErrorReport` is immutable (`error_report.dart:36-105`); reporter implements all four adapters (`error_reporter.dart:129-180`); globals are installed from `main.dart:30-32`; and `PlayerServices` owns the bridge (`player_services.dart:148-156`). The focused tests directly exercise adapter normalization, bridge validation/OpenError/notifier ingress, timestamps, stack markers, IDs, and immutable PlayerError snapshots. Whitespace-path and throwing-provider gaps from the prior verification are covered by active passing tests. |
| 2 | 应用启动后，框架错误仍保留开发调试输出，异步未捕获错误被应用接管而不会作为未处理错误继续冒泡。 | PRESENT_BEHAVIOR_UNVERIFIED | `GlobalErrorHooks` presents first then reports (`global_error_hooks.dart:69-80`), always returns literal `true` for dispatcher errors (`:83-94`), and is installed inside `runZonedGuarded` after reporter initialization (`main.dart:22-34`). Injected-seam tests pass, but a booted Windows Flutter runtime has not exercised its actual process-global callbacks. |
| 3 | 连续发生的相同错误会在当前报告中合并重复次数；不同错误按发生顺序等待用户处理，关闭当前项会展示下一项而不丢失已记录证据。 | FAILED | FIFO capacity, dismissal, flush, and several separation cases work, but the matching algorithm selects an out-of-window oldest duplicate and the delimiter-serialized fingerprint can collide across distinct message/path fields. Either defect permits incorrect retention/merging. |
| 4 | 报告服务、其任一副作用或错误处理重入发生故障时，播放器不会因错误反馈链再次崩溃。 | VERIFIED (coincidental-reliance) | `_reportSafely`, `_publishSafely`, per-effect `_notifyEffects`, and terminal `_emitLastResort` isolate failures (`error_reporter.dart:201-237,373-407`); focused tests pass for throwing collaborators, effects, listeners, reentry, hook reporters/presenters, and fallback output. The bridge's broad silent catch is a warning because it makes this proof depend on the concrete reporter's own containment. |

**Score:** 2/4 truths verified (1 present, behavior-unverified)

## Re-verification Results

| Previous residual gap | Independent current-code evidence | Result |
| --- | --- | --- |
| CAP-01-WHITESPACE-PATH-REDACTION | `DiagnosticRedactor` uses a token scanner rather than whitespace-terminated matching (`diagnostic_redactor.dart:23-193`). Active tests cover quoted/unquoted Windows/POSIX paths containing whitespace, parentheses, and brackets through report, effect, and presentation (`error_reporter_test.dart:313-433`). | CLOSED |
| CAP-01-BRIDGE-METADATA-CONTAINMENT | `_snapshotMediaPath` catches metadata failure and returns null, after which `_reportSafely` invokes `reportPlayerError` once (`player_error_report_bridge.dart:53-71`). The active recording-reporter test asserts original identity and null metadata (`player_error_report_bridge_test.dart:92-112`). | CLOSED |
| CAP-04-SEMANTIC-DEDUPE-IDENTITY | Severity, PlayerError discriminator, and sanitized path were added to the identity inputs, but queue selection and serialization still violate semantic dedupe. | NOT CLOSED |

## Detailed Plan Must-Have Audit

| Plan | Must-have group | Status | Evidence |
| --- | --- | --- | --- |
| 01-01 | Four adapter APIs make immutable bounded reports; supplied/absent stack policy is retained. | VERIFIED | Adapter and snapshot tests pass; report fields are final and `copyWith` preserves identity. |
| 01-01 | Fan-in is non-throwing, effects isolate, and recursive intake terminates. | VERIFIED | Reentrancy/effect/listener/collaborator fault-injection tests pass. |
| 01-01 | Capacity is five; sixth distinct report evicts head; dismiss and flush preserve FIFO. | VERIFIED | `error_reporter_test.dart:152-188` passes. |
| 01-01 | A matching report inside 10 seconds merges; after 10 seconds it is distinct. | FAILED | This claim is not true once more than one equal post-window report is retained; oldest-match selection breaks the 0s/11s/15s sequence. |
| 01-01 | Pre-ready reports remain queued and idempotent flush presents the original head. | VERIFIED | Queue/flush test passes and `_publishSafely` does not mutate `_queue`. |
| 01-02 | Framework hook presents first and forwards; dispatcher forwards exact values and returns true. | VERIFIED | Active setter-injected behavioral tests prove order, identity, containment, and `true`. Real-Windows behavior remains separately behavior-unverified above. |
| 01-02 | One guarded bootstrap owns bindings, initialization, hooks, and runApp; unavailable reporter fallback returns normally. | VERIFIED | `main.dart:22-62` and deterministic fallback tests verify the structural/lifecycle contract. |
| 01-02 | Window initialization recovery preserves App state and reports once; main owns diagnostic initialization. | PRESENT_BEHAVIOR_UNVERIFIED | Source code has one local catch/forward path (`main.dart:40-52`) and PlayerServices no longer initializes the logger, but no test injects a real WindowService initialization failure to prove state plus exactly-once reporting. |
| 01-03 | Validation, OpenError dual ingress, later notifier error, and disposal flow through one production-owned bridge. | VERIFIED | Bridge and PlayerServices tests cover validation, identity-scoped dual ingress suppression, later notifier input, ownership, order, and idempotent detach. |
| 01-03 | Windows/UNC/POSIX/file-URI material is redacted before queue/effects/presentation. | VERIFIED | Active table-driven redaction and downstream observation test passes. |
| 01-03 | Deduplication merges only for nonnegative elapsed time through ten seconds. | FAILED | The negative-clock guard exists, but selection of an older equal report means the complete time-window invariant is false for retained repeated fingerprints. |
| 01-04 | Whitespace-bearing local paths expose basename-only values through all fan-out. | VERIFIED | The gap-closure scanner and end-to-end tests cover the named Windows/POSIX cases. |
| 01-04 | Different severity, typed PlayerError code, or sanitized media path stay distinct. | VERIFIED | Active semantic-separation test verifies these three dimensions. |
| 01-04 | Every fully equal report merges only within the inclusive 0–10 second window; capacity remains five. | FAILED | Oldest-match selection violates the within-window portion; raw delimiter serialization violates the every-semantic-field portion. |
| 01-04 | PlayerError structured identity is frozen at intake; throwing bridge metadata lookup forwards once with null. | VERIFIED | `playerErrorCode` is immutable/copy-preserved; active mutation and throwing-provider tests pass. |
| 01-04 | D-01/D-02/D-03/CAP-03 behavior remains unchanged. | VERIFIED | No Wave-4 production changes touch bootstrap or presentation ownership; focused diagnostics and static analysis pass. |

## Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/kernel/diagnostics/error_report.dart` | Immutable report/presentation contracts and player discriminator snapshot | VERIFIED | Final fields and replacement-only `copyWith`; direct contract test passes. |
| `lib/kernel/diagnostics/error_reporting_dependencies.dart` | Injected clock/ID/path/effect/fallback seams | VERIFIED | Substantive typed interfaces consumed by reporter, hooks, and bridge. |
| `lib/kernel/diagnostics/error_reporter.dart` | Four-source fan-in, bounded FIFO, effects, dedupe | PARTIAL | Exists, substantive, and production-wired, but contains both dedupe blockers at `:274-304` and `:321-324`. |
| `lib/kernel/diagnostics/diagnostic_redactor.dart` | Pre-fan-out local path redaction | VERIFIED | Scanner is called from `_createReport` before bounds/queue/effects/presentation. |
| `lib/kernel/diagnostics/global_error_hooks.dart` | Framework/dispatcher callbacks | VERIFIED | Production setters and tested injected seams are wired from main. |
| `lib/main.dart` | Same-zone bootstrap and early initialization | VERIFIED | The first executable operation is `runZonedGuarded`; initialization precedes hook installation. |
| `lib/kernel/diagnostics/player_error_report_bridge.dart` | Sole project-owned player ingress bridge | VERIFIED with warning | Listener/callback and lifecycle wiring work. Its `on Object` catch at `:57-60` silently swallows an alternate reporter failure. |
| `lib/kernel/player_services.dart` | Bridge composition and teardown ownership | VERIFIED | Exactly one bridge is created and detached before controller/engine disposal. |
| `test/diagnostics/error_reporter_test.dart` | Report, queue, redaction, containment regression proof | PARTIAL | 18 active passing tests, but missing 0/11/15 recurrence and `|` collision regression coverage. |
| `test/diagnostics/global_error_hooks_test.dart` | Global hook/fallback test proof | VERIFIED | 9 active passing tests; runtime process-global coverage still requires Windows verification. |
| `test/diagnostics/player_error_report_bridge_test.dart` | Player ingress and metadata fault proof | VERIFIED | 6 active passing tests including null-path exactly-once behavior. |

## Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `GlobalErrorHooks.install` | Flutter and dispatcher globals | synchronous production setter assignment | WIRED | `main.dart:32` calls install; both globals are assigned in `global_error_hooks.dart:104-114`. |
| guarded-zone callback | bootstrap reporter intake | lifecycle-probed `BootstrapErrorFallback` | WIRED | `main.dart:61`, `:69-126` contain unavailable-singleton and terminal-output paths. |
| `PlayerServices` | `PlaybackController.onError` and `MediaEngine.lastError` | one `PlayerErrorReportBridge` | WIRED | `player_services.dart:148-156`; bridge adds/removes the notifier listener and calls reporter at `player_error_report_bridge.dart:22,57`. |
| `_createReport` | redactor, immutable queue, effect, presentation | sanitize → bound → `_accept` → publish/effect | PARTIAL | Dynamic source data flows correctly, but erroneous dedupe identity/selection corrupts the queue behavior. |
| `ErrorReport.copyWith` | retained FIFO merge slot | replacement at matching index | PARTIAL | Replacement preserves semantic fields, but the selected index may be the wrong historical occurrence. |

## Data-Flow Trace (Level 4)

| Artifact | Data variable | Source | Produces real data | Status |
| --- | --- | --- | --- | --- |
| global hooks / main | Flutter, dispatcher, and zone error inputs | Flutter runtime boundaries | Yes | FLOWING (runtime Windows hook dispatch not directly exercised) |
| player bridge | `PlayerError` and current media snapshot | Controller callback plus `MediaEngine.lastError` | Yes | FLOWING |
| reporter normalization | immutable report values | source errors and injected clock/path provider | Yes | FLOWING |
| dedupe queue | semantic report identity and occurrence count | retained reports plus clock | No, for recurrence/collision edge cases | DISCONNECTED FROM REQUIRED SEMANTICS |

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Immutable reports, four adapters, FIFO, redaction, containment, hooks, player bridge, lifecycle | `flutter test test/diagnostics/error_report_test.dart test/diagnostics/error_reporter_test.dart test/diagnostics/global_error_hooks_test.dart test/diagnostics/player_error_report_bridge_test.dart test/kernel/player_services_test.dart test/kernel/services/playback_controller_test.dart` | 51 tests passed | PASS |
| Static analysis | `flutter analyze` | `No issues found!` | PASS |
| 0s → 11s → 15s equal recurrence | Manual source trace of `_findMatchingIndex` and `_accept` | Selects index 0 at t=15, sees 15 seconds, appends; t=11 item is never examined | FAIL |
| `|` message/path boundary collision | Manual source trace of `_fingerprint` | Both differing tuples serialize to the same raw delimiter string | FAIL |
| Real Windows global hooks | No server/application started by verifier | Cannot safely invoke actual process-global callbacks without a Windows app run | SKIP |

## Requirements Coverage

| Requirement | Source plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| CAP-01 | 01-01, 01-02, 01-03, 01-04 | Four sources share immutable report contract with timestamps, severity, error, stack, path and event ID | NEEDS HUMAN | Code and focused tests verify the report contract, player wiring, redaction, and injected global callbacks. The real Windows global-hook outcome is not exercised. |
| CAP-02 | 01-02, 01-04 | Three global hooks are installed in one guarded zone; framework presentation remains; dispatcher returns true | NEEDS HUMAN | Source and injected callback tests pass; process-global Windows runtime behavior remains unproven. |
| CAP-03 | 01-01, 01-02, 01-04 | Sole non-throwing reentrancy-safe fan-in/fan-out with isolated effects | SATISFIED | Fault injection verifies reporter/hook behavior. Warning: bridge swallows failures from an arbitrary injected reporter without terminal output. |
| CAP-04 | 01-01, 01-03, 01-04 | Bounded FIFO plus correct fingerprint dedupe/count/dismissal | BLOCKED | Capacity, FIFO and normal separations work, but the two dedupe blockers make the full semantic window contract false. |

All plan-declared IDs are accounted for: CAP-01, CAP-02, CAP-03, and CAP-04. No additional Phase 1 requirements are orphaned in `D:/simple_player_flutter/.planning/REQUIREMENTS.md`.

## Test Quality Audit

| Test file | Linked requirements | Active | Skipped | Circular | Assertion level | Verdict |
| --- | --- | ---: | ---: | --- | --- | --- |
| `test/diagnostics/error_report_test.dart` | CAP-01, CAP-04 | 1 | 0 | No | Value | Valid immutable replacement check. |
| `test/diagnostics/error_reporter_test.dart` | CAP-01, CAP-03, CAP-04 | 18 | 0 | No | Behavioral | Insufficient for newest-in-window recurrence and delimiter collision. |
| `test/diagnostics/global_error_hooks_test.dart` | CAP-01, CAP-02, CAP-03 | 9 | 0 | No | Behavioral/source-order | Valid injected-seam evidence; not production-Windows callback proof. |
| `test/diagnostics/player_error_report_bridge_test.dart` | CAP-01, CAP-04 | 6 | 0 | No | Behavioral | Valid bridge/metadata/lifecycle evidence. |
| `test/kernel/player_services_test.dart` | CAP-01 | 3 | 0 | No | Behavioral | Valid composition and disposal evidence. |

**Disabled tests on requirements:** 0  
**Circular patterns detected:** 0  
**Insufficient assertions:** 2 blocker omissions — no 0/11/15 recurrence test and no `|` fingerprint-collision test.

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | ---: | --- | --- | --- |
| `lib/kernel/diagnostics/error_reporter.dart` | 274-304 | First FIFO equality match selected before time-window evaluation | BLOCKER | A valid current recurrence fragments into an unnecessary third report rather than increasing the newer report's count. |
| `lib/kernel/diagnostics/error_reporter.dart` | 321-324 | Unescaped delimiter serialization of semantic identity | BLOCKER | Distinct message/media-path evidence can collide and be incorrectly merged. |
| `lib/kernel/diagnostics/player_error_report_bridge.dart` | 57-60 | Silent broad reporter-failure catch | WARNING | An alternate `ErrorReporter` implementation can lose diagnostic evidence without terminal output; it does not currently crash the player. |
| `lib/kernel/player_services.dart` | 163-171, 194-201 | Broad cleanup catches | WARNING | Catches programming errors during disposal; pre-existing lifecycle behavior is not a direct cause of the Phase 1 goal failure. |

No `TBD`, `FIXME`, or `XXX` debt marker exists in Phase-1 diagnostic production files. Static source review found no remote telemetry transport, no mounted-UI/modal dependency in capture, and no media_kit package modification. These prohibition checks are non-authoritative static judgments; the phase already has concrete blockers and they must not be treated as a substitute for fixing them.

### Decision Coverage

All 4/4 trackable `01-CONTEXT.md` decisions are represented in shipped artifacts: same-zone bootstrap (D-01), main-owned initialization (D-02), readiness-gated FIFO publication (D-03), and capacity/time-window policy (D-04). This non-blocking check does not establish that the D-04 implementation is correct.

## Deferred Items

None. The two failed dedupe properties are Phase-1 CAP-04 responsibilities. No later roadmap success criterion specifically schedules their repair, so they are not deferred to Phases 2–5.

## Human Verification Required After Gap Closure

### 1. Windows debug global-hook smoke

**Test:** Run `flutter run -d windows` in debug mode. Trigger a controlled Flutter framework exception and a root-isolate uncaught asynchronous exception after startup.

**Expected:** Flutter's normal development diagnostic remains visible; each input results in exactly one report; dispatcher handling prevents application termination and the player remains usable.

**Why human:** The active tests use setter-injected callbacks rather than Flutter Windows' live process-global callback dispatch.

## Gaps Summary

The 01-04 work genuinely closes the prior whitespace redaction and bridge-metadata gaps. It also correctly adds severity, structured PlayerError code, and sanitized media path to the intended identity dimensions. However, its implementation is still not a correct semantic deduplicator.

First, it searches equal fingerprints FIFO-first, not newest applicable occurrence. The reproducible timeline `t=0`, `t=11`, `t=15` violates the stated inclusive 0–10-second merge policy. Second, it represents the identity as a raw pipe-delimited string. Since message and media path are untrusted strings that can contain `|`, different reports can have the same serialized key. Both defects are observable in the actual implementation and are BLOCKERS for CAP-04 and the phase goal.

The phase must not proceed until the two gaps are repaired and targeted regression tests are added. After automated closure, retain the Windows debug hook smoke as the remaining human verification item and correct the invalid MVP goal metadata before relying on an MVP/UAT completion verdict.

---

_Verified: 2026-08-28T16:10:00Z_  
_Verifier: Claude (gsd-verifier)_
