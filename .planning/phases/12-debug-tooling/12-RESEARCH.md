# Phase 12: Debug Tooling - Research

**Researched:** 2026-05-30
**Domain:** Structured logging, named loggers, performance tracing
**Confidence:** MEDIUM

## Summary

This phase enhances the existing logging infrastructure in `lib/kernel/utils/log.dart` (136 lines) with three capabilities: (1) structured JSON output via logger package's built-in `JsonPrinter`, (2) module-scoped named Logger instances for engine/bridge/services/UI, and (3) `dart:developer` Timeline events on 4 performance-sensitive async methods.

The current implementation uses a single global `Logger log` variable with `PrettyPrinter`, `ProductionFilter` for release filtering, and a custom `_RotatingFileOutput` class. 19 files import and use `log.d()`, `log.i()`, `log.w()`, `log.e()`. The migration is additive — existing `log.` calls continue working; new module loggers are introduced alongside.

**Primary recommendation:** Modify `initLog()` to create 4 module loggers + update global `log`, add Timeline wrapping to `FvpEngine.open()`, `FvpEngine.seekTo()`, `WindowService._enterFullscreen()`, `WindowService._exitFullscreen()`. Migrate 19 files gradually to module loggers.

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Use `logger` package built-in `JsonPrinter`, zero custom code
- **D-02:** JsonPrinter default fields: level, message, time, error, stackTrace
- **D-03:** No custom `module` field in JSON — named logger prefix distinguishes source
- **D-04:** Module loggers: `Logger('engine')`, `Logger('bridge')`, `Logger('services')`, `Logger('ui')`
- **D-05:** Keep global `log` as default logger (backward compat), new code uses module loggers
- **D-06:** Direct `Logger(filter: ..., printer: ..., output: ...)` constructor — no factory class
- **D-07:** Module loggers share same printer/output config (set by `initLog`)
- **D-08:** Track `FvpEngine.open()` — media open latency
- **D-09:** Track `FvpEngine.seekTo()` — seek response time
- **D-10:** Track `WindowService._enterFullscreen()` / `_exitFullscreen()` — fullscreen toggle
- **D-11:** Use `dart:developer.Timeline.startSync()` / `finishSync()` wrapping
- **D-12:** Debug mode: all levels to console (current behavior preserved)
- **D-13:** Release mode: warning+ only to file (ProductionFilter threshold = Level.warning)
- **D-14:** File output keeps PrettyPrinter format; debug console keeps PrettyPrinter

### Claude's Discretion

- logger package version upgrade strategy
- Timeline event category naming convention
- Testing strategy (mock Logger vs verify output format)

### Deferred Ideas (OUT OF SCOPE)

None

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| logger | 2.7.0 [VERIFIED: pubspec.lock] | Structured logging with printers/filters/outputs | Already in project, mature, built-in JsonPrinter |
| dart:developer | SDK built-in | Timeline events for DevTools profiling | Zero dependency, native DevTools integration |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter/foundation | SDK | `kDebugMode` for mode branching | Already used in project |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| logger JsonPrinter | Hand-rolled JSON encoder | Unnecessary — JsonPrinter handles edge cases (multiline, stack traces) |
| dart:developer Timeline | ` Stopwatch` + log output | Timeline integrates with DevTools Performance panel; log-only timing is invisible to profiler |

**Installation:** No new packages needed — `logger: ^2.5.0` already in pubspec.yaml.

## Package Legitimacy Audit

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| logger | pub.dev | 6+ yrs | established | github.com/leisim/logger | N/A (Dart) | Approved — already in project |

No new packages installed in this phase.

## Architecture Patterns

### System Architecture Diagram

```
initLog()
  |
  +-- Creates 4 module loggers + updates global log
  |   Logger('engine')  -- PrettyPrinter + ProductionFilter (release) + MultiOutput
  |   Logger('bridge')  -- same config
  |   Logger('services')-- same config
  |   Logger('ui')      -- same config
  |   log (global)      -- same config (backward compat)
  |
  +-- Output routing:
      Debug mode:  ConsoleOutput (PrettyPrinter)
      Release mode: MultiOutput([ConsoleOutput, _RotatingFileOutput])
                   ConsoleOutput: PrettyPrinter (no colors)
                   File: PrettyPrinter (no colors)

Timeline Events (dart:developer):
  FvpEngine.open()        --> Timeline.startSync('fvp.open') ... finishSync()
  FvpEngine.seekTo()      --> Timeline.startSync('fvp.seek') ... finishSync()
  WindowService._enterFullscreen() --> Timeline.startSync('window.enterFullscreen') ... finishSync()
  WindowService._exitFullscreen()  --> Timeline.startSync('window.exitFullscreen') ... finishSync()
```

### Recommended Changes to log.dart

```
lib/kernel/utils/log.dart
├── Global: Logger log = Logger(...)          # KEEP — backward compat
├── Module loggers:                           # NEW
│   ├── Logger logEngine = Logger(...)
│   ├── Logger logBridge = Logger(...)
│   ├── Logger logServices = Logger(...)
│   └── Logger logUi = Logger(...)
├── initLog()                                 # MODIFY — update all 5 loggers
└── _RotatingFileOutput                       # KEEP — unchanged
```

### Pattern 1: Module Logger Creation in initLog()

**What:** Create 4 named loggers sharing the same filter/printer/output configuration
**When to use:** Application startup, called from `main.dart`
**Example:**
```dart
// Source: logger package API (pub.dev/packages/logger)
// Logger constructor accepts optional positional `filter` or named params
Logger logEngine = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 4,
    lineLength: 100,
    colors: false,           // release mode
    printEmojis: false,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
  filter: ProductionFilter(), // Level.warning threshold in release
  output: MultiOutput([ConsoleOutput(), rotatingFileOutput]),
);
```

**Key insight:** The logger package `Logger` constructor does NOT have a `name` parameter. The first positional argument (if a String) IS the prefix. Call `Logger('engine')` to create a logger with 'engine' as the prefix that appears in output. [ASSUMED — verify against logger 2.7.0 source]

### Pattern 2: Timeline Wrapping for Async Methods

**What:** Wrap performance-sensitive async methods with `dart:developer` Timeline events
**When to use:** Methods where latency matters (open, seek, fullscreen toggle)
**Example:**
```dart
// Source: dart:developer SDK documentation
import 'dart:developer';

Future<void> open(String path) async {
  Timeline.startSync('fvp.open');
  try {
    // ... existing implementation ...
  } finally {
    Timeline.finishSync();
  }
}
```

### Anti-Patterns to Avoid

- **Custom JSON encoder:** Don't hand-roll JSON output — `JsonPrinter` handles multiline messages, stack traces, and error objects correctly
- **Logger factory classes:** Don't create abstract factories — direct `Logger(...)` construction is simple enough for 4 instances
- **Breaking existing log calls:** Don't force-migrate all 19 files in one commit — gradual migration with both `log` and module loggers coexisting

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON log format | Custom encoder | `JsonPrinter()` | Handles edge cases (errors, stack traces, multiline) |
| Performance tracing | Stopwatch + log | `Timeline.startSync/finishSync` | Native DevTools integration |
| Log level filtering | Custom filter class | `ProductionFilter()` | Already handles debug/release mode switching |

## Common Pitfalls

### Pitfall 1: Logger Name Parameter Behavior
**What goes wrong:** Assuming `Logger('name')` sets a visible prefix in output
**Why it happens:** The logger package's API may treat the first positional arg differently across versions
**How to avoid:** Verify `Logger('engine')` output includes the prefix string; if not, use a custom printer wrapper
**Warning signs:** Log output shows no module identifier
**Confidence:** [ASSUMED] — needs runtime verification against logger 2.7.0

### Pitfall 2: ProductionFilter Level Threshold
**What goes wrong:** Assuming `ProductionFilter()` defaults to `Level.warning`
**Why it happens:** Default may be `Level.verbose` or `Level.debug` in some versions
**How to avoid:** Explicitly set `filter: ProductionFilter(Level.warning)` or verify default
**Warning signs:** Release logs include debug/trace messages in file output
**Confidence:** [ASSUMED] — needs verification; current code uses `ProductionFilter()` without explicit level

### Pitfall 3: Timeline.startSync with Async Methods
**What goes wrong:** `finishSync()` not called if exception thrown before it
**Why it happens:** Missing try/finally wrapper
**How to avoid:** Always use try/finally pattern around Timeline.startSync/finishSync
**Warning signs:** DevTools shows unclosed trace events

### Pitfall 4: Module Logger Not Updated by initLog()
**What goes wrong:** Creating module loggers at declaration time (before `initLog()` runs) means they get debug-mode config, then `initLog()` only updates global `log`
**Why it happens:** Module loggers are `late` globals initialized before `initLog()` is called
**How to avoid:** `initLog()` must reassign ALL 5 loggers (4 module + 1 global)
**Warning signs:** Release mode logs from module loggers still go to console only

## Code Examples

### Current log.dart Structure (for reference)
```dart
// lib/kernel/utils/log.dart — current implementation
Logger log = Logger(
  printer: PrettyPrinter(
    methodCount: 0, errorMethodCount: 4, lineLength: 100,
    colors: true, printEmojis: false,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);

Future<void> initLog() async {
  if (kDebugMode) return;
  // Creates Logger with ProductionFilter + MultiOutput(ConsoleOutput, _RotatingFileOutput)
  log = Logger(filter: ProductionFilter(), printer: PrettyPrinter(...), output: MultiOutput([...]));
}
```

### Expected log.dart After Phase 12
```dart
// Module loggers — initialized with debug defaults, overwritten by initLog() in release
Logger log = Logger(printer: PrettyPrinter(...));
Logger logEngine = Logger(printer: PrettyPrinter(...));
Logger logBridge = Logger(printer: PrettyPrinter(...));
Logger logServices = Logger(printer: PrettyPrinter(...));
Logger logUi = Logger(printer: PrettyPrinter(...));

Future<void> initLog() async {
  if (kDebugMode) return;
  final output = MultiOutput([ConsoleOutput(), _RotatingFileOutput(...)]);
  final printer = PrettyPrinter(methodCount: 0, colors: false, ...);
  final filter = ProductionFilter(Level.warning);  // explicit threshold
  log = Logger(filter: filter, printer: printer, output: output);
  logEngine = Logger(filter: filter, printer: printer, output: output);
  logBridge = Logger(filter: filter, printer: printer, output: output);
  logServices = Logger(filter: filter, printer: printer, output: output);
  logUi = Logger(filter: filter, printer: printer, output: output);
}
```

### Migration Pattern (file-by-file)
```dart
// Before:
import '../utils/log.dart';
log.e('FvpEngine.open error: $e');

// After:
import '../utils/log.dart';  // same import, now exports logEngine
logEngine.e('FvpEngine.open error: $e');
```

### Timeline Wrapping Pattern
```dart
import 'dart:developer';

Future<void> open(String path) async {
  Timeline.startSync('fvp.open');
  try {
    // ... existing 100+ line method body ...
  } finally {
    Timeline.finishSync();
  }
}
```

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test + package:test (built-in) |
| Config file | none — standard flutter test |
| Quick run command | `flutter test test/unit/kernel/utils/log_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DBG-01 | Module loggers created by initLog | unit | `flutter test test/unit/kernel/utils/log_test.dart` | Wave 0 |
| DBG-01 | JsonPrinter output is valid JSON | unit | same file | Wave 0 |
| DBG-01 | ProductionFilter blocks debug-level in release | unit | same file | Wave 0 |
| DBG-01 | Timeline events emitted for open/seek/fullscreen | unit | `flutter test test/unit/kernel/engine/fvp_engine_test.dart` | Wave 0 |

### Wave 0 Gaps
- [ ] `test/unit/kernel/utils/log_test.dart` — test module logger creation, JsonPrinter output format, ProductionFilter threshold
- [ ] `test/unit/kernel/engine/fvp_engine_test.dart` — test Timeline.startSync called on open/seekTo (may need mock dart:developer)

### Testing Strategy
- **Logger output format:** Create Logger with JsonPrinter, call `.d('test')`, capture output via custom `LogOutput` subclass, parse as JSON, verify fields exist
- **ProductionFilter threshold:** Create Logger with `ProductionFilter(Level.warning)`, call `.d('debug')` and `.w('warning')`, verify debug is suppressed
- **Timeline events:** Hard to unit-test directly (dart:developer writes to VM timeline buffer). Verify by checking code has `Timeline.startSync` calls — this is a code review task, not automated test
- **Migration correctness:** Verify each file's import resolves and compiles — `flutter analyze` covers this

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `Logger('engine')` sets 'engine' as visible prefix in output | Pattern 1, Pitfall 1 | Module loggers may not show module name — need custom printer wrapper |
| A2 | `ProductionFilter()` defaults to `Level.warning` | Pitfall 2 | Release logs may include unwanted debug/trace messages |
| A3 | Logger 2.7.0 `JsonPrinter` produces `{"level":"INFO","message":"...","time":"..."}` format | D-02 | JSON field names may differ from expectations |
| A4 | `Timeline.startSync`/`finishSync` works correctly across async gaps in Dart VM | Pattern 2 | May need `Timeline.startSync` with async variant or different approach |

## Open Questions

1. **Does `Logger('name')` actually set a visible prefix in output?**
   - What we know: The constructor accepts a first positional String argument
   - What's unclear: Whether PrettyPrinter/JsonPrinter include this prefix in output
   - Recommendation: Verify at runtime — if not visible, the prefix value is metadata only and D-03's assumption (no custom module field needed) breaks. Fallback: add module name as prefix via custom printer wrapper.

2. **What is ProductionFilter's default level threshold?**
   - What we know: Current code uses `ProductionFilter()` without explicit level
   - What's unclear: Default may be `Level.verbose` or `Level.warning`
   - Recommendation: Set explicitly: `ProductionFilter(Level.warning)` to match D-13

3. **Should JsonPrinter be used for file output or only console?**
   - What we know: D-14 says file keeps PrettyPrinter format
   - What's unclear: Whether structured JSON should go to file for log aggregation tools
   - Recommendation: Follow D-14 — PrettyPrinter for file (human-readable), PrettyPrinter for debug console. JsonPrinter could be a future option for dedicated log aggregation.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| logger | Structured logging | ✓ | 2.7.0 | — |
| dart:developer | Timeline events | ✓ | SDK built-in | — |
| flutter_test | Unit tests | ✓ | SDK | — |

No missing dependencies.

## Sources

### Primary (HIGH confidence)
- pubspec.lock — logger 2.7.0 confirmed
- `lib/kernel/utils/log.dart` — current implementation (136 lines, read in full)
- `lib/kernel/engine/fvp_engine.dart` — open() at line 230, seekTo() at line 422
- `lib/kernel/bridge/window_service.dart` — _enterFullscreen() at line 197, _exitFullscreen() at line 256

### Secondary (MEDIUM confidence)
- dart:developer Timeline API — SDK documentation, well-known API
- logger package PrettyPrinter/JsonPrinter — pub.dev API docs [ASSUMED for exact field names]

### Tertiary (LOW confidence)
- Logger name/prefix behavior — training data only [ASSUMED]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — logger 2.7.0 already in project, dart:developer is SDK built-in
- Architecture: HIGH — additive changes to existing log.dart, clear migration path
- Pitfalls: MEDIUM — Logger name prefix behavior and ProductionFilter defaults need runtime verification
- Testing: MEDIUM — Timeline events hard to test automatically, logger output testable with custom LogOutput

**Research date:** 2026-05-30
**Valid until:** 2026-06-30 (stable — logger package and dart:developer are mature)

---

*Phase: 12-Debug Tooling*
*Research complete: 2026-05-30*
