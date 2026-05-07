# Coding Conventions

**Analysis Date:** 2026-05-07

## Naming Patterns

**Files:**
- `snake_case.dart` for all Dart files (Dart convention)
- File names match the primary class/concept: `media_engine.dart` contains `MediaEngine`, `playlist.dart` contains `Playlist`
- Test files mirror source path: `lib/kernel/playlist/playlist.dart` -> `test/kernel/playlist/playlist_test.dart`
- Test helpers go in `test/helpers/` (e.g., `fake_engine.dart`)

**Classes:**
- `PascalCase` for all classes, enums, typedefs, extensions
- Abstract interfaces use no prefix: `MediaEngine`, `PlatformService`
- Concrete implementations use descriptive prefix: `FvpEngine`, `WindowsPlatformService`
- Data containers (value objects): `AppSettings`, `MediaInfo`, `AudioTrackInfo`
- Services end with `Service`: `VideoProcessingService`, `WindowManagerService`, `AspectRatioService`
- Mixins use verb-phrase names: `FileOperations`, `PlaybackNavigator`, `StateMonitor`

**Functions/Methods:**
- `camelCase` for all functions and methods
- Boolean getters use `is`/`has` prefix: `isEmpty`, `isNotEmpty`, `hasNext`, `hasPrevious`, `hasVideo`
- Void commands are imperative verbs: `play()`, `pause()`, `stop()`, `dispose()`
- Query methods return values without side effects: `peekNext()`, `peekPrevious()`, `getAudioTracks()`
- Private methods prefixed with `_`: `_guardedAction`, `_onStateChanged`, `_poll`

**Variables:**
- `camelCase` for local variables and parameters
- Private fields prefixed with `_`: `_player`, `_disposed`, `_currentIndex`
- Constants use `camelCase` (not `SCREAMING_SNAKE_CASE`) for class-level constants: `_prepareTimeoutSeconds`, `_pollIntervalMs`, `_debounceMs`
- Static const keys use `_key` prefix: `_keyVolume`, `_keyLastFile`, `_keyWindowWidth` (SharedPreferences keys)

**Enums:**
- `PascalCase` enum names: `MediaState`, `PlayMode`, `VideoEffectType`, `AspectRatioMode`, `WindowMode`
- `camelCase` enum values: `idle`, `loading`, `playing`, `loopAll`, `loopSingle`
- Enum values with associated data use constructor: `AspectRatioMode.keepOriginal('原始', 1.1920928955078125e-7)`

## Code Style

**Formatting:**
- `dart format` for all `.dart` files (80-char line length, default)
- Trailing commas on multi-line argument/parameter lists
- `package:flutter_lints/flutter.yaml` as base linter config in `analysis_options.yaml`

**Immutability:**
- Prefer `final` for local variables and fields
- Use `const` constructors where all fields are `final`: `const AppSettings(...)`, `const MediaInfo()`
- Return `List.unmodifiable` from public getters: `List<PlaylistItem> get items => List.unmodifiable(_items);`
- Use `copyWith()` for immutable updates on data classes: `PlaylistItem.copyWith()`

**Null Safety:**
- Avoid `!` (bang operator) -- use `?.`, `??`, `if (x != null)` or early return guards
- Avoid `late` unless initialization is guaranteed (prefer nullable or constructor init)
- Use `required` for mandatory constructor parameters
- `@visibleForTesting` on test-only reset methods: `SettingsStore.resetPrewarm()`, `PlatformService.reset()`

**Dart 3 Pattern Matching:**
- Use `switch` expressions for exhaustive mapping (see `FvpCallbackHandler.mapMdkState`, `FvpEngine.setVideoEffect`)
- Exhaustive `switch` on enums: all enum branches covered, no default wildcard

## Import Organization

**Order:**
1. `dart:` imports (`dart:async`, `dart:convert`, `dart:io`, `dart:math`)
2. `package:flutter/` imports
3. External `package:` imports (`package:fvp/`, `package:shared_preferences/`, `package:path_provider/`, `package:window_manager/`)
4. Relative imports for same-package files (`../models/`, `../engine/`, `../services/`)

**Path Style:**
- Use relative imports within `lib/kernel/` (e.g., `import '../models/media_state.dart'`)
- Use `package:` imports only for cross-package references
- No barrel files / index exports -- direct file imports throughout

**Import Prefixes:**
- `package:fvp/mdk.dart` imported as `mdk` prefix: `import 'package:fvp/mdk.dart' as mdk;`

## Error Handling

**Strategy: Guard Clause + try-catch + debugPrint + graceful fallback**

Every public method that touches external resources follows this pattern:

```dart
// Pattern 1: _guardedAction wrapper (preferred for simple operations)
void _guardedAction(String name, void Function() action) {
  if (_disposed) return;
  try {
    action();
  } on Exception catch (e) {
    debugPrint('FvpEngine.$name error: $e');
    errorMessage.value = '$name failed: $e';
  }
}

// Pattern 2: Inline guard + try-catch (for complex async operations)
Future<void> open(String path) async {
  if (_disposed) return;
  // ... validation ...
  try {
    // ... operation ...
  } on Exception catch (e) {
    state.value = MediaState.error;
    errorMessage.value = 'Failed to open: $e';
  } finally {
    isBuffering.value = false;
    _isOpening = false;
  }
}
```

**Rules:**
- Always catch `on Exception` (not bare `catch (e)`) -- never catch `Error` subtypes
- Use `debugPrint()` for all logging, never `print()`
- Chinese error messages are acceptable (existing codebase convention)
- Never silently swallow errors -- always log with `debugPrint`
- Persistence operations: catch + log + return safe defaults (see `SettingsStore.load`)
- `unawaited()` for intentional fire-and-forget Futures: `unawaited(SettingsStore.saveVolume(...))`

**Error Propagation:**
- Services expose `ValueNotifier<String?> errorMessage` for UI display
- Mixins use `void Function(Object error)? onError` callback pattern
- `validationError` ValueNotifier for user-facing validation messages (see `FileOperations`)

## Logging

**Framework:** `debugPrint()` from `package:flutter/foundation.dart`

**Patterns:**
- Class-scoped prefix: `debugPrint('FvpEngine.open() blocked -- already opening')`
- Error context: `debugPrint('PlaylistStore._flush failed: $e')`
- Lifecycle events: `debugPrint('[App] init completed in ${sw.elapsedMilliseconds}ms')`
- Subsystem tags in brackets: `[WindowManager]`, `[App]`, `[AspectRatio]`

## Class Design

**Singleton Pattern (factory private constructor):**
```dart
class WindowManagerService {
  WindowManagerService._();
  static final WindowManagerService I = WindowManagerService._();
}
```
Used for: `WindowManagerService`, `AspectRatioService`

**Singleton Pattern (init + accessor):**
```dart
abstract class PlatformService {
  static PlatformService? _instance;
  static PlatformService get I { ... }
  static void init(PlatformService impl) => _instance = impl;
  @visibleForTesting
  static void reset() => _instance = null;
}
```
Used for: `PlatformService` (abstract interface + factory singleton)

**Mixin Composition (Orchestrator pattern):**
```dart
class PlaybackController
    with FileOperations, PlaybackNavigator, StateMonitor {
  // Constructor holds shared state
  // Mixins declare abstract getters for shared dependencies
}
```
Used for: `PlaybackController` composed from `FileOperations`, `PlaybackNavigator`, `StateMonitor`

**Abstract Interface + Concrete Implementation:**
- `MediaEngine` (abstract) at `lib/kernel/engine/media_engine.dart` -> `FvpEngine` (concrete) at `lib/kernel/engine/fvp_engine.dart`
- `PlatformService` (abstract) at `lib/kernel/services/platform_service.dart` -> `WindowsPlatformService` at `lib/kernel/platform/windows_platform_service.dart`

**Helper Composition (delegation):**
`FvpEngine` delegates to 3 focused helper classes, each owning a single concern:
- `FvpCallbackHandler` at `lib/kernel/engine/fvp_callback_handler.dart` -- mdk callback registration, state mapping
- `PositionPoller` at `lib/kernel/engine/position_poller.dart` -- 250ms timer polling
- `TrackManager` at `lib/kernel/engine/track_manager.dart` -- audio/subtitle track selection

**Data Classes (value objects):**
- All fields `final`
- `const` constructor where possible
- `copyWith()` for immutable updates
- `toJson()` / `fromJson()` for serialization
- `==` and `hashCode` override based on identity field
- See: `PlaylistItem`, `AppSettings`, `MediaInfo`, `AudioTrackInfo`, `VideoCodecInfo`

## Function Design

**Size:** Keep functions under 50 lines. Large functions like `FvpEngine.open()` (~60 lines) are exceptions justified by sequential async steps.

**Parameters:**
- Use named parameters with `required` for mandatory ones
- Use default values for optional parameters: `void skipForward([int seconds = 10])`
- Clamp input values at entry point (defensive programming): `value.clamp(0.0, 1.0)`

**Return Values:**
- CQS (Command-Query Separation): queries return values without side effects, commands are void
- `peekNext()` returns index without modifying state; caller sets `currentIndex` explicitly
- `add()` returns new index; `removeAt()` returns `bool` success indicator

## Module Design

**Exports:** No barrel files. Each file is imported directly by path.

**Layer Boundaries:**
- `lib/kernel/models/` -- Pure data classes, enums (minimal Flutter dependency)
- `lib/kernel/engine/` -- Media engine abstraction and implementation
- `lib/kernel/services/` -- Business logic orchestrators (mixins)
- `lib/kernel/persistence/` -- Storage layer (SharedPreferences, JSON files)
- `lib/kernel/playlist/` -- Playlist data structure
- `lib/kernel/ui/` -- Design tokens, theme
- `lib/kernel/window/` -- Window management
- `lib/kernel/platform/` -- Platform-specific implementations
- `lib/kernel/utils/` -- Pure utility functions

## ValueNotifier State Management

This codebase uses `ValueNotifier` + `ValueListenableBuilder` exclusively (no Provider/Riverpod/Bloc).

**Pattern:**
```dart
// In service/engine class:
final ValueNotifier<MediaState> state = ValueNotifier<MediaState>(MediaState.idle);

// In widget:
ValueListenableBuilder<MediaState>(
  valueListenable: engine.state,
  builder: (context, state, _) => Text(state.name),
)
```

**Rules:**
- Every `ValueNotifier` must be `dispose()`d in the owning class's `dispose()` method
- Use `addListener()` for side effects (see `VideoProcessingService` constructor)
- Use `ValueListenableBuilder` in widget tree for reactive UI

## Comments

**When to Comment:**
- Class-level doc comments explaining purpose, design principles, and composition
- Method-level doc comments for public API: parameter ranges, return values, side effects
- Inline comments for non-obvious logic
- Feature tags: `// FEAT-01: Resume from saved position`, `// RC-3: Window geometry validation`

**Language:** Chinese comments are acceptable and common throughout the codebase.

## Async Patterns

- Always `await` Futures or explicitly call `unawaited()` for fire-and-forget
- Use `Future.wait` for concurrent operations: `await Future.wait([future1, future2])`
- Debounce with `Timer` for persistence: `Timer(const Duration(milliseconds: 300), _flush)`
- Generation guard for concurrent async: `int openGeneration = 0; final gen = ++openGeneration;`
- `Completer` for bridging sync callbacks to async: `_initCompleter = Completer<void>()`

---

*Convention analysis: 2026-05-07*
