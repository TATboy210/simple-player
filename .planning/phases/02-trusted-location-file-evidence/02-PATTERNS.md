# Phase 2: 可信定位与文件证据 - Pattern Map

**Mapped:** 2026-08-30
**Files analyzed:** 7 (5 new + 2 modified)
**Analogs found:** 7 / 7

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/kernel/diagnostics/error_location.dart` | model + utility (sealed type + frame extractor) | transform (string→frames) | `lib/kernel/diagnostics/error_report.dart` (sealed/final immutable pattern) + `error_reporter.dart:_topFrame` | role-match |
| `lib/kernel/diagnostics/source_line_reader.dart` | utility (file I/O + containment) | file-I/O | `lib/kernel/services/path_validator.dart` (containment philosophy); no direct file-read analog | role-match |
| `lib/kernel/diagnostics/diagnostic_pack_formatter.dart` | utility (pure formatter) | transform | `kernel_logger.dart:serializeLogContext` (pure top-level fn) + `diagnostic_redactor.dart` (scanner) | exact (pure-fn convention) |
| `lib/kernel/diagnostics/error_log_file_sink.dart` | service (durable append + status notifier) | file-I/O, event-driven | `kernel_logger.dart` sink classes (:76-339) for interface shape; no dart:io append analog exists yet | role-match |
| `lib/kernel/diagnostics/error_log_location.dart` | config (path resolution seam) | request-response (async resolve) | `playlist_store.dart` (path_provider usage, `lib/kernel/persistence/playlist_store.dart:60`) | role-match |
| `lib/kernel/diagnostics/error_report.dart` (MODIFY) | model | transform | itself — additive optional field, mirrors `mediaPath` nullable-field shape | exact |
| `lib/kernel/diagnostics/error_reporter.dart` (MODIFY) | service | event-driven | itself — `_notifyEffects` (:410-418) is the FileSink attachment point | exact |
| `lib/main.dart` (MODIFY) | composition root | — | itself — init sequence (:35-38) is where sink/effect wiring goes | exact |

All analog paths verified git-tracked via `git ls-files`.

## Pattern Assignments

### `error_log_file_sink.dart` (service, file-I/O)

**Analog (interface shape):** `lib/kernel/diagnostics/kernel_logger.dart`

Sink classes are `final class X implements LogSink`, const-constructible when stateless, with bilingual `///` doc comments and `// ---- Section ----` dividers (lines 76-90, 210-278, 313-339):

```dart
abstract interface class LogSink {                       // :76
  void log(LogLevel level, String msg, {
    Map<String, Object?>? context, Object? error, StackTrace? stackTrace});
}
final class DebugPrintSink implements LogSink {          // :256 — precedent: debugPrint
  const DebugPrintSink();                                //   inside lib/kernel/ is tolerated
  ...
}
```

**D-08 note:** FileSink attaches to `ErrorReporterImpl` effects (not CompositeSink), so it does NOT need to implement `LogSink` — it is a `typedef ErrorReportEffect` conforming closure/class. Effect contract (`error_reporting_dependencies.dart:21-22`):

```dart
typedef ErrorReportEffect =
    void Function(ErrorReport report, ReportAcceptance acceptance);
```

**Single-writer queue (D-02, from RESEARCH Pattern 3):**

```dart
Future<void> _pending = Future<void>.value();
void enqueue(String pack) {
  _pending = _pending
      .then((_) => _file.writeAsString(pack, mode: FileMode.append,
          encoding: utf8, flush: true))
      .catchError((Object e, StackTrace st) { /* rate-limited degraded + status */ });
}
Future<void> dispose() => _pending;
```

**Error/degradation pattern:** copy the reporter's containment idiom (`error_reporter.dart:410-426`): each effect isolated in `on Object catch` → `_emitLastResort` (never re-enters diagnostics). Kernel MUST NOT use `debugPrint` unconditionally — release gate greps `debugPrint(` (`tool/audit/phase21_release_gate.sh:49`); gate a debug/profile degraded channel like `DebugPrintSink`, use `developer.log` in release (precedent: `error_reporter.dart:435-444`).

**Status notifier:** expose `ValueNotifier<bool>` for "日志不可用" — same convention as `ErrorReporterImpl.presentation` (`error_reporter.dart:95-102`): stable instance, immutable value.

### `diagnostic_pack_formatter.dart` (utility, transform)

**Analog:** `lib/kernel/diagnostics/kernel_logger.dart` `serializeLogContext` (:138-200) — pure top-level function, deterministic output, cycle/edge-case hardened with fixed fallback strings. Plus `diagnostic_redactor.dart` for the "scanner that never trusts input" style.

```dart
String serializeLogContext(Map<String, Object?> context) {   // :138
  ...
  return jsonEncode(normalized);
}
```

Formatter contract (D-04/D-07): `String formatDiagnosticPack(ErrorReport report, {String? logPath})` — pure, no I/O. Rules extracted from Phase 1 code:
- Fields copied **verbatim** — do NOT re-apply `DiagnosticRedactor` (Pitfall 5: intake already redacted at `error_reporter.dart:380-383`; raw stack contains `file:///D:/...` that re-redaction would mangle).
- D-07 override: pack shows FULL media path → the pack must use a full-path source. `ErrorReport.mediaPath` is basename-redacted at intake, so the full path must be added as a new intake-preserved field or the reporter's `mediaPathOverride ?? _currentMediaPath()` raw value must be captured separately (planner decision; CONTEXT D-07 locks the display policy, not the mechanism).
- Escape CR/LF in single-line field values so a hostile message cannot forge a `== ` segment header; raw stack confined to terminal segment.

### `error_location.dart` (model + utility, transform)

**Analog:** `lib/kernel/diagnostics/error_report.dart` — sealed/final immutable data classes, `required` constructor params, nullable optional fields, doc comments:

```dart
final class ErrorReport {
  const ErrorReport({required this.eventId, ..., this.mediaPath});  // :36-50
```

**Frame extraction (LOC-01, D-05)** — extend `error_reporter.dart:_topFrame` (:356-369), which already does the first-project-frame scan:

```dart
for (final line in lines) {
  if (line.contains('package:simple_player_flutter/')) {
    return _bounded(line, _maxFrameLength);              // :359-361
  }
}
```

Upgraded extractor must: pre-filter each `#` line with `RegExp(r'^#(\d+) +(.+) \((.+?):?(\d+){0,1}:?(\d+){0,1}\)$')` before `StackFrame.fromStackString` (malformed lines throw inside `fromStackTraceLine`'s `match!`); drop sentinel frames (`line: -1`, `<asynchronous suspension>`); match `f.package == 'simple_player_flutter'` OR `f.packageScheme == 'file'` with `packagePath` (`/D:/...` → strip leading slash); wrap whole parse in `on Object → const []`; keep ≤1 primary + 2 secondary frames; raw stack untouched.

### `source_line_reader.dart` (utility, file-I/O)

**Analog:** `lib/kernel/services/path_validator.dart` — containment/validation philosophy (extension whitelist, traversal rejection, fail-closed). No file-read analog exists; follow RESEARCH Pattern 2 (self-anchored root capture from `StackTrace.current` at init; `kReleaseMode` short-circuit before any FS work; canonicalize + reject `..` + `File.existsSync()`; any failure → null, never throw). `Isolate.resolvePackageUri` is unusable in Flutter — do not use.

### `error_log_location.dart` (config seam, request-response)

**Analog:** `lib/kernel/persistence/playlist_store.dart` — path_provider usage pattern (`getApplicationSupportDirectory()` awaited, then directory composed). Constraint: kernel must NOT await plugins at static-init; resolve in `main.dart` and inject the resolved path (composition-root pattern below). `Directory('${support.path}/logs').create(recursive: true)` is idempotent; null/MAX_PATH failure → degraded state, not exception (Pitfall 6).

### `error_report.dart` (MODIFY, model)

**Analog:** itself — additive nullable field, exactly mirroring the existing `mediaPath` pattern:

```dart
this.location,                       // add to const constructor (:38-50)
final ErrorLocation? location;       // nullable optional field, no required churn
```

Do NOT extend `copyWith` beyond what's needed — enrichment happens before queue insertion in `_createReport` (existing `copyWith` covers only `lastOccurredAt`/`occurrenceCount`, :92-106).

### `error_reporter.dart` (MODIFY, service)

**Analog:** itself — the effect fan-out is already built:

```dart
void _notifyEffects(ErrorReport report, ReportAcceptance acceptance) {  // :410
  for (final effect in _effects) {
    try {
      effect(report, acceptance);
    } on Object catch (failure, stackTrace) {
      _emitLastResort(failure, stackTrace);           // per-effect isolation
    }
  }
}
```

Effects are injected via constructor (`List<ErrorReportEffect> effects = const []`, :64/:69) — the FileSink effect is passed in from `main.dart`, not constructed inside the reporter. Location enrichment slots into `_createReport` (:240-271) before `_accept`, so dedupe identity (`_identity`, :333-343) stays stable — decide deliberately whether location participates in identity (recommend: no, keep the 7-field tuple untouched).

### `main.dart` (MODIFY, composition root)

**Analog:** itself — init sequence at :35-38 is the wiring point; sync singletons first, async plugin work after:

```dart
KernelLoggerImpl.init();                     // :35
ErrorReporterImpl.init();                    // :36 — construct with effects list here
GlobalErrorHooks.install(ErrorReporterImpl.I);  // :37
```

FileSink wiring: `await getApplicationSupportDirectory()` fits naturally inside the existing `runZonedGuarded` async body (after `:39`), construct sink with resolved path, then `ErrorReporterImpl.init()` variant or re-init accepting `effects: [fileSinkEffect]`. On resolution failure: still init the reporter, omit the effect (degraded "日志不可用" state), never crash startup — precedent is the windowInitError containment block (:52-76).

## Shared Patterns

### Containment boundary (`on Object catch` → last-resort)
**Source:** `lib/kernel/diagnostics/error_reporter.dart:410-426`
**Apply to:** FileSink effect, formatter caller, location extractor — every phase-2 entry point.

### Bilingual doc comments + section dividers
**Source:** all `lib/kernel/diagnostics/*.dart` (e.g. `kernel_logger.dart:1-21`, `error_reporter.dart:38-41`)
**Apply to:** all 5 new files. Chinese first line, English explanation; `library;` directive at file top.

### Test conventions (Wave 0)
**Source:** `test/diagnostics/error_reporter_test.dart:13-49` — AAA structure, `group`/`test`, constructor-injected fakes (`ErrorReporterImpl.forTesting`), `resetForTesting` in setup. New test files mirror lib path: `test/diagnostics/error_location_test.dart` etc. Failure injection for the sink needs an injectable writer port defined in `error_reporting_dependencies.dart` (existing typedef/seam file).

### Kernel gate compliance
- `tool/audit/kernel_logger_gate.sh` GATE 1: **never** `import 'package:logger'` under `lib/kernel/` — dart:io only.
- Release gate greps `debugPrint(` — debug-mode-gate any degraded console output; use `developer.log` in release.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `source_line_reader.dart` | utility | file-I/O | No existing kernel file reads source files from disk; use RESEARCH Pattern 2 + PathValidator philosophy |
| `error_log_file_sink.dart` (dart:io portion) | service | file-I/O | No dart:io append/flush code exists in the codebase; Future-chain queue comes from RESEARCH Pattern 3 |

## Metadata

**Analog search scope:** `lib/kernel/diagnostics/`, `lib/kernel/services/`, `lib/kernel/persistence/`, `lib/main.dart`, `test/diagnostics/`
**Files read:** 9 (5 lib + 1 main + 1 test + CONTEXT/RESEARCH)
**Pattern extraction date:** 2026-08-30
