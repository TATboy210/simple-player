---
phase: quick-260901-eyw
plan: 01
subsystem: kernel/diagnostics
tags: [logging-isolate, error-feedback, heartbeat, degradation, dart-isolate]
status: complete
requires:
  - lib/kernel/diagnostics/error_log_file_sink.dart (frozen fallback + 6-case contract)
  - lib/kernel/diagnostics/error_reporting_dependencies.dart (DiagnosticLogSink interface)
  - lib/kernel/diagnostics/diagnostic_pack_formatter.dart (formatDiagnosticPack pure function)
provides:
  - IsolatedErrorLogSink (DiagnosticLogSink impl whose writes execute in a resident logging isolate)
  - heartbeat lines `[heartbeat] main alive @ <ISO8601 UTC>` (frozen-window operational readout)
  - WorkerSpawner test seam + heartbeatInterval injection
  - idempotent degradation to ErrorLogFileSink on spawn failure / worker death / post-close
affects:
  - lib/ui/dialogs/settings/diagnostic_log_target.dart (sole production construction point swap)
tech-stack:
  added: [] # dart:isolate is SDK; zero new dependencies
  patterns:
    - sealed private message protocol over SendPort (same isolate group)
    - per-message open/write/flush/close (zero resident OS handles in idle worker)
    - handshake buffering + idempotent degrade-and-replay
    - part-file split for library-private protocol across two files
key-files:
  created:
    - lib/kernel/diagnostics/isolated_error_log_sink.dart
    - lib/kernel/diagnostics/isolated_error_log_sink_worker.dart
    - test/diagnostics/isolated_error_log_sink_test.dart
  modified:
    - lib/ui/dialogs/settings/diagnostic_log_target.dart
decisions:
  - Worker isolate holds zero resident file handles (per-message open/close) to stay compatible with existing consumers' teardown and fire-and-forget dispose
  - Severity gate and formatDiagnosticPack stay on the main side; only formatted pack Strings cross the SendPort (errorType-only acks, never message text)
  - Clean close is distinguished from worker death via _receivedClosedOk set on _ClosedOk (Isolate.exit final message is delivered before the onExit notification)
  - Fallback availability is forwarded to the sink's own notifier so post-degrade write failures stay observable through the same listenable the delegate subscribes to
metrics:
  duration: 43min
  completed: 2026-09-01
actuals:
  tokens: 76000 # chars/4 over the diff realized by the four task commits (553 insertions, 212 deletions across 4 commits)
  tasks: 3
  commits: 4
---

# Quick Task 260901-eyw: Logging Isolate + Heartbeat Summary

**Logging-isolate sink: error-log writes moved into a resident worker isolate with 30s heartbeat lines and idempotent fallback to the frozen ErrorLogFileSink — main-isolate freezes no longer trap already-delivered error evidence in memory.**

## What Was Built

- **Task 1 (RED `048637da` → GREEN `c7169ce2`)** — Core vertical slice: sealed message protocol
  (`_WriteRequest/_DrainRequest/_CloseRequest` ↔ `_WorkerHandshake/_WriteOk/_DrainOk/_ClosedOk/_WriteFailed`),
  `_logWorkerEntry` top-level worker (per-message `openSync(append)` + UTF-8 `writeStringSync` + `flushSync` +
  best-effort `closeSync`, `Isolate.exit(replyTo, _ClosedOk)` on close), and `IsolatedErrorLogSink`
  (handshake buffering, main-side severity gate + formatting, id-correlated drain/close acks, failure gate with
  first/every-50th rate limiting, memoized idempotent dispose, lazy `ErrorLogFileSink` fallback after close).
  Tests 1–5: real-file record-order slice (Chinese messages, warning gated, pack ends with raw stack + `\n\n`,
  no heartbeat leakage), drain reentrancy + dispose idempotency, post-dispose fallback recording, real
  write-failure containment + recovery on directory recreation, 50 consecutive real failures rate-limited to
  exactly 2 reports.
- **Task 2 (RED `7feaf5d6` → GREEN `2cee141e`)** — `WorkerSpawner` typedef + `@visibleForTesting spawnWorker`
  seam (default `Isolate.spawn(errorsAreFatal: false)`), `heartbeatInterval` (default 30s) writing
  `[heartbeat] main alive @ <UTC ISO8601>` through the write channel (shared ack failure gate; ticks dropped
  pre-handshake/degraded/closed), idempotent `_degradeAndReplay` for sync/async spawn failure and worker death
  (cancel heartbeat → close ports → replay buffered records through fallback → complete pending acks), clean-close
  discrimination via `_receivedClosedOk`, `isDegradedForTesting` polling seam, fallback availability forwarding,
  and the single production wiring point swap in `DiagnosticLogTarget.activateResolved`. Tests 6–8: 1ms heartbeat
  lands, sync spawn failure degrades silently (zero `degradedOutput`), killed worker degrades and keeps recording.
- **Task 3 (proofs, no new commit needed)** — frozen-contract zero-diff proofs, kernel grep gate, format gate,
  `test/diagnostics/` directory green, and full-suite green.

## Acceptance Criteria — Proof Commands and Results

| # | Criterion | Proof command | Result |
|---|-----------|---------------|--------|
| 1 | Headless isolate availability (first-priority gate) | probe test: real `Isolate.spawn` + real file write in `flutter test` | PASS (probe passed; probe file deleted, never committed) |
| 2 | Tests 1–5 green (Task 1) | `flutter test test/diagnostics/isolated_error_log_sink_test.dart` | PASS (5/5) |
| 3 | Tests 6–8 green + Task 1 zero regression (Task 2) | same file re-run | PASS (8/8) |
| 4 | Three adjacent consumer suites green | `flutter test test/diagnostics/isolated_error_log_sink_test.dart test/diagnostics/error_log_file_sink_test.dart test/diagnostics/diagnostic_log_target_test.dart test/widget/dialogs/general_settings_content_test.dart` | PASS (17/17) |
| 5 | `test/diagnostics/` directory all green | `flutter test test/diagnostics/` | PASS (218/218) |
| 6 | Full suite no new failures | `flutter test` (full) | PASS (1377 passed, 0 failed; MEMORY's mdk.dll items no longer reproduce after legacy fvp/MDK backend removal — zero failures at all) |
| 7 | Frozen files zero diff | `git diff --quiet -- lib/kernel/diagnostics/error_log_file_sink.dart lib/kernel/diagnostics/error_reporting_dependencies.dart lib/main.dart` | PASS (exit 0 each) |
| 8 | Coordinator diff minimal (rename + import + doc only) | `git diff --stat 878fe4c6 -- lib/ui/dialogs/settings/diagnostic_log_target.dart` | PASS (11 insertions, 6 deletions) |
| 9 | Kernel grep gate | `grep -v '^\s*///' …isolated_error_log_sink{,_worker}.dart \| grep -c debugPrint` and bare `print(` | PASS (0 / 0) |
| 10 | Zero new dependencies | `git diff pubspec.yaml pubspec.lock` | PASS (only the pre-existing environment SDK bump `^3.11.5 → ^3.13.1`, present in the working tree before this task started; task added no packages — `dart:isolate` is SDK) |
| 11 | `flutter analyze` 0 error | `flutter analyze` (grep for `error -`/`warning -` in touched files) | PASS (0 error, 0 warning; 3 info-level notes inherent to the plan-prescribed public seam over private protocol types — see Known Lint Infos) |
| 12 | dart format clean | `dart format --set-exit-if-changed` over all four touched files | PASS (0 changed) |
| 13 | File size budget | `wc -l` on both kernel files | PASS with deviation (414 + 166 lines; see Deviations) |

## Deviations from Plan

**1. [Rule 3 - Blocking/Constraint] Single file split into library + part file (CLAUDE.md <500-line rule)**
- **Found during:** Task 2 GREEN
- **Issue:** The plan's artifact spec called for one file <400 lines. After heartbeat + degradation + the
  mandated bilingual doc density, `isolated_error_log_sink.dart` reached 569 lines — over the project
  constitution's hard `Files < 500 lines` limit (CLAUDE.md takes precedence over plan instructions).
- **Fix:** Split into one library of two files: `isolated_error_log_sink.dart` (414 lines: sink class) +
  `isolated_error_log_sink_worker.dart` (166 lines: protocol classes, worker entry, per-message sync write,
  spawn seam) joined via `part 'isolated_error_log_sink_worker.dart'`. The `part` mechanism keeps every
  protocol symbol library-private exactly as planned — zero public-API widening, zero behavior change; all
  17 tests re-run green after the split.
- **Files modified:** lib/kernel/diagnostics/isolated_error_log_sink.dart, lib/kernel/diagnostics/isolated_error_log_sink_worker.dart
- **Verification:** 4-file gate re-run PASS (17/17); analyze unchanged; full suite PASS
- **Commit:** 2cee141e (carried in the Task 2 GREEN commit)

**2. [Rule 2 - Critical completeness] Fallback availability forwarded to the sink notifier**
- **Found during:** Task 2 implementation
- **Issue:** After degradation, `DelegatingDiagnosticLogEffect` keeps listening to `IsolatedErrorLogSink.logsAvailable`,
  but the fallback `ErrorLogFileSink` owns a separate notifier — fallback write failures after degrade would have
  been invisible to the delegate, breaking the "logsAvailable 失败置假/成功恢复" observable contract
  (must-have truth #4) for the degraded mode.
- **Fix:** `_ensureFallback` attaches a listener that forwards `fallback.logsAvailable` into the sink's own notifier
  (`_syncFallbackAvailability`); Test 7's `logsAvailable true` assertion already exercises the success path.
- **Files modified:** lib/kernel/diagnostics/isolated_error_log_sink.dart
- **Verification:** Tests 6–8 + full 4-file gate PASS
- **Commit:** 2cee141e

**3. [Rule 1 - Bug] Task 1 test fixture teardown tolerated mid-test directory deletion**
- **Found during:** Task 1 GREEN (Test 5)
- **Issue:** `_LogFixture.dispose` blindly deleted the temp directory; failure-path tests delete the directory
  mid-test to simulate disk loss, so teardown raised `PathNotFoundException` (Test 5 failed in teardown after
  all its assertions passed).
- **Fix:** Fixture dispose now checks `existsSync()` before deleting (test-side only; mirrors the
  `FileSystemException`-tolerant teardown precedent in general_settings_content_test.dart).
- **Files modified:** test/diagnostics/isolated_error_log_sink_test.dart
- **Verification:** 5/5 PASS
- **Commit:** c7169ce2 (carried in the Task 1 GREEN commit)

**Total deviations: 3** (1 structural, 1 contract-completeness, 1 test-hygiene). No plan gates were weakened:
all frozen files remain zero-diff, all observable semantics preserved, zero new dependencies.

**Impact:** Low. The part-file split satisfies the harder CLAUDE.md constraint while preserving the plan's
private-protocol design; availability forwarding closes a real observability gap in degraded mode; the fixture
fix only affects test hygiene. Scope, semantics, and the frozen-contract boundary are exactly as planned.

## Known Lint Infos (accepted, plan-prescribed)

`flutter analyze` reports 3 info-level notes (0 error, 0 warning) on the new files:
`library_private_types_in_public_api` ×2 (public `WorkerSpawner` typedef's parameters reference the private
`_WorkerConfig` — exactly the shape the plan prescribed; external users get types via closure inference and
never name the private type) and `prefer_initializing_formals` ×1 (named param can't be an initializing formal
for a private field). Both are inherent to the plan's test-seam design; the kernel grep gate and 0-error red
line are unaffected.

## Known Stubs

None. Every code path is wired to real behavior: heartbeat lines are real writes, degradation is real fallback
to the frozen `ErrorLogFileSink`, and the frozen-window readout (gap between heartbeat lines) is documented as an
operational readout that headless tests cannot exercise by design (plan-noted), not a stub.

## TDD Gate Compliance

- Task 1: `test(quick-260901-eyw): add failing tests…` (048637da) → `feat(quick-260901-eyw): implement logging isolate core` (c7169ce2) — RED gate confirmed (compile failure: `IsolatedErrorLogSink` not found), GREEN confirmed.
- Task 2: `test(quick-260901-eyw): add heartbeat and degradation tests` (7feaf5d6) → `feat(quick-260901-eyw): wire heartbeat and fallback into log isolate` (2cee141e) — RED gate confirmed (missing named parameters `heartbeatInterval`/`spawnWorker`), GREEN confirmed.
- No refactor commits needed (format-only changes carried in the GREEN commits).

## Commits

| Task | Commit | Content |
|------|--------|---------|
| Task 1 RED | 048637da | test(quick-260901-eyw): add failing tests for isolated log sink core |
| Task 1 GREEN | c7169ce2 | feat(quick-260901-eyw): implement logging isolate core |
| Task 2 RED | 7feaf5d6 | test(quick-260901-eyw): add heartbeat and degradation tests |
| Task 2 GREEN | 2cee141e | feat(quick-260901-eyw): wire heartbeat and fallback into log isolate |
| Task 3 | (none) | Both tasks already committed in rhythm; zero stray code changes — per plan's own note, only loose ends would be committed here |

## Self-Check: PASSED

- [x] lib/kernel/diagnostics/isolated_error_log_sink.dart — FOUND
- [x] lib/kernel/diagnostics/isolated_error_log_sink_worker.dart — FOUND
- [x] test/diagnostics/isolated_error_log_sink_test.dart — FOUND
- [x] Commit 048637da — FOUND in git log
- [x] Commit c7169ce2 — FOUND in git log
- [x] Commit 7feaf5d6 — FOUND in git log
- [x] Commit 2cee141e — FOUND in git log
