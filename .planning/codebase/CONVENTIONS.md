<!-- refreshed: 2026-06-26 -->

# Code Conventions

## Naming

- **Files**: `snake_case.dart` — `control_bar.dart`, `playlist_item.dart`
- **Classes**: `PascalCase` — `PlaybackController`, `GlassContainer`, `FakeEngine`
- **Variables/functions**: `camelCase` — `textureId`, `playIndex`, `isBuffering`
- **Booleans**: `is`/`has`/`should` prefix — `isResizing`, `blurEnabled`, `isAlwaysOnTop`
- **Constants**: `static const` in `Tokens` class — `Tokens.bgDeep`, `Tokens.glassBlur`
- **Enums**: `PascalCase` names, `camelCase` values — `enum PlayMode { loopAll, loopSingle, shuffle }`
- **Test fakes**: `Fake<Interface>` — `FakeEngine`, `FakeWindowService`
- **Test files**: mirror lib path — `lib/kernel/playlist/playlist.dart` -> `test/kernel/playlist/playlist_test.dart`

## Import Organization

1. `dart:` stdlib imports first
2. `package:` external dependencies
3. Relative project imports (using `../` paths)
4. No blank-line grouping convention observed

```
import 'package:flutter/material.dart';
import 'package:player_engine/player_engine.dart';
import '../../kernel/models/playlist_item.dart';
import '../theme/tokens.dart';
```

## Comments

- Chinese comments are acceptable: `/// 毛玻璃模糊层级`, `// 最深背景 - 加深`
- `///` doc comments for classes and public APIs
- `//` inline comments for implementation notes
- Section separators: `// ── Section Name ──` with em-dash markers
- Reference design decisions by ID: `(D-13)`, `(D-15)`
- Module-scoped `[Tag]` in log messages: `log.e('[PlayerFeature] init failed')`

## Logging

- Use `log.*` from `kernel/utils/log.dart` (backed by `package:logger`)
- Levels: `log.d()` debug, `log.w()` warning, `log.e()` error
- Module loggers: `logEngine`, `logBridge` for domain-specific output
- `debugPrint()` is forbidden by `analysis_options.yaml` (`avoid_print: true`)
- Release logging goes to `%APPDATA%\SimplePlayer\logs\` with 2MB rotation

## Error Handling

- `try {} on Exception catch (e) {}` — catch typed `Exception`, not bare `catch (e)`
- Log errors with context: `log.e('[Service] action failed: $e')`
- Graceful fallback — never silent `catch (_) {}` (some legacy exceptions exist in linux_platform_fullscreen)
- `catchError` for Futures: `.catchError((Object e) => log.e('...'))`
- Stack traces captured with `catch (e, st)` at bridge/engine layer

## Design Tokens

- All visual constants via `Tokens.*` (519 usages across codebase)
- Colors: `Tokens.bgDeep`, `Tokens.accent`, `Tokens.textPrimary`
- Typography: `Tokens.fontBody`, `Tokens.weightMedium`
- Spacing: `Tokens.spaceSm`, `Tokens.radiusMd`
- Blur: `Tokens.glassBlur`, `Tokens.glassBlurThin`, `Tokens.glassBlurThick`
- No hardcoded colors, fonts, or spacing in widget code

## Glass-Morphism Pattern

- Wrap in `GlassContainer` widget (59 usages)
- 3-tier blur: `GlassTier.thin` (title bar), `.normal` (control bar), `.thick` (dialogs)
- Key properties: `bgGlass` background, `borderHighlight` border, `BackdropFilter` blur
- Performance: skip blur when `opacity < 0.01`, `blurEnabled: false`, or `resizing: true`
- Example: `GlassContainer(tier: GlassTier.normal, child: ...)`

## Widget Composition

- **State management**: `ValueNotifier` + `ValueListenableBuilder` (121 usages), no Provider/Riverpod
- **Composition over inheritance**: widgets take callbacks (`VoidCallback`, `ValueChanged<T>`)
- **Nullable callbacks for optional features**: `VoidCallback? onOpenFile`, `VoidCallback? onToggleFullscreen`
- **Responsive layout**: width thresholds (e.g., 500dp) to show/hide secondary controls
- **Reusable shared widgets**: `GlassContainer`, `EmptyState`, `EdgeGlow`, `GlassButton`, `GlassChip`
- **Feature modules**: `features/player/` holds service orchestration, `kernel/` holds pure logic

## Strict Mode

`analysis_options.yaml` enforces:
- `strict-casts: true`, `strict-inference: true`, `strict-raw-types: true`
- `prefer_const_constructors`, `prefer_final_locals`
- `avoid_print`, `avoid_void_async`, `unawaited_futures`
- `missing_required_param: error`, `missing_return: error`

## Async Patterns

- Always `await` Futures or explicitly call `unawaited()`
- Never mark function `async` if it never `await`s
- Check `context.mounted` before using `BuildContext` after `await`
- Prefer `Future.wait` for concurrent operations

## Immutability

- Use `final` fields on data classes
- Provide `copyWith()` method for immutable updates
- Override `==` and `hashCode` for value equality (e.g., `PlaylistItem`)
- Use `List.unmodifiable()` for read-only collections
