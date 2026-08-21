# Coding Conventions

**Analysis Date:** 2026-08-21

## Naming Patterns

**Files:**
- `snake_case.dart` for all Dart files (Dart convention enforced by tooling)
- Feature-prefixed grouping: `player_screen.dart`, `player_keyboard_actions.dart`, `player_video_controls.dart` in `lib/ui/player/`
- Test files mirror source path under `test/`: `lib/kernel/services/path_validator.dart` → `test/kernel/services/path_validator_test.dart`
- Fakes prefixed with `fake_`: `test/helpers/fake_engine.dart`, `test/helpers/fake_window_service.dart`
- Generated l10n files committed: `lib/l10n/app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_zh.dart`

**Functions:**
- `camelCase` for all functions and methods
- Booleans prefixed `is`/`has`/`should`/`can`: `isPlaying`, `isBuffering`, `hasMedia`, `isFullscreen`
- Private members prefixed `_`: `_disposed`, `_loadLibrary()`, `_onStateChanged()`

**Variables:**
- `camelCase` for locals and fields
- `final` preferred for all locals (enforced by `prefer_final_locals` lint in `analysis_options.yaml`)
- `SCREAMING_SNAKE_CASE` for top-level compile-time constants — NOT used; project uses `static const` class fields via `Tokens.*` instead

**Types:**
- `PascalCase` for classes, enums, sealed classes, extensions
- Enums carry semantic getters: `WindowMode.isFullscreen`, `MediaState` values
- Sealed class hierarchies for closed result/error sets: `sealed class OpenResult` (`lib/kernel/engine/open_result.dart`), `sealed class PlayerError` (`lib/kernel/models/player_error.dart`)

**Constants:**
- Design tokens: `static const` fields on `Tokens` class (`lib/ui/theme/tokens.dart`) — e.g., `Tokens.bgGlass`, `Tokens.accent`, `Tokens.glassBlur`
- Private static constants: `_urlSchemes`, `_maxCacheSize`, `_probesEnabled`

## Code Style

**Formatting:**
- `dart format` (80-char line, default Flutter rules)
- Trailing commas on multi-line argument/parameter lists (improves diff readability)
- `prefer_single_quotes: true` enforced in `analysis_options.yaml`

**Linting:**
- Base: `package:flutter_lints/flutter.yaml`
- Strict mode enabled: `strict-casts`, `strict-inference`, `strict-raw-types` (`analysis_options.yaml`)
- Key enabled rules: `prefer_const_constructors`, `prefer_final_locals`, `prefer_final_in_for_each`, `avoid_print`, `prefer_single_quotes`, `always_declare_return_types`, `avoid_void_async`, `cancel_subscriptions`, `close_sinks`, `unawaited_futures`
- DCM (Dart Code Metrics) configured with 18 rules and metrics thresholds: cyclomatic-complexity 15, maximum-nesting-level 6, number-of-parameters 8, number-of-methods 20, widgets-nesting-level 8

**Kernel logging ban:**
- `lib/kernel/` must NOT use `debugPrint()` — enforced via CI grep gate (Flutter analyzer lacks directory-level lint overrides)
- Kernel code must use `KernelLogger` instead (see Logging section)

## Import Organization

**Order:**
1. `dart:` SDK imports
2. External `package:` imports (flutter, media_kit, etc.)
3. Internal `package:simple_player_flutter/` imports
4. Relative imports within the same feature (`'./file.dart'`)

**Path Aliases:**
- None — all imports use full `package:simple_player_flutter/...` paths or relative paths
- Relative imports used within tightly-coupled files: `engine_state_machine.dart` imports `'media_state.dart'`, `'../diagnostics/kernel_logger.dart'`
- Deferred imports for lazy loading: `import 'player_feature.dart' deferred as player_feature;` (`lib/features/player/deferred_player_feature.dart`)

**Show/hide directives:**
- Used to narrow scope: `import '../diagnostics/kernel_logger.dart' show KernelLoggerImpl;` (`lib/kernel/engine/engine_state_machine.dart`)

## Error Handling

**Patterns:**
- Sealed class hierarchies for structured, exhaustive error handling — `PlayerError` (`lib/kernel/models/player_error.dart`) with subtypes `FileError`, `CodecError`, `PlaybackError`, `NetworkError`, `UnknownError`, each carrying a typed code enum
- Sealed `OpenResult` (`lib/kernel/engine/open_result.dart`): `OpenSuccess`, `OpenError`, `OpenSuperseded` — enables exhaustive `switch` pattern matching
- Error codes are append-only registries: `FileErrorCode`, `CodecErrorCode`, etc. — existing codes never renamed/deleted (`lib/kernel/models/player_error.dart`)
- Each error carries: `message` (human-readable), `cause` (original exception, optional), `context` (`ErrorContext?` with action/generation/path/timestamp/module), `isFatal`, `l10nKey` (for UI translation lookup)
- `on Object catch (error, stackTrace)` at composition root (`lib/main.dart:35`) — catches everything at app entry, logs via `KernelLogger.I.e(...)`, records error string for UI display
- Specify exception types in `on` clauses — never bare `catch (e)` (per CLAUDE.md rule)
- Never catch `Error` subtypes — they indicate programming bugs

**Input validation:**
- Centralized at system boundaries via `PathValidator` (`lib/kernel/services/path_validator.dart`): extension whitelist, path-traversal detection, URL scheme filtering
- All file-open entry points (FilePicker, drag-and-drop, history replay) must pass through `PathValidator.validate()` before reaching the engine
- Null byte injection, UNC paths, home expansion, control characters all rejected (fuzz-tested in `test/kernel/security/fuzz_input_test.dart`)

## Logging

**Framework:** `KernelLogger` (custom, zero third-party dependencies)

**Architecture:**
- Abstract `KernelLogger` base + concrete `KernelLoggerImpl` (`lib/kernel/diagnostics/kernel_logger.dart`)
- 6 severity levels: `trace`, `debug`, `info`, `warn`, `error`, `fatal` — 1:1 method mapping
- Shortcut methods: `.t()`, `.d()`, `.i()`, `.w()`, `.e()`, `.f()`
- Static singleton accessor: `KernelLogger.I` (throws `StateError` if `init()` not called)
- Build-mode-gated sinks via `createDefaultLogSink()`:
  - debug → `CompositeSink([DebugPrintSink(), DevToolsSink()])`
  - profile → `DevToolsSink()` (low-noise performance diagnostics)
  - release → `NullSink()` (tree-shakeable, zero output)

**Patterns:**
- Kernel modules obtain logger via `final _log = KernelLogger.I;` at file scope (`lib/kernel/services/playback_controller.dart:29`, `lib/kernel/utils/path_utils.dart:7`)
- Call as `_log.info('message')`, `_log.error('message', error: e, stackTrace: st, context: {...})`
- Structured context via `Map<String, Object?>` — serialized to stable-key JSON, cycle-safe (`serializeLogContext`)
- Path redaction: `redactPath()` strips directory prefixes before logging (`lib/kernel/diagnostics/kernel_logger.dart:126`)
- UI layer (outside `lib/kernel/`) may use `debugPrint()` — but kernel MUST use `KernelLogger`
- Test setup: `KernelLoggerImpl.resetForTesting()` then `KernelLoggerImpl.init()` in `setUpAll`

## Comments

**When to Comment:**
- Every public class, mixin, and non-trivial function has a `///` doc comment (mandated by CLAUDE.md)
- Doc comments are bilingual: Chinese first line, then English explanation — e.g., `/// 路径安全校验工具 — 统一入口` / `/// Centralised file-path validation: ...`
- Inline comments for non-obvious logic — explain *why*, not *what*
- Magic values documented: `Tokens.bgGlass = Color(0x8C0C0F18); // 加深`
- Side effects documented: I/O operations, state mutations, external calls
- TODOs include brief explanation: `// TODO: 全屏回归场景 ... 待用 media_kit 集成测试重写`

**JSDoc/TSDoc:**
- Dart `///` doc comments on all public APIs
- Examples included in doc comments for pattern usage: `sealed class OpenResult` shows exhaustive `switch` example (`lib/kernel/engine/open_result.dart:5-19`)
- Architecture position documented: `/// 架构位置：PlayerViewModel → PlaybackController → MediaEngine` (`lib/kernel/services/playback_controller.dart:7`)

## Function Design

**Size:**
- Functions < 50 lines (20 for pure logic, 50 for UI builders) per CLAUDE.md
- Files < 500 lines — extract modules when approaching limit

**Parameters:**
- `required` for constructor params that must always be provided
- Optional named params with nullable types or defaults
- Callbacks typed as `VoidCallback?` or `void Function(T)?`

**Return Values:**
- Sealed `Result`-style types for fallible operations: `OpenResult` (`lib/kernel/engine/open_result.dart`)
- `ValueNotifier<T>` for reactive state exposure (see State Management)
- Immutable data classes with `copyWith()` for state mutations: `PlaylistItem.copyWith()` (`lib/kernel/models/playlist_item.dart:62`)

## Module Design

**Exports:**
- No barrel files — direct imports to specific files
- `show` directives to narrow scope where needed: `show KernelLoggerImpl`
- `library;` directive used at file top for explicit library declaration (e.g., `kernel_logger.dart`, `playback_controller.dart`)

**ISP Decomposition:**
- Engine interface split into 7 ISP facets: `EngineStateView` (read-only state), `PlaybackControl`, `TrackControl`, `SubtitleConfig`, `VideoEffectControl`, `RendererControl`, `VolumeControl` (`lib/kernel/engine/`)
- Composite `MediaEngine` aggregates all facets for service-layer consumption (`lib/kernel/engine/media_engine.dart`)
- UI layer depends on `EngineStateView` (read-only); service layer depends on `MediaEngine` (state + control)

**State Management:**
- `ValueNotifier` + `ValueListenableBuilder` exclusively — no Provider/Riverpod/Bloc
- `MediaEngine` exposes `ValueNotifier`s for all reactive state (position, volume, state, etc.)
- `EngineStateMachine` owns 3 ValueNotifiers + generation counter (`lib/kernel/engine/engine_state_machine.dart`)
- Widgets rebuild via `ValueListenableBuilder` wrappers
- Generation guard pattern: `nextGeneration()` / `isCurrent(gen)` prevents stale async callbacks from polluting state

**Immutability:**
- `final` for all local variables (lint-enforced)
- `const` constructors wherever all fields are `final`
- `copyWith()` for state mutations in immutable classes
- Avoid `!` bang operator — prefer `?.`, `??`, `if (x != null)`, or Dart 3 pattern matching
- Avoid `late` — prefer nullable types or constructor initialization (exception: `late final` where init is guaranteed in constructor body, documented with comment)
- Avoid `as` casts — use `switch`/`if (x is Type)` pattern matching

**Design System Enforcement:**
- All visual values via `Tokens.*` (`lib/ui/theme/tokens.dart`) — no hardcoded colors, fonts, or spacing
- Glass-morphism pattern: `BackdropFilter` + `Tokens.bgGlass` + `Tokens.glassBlur` via `GlassContainer` widget (`lib/ui/shared/glass_container.dart`)
- Single theme: Midnight (compile-time const), `ThemeMode.dark` always (`lib/app.dart:60`)
- `GlassTier` enum for blur levels (thin/normal/thick) with cached `ImageFilter` instances

---

*Convention analysis: 2026-08-21*
