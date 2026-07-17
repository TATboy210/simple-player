> ⚠️ **v2.1 前快照（2026-07-12）** — 此文档描述 v2.1 重构前结构，Phase 15+ 一律对 LIVE code + codegraph 核对，勿信本快照具体路径/类名。保留作演进历史。

# Coding Conventions

**Analysis Date:** 2026-07-12

## Naming Patterns

**Files:**
- snake_case for all Dart files: `display_config.dart`, `engine_state.dart`
- Test files use `_test.dart` suffix: `display_config_test.dart`, `control_bar_test.dart`
- Feature directories use lowercase: `features/player/`, `kernel/engine/`

**Functions:**
- camelCase for all functions and methods: `getRefreshRate()`, `syncModeForHz()`
- Private methods prefixed with underscore: `_initImpl()`, `_detectRefreshRate()`
- Boolean getters use `is`/`has`/`can` prefix: `isPrimary`, `isBuffering`

**Variables:**
- camelCase for instance variables: `_cachedHz`, `_initialized`
- Private fields prefixed with underscore: `_displays`, `_inner`
- Constants use `static const`: `static const bgDeep = Color(...)`

**Types:**
- PascalCase for classes and enums: `DisplayConfig`, `MediaState`, `PlayMode`
- Enums use PascalCase values: `PlayMode.loopAll`, `MediaState.playing`

## Code Style

**Formatting:**
- Tool: `dart format` (standard Flutter formatter)
- Line length: 80 characters (default)
- Single quotes for strings: `'text'` not `"text"`

**Linting:**
- Tool: `flutter_lints` with strict mode enabled
- Key rules from `analysis_options.yaml`:
  - `strict-casts: true` — no implicit downcasts
  - `strict-inference: true` — explicit types required
  - `strict-raw-types: true` — no raw generic types
  - `prefer_const_constructors: true`
  - `prefer_final_locals: true`
  - `avoid_print: true` — use `debugPrint()` or logger
  - `unawaited_futures: true` — explicit async handling

## Import Organization

**Order:**
1. Dart SDK imports: `dart:async`, `dart:io`, `dart:ui`
2. Flutter imports: `package:flutter/material.dart`, `package:flutter_test/flutter_test.dart`
3. Third-party imports: `package:fvp/mdk.dart`, `package:logger/logger.dart`
4. Project imports: `package:simple_player_flutter/...`
5. Relative imports: `../../helpers/fake_engine.dart`

**Path Aliases:**
- No aliases — use full package paths: `package:simple_player_flutter/kernel/...`
- Relative imports allowed within same feature/test directory

## Error Handling

**Patterns:**
```dart
// Pattern 1: try-catch with logger
try {
  final display = PlatformDispatcher.instance.views.first;
  return 60;
} catch (e, st) {
  logBridge.e('[DisplayConfig._detectRefreshRate] $e\n$st');
  return 60; // safe default
}

// Pattern 2: Specific exception types
on Exception catch (e) {
  debugPrint('[Log] file logging init failed: $e');
}

// Pattern 3: Silent cleanup (only for non-critical operations)
try {
  _file.renameSync(archive.path);
} on Exception {
  // rename failed — continue with current file
}
```

**Rules:**
- Always catch specific exception types (not bare `catch (e)`)
- Provide safe fallback values for non-critical operations
- Log errors with context: `logBridge.e('[ClassName.method] $e')`
- Never silently swallow errors in critical paths

## Logging

**Framework:** `logger` package with custom `PrefixPrinter`

**Module Loggers:**
```dart
log          // Global logger (no prefix)
logEngine    // Engine module: [engine] prefix
logBridge    // Bridge module: [bridge] prefix
logServices  // Services module: [services] prefix
logUi        // UI module: [ui] prefix
```

**Patterns:**
```dart
// Debug logging
logEngine.d('[FvpEngine] open: $path');

// Error logging with stack trace
logBridge.e('[DisplayConfig._detectReleaseRate] $e\n$st');

// Warning logging (release mode only)
logServices.w('[PlaybackController] retry failed');
```

**Configuration:**
- Debug mode: Console output with colors, all levels
- Release mode: File output to `%APPDATA%\SimplePlayer\logs\`, warning+ only
- Log rotation: 2 MB per file, keep 5 archives

## Comments

**When to Comment:**
- Class doc comments: Every public class and mixin
- Method doc comments: Non-trivial public methods
- Inline comments: Magic numbers, algorithms, side effects
- TODO/FIXME: Include brief explanation

**Language:** Chinese comments are OK (existing codebase convention)

**Examples:**
```dart
/// Refresh-rate-aware D3D11 sync mode policy.
///
/// Detects the primary display's refresh rate and derives the optimal
/// `d3d11.sync.cpu` value for the D3D11 rendering backend.
class DisplayConfig {
  DisplayConfig._();

  /// 内部实例 — 持有缓存状态，消除 static mutable state
  static final DisplayConfig _instance = DisplayConfig._();

  // 安全降级 — 未检测时假设 60Hz，选择同步模式（最安全）
  int _cachedHz = 60;
}
```

## Function Design

**Size:** <50 lines preferred, <20 for pure logic

**Parameters:** Use named parameters for optional arguments:
```dart
void configureMedia({
  int durationMs = 60000,
  List<AudioTrackInfo>? audioTracks,
  List<SubtitleTrackInfo>? subtitleTracks,
}) { ... }
```

**Return Values:** Explicit return types required (strict mode)

## Module Design

**Exports:** Use `export` for barrel files:
```dart
// engine_state.dart
export 'media_error_type.dart';
export 'models/media_info.dart';
export 'media_state.dart';
```

**Barrel Files:** Used for feature modules (e.g., `engine_state.dart` exports all engine types)

## Design System Enforcement

**All visual values via `Tokens.*`:**
```dart
// CORRECT
color: Tokens.controlBarBg,
borderRadius: BorderRadius.circular(Tokens.controlBarRadius),

// WRONG — hardcoded values
color: Color(0xFF0C0F18),
borderRadius: BorderRadius.circular(16),
```

**Glass-morphism pattern:**
```dart
BackdropFilter(
  filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
  child: Container(
    decoration: BoxDecoration(
      color: Tokens.bgGlass,
      border: Border.all(color: Tokens.borderHighlight),
    ),
  ),
)
```

## State Management

**Pattern:** ValueNotifier + ValueListenableBuilder

```dart
// Engine state
final ValueNotifier<MediaState> state = ValueNotifier(MediaState.idle);
final ValueNotifier<int> position = ValueNotifier(0);

// Widget rebuild
ValueListenableBuilder<int>(
  valueListenable: engine.position,
  builder: (context, value, child) {
    return Text(formatMs(value));
  },
)
```

**Rules:**
- No Provider/Riverpod/Bloc — use ValueNotifier only
- Expose state as `ValueNotifier<T>` fields
- Widgets rebuild via `ValueListenableBuilder`

## Async Best Practices

```dart
// Always await or explicitly mark fire-and-forget
unawaited(EnginePrewarm.prewarm(...));

// Check context.mounted after await
await someAsyncOperation();
if (!context.mounted) return;

// Use Future.wait for concurrent operations
final results = await Future.wait([op1(), op2()]);
```

---

*Convention analysis: 2026-07-12*
