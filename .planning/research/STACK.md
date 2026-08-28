# Stack Research

**Domain:** Flutter Windows desktop local error capture, localization, and feedback
**Researched:** 2026-08-28
**Confidence:** HIGH for Flutter/logger APIs; MEDIUM for package-market recommendation

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Flutter framework error boundary | Flutter SDK already pinned by project | Capture Flutter build/layout/paint and framework-callback exceptions | Use the framework-supported `FlutterError.onError` hook. It receives a rich `FlutterErrorDetails` record, including the original exception, throwing-site stack when available, context, library, and diagnostic collector. Preserve `FlutterError.presentError(details)` so debug console/IDE behavior remains intact, then forward the normalized record to `ErrorReporter`. **Confidence: HIGH.** |
| Dart platform error boundary | Dart/Flutter SDK | Capture unhandled root-isolate errors outside a Flutter callback, notably async/plugin errors | Use `PlatformDispatcher.instance.onError`; Flutter explicitly recommends it for errors not routed to `FlutterError.onError`. The callback must return `true` after durable capture to mark the error handled. Register it once during startup. **Confidence: HIGH.** |
| Narrow Zone startup guard | Dart SDK | Last-resort capture of synchronous startup failures and any uncaught error routed to the guarded zone | Use `runZonedGuarded` only around bootstrap, not as the primary async-error mechanism. Flutter 3.3+ recommends `PlatformDispatcher.onError` over custom Zones for application exceptions; Zones create a separate error zone and can make failed futures appear not to complete across zone boundaries. Put `WidgetsFlutterBinding.ensureInitialized()`, hook installation, initialization, and `runApp()` inside the *same* guarded callback to avoid Flutter's zone-mismatch error. **Confidence: HIGH.** |
| `logger` | `2.7.0` (already locked) | Formatting/output engine behind the project `FileSink` | Reuse the existing direct dependency rather than adopting an error-reporting suite. `Logger` composes `LogFilter`, `LogPrinter`, and `LogOutput`; it provides the exact file output required by this milestone while `KernelLogger` remains the project-facing facade. **Confidence: HIGH.** |
| `path_provider` | `2.1.6` declared | Resolve an application-writable Windows log directory | Retain the existing package and resolve a directory before creating the logger output. Do not use `Directory.current` or the installed executable directory: those are not dependable writable storage locations for Windows release installs. **Confidence: HIGH for existing dependency/use; MEDIUM for exact chosen directory policy.** |

### Minimum Correct Global Wiring

Install all three boundaries before application services can throw. The reporter must make its in-memory/UI update synchronous and make disk failure non-fatal; an error handler that itself throws creates a second failure and can defeat reporting.

```dart
void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize the reporter and its append-only file output before capture starts.
    await ErrorReporter.I.initialize();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      ErrorReporter.I.reportFlutterError(details);
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      ErrorReporter.I.report(
        error: error,
        stackTrace: stack,
        origin: ErrorOrigin.platformDispatcher,
      );
      return true;
    };

    runApp(const SimplePlayerApp());
  }, (Object error, StackTrace stack) {
    // Must be safe before/after reporter initialization and must never throw.
    ErrorReporter.I.reportBootstrapError(error, stack);
  });
}
```

**Capture boundaries and limits**

| Boundary | Catches | Does not promise to catch | Required behavior |
|----------|---------|---------------------------|-------------------|
| `FlutterError.onError` | Exceptions Flutter catches in its own callbacks: commonly build, layout, paint, gestures and framework lifecycle work | Async/plugin errors outside a Flutter callback | Call `FlutterError.presentError(details)` and forward `details`; do not set it to `null`. |
| `PlatformDispatcher.instance.onError` | Unhandled root-isolate errors outside Flutter callbacks, including typical asynchronous platform/plugin failures | Errors in spawned isolates; VM/process termination before callback execution; native access violations | Report and return `true`. Give every spawned isolate its own error listener/forwarding path if the app later adds isolates. |
| `runZonedGuarded` | Synchronous bootstrap failure and uncaught asynchronous errors belonging to its zone | Native process crashes; a complete substitute for platform dispatcher; errors/futures crossing incompatible error zones | Keep bootstrap and `runApp()` in the same zone. Do not nest zones gratuitously. |
| Engine adapter / `PlayerError` path | Errors deliberately surfaced by the existing media-engine wrapper | A libmpv/native crash that terminates the process | Forward directly to the same `ErrorReporter`; it is an explicit fourth source, not a global-hook side effect. |

`ErrorWidget.builder` is **not** an error-capture hook. It is optional presentation fallback for a widget that fails to build. The planned non-modal error card should be driven by `ErrorReporter` instead; use `ErrorWidget.builder` only if a neutral replacement widget is needed to keep a damaged subtree from obscuring the application.

### Supporting Libraries

| Library/API | Version | Purpose | When to Use |
|-------------|---------|---------|-------------|
| `logger.FileOutput` | `logger 2.7.0` | Append formatted `OutputEvent.lines` to one `dart:io` `File` | Use for the required single plain-text error file. Constructor: `FileOutput(file: file, overrideExisting: false, encoding: utf8)`. `false` is the default and means append. Create the parent directory first; `FileOutput.init()` opens the file but does not create parents. Await `logger.init` before writing and call `logger.close()` during orderly shutdown to flush/close. **Confidence: HIGH.** |
| Custom `LogPrinter` | `logger 2.7.0` | Emit stable, readable error-record blocks without terminal coloring or decorative borders | Preferred for this feature. Extend `LogPrinter`, implement `List<String> log(LogEvent event)`, and output timestamp, origin, media path, localized `file:line`, exception, raw stack, and separator. This preserves one authoritative serialized format in the `logger` pipeline. **Confidence: HIGH.** |
| `SimplePrinter` | `logger 2.7.0` | Built-in concise formatter | Acceptable only for a prototype; configure `colors: false, printTime: true`. It is insufficient if the log must include the full stack/source-location record in a predictable multiline form. **Confidence: HIGH.** |
| `PrettyPrinter`, `PrefixPrinter`, `HybridPrinter`, `LogfmtPrinter` | `logger 2.7.0` | Built-in alternate formatters | Do **not** choose these for the milestone's human-readable, append-only error journal: Pretty output is verbose/decorative; logfmt targets structured key/value ingestion; prefix/hybrid add presentation policy with no localization benefit. They remain supported package APIs. **Confidence: HIGH.** |
| `logger.MultiOutput` | `logger 2.7.0` | Fan out a single logger record to multiple `LogOutput`s | Do not need it initially because the project's `CompositeSink` already owns sink fan-out. Consider only if the file engine must also write to another `logger` output. **Confidence: HIGH.** |
| `logger.AdvancedFileOutput` | `logger 2.7.0` | Buffered output and optional rotation | Explicitly defer: the milestone excludes rotation. It adds timers, buffering, rotation and its own error printing. If later adopted, configure immediate writes for errors/fatals and confirm shutdown flushing. **Confidence: HIGH.** |
| `StackFrame` (`foundation.dart`) | Flutter SDK | Parse a conventional VM `StackTrace` into package/path/line/column/method | Use `StackFrame.fromStackTrace(stack)` to select the first app-owned `package:simple_player_flutter/...` frame, then display its `packagePath:line` and preserve the entire raw stack. Treat parse failure, `line < 0`, and async-suspension/stack-overflow markers as ordinary graceful-degradation cases. **Confidence: HIGH.** |

### `logger` API Status: Exact Names and Recommended Adapter

The project has **`logger: ^2.7.0` in `pubspec.yaml` and resolves exactly `logger 2.7.0` in `pubspec.lock`**. Pub.dev reports `2.7.0` as the current stable release (published 2026-03-15).

* Valid file APIs: **`FileOutput`** and **`AdvancedFileOutput`**.
* There is **no `LogFileOutput`** in logger 2.7.0. Do not plan against that name.
* The extensibility base is **`LogOutput`**, not `Output`. Its relevant contract is `Future<void> init()`, `void output(OutputEvent event)`, and `Future<void> destroy()`.
* `Logger` constructor accepts `filter`, `printer`, `output`, and `level`; its `init` future completes when all components initialize.

Use a **thin adapter**, not a replacement for `KernelLogger`:

1. `ErrorReporter` normalizes all four origins into an immutable `ErrorReport`.
2. `FileSink implements LogSink` owns one `Logger(output: FileOutput(...), printer: ErrorReportPrinter(), level: Level.error)`.
3. `FileSink.log(...)` returns immediately for any level below `LogLevel.error`; for error/fatal it maps project level to `logger.Level`, passes `error` and `stackTrace`, and sends the normalized record as its message.
4. `ErrorReporter` independently updates its `ValueNotifier` for the error card. A disabled card must not disable file persistence.
5. `FileSink` catches `FileSystemException`/logger output failure, reports it only through `debugPrint`/`FlutterError.presentError` without recursively calling `ErrorReporter`, and exposes a safe failure state to settings UI.

This honors the existing `KernelLogger → LogSink` seam and keeps `logger` as an output engine rather than letting a third-party global logger become a second logging architecture.

### Error Localization and Source-Line Policy

| Available runtime data | Reliable use | Limitation / policy |
|------------------------|--------------|--------------------|
| `FlutterErrorDetails.exception`, `.stack`, `.context`, `.library`, `.informationCollector`, `.silent` | Preserve the exception and diagnostics; `.stack` represents where the exception was thrown rather than caught | `.stack` is nullable and `FlutterErrorDetails` contains **no source-code excerpt**. Do not scrape `details.toString()` as the canonical data model. |
| `StackTrace` | Preserve its complete `toString()` verbatim in the report | Dart's public `StackTrace` API is fundamentally string-oriented; it does not guarantee structured frames, source files, source text, or a stable parser format. |
| `StackFrame.fromStackTrace` | Best-effort file/line/column/method extraction for a normal Flutter Windows VM trace | It parses the trace string. Frames may be unparseable/missing, represent async suspension, or have unknown (`-1`) line/column. Never allow parser failure to discard the raw stack. |
| App source checkout in debug/development | After selecting a verified app-owned relative path (`lib/...`) and valid positive line, read the line from the checkout and show it as an optional convenience | Do not accept arbitrary absolute stack paths. Canonicalize and enforce that resolved paths remain under project root. Guard file I/O and line bounds. This capability is for a developer checkout, not a generic installed application. |
| Installed/profile/release executable | Show error, selected location when available, full raw stack, log path and media path | Flutter/Dart source files are not normally shipped in the release bundle. Never promise a source line; show “source unavailable in this build” when no trusted readable local source is present. Symbol/location fidelity can also be weaker than debug. |

**Recommended locator algorithm:** parse once; choose the first frame with `packageScheme == 'package'`, `package == 'simple_player_flutter'`, a non-empty `packagePath`, and `line > 0`; render `packagePath:line[:column]`. If none qualifies, use the first parseable non-SDK frame as labeled fallback; otherwise show `Location unavailable`. Keep a raw `StackTrace.toString()` field in every report. This prevents the UI from inventing a location when the runtime cannot provide one.

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `flutter test` | Verify normalization, frame selection, FileSink error-only filtering, and hook delegation | Inject `LogSink`, source reader, clock and path resolver. Never write to a real user log directory in tests. Test `FlutterErrorDetails.stack == null`, malformed stacks, no app frame, invalid line, missing source file, and disk write failure. |
| `flutter analyze` | Enforce strict Dart checks | Keep error-hook bodies small, typed, and non-throwing. Explicitly use `unawaited()` only for deliberate fire-and-forget persistence, with a failure observer. |
| Windows WER LocalDumps / WinDbg (developer machine only) | Diagnose hard native process crashes beyond Dart/Flutter hooks | Not part of application functionality. WER LocalDumps is disabled by default, requires administrator registry configuration, and is independently managed by Windows. It can capture native process dumps after a crash; app-level Dart hooks cannot reliably do so. |

## Installation

No additional runtime dependency is recommended.

```bash
# Existing direct dependencies — retain their current constraints.
flutter pub get

# logger currently resolves to 2.7.0; confirm after any dependency update.
flutter pub deps | findstr logger
```

Do **not** add a source-reading, crash-reporting, state-management, or remote-observability package for this milestone. Implement the small source-reader and `FileSink` behind existing narrow interfaces.

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `FlutterError.onError` + `PlatformDispatcher.instance.onError` | `runZonedGuarded` as the sole global handler | Do not use as sole handler. Use the Zone only as startup/fallback guard; PlatformDispatcher is Flutter's current recommended app-exception boundary. |
| Existing `KernelLogger` facade + `logger.FileOutput` adapter | Make `logger.Logger` the application-wide logger | Only in a greenfield app with no diagnostics facade. Here it would require broad migration and duplicate the current `LogSink` abstraction. |
| Custom `ErrorReportPrinter` + `FileOutput` | `AdvancedFileOutput` | Use only if scope later adds rotation/buffering. It conflicts with the explicit single-file append-only scope today. |
| Small in-house reporter | `crash_forensics 1.0.0` | Consider only if the product later needs structured JSON bundles, breadcrumbs, device snapshots, encrypted reports, or optional transport. It claims Windows support/local storage, but is a new package (v1.0.0), from an unverified uploader, with very low observed adoption and broad dependencies—poor fit for this local plain-text requirement. **Confidence: MEDIUM.** |
| Small in-house reporter | `talker 5.1.20` | Consider when rich interactive in-app log history/sharing is a product requirement. It lists Windows support, but published package information does not establish the required local append-only file persistence; it is unnecessary architecture for this milestone. **Confidence: MEDIUM.** |
| Developer source checkout lookup | Bundle `.dart` files/source reader into release app | Only for a purpose-built developer distribution that deliberately ships source and accepts the disclosure/size tradeoff. Never do this for the normal release merely to fill a card field. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `LogFileOutput` | This API name does not exist in `logger 2.7.0`; implementation would fail at compile time or force an unrelated package. | `logger.FileOutput`. |
| Replacing `PlatformDispatcher.onError` with a Zone-only strategy | Flutter identifies platform dispatcher handling as the modern recommended mechanism; Zone boundaries can introduce error-zone/future semantics and Flutter zone mismatch. | Both first-party hooks plus a narrow bootstrap `runZonedGuarded`. |
| Calling `runZonedGuarded` only around `runApp` after binding initialization | Flutter binding initialization and `runApp` then occur in different zones, which triggers a debug zone-mismatch warning/error path. | Put `ensureInitialized`, hook registration, initialization and `runApp` in the same zone. |
| Recursive error reporting when file output fails | A failed error handler can create a reporting loop during the very event meant to be captured. | A non-recursive fallback (`debugPrint`/original Flutter presentation) and a visible “log unavailable” state. |
| Trusting absolute file paths from a stack trace | Stack strings are diagnostic text, not an authorization boundary; reading arbitrary paths risks disclosure and unreliable behavior. | Only resolve verified `package:simple_player_flutter` frames relative to an injected project source root, then canonicalize and enforce containment. |
| Sentry, Crashlytics, or remote telemetry | Explicitly out of scope; they create credentials, privacy, network and operational surface without serving the developer-local workflow. | Local `ErrorReporter` + text file. |
| Expecting Dart hooks to capture libmpv/FFI access violations or abrupt process death | The VM/process can terminate before Dart callbacks run. | Developer-only Windows WER LocalDumps/WinDbg for native-crash triage; retain engine error-channel forwarding for recoverable errors. |

## Stack Patterns by Variant

**If running from the repository in debug/development:**
- Enable trusted source-line lookup after app-frame selection and strict project-root containment.
- Because the developer's checkout contains matching `.dart` files and the feature's core value is immediate local diagnosis.

**If running an installed/profile/release Windows build:**
- Persist the selected `file:line` only when the stack yields it; otherwise show “Location unavailable”; always preserve error, origin, raw stack and log path.
- Because source files are normally absent, and fabricated/failed source lookup is worse than explicit degradation.

**If a future phase adds background isolates:**
- Register an isolate error listener and forward a normalized event to `ErrorReporter` on the root isolate.
- Because `PlatformDispatcher.instance.onError` only handles the root isolate.

**If a future phase adds log rotation:**
- Replace only the `FileOutput` construction with `AdvancedFileOutput`, configure `writeImmediately` for error/fatal, and add explicit shutdown-flush tests.
- Because the adapter shields the rest of the application, while avoiding premature rotation machinery now.

## Version Compatibility

| Package/API | Compatible With | Notes |
|-------------|-----------------|-------|
| `logger 2.7.0` | Dart SDK `>=2.17.0 <4.0.0` | Existing app resolves 2.7.0. File outputs are conditionally exported for `dart:io`, which is available on Windows desktop. |
| `logger.FileOutput` | Windows desktop (`dart:io`) | Requires a writable pre-created parent directory and `await logger.init`; append mode is default. |
| `FlutterError.onError` + `PlatformDispatcher.instance.onError` | Flutter 3.3+ | `PlatformDispatcher.onError` was introduced as the recommended app-exception hook in Flutter 3.3. This project should use it rather than relying on Zone-only handling. |
| `StackFrame` | Flutter Windows VM stack traces | Best-effort parser over `StackTrace.toString`, not a language-level structured-stack guarantee. Retain raw trace. |

## Sources

- [Flutter: Handling errors in Flutter](https://docs.flutter.dev/testing/errors) — official global-hook guidance and combined `FlutterError`/`PlatformDispatcher` pattern. **Confidence: HIGH**
- [Flutter 3.3: PlatformDispatcher.onError](https://docs.flutter.dev/release/release-notes/release-notes-3.3.0) — current direction away from custom Zone handling for application exceptions. **Confidence: HIGH**
- [Flutter: Zone mismatch breaking change](https://docs.flutter.dev/release/breaking-changes/zone-errors) — same-zone requirement for binding initialization and `runApp`. **Confidence: HIGH**
- [Flutter API: PlatformDispatcher.onError](https://api.flutter.dev/flutter/dart-ui/PlatformDispatcher/onError.html) — root-isolate scope, registered-zone behavior, and boolean handling contract. **Confidence: HIGH**
- [Flutter API: FlutterErrorDetails](https://api.flutter.dev/flutter/foundation/FlutterErrorDetails-class.html) and [stack property](https://api.flutter.dev/flutter/foundation/FlutterErrorDetails/stack.html) — available structured diagnostics and no source excerpt. **Confidence: HIGH**
- [Flutter API: StackFrame](https://api.flutter.dev/flutter/foundation/StackFrame-class.html) and [Flutter source parser](https://github.com/flutter/flutter/blob/main/packages/flutter/lib/src/foundation/stack_frame.dart) — best-effort frame extraction fields/limitations. **Confidence: HIGH**
- [Dart API: runZonedGuarded](https://api.dart.dev/stable/dart-async/runZonedGuarded.html) and [StackTrace](https://api.dart.dev/stable/dart-core/StackTrace-class.html) — zone semantics and string-oriented trace contract. **Confidence: HIGH**
- [logger 2.7.0 on pub.dev](https://pub.dev/packages/logger) and [logger source](https://github.com/SourceHorizon/logger) — current version and `FileOutput`/`AdvancedFileOutput`/printer/output APIs. **Confidence: HIGH**
- [crash_forensics 1.0.0](https://pub.dev/packages/crash_forensics) and [talker 5.1.20](https://pub.dev/packages/talker) — package alternatives assessed for local Windows reporting. **Confidence: MEDIUM**
- [Microsoft: Collecting User-Mode Dumps (WER LocalDumps)](https://learn.microsoft.com/en-us/windows/win32/wer/collecting-user-mode-dumps) — native-crash diagnostic boundary outside Dart error hooks. **Confidence: HIGH**

---
*Stack research for: Simple Player Flutter v2.1 local error capture, locate, and feedback system*
*Researched: 2026-08-28*
