---
phase: 05-e2e-resilience-verification
reviewed: 2026-09-01T00:00:00Z
depth: quick
files_reviewed: 3
files_reviewed_list:
  - test/diagnostics/end_to_end_injection_test.dart
  - test/diagnostics/burst_resilience_test.dart
  - docs/error-diagnostics-limitations.md
findings:
  critical: 0
  warning: 1
  info: 4
  total: 5
status: issues_found
---

# Phase 05: Code Review Report

**Reviewed:** 2026-09-01
**Depth:** quick
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Reviewed the phase's two test suites and the developer-facing limitations doc at quick depth, spot-checking every production symbol they assert against (`ErrorReporterImpl`, `ErrorLogFileSink`, `IsolatedErrorLogSink`/worker, `DelegatingDiagnosticLogEffect`, `ErrorCardHost`, `GlobalErrorHooks`, `BootstrapErrorFallback`, `ErrorCaptureSnapshot`, `buildErrorCardMount`, `ErrorLogLocation`, `SourceLineReader`).

The test suites are high quality. The four-source e2e injection genuinely routes through production entry points (the `BootstrapErrorFallback.report` static is the same function used at `main.dart:119`; `GlobalErrorHooks.forTesting` installs the real `_handleFramework`/`_handlePlatform` closures via captured seams without polluting process globals), and the three-piece assertion (exactly one new report with `occurrenceCount == 1`, one file record anchored by real-I/O polling, one visible card) is sound. The burst suite's design-value口径 matches the implementation: FIFO `_maxQueueLength = 5` (`error_reporter.dart:47`), dedupe window 10s, mixed-burst math checks out (900 distinct + 100 dup → queue exactly 5, merged `occurrenceCount == 100`, `burst-000`/`burst-100` valid eviction samples). The close-failure test's assertions are internally consistent: a throwing `presentation` listener is contained by Flutter's `ChangeNotifier.notifyListeners`, which routes listener exceptions to `FlutterError.reportError` (`change_notifier.dart:436-438`), so `listenerFailures` is non-empty while the reporter chain's `lastResort` stays empty. All precedent test names cited in the docstrings exist (`error_reporter_test.dart:156/291/743`, `error_card_test.dart:746`).

The doc is accurate on the isolate write semantics (worker does append-open → UTF-8 → flush per pack, `isolated_error_log_sink_worker.dart:116-138`), the 30s heartbeat default (`isolated_error_log_sink.dart:49`), the once-guard degrade sequence (`_degradeAndReplay`, lines 264-291), the exe-root → Application Support fallback chain, and the release source-line degradation (`source_line_reader.dart:218-222`). One concrete technical instruction is wrong: the WER per-app registry key names an exe that does not exist (WR-01 below), which would silently defeat the zero-code native-crash fallback the section exists to provide.

## Warnings

### WR-01: WER per-app registry key names the wrong executable

**File:** `docs/error-diagnostics-limitations.md:111` (also line 128)

**Issue:** §4 instructs creating the per-app LocalDumps key `HKLM\...\LocalDumps\simple_player.exe`, and the reading step looks for `simple_player.exe.<pid>.dmp`. The built binary is `simple_player_flutter.exe` (`windows/CMakeLists.txt:7` `set(BINARY_NAME "simple_player_flutter")`), and nothing renames it for distribution (`pubspec.yaml:73-77` msix_config sets only display/identity names; `distribute_options.yaml` sets no executable name). WER per-app LocalDumps subkeys must match the executable file name exactly — following the doc verbatim creates a key that never applies, and native crashes then produce no dumps with no error surfaced anywhere. For a section whose entire purpose is the zero-code native-crash fallback, the failure mode is silent loss of the diagnostic evidence it promises.

**Fix:** Correct the key and the dump filename in both places:

```
HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps\simple_player_flutter.exe
```

and in the reading step: `simple_player_flutter.exe.<pid>.dmp`. (Optional hardening: add a one-line note that the key must match the actual exe file name from `BINARY_NAME`, so a future rename doesn't silently re-break this.)

## Info

### IN-01: Hardcoded zh badge literal couples four assertions to ARB wording

**File:** `test/diagnostics/end_to_end_injection_test.dart:142`

**Issue:** `expectCardVisible` asserts `find.text('1 错误')` — the rendered output of `l10n.errorCardBadgeLabel(1)` under the zh ARB (`app_zh.arb:212` `"{count} 错误"`). The same file already resolves l10n properly for the PlayerError case (lines 262-265, `l10n.errorFilePathEmpty`), so the badge assertion is an inconsistent spot of string coupling: any ARB wording change (e.g. "1 个错误") breaks all four e2e tests without any behavior change.

**Fix:** Pass the resolved label through, mirroring the existing `displayed` pattern:

```dart
void expectCardVisible(String message, {String? displayed, String? badgeLabel}) {
  expect(find.byType(ErrorCard), findsOneWidget);
  expect(find.textContaining(displayed ?? message), findsOneWidget);
  expect(find.text(badgeLabel ?? '1 错误'), findsOneWidget);
}
```

or resolve `AppLocalizations.of(context).errorCardBadgeLabel(1)` in each test. Low priority — the test is deterministic under the fixed zh locale.

### IN-02: e2e file-evidence leg bypasses the production isolate sink

**File:** `test/diagnostics/end_to_end_injection_test.dart:65`

**Issue:** The suite's header claims "四源各经真实注入入口走完整链路", but the durable-evidence leg constructs `ErrorLogFileSink` directly, while production activation is `IsolatedErrorLogSink` (`diagnostic_log_target.dart:65` via `DiagnosticLogTarget.activateResolved`). The direct sink is the documented contract-equivalent fallback (identical severity gate / append+UTF-8+flush / failure containment), so the capture chain itself is real — but the isolate boundary (handshake, pending buffer, worker protocol) is unexercised by this suite, which is fine as long as the scoping is explicit.

**Fix:** Add one sentence to the file header: "文件证据腿经 ErrorLogFileSink 直写（IsolatedErrorLogSink 的降级回退、契约逐项一致）；isolate 边界由 isolated_error_log_sink 专属套件覆盖。" No code change required.

### IN-03: Close-failure test's stated premise mischaracterizes the mechanism

**File:** `test/diagnostics/burst_resilience_test.dart:19-20` (docstring item D) and comment at lines 226-227

**Issue:** The docstring says "close-advance 触发 failing effect 不抛第二错误". By design, effects are never invoked on the dismiss path — `ErrorReportEffect` fires only for `newReport`/`merged` acceptance (`error_reporting_dependencies.dart:39-40,53`: "eviction and reentrancy suppression are not accepted captures"), and `dismissCurrent` (`error_reporter.dart:235-245`) only removes the head and re-publishes. The failing effect in this test actually fires only during the two `reportPlatformSafely` intake calls (before `lastResort.clear()`); what the close-advance leg really locks is (a) the throwing presentation listener being contained by the Flutter notifier boundary and (b) no second report entering the queue. The assertions themselves are correct and valuable — only the coverage claim is misleading, and a maintainer could conclude the dismiss path exercises effects when it cannot.

**Fix:** Reword item D and the inline comment to: "close-advance 路径验证 dismiss 推进零第二报告入队、抛错 presentation 监听被 FlutterError.onError 边界收容（effect 按契约只在 intake 接纳时触发，dismiss 不经过 effect 链）"。

### IN-04: Doc conflates the two causes of `logsAvailable == false`

**File:** `docs/error-diagnostics-limitations.md:74-77`

**Issue:** §3 presents `logsAvailable == false` as one state with one response: "写盘链已降级（磁盘 I/O 失败，once-guard：cancel 心跳 → 缓冲重放 → 放行未决 drain/dispose）". The implementation distinguishes two paths: (a) a disk I/O write failure routes through `_containWriteFailure` (`isolated_error_log_sink.dart:239-240, 344-350`) — availability goes false but the heartbeat Timer keeps running, so heartbeat lines continue; (b) worker death/spawn failure routes through the once-guard `_degradeAndReplay` (lines 264-291) — that is where heartbeat cancel → pending replay → ack release happens. A developer using this doc to debug could wrongly infer "logsAvailable=false ⇒ 心跳已停", corrupting the §3 frozen-window reading method (heartbeats stopping is specifically the worker/main-isolate-death signal, not the disk-failure signal).

**Fix:** Split the bullet: 磁盘 I/O 写失败 → `logsAvailable` 置假，心跳继续；worker 死亡/spawn 失败 → once-guard（cancel 心跳 → 缓冲重放 → 放行未决 drain/dispose），心跳停写。Both leave capture/presentation unaffected — that shared conclusion is already correct.

---

_Reviewed: 2026-09-01T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: quick_
