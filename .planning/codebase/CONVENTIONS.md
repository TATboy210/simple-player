# Coding Conventions

**Analysis Date:** 2026-07-03

## Naming Patterns

**Files:**
- `snake_case.dart` for all source files: `glass_container.dart`, `playback_controller.dart`, `position_poller.dart`
- Private files prefixed with underscore: `_settings_nav_item.dart`
- Test files suffixed `_test.dart`, mirroring source path: `test/kernel/utils/time_utils_test.dart` for `lib/kernel/utils/time_utils.dart`

**Classes:**
- `PascalCase` for classes, enums, mixins, typedefs: `GlassContainer`, `MediaState`, `EngineState`
- Private classes prefixed with `_`: `_RotatingFileOutput`, `_OsdOverlayState`
- Capability marker mixins: `TrackControl`, `VideoEffects`, `RendererConfig`

**Functions/Methods:**
- `camelCase`: `formatMs()`, `openAndPlay()`, `seekTo()`
- Private prefixed with `_`: `_flushImpl()`, `_migrateHistory()`
- Boolean getters: `isAllowedMedia()`, `isPathTraversal()`, `hasVideo`, `isEmpty`

**Variables:**
- `camelCase` for locals and fields: `rebuildCount`, `currentFileName`
- Private fields prefixed with `_`: `_disposed`, `_debounce`, `_pendingJson`
- Constants: `camelCase` for private (`_debounceMs`, `_maxRetries`), `UPPER_SNAKE_CASE` rarely used

**Enum Values:**
- `camelCase`: `loopAll`, `loopSingle`, `seeking`, `buffering`

## Code Style

**Formatting:**
- `dart format` (standard Dart formatter)
- Trailing commas on multi-line argument lists
- 2-space indentation

**Linting:**
- Config: `analysis_options.yaml`
- Base: `package:flutter_lints/flutter.yaml`
- Strict mode: `strict-casts: true`, `strict-inference: true`, `strict-raw-types: true`
- Errors: `missing_required_param: error`, `missing_return: error`
- Key rules: `prefer_const_constructors`, `prefer_final_locals`, `avoid_print`, `prefer_single_quotes`, `always_declare_return_types`, `avoid_void_async`, `cancel_subscriptions`, `close_sinks`, `unawaited_futures`

**Key Style Rules:**
- Always use `Tokens.*` for colors, spacing, radius, fonts -- never hardcode visual values
- Always use `debugPrint()` or the `log` module logger -- never `print()`
- Use `const` constructors where possible
- Use `final` for all local variables that are not reassigned
- Prefer single quotes for strings

## Import Organization

**Order:**
1. `dart:` imports (`dart:async`, `dart:convert`, `dart:io`, `dart:developer`)
2. `package:flutter/` imports
3. `package:` third-party imports (`package:logger/logger.dart`, `package:path/path.dart`)
4. Relative imports (kernel, features, ui)

**Path Aliases:**
- No path aliases used -- all imports are relative or package-based

**Barrel Files:**
- `engine_state.dart` re-exports `media_state.dart`, `media_error_type.dart`, `models/media_info.dart`, `track_control.dart`, `video_effects.dart`, `renderer_config.dart`
- `glass_widgets.dart` re-exports `glass_container.dart`, `glass_chip.dart`
- `settings_store.dart` re-exports `models/app_settings.dart`
- Usage: `import '../shared/glass_widgets.dart';`

## State Management

**Pattern:** `ValueNotifier` + `ValueListenableBuilder` (no Provider/Riverpod/Bloc)

```dart
// Engine exposes ValueNotifiers
final ValueNotifier<MediaState> state = ValueNotifier(MediaState.idle);
final ValueNotifier<int> position = ValueNotifier(0);
final ValueNotifier<double> volume = ValueNotifier(1.0);

// Widgets listen via ValueListenableBuilder
ValueListenableBuilder<MediaState>(
  valueListenable: engine.state,
  builder: (context, state, child) { ... },
)
```

**File:** `lib/kernel/engine/engine_state.dart` -- `EngineState` mixin defines all ValueNotifier fields

**Rules:**
- UI widgets never directly modify engine state -- use `PlayerActions` callbacks or engine methods
- `PlayerActions` (`lib/ui/player/player_actions.dart`) bundles all UI-to-controller callbacks
- Widgets receive `EngineState` (mixin), never `FvpEngine` (concrete class)

## Error Handling

**Patterns:**
- `try-catch` with typed `on Exception` (not bare `catch (e)`)
- Graceful fallback: log error + return safe default, never crash

```dart
// Storage: log + return null/empty
} on Exception catch (e) {
  log.e('PlaylistStore.load failed: $e');
  return null;
}

// UI actions: log + no-op
} on Exception catch (e) {
  debugPrint('[FolderScanner] Failed to scan "$directory": $e');
  return [];
}
```

**Structured Errors:**
- `PlayerError` (`lib/kernel/models/player_error.dart`) with `PlayerErrorCode` enum
- `ValidationResult` pattern: `String? validate(path)` returns null for valid, error message for invalid

**Singleton Reset for Tests:**
- `@visibleForTesting` static `reset()` / `resetPrewarm()` methods on singletons
- Example: `SettingsStore.resetPrewarm()`, `PlaylistStore.reset()`

## Logging

**Framework:** `package:logger` with custom `PrefixPrinter`

**File:** `lib/kernel/utils/log.dart`

**Module Loggers:**
```dart
log         // global (no prefix)
logEngine   // [engine] prefix
logBridge   // [bridge] prefix
logServices // [services] prefix
logUi       // [ui] prefix
```

**Rules:**
- Use `debugPrint()` for simple debug output
- Use `log.d()` / `log.w()` / `log.e()` for structured logging with module context
- Release mode: `ProductionFilter` (warning+), rotating file output at `%APPDATA%\SimplePlayer\logs\`
- Debug mode: console-only, all levels

**Performance Logging:**
- `DebugProbe` (`lib/kernel/utils/debug_probe.dart`) -- compile-time gated (`kDebugMode`), tree-shaken in release
- `PerfMonitor` (`lib/kernel/utils/perf_monitor.dart`) -- frame timing via `SchedulerBinding.addTimingsCallback`

## Comments

**When to Comment:**
- Every public class, enum, mixin, and non-trivial function gets a `///` doc comment
- Chinese comments are acceptable (existing codebase convention)
- Inline comments for non-obvious logic: explain *why*, not *what*
- Section dividers: `// --- Section Name ---`

```dart
/// 播放控制器 — 播放器全部运行时能力的统一入口
///
/// 组合 PlaybackNavigator / FileOperations / StateMonitor 三个子模块，
/// UI 层只与本类交互。
class PlaybackController { ... }
```

**Design Decision Tags:**
- `D-03`, `D-08`, `D-13`, `D-14`, `D-15` -- reference design decision documents
- Example: `// D-13: opacity < 0.01 skips BackdropFilter`

## Function Design

**Size:** Functions < 50 lines (20 for pure logic, 50 for UI builders). Split large functions.

**Parameters:**
- Use `required` for mandatory constructor params
- Named parameters for optional/configurable params
- `VoidCallback` for no-arg event handlers

```dart
const PlayerActions({
  this.onPrevious,
  this.onNext,
  this.onToggleFullscreen,
  this.isVideo = false,
});
```

**Return Values:**
- `Future<bool>` for operations with success/fail outcome
- `String?` for validation (null = valid, string = error message)
- `List<T>` for queries (empty list on error, never null)

## Module Design

**Exports:**
- Barrel files for public API surfaces
- `show` clauses to limit re-exports: `export 'glass_container.dart' show GlassContainer, GlassButton, GlassTier;`

**Singleton Pattern:**
- Private constructor + static `_instance` + static methods
- `@visibleForTesting` `reset()` for test isolation

```dart
class PlaylistStore {
  static PlaylistStore _instance = PlaylistStore();
  PlaylistStore({String? storagePath}) : _storagePath = storagePath;

  static void save(Playlist playlist) => _instance._saveImpl(playlist);

  @visibleForTesting
  static void reset({PlaylistStore? newInstance}) { ... }
}
```

**Mixin Composition:**
- `EngineState` mixin defines interface
- Capability mixins: `TrackControl`, `VideoEffects`, `RendererConfig` (marker mixins)
- `FvpEngine with EngineState, TrackControl, VideoEffects, RendererConfig`
- `FakeEngine with EngineState, TrackControl, VideoEffects, RendererConfig`

## Immutability

**Data Classes:**
- `copyWith()` pattern for immutable updates
- `==` and `hashCode` overrides
- `toJson()` / `fromJson()` for serialization

```dart
class PlaylistItem {
  PlaylistItem copyWith({int? timestamp, int? positionMs, int? durationMs}) {
    return PlaylistItem(path: path, timestamp: timestamp ?? this.timestamp, ...);
  }
}
```

**Nullable `copyWith` Fields:**
- Use `_sentinel` pattern to distinguish "not provided" from "explicitly set to null"

```dart
class AppSettings {
  static const _sentinel = Object();
  AppSettings copyWith({Object? windowX = _sentinel, ...}) {
    return AppSettings(windowX: windowX == _sentinel ? this.windowX : windowX as double?, ...);
  }
}
```

## Design System

**File:** `lib/ui/theme/tokens.dart` -- `Tokens` class with static const fields

**Usage:**
- All colors via `Tokens.bgDeep`, `Tokens.accent`, `Tokens.textPrimary`, etc.
- All spacing via `Tokens.spXs` (4), `Tokens.spSm` (8), `Tokens.spMd` (12), `Tokens.spLg` (16), `Tokens.spXl` (24)
- All radius via `Tokens.radiusSm` (8), `Tokens.radiusMd` (14), `Tokens.radiusLg` (22), `Tokens.radiusXl` (32)
- All fonts via `Tokens.fontFamily`, `Tokens.fontBody` (14), `Tokens.fontCaption` (12)
- All animation durations via `Tokens.durationFast` (80), `Tokens.durationNormal` (150), `Tokens.durationFade` (300)
- Glass blur via `Tokens.glassBlurThin` (4), `Tokens.glassBlur` (10), `Tokens.glassBlurThick` (12)

**Glassmorphism Pattern:**
```dart
GlassContainer(
  tier: GlassTier.normal,
  opacity: opacityNotifier,
  blurEnabled: true,
  backgroundColor: Tokens.bgGlass,
  child: ...,
)
```

## Async Patterns

**Rules:**
- Always `await` Futures or explicitly call `unawaited()` for fire-and-forget
- Never mark a function `async` if it never `await`s anything
- Check `context.mounted` before using `BuildContext` after any `await`
- Debounce for I/O: `PlaylistStore` uses 300ms debounce timer
- Atomic writes: write `.tmp` then `rename()` for crash safety

## FFI / Platform Bridge

**MethodChannel:** `com.simple_player/window` for Win32 bridge
**File:** `lib/kernel/bridge/` -- platform-specific implementations
**Pattern:** Always free FFI memory in `finally` blocks; document memory ownership

---

*Convention analysis: 2026-07-03*
