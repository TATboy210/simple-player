---
phase: 01
reviewed: 2026-08-28T15:21:22Z
depth: standard
files_reviewed: 13
files_reviewed_list:
  - lib/kernel/diagnostics/diagnostic_redactor.dart
  - lib/kernel/diagnostics/error_report.dart
  - lib/kernel/diagnostics/error_reporter.dart
  - lib/kernel/diagnostics/error_reporting_dependencies.dart
  - lib/kernel/diagnostics/global_error_hooks.dart
  - lib/kernel/diagnostics/player_error_report_bridge.dart
  - lib/kernel/player_services.dart
  - lib/main.dart
  - test/diagnostics/error_report_test.dart
  - test/diagnostics/error_reporter_test.dart
  - test/diagnostics/global_error_hooks_test.dart
  - test/diagnostics/player_error_report_bridge_test.dart
  - test/kernel/player_services_test.dart
findings:
  blocker: 2
  warning: 2
  info: 0
  total: 4
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-08-28T15:21:22Z
**Depth:** standard
**Files Reviewed:** 13
**Status:** issues_found

## Summary

The unified error capture and reporting pipeline was reviewed at standard depth, including global hooks, report construction and deduplication, path redaction, player-error bridging, service lifecycle integration, and their focused tests. Two defects break the promised semantic deduplication contract, and two error-containment paths silently discard diagnostic failures or catch programming errors too broadly.

## Critical Issues

### BL-01: Deduplication selects the oldest matching report, not a match within the dedupe window

**File:** `lib/kernel/diagnostics/error_reporter.dart:274-289,297-304`

**Issue:** `_findMatchingIndex` returns the first same-fingerprint report in FIFO order. When the same failure has already recurred outside the 10-second window, the queue can contain multiple matching reports. A later recurrence within 10 seconds of the newest one is compared only to the oldest one; its elapsed time exceeds the window, so the new report is appended rather than merged.

Example timeline: identical failures at `t=0` and `t=11` produce two queue items. At `t=15`, the new failure should merge into the `t=11` item, but the code compares it with `t=0` and adds a third item.

This violates the stated 0–10 second semantic-dedupe contract and causes duplicate-storm counts to fragment once a failure recurs over time.

**Fix:** Search matching reports from newest to oldest and select the first match whose `lastOccurredAt` is not in the future and is within `_dedupeWindow`; alternatively, include the time-window test in the search predicate. Add a regression test for occurrences at 0s, 11s, and 15s.

### BL-02: Delimiter-concatenated fingerprints can collide across different report fields

**File:** `lib/kernel/diagnostics/error_reporter.dart:321-324`

**Issue:** `_fingerprint` uses unescaped `|` delimiters between attacker-/runtime-controlled text fields (`message`, `mediaPath`, stack frame). Different reports can therefore serialize to the same fingerprint if a field contains `|`.

For example, reports with the same fixed fields and top frame can collide when one has `message: 'open failed|segment'` and `mediaPath: 'clip.mp4'`, while another has `message: 'open failed'` and `mediaPath: 'segment|clip.mp4'`. Remote media URLs and error text can legally contain this character. The second report will be merged into the first despite representing distinct diagnostic evidence.

This directly defeats the phase requirement that only a full semantic match may merge reports.

**Fix:** Replace the string serialization with a typed immutable equality key, such as a private record containing the individual fields, or compare all fingerprint fields directly. Do not use delimiter-based serialization unless every component is unambiguously length-prefixed or escaped. Add collision regression tests using `|` in message and media-path values.

## Warnings

### WR-01: The bridge silently discards reporter failures without invoking a terminal fallback

**File:** `lib/kernel/diagnostics/player_error_report_bridge.dart:53-61`

**Issue:** `_reportSafely` catches all `Object` failures from `_reporter.reportPlayerError` and intentionally does nothing. Although the production reporter currently contains its own fallback handling, the bridge accepts the `ErrorReporter` interface and can be given another implementation. A failing reporter implementation then drops player diagnostics completely and leaves no terminal trace, contrary to the project rule against silent error swallowing.

**Fix:** Inject or use a non-recursive `LastResortOutput` at this boundary and invoke it with the caught error and stack trace. Narrow the catch to expected recoverable failures where possible; do not silently catch programming `Error` subtypes.

### WR-02: Service initialization uses a bare catch and catches programming errors during cleanup

**File:** `lib/kernel/player_services.dart:163-171`

**Issue:** `catch (_)` catches every `Object`, including `Error` subclasses, without retaining the failure or stack trace locally. This violates the project convention requiring typed error handling and avoiding catches of programming errors. While `rethrow` preserves propagation, cleanup operations can obscure diagnostics if a cleanup path itself fails, and the bare catch makes the intended boundary unclear.

**Fix:** Use `on Exception catch (error, stackTrace)` for expected initialization failures, log the cleanup context through `KernelLogger`, and let programming `Error`s propagate unless there is a documented reason to contain them.

## Verification Performed

- Read all 13 required source and test files.
- Traced the player-error path across `MediaKitEngine`/`PlaybackController` → `PlayerErrorReportBridge` → `ErrorReporterImpl`.
- Ran focused diagnostics and lifecycle tests successfully:

```text
flutter test test/diagnostics/error_reporter_test.dart test/diagnostics/global_error_hooks_test.dart test/diagnostics/player_error_report_bridge_test.dart test/kernel/player_services_test.dart
```

---

_Reviewed: 2026-08-28T15:21:22Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
