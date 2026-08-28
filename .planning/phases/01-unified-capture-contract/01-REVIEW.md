---
phase: 01-unified-capture-contract
reviewed: 2026-08-28T00:00:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - lib/kernel/diagnostics/error_report.dart
  - lib/kernel/diagnostics/error_reporter.dart
  - lib/kernel/diagnostics/error_reporting_dependencies.dart
  - lib/kernel/diagnostics/global_error_hooks.dart
  - lib/kernel/player_services.dart
  - lib/main.dart
  - test/diagnostics/error_report_test.dart
  - test/diagnostics/error_reporter_test.dart
  - test/diagnostics/global_error_hooks_test.dart
findings:
  critical: 2
  warning: 1
  info: 0
  total: 3
status: findings
---

# Phase 01: Code Review Report

**Reviewed:** 2026-08-28T00:00:00Z  
**Depth:** standard  
**Files Reviewed:** 9  
**Status:** findings

## Summary

The global Flutter and platform-dispatcher adapters are wired and the focused diagnostic tests pass, but the submitted integration does not connect player-engine failures to the new reporter. In addition, the report contract preserves full media paths and arbitrary error/path content for future effects, violating the stated diagnostic-path redaction requirement. A wall-clock rollback can also make the deduplication window merge occurrences that are not temporally adjacent.

Verification performed: `flutter analyze` on all nine scoped files and the three focused diagnostic test files passed; `flutter test test/diagnostics/error_report_test.dart test/diagnostics/error_reporter_test.dart test/diagnostics/global_error_hooks_test.dart` passed (20 tests).

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Player-engine failures never enter the unified reporter

**Classification:** **BLOCKER**  
**File:** `D:/simple_player_flutter/lib/kernel/player_services.dart:132`  
**Related paths:** `D:/simple_player_flutter/lib/kernel/services/playback_controller.dart:157-159`, `D:/simple_player_flutter/lib/kernel/engine/media_kit_engine.dart:168-176`, `D:/simple_player_flutter/lib/kernel/engine/media_kit_engine.dart:591-597`  
**Issue:** `PlayerServices` constructs `PlaybackController(engine: engine)` without its optional `onError` callback. The only controller paths that forward a `PlayerError` are consequently no-ops. Separately, engine failures emitted through `lastError` (including `_player.stream.error`) have no listener anywhere in the application that calls `reportPlayerError`. Repository-wide call-site review shows that `reportPlayerError` has no production caller. Thus the claimed fourth capture boundary, `ErrorSource.playerEngine`, is unreachable in the shipped application; playback errors remain limited to the legacy engine/UI notifier and never reach the FIFO, effects, or future persisted/card presentation.

**Fix:** Inject the reporter at the service composition boundary and establish exactly one engine-error bridge, with deduplication ownership remaining in `ErrorReporterImpl`. For example, pass `onError: (error) => ErrorReporterImpl.I.reportPlayerError(error, mediaPath: controller.currentPath.value)` when constructing the controller, and subscribe once to `engine.lastError` for asynchronous engine-stream errors (removing that listener during disposal). Alternatively, make `PlaybackController` own the single subscription and inject the narrow `ErrorReporter` interface. Add integration tests that prove an `OpenError`, a validation error, and an asynchronous `lastError` update each produce a `playerEngine` report exactly once.

### CR-02: Error reports retain and expose full user filesystem paths

**Classification:** **BLOCKER**  
**File:** `D:/simple_player_flutter/lib/kernel/diagnostics/error_reporter.dart:245-260`  
**Related paths:** `D:/simple_player_flutter/lib/kernel/diagnostics/error_reporter.dart:328-342`, `D:/simple_player_flutter/lib/kernel/diagnostics/error_report.dart:75-76`  
**Issue:** The reporter copies `mediaPathOverride`, `ErrorContext.path`, and the current-media-path provider verbatim into `ErrorReport.mediaPath`. It also accepts arbitrary `error.toString()`/`PlayerError.message` and raw stack text without path redaction. These values are subsequently handed to every `ErrorReportEffect`, which is the planned logging/persistence path, and will be displayed by the planned card host. A Windows absolute media path commonly discloses the account name and directory structure. This contradicts the phase's explicit security requirement that diagnostics not leak sensitive paths and the project convention that diagnostic paths are redacted. Length bounding limits volume, not disclosure.

**Fix:** Normalize all diagnostic text before constructing the report. Store only a basename (or a dedicated redacted path token) for `mediaPath`, and redact Windows, POSIX, URI, message, and stack-trace path forms before queuing or invoking effects. Reuse or extend the project redaction utility so a single, tested policy applies. Add tests with `C:\\Users\\Alice\\Videos\\secret.mp4`, UNC paths, `file:///C:/Users/Alice/...`, and error messages/stacks containing those values; assert that neither the queue snapshot nor a captured effect receives `Alice` or the directory prefix.

## Warnings

### WR-01: Clock rollback makes the 10-second dedupe window unbounded backward in time

**Classification:** **WARNING**  
**File:** `D:/simple_player_flutter/lib/kernel/diagnostics/error_reporter.dart:268-275`  
**Issue:** The comparison only checks whether `candidate.lastOccurredAt.difference(existing.lastOccurredAt) <= _dedupeWindow`. `SystemClock` is wall-clock based and can move backward following NTP correction or a user clock change. Any negative duration satisfies this condition, so an identical error observed minutes or hours later can be merged into an old FIFO entry rather than appended as a new incident. This incorrectly suppresses a recurrence and preserves an obsolete queue position.

**Fix:** Require a non-negative elapsed duration before merging, or use a monotonic elapsed-time source for dedupe policy:

```dart
final elapsed = candidate.lastOccurredAt.difference(existing.lastOccurredAt);
if (elapsed >= Duration.zero && elapsed <= _dedupeWindow) {
  // merge
}
```

Add a `FakeClock` regression test that moves backward by more than ten seconds and verifies a second FIFO report is appended rather than merged.

---

_Reviewed: 2026-08-28T00:00:00Z_  
_Reviewer: Claude (gsd-code-reviewer)_  
_Depth: standard_
