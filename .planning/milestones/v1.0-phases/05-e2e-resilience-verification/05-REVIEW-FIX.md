---
phase: 05-e2e-resilience-verification
fixed_at: 2026-09-01T12:56:28Z
review_path: .planning/phases/05-e2e-resilience-verification/05-REVIEW.md
iteration: 1
findings_in_scope: 5
fixed: 5
skipped: 0
status: all_fixed
---

# Phase 05: Code Review Fix Report

**Fixed at:** 2026-09-01T12:56:28Z
**Source review:** .planning/phases/05-e2e-resilience-verification/05-REVIEW.md
**Iteration:** 1
**Execution mode:** main working tree (no worktree), plain commits on master — per orchestrator directive

**Summary:**
- Findings in scope: 5 (1 warning + 4 info; 0 critical)
- Fixed: 5
- Skipped: 0

## Fixed Issues

### WR-01: WER per-app registry key names the wrong executable

**Files modified:** `docs/error-diagnostics-limitations.md`
**Commit:** 925c524f
**Applied fix:** §4 per-app LocalDumps key corrected to `...\LocalDumps\simple_player_flutter.exe` (line 111), the global-fallback bullet's sub-key name likewise (line 114), and the reading step's dump filename to `simple_player_flutter.exe.<pid>.dmp`. Added a hardening note: the sub-key must match the executable name verbatim, ground truth is `windows/CMakeLists.txt` `set(BINARY_NAME "simple_player_flutter")`, and a future rename must sync this key or WER silently produces zero dumps.

### IN-01: Hardcoded zh badge literal couples four assertions to ARB wording

**Files modified:** `test/diagnostics/end_to_end_injection_test.dart`
**Commit:** 24a5c8ee
**Applied fix:** `expectCardVisible` now resolves the badge label via `AppLocalizations.of(context).errorCardBadgeLabel(1)` (reusing the file's existing l10n-resolution pattern from the PlayerError case at :262-265) instead of the hardcoded `'1 错误'` literal. Implementation note: the helper is defined outside `testWidgets` bodies (no `tester` in scope), so the context is obtained via `find.byType(ErrorCard).evaluate().single` — same l10n contract, no signature change, all four call sites untouched. ARB wording changes no longer break the suite.

### IN-02: e2e file-evidence leg bypasses the production isolate sink

**Files modified:** `test/diagnostics/end_to_end_injection_test.dart`
**Commit:** 24a5c8ee
**Applied fix:** File header retitled from "走完整链路" to "走完整捕获→呈现链路" and a scoping paragraph added (bilingual, per doc convention): the durable-evidence leg writes via `ErrorLogFileSink` directly — the contract-equivalent degraded fallback of the production `IsolatedErrorLogSink` (same severity gate / append+UTF-8+flush / failure containment); the isolate boundary (handshake, pending buffer, worker protocol) is covered by `test/diagnostics/isolated_error_log_sink_test.dart` (verified to exist). No code change.

### IN-03: Close-failure test's stated premise mischaracterizes the mechanism

**Files modified:** `test/diagnostics/burst_resilience_test.dart`
**Commit:** 24a5c8ee
**Applied fix:** Docstring item D and the Act comment (lines 226-227) reworded to the accurate mechanism: close-advance locks (a) dismiss advancing with zero second reports enqueued and (b) the throwing presentation listener being contained by the `FlutterError.onError` boundary; effects fire by contract only on intake acceptance (`newReport`/`merged` — verified against `error_reporting_dependencies.dart:39-40,53`), so the dismiss path never traverses the effect chain. Assertions unchanged (they were already correct).

### IN-04: Doc conflates the two causes of `logsAvailable == false`

**Files modified:** `docs/error-diagnostics-limitations.md`
**Commit:** 925c524f
**Applied fix:** §3 bullet split into the two causes: disk I/O write failure → `logsAvailable` false but the heartbeat keeps running (heartbeat stoppage is not the disk-failure signal); worker death/spawn failure → once-guard (cancel heartbeat → pending replay → release drain/dispose) → heartbeats stop. Shared conclusion kept: capture/presentation unaffected in both cases. The English summary amended to match, protecting the §3 frozen-window reading method from the "logsAvailable=false ⇒ 心跳已停" misreading.

## Verification

**Where verification ran:** main working tree (`D:/simple_player_flutter`, master) — no worktree was created (execution mode directive), so all numbers below are reproducible from the current checkout.

- `dart format test/diagnostics/end_to_end_injection_test.dart test/diagnostics/burst_resilience_test.dart` — applied (formatter reflow only; project enforces dart format in CI).
- `flutter test test/diagnostics/end_to_end_injection_test.dart test/diagnostics/burst_resilience_test.dart` — **All tests passed! (+8: 4 e2e + 4 burst)**
- `flutter analyze` — **0 errors** (64 issues, all pre-existing `info` level elsewhere); grep for the three touched files in analyzer output: **zero entries**.

Commits (staged only the touched files; `.mcp.json` / `pubspec.*` / `.planning/state.json` / `.planning/agent-history.json` deliberately never staged):

1. `925c524f` — fix(05): WR-01+IN-04 correct WER exe name to simple_player_flutter.exe and split logsAvailable causes in doc
2. `24a5c8ee` — fix(05): IN-01/02/03 resolve badge label via l10n and correct e2e scoping plus close-advance effect wording in tests

---

_Fixed: 2026-09-01T12:56:28Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
