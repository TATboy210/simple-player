# Phase 18: Sealed 错误模型稳化 - Research

**Researched:** 2026-07-19
**Domain:** Sealed error model extension, error propagation chain, UI error translation, thread marshalling
**Confidence:** HIGH

## Summary

Phase 18 extends the existing sealed `PlayerError` (5 subclasses, 4 per-subclass enums) with structured `ErrorContext`, `isFatal`/`l10nKey` accessors, and error code `recoverable` markers. The propagation chain runs from engine catch points through `lastError` ValueNotifier to `ErrorBanner` UI translation. The existing architecture provides strong foundations: sealed class exhaustive matching, ValueNotifier unidirectional data flow, and `KernelLogger` (Phase 17) with `error()`/`fatal()` methods accepting structured context maps.

**Critical architectural finding:** FvpEngine currently accesses `KernelLogger.I` via a top-level `final log = KernelLogger.I` static reference — it does NOT receive the `DiagnosticsBundle` via constructor injection. The `DiagnosticsBundle` lives in `KernelAdapter` (Phase 16 seam). P18 catch-point logger integration can use the existing `log` reference without constructor changes. The three-step pattern (construct PlayerError → assign lastError → logger.e) fits the current architecture without requiring bundle injection into FvpEngine.

**Primary recommendation:** Extend `PlayerError` with optional `ErrorContext? context` field + abstract `bool get isFatal` + `String get l10nKey` getters. Add `recoverable` marker to each per-subclass enum. Transform FvpEngine catch points to three-step pattern. Add l10n error keys to ARB files. ErrorBanner switches from `error.message` direct display to `l10nKey` lookup with fallback.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Error construction (ErrorContext) | Engine (FvpEngine/MediaOpener) | — | Engine catch points know action/path/generation — most precise context source |
| Error propagation (lastError) | Engine (ValueNotifier) | — | Existing contract, UI listens via ValueListenableBuilder |
| Logger emission | Engine (catch points) | — | Logger accessed via static `KernelLogger.I`, no bundle injection needed |
| Error classification (isFatal) | Model (PlayerError sealed) | — | Single source of truth in code enum markers |
| UI error translation | UI (ErrorBanner) | l10n (ARB files) | ErrorBanner reads l10nKey, looks up AppLocalizations |
| Thread marshalling | Engine (FvpCallbackHandler) | — | mdk callbacks already use addPostFrameCallback |
| Error signature narrowing | Service (PlaybackController) | — | _onError(Object) → _onError(PlayerError) |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| dart:async | SDK | scheduleMicrotask for thread marshalling | Dart standard library |
| flutter/foundation | SDK | ValueNotifier, kDebugMode | Already in use, project standard |
| fvp/mdk | pubspec.lock | mdk.Player callbacks (onStateChanged/onMediaStatus) | Existing dependency |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter/scheduler | SDK | SchedulerBinding.addPostFrameCallback | Already used in FvpCallbackHandler for main-thread dispatch |

**Installation:** No new packages required. Phase 18 is zero-dependency — all changes use existing SDK and project imports.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Optional ErrorContext field | Required ErrorContext | Breaks backward compatibility with ~5 existing catch points; D1 decides optional |
| Unified ErrorCode enum | Per-subclass enums (current) | Over-abstraction; D5 decides keep per-subclass, they ARE the registry |
| ErrorView widget | ErrorBanner (existing) | Unnecessary new widget; D7 decides extend ErrorBanner with l10nKey |

## Package Legitimacy Audit

No new packages installed. Phase 18 extends existing code only.

| Package | Registry | Verdict | Disposition |
|---------|----------|---------|-------------|
| (none) | — | — | No new packages |

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Error Construction                         │
│  FvpEngine catch points ──┐   MediaOpener ──┐               │
│  (open/play/seek/guarded) │   (prepare/     │               │
│                            │    texture)     │               │
│                            ▼                 ▼               │
│                    PlayerError + ErrorContext                 │
│                    (action/generation/path/timestamp/module)  │
└────────────────────────┬────────────────────────────────────┘
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
   lastError.value   bundle.logger   stateMachine
   (ValueNotifier)   .e(msg,ctx)    .transitionTo
          │              │           (MediaState.error)
          │              ▼
          │     KernelLogger → LogSink
          │     (DevTools/DebugPrint/Null)
          ▼
┌─────────────────────────────────────────────────────────────┐
│                    Error Propagation                          │
│  ValueNotifier<PlayerError?> ──→ ValueListenableBuilder      │
│                                          │                   │
│  PlaybackController._onError(PlayerError)│                   │
│  (service submodules call onError)       │                   │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    UI Translation                             │
│  ErrorBanner reads:                                           │
│    error.l10nKey → AppLocalizations lookup → localized msg    │
│    error.isFatal → severity indicator                         │
│    switch(error) → action button routing (preserved)          │
│  Sealed PlayerError NEVER exposed as raw object to UI         │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    Thread Marshalling (ERR-05)                │
│  mdk callback thread                                           │
│    → catch exception → construct PlayerError                  │
│    → scheduleMicrotask → main thread                          │
│    → lastError.value = error + logger.e()                     │
│    callbackStackTrace carried as ErrorContext field            │
└─────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure

```
lib/kernel/
├── models/
│   └── player_error.dart          # EXTEND: + ErrorContext + isFatal + l10nKey + recoverable markers
├── engine/
│   ├── fvp_engine.dart            # MODIFY: ~8 catch points → three-step pattern
│   ├── media_opener.dart          # MODIFY: construct ErrorContext at error sites
│   └── fvp_callback_handler.dart  # MODIFY: catch+marshal mdk callback errors
├── services/
│   └── playback_controller.dart   # MODIFY: _onError(Object) → _onError(PlayerError)
├── diagnostics/
│   └── kernel_logger.dart         # NO CHANGE (P17 delivered, error/fatal signatures already correct)
└── adapter/
    └── kernel_adapter.dart        # NO CHANGE (lastError forwarding already works via ValueNotifier)

lib/l10n/
├── app_en.arb                     # ADD: error.* keys for each error code
└── app_zh.arb                     # ADD: error.* keys (Chinese translations)

lib/ui/player/
└── error_banner.dart              # MODIFY: l10nKey lookup instead of raw error.message
```

### Pattern 1: Three-Step Error Handling

**What:** Every engine catch point follows the same three-step pattern: construct PlayerError with ErrorContext → assign to lastError.value → emit via bundle.logger.e().
**When to use:** Every `on Exception catch` in FvpEngine and MediaOpener.
**Example:**
```dart
// Source: CONTEXT.md D10 — three-step error pattern
} on Exception catch (e, st) {
  if (_disposed || gen != _openGeneration) return;
  final error = PlaybackError(
    PlaybackErrorCode.playFailed,
    '无法打开: ${PathUtils.basename(trimmed)}',
    e,
  )..context = ErrorContext(
    action: 'open',
    generation: gen,
    path: trimmed,
    timestamp: DateTime.now(),
    module: 'FvpEngine',
  );
  lastError.value = error;
  log.e('open() error', context: error.context?.toMap(), error: e, stackTrace: st);
  _stateMachine.transitionTo(MediaState.error, 'open');
}
```

### Pattern 2: ErrorContext Optional Field with Backward Compatibility

**What:** `PlayerError` gains an optional `ErrorContext? context` field. Existing code that constructs errors without context continues to work.
**When to use:** Extending sealed class without breaking existing constructors.
**Example:**
```dart
// Source: CONTEXT.md D1 — optional context field
sealed class PlayerError {
  String get message;
  Object? get cause;
  ErrorContext? context;  // NEW: optional, backward compatible
  bool get isFatal;       // NEW: abstract getter
  String get l10nKey;     // NEW: abstract getter for UI translation
  const PlayerError();
}
```

### Pattern 3: l10nKey-Based UI Translation

**What:** ErrorBanner uses `error.l10nKey` to look up localized message from AppLocalizations, falling back to `error.message` if key not found.
**When to use:** At the UI boundary — ErrorBanner is the sole consumer.
**Example:**
```dart
// Source: CONTEXT.md D7 — l10nKey translation with fallback
String displayMessage;
try {
  displayMessage = l10n.errorByCode(error.l10nKey);
} on Exception {
  displayMessage = error.message;  // fallback to raw message
}
```

### Anti-Patterns to Avoid

- **Catching Error subtypes:** Never catch `Error` subclasses (programming bugs). Only catch `Exception`. [CONTEXT.md ERR-02]
- **Silent error swallowing:** Every catch must either rethrow or construct PlayerError + assign lastError + log. Never bare `catch (_) {}`. [CLAUDE.md]
- **Exposing raw sealed to UI:** UI must read l10nKey/isFatal/message, never switch on sealed type for display text. [CONTEXT.md D7]
- **Renaming error codes:** Error codes are append-only. Existing codes never renamed or deleted. [CONTEXT.md D6]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Error code registry | Custom registry class | Per-subclass enums with `recoverable` marker | D5: enums ARE the registry, no extra abstraction |
| Thread marshalling | Custom Isolate message passing | scheduleMicrotask (existing pattern in FvpCallbackHandler) | D9: standard Flutter microtask scheduling |
| l10n error lookup | Custom error-to-string mapper | ARB keys + AppLocalizations | D7: standard Flutter l10n, `flutter gen-l10n` generates |

## Common Pitfalls

### Pitfall 1: FvpEngine Has No DiagnosticsBundle Reference
**What goes wrong:** Planner assumes FvpEngine receives DiagnosticsBundle via constructor.
**Why it happens:** DiagnosticsBundle is created in PlayerServices and passed to KernelAdapter, not FvpEngine.
**How to avoid:** FvpEngine uses the existing `final log = KernelLogger.I` top-level reference. The three-step pattern calls `log.e(...)` directly — no constructor change needed.
**Warning signs:** Plan tasks that add `DiagnosticsBundle bundle` parameter to FvpEngine constructor.

### Pitfall 2: PlaybackController.onError Is Null in Production
**What goes wrong:** Planner assumes _onError callback is wired in production.
**Why it happens:** PlayerServices creates PlaybackController without passing onError (line 118-122). The callback is null.
**How to avoid:** P18 changes _onError signature from `Object` to `PlayerError`, but the null-wiring issue is pre-existing. Service submodules already guard with `_controller.onError?.call(e)`. P18 should not attempt to fix the null wiring — that's a separate concern.
**Warning signs:** Plan tasks that wire onError in PlayerServices.

### Pitfall 3: "KernelError" Does Not Exist in Codebase
**What goes wrong:** Plan references `KernelError` as the sealed class name.
**Why it happens:** REQUIREMENTS.md ERR-04 says "sealed KernelError 永不以原始对象暴露给 UI" but the actual class is `PlayerError`.
**How to avoid:** The sealed class is `PlayerError` (player_error.dart). "KernelError" in requirements is a naming artifact. All code references must use `PlayerError`.
**Warning signs:** Any code or plan referencing `KernelError`.

### Pitfall 4: ErrorContext Assignment on const Constructors
**What goes wrong:** Attempting to assign `context` field on const-constructed PlayerError instances.
**Why it happens:** Current constructors are `const`. Adding a mutable `context` field breaks const.
**How to avoid:** D1 says `ErrorContext? context` is an optional field. Two approaches: (a) make constructors non-const (breaking change), or (b) use a setter method / copy-with pattern. Recommended: make constructors non-const since ErrorContext contains DateTime.now() which is non-const anyway (D3).
**Warning signs:** Keeping `const` on PlayerError subclass constructors.

### Pitfall 5: mdk Callback Error Conversion Timing
**What goes wrong:** Constructing PlayerError on the callback thread, then accessing lastError (a ValueNotifier) from that thread.
**Why it happens:** ValueNotifier.notifyListeners() triggers widget rebuilds — must happen on main thread.
**How to avoid:** D9 specifies: catch on callback thread → construct PlayerError + capture callbackStackTrace → scheduleMicrotask to main thread → assign lastError + log. The existing FvpCallbackHandler._scheduleOnMain pattern (addPostFrameCallback) is the reference implementation.
**Warning signs:** Direct `lastError.value = error` inside mdk callback handlers without main-thread dispatch.

## Code Examples

### ErrorContext Data Class
```dart
/// 错误结构化上下文 — 携带错误发生时的环境信息 (D1)
///
/// Carries structured context at error construction site.
/// Fields are optional except timestamp (always set at construction).
class ErrorContext {
  /// 操作名称 (e.g., 'open', 'play', 'seek')
  final String? action;

  /// open() 递增计数器 — 关联到具体哪次 open 请求
  final int? generation;

  /// 文件路径或 URL
  final String? path;

  /// 错误发生时间 (D3: default DateTime.now(), injectable for tests)
  final DateTime timestamp;

  /// 模块名称 (e.g., 'FvpEngine', 'MediaOpener')
  final String? module;

  /// mdk 回调线程栈 — 仅跨线程封送时填充 (D11)
  final StackTrace? callbackStackTrace;

  ErrorContext({
    this.action,
    this.generation,
    this.path,
    DateTime? timestamp,
    this.module,
    this.callbackStackTrace,
  }) : timestamp = timestamp ?? DateTime.now();

  /// 序列化为 Map — 传给 KernelLogger.error(context:) 参数
  Map<String, Object?> toMap() => {
    if (action != null) 'action': action,
    if (generation != null) 'generation': generation,
    if (path != null) 'path': path,
    'timestamp': timestamp.toIso8601String(),
    if (module != null) 'module': module,
    if (callbackStackTrace != null) 'callbackStackTrace': callbackStackTrace.toString(),
  };
}
```

### Per-Subclass Enum with recoverable Marker
```dart
// Source: CONTEXT.md D5 — each enum IS the registry, with recoverable marker
enum FileErrorCode {
  pathEmpty(recoverable: true),
  fileNotFound(recoverable: true),
  pathTraversal(recoverable: false);  // security violation — fatal

  final bool recoverable;
  const FileErrorCode({required this.recoverable});
}

enum PlaybackErrorCode {
  playFailed(recoverable: true),
  seekFailed(recoverable: true),
  textureFailed(recoverable: false),  // GPU/driver issue — fatal
  openTimeout(recoverable: true);

  final bool recoverable;
  const PlaybackErrorCode({required this.recoverable});
}
```

### FvpEngine Three-Step Catch Pattern
```dart
// Source: CONTEXT.md D10 — construct + assign + log in one block
@override
Future<void> open(String path) async {
  // ... existing code ...
  } on Exception catch (e, st) {
    if (_disposed || gen != _openGeneration) return;
    // Step 1: Construct PlayerError with ErrorContext
    final error = PathValidator.isUrl(trimmed)
        ? NetworkError(NetworkErrorCode.timeout, '无法打开: ${PathUtils.basename(path)}', e)
        : PlaybackError(PlaybackErrorCode.playFailed, '无法打开: ${PathUtils.basename(path)}', e);
    error.context = ErrorContext(
      action: 'open',
      generation: gen,
      path: trimmed,
      module: 'FvpEngine',
    );
    // Step 2: Assign to lastError
    lastError.value = error;
    // Step 3: Log with structured context
    log.e('open() error — ${PathUtils.basename(trimmed)}',
      context: error.context?.toMap(), error: e, stackTrace: st);
    _stateMachine.transitionTo(MediaState.error, 'open');
    metrics.recordOpen(success: false);
    eventLog.add('error', {'action': 'open', 'error': e.toString()});
  }
}
```

### ErrorBanner l10nKey Translation
```dart
// Source: CONTEXT.md D7 — l10nKey lookup with fallback
@override
Widget build(BuildContext context) {
  return ValueListenableBuilder2<MediaState, PlayerError?>(
    first: engine.state,
    second: engine.lastError,
    builder: (context, state, error, _) {
      if (state != MediaState.error || error == null) {
        return const SizedBox.shrink();
      }
      final l10n = AppLocalizations.of(context);
      // UI translation: l10nKey → localized message, fallback to raw message
      final displayMessage = _resolveMessage(l10n, error);
      // ... rest of widget tree using displayMessage instead of error.message
    },
  );
}

String _resolveMessage(AppLocalizations l10n, PlayerError error) {
  // l10nKey lookup with graceful fallback
  return switch (error.l10nKey) {
    'error.file.pathEmpty' => l10n.errorFilePathEmpty,
    'error.file.fileNotFound' => l10n.errorFileNotFound,
    // ... other keys ...
    _ => error.message,  // fallback: raw message for unknown keys
  };
}
```

### Thread Marshalling Pattern (ERR-05)
```dart
// Source: CONTEXT.md D9 + FvpCallbackHandler._scheduleOnMain reference
// Inside FvpCallbackHandler.init(), in mdk callback listener:
_player.onStateChanged.listen((event) {
  if (_disposed) return;
  try {
    final mapped = mapMdkState(event.newValue);
    _scheduleOnMain(() {
      if (_disposed) return;
      _stateMachine.transitionTo(mapped, 'mdk.onStateChanged');
    });
  } on Exception catch (e, st) {
    // Catch on callback thread, construct error with callback stack
    final error = PlaybackError(
      PlaybackErrorCode.playFailed,
      'mdk callback error: $e',
      e,
    )..context = ErrorContext(
      action: 'mdk.onStateChanged',
      module: 'FvpCallbackHandler',
      callbackStackTrace: st,  // D11: carry callback thread stack
    );
    // Marshal to main thread for lastError assignment
    _scheduleOnMain(() {
      if (_disposed) return;
      _lastErrorNotifier.value = error;
      log.e('mdk callback error', context: error.context?.toMap(), error: e, stackTrace: st);
    });
  }
});
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Flat error enum + message string | Sealed PlayerError 5 subclasses | v2.1 | Exhaustive pattern matching, type-safe |
| Direct `error.message` in ErrorBanner | l10nKey lookup (P18) | Phase 18 | UI decoupled from error internals |
| `_onError(Object error)` | `_onError(PlayerError error)` (P18) | Phase 18 | Type-safe error propagation |
| No ErrorContext | ErrorContext with action/generation/path (P18) | Phase 18 | Structured diagnostics |
| No isFatal classification | `bool get isFatal` via code.recoverable (P18) | Phase 18 | Recoverable vs fatal at model level |

**Deprecated/outdated:**
- Raw `error.message` display in ErrorBanner: replaced by l10nKey translation in P18
- `Object error` type in PlaybackController._onError: narrowed to `PlayerError` in P18

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | FvpEngine can access KernelLogger.I via existing top-level `final log` without constructor change | Architecture | Low — if bundle injection is required instead, FvpEngine constructor needs a DiagnosticsBundle parameter, which changes the factory pattern |
| A2 | Making PlayerError subclass constructors non-const is acceptable | Pitfall 4 | Low — existing const call sites (e.g., `const FileError(...)`) would need removal of `const` keyword, but all are in tests and a few catch points |
| A3 | ErrorContext can be a mutable field (setter) on a sealed class | Pattern 2 | Medium — Dart sealed classes allow mutable fields on final subclasses; if this fails at compile time, need copy-with pattern instead |
| A4 | `error.l10nKey` naming convention `error.{type}.{code}` is acceptable | Pattern 3 | Low — naming is a convention, not a technical constraint |

## Open Questions

1. **ErrorContext mutation pattern on sealed class**
   - What we know: D1 says `PlayerError sealed class 新增可选 ErrorContext? context 字段`. Current constructors are `const`.
   - What's unclear: Whether `context` should be a mutable field (setter) or if constructors should become non-const with optional context parameter.
   - Recommendation: Make constructors non-const with optional named `context` parameter. This is cleaner than a mutable setter and preserves immutability of the error object after construction. All existing `const` call sites are trivial to update (remove `const` keyword).

2. **l10nKey resolution: switch expression vs Map lookup**
   - What we know: D7 says l10nKey format is `error.{type}.{code}`, ErrorBanner uses it to look up AppLocalizations.
   - What's unclear: Whether to use a switch expression on l10nKey string or a `Map<String, String Function(AppLocalizations)>` lookup.
   - Recommendation: Switch expression — type-safe, compile-time exhaustive checking when new codes are added, consistent with existing sealed pattern matching in ErrorBanner.

3. **ErrorContext.toMap() field naming for logger**
   - What we know: D10 says logger reads structured context from ErrorContext.toMap().
   - What's unclear: Exact field names in the map (camelCase vs snake_case).
   - Recommendation: camelCase (Dart convention) — `action`, `generation`, `path`, `timestamp`, `module`, `callbackStackTrace`.

4. **recoverable values for each enum code**
   - What we know: D5 says each code has a `recoverable` marker. D4 says `isFatal = !code.recoverable`.
   - What's unclear: Exact values for each code.
   - Recommendation:
     - FileErrorCode: pathEmpty=true, fileNotFound=true, pathTraversal=false (security)
     - CodecErrorCode: unsupportedFormat=true, decodeFailed=true, codecUnsupported=true
     - PlaybackErrorCode: playFailed=true, seekFailed=true, textureFailed=false (GPU), openTimeout=true
     - NetworkErrorCode: timeout=true, connectionLost=true
     - UnknownError: always recoverable=true (no code, treat as transient)

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All code | ✓ | pubspec.lock | — |
| fvp/mdk | Engine callbacks | ✓ | pubspec.lock | — |
| dart:async | scheduleMicrotask | ✓ | SDK | — |
| flutter/scheduler | addPostFrameCallback | ✓ | SDK | — |

**Missing dependencies with no fallback:** None — Phase 18 uses only existing SDK/project dependencies.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) |
| Config file | pubspec.yaml (dev_dependencies) |
| Quick run command | `flutter test test/kernel/models/player_error_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ERR-01 | PlayerError extended with ErrorContext + isFatal + l10nKey + recoverable enums | unit | `flutter test test/kernel/models/player_error_test.dart` | ✅ (extend) |
| ERR-02 | isFatal = !code.recoverable, no silent catch of Error subtypes | unit | `flutter test test/kernel/models/player_error_test.dart` | ✅ (extend) |
| ERR-03 | Engine catch points: construct PlayerError + assign lastError + logger.e | unit | `flutter test test/kernel/engine/fvp_engine_error_test.dart` | ❌ Wave 0 |
| ERR-04 | ErrorBanner uses l10nKey translation, not raw message | widget | `flutter test test/widget/player/error_banner_test.dart` | ✅ (extend) |
| ERR-05 | mdk callback errors marshalled to main thread with callbackStackTrace | unit | `flutter test test/kernel/engine/fvp_callback_handler_test.dart` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/kernel/models/player_error_test.dart test/widget/player/error_banner_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/kernel/engine/fvp_engine_error_test.dart` — covers ERR-03 (three-step pattern verification)
- [ ] `test/kernel/engine/fvp_callback_handler_error_test.dart` — covers ERR-05 (thread marshalling with ErrorContext)
- [ ] Extend `test/kernel/models/player_error_test.dart` — add ErrorContext/isFatal/l10nKey/recoverable tests
- [ ] Extend `test/widget/player/error_banner_test.dart` — add l10nKey translation tests
- [ ] Extend `test/integration/error_propagation_test.dart` — add ErrorContext propagation tests

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | yes | PathValidator (existing), ErrorContext.path sanitization |
| V6 Cryptography | no | — |

### Known Threat Patterns for Flutter Desktop Media Player

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Error message leaks file paths | Information Disclosure | ErrorContext.path redacted in logger (existing redactPath in KernelLogger); l10nKey translation hides internal paths from UI |
| Path traversal via error context | Tampering | PathValidator.validate() already exists; ErrorContext.path is for diagnostics only, not used for file operations |

**Note:** ErrorContext.path carries the same path that was already validated by PathValidator before the operation. The context field is diagnostic-only and does not introduce new attack surface.

## Sources

### Primary (HIGH confidence)
- `lib/kernel/models/player_error.dart` — existing sealed PlayerError 5 subclasses, all constructors and fields verified
- `lib/kernel/engine/fvp_engine.dart` — 636 lines, ~8 catch points identified, `final log = KernelLogger.I` static reference confirmed
- `lib/kernel/engine/engine_state_view.dart` — `ValueNotifier<PlayerError?> get lastError` contract verified
- `lib/kernel/diagnostics/kernel_logger.dart` — P17 delivered, error/fatal signatures with `{Object? error, StackTrace? stackTrace}` confirmed
- `lib/kernel/diagnostics/diagnostics_bundle.dart` — bundle carrier with logger slot confirmed
- `lib/ui/player/error_banner.dart` — sealed pattern matching + `error.message` direct display confirmed
- `lib/kernel/services/playback_controller.dart` — `_onError(Object error)` signature confirmed, null in production
- `lib/kernel/engine/fvp_callback_handler.dart` — `addPostFrameCallback` thread marshalling pattern confirmed
- `lib/l10n/app_en.arb` + `lib/l10n/app_zh.arb` — existing l10n structure confirmed, no error.* keys yet
- `.planning/phases/18-sealed/18-CONTEXT.md` — D1-D11 decisions, all locked

### Secondary (MEDIUM confidence)
- `lib/kernel/player_services.dart` — FvpEngine construction without bundle injection confirmed (line 104)
- `lib/kernel/adapter/kernel_adapter.dart` — bundle held by adapter, not engine (line 104)
- `lib/kernel/services/auto_advance_policy.dart` — `_controller.onError?.call(e)` null-guard pattern confirmed
- `lib/kernel/services/playback_navigator.dart` — error propagation through onError confirmed

### Tertiary (LOW confidence)
- None — all claims verified against live code

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero new dependencies, all SDK/project existing
- Architecture: HIGH — all integration points verified in live code
- Pitfalls: HIGH — all pitfalls discovered from direct code inspection

**Research date:** 2026-07-19
**Valid until:** 2026-08-19 (stable — sealed class extension is well-defined, no external API dependencies)
