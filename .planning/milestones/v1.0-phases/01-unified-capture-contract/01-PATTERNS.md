# Phase 1: 统一捕获与报告契约 - Pattern Map

**Mapped:** 2026-08-28  
**Files analyzed:** 9 planned new/modified files  
**Analogs found:** 9 / 9

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/kernel/diagnostics/error_report.dart` | model | transform | `lib/kernel/models/player_error.dart` | role-match |
| `lib/kernel/diagnostics/error_reporting_dependencies.dart` | utility | transform | `lib/kernel/diagnostics/clock.dart` | role-match |
| `lib/kernel/diagnostics/error_reporter.dart` | service | event-driven | `lib/kernel/diagnostics/kernel_logger.dart` | role-match |
| `lib/kernel/diagnostics/global_error_hooks.dart` | utility | event-driven | `lib/main.dart` | data-flow-match |
| `lib/main.dart` | config / composition root | event-driven | current `lib/main.dart` bootstrap | exact |
| `lib/kernel/player_services.dart` | service | request-response / lifecycle | current `lib/kernel/player_services.dart` | exact |
| `test/diagnostics/error_report_test.dart` | test | transform | `test/unit/kernel/diagnostics/startup_timeline_test.dart` | role-match |
| `test/diagnostics/error_reporter_test.dart` | test | event-driven | `test/diagnostics/kernel_logger_test.dart` | role-match |
| `test/diagnostics/global_error_hooks_test.dart` | test | event-driven | `test/diagnostics/kernel_logger_test.dart` | partial |

### Scope interpretation

- The Phase 1 explicit `PlayerError` intake is an API on `ErrorReporterImpl` (for example, `reportPlayerError`), not a `MediaKitEngine.lastError` subscription. Do **not** modify `lib/kernel/engine/media_kit_engine.dart` for a listener in this phase; the full notifier bridge is deferred to Phase 3.
- The current media path is read through an injected `String? Function()` snapshot provider. `PlaybackController.currentPath` remains its owner; Phase 1 does not couple generic diagnostics to `PlaybackController` or `MediaEngine`.
- Research’s proposed test paths are `test/diagnostics/`, matching the existing diagnostics test suite, rather than `test/kernel/diagnostics/`.

## Pattern Assignments

### `lib/kernel/diagnostics/error_report.dart` (model, transform)

**Analog:** `lib/kernel/models/player_error.dart`

**Imports and public-contract style** (lines 1-18):
```dart
/// 播放器结构化错误 — sealed class 层级, 支持穷举模式匹配
///
/// Structured player error — sealed class hierarchy with exhaustive pattern matching.
/// 每个子类型携带自己的子枚举 code，兼顾类型安全和细粒度错误码。
/// Each subtype carries its own code enum for type-safe, fine-grained error codes.
...
sealed class PlayerError {
```

Copy the bilingual `///` documentation style for both public enums and immutable value classes. `ErrorReport` itself should be `final class` with `const` constructor, `final` fields, and a narrow `copyWith` that creates a replacement rather than mutating a queued report.

**Error-context source pattern** (lines 57-113):
```dart
class ErrorContext {
  final String? action;
  final int? generation;
  final String? path;
  final DateTime timestamp;
  final String? module;
  final StackTrace? callbackStackTrace;

  ErrorContext({
    this.action,
    this.generation,
    this.path,
    DateTime? timestamp,
    this.module,
    this.callbackStackTrace,
  }) : timestamp = timestamp ?? DateTime.now();
}
```

For the new report contract, capture scalar snapshots (`errorType`, bounded textual `message`, textual stack snapshot, media path, timestamps, severity/source, event ID, occurrence count), not an arbitrary exception object. This differs intentionally from mutable `PlayerError.context`: reports must remain frozen after acceptance.

**Player-source mapping inputs** (lines 18-52):
```dart
sealed class PlayerError {
  String get message;
  Object? get cause;
  ErrorContext? get context;
  set context(ErrorContext? value);
  bool get isFatal;
  String get l10nKey;
}
```

`ErrorReporterImpl.reportPlayerError` should derive `fatal` from `isFatal`, copy `message`, and prefer explicit `mediaPath`, then `error.context?.path`, then the injected current-path snapshot. Do not retain `PlayerError` as a mutable report field.

---

### `lib/kernel/diagnostics/error_reporting_dependencies.dart` (utility, transform)

**Analog:** `lib/kernel/diagnostics/clock.dart`

**Small injected dependency pattern** (lines 1-36):
```dart
/// 时钟抽象 — 将 DateTime.now() 封装为可注入接口。
///
/// Abstract clock. Production code uses [SystemClock], tests use [FakeClock]
/// to control time progression without real wall-clock dependency.
abstract class Clock {
  /// 当前时间。
  DateTime now();
}

final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}
```

Reuse the existing `Clock` abstraction rather than adding a second clock type. Put only genuinely new reporter seams here: function typedefs/interfaces for process-local event ID generation, current-media-path snapshot, isolated report effects, and a final non-recursive fallback. Prefer constructor injection and production defaults, as the monitor does.

**Injectable construction precedent** (`lib/kernel/diagnostics/memory_monitor.dart`, lines 92-102):
```dart
MemoryMonitor({
  required this.rssProvider,
  required this.clock,
  this.thresholdBytes = 50 * 1024 * 1024,
  this.maxHistory = 200,
  this.interval = const Duration(seconds: 30),
  KernelLogger? logger,
  this.onTick,
}) : _logger = logger {
  _startImpl();
}
```

Apply this dependency-injection shape to testing constructors/defaults; do not reach into global static state to control time or output in unit tests.

---

### `lib/kernel/diagnostics/error_reporter.dart` (service, event-driven)

**Analog:** `lib/kernel/diagnostics/kernel_logger.dart`

**Imports and singleton lifecycle** (lines 21-27; 483-529):
```dart
library;

import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
...
final class KernelLoggerImpl extends KernelLogger {
  KernelLoggerImpl(this._sink);

  final LogSink _sink;

  static KernelLoggerImpl? _instance;

  static KernelLoggerImpl get I {
    final inst = _instance;
    if (inst == null) {
      throw StateError(
        'KernelLoggerImpl.I accessed before init(). '
        'Call KernelLoggerImpl.init() at app startup.',
      );
    }
    return inst;
  }

  static void init() {
    if (_instance != null) return;
    ...
  }

  @visibleForTesting
  static void resetForTesting() {
    _instance = null;
  }
}
```

Make `ErrorReporterImpl.I`, `init()`, and `resetForTesting()` follow this nullable-static / guarded-accessor convention. Its ordinary constructor or `forTesting` constructor must accept all seams required for deterministic tests (clock, ID source, media path provider, effects, last-resort output). `init()` must be idempotent so composition-root startup remains safe.

**Fan-out interface and collection traversal** (lines 72-89; 309-338):
```dart
abstract interface class LogSink {
  void log(
    LogLevel level,
    String msg, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  });
}
...
final class CompositeSink implements LogSink {
  CompositeSink(this._sinks);

  final List<LogSink> _sinks;

  @override
  void log(...) {
    for (final sink in _sinks) {
      sink.log(...);
    }
  }
}
```

Define a synchronous `ErrorReportEffect` seam in the dependency file and copy the injected-list iteration shape, but **improve it for this error boundary**: each effect call must be isolated with `on Object catch (error, stackTrace)`, then invoke only a non-recursive last-resort fallback. The reporter’s public intake methods must contain all normalization, notification, and effect failures so callers and global hooks return normally.

**Safe containment idiom** (lines 156-173):
```dart
try {
  final entries = value.entries.toList()..sort(...);
  return <String, Object?>{...};
} finally {
  activeContainers.remove(value);
}
```

Use `try`/`finally` to always reset `_isReporting`, including if report normalization, state publication, an effect, or a listener fails. The special `on Object` catch is limited to this reporting composition boundary; document why it is intentionally broader than ordinary application catches. The fallback must not call `ErrorReporter`, `KernelLogger`, UI, or allocate a new report.

**State and idempotency precedent** (`lib/kernel/diagnostics/startup_timeline.dart`, lines 25-60):
```dart
StartupTimeline({KernelLogger? logger}) : _logger = logger ?? KernelLogger.I;

final KernelLogger _logger;
final Map<String, int> _marks = {};
bool _reported = false;

void mark(String phase) {
  if (_reported) return;
  _marks.putIfAbsent(phase, () => _stopwatch.elapsedMilliseconds);
}
```

Expose a `ValueNotifier<ErrorPresentationState>` whose value is a new immutable snapshot whenever presentation becomes publishable. Keep the backing five-entry `ListQueue<ErrorReport>` private. `flushPresentation()` must be idempotent like `ready()`: it only transitions readiness and publishes the existing head; it must never recreate, reorder, clear, or re-deduplicate reports.

**Required policy to implement, not a legacy copy:**

- Use `ListQueue<ErrorReport>` from `dart:collection`; capacity is exactly five.
- The head is current/oldest. A sixth distinct report removes the head before appending. `dismissCurrent()` removes only head and promotes the next.
- Compare only the at-most-five queued items; do not make an unbounded fingerprint map.
- Fingerprint `(source, errorType, message, top application stack frame)`. Merge only when the same fingerprint occurs within `const Duration(seconds: 10)`; replace the matching immutable value with `copyWith(occurrenceCount: ..., lastOccurredAt: ...)`, retaining position and original event ID.
- Queue acceptance happens before UI readiness. Before flush, retain reports but do not publish a UI-facing current item. Effects still run at report acceptance.

---

### `lib/kernel/diagnostics/global_error_hooks.dart` (utility, event-driven)

**Analog:** `lib/main.dart`

**Current composition-root imports and bootstrap ordering** (lines 1-25):
```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'kernel/diagnostics/kernel_logger.dart';
import 'kernel/diagnostics/startup_timeline.dart';
import 'kernel/window_bridge/window_manager_service.dart';
...
if (kDebugMode) {
  MarionetteBinding.ensureInitialized();
} else {
  WidgetsFlutterBinding.ensureInitialized();
}

MediaKit.ensureInitialized();
KernelLoggerImpl.init();
await windowManager.ensureInitialized();
```

`GlobalErrorHooks` is a thin adapter, not an alternate application bootstrap. It should isolate Flutter/Dart static callback assignment behind injected setter/callback seams for tests, while production `install` assigns `FlutterError.onError` and `PlatformDispatcher.instance.onError` exactly once.

**Hook behavior required by phase contract:**
```dart
FlutterError.onError = (FlutterErrorDetails details) {
  // Preserve familiar debug framework diagnostics first.
  FlutterError.presentError(details);
  reporter.reportFlutterSafely(details);
};

PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
  reporter.reportPlatformSafely(error, stackTrace);
  return true;
};
```

Guard `FlutterError.presentError` independently: if it fails, use the reporter’s explicitly non-recursive last-resort seam, then still attempt safe reporter intake. Neither callback may perform I/O or await work. The dispatcher return value must remain literal `true` after safe acceptance.

---

### `lib/main.dart` (config / composition root, event-driven)

**Analog:** current `lib/main.dart`

**Existing local recovery path to preserve** (lines 27-49):
```dart
final startupTimeline = StartupTimeline();
final windowService = WindowService();
String? windowInitError;
try {
  await windowService.init();
  startupTimeline.mark(StartupTimeline.phaseInfrastructure);
} on Object catch (error, stackTrace) {
  windowInitError = '$error';
  KernelLogger.I.e(
    '[main] Window initialization failed: $error',
    error: error,
    stackTrace: stackTrace,
  );
}

runApp(
  App(
    startupTimeline: startupTimeline,
    windowService: windowService,
    windowInitError: windowInitError,
  ),
);
```

Keep this local UI-state behavior and its existing `App` arguments. Add exactly one reporter forwarding call in this local catch; do not rethrow the handled window-init error, and do not rely on the global guard to report it a second time.

**Required structural change:** place the *first executable statement* in `main` as `runZonedGuarded<Future<void>>(...);`. Move both binding branches, `MediaKit.ensureInitialized`, logger/reporter initialization, `windowManager.ensureInitialized`, hook installation, existing `try/on Object` window initialization, and `runApp` inside that one async guarded closure.

Initialize `KernelLoggerImpl` and `ErrorReporterImpl` before any later bootstrap service that could report. Assign `PlatformDispatcher.instance.onError` only inside this guarded closure, because it is associated with the registration zone. The zone `onError` callback must delegate directly to the reporter’s safe bootstrap intake and return normally.

Use current relative import style for nearby files, adding direct imports for the new diagnostics modules. Preserve `Future<void> main()`; do not introduce a second bootstrap function unless it makes the zone boundary clearer and remains wholly invoked within the guard.

---

### `lib/kernel/player_services.dart` (service, request-response / lifecycle)

**Analog:** current `lib/kernel/player_services.dart`

**Current idempotent initialization gate** (lines 104-125):
```dart
Future<void> init() {
  if (_disposed) return Future<void>.value();
  if (_initialized) return Future<void>.value();
  return _initOperation ??= _initOnce();
}

Future<void> _initOnce() async {
  try {
    KernelLoggerImpl.init();
    final memoryMonitor = MemoryMonitor(
      rssProvider: const ProcessInfoRssProvider(),
      clock: const SystemClock(),
      logger: KernelLoggerImpl.I,
    );
    MemoryMonitor.init(memoryMonitor);
```

The phase change is deliberately narrow: remove the redundant `KernelLoggerImpl.init()` from `_initOnce`, because `main` now owns the sole normal application initialization. Retain `KernelLoggerImpl.I` when injecting `MemoryMonitor`, and retain all existing initialization gates and rollback behavior. Update the initialization-order doc comment (lines 104-110) so it no longer claims the service initializes the logger.

Do not move `MemoryMonitor` ownership into `main`; it remains a service-lifecycle resource created/disposed by `PlayerServices`.

---

### `test/diagnostics/error_report_test.dart` (test, transform)

**Analog:** `test/unit/kernel/diagnostics/startup_timeline_test.dart`

**Test file setup, direct injection, and focused contract assertions** (lines 1-20):
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/diagnostics/startup_timeline.dart';

import '../../../helpers/fake_kernel_logger.dart';

/// StartupTimeline 单元测试 — 打点/收尾幂等与结构化日志字段契约。
...
void main() {
  group('StartupTimeline', () {
    test('ready 输出逐阶段差值与 totalMs，阶段字段齐全', () {
      final sink = RecordingLogSink();
      final timeline = StartupTimeline(logger: KernelLoggerImpl(sink));
```

Use package imports for production files, a short file-level Chinese/English purpose comment, `group` by public contract, and behavior-driven test names. Test immutable fields, enum/source/severity mappings, safe string/stack snapshot degradation and truncation, plus `copyWith` preserving event ID/first timestamp/original values while replacing only merge fields. Use no real engine or wall clock.

---

### `test/diagnostics/error_reporter_test.dart` (test, event-driven)

**Analog:** `test/diagnostics/kernel_logger_test.dart`

**Hand-written spy seam** (lines 6-23):
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';

/// Test spy sink that records all log calls for assertion.
class SpySink implements LogSink {
  final List<(LogLevel, String, Map<String, Object?>?)> calls = [];

  @override
  void log(
    LogLevel level,
    String msg, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    calls.add((level, msg, context));
  }
}
```

Create small local fakes/spies for effects, ID sequence, media path, and last-resort output. Prefer a `FakeClock` from the existing production `clock.dart` over `Future.delayed` or global time manipulation:

```dart
final clock = FakeClock(DateTime(2026, 8, 28));
clock.currentTime = DateTime(2026, 8, 28, 0, 0, 10);
```

**Singleton isolation convention** (lines 229-241):
```dart
group('KernelLoggerImpl lifecycle', () {
  test('I throws StateError before init() is called', () {
    KernelLoggerImpl.resetForTesting();
    expect(() => KernelLoggerImpl.I, throwsA(isA<StateError>()));
  });

  test('I returns same instance after init() (identity)', () {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
    final a = KernelLoggerImpl.I;
    final b = KernelLoggerImpl.I;
    expect(identical(a, b), isTrue);
  });
});
```

Reset `ErrorReporterImpl` in `setUp`/`tearDown` whenever static lifecycle is exercised; use an ordinary injected reporter for most policy tests. Cover all four adapters’ report normalization, player fatal/media-path mapping, FIFO five/six ordering, dismiss promotion, pre-flush retention + idempotent flush, within-window merging and post-10-second distinct append, and 100/1000 duplicate bursts. Fault-inject an effect, normalizer/provider, notifier listener, and reentrant intake; each public report method must `returnsNormally` with no recursive effect loop.

---

### `test/diagnostics/global_error_hooks_test.dart` (test, event-driven)

**Analog:** `test/diagnostics/kernel_logger_test.dart` and existing Flutter-global restoration practice in `test/ui/player/responsive_layout_test.dart` lines 180-200.

**Process-global callback restoration precedent** (`test/ui/player/responsive_layout_test.dart`, lines 180-200):
```dart
final reportedErrors = <FlutterErrorDetails>[];
final previousOnError = FlutterError.onError;
FlutterError.onError = reportedErrors.add;
addTearDown(() => FlutterError.onError = previousOnError);
...
FlutterError.onError = previousOnError;
```

Production hook installation should be setter-injectable so this test can use local callback variables rather than leave global Flutter handlers altered. Where a real global must be touched, capture and restore it with `addTearDown` immediately after assignment. Do not invoke a real `MediaKitEngine`.

Test that framework details are presented/delegated once, report intake happens once even if presentation fails, platform intake receives exact error/stack and returns `true`, and each adapter returns normally when reporter intake fails. Assert behavior through a hand-written recording reporter/fake callbacks, not mocks.

## Shared Patterns

### Singleton lifecycle and test reset
**Source:** `lib/kernel/diagnostics/kernel_logger.dart` lines 483-529; `lib/kernel/diagnostics/memory_monitor.dart` lines 41-79  
**Apply to:** `ErrorReporterImpl`, reporter tests, bootstrap wiring

```dart
static KernelLoggerImpl? _instance;

static KernelLoggerImpl get I {
  final inst = _instance;
  if (inst == null) {
    throw StateError(
      'KernelLoggerImpl.I accessed before init(). '
      'Call KernelLoggerImpl.init() at app startup.',
    );
  }
  return inst;
}

static void init() {
  if (_instance != null) return;
  _instance = KernelLoggerImpl(createDefaultLogSink(mode));
}

@visibleForTesting
static void resetForTesting() {
  _instance = null;
}
```

Use a nullable static plus guarded getter, no `late`, and idempotent startup initialization. Ensure test reset disposes the reporter’s `ValueNotifier` if it owns one, then clears the static reference.

### Injectable dependencies and deterministic time
**Source:** `lib/kernel/diagnostics/clock.dart` lines 5-36; `lib/kernel/diagnostics/memory_monitor.dart` lines 92-143  
**Apply to:** reporter creation and reporter tests

```dart
abstract class Clock {
  DateTime now();
}

final class FakeClock implements Clock {
  FakeClock([DateTime? initial]) : _now = initial ?? DateTime(2026);

  DateTime _now;

  set currentTime(DateTime t) => _now = t;

  @override
  DateTime now() => _now;
}
```

Inject production defaults at composition root and test replacements in constructors. Do not add a package or use timer delays for dedupe-window tests.

### ValueNotifier ownership and immutable replacement
**Source:** `lib/kernel/services/playback_controller.dart` lines 67-79; `lib/kernel/diagnostics/memory_monitor.dart` lines 139-143  
**Apply to:** reporter presentation state

```dart
final ValueNotifier<String?> currentPath = ValueNotifier<String?>(null);
...
final ValueNotifier<MemorySnapshot?> snapshotNotifier =
    ValueNotifier<MemorySnapshot?>(null);
```

The reporter owns one stable `ValueNotifier<ErrorPresentationState>` instance. Change its `.value` only to a fresh immutable state after a queue transition; do not replace the notifier instance and do not introduce Provider/Riverpod/Bloc.

### Player error and path snapshot boundary
**Source:** `lib/kernel/services/playback_controller.dart` lines 134-163; `lib/kernel/engine/media_kit_engine.dart` lines 163-215 and 591-598  
**Apply to:** `ErrorReporterImpl.reportPlayerError` only in Phase 1

```dart
case OpenSuccess():
  ...
  currentPath.value = path;
  return true;
case OpenError(:final error):
  onError?.call(error);
  return false;
```

```dart
_player.stream.error.listen((msg) {
  _lastError.value = UnknownError(
    msg,
    null,
    ErrorContext(action: 'stream', module: 'MediaKitEngine'),
  );
}),
```

`PlaybackController` is the path owner and `MediaKitEngine` is already the player-error producer. In Phase 1, keep diagnostics decoupled by accepting explicit `PlayerError`/path data; do not add the listener or change engine lifecycle.

### Global error containment
**Source:** current `lib/main.dart` lines 27-49 and research-defined Phase-1 boundary  
**Apply to:** `main.dart`, `global_error_hooks.dart`, `error_reporter.dart`

- `runZonedGuarded` must enclose both binding branches, hook registration, all existing bootstrap awaits, and `runApp`.
- Preserve `FlutterError.presentError(details)` before reporting framework failures.
- `PlatformDispatcher.instance.onError` must report safely and return `true`.
- Reporter intake, effect invocation, and fallback must be individually contained; fallback never re-enters logger/reporter/UI.
- Retain the local window-init UI fallback and forward it exactly once to the reporter.

## No Analog Found

| File / Concern | Role | Data Flow | Reason / Planner Direction |
|---|---|---|---|
| `lib/kernel/diagnostics/global_error_hooks.dart` | utility | event-driven | No existing project wrapper owns Flutter’s process-global error callbacks. Extract a setter-injectable thin adapter; use `main.dart` for bootstrap ordering and the research hook contract for exact Flutter behavior. |
| Reporter bounded FIFO, time-window fingerprinting, and pre-UI flush | service policy | event-driven | No existing diagnostic component has this exact queue policy. Use `ListQueue`, injected `Clock`, immutable report replacement, and the fixed Phase-1 rules rather than adapting an unrelated list/state implementation. |

## Metadata

**Analog search scope:** `lib/main.dart`, `lib/kernel/diagnostics/`, `lib/kernel/models/`, `lib/kernel/services/`, `lib/kernel/engine/`, `test/diagnostics/`, `test/unit/kernel/diagnostics/`, `test/helpers/`, existing Flutter-global callback tests  
**Files scanned/read:** 15  
**Pattern extraction date:** 2026-08-28
