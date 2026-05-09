# Coding Conventions

**Analysis Date:** 2026-05-09

## Naming Patterns

**Files:**
- `snake_case.dart` for all Dart files (e.g., `playback_controller.dart`, `media_engine.dart`)
- Directories mirror module structure: `kernel/engine/`, `kernel/services/`, `kernel/models/`

**Functions/Methods:**
- `camelCase` for all functions and methods
- Private members prefixed with `_` (e.g., `_disposed`, `_currentPath`, `_guardedAction`)
- Mixin methods follow same conventions as class methods

**Variables:**
- `camelCase` for variables (e.g., `currentFileName`, `openGeneration`)
- Private fields prefixed with `_` (e.g., `_items`, `_currentIndex`, `_mode`)

**Types/Classes:**
- `PascalCase` for classes, enums, mixins (e.g., `PlaybackController`, `MediaEngine`, `PlayMode`)
- Mixins: descriptive names (e.g., `FileOperations`, `PlaybackNavigator`, `StateMonitor`)

**Constants:**
- `SCREAMING_SNAKE_CASE` for top-level constants (e.g., `_prepareTimeoutSeconds`, `_textureTimeoutSeconds`)
- Private constants prefixed with `_` (e.g., `_keyVolume`, `_keyLastFile`)
- SharedPreferences keys follow `_key` prefix pattern: `_keyVolume`, `_keyWindowWidth`

**Booleans:**
- Prefer `is`, `has`, `should` prefixes (e.g., `isMuted`, `isBuffering`, `isEmpty`, `isFullscreen`, `hasNext`, `hasPrevious`)

## Code Style

**Formatting:**
- `dart format` for all `.dart` files
- Line length: 80 characters (dart format default)
- Trailing commas on multi-line argument/parameter lists

**Linting:**
- `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`
- No custom lint rules beyond defaults

## Import Organization

**Order:**
1. `dart:` imports (e.g., `dart:io`, `dart:async`, `dart:math`)
2. External `package:` imports (e.g., `package:flutter/foundation.dart`, `package:fvp/mdk.dart`)
3. Internal `package:` imports (e.g., `package:simple_player_flutter/kernel/...`)
4. Relative imports for same-module files (e.g., `../models/media_state.dart`)

**Path Style:**
- Relative imports used within kernel module: `import '../models/media_state.dart'`
- Package imports for cross-module: `import 'package:simple_player_flutter/kernel/utils/path_validator.dart'`
- Log utility imported as: `import 'package:simple_player_flutter/kernel/utils/log.dart'`

## Error Handling

**Patterns:**
- Guard clause: check `_disposed` before any operation (e.g., `if (_disposed) return;`)
- `_guardedAction` pattern in `FvpEngine`: wraps try-catch + log + sets `errorMessage.value`
- Try-catch with `on Exception catch (e)` — never bare `catch (e)`
- Log errors with `log.d()` (kernel-wide Logger instance)
- Set `errorMessage.value` for user-visible errors
- Graceful fallback: `SettingsStore.load()` returns defaults on failure, never crashes
- Validation errors stored in `validationError` ValueNotifier, not thrown

**Specific patterns from `lib/kernel/engine/fvp_engine.dart`:**
```dart
// Guard clause + try-catch + error message
void _guardedAction(String name, void Function() action) {
  if (_disposed) return;
  try {
    action();
  } on Exception catch (e) {
    log.d('FvpEngine.$name error: $e');
    errorMessage.value = '$name failed: $e';
  }
}
```

**SettingsStore pattern from `lib/kernel/persistence/settings_store.dart`:**
```dart
// Generic save helper with try-catch
static Future<void> _save(String method, Future<void> Function(SharedPreferences prefs) op) async {
  try {
    final prefs = await _getPrefs();
    await op(prefs);
  } on Exception catch (e) {
    log.d('SettingsStore.$method failed: $e');
  }
}
```

**Validation pattern from `lib/kernel/utils/path_validator.dart`:**
```dart
// Returns null for valid, error string for invalid
static String? validate(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return 'path is empty';
  if (isPathTraversal(trimmed)) return 'unsafe path: $trimmed';
  if (!isAllowedMedia(trimmed)) return 'unsupported file type: $trimmed';
  return null;
}
```

## Logging

**Framework:** `logger` package via `lib/kernel/utils/log.dart`

**Global instance:** `final Logger log = Logger(...)` — import as `log.d()`, `log.w()`

**Patterns:**
- `log.d()` for debug messages (most common)
- `log.w()` for warnings
- Minimal method count, no emojis, compact desktop output
- Only logs in debug mode (default filter)

**When to log:**
- Error catch blocks: `log.d('ComponentName.method error: $e')`
- State transitions: `log.d('[App] init completed in ${sw.elapsedMilliseconds}ms')`
- Validation failures: `log.d('playIndex: rejected unsafe path: $validationError')`
- Guard blocks: `log.w('FvpEngine.open() blocked — already opening')`

## Comments

**When to Comment:**
- Chinese comments are acceptable (existing codebase convention)
- Doc comments (`///`) on all public classes, mixins, and key methods
- Inline comments for non-obvious logic (e.g., `// PAR correction`)
- Section dividers: `// ─── Section Name ───`

**Doc Comment Style:**
```dart
/// FileOperations mixin — open/batch add files
///
/// Responsibilities: openAndPlay, addFiles, validationError
mixin FileOperations {
```

**Section Dividers:**
```dart
// ─── Playback Control ───
// ─── Audio/Subtitle (delegated to TrackManager) ───
// ─── Lifecycle ───
```

## Function Design

**Size:** Keep functions focused. Large operations decomposed into helpers (e.g., `_guardedAction`, `_sanitizeDimension`).

**Parameters:**
- Use named parameters with `required` for mandatory fields
- Optional parameters with defaults: `[int seconds = 10]`
- Defensive clamping: `value.clamp(0.0, 1.0)`

**Return Values:**
- CQS separation: query methods return values without side effects (e.g., `peekNext()` returns index without mutating `_currentIndex`)
- Command methods are void or return Future<void>
- Validation methods return `String?` (null = valid, string = error message)

## Module Design

**State Management:**
- `ValueNotifier` + `ValueListenableBuilder` pattern (no Provider/Riverpod/Bloc)
- `MediaEngine` exposes 13 ValueNotifiers as reactive state
- Widgets rebuild via `ValueListenableBuilder` wrappers

**Mixin Composition:**
- `PlaybackController` composed of 3 mixins: `FileOperations`, `PlaybackNavigator`, `StateMonitor`
- Mixins declare abstract getters for shared state: `MediaEngine get engine; Playlist get playlist;`
- Mixins implement shared methods: `void savePlaylist();`

**Singleton Pattern:**
- `PlatformService` uses factory singleton: `PlatformService.init()` in main(), `PlatformService.I` throughout app
- `@visibleForTesting static void reset()` for test teardown

**Data Classes:**
- Immutable with `copyWith()` pattern (e.g., `PlaylistItem`)
- `toJson()` / `fromJson()` for serialization
- Defensive deserialization: clamp values, skip corrupt items, fallback to defaults

**Abstract Interfaces:**
- `MediaEngine` defines the engine contract — all playback backends implement this
- UI layer depends only on the interface, not concrete implementations

## Defensive Programming

**Input Clamping:**
```dart
final clamped = value.clamp(0.0, 1.0);
```
All numeric inputs clamped to valid ranges at entry points.

**Index Validation:**
```dart
if (index < 0 || index >= playlist.length) return;
```
Bounds checks before any list access.

**Serialization Defense:**
```dart
final modeIndex = (json['mode'] as num?)?.toInt() ?? 0;
playlist._mode = (modeIndex >= 0 && modeIndex < PlayMode.values.length)
    ? PlayMode.values[modeIndex]
    : PlayMode.normal;
```
Clamp indices, skip corrupt items, fallback to defaults.

**Path Traversal Prevention:**
```dart
if (isPathTraversal(trimmed)) return 'unsafe path: $trimmed';
```
All file paths validated through `PathValidator.validate()` before use.

**Lifecycle Guards:**
```dart
if (_disposed) return;
```
Check `_disposed` flag before every operation in engine/services.

---

*Convention analysis: 2026-05-09*
