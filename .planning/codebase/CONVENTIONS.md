# Coding Conventions

**Analysis Date:** 2026-06-23

## Naming Patterns

**Files:**
- Use `snake_case.dart` for all Dart files
- Test files: `{name}_test.dart` (mirrors lib structure)
- Pattern: descriptive names like `playback_controller.dart`, `glass_container.dart`

**Classes:**
- Use `PascalCase` for all classes and enums
- Examples: `PlaybackController`, `GlassContainer`, `MediaState`, `PlayMode`

**Functions/Methods:**
- Use `camelCase` for all functions and methods
- Private methods prefixed with underscore: `_flush()`, `_ensureSink()`
- Getters use `is/has/should` prefix for booleans: `isEmpty`, `hasVideo`, `hasAudio`

**Variables:**
- Use `camelCase` for all variables and parameters
- Private fields prefixed with underscore: `_debounce`, `_pendingJson`
- Constants use `camelCase` (Dart convention): `static const _fileName = 'playlist.json'`
- Public constants: `supportedExtensions`, `allowedExtensions`

**Enums:**
- Use `PascalCase` for enum names: `MediaState`, `PlayMode`, `GlassTier`
- Use `camelCase` for enum values: `MediaState.playing`, `PlayMode.loopAll`

## Code Style

**Formatting:**
- Follow Dart default formatting (dart format)
- 2-space indentation
- Single quotes preferred (enforced by `prefer_single_quotes` lint)

**Linting:**
- Strict mode enabled: `strict-casts`, `strict-inference`, `strict-raw-types`
- Missing required params → error
- Missing return → error
- Dead code → warning
- Key lints enforced:
  - `prefer_const_constructors`
  - `prefer_final_locals`
  - `avoid_print`
  - `always_declare_return_types`
  - `unawaited_futures`

**File Length:**
- Target < 500 lines (see `control_bar.dart` at 350 lines)
- Maximum 800 lines (extract modules when approaching)

**Function Length:**
- Target < 50 lines for pure logic
- Target < 50 lines for UI builders
- Maximum 80 lines (split into smaller functions)

## Import Organization

**Order:**
1. Dart core libraries (`dart:io`, `dart:convert`, `dart:async`)
2. Flutter framework (`package:flutter/...`)
3. Third-party packages (`package:player_engine/...`, `package:logger/...`)
4. Project imports (relative paths for same layer, absolute for cross-layer)

**Path Aliases:**
- No path aliases configured
- Use relative imports for files in same directory/layer
- Use package imports for cross-layer dependencies

**Example:**
```dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:player_engine/player_engine.dart';
import '../models/play_mode.dart';
import '../playlist/playlist.dart';
```

## Error Handling

**Patterns:**
- Always use `on Exception catch (e)` (never bare `catch (e)`)
- Log errors with context: `log.e('PlaylistStore.load failed: $e')`
- Provide graceful fallbacks (return null, empty list, or default value)
- Never silently swallow errors (`catch (_) {}` is forbidden)

**Error Types:**
- Use `FormatException` for data parsing errors
- Use `Exception` for general errors
- Never catch `Error` subtypes (they indicate programming bugs)

**Example:**
```dart
try {
  // risky operation
} on Exception catch (e) {
  log.e('Operation failed: $e');
  return null; // graceful fallback
}
```

## Logging

**Framework:** `package:logger` with custom `PrefixPrinter`

**Module Loggers:**
- `log` — global logger (no prefix)
- `logEngine` — engine layer (`[engine]` prefix)
- `logBridge` — bridge layer (`[bridge]` prefix)
- `logServices` — services layer (`[services]` prefix)
- `logUi` — UI layer (`[ui]` prefix)

**Log Levels:**
- `log.d(...)` — debug info (development only)
- `log.i(...)` — informational
- `log.w(...)` — warnings (failures with fallback)
- `log.e(...)` — errors (failures requiring attention)

**Production Behavior:**
- Debug mode: console output only
- Release mode: warning+ level, file rotation (2MB max, 5 archives)
- Log location: `%APPDATA%\SimplePlayer\logs\`

## Comments

**When to Comment:**
- Always document public APIs with `///` doc comments
- Explain "why" not "what" for complex logic
- Use Chinese comments (codebase convention)
- Document edge cases and security considerations

**Doc Comment Format:**
```dart/// 路径安全校验工具
///
/// 统一的文件路径校验：扩展名白名单、路径遍历检测。
/// 所有文件打开入口（FilePicker、拖放、历史记录）必须通过此工具校验。class PathValidator { ... }
```

**Inline Comments:**
- Use Chinese for explanations: `// 从末尾找最后一个 / 或 \`
- Use English for technical notes: `// Wait for async yield`

## Design System

**Tokens:**
- All visual values via `Tokens.*` constants (defined in `lib/ui/theme/tokens.dart`)
- Colors: `Tokens.bgBase`, `Tokens.accent`, `Tokens.textPrimary`
- Spacing: `Tokens.spXs` (4), `Tokens.spSm` (8), `Tokens.spMd` (12), `Tokens.spLg` (16)
- Border radius: `Tokens.radiusSm` (6), `Tokens.radiusMd` (10), `Tokens.radiusLarge` (12)
- Animation durations: `Tokens.durationFast` (80ms), `Tokens.durationNormal` (150ms)

**Glassmorphism Pattern:**
```dart
GlassContainer(
  tier: GlassTier.normal,  // thin/normal/thick
  blurEnabled: true,
  resizing: resizingNotifier,  // optional ValueNotifier<bool>
  child: ...,
)
```

**Theme:**
- Single theme: Midnight (compile-time const)
- Font: Noto Sans SC (Regular 400, Medium 500, SemiBold 600)
- No dynamic theming (no ThemeMode.light)

## State Management

**Pattern:** ValueNotifier + ValueListenableBuilder (no Provider/Riverpod/Bloc)

**Engine State:**
- `PlayerEngine` exposes `ValueNotifier` fields: `state`, `position`, `duration`, `volume`, etc.
- Widgets rebuild via `ValueListenableBuilder`
- Example:
```dart
ValueListenableBuilder<MediaState>(
  valueListenable: engine.state,
  builder: (context, state, child) {
    if (state == MediaState.playing) return PauseButton();
    return PlayButton();
  },
)
```

**Controller Pattern:**
- `PlaybackController` orchestrates playlist + engine state
- Uses composition: `PlaybackNavigator`, `FileOperations`, `StateMonitor`
- Callbacks for UI updates: `onNeedRebuild`, `onError`

## Immutability

**Data Classes:**
- Use `final` fields
- Provide `copyWith()` method for immutable updates
- Override `==` and `hashCode` for value equality
- Example: `PlaylistItem` with `path`, `timestamp`, `positionMs`

**Collections:**
- Use `List.unmodifiable()` for read-only lists
- Avoid mutating passed-in collections

## Async Patterns

**Future Handling:**
- Always `await` Futures or explicitly call `unawaited()`
- Never mark function `async` if it never `await`s
- Check `context.mounted` before using `BuildContext` after `await`

**Isolate Usage:**
- Use `Isolate.run()` for heavy I/O operations
- Example: `PlaylistStore.loadInBackground()` runs JSON parsing in isolate
- Fallback to main isolate on failure

## FFI / Platform Integration

**MethodChannel Naming:**
- Channel: `com.simple_player/window`
- Commands: `setFullscreen`, `setTitle`, `setFrameless`, etc.
- Events: `onResize`, `onClose`, `onMaximize`

**Memory Management:**
- Always free FFI memory in `finally` blocks
- Copy strings crossing thread boundaries
- Document memory ownership

## Testing Conventions

**Test Structure:**
- Follow AAA pattern (Arrange-Act-Assert)
- Use `group()` for logical test grouping
- Use descriptive test names: `'rejects invalid path (empty string)'`

**Mocking:**
- Prefer hand-written fakes over mocks
- Example: `FakeEngine` implements `PlayerEngine`
- Track call counts for verification: `openCallCount`, `playCallCount`

**Widget Tests:**
- Wrap in `MaterialApp` + `Scaffold`
- Use `buildSubject()` helper for widget construction
- Test with `FakeEngine` instead of real engine

---

*Convention analysis: 2026-06-23*
