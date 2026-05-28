# Coding Conventions

**Analysis Date:** 2026-05-28

## Naming Patterns

| Element | Convention | Example |
|---------|-----------|---------|
| Files | `snake_case.dart` | `media_engine.dart` |
| Classes | `PascalCase` | `FvpEngine`, `GlassContainer` |
| Enums | `PascalCase` type, `camelCase` values | `MediaState.playing` |
| Functions | `camelCase` | `playIndex`, `openAndPlay` |
| Private | `_camelCase` | `_guardedAction`, `_disposed` |
| Booleans | `is`/`has` prefix | `isEmpty`, `hasVideo` |
| Constants | `camelCase` (class members) | `_prepareTimeoutSeconds` |
| Top-level | `camelCase` in Tokens | `bgBase`, `accent` |

## Import Organization

1. `dart:` imports
2. `package:flutter/` imports
3. External `package:` imports
4. Relative imports (same-layer)

**Style:** Relative imports throughout, no path aliases (`@/`, `~/`)

## Error Handling

### `_guardedAction` Pattern (FvpEngine)
```dart
void _guardedAction(String name, void Function() action) {
  if (_disposed) return;
  try {
    action();
  } on Exception catch (e) {
    debugPrint('FvpEngine.$name error: $e');
    _errorType = MediaErrorType.playback;
    errorMessage.value = '$name 失败: $e';
  }
}
```

### Rules
- Always `on Exception`, never bare `catch (e)`
- Use `debugPrint()` for logging, never `print()`
- Chinese error messages acceptable
- Graceful fallback: catch + set error state + continue
- `_disposed` guard at top of every public method

### Structured Errors
- `PlayerError` — error code + message + cause
- `ValidationError` — validation type + message
- `MediaErrorType` — file/codec/playback/network/unknown

## Logging

**Framework:** `logger` package (v2.5.0)
**Global instance:** `lib/kernel/utils/log.dart`

- `debugPrint()` for simple inline logging (most common)
- `log` instance for structured logging (kernel layer)
- Prefix with `[ClassName]` for context

## Design Tokens

All visual values via `Tokens.*` (`lib/ui/theme/tokens.dart`):

| Category | Examples |
|----------|---------|
| Colors | `bgBase`, `bgPanel`, `accent`, `textPrimary` |
| Typography | `fontBody`, `fontCaption`, `weightMedium` |
| Spacing | `spSm` (8), `spMd` (12), `spLg` (16) |
| Radius | `radiusSm` (6), `radiusMd` (10), `radiusLarge` (12) |
| Animation | `durationFast` (80ms), `durationNormal` (150ms) |
| Glass | `glassBlur` (10), `glassBlurThick` (24) |
| Icons | `iconSm` (16), `iconMd` (18), `iconLg` (20) |

## Widget Patterns

### ValueNotifier + ValueListenableBuilder
```dart
ValueListenableBuilder<MediaState>(
  valueListenable: widget.engine.state,
  builder: (context, state, child) =>
      state == MediaState.idle ? child! : const SizedBox.shrink(),
  child: Positioned.fill(child: widget.emptyState!),  // cached
)
```

### Glass Components
- `GlassContainer` — ClipRRect + BackdropFilter + RepaintBoundary
- `GlassButton` — hover/press scale animation
- `GlassIconButton` — 36x36 Material + InkWell, no splash

### Widget Caching
```dart
ControlBar? _cachedBar;
MediaEngine? _cachedEngine;
bool? _cachedIsFullscreen;
```

## Service Architecture

### Composition
```dart
class PlaybackController {
  final PlaybackNavigator navigator;
  final FileOperations fileOps;
  final StateMonitor monitor;
  // Forward methods: playIndex(i) => navigator.playIndex(i)
}
```

### Singleton
```dart
class LocaleService {
  static final LocaleService I = LocaleService._();
  LocaleService._();
}
```

## Commit Format

Conventional Commits: `<type>: <description>`

Types: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `perf:`, `chore:`, `wip:`, `checkpoint:`

## Comments

- Chinese comments acceptable and common
- `///` for public APIs, `//` for implementation notes
- Section dividers: `// ─── Section Name ───`
