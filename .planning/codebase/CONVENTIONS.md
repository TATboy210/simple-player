# Coding Conventions

**Analysis Date:** 2026-05-23

## Naming Patterns

**Files:**
- `snake_case.dart` for all Dart files (e.g., `playback_controller.dart`, `glass_container.dart`)
- Private widgets use underscore prefix in class name but not filename (e.g., `_QuickMenuItem` in `app.dart`)
- Test files mirror source path: `lib/kernel/services/path_validator.dart` → `test/kernel/services/path_validator_test.dart`

**Functions:**
- `camelCase` for all functions and methods (e.g., `openAndPlay`, `togglePlayPause`, `playIndex`)
- Private members prefixed with `_` (e.g., `_disposed`, `_currentPath`, `_isOpening`)
- Boolean getters use `is`/`has` prefix (e.g., `isMuted`, `isBuffering`, `isEmpty`)

**Variables:**
- `camelCase` for local variables and parameters
- `SCREAMING_SNAKE_CASE` for compile-time constants only in `Tokens` class (e.g., `bgBase`, `fontBody`)
- Private fields: `_fieldName` (e.g., `_engine`, `_playlist`, `_disposed`)

**Types:**
- `PascalCase` for classes, enums, typedefs (e.g., `PlaybackController`, `MediaState`, `GlassTier`)
- Enum values: `camelCase` (e.g., `MediaState.playing`, `WindowMode.windowed`)
- Sealed/abstract classes: descriptive names (e.g., `MediaEngine`, `ThumbnailProvider`)

**Constants:**
- In `Tokens` class: short descriptive names without prefix (e.g., `bgBase`, `accent`, `spSm`)
- In other classes: `static const` with descriptive names (e.g., `_prepareTimeoutSeconds`, `_defaultSkipSeconds`)

## Code Style

**Formatting:**
- `dart format` enforced (80-char line length default)
- Trailing commas on multi-line argument/parameter lists
- Consistent 2-space indentation

**Linting:**
- `flutter_lints` package (`analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`)
- No custom lint rules beyond defaults

**Design Tokens:**
- ALL visual values via `Tokens.*` constants from `lib/kernel/ui/theme/tokens.dart`
- No hardcoded colors, font sizes, spacing, or border radii in widgets
- Example: `Tokens.bgGlass`, `Tokens.textPrimary`, `Tokens.radiusLarge`, `Tokens.spSm`

## Import Organization

**Order:**
1. `dart:` imports (e.g., `dart:ui`, `dart:async`, `dart:convert`)
2. `package:flutter/` imports (e.g., `package:flutter/material.dart`)
3. External `package:` imports (e.g., `package:fvp/mdk.dart`, `package:shared_preferences`)
4. Relative imports for same-layer code (e.g., `../models/media_state.dart`)

**Path Style:**
- Relative imports within the same package (e.g., `import '../engine/media_engine.dart'`)
- No `package:simple_player_flutter/` prefix for internal imports

## State Management

**Pattern: ValueNotifier + ValueListenableBuilder**

This project does NOT use Provider, Riverpod, BLoC, or any external state management.

- Services expose `ValueNotifier<T>` fields for reactive state
- Widgets rebuild via `ValueListenableBuilder<T>` wrappers
- Multiple notifiers composed via nested `ValueListenableBuilder` or custom `ValueListenableBuilder2`

```dart
// Service pattern (from lib/kernel/engine/media_engine.dart)
abstract class MediaEngine {
  ValueNotifier<int?> get textureId;
  ValueNotifier<MediaState> get state;
  ValueNotifier<int> get position;
  ValueNotifier<double> get volume;
  // ... 10+ ValueNotifiers
}

// Widget pattern (from lib/app.dart)
ValueListenableBuilder<int>(
  valueListenable: _themeIndex,
  builder: (context, themeIdx, _) => ValueListenableBuilder<Locale>(
    valueListenable: _locale,
    builder: (context, locale, _) => MaterialApp(/* ... */),
  ),
)
```

**Disposable Pattern:**
- Every class with ValueNotifiers must call `.dispose()` on all notifiers
- Use `_disposed` guard flag to prevent post-dispose operations
- `dispose()` method must be idempotent

```dart
// From lib/kernel/services/video_processing_service.dart
void dispose() {
  if (_disposed) return;
  _disposed = true;
  _persistDebounce?.cancel();
  brightness.dispose();
  contrast.dispose();
  // ... dispose all notifiers
}
```

## Error Handling

**Patterns:**
- `try/on Exception catch` with specific exception types (never bare `catch (e)`)
- `debugPrint()` for logging errors (never `print()`)
- Graceful fallback: catch + debugPrint + continue (never crash)
- Validation errors surfaced via `ValueNotifier<String?>` (e.g., `validationError`)

```dart
// From lib/kernel/services/file_operations.dart
try {
  await playIndex(idx);
  return true;
} on Exception catch (e) {
  validationError.value = e.toString();
  return false;
}

// From lib/kernel/engine/fvp_engine.dart
void _guardedAction(String name, void Function() action) {
  if (_disposed) return;
  try {
    action();
  } on Exception catch (e) {
    debugPrint('FvpEngine.$name error: $e');
    _errorType = MediaErrorType.playback;
    errorMessage.value = '$name failed: $e';
  }
}
```

**Guard Clauses:**
- Every public method checks `_disposed` first
- Input validation at entry points (e.g., `PathValidator.validate()`)
- `clamp()` on numeric inputs to prevent invalid ranges

## Logging

**Framework:** `logger` package (`lib/kernel/utils/log.dart`)

**Patterns:**
- `debugPrint()` for simple debug messages (Flutter built-in)
- `log` instance from `lib/kernel/utils/log.dart` for structured logging
- Chinese error messages acceptable (existing codebase convention)
- Format: `[ClassName] methodName failed: $e`

```dart
// From lib/kernel/utils/log.dart
final Logger log = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 4,
    lineLength: 100,
    colors: true,
    printEmojis: false,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);
```

## Comments

**When to Comment:**
- Chinese doc comments on classes and public APIs (existing convention)
- `///` doc comments for public classes, methods, and properties
- Inline `//` comments for non-obvious logic
- Section separators: `// ─── Section Name ───`

**JSDoc/TSDoc:**
- Use Dart doc comments (`///`) for public APIs
- Include parameter descriptions for non-obvious parameters
- State machine documentation in enum comments (e.g., `MediaState`)

```dart
/// 播放控制器 — 业务编排层（Orchestrator）
///
/// 由 3 个 mixin 组合而成:
///   - FileOperations: 文件打开（校验 → 添加到列表 → 播放）
///   - PlaybackNavigator: 播放列表导航（上一首/下一首/指定索引）
///   - StateMonitor: 自动连播、断点保存、设置恢复、播放列表管理
class PlaybackController with FileOperations, PlaybackNavigator, StateMonitor {
```

## Function Design

**Size:** Keep functions under 50 lines. Extract complex logic into helpers.

**Parameters:**
- Use named parameters with `required` for mandatory ones
- Default values for optional parameters (e.g., `[int seconds = 10]`)
- `VoidCallback` for simple callbacks, typed `Function` for complex ones

**Return Values:**
- `Future<bool>` for success/failure operations (e.g., `openAndPlay`)
- `Future<void>` for fire-and-forget async (e.g., `playIndex`)
- `String?` for nullable results (e.g., `validate` returns null on success)
- `int` for counts (e.g., `addFiles` returns added count)

## Module Design

**Composition over Inheritance:**
- `PlaybackController` uses `with` mixins (`FileOperations`, `PlaybackNavigator`, `StateMonitor`)
- `FvpEngine` delegates to helpers (`FvpCallbackHandler`, `PositionPoller`, `TrackManager`)
- Abstract interfaces for testability (`MediaEngine`)

**Dependency Injection:**
- Constructor injection for services (e.g., `PlaybackController(engine: engine, playlist: playlist)`)
- Static singleton pattern for cross-cutting concerns (e.g., `WindowService.instance`)
- `@visibleForTesting` for test-only reset methods (e.g., `SettingsStore.resetPrewarm()`)

```dart
// From lib/window/window_service.dart
class WindowService {
  static final WindowService instance = WindowService._();
  WindowService._();
  // ...
}
```

**Singleton Pattern:**
- Direct static singleton access for platform services
- `WindowService.instance` for window operations
- `WindowLifecycleBus.instance` for window event bus

## Concurrency Patterns

**Debouncing:**
- `Timer`-based debounce for persistence operations (50ms-500ms)
- Cancel previous timer on rapid calls
- Example: `VideoProcessingService._persistDebounce` (50ms), `PlaylistStore` (500ms)

```dart
// From lib/kernel/services/video_processing_service.dart
void schedulePersist() {
  _persistDebounce?.cancel();
  _persistDebounce = Timer(const Duration(milliseconds: 50), _persistAll);
}
```

**Generation Guards:**
- Integer counter incremented per async operation
- Check counter value after await to discard stale results
- Example: `PlaybackNavigator.openGeneration`

```dart
// From lib/kernel/services/playback_navigator.dart
final gen = ++openGeneration;
await engine.open(current.path);
if (gen != openGeneration) return; // discard stale
```

## Conventional Commits

**Format:** `<type>: <description>`

**Types:** `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`, `perf:`, `ci:`

**Examples:**
- `feat: settings system redesign — draggable panel, OK/Cancel/Apply`
- `fix: UI refinements for control bar, OSD overlay, and app shell`
- `refactor: extract control bar into independent widgets`

---

*Convention analysis: 2026-05-23*
