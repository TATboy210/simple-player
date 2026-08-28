---
phase: 01-unified-capture-contract
reviewed: 2026-08-28T21:30:00+08:00
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
  critical: 0
  warning: 2
  info: 0
  total: 4
status: findings
---

# Phase 01: Code Review Report (post gap-closure re-review)

_Reviewed: 2026-08-28T21:30:00+08:00_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

## Summary

Re-review after the 01-03 gap-closure plan (PlayerError bridge production reachability, diagnostic redaction, rollback-safe dedupe). The prior review's CR-01 (fourth source unreachable) and CR-02 (raw path disclosure) are resolved: the bridge is wired through `PlayerServices`, and paths are redacted before queue/fan-out. Validation performed by the reviewer: `flutter analyze` on the eight production files passed; targeted diagnostics + PlayerServices tests (32) passed. This round surfaced two residual/new blockers and two warnings.

## Blockers

### BL-01: Path redaction leaks directory components when a local path contains whitespace

**Classification:** **BLOCKER**
**File:** `lib/kernel/diagnostics/diagnostic_redactor.dart:32-39`
**Issue:** The embedded Windows and POSIX path regexes terminate at whitespace. The remainder of a path is left untouched, despite the documented contract that redaction retains only the filename. For example, redacting `Unable to open C:\Users\alice\Private Videos\incident.mp4` produces text equivalent to `Unable to open Private Videos\incident.mp4` — the user-name prefix is removed, but sensitive directory names remain in the error message and stack snapshot. The same flaw affects POSIX paths such as `/home/alice/Private Videos/incident.mp4`. Those snapshots are intended for cards and future logs, turning a diagnostic failure into local filesystem metadata disclosure.

**Fix:** Replace whitespace-delimited regex matching with a path-token parser that handles quoted paths and spaces, or expand the match through known diagnostic delimiters while preserving the whole path token before passing it to `_basename`. Add regression cases for Windows and POSIX paths containing spaces, parentheses, and bracket characters; assert that only `incident.mp4` remains.

### BL-02: Dedupe merges errors with different severities and media targets, hiding fatal errors

**Classification:** **BLOCKER**
**File:** `lib/kernel/diagnostics/error_reporter.dart:268-283,316-318`
**Issue:** `_fingerprint` consists only of source, runtime type, message, and top stack frame. It excludes `severity`, any structured `PlayerError` code, and `mediaPath`. Consequently, two `PlayerError`s of the same subtype and message at the same source line are merged even if one is recoverable and the other is fatal, or if they concern different media. `_accept` preserves the first report's immutable severity and path, so a subsequent fatal event can be presented and persisted as the earlier non-fatal event. A concrete collision is possible between differently coded `FileError` or `PlaybackError` instances that share a message and callback frame. The later report increments `occurrenceCount` but loses its fatal classification and media association.

**Fix:** Include all semantic identity fields in the dedupe key. At minimum include `severity` and sanitized `mediaPath`; preferably add an explicit structured error-code/discriminator field to `ErrorReport` and include it in `_fingerprint`. Add tests proving that (1) recoverable and fatal errors with otherwise identical text/frame remain separate; (2) identical errors for different media paths remain separate.

## Warnings

### WR-01: Bridge silently drops player diagnostics if metadata lookup or reporter intake throws

**Classification:** **WARNING**
**File:** `lib/kernel/diagnostics/player_error_report_bridge.dart:53-60`
**Issue:** `_reportSafely` catches every `Object` and silently discards it. In particular, if `currentMediaPath()` throws, the bridge never calls the reporter with a null fallback path. This violates the unified-capture goal: a failure in optional diagnostic metadata prevents the underlying player error from being captured at all. The empty handler also conflicts with the project convention requiring an explicit logged or terminal fallback for caught errors.

**Fix:** Isolate path lookup from report submission. If path lookup fails, call `reportPlayerError(error)` without `mediaPath`; if reporter submission itself fails, send the failure to an injected non-recursive `LastResortOutput`:

```dart
String? mediaPath;
try {
  mediaPath = error.context?.path ?? _currentMediaPath();
} on Object catch (failure, stackTrace) {
  _lastResortOutput(failure, stackTrace);
}
_reporter.reportPlayerError(error, mediaPath: mediaPath);
```

Add a bridge test where `currentMediaPath` throws and verify the player error still reaches the reporter.

### WR-02: Redactor modifies valid network URLs containing a drive-like path segment

**Classification:** **WARNING**
**File:** `lib/kernel/diagnostics/diagnostic_redactor.dart:32-35`
**Issue:** The Windows-path regex can match a valid remote URL path segment when it resembles `C:/...`. For example, `https://example.test/C:/streams/camera.m3u8` is transformed because the `C:/streams/...` suffix satisfies the Windows-path expression. This contradicts the stated contract that network URLs remain untouched and removes useful source information from stream failures.

**Fix:** Detect and preserve URI spans before scanning local filesystem paths, or require a non-URI context before applying Windows-drive redaction. Add test coverage for `http`, `https`, `rtsp`, and `rtmp` URLs whose path contains `X:/`.

---

## Prior-Round Findings Status (resolved by 01-03)

| Prior ID | Title | Status |
|----------|-------|--------|
| CR-01 | Player-engine failures never enter the unified reporter | ✅ Resolved — bridge wired via PlayerServices (01-03) |
| CR-02 | Error reports retain and expose full user filesystem paths | ⚠️ Mostly resolved — redaction added, but BL-01 (whitespace paths) and WR-02 (URLs) are residual gaps |
| WR-01 (old) | Clock rollback makes 10-second dedupe window unbounded backward | ✅ Resolved — rollback rejected (01-03); BL-02 is a distinct dedupe identity gap |
