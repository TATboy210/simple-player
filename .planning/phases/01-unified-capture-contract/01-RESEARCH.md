# Phase 1: 统一捕获与报告契约 - Research

**Researched:** 2026-08-28  
**Domain:** Flutter/Dart root-isolate error capture, immutable diagnostics contracts, bounded presentation queue, and failure-isolated reporting  
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### 启动组装
- **D-01:** runZonedGuarded 全包 main 体——binding 初始化（含 debug 的 MarionetteBinding 分支与 release 的 WidgetsFlutterBinding 分支，两分支同 zone）、MediaKit/KernelLogger/窗口服务初始化、钩子安装、runApp 全部在 guarded 闭包内 — **Reversibility:** reversible — 仅启动函数内的包裹结构调整
- **D-02:** ErrorReporter 用 kernel 静态单例模式（ErrorReporterImpl.I，与 KernelLoggerImpl.I 同款项目惯例），main 最早初始化；player_services 中重复的 KernelLoggerImpl.init() 调用点收敛到 main 一处 — **Reversibility:** costly — 调用方遍布各层（scanner/utils/services），改持有模式需触碰所有 KernelLoggerImpl.I 消费点同款数量的调用方

#### 启动期错误补显
- **D-03:** pre-runApp 错误由 reporter 记录，UI 挂载后自动补显卡片（flush 语义）；补显内容同样走 FIFO 与去重 — **Reversibility:** reversible — reporter 增加一个 pending-flush 列表

#### 队列与去重参数
- **D-04:** FIFO 容量 5 条，超出丢最旧（已落盘证据不丢）；去重为时间窗合并（同指纹错误在窗口内合并计数，超窗视为新错误）——具体窗口时长由 planner 依研究结论定（研究建议"短窗"，产品语义已锁定为时间窗合并而非永久合并） — **Reversibility:** reversible — 常量调整

### Claude's Discretion
- 指纹字段构成（类型/消息/来源/顶部应用帧——研究已建议，planner 细化）
- 严重级枚举命名（warning/error/fatal 文本语义已定）
- 重复 init 收敛的具体实现方式
- reporter 呈现状态的 notifier 具体形态（ValueNotifier<ErrorPresentationState> 不可变状态，研究已建议）

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

## Project Constraints (from CLAUDE.md)

- Use `ValueNotifier + ValueListenableBuilder`; do not add a state-management package. [VERIFIED: D:/simple_player_flutter/CLAUDE.md:88-93]
- Keep `media_kit` unchanged; implement only project wrapper/UI/test layers. [VERIFIED: D:/simple_player_flutter/.claude/CLAUDE.md:12-16]
- Maintain `flutter analyze` with zero errors and a green `flutter test` suite. [VERIFIED: D:/simple_player_flutter/.claude/CLAUDE.md:12-16]
- Kernel code must not call `debugPrint()`; it must use `KernelLogger`, except a documented non-recursive last-resort boundary that must not enter the logger/reporter chain again. The existing CI guidance is: `grep -rn 'debugPrint(' lib/kernel/ | grep -v kernel_logger.dart | grep -v '//'`. [VERIFIED: D:/simple_player_flutter/analysis_options.yaml:21-24]
- Public classes and non-trivial functions require bilingual `///` documentation; side effects and non-obvious logic require inline rationale comments. [VERIFIED: D:/simple_player_flutter/.claude/CLAUDE.md:167-177]
- Use `final` locals, avoid `!`, `late`, and `as`, specify exception types, and do not use a bare `catch (e)`. [VERIFIED: D:/simple_player_flutter/.claude/CLAUDE.md:203-208; D:/simple_player_flutter/.claude/CLAUDE.md:241-245]
- Functions must remain under 50 lines and files under 500 lines; split the reporter into cohesive model/policy/hook files rather than a monolith. [VERIFIED: D:/simple_player_flutter/.claude/CLAUDE.md:179-188]
- No project skills directory or `SKILL.md` was present during this research. [VERIFIED: project skill discovery command, 2026-08-28]

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CAP-01 | 四类错误源（FlutterError.onError 框架异常、PlatformDispatcher.onError 异步未捕获、runZonedGuarded 启动兜底、PlayerError 引擎错误）统一归一化为同一不可变 ErrorReport 契约（时间戳/严重级/错误/栈/媒体路径快照/event ID） | Defines `ErrorReport`, source/severity mapping, safe normalization, media snapshot seam, and fourth-source intake point. |
| CAP-02 | 三全局钩子在启动时于同一 guarded zone 内安装，保留 FlutterError.presentError 调试输出，dispatcher 处理后返回 true | Gives exact bootstrap ordering, thin hook rules, same-zone condition, and hook-installer test seam. |
| CAP-03 | ErrorReporter 为唯一 fan-in/fan-out 服务，入口不抛异常（reentrancy-safe），副作用逐一隔离，故障注入测试覆盖 | Defines singleton lifecycle, independent effects, recursion guard, safe fallback, and failure-injection matrix. |
| CAP-04 | 有界 FIFO 队列 + 指纹去重（类型/消息/来源/顶部应用帧），重复错误合并计数，关闭卡片推进队列不删证据 | Fixes capacity at five, recommends a 10-second window, bounded fingerprint strategy, duplicate replacement, dismiss/flush semantics, and burst tests. |
</phase_requirements>

## Summary

Phase 1 should add a compact, kernel-owned diagnostic core: immutable report values, a static `ErrorReporterImpl.I`, a bounded FIFO presentation policy, and thin adapters for the three global Flutter/Dart boundaries plus an explicit player-error intake method. It must not add file persistence, source-line enrichment, the error card, or the complete `lastError` listener bridge; those belong to later phases. The reporter is therefore the only application fan-in/fan-out boundary now, while Phase 2 can attach durable file effects and Phase 3 can attach the player bridge and card host. [VERIFIED: D:/simple_player_flutter/.planning/phases/01-unified-capture-contract/01-CONTEXT.md:7-10]

Use a five-item deque that contains the active report at its head and pending reports behind it. A duplicate replaces its existing immutable item in-place with an incremented `occurrenceCount` and a later `lastOccurredAt`, preserving its original `eventId`, FIFO position, and first occurrence. Choose a **10-second** injectable monotonic-clock window: it is short enough to collapse a repeated callback storm while allowing a persistent failure to reappear as a fresh item once the immediate burst has passed. The exact duration is a product-policy recommendation, not a framework fact. [ASSUMED]

Keep every hook synchronous and minimal: preserve `FlutterError.presentError(details)`, hand normalized primitive data to `ErrorReporter`, and return `true` from the dispatcher handler after the reporter has accepted the event. Flutter documents that framework callback failures route to `FlutterError.onError`, while asynchronous failures outside a Flutter callback route through `PlatformDispatcher.instance.onError`; its official example returns `true` to mark the dispatcher error handled. [CITED: https://docs.flutter.dev/testing/errors]

**Primary recommendation:** Build `ErrorReport` + `ErrorReporterImpl` + `GlobalErrorHooks` as small, independently tested kernel components, initialize them first inside one `runZonedGuarded` bootstrap closure, and use an injected five-item FIFO/dedupe policy rather than putting queue or error-normalization logic in `main.dart` or the future UI.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Framework and root-isolate error capture | Frontend Server (Flutter composition root) | API / Backend (kernel diagnostics) | `main.dart` owns process-wide hook registration; the reporter owns normalization and policy. [CITED: https://docs.flutter.dev/testing/errors] |
| Bootstrap fallback capture | Frontend Server (Flutter composition root) | API / Backend (kernel diagnostics) | The guarded zone encloses the complete startup path; its callback delegates immediately to the reporter. [CITED: https://dart.dev/libraries/async/zones] |
| Report normalization, IDs, severity, snapshots, dedupe, FIFO | API / Backend (kernel diagnostics) | — | This is app business/diagnostic policy, independent of widgets and media-engine implementation. [ASSUMED] |
| Current media-path snapshot | API / Backend (playback facade) | API / Backend (diagnostics provider seam) | `PlaybackController` owns active path state and exposes it as a notifier; diagnostics reads only an injected snapshot provider. [VERIFIED: D:/simple_player_flutter/lib/kernel/services/playback_controller.dart:67-79] Quote: `final ValueNotifier<String?> currentPath = ValueNotifier<String?>(null);` |
| Player error reporting seam | API / Backend (engine wrapper / future feature bridge) | API / Backend (kernel diagnostics) | `MediaEngine` exposes the engine error notifier; Phase 1 adds an explicit intake only, and Phase 3 owns the subscription bridge. [VERIFIED: D:/simple_player_flutter/lib/kernel/engine/media_kit_engine.dart:74-77; 138-143] Quote: `final ValueNotifier<PlayerError?> _lastError = ValueNotifier<PlayerError?>(null);` and `ValueNotifier<PlayerError?> get lastError => _lastError;` |
| Presentation flush and eventual card | Browser / Client (Flutter UI) | API / Backend (reporter) | The UI announces readiness after mount; reporter remains owner of queue progression and immutable presentation state. [ASSUMED] |

## Standard Stack

### Core

| Library / API | Version | Purpose | Why Standard |
|---------------|---------|---------|--------------|
| Flutter `FlutterError.onError` | Flutter SDK 3.47.1 available locally | Capture exceptions already caught by Flutter framework callbacks and retain debug presentation. [CITED: https://docs.flutter.dev/testing/errors] | Flutter documents this as the framework error-handler boundary. [CITED: https://docs.flutter.dev/testing/errors] |
| Flutter `PlatformDispatcher.instance.onError` | Flutter SDK 3.47.1 available locally | Capture uncaught root-isolate asynchronous errors outside Flutter callbacks. [CITED: https://docs.flutter.dev/testing/errors] | Flutter documents it as the complementary handler and its example returns `true` after handling. [CITED: https://docs.flutter.dev/testing/errors] |
| Dart `runZonedGuarded` | Dart SDK 3.13.1 available locally | Guard the complete startup closure as a fallback boundary. [CITED: https://dart.dev/libraries/async/zones] | Dart documents that asynchronous errors remain within their originating error zone, so it is a narrow startup guard rather than the only capture mechanism. [CITED: https://dart.dev/libraries/async/zones] |
| `ValueNotifier<ErrorPresentationState>` | Flutter SDK 3.47.1 available locally | Expose immutable active/pending state without a new state library. [VERIFIED: D:/simple_player_flutter/CLAUDE.md:88-93] | Required by the project’s established state-management convention. [VERIFIED: D:/simple_player_flutter/CLAUDE.md:88-93] |
| Existing `KernelLoggerImpl` | In-repo | Existing singleton/logger facade used as an isolated report effect in this phase and extended by Phase 2. [VERIFIED: D:/simple_player_flutter/lib/kernel/diagnostics/kernel_logger.dart:483-529] | The implementation already follows the required nullable-static singleton lifecycle. [VERIFIED: D:/simple_player_flutter/lib/kernel/diagnostics/kernel_logger.dart:489-519] |

### Supporting

| Library / API | Version | Purpose | When to Use |
|---------------|---------|---------|-------------|
| `dart:collection` `ListQueue` | Dart SDK | Bounded FIFO operations without hand-rolled linked-list bookkeeping. [ASSUMED] | Use internally for five queued report envelopes. |
| `dart:developer.log` | Dart SDK | Non-recursive last-resort diagnostic fallback, wrapped so it cannot escape the reporter. [ASSUMED] | Use only after reporter/logger/effect failure; do not feed it back into `ErrorReporter` or `KernelLogger`. |
| `fake_async` | Existing dev dependency `^1.3.1` | Deterministic dedupe-window tests without waiting for wall time. [VERIFIED: D:/simple_player_flutter/pubspec.yaml:46-57] Quote: `fake_async: ^1.3.1` | Use only if the policy accepts a clock abstraction or scheduled flush behavior is tested. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| First-party three-boundary capture | Zone-only catch-all | Do not use zone-only handling: Flutter distinguishes framework callback errors from asynchronous errors outside Flutter callbacks. [CITED: https://docs.flutter.dev/testing/errors] |
| App-owned five-entry `ListQueue` policy | An unbounded event history/state library | Do not introduce either: the locked policy is bounded FIFO and the project prohibits a new state-management library. [VERIFIED: D:/simple_player_flutter/.planning/phases/01-unified-capture-contract/01-CONTEXT.md:22-24; D:/simple_player_flutter/CLAUDE.md:88-93] |
| Explicit future player bridge intake | Making `ErrorReporter` import `MediaEngine` / `PlaybackController` | Do not couple generic diagnostics to player lifecycle; inject a `String? Function()` snapshot provider and add the listener at the feature composition boundary in Phase 3. [ASSUMED] |

**Installation:** No packages are installed in Phase 1. [VERIFIED: D:/simple_player_flutter/pubspec.yaml:9-57]

## Architecture Patterns

### System Architecture Diagram

```text
 Flutter framework callbacks                 root-isolate async failures
            │                                            │
 FlutterError.onError                         PlatformDispatcher.onError
   ├─ FlutterError.presentError(details)                 ├─ report accepted
   └──────────────────────────┬─────────────────────────┘  └─ return true
                              │
 guarded bootstrap error ─────┼──── explicit PlayerError intake (no listener yet)
 runZonedGuarded onError      │
                              v
               ErrorReporterImpl.I  [kernel, no UI imports]
        normalize → safe snapshots → fingerprint → 5-entry FIFO
                 │                  │                 │
                 │                  │                 └─ flush when UI announces ready
                 │                  │                         │
                 │                  └─ duplicate: replace immutable item,
                 │                     count + last timestamp only
                 v
        each isolated report effect (Phase 1: existing logger/spy seam)
                 │
                 └─ failure → one non-recursive last-resort fallback

 Future Phase 2: durable file effect      Future Phase 3: ErrorCardHost listener
```

### Recommended Project Structure

```text
lib/
├── main.dart                                      # guarded composition root + hook install
└── kernel/
    └── diagnostics/
        ├── error_report.dart                      # immutable models, enums, copyWith
        ├── error_reporter.dart                    # singleton, queue, dedupe, effects
        ├── error_reporting_dependencies.dart      # Clock, ID, media-path, effect typedefs
        └── global_error_hooks.dart                # thin Flutter/Dart adapters/test seam

test/
└── diagnostics/
    ├── error_report_test.dart
    ├── error_reporter_test.dart
    └── global_error_hooks_test.dart
```

Do not place the generic reporter under `features/player/`, and do not add the full `engine.lastError` listener in Phase 1. The existing engine’s notifier is the future bridge input; the phase boundary explicitly defers complete connection to Phase 3. [VERIFIED: D:/simple_player_flutter/.planning/phases/01-unified-capture-contract/01-CONTEXT.md:7-10]

### Pattern 1: Immutable report plus immutable presentation snapshot

**What:** Define an immutable report value and replace—not mutate—the notifier’s `ErrorPresentationState` on queue changes. Each queued item is an `ErrorReport`; duplicate merging produces `existing.copyWith(...)`.

**When to use:** For all four error sources and all current/future effects.

**Recommended contract:**

```dart
/// 统一错误来源；每个值仅描述捕获边界，不描述展示或存储策略。
enum ErrorSource {
  flutterFramework,
  platformDispatcher,
  guardedZone,
  playerEngine,
}

/// 用户可见严重级；PlayerError 的 fatal 标记映射为 fatal，其余引擎错误为 error。
enum ErrorSeverity { warning, error, fatal }

/// 已冻结的诊断事件；所有字段在构造后不可变。
final class ErrorReport {
  const ErrorReport({
    required this.eventId,
    required this.source,
    required this.severity,
    required this.firstOccurredAt,
    required this.lastOccurredAt,
    required this.errorType,
    required this.message,
    required this.rawStackTrace,
    required this.mediaPath,
    required this.occurrenceCount,
  });

  final String eventId;
  final ErrorSource source;
  final ErrorSeverity severity;
  final DateTime firstOccurredAt;
  final DateTime lastOccurredAt;
  final String errorType;
  final String message;
  final String rawStackTrace;
  final String? mediaPath;
  final int occurrenceCount;

  ErrorReport copyWith({
    DateTime? lastOccurredAt,
    int? occurrenceCount,
  }) => ErrorReport(
    eventId: eventId,
    source: source,
    severity: severity,
    firstOccurredAt: firstOccurredAt,
    lastOccurredAt: lastOccurredAt ?? this.lastOccurredAt,
    errorType: errorType,
    message: message,
    rawStackTrace: rawStackTrace,
    mediaPath: mediaPath,
    occurrenceCount: occurrenceCount ?? this.occurrenceCount,
  );
}
```

The enum spelling and the report’s field names are prescriptive Phase-1 recommendations, not existing project values. [ASSUMED] The source list maps exactly to the required four input classes: `FlutterError.onError`, `PlatformDispatcher.onError`, `runZonedGuarded`, and `PlayerError`. [VERIFIED: D:/simple_player_flutter/.planning/REQUIREMENTS.md:8-14] Quote: `FlutterError.onError 框架异常、PlatformDispatcher.onError 异步未捕获、runZonedGuarded 启动兜底、PlayerError 引擎错误`.

Use `errorType` and a safely obtained textual `message` rather than retaining a mutable arbitrary exception object in the immutable report. Preserve a non-empty string stack snapshot; when Flutter supplies no stack, record a clear unavailable/fallback marker without claiming it is the original throw-site stack. Flutter’s `FlutterErrorDetails.stack` may be absent, so the model must handle that degradation. [CITED: https://api.flutter.dev/flutter/foundation/FlutterErrorDetails/stack.html]

### Pattern 2: Five-entry FIFO is the presentation backlog, not the evidence store

**What:** Maintain one deque where index/head zero is the current report and later entries are pending. `dismissCurrent()` removes only the head, then publishes the next queued report. At capacity, a *new distinct* report removes the oldest/head before appending the new one, exactly matching D-04. Duplicate updates retain position.

**When to use:** Before UI exists, after it mounts, and when it is disabled in later phases.

**Policy details:**

1. Generate a report group ID from an injected process-local sequence plus clock value, such as `error-<micros>-<sequence>`; never reuse the ID when a new distinct item enters the queue. [ASSUMED]
2. Fingerprint exactly `(source, errorType, message, topApplicationFrame)`. Derive `topApplicationFrame` by taking the first stack line containing `package:simple_player_flutter/`; if none exists, use the first nonblank stack line with a stable `fallback:` prefix. Cap the chosen line at 512 characters before hashing/comparing. [ASSUMED]
3. Compare only existing five queued records. If the fingerprint matches and `now - existing.lastOccurredAt <= const Duration(seconds: 10)`, update that report’s count and `lastOccurredAt`; do not append or change its `eventId`. [ASSUMED]
4. If no matching in-window entry exists, append a new report; if all five slots are occupied, remove the oldest before append. [VERIFIED: D:/simple_player_flutter/.planning/phases/01-unified-capture-contract/01-CONTEXT.md:22-24] Quote: `FIFO 容量 5 条，超出丢最旧`.
5. Keep report effects independent from this UI queue. A queue eviction is not a durable-evidence operation; Phase 2’s file effect is the component that makes the D-04 statement “已落盘证据不丢” true. [VERIFIED: D:/simple_player_flutter/.planning/phases/01-unified-capture-contract/01-CONTEXT.md:22-24] Quote: `超出丢最旧（已落盘证据不丢）`.

Do **not** keep an unbounded `Map<String, DateTime>` fingerprint cache. The five queue entries already bound memory, and the planned source/stack strings should have an explicit maximum length before storage. The length policy is a recommended defensive constraint; set the exact maximum in the plan/tests. [ASSUMED]

### Pattern 3: Flush is an idempotent presentation-readiness transition

**What:** Reports created before `runApp` enter the same five-entry deque but presentation publication remains inactive. The future root card host calls `ErrorReporter.I.flushPresentation()` in its first post-frame callback; the reporter then publishes a new immutable state whose current item is the existing deque head. Reports arriving after readiness publish immediately.

**When to use:** All pre-`runApp` failures, including window initialization failures already handled by `main.dart`.

**Required semantics:**

- `flushPresentation()` is idempotent and never clears, recreates, reorders, or re-deduplicates records. [ASSUMED]
- While not ready, `dismissCurrent()` still updates queue state safely but does not synchronously notify a UI that does not exist. [ASSUMED]
- The caller must invoke the readiness method from the UI mounting boundary, not `main.dart`; Phase 1 has no card/root host capable of knowing its own first frame. [ASSUMED]
- Phase 3 must use `WidgetsBinding.instance.addPostFrameCallback` when it attaches the card host, so a framework build failure does not cause a synchronous UI notification during the failing build. Flutter’s framework catches build/layout/paint errors through `FlutterError.onError`; synchronous notifier publication from that handler is therefore unsafe for a future card host. [CITED: https://docs.flutter.dev/testing/errors]

### Pattern 4: Reentrancy guard plus independently isolated effects

**What:** The reporter’s public intake methods never throw. A private `_isReporting` guard prevents the reporter from recursively attempting to report a failure caused by report construction, a notifier listener, or an effect. Each effect is invoked in its own protected block so one failing effect does not suppress others.

**When to use:** Every public `report…` method, every global callback, and every future file/card/copy effect.

**Implementation rules:**

```dart
void reportCapturedError(CapturedError input) {
  if (_isReporting) {
    _emitLastResort('Suppressed reentrant error report.');
    return;
  }

  _isReporting = true;
  try {
    final result = _accept(input); // normalise, snapshot, dedupe, enqueue
    for (final effect in _effects) {
      try {
        effect(result.report);
      } on Object catch (error, stackTrace) {
        _emitLastResort('Error-report effect failed: $error', stackTrace);
      }
    }
  } on Object catch (error, stackTrace) {
    _emitLastResort('ErrorReporter failed: $error', stackTrace);
  } finally {
    _isReporting = false;
  }
}
```

The `on Object catch` instances above are a narrow composition-boundary exception to the ordinary “do not catch Error subtypes” convention: success criterion 4 explicitly requires reporter-side faults not to create a new application fault. Each catch must be named, documented as a last-resort containment boundary, and must only invoke a fallback that cannot re-enter `ErrorReporter` or `KernelLogger`. [VERIFIED: D:/simple_player_flutter/.planning/ROADMAP.md:28-32] Quote: `报告服务、其任一副作用或错误处理重入发生故障时，播放器不会因错误反馈链再次崩溃。`

`_emitLastResort` should attempt one minimal `dart:developer.log` call inside its own final containment guard and otherwise intentionally stop. It must not use `debugPrint()` from `lib/kernel/`, must not call `ErrorReporter`, must not call a potentially failing `KernelLogger` effect, must not schedule UI work, and must not allocate another `ErrorReport`. This is a failure-isolation design recommendation. [ASSUMED]

### Pattern 5: Exact startup assembly and hook ownership

**What:** `main` establishes the guarded zone first, then initializes existing logger and reporter before services that can fail, initializes either binding branch inside that same zone, installs hooks inside that zone, and starts the rest of the existing bootstrap before `runApp`.

**Why:** Dart error-zone documentation says asynchronous errors are contained in their originating error zone and can fail to reach an outside handler. [CITED: https://dart.dev/libraries/async/zones] The current app initializes a binding before `MediaKit`, initializes `KernelLoggerImpl`, awaits window setup, and calls `runApp` later. [VERIFIED: D:/simple_player_flutter/lib/main.dart:16-49]

**Prescriptive ordering:**

```dart
void main() {
  runZonedGuarded<Future<void>>(
    () async {
      // Keep all Flutter binding/runApp work in this guarded zone.
      KernelLoggerImpl.init();
      ErrorReporterImpl.init(
        currentMediaPath: () => null,
      );

      if (kDebugMode) {
        MarionetteBinding.ensureInitialized();
      } else {
        WidgetsFlutterBinding.ensureInitialized();
      }

      GlobalErrorHooks.install(ErrorReporterImpl.I);
      MediaKit.ensureInitialized();
      // Preserve the existing window initialization try/on Object boundary.
      // Construct App and call runApp here, still in this guarded closure.
    },
    (Object error, StackTrace stackTrace) {
      ErrorReporterImpl.reportBootstrapSafely(error, stackTrace);
    },
  );
}
```

This skeleton is intentionally not a copy-paste implementation: the current `App` construction requires the already-created `StartupTimeline`, `WindowService`, and `windowInitError` arguments. [VERIFIED: D:/simple_player_flutter/lib/main.dart:27-49] The ordering rule is that both `MarionetteBinding.ensureInitialized()` and `WidgetsFlutterBinding.ensureInitialized()` branches, hook assignment, all asynchronous bootstrap work, and `runApp` remain inside the one guarded closure as D-01 requires. [VERIFIED: D:/simple_player_flutter/.planning/phases/01-unified-capture-contract/01-CONTEXT.md:16-18] Quote: `runZonedGuarded 全包 main 体——binding 初始化（含 debug 的 MarionetteBinding 分支与 release 的 WidgetsFlutterBinding 分支，两分支同 zone）、MediaKit/KernelLogger/窗口服务初始化、钩子安装、runApp 全部在 guarded 闭包内`.

`GlobalErrorHooks.install` must do the following, with no I/O or `await` in either callback:

```dart
FlutterError.onError = (FlutterErrorDetails details) {
  try {
    FlutterError.presentError(details);
  } on Object catch (error, stackTrace) {
    ErrorReporterImpl.emitLastResortSafely(error, stackTrace);
  }
  ErrorReporterImpl.reportFlutterSafely(details);
};

PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
  ErrorReporterImpl.reportPlatformSafely(error, stackTrace);
  return true;
};
```

Flutter’s official guidance shows `FlutterError.presentError(details)` in a custom framework handler, and says errors outside a Flutter callback are forwarded to `PlatformDispatcher.instance.onError`; returning `true` marks that error handled. [CITED: https://docs.flutter.dev/testing/errors] The dispatcher handler must be assigned *inside* the guarded closure because the handler is associated with the zone active at registration. [CITED: https://api.flutter.dev/flutter/dart-ui/PlatformDispatcher/onError.html]

Do not replace `main`’s existing window initialization failure path with a generic global hook. It currently catches an `Object`, preserves a `windowInitError` string, and logs the original error/stack before calling `runApp`; retain that UI startup-state contract while additionally forwarding its evidence through the reporter, using a local one-time path so the same thrown window initialization error is not reported twice. [VERIFIED: D:/simple_player_flutter/lib/main.dart:30-41] Quote: `String? windowInitError;` and `} on Object catch (error, stackTrace) {`.

### Pattern 6: Player-error source maps through a generic explicit intake

**What:** Add a `reportPlayerError(PlayerError error, {String? mediaPath})` API or an adapter that converts `PlayerError` into generic `CapturedError`; do not attach an engine listener in this phase.

**Mapping:** `PlayerError.isFatal == true` maps to `ErrorSeverity.fatal`; otherwise map to `ErrorSeverity.error`. The project-defined values are: `bool get isFatal;`, `String get message;`, `Object? get cause;`, and `ErrorContext? get context;`. [VERIFIED: D:/simple_player_flutter/lib/kernel/models/player_error.dart:18-52] Quote: `bool get isFatal;`, `String get message;`, `Object? get cause;`, and `ErrorContext? get context;`.

If a bridge caller supplies `mediaPath`, snapshot that parameter. Otherwise use the injected `currentMediaPath()` at report construction time. The active-path owner only writes `currentPath.value = path` on `OpenSuccess`; an `OpenError` thus requires the future Phase-3 bridge/call boundary to pass the attempted path explicitly rather than guessing. [VERIFIED: D:/simple_player_flutter/lib/kernel/services/playback_controller.dart:143-163] Quote: `case OpenSuccess():` and `currentPath.value = path;` and `case OpenError(:final error):`.

## Don’t Hand-Roll

| Problem | Don’t Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Framework callback capture | Custom widget-tree-wide `try/catch` wrappers | `FlutterError.onError` | Flutter routes framework-triggered callback failures to this handler. [CITED: https://docs.flutter.dev/testing/errors] |
| Root-isolate async capture | A Zone-only application exception mechanism | `PlatformDispatcher.instance.onError` plus the narrow zone guard | Flutter documents dispatcher handling for asynchronous errors outside Flutter callbacks. [CITED: https://docs.flutter.dev/testing/errors] |
| FIFO container | Custom linked list/index bookkeeping | `ListQueue<ErrorReport>` | The SDK collection provides queue semantics; capacity policy stays in a small explicit method. [ASSUMED] |
| State-management architecture | Provider/Riverpod/Bloc/event bus | Existing `ValueNotifier<ErrorPresentationState>` | The project locks `ValueNotifier + ValueListenableBuilder` and prohibits a new state library. [VERIFIED: D:/simple_player_flutter/CLAUDE.md:88-93] |
| Durable file logging | A direct write from global hooks | A Phase-2 `KernelLogger` effect/file sink | This phase explicitly excludes file persistence; direct writes create a recursive I/O failure path. [VERIFIED: D:/simple_player_flutter/.planning/phases/01-unified-capture-contract/01-CONTEXT.md:7-10] |

**Key insight:** Capture, queue policy, and future effects are separate filters. A hook should only adapt input; the reporter owns immutable normalization and acknowledgement state; effects own their own failure containment. [ASSUMED]

## Common Pitfalls

### Pitfall 1: Treating the zone as the only global handler

**What goes wrong:** Framework build/layout/paint failures and asynchronous errors outside framework callbacks use different routes, so a zone-only implementation has gaps. [CITED: https://docs.flutter.dev/testing/errors]

**How to avoid:** Install all three boundaries; preserve local error handling for expected operations, and direct each boundary to the same reporter. Dart documents that errors do not leave their originating error zone, so do not pass erroring startup futures across error-zone boundaries. [CITED: https://dart.dev/libraries/async/zones]

### Pitfall 2: Binding/runApp zone mismatch

**What goes wrong:** Moving only `runApp` into `runZonedGuarded` leaves binding initialization in another zone, violating D-01’s explicit same-zone decision. [VERIFIED: D:/simple_player_flutter/.planning/phases/01-unified-capture-contract/01-CONTEXT.md:16-18] Quote: `binding 初始化（含 debug 的 MarionetteBinding 分支与 release 的 WidgetsFlutterBinding 分支，两分支同 zone）`.

**How to avoid:** The first executable statement in `main` invokes `runZonedGuarded`; both binding branches and all remaining bootstrap work occur inside its closure. In debug verification, turn on Flutter’s zone-mismatch fatal diagnostic before binding initialization if the API is available in the pinned SDK. [ASSUMED]

### Pitfall 3: Error reporting creates a second failure or loop

**What goes wrong:** A sink, formatter, or listener throws while an error handler is active; allowing it to escape can make the feedback chain the new crash source. [VERIFIED: D:/simple_player_flutter/.planning/ROADMAP.md:28-32] Quote: `报告服务、其任一副作用或错误处理重入发生故障时，播放器不会因错误反馈链再次崩溃。`

**How to avoid:** Use `_isReporting`, isolate each effect, and use a last-resort output that never re-enters reporter/logger/UI. Test an effect that throws and a notifier listener that throws. [ASSUMED]

### Pitfall 4: Dedupe that loses ordering or grows forever

**What goes wrong:** A global fingerprint `Set` hides all future occurrences or leaks for long-running playback. [ASSUMED]

**How to avoid:** Compare against only the at-most-five queued reports, merge only inside the 10-second window, and replace the matching immutable report in its existing FIFO slot. [ASSUMED]

### Pitfall 5: Calling UI publication during a failed build

**What goes wrong:** Future `ValueListenableBuilder` card hosts can receive a synchronous notifier update while Flutter is processing the failing build, producing a secondary build-state error. [ASSUMED]

**How to avoid:** Record/enqueue immediately but gate UI-facing publication behind `flushPresentation()`/post-frame integration in Phase 3. Do not defer capture, ID generation, dedupe, or isolated logger effects. [ASSUMED]

### Pitfall 6: Duplicate startup reports

**What goes wrong:** The local `windowService.init()` catch, guarded-zone handler, and a global handler can all forward the same exception. The current local path already catches and logs window initialization failure. [VERIFIED: D:/simple_player_flutter/lib/main.dart:30-41]

**How to avoid:** Keep the local window UI-state catch, forward once through a designated reporter call, and do not rethrow that handled error. The fingerprint also dampens accidental duplicate input but must not be the primary correctness mechanism. [ASSUMED]

## Code Examples

### Safe effect seam and presentation state

```dart
/// A synchronous isolated side effect; Phase 2 and 3 register file/card effects.
typedef ErrorReportEffect = void Function(ErrorReport report);

/// Immutable snapshot consumed later by a ValueListenableBuilder card host.
final class ErrorPresentationState {
  const ErrorPresentationState({
    required this.current,
    required this.pendingCount,
    required this.isReady,
  });

  final ErrorReport? current;
  final int pendingCount;
  final bool isReady;
}
```

This follows the project’s `ValueNotifier` convention; the particular `ErrorPresentationState` shape is a Phase-1 recommendation for planner implementation. [VERIFIED: D:/simple_player_flutter/CLAUDE.md:88-93] [ASSUMED]

### Test-only reporter construction

```dart
final clock = _FakeClock(DateTime.utc(2026, 8, 28));
final delivered = <ErrorReport>[];
final reporter = ErrorReporterImpl.forTesting(
  clock: clock.now,
  currentMediaPath: () => r'D:\media\demo.mp4',
  effects: [delivered.add],
);

reporter.reportPlatform(
  StateError('decoder callback failed'),
  StackTrace.fromString('package:simple_player_flutter/kernel/test.dart:10'),
);
```

Inject a clock, ID source, media provider, and effect list rather than changing static state or relying on wall time. The project already tests injectable sinks through `KernelLoggerImpl(this._sink)` and resets its singleton with `KernelLoggerImpl.resetForTesting()`. [VERIFIED: D:/simple_player_flutter/lib/kernel/diagnostics/kernel_logger.dart:483-529] Quote: `KernelLoggerImpl(this._sink);` and `static void resetForTesting() {`.

## State of the Art

| Old / unsafe approach | Current recommended approach | Impact |
|-----------------------|------------------------------|--------|
| `runZonedGuarded` as sole global handler | `FlutterError.onError` plus `PlatformDispatcher.onError`, with guarded startup fallback | Covers Flutter framework callbacks and root-isolate async routing separately. [CITED: https://docs.flutter.dev/testing/errors] |
| Direct UI/file work inside global callbacks | Thin capture adapter → failure-isolated application reporter | Makes fault injection and recursion prevention practical. [ASSUMED] |
| Unbounded error list or permanent fingerprint set | Five-entry FIFO plus time-window merge | Preserves user acknowledgement order while bounding memory. [VERIFIED: D:/simple_player_flutter/.planning/phases/01-unified-capture-contract/01-CONTEXT.md:22-24] |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A 10-second dedupe window is the appropriate initial “short window.” | Summary / FIFO policy | May be too noisy or too aggressive for real engine faults; tune without changing architecture. |
| A2 | `ErrorSource` names `flutterFramework`, `platformDispatcher`, `guardedZone`, `playerEngine` and `ErrorSeverity` names `warning`, `error`, `fatal` are suitable public API names. | Contract | Public naming changes become costly once Phases 2–5 depend on them. |
| A3 | A process-local clock-plus-sequence event ID meets the required event-ID semantics. | FIFO policy | If cross-session uniqueness becomes required, the generator must change. |
| A4 | A five-entry deque can serve as both pre-UI pending list and post-UI active/pending queue. | Flush semantics | An unforeseen UI requirement may demand a distinct backing store, although D-03 still remains implementable. |
| A5 | `dart:developer.log` is the safest non-recursive last-resort fallback within the project’s kernel logging restriction. | Reentrancy | A platform/build mode could make it unavailable or unsuitable; fallback must remain best-effort and silent after containment. |
| A6 | First `package:simple_player_flutter/` stack line, with first-nonblank fallback, is sufficient for Phase-1 fingerprinting before Phase-2 location parsing. | FIFO policy | Equivalent errors with differing wrapper frames could fail to merge or unrelated errors could merge. |

## Open Questions

1. **Should the current active report be evicted when the five-item FIFO overflows?**
   - What we know: D-04 explicitly says capacity five and “超出丢最旧”; the active report is logically the oldest/head. [VERIFIED: D:/simple_player_flutter/.planning/phases/01-unified-capture-contract/01-CONTEXT.md:22-24] Quote: `FIFO 容量 5 条，超出丢最旧`.
   - Recommendation: Implement literal head eviction and document it in the card’s future queued-count presentation; do not invent a sixth active slot. [ASSUMED]

2. **How should Phase 1 expose an engine-error source without prematurely creating the Phase-3 bridge?**
   - What we know: `MediaEngine` provides `lastError`, and the phase boundary says only an explicit intake point belongs now. [VERIFIED: D:/simple_player_flutter/lib/kernel/engine/media_kit_engine.dart:138-143; D:/simple_player_flutter/.planning/phases/01-unified-capture-contract/01-CONTEXT.md:7-10]
   - Recommendation: Add and test `reportPlayerError`; defer listener lifecycle, failed-open attempted-path forwarding, and old `ErrorBanner` migration to Phase 3. [ASSUMED]

3. **Will a report effect be required to run once per duplicate occurrence in Phase 2?**
   - What we know: Phase 1 only requires duplicate count merging and queue semantics; Phase 2 owns file evidence. [VERIFIED: D:/simple_player_flutter/.planning/REQUIREMENTS.md:10-14; 21-27]
   - Recommendation: Define a `ReportAcceptance` disposition now (`new`, `merged`, `dropped`, `reentrantSuppressed`) so Phase 2 can decide whether to append a bounded repeat-summary without changing public reporter APIs. [ASSUMED]
   - **RESOLVED (2026-08-28, plan-phase final iteration):** Effects fire on every accepted capture/merge — each accepted report (new append, merged in-slot replacement, or post-window new append) dispatches its effects carrying the `ReportAcceptance` disposition, while `dropped` (head eviction) and `reentrantSuppressed` intakes dispatch no effects. This is consistent with D-04's merge-count semantics and lets Phase 2 add a bounded repeat-summary effect for merged occurrences without changing public reporter APIs. Test assertion recorded in 01-01-PLAN.md Task 2 acceptance_criteria.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Flutter CLI | Analyze and tests | ✓ | `3.47.1` | — |
| Dart SDK | Reporter/kernel compilation | ✓ | `3.13.1` | — |
| Existing Flutter SDK APIs | Global hooks and `ValueNotifier` | ✓ | Flutter 3.47.1 | — |
| New external package | Phase 1 | Not required | — | Use existing SDK APIs |

**Missing dependencies with no fallback:** None. [VERIFIED: environment probe, 2026-08-28]

**Missing dependencies with fallback:** None. [VERIFIED: environment probe, 2026-08-28]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (SDK dependency) [VERIFIED: D:/simple_player_flutter/pubspec.yaml:46-50] |
| Config file | `analysis_options.yaml`; no separate test runner config found. [VERIFIED: D:/simple_player_flutter/analysis_options.yaml:1-70] |
| Quick run command | `flutter test test/diagnostics/error_report_test.dart test/diagnostics/error_reporter_test.dart test/diagnostics/global_error_hooks_test.dart` |
| Full suite command | `flutter test` |
| Static analysis command | `flutter analyze` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CAP-01 | Each factory/adaptor produces the same immutable contract with source, ID, timestamps, severity, message/type, stack snapshot, and media snapshot. | unit | `flutter test test/diagnostics/error_report_test.dart` | ❌ Wave 0 |
| CAP-01 | Player error explicit intake maps `isFatal` and snapshots supplied/provider media path. | unit | `flutter test test/diagnostics/error_reporter_test.dart` | ❌ Wave 0 |
| CAP-02 | Hook installer preserves framework presentation, delegates exactly once, and dispatcher returns `true`. | unit with injected handler setters | `flutter test test/diagnostics/global_error_hooks_test.dart` | ❌ Wave 0 |
| CAP-02 | Binding, hook assignment, and `runApp` are launched from one guarded zone. | debug startup smoke | `flutter run -d windows` with zone mismatch fatal diagnostic enabled | ❌ manual startup gate |
| CAP-03 | Every injected effect failure, normalizer failure, and reentrant report returns normally and does not invoke a second report/effect loop. | unit fault injection | `flutter test test/diagnostics/error_reporter_test.dart` | ❌ Wave 0 |
| CAP-04 | Same fingerprint inside 10 seconds merges count and preserves first ID/FIFO position; after 10 seconds it appends. | deterministic unit (`FakeClock`) | `flutter test test/diagnostics/error_reporter_test.dart` | ❌ Wave 0 |
| CAP-04 | Five distinct reports retain FIFO order; sixth evicts head; dismiss promotes next; pre-flush reports survive flush. | unit | `flutter test test/diagnostics/error_reporter_test.dart` | ❌ Wave 0 |
| CAP-04 | 100 and 1000 identical reports retain queue length ≤5 and effect count follows accepted/merged policy. | unit | `flutter test test/diagnostics/error_reporter_test.dart` | ❌ Wave 0 |

### Test Design Details

- Use hand-written spies/fakes, not mocks: `SpySink implements LogSink` is an established test pattern. [VERIFIED: D:/simple_player_flutter/test/diagnostics/kernel_logger_test.dart:9-23] Quote: `class SpySink implements LogSink {`.
- Reset global singletons in `setUp`/`tearDown`; the existing logger exposes `KernelLoggerImpl.resetForTesting()`. [VERIFIED: D:/simple_player_flutter/lib/kernel/diagnostics/kernel_logger.dart:522-529] Quote: `static void resetForTesting() {`.
- Extract hook installation into a setter-injectable helper so tests do not leave process-global `FlutterError.onError` or `PlatformDispatcher.onError` altered. The static production installer should preserve prior handlers in test-only cleanup, but application startup assigns its owned handlers once. [ASSUMED]
- Do not trigger real media_kit/libmpv instances in reporter tests. The project explicitly documents that `MediaKitEngine` unit tests should use static pure logic because construction depends on native libmpv. [VERIFIED: D:/simple_player_flutter/lib/kernel/engine/media_kit_engine.dart:35-40] Quote: `单测不应实例化本类 (依赖 native libmpv)`.
- Run focused tests before full suite; the repository has existing headless media DLL failure history, so distinguish known environment failures from diagnostic-core failures before changing implementation. [ASSUMED]

### Sampling Rate

- **Per task commit:** focused diagnostic tests plus `flutter analyze`. [ASSUMED]
- **Per wave merge:** `flutter test` plus `flutter analyze`. [VERIFIED: D:/simple_player_flutter/CLAUDE.md:5-12]
- **Phase gate:** full suite green and Windows debug startup smoke with all bootstrap work in the guarded zone. [VERIFIED: D:/simple_player_flutter/.planning/phases/01-unified-capture-contract/01-CONTEXT.md:16-18]

### Wave 0 Gaps

- [ ] `test/diagnostics/error_report_test.dart` — immutable contract, safe stack/message normalization, `copyWith` behavior.
- [ ] `test/diagnostics/error_reporter_test.dart` — factory mapping, FIFO/dedupe/flush, capacity, failure isolation, reentrancy, synthetic burst.
- [ ] `test/diagnostics/global_error_hooks_test.dart` — thin adapters and dispatcher `true` contract.
- [ ] Test fakes for clock, media-path provider, ID generator, and effects — keep local to diagnostics tests unless reuse becomes real.
- [ ] No new test framework install is needed. [VERIFIED: D:/simple_player_flutter/pubspec.yaml:46-57]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | No authentication functionality is in Phase 1. [VERIFIED: D:/simple_player_flutter/.planning/REQUIREMENTS.md:6-14] |
| V3 Session Management | No | No session functionality is in Phase 1. [VERIFIED: D:/simple_player_flutter/.planning/REQUIREMENTS.md:6-14] |
| V4 Access Control | No | No access-control functionality is in Phase 1. [VERIFIED: D:/simple_player_flutter/.planning/REQUIREMENTS.md:6-14] |
| V5 Input Validation | Yes | Treat exception messages, stacks, and media paths as untrusted diagnostic payload; bound stored text and never interpret a stack line as a path/action in Phase 1. [ASSUMED] |
| V6 Cryptography | No | This phase stores no credentials and introduces no cryptographic operation. [VERIFIED: D:/simple_player_flutter/.planning/REQUIREMENTS.md:6-14] |

### Known Threat Patterns for Flutter/Dart diagnostic capture

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Malicious/huge exception message or stack causes memory pressure | Denial of Service | Bound individual string snapshots and maintain only five queued reports; retain truncation metadata rather than allocating unbounded copies. [ASSUMED] |
| Plugin/error text influences a later source-path reader | Information Disclosure | Phase 1 only fingerprints text; Phase 2 must accept only validated project-relative locations before source-file reads. [VERIFIED: D:/simple_player_flutter/.planning/REQUIREMENTS.md:15-20] |
| Reporter effect failure causes recursive reporting | Denial of Service | Reentrancy guard, per-effect isolation, and non-recursive last-resort fallback. [VERIFIED: D:/simple_player_flutter/.planning/REQUIREMENTS.md:10-14] |
| Full local media path appears in diagnostic memory/output | Information Disclosure | Preserve the requested failure-time snapshot for local developer diagnostics; do not add network transport or telemetry. [VERIFIED: D:/simple_player_flutter/.planning/REQUIREMENTS.md:64-73] |

## Sources

### Primary (official documentation)

- [Flutter: Handling errors](https://docs.flutter.dev/testing/errors) — framework vs. dispatcher routing, `FlutterError.presentError`, and dispatcher handled return. [CITED: https://docs.flutter.dev/testing/errors]
- [Flutter API: PlatformDispatcher.onError](https://api.flutter.dev/flutter/dart-ui/PlatformDispatcher/onError.html) — root-isolate handler/registered-zone contract. [CITED: https://api.flutter.dev/flutter/dart-ui/PlatformDispatcher/onError.html]
- [Dart: Zones](https://dart.dev/libraries/async/zones) — error-zone containment behavior. [CITED: https://dart.dev/libraries/async/zones]

### Project sources inspected this session

- `D:/simple_player_flutter/lib/main.dart` — current bootstrap order and window-init catch. [VERIFIED: D:/simple_player_flutter/lib/main.dart:16-49]
- `D:/simple_player_flutter/lib/kernel/diagnostics/kernel_logger.dart` — singleton lifecycle, logger sink interface, existing test seam. [VERIFIED: D:/simple_player_flutter/lib/kernel/diagnostics/kernel_logger.dart:68-90; 483-583]
- `D:/simple_player_flutter/lib/kernel/player_services.dart` — duplicate `KernelLoggerImpl.init()` at service initialization. [VERIFIED: D:/simple_player_flutter/lib/kernel/player_services.dart:104-125] Quote: `KernelLoggerImpl.init();`
- `D:/simple_player_flutter/lib/kernel/models/player_error.dart` — PlayerError contract and fatal mapping input. [VERIFIED: D:/simple_player_flutter/lib/kernel/models/player_error.dart:18-52]
- `D:/simple_player_flutter/lib/kernel/engine/media_kit_engine.dart` — `lastError` notifier publication points. [VERIFIED: D:/simple_player_flutter/lib/kernel/engine/media_kit_engine.dart:74-77; 138-143; 591-598]
- `D:/simple_player_flutter/lib/kernel/services/playback_controller.dart` — current path ownership and failed-open behavior. [VERIFIED: D:/simple_player_flutter/lib/kernel/services/playback_controller.dart:67-84; 134-163]

## Metadata

**Confidence breakdown:**
- Standard stack: MEDIUM — official Flutter/Dart documentation was consulted through Context7; classifier returned MEDIUM for Context7 sources. [VERIFIED: classify-confidence context7, 2026-08-28]
- Architecture: MEDIUM — locked context and direct project source inspection establish seams; new model/policy names and duration are recommendations. [VERIFIED: D:/simple_player_flutter/.planning/phases/01-unified-capture-contract/01-CONTEXT.md:13-30]
- Pitfalls: MEDIUM — routing/zone facts are official; actual flood thresholds and fallback implementation need Phase-1 tests. [CITED: https://docs.flutter.dev/testing/errors]

**Research date:** 2026-08-28  
**Valid until:** 2026-09-27 for stable Flutter/Dart APIs; recheck before changing Flutter SDK major/minor versions.

## RESEARCH COMPLETE
