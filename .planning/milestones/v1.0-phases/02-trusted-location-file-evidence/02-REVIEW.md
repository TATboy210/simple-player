---
status: findings
phase: 02-trusted-location-file-evidence
depth: standard
files_reviewed: 18
critical: 2
warning: 1
info: 0
total: 3
---

# Phase 02 Code Review Report

Reviewer: gsd-code-reviewer (standard depth) · 2026-08-30

### BL-1 — BLOCKER: Errors captured before log activation are permanently omitted from durable evidence

**File:** `lib/kernel/diagnostics/error_reporting_dependencies.dart:97-99`, `lib/main.dart:46`

The global hooks are installed and diagnostic-log activation is deliberately launched without awaiting it. During the resulting interval, `DelegatingDiagnosticLogEffect.record()` silently drops every accepted report because `_sink` is null. The reports remain in the UI FIFO, but they are never replayed after `activate()` assigns a sink.

This loses precisely the startup/path-provider failures the hooks-first ordering is intended to capture, violating the durable "error → log file" evidence path.

**Fix:** Buffer accepted reports in the delegate while unresolved (with an explicit bound), then flush that buffer to the sink in original order during activation. Serialize activation and subsequent records so newly arriving reports cannot overtake buffered reports. Alternatively, make durable logging ready before proceeding with failure-prone startup work.

### BL-2 — BLOCKER: Production source excerpts degrade to absent for normal package-based Flutter stack frames

**File:** `lib/kernel/diagnostics/source_line_reader.dart:87-92`, `lib/kernel/diagnostics/source_line_reader.dart:176-200`

`SourceLineReader()` obtains its trusted root from `StackTrace.current`, but `_captureTrustedRoot()` accepts only frames whose `packageScheme == 'file'` (line 188). Normal Flutter/Dart debug stack frames are commonly `package:simple_player_flutter/...`; this is also the source identity accepted by `extractErrorLocation()`. When all diagnostic-module frames are package URIs, no root is captured, `_trustedRoot` remains null, and `read()` always returns null at lines 119-122.

Consequently, valid trusted project locations are formatted without the requested source-line evidence in the ordinary debug/profile execution path. The tests only exercise the explicit `forTesting(trustedRoot: ...)` seam and therefore do not validate production root establishment.

**Fix:** Establish the root through a verified package-to-file resolution mechanism owned by the application (for example, resolve the known diagnostics package URI during bootstrap and canonicalize it), then pass the validated root into the reader. Retain the existing canonical containment checks and no-cwd/no-executable fallback policy. Add an integration test covering production-style `package:` frames and asserting source lines are emitted.

### WR-1 — WARNING: Re-activating the diagnostic delegate leaks the old sink and leaves its listener attached

**File:** `lib/kernel/diagnostics/error_reporting_dependencies.dart:102-110`

`activate()` overwrites `_sink` unconditionally, without removing `_syncAvailability` from the prior sink or draining/disposing the old writer. A retry, reconfiguration, or repeated activation can leave the previous sink writing in the background and retain the delegate through its listener. The visible `logPath` and availability then describe only the replacement sink, making the durable-output state inconsistent.

**Fix:** Make activation one-shot and safely reject/contain repeated calls, or make activation asynchronous and atomically detach, drain, and dispose the previous sink before assigning the replacement. Add a test covering repeated activation.

---

## Validation Performed

- `flutter test test/diagnostics --reporter compact` — 178 tests passed
- `flutter analyze` — 0 errors, 59 info-level style findings (pre-existing)
- `git diff --check` — no whitespace errors
