# Coding Conventions

**Analysis Date:** 2026-05-09

## Naming Patterns

**Files:**
- `snake_case.dart` for all Dart files (Dart convention)
- Examples: `playback_controller.dart`, `fvp_engine.dart`, `playlist_item.dart`

**Classes:**
- `PascalCase` for classes, enums, typedefs
- Examples: `PlaybackController`, `MediaEngine`, `PlaylistItem`, `PlayMode`, `MediaState`

**Functions/Methods:**
- `camelCase` for all functions and methods
- Examples: `playIndex()`, `openAndPlay()`, `seekTo()`, `setVolume()`

**Variables:**
- `camelCase` for local variables and parameters
- Private members prefixed with `_`
- Examples: `_player`, `_disposed`, `_currentPath`, `openGeneration`

**Constants:**
- `camelCase` for class-level constants (Dart convention, not SCREAMING_SNAKE)
- Examples: `_prepareTimeoutSeconds`, `_defaultSkipSeconds`, `_urlSchemes`

**Enums:**
- `PascalCase` enum name, `camelCase` values
- Examples: `MediaState.idle`, `PlayMode.loopAll`, `VideoEffectType.brightness`

## Code Style

**Formatting:**
- Dart default formatter (`dart format`)
- Line length: 80 characters (Dart default)
- Trailing commas on multi-line argument lists

**Linting:**
- `package:flutter_lints/flutter.yaml` via `analysis_options.yaml`
- No custom lint rules configured

## Import Organization

**Order:**
1. `dart:*` imports first
2. External `package:` imports (flutter, fvp, shared_preferences, etc.)
3. Internal `package:simple_player_flutter/` imports
4. Relative imports (`../models/`, `../utils/`) for same-package kernel code

**Pattern observed:**
```dart
import 'package:simple_player_flutter/kernel/utils/log.dart'; // package import first
import 'dart:async';                                          // dart: after (inconsistent)
import 'package:flutter/foundation.dart';                     // external package
import '../models/media_state.dart';                          // relative for kernel
```

**Path aliases:** None used. All imports use relative paths within kernel or package imports.

## Error Handling

**Pattern: Guard Clause + try-catch + debugPrint**

Every public method follows this pattern:
```dart
void someAction() {
  if (_disposed) return;  // Guard: disposed check
  try {
    // action
  } on Exception catch (e) {
    log.d('ClassName.method error: $e');  // Log with logger package
    errorMessage.value = '用户友好的错误消息: $e';  // Set error state
  }
}
```

**Key rules:**
- Always check `_disposed` before any action
- Use `on Exception catch (e)` — never bare `catch (e)`
- Use `log.d()` (Logger package) for debug logging — never `print()`
- Set `errorMessage.value` for user-facing errors (Chinese messages)
- Use `_guardedAction()` helper in `FvpEngine` for repetitive guard+try-catch
- `SettingsStore.load()` returns safe defaults on failure — never crashes
- Deserialization uses defensive clamping (e.g., `modeIndex.clamp(0, PlayMode.values.length - 1)`)

**Error propagation:**
- `onError` callback for notifying UI layer
- `validationError` ValueNotifier for path validation failures
- `errorMessage` ValueNotifier on MediaEngine for playback errors

## Logging

**Framework:** `logger` package (PrettyPrinter, methodCount: 0, no emojis)

**Implementation:** `lib/kernel/utils/log.dart`
```dart
final Logger log = Logger(
  printer: PrettyPrinter(methodCount: 0, errorMethodCount: 4, ...),
);
```

**Usage pattern:**
```dart
log.d('[ClassName] descriptive message: $context');
log.w('Warning message');
```

**Rules:**
- Use `log.d()` for debug info, `log.w()` for warnings
- Prefix messages with `[ClassName]` for source identification
- Include relevant context (path, error, state)
- Never use `print()` or `debugPrint()` for logging (use `log.*` instead)

## Comments

**When to Comment:**
- Chinese comments are acceptable and common throughout the codebase
- Document complex algorithms (e.g., CQS navigation, index clamping)
- Explain "why" not "what" for non-obvious decisions
- Use `///` doc comments for public APIs
- Use `//` for inline explanations

**Examples:**
```dart
/// 播放列表管理 — 状态机
///
/// 核心职责:
///   - 维护有序播放项列表
///   - 跟踪当前播放索引（add/remove/reorder 时自动调整）

// CQS 分离: next()/previous() 只返回新索引，不修改内部状态
// 设计决策: peekNext/peekPrevious 是纯查询，不修改 _currentIndex。
```

## Function Design

**Size:** Functions are typically 10-40 lines. Complex functions like `FvpEngine.open()` are ~80 lines but broken into clear sections.

**Parameters:**
- Use named parameters with `required` for mandatory params
- Use default values for optional params: `[int seconds = 10]`
- Clamp numeric inputs at entry: `value.clamp(0.0, 1.0)`

**Return Values:**
- `void` for commands (CQS pattern)
- `Future<void>` for async commands
- Return values for queries: `int peekNext()`, `String? validate()`
- `bool` for success/failure: `Future<bool> openAndPlay()`

## Module Design

**Exports:**
- Classes exported directly from their files (no barrel files)
- No `index.dart` or barrel export files detected

**Mixins:**
- `FileOperations`, `PlaybackNavigator`, `StateMonitor` are mixins composed into `PlaybackController`
- Mixins declare abstract getters for shared dependencies: `MediaEngine get engine;`
- Mixins use `on` clause for type constraints where needed

**Singletons:**
- `PlatformService.I` — factory singleton with `init()` / `reset()` pattern
- `SettingsStore` — static class with `_cachedPrefs` for prewarm optimization
- `log` — top-level final Logger instance

## State Management

**Pattern: ValueNotifier + ValueListenableBuilder**

- No Provider, Riverpod, or Bloc
- `MediaEngine` exposes 13 `ValueNotifier` fields for reactive state
- Widgets rebuild via `ValueListenableBuilder` wrappers
- `ValueNotifier` lifecycle: create in constructor, `dispose()` in `dispose()`

**Example:**
```dart
final ValueNotifier<MediaState> state = ValueNotifier<MediaState>(MediaState.idle);

@override
void dispose() {
  state.dispose();
  // ... dispose all notifiers
}
```

## Immutability

**Models:**
- `PlaylistItem` uses `copyWith()` for immutable updates
- `AppSettings` is `const` constructor with all `final` fields
- `MediaInfo`, `AudioTrackInfo`, `SubtitleTrackInfo`, `VideoCodecInfo` are all `const` with `final` fields
- `Playlist.items` returns `List.unmodifiable(_items)` to prevent external mutation

**Collections:**
- Internal lists are mutable (`_items`, `_players`)
- Public getters return unmodifiable views

## Conventional Commits

**Format:** `type: description`

**Types used:**
- `feat:` — new features
- `fix:` — bug fixes
- `refactor:` — code restructuring
- `test:` — test additions/changes
- `docs:` — documentation
- `chore:` — maintenance

## Dart 3 Features

**Pattern matching:**
```dart
final mdkEffect = switch (effect) {
  VideoEffectType.brightness => mdk.VideoEffect.brightness,
  VideoEffectType.contrast => mdk.VideoEffect.contrast,
  VideoEffectType.hue => mdk.VideoEffect.hue,
  VideoEffectType.saturation => mdk.VideoEffect.saturation,
};
```

**Sealed classes:** Not currently used (enums preferred for simple state)

## Defensive Programming

**Input validation at boundaries:**
- `PathValidator.validate()` — path traversal + extension whitelist
- `PathValidator.isAllowedMedia()` — extension check
- Numeric clamping: `value.clamp(min, max)` everywhere
- `fromJson` methods validate types: `if (path is! String) throw FormatException(...)`
- Window geometry sanitization: `_sanitizeDimension()`, `_sanitizeCoordinate()`

**Disposed guards:**
- Every public method on disposable classes checks `_disposed`
- Pattern: `if (_disposed) return;`

---

*Convention analysis: 2026-05-09*
