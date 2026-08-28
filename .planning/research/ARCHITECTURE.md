# Architecture Research

**Domain:** Flutter Windows local error capture → report → display pipeline
**Researched:** 2026-08-28
**Confidence:** MEDIUM

## Standard Architecture

### System Overview

```text
                         process / framework boundaries
┌──────────────────────────────────────────────────────────────────────────┐
│ Startup guard        Flutter framework        Dart/platform async         │
│ runZonedGuarded      FlutterError.onError     PlatformDispatcher.onError  │
│       │                      │                         │                 │
└───────┴──────────────────────┴─────────────────────────┴─────────────────┘
        │                      │                         │
        └──────────────────────┴─────────────────────────┘
                                       │ capture only
                                       v
┌──────────────────────────────────────────────────────────────────────────┐
│ ErrorReporter (application-owned kernel service)                          │
│ normalize source → attach context → dedupe/throttle → publish/sink safely │
│                                                                          │
│  ErrorReport immutable value ──> ValueNotifier<ErrorReport?> current     │
└──────────────┬───────────────────────────────┬───────────────────────────┘
               │                               │
          synchronous fan-out             synchronous fan-out
               │                               │
               v                               v
┌────────────────────────────┐      ┌─────────────────────────────────────┐
│ KernelLogger facade         │      │ ErrorCardHost (app/player Stack)    │
│ ErrorOnlyFileSink           │      │ ValueListenableBuilder              │
│ logger FileOutput           │      │ non-modal, persistent, dismissible  │
│ one configured text file    │      │ detail/copy/log-path/media-path     │
└────────────────────────────┘      └─────────────────────────────────────┘
               ^                               ^
               │                               │ settings only alter display
┌──────────────┴───────────────────────────────┴───────────────────────────┐
│ Local feature path: MediaEngine.lastError / PlayerError                  │
│ → bridge listener owned by PlayerServices or PlayerFeature               │
│ → ErrorReporter.reportPlayerError(error, currentPath.value)              │
└──────────────────────────────────────────────────────────────────────────┘
```

The project should use **one application-owned `ErrorReporter` as the fan-in point**, not let global hooks, `ErrorBanner`, and file logging each independently interpret errors. The hooks only capture. The reporter constructs the UI/log contract once, controls duplicate/noise policy, publishes it, and calls the pre-existing logging facade. This preserves the existing Unix-style narrow interfaces: hook input → report transformation → independent outputs.

### Component Responsibilities

| Component | Responsibility | Boundary / communicates with |
|---|---|---|
| **Global hook installer** | Installs `FlutterError.onError`, `PlatformDispatcher.instance.onError`, and wraps bootstrap in `runZonedGuarded`; converts runtime callback inputs into reporter calls. | `main.dart` only; depends on `ErrorReporter`; never owns card state, path state, or disk I/O. |
| **ErrorSource + immutable `ErrorReport`** | Defines stable, presentation-independent error data: occurrence time, source, severity, message/error type, stack, extracted source location/source line when available, media path snapshot, log path, and optional safe metadata. | `kernel/diagnostics`; created only by reporter/factories; no Flutter widget imports. |
| **ErrorReporter** | Normalizes all inputs, snapshots contextual providers, creates a fresh report, deduplicates/reports throttled repeats, writes exactly one logger event, and assigns `currentReport.value`. Reporting failures are caught locally to prevent recursive failure. | App-owned service. Knows `KernelLogger` and injected context providers, exposes only `report...`, `currentReport`, `dismiss`, and `dispose`. |
| **Context providers / bridges** | Adapt a narrow existing source to a reporter input. The playback bridge listens to `engine.lastError` and passes `PlaybackController.currentPath.value` at the instant the `PlayerError` is observed. | Player composition boundary only. `ErrorReporter` must not import `MediaEngine`, `PlayerError`, or `PlaybackController`. |
| **KernelLogger + `ErrorOnlyFileSink`** | Keeps existing logging API/call sites stable. Extends its sink composition so `error`/`fatal` events format as plain text and append to a configured `File` via `logger`'s `FileOutput`. | Diagnostics/output boundary. It receives already-normalized data; it does not publish UI state or deduplicate reports. |
| **ErrorCardHost / ErrorCard** | Listens to reporter state, renders left-top non-modal card and details, provides copy/dismiss actions, and honours card-visibility preference. A disabled card does not block capture or file output. | UI only. Reads immutable report state; calls reporter `dismiss`; no direct engine, hook, or file access. |
| **Settings state + General tab** | Persists card visibility and file destination; applies changes through a narrow settings/configuration API. | Does not directly rewire global handlers. The logger/reporter receive an atomic configuration update or restart-safe initialization value. |

## Recommended Project Structure

```text
lib/
├── main.dart                                  # composition root + hook installation
├── app.dart                                   # receives app-scoped ErrorReporter; mounts host
├── kernel/
│   └── diagnostics/
│       ├── kernel_logger.dart                 # existing facade; add file-sink composition
│       ├── error_report.dart                  # immutable model + ErrorSource
│       ├── error_reporter.dart                # normalization, dedupe, publication, logging
│       ├── error_context.dart                 # tiny provider typedefs / source-location helpers
│       └── error_file_sink.dart               # logger FileOutput adapter, error/fatal filter
├── features/
│   └── player/
│       ├── player_feature.dart                # owns player-error bridge lifecycle
│       └── player_error_report_bridge.dart    # optional extraction if feature grows
└── ui/
    ├── player/
    │   ├── player_screen.dart                 # hosts ErrorCardHost in existing Stack
    │   ├── error_card_host.dart               # listens to global reporter + visibility pref
    │   └── error_card.dart                    # pure presentational card/detail/copy actions
    └── dialogs/settings/
        └── general_settings_content.dart      # enabled General tab; preferences controls
```

### Structure Rationale

- **`kernel/diagnostics/`:** The report pipeline is cross-cutting diagnostics infrastructure, not a player feature. Keeping report/model/file concerns beside `KernelLogger` prevents a UI dependency from leaking into the kernel.
- **`player_error_report_bridge.dart`:** This is the sole allowed dependency seam from `PlayerError`/`MediaEngine` to generic diagnostics. It makes playback-specific mapping testable and prevents `ErrorReporter` from becoming a player-service locator.
- **`ui/player/error_card*.dart`:** Replaces `error_banner.dart` rather than evolving it. The old banner owns a specific engine state; the new host owns presentation of generic app reports.
- **`main.dart` and `app.dart`:** They are composition roots, so only they receive app-scoped reporter construction and hook-install responsibilities. Widgets receive the reporter by constructor or inherited narrow holder, rather than accessing a static global.

## Architectural Patterns

### Pattern 1: Fan-in capture, fan-out reporting

**What:** Multiple capture mechanisms invoke a single reporter. The reporter produces one immutable report, then fans it out to the logger/file sink and presentation notifier.

**When to use:** Always here: framework errors, dispatcher errors, guarded-zone errors, and explicit playback-engine errors have different raw shapes but need one user-visible and on-disk representation.

**Trade-offs:** It adds a small model/service layer, but avoids three divergent renderers, duplicate log formats, and untestable hook-specific logic. Do not turn it into a generic telemetry framework: remote upload and event analytics are explicitly out of scope.

```dart
/// Converts one captured failure into a log event and the current UI report.
void report(
  Object error,
  StackTrace stackTrace, {
  required ErrorSource source,
  String? mediaPath,
}) {
  final report = _reportFactory.create(
    error: error,
    stackTrace: stackTrace,
    source: source,
    mediaPath: mediaPath ?? _currentMediaPath(),
  );
  if (_shouldSuppress(report)) return;

  // Logging must not rely on UI attachment; a hidden card still leaves evidence.
  _logger.error(report.summary, context: report.logContext,
      error: error, stackTrace: stackTrace);
  currentReport.value = report;
}
```

The code is illustrative: actual implementation should make `report` non-throwing, catch file/log formatting failures, and use a bounded fingerprint cache rather than an unbounded `Set`.

### Pattern 2: Snapshot contextual enrichment at the reporting boundary

**What:** `ErrorReporter` receives a `String? Function()` current-media-path provider (or an explicit path), and snapshots it while constructing the report. The report never later reads mutable `currentPath`.

**When to use:** For all globally captured errors and engine errors, because the user may open or stop another file before tapping the card or viewing the disk log.

**Trade-offs:** A snapshot identifies the relevant media at failure time. It may be absent during startup and must be represented as `null`/“no media”, not fabricated. Passing a provider preserves kernel independence from `PlaybackController`; passing the actual path from the playback bridge is most explicit for engine events.

**Required ordering nuance:** Today `PlaybackController.openAndPlay` sets `currentPath.value` only after `OpenSuccess`; a failed open therefore has no new active media path. For an `OpenError`, the bridge should attach the **attempted path at the operation boundary** if that information is available, otherwise the report should truthfully show the previously active/null path. Do not change generic reporter semantics to guess it.

### Pattern 3: App-scoped immutable state, UI-owned subscription

**What:** `ErrorReporter.currentReport` is a `ValueNotifier<ErrorReport?>`. Each report is a new immutable object. `ErrorCardHost` uses `ValueListenableBuilder`; only the composition-root owner disposes the reporter.

**When to use:** The project convention is `ValueNotifier + ValueListenableBuilder`, and a single current persistent card is the requirement.

**Trade-offs:** This intentionally models one visible current error, not a timeline. New errors replace the card while all errors still append to disk. If later requirements need an in-app history, add a bounded immutable list deliberately; do not silently retain all reports in memory.

### Pattern 4: Logging facade remains authoritative for disk output

**What:** Add an `ErrorOnlyFileSink` beneath `KernelLogger`, then have `ErrorReporter` invoke `KernelLogger.error/fatal`. Use `logger` 2.x `FileOutput(file: File(path))`; its default `overrideExisting: false` is the desired append behavior.

**When to use:** The milestone requires both the existing facade and the `logger` package, and only error events must reach disk.

**Trade-offs:** `logger` is an output engine, not a replacement application logging API. Keep `KernelLogger`'s existing sinks and level semantics. Prefer `FileOutput` over `AdvancedFileOutput`: the latter defaults to buffering and size rotation, which contradict the explicit single append-only, no-rotation scope. File creation/path validation and write failure handling belong in this sink/configuration boundary.

## Data Flow

### Global exception flow

```text
1. Flutter build/layout/paint/event callback throws
   → FlutterError.onError(FlutterErrorDetails)
   → FlutterError.presentError(details) retains normal debug visibility
   → ErrorReporter.reportFlutter(details)

2. Async/platform error outside a Flutter callback
   → PlatformDispatcher.instance.onError(error, stack)
   → ErrorReporter.report(error, stack, source: platformDispatcher)
   → return true only after report was accepted for handling

3. Uncaught startup/zone error scheduled inside guarded bootstrap zone
   → runZonedGuarded(..., onError)
   → ErrorReporter.report(error, stack, source: zone)

4. ErrorReporter
   → normalize raw input to ErrorReport
   → snapshot current media path and configured log path
   → fingerprint + bounded time-window throttle
   → KernelLogger.error/fatal(..., error, stackTrace, context)
       → CompositeSink's normal dev sinks (as configured)
       → ErrorOnlyFileSink → logger.FileOutput → append plain-text log
   → currentReport.value = immutable report
   → ValueListenableBuilder rebuilds ErrorCardHost
```

`FlutterError.onError` catches errors caught by Flutter framework callbacks; errors outside those callbacks flow to `PlatformDispatcher.instance.onError`, not the Flutter handler. The official Flutter guidance configures both before `runApp`, preserves `FlutterError.presentError` when overriding the framework handler, and returns `true` from a handled dispatcher callback. `runZonedGuarded` remains useful for startup/top-level guarded execution, but it is not a universal replacement: error-zone boundaries affect Futures, so `PlatformDispatcher` and local handling remain necessary.

### Playback engine error flow

```text
MediaKitEngine updates engine.lastError (ValueNotifier<PlayerError?>)
    ↓
PlayerErrorReportBridge listener observes a non-null/new PlayerError
    ↓
path snapshot: controller.currentPath.value
(or explicit operation path for a failed open where available)
    ↓
ErrorReporter.reportPlayerError(error, mediaPath: snapshot)
    ↓
normalized ErrorReport(source: playerEngine)
    ↓
KernelLogger error line + file append + currentReport publication
    ↓
ErrorCardHost replaces/shows its single persistent non-modal card
```

The engine error path should be a **listener bridge**, not a `PlayerError`-aware branch inside the card and not a second UI-only error channel. The bridge must be registered once at player-service/feature initialization and removed before the engine/controller is disposed. It should guard against repeated notification of the same error identity/fingerprint; the reporter is the final dedupe authority.

### Presentation and preference flow

```text
Settings General tab
    ↓ save `showErrorCards` and `errorLogPath`
settings store/config controller
    ├─→ ErrorCardHost: visibility only (capture/file output continue)
    └─→ File-sink configuration: validate/create destination or retain last known-good sink

ErrorCard close button
    ↓
ErrorReporter.dismiss(reportId)
    ↓
currentReport.value = null
    ↓
card disappears; log entry remains on disk
```

Do not make “card disabled” mean “do not create the report”: it must suppress only presentation, while errors are still normalized, logged, and appended. Likewise, dismissing is a UI acknowledgement, not error recovery and not deletion of the log.

## Suggested Build Order and Dependency Implications

1. **Define diagnostic contracts first — `ErrorSource`, immutable `ErrorReport`, report factory/formatter, and tests.**
   - Establishes the single contract used by global hooks, playback bridge, file output, card, copy action, and source-location fallback.
   - Include source location/source-line fields as nullable: Debug/profile can enrich when readable; release must render a graceful “unavailable” representation without trying to read local source files.

2. **Extend `KernelLogger` with a separately testable `ErrorOnlyFileSink`.**
   - Implement error/fatal filtering, append-to-configured-file formatting, destination validation, and non-throwing failure behavior.
   - Preserve existing `DebugPrintSink`/`DevToolsSink` behavior and existing callers. Do not make `ErrorReporter` write `dart:io` files directly: that would bypass the stated facade and duplicate formatting/output policy.

3. **Build `ErrorReporter` on top of the contracts and logger.**
   - Inject `KernelLogger`, current-media-path provider, configured log-path provider, clock, and bounded dedupe policy for deterministic tests.
   - Test normalization, snapshot timing, one log event per accepted report, notifier publication, dismissal, duplicate throttling, and reporting-sink failure isolation.

4. **Wire startup composition and global hooks before `runApp`.**
   - In `main.dart`: initialize binding; establish logger/reporting dependencies; install `FlutterError.onError` and `PlatformDispatcher.onError`; then run the complete bootstrap/runApp inside `runZonedGuarded`.
   - The reporter must exist before `windowManager`, `WindowService`, and player initialization so startup exceptions can be represented. Avoid a period where a hook calls `KernelLogger.I` before it has been initialized.
   - Keep the hook callbacks thin and non-async; capture first and never let reporting exceptions escape into a recursive handler path.

5. **Add the explicit playback-error bridge.**
   - Create/wire after `PlaybackController` and `MediaEngine` exist. It needs `engine.lastError` and a path context source, so it cannot precede player services.
   - Replace the old `ErrorBanner` only after this bridge exists, otherwise expected engine errors lose their current UI path.

6. **Mount `ErrorCardHost` and implement `ErrorCard`; remove `ErrorBanner`.**
   - Place the host high enough in the existing player/app `Stack` to be left-top and outside title-bar/control interaction zones, but do not put it in a modal `OverlayEntry` or route.
   - The card should be a pure rendering/action layer, with selection/copy support isolated from reporting and no `MediaEngine` dependency.

7. **Enable the Settings General tab and connect preferences last.**
   - Preference controls depend on a working card visibility input and a working file-sink configuration API.
   - Treat path changes as an I/O boundary: validate, attempt directory/file setup, surface a local settings validation error if needed, and preserve the last known-good active destination rather than disabling all diagnostics.

8. **End-to-end fault-injection and lifecycle verification.**
   - Separately prove each capture source: framework build failure, dispatcher async failure, guarded startup/zone failure, and `PlayerError` update.
   - Assert each generates one card (if enabled) and one append-only error log event with correct source/media snapshot; confirm dismissed/disabled cards still leave the file entry; test release fallback formatting without source content.

### Why this order matters

`ErrorReport` is the contract. File logging and reporting depend on it. Hook installation depends on a reporting instance that cannot itself fail due to uninitialized logging. The player bridge then adapts player-specific state into an already-tested generic system. UI and settings are last because they consume state/configuration but must not define capture behavior. This order prevents the common brownfield failure of replacing `ErrorBanner` before there is an equivalent engine-error path.

## Scaling Considerations

| Scale | Architecture adjustment |
|---|---|
| One local desktop user (this project) | One app-owned reporter, one current card, append-only single file, bounded dedupe cache. This is sufficient. |
| Long-running media sessions | Bound the fingerprint cache and avoid retaining full report history/large stack strings beyond current card; no log rotation because it is explicitly out of scope, but make write failures visible through a safe fallback. |
| Future remote diagnostics | Add a separate optional `ErrorReportSink` after local file output, with redaction and opt-in policy. Do not let remote concerns reshape the local report/card contract now. |

## Anti-Patterns

### Anti-Pattern 1: Multiple independent error paths

**What people do:** Global hooks log one format, `ErrorBanner` renders `PlayerError` separately, and each feature calls its own file writer.

**Why it's wrong:** Duplicate cards/logs, inconsistent media context, impossible common settings, and different release fallbacks result. A single exception may be presented differently depending on source.

**Do this instead:** Funnel every source into `ErrorReporter`; use small source adapters at the edges.

### Anti-Pattern 2: Catch-all global hooks as normal application control flow

**What people do:** Remove local error handling because global hooks exist, or use a global callback to “recover” from expected file/open/validation failures.

**Why it's wrong:** Global hooks are diagnostic last-resort boundaries. They lack operation-specific recovery information and zone behavior means they are not universal. Expected player/domain failures should continue to use typed local paths such as `OpenResult`/`PlayerError`.

**Do this instead:** Preserve explicit local handling; explicitly forward meaningful `PlayerError` events to the reporter for uniform diagnostics/UI.

### Anti-Pattern 3: `ErrorReporter` imports the playback subsystem

**What people do:** Have diagnostics read `PlaybackController.currentPath` or `MediaEngine.lastError` directly.

**Why it's wrong:** Diagnostics becomes coupled to player lifecycle and tests require a media engine. It violates the component boundary and risks accesses after disposal.

**Do this instead:** Inject a `String? Function()` context provider and use a one-purpose player bridge to map `PlayerError`.

### Anti-Pattern 4: Unbounded deduplication or throttling that hides evidence

**What people do:** Store every error fingerprint forever, or discard repeat failures without recording/counting them.

**Why it's wrong:** Long sessions leak memory; a persistent fault looks like it occurred only once.

**Do this instead:** Use a bounded, time-window fingerprint policy. Suppress repeated card churn while either logging a repeat count/summary or allowing periodic re-emission. Define the exact policy in the implementation phase.

### Anti-Pattern 5: Letting error reporting throw or await inside error hooks

**What people do:** Write files directly in a hook and allow formatter/I/O errors to propagate; make a hook `async` and rely on its Future.

**Why it's wrong:** The reporter can recursively trigger the same handler, lose shutdown-time exceptions, or make the original failure less observable.

**Do this instead:** Keep hook entrypoints synchronous, isolate secondary failures with narrowly typed catches plus `debugPrint` fallback, and make disk output best-effort while retaining non-file diagnostic sinks.

### Anti-Pattern 6: Using `AdvancedFileOutput` defaults for the stated file requirement

**What people do:** Select it because it sounds more capable.

**Why it's wrong:** Its defaults buffer writes and rotate around 1024 KB, conflicting with immediate-ish single-file append behavior and the explicit no-rotation scope.

**Do this instead:** Use `logger` `FileOutput` with `overrideExisting: false` via an error-only adapter.

## Integration Points

### External Services

| Service | Integration pattern | Notes |
|---|---|---|
| Flutter framework | `FlutterError.onError` installed in composition root | Call `FlutterError.presentError(details)` before/alongside reporting to retain development console output. |
| Dart/Flutter engine dispatcher | `PlatformDispatcher.instance.onError` installed before `runApp` | Return `true` after handling. Callback runs in the zone current when assigned; do not assume it replaces zone guards. |
| Dart async zones | `runZonedGuarded` wraps the complete remaining bootstrap and `runApp` | Keep async work created/awaited within its error zone where possible; zone boundaries affect failing futures. |
| `logger` ^2.7.0 | `FileOutput(file: File(configuredPath))` inside custom project `LogSink` | `FileOutput` appends by default. Ensure parent directory creation/path validation belongs to adapter/config boundary. |
| Native libmpv/media_kit / Windows | Existing `MediaEngine.lastError` / `PlayerError` channel | Dart-level strategy cannot report native process crashes, graphics-driver crashes, or failures before Dart bootstrap. These are acknowledged limits, not targets for this milestone. |

### Internal Boundaries

| Boundary | Communication | Notes |
|---|---|---|
| `main.dart` ↔ `ErrorReporter` | constructor injection and thin callback calls | Main installs handlers; reporter owns normalization only. |
| `ErrorReporter` ↔ `KernelLogger` | `error`/`fatal` facade call | One structured log context from report; logger owns sinks/file write. |
| `KernelLogger` ↔ `ErrorOnlyFileSink` | existing `LogSink.log` fan-out | Filter levels at file sink; never change all existing call sites. |
| `PlaybackController` / `MediaEngine` ↔ bridge | `ValueNotifier` listener + explicit operation context | Bridge lifetime follows player services; no diagnostics → engine imports. |
| bridge ↔ `ErrorReporter` | `reportPlayerError()` | Convert `PlayerError` in bridge or mapper; generic reporter receives stable data. |
| `ErrorReporter` ↔ `ErrorCardHost` | `ValueNotifier<ErrorReport?>` | Immutable replacement state, UI subscribes only. |
| settings ↔ card/file output | persisted preferences + configuration API | Card toggle affects only UI; log-path update validates and preserves last known-good writer. |

## Sources

- [Flutter: Handling errors](https://docs.flutter.dev/testing/errors) — official capture-boundary and handler guidance; Context7-resolved, **MEDIUM** confidence.
- [PlatformDispatcher.onError API](https://api.flutter.dev/flutter/dart-ui/PlatformDispatcher/onError.html) — dispatcher return/zone semantics; official API, cross-checked, **MEDIUM** confidence.
- [Dart `runZonedGuarded` API](https://api.dart.dev/dart-async/runZonedGuarded.html) — guarded-zone coverage and error-zone caveat; official API, cross-checked, **MEDIUM** confidence.
- [Flutter `ValueNotifier` API](https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html) — immutable value/publication and disposal semantics; official API, **MEDIUM** confidence.
- [logger package](https://pub.dev/packages/logger), [FileOutput API](https://pub.dev/documentation/logger/latest/logger/FileOutput-class.html), and [AdvancedFileOutput API](https://pub.dev/documentation/logger/latest/logger/AdvancedFileOutput-class.html) — file output behavior; package documentation, **MEDIUM** confidence.
- Existing-project integration inspected in `lib/main.dart`, `lib/kernel/diagnostics/kernel_logger.dart`, `lib/kernel/services/playback_controller.dart`, `lib/features/player/player_feature.dart`, and `lib/ui/player/error_banner.dart`.

---
*Architecture research for: Simple Player Flutter local error capture, report, and display system*
*Researched: 2026-08-28*
