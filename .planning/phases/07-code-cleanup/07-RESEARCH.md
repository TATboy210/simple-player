# Phase 7: Code Cleanup - Research

**Researched:** 2026-05-14
**Domain:** Dead code removal, keyboard handler fix, localization, static analysis cleanup
**Confidence:** HIGH

## Summary

Phase 4 (code cleanup) has 5 requirements: remove dead WindowManagerService, fix swallowed 'A' key, localize AspectRatioService labels, pass `dart analyze`, and verify overlay cleanup. The CONTEXT.md has locked decisions for each requirement.

**Key finding:** `dart analyze` currently shows 8 info warnings, not 4 as estimated. Two are deprecated API uses (`onReorder` and `activeColor`) and one is `use_build_context_synchronously` — these are more serious than the `unnecessary_getters_setters` and `unnecessary_underscores` originally noted.

**Primary recommendation:** Execute in 3 tasks: (1) delete dead code + create PlatformService proxy, (2) wire 'A' key + localize AspectRatio labels, (3) fix all 8 `dart analyze` warnings.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Dead code removal | Kernel layer | — | WindowManagerService + WindowsPlatformService are kernel-layer files |
| PlatformService proxy | Kernel/services | — | Abstract interface lives in kernel/services |
| Keyboard handler | UI/player | — | KeyboardHandler is a UI widget |
| AspectRatio localization | Window layer | L10n | Service is in window/, labels need l10n keys |
| Static analysis fixes | Various | — | Scattered across multiple files |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter | stable | UI framework | Project base |
| fvp | latest | Media playback | MDK/FFmpeg wrapper |
| window_manager | latest | Window management | Frameless window support |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter_localizations | — | L10n infrastructure | Already configured |

## Architecture Patterns

### Pattern 1: Singleton Proxy for PlatformService

**What:** Replace `PlatformService` factory singleton with a `_Proxy` class that delegates to `WindowBridge.I`

**When to use:** When deleting `WindowsPlatformService` but keeping the abstract `PlatformService` interface (because `CustomTitleBar` depends on it)

**Example:**
```dart
// In platform_service.dart — replace factory singleton with proxy
abstract class PlatformService {
  static PlatformService get I => _instance ?? _Proxy();
  static PlatformService? _instance;

  // ... abstract methods unchanged ...
}

/// Transparent proxy — delegates to WindowBridge.I
/// CustomTitleBar uses PlatformService.I — this proxy ensures it works
/// without requiring any changes to CustomTitleBar.
class _Proxy implements PlatformService {
  WindowBridge get _bridge => WindowBridge.I;

  @override
  Future<void> minimize() => _bridge.minimize();
  @override
  Future<void> toggleMaximize() => _bridge.toggleMaximize();
  @override
  Future<void> close() => _bridge.close();
  @override
  Future<void> startDragging() => _bridge.startDragging();
  @override
  Future<void> toggleFullscreen() => _bridge.toggleFullscreen();
  @override
  Future<void> exitFullscreen() => _bridge.exitFullscreen();
  @override
  Future<void> toggleAlwaysOnTop() => _bridge.toggleAlwaysOnTop();
  @override
  ValueNotifier<WindowMode> get mode => _bridge.mode;
  @override
  ValueNotifier<bool> get isAlwaysOnTop => _bridge.isAlwaysOnTop;
  @override
  ValueNotifier<bool> get isMaximized => _bridge.isMaximized;
  @override
  ValueNotifier<bool> get isResizing => _bridge.isResizing;
  @override
  Future<void> initService() async {} // no-op — WindowBridge handles init
  @override
  Future<void> dispose() async {} // no-op — WindowBridge handles dispose
}
```

**Why this works:** `WindowBridge.I` returns `NoopWindowBridge` if not yet injected, so `PlatformService.I` never throws `StateError`. After `WindowBootstrap.init()`, it returns the real `WindowService`.

### Pattern 2: Callback Prop for Keyboard Handler

**What:** Add `onCycleAspectRatio` callback to KeyboardHandler, wire in PlayerScreen

**When to use:** KeyboardHandler already has 18 callback props — adding one more follows established pattern

**Example:**
```dart
// In keyboard_handler.dart — add prop
final VoidCallback? onCycleAspectRatio;

// In _handleKeyEvent — replace swallowed key
if (key == LogicalKeyboardKey.keyA) {
  onCycleAspectRatio?.call();
  return KeyEventResult.handled;
}

// In player_screen.dart — wire callback
onCycleAspectRatio: () => AspectRatioService.I.cycleRatio(),
```

### Pattern 3: AspectRatio Label via Enum

**What:** Use `AspectRatioMode` enum with localized labels instead of hardcoded strings

**When to use:** The kernel's `AspectRatioMode` already has a `.label` getter. The window `AspectRatioService` can expose a `currentMode` getter that returns the enum, letting UI code map to l10n.

**Example:**
```dart
// In aspect_ratio_service.dart — add mode getter
AspectRatioMode? get currentMode {
  if (_current == 0.0) return null; // free/unlocked
  for (final mode in AspectRatioMode.values) {
    if ((_current - mode.mdkValue).abs() < 0.01) return mode;
  }
  return null; // custom ratio
}

// In custom_title_bar.dart — use l10n for label
final mode = AspectRatioService.I.currentMode;
final label = mode != null ? _l10nAspectRatio(l10n, mode) : l10n.aspectRatioFree;
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| AspectRatio labels | Custom string mapping | `AspectRatioMode` enum + l10n keys | Already exists in kernel layer |
| PlatformService delegation | Manual forwarding of each method | Proxy class implementing interface | Compiler enforces all methods |

## Common Pitfalls

### Pitfall 1: Deleting PlatformService Without Updating CustomTitleBar
**What goes wrong:** CustomTitleBar calls `PlatformService.I` at line 22 and 114. Deleting the class causes compile errors.
**Why it happens:** Assumed "dead code" without checking import graph.
**How to avoid:** Create proxy FIRST, then delete WindowsPlatformService.
**Warning signs:** `dart analyze` shows undefined identifier errors.

### Pitfall 2: AspectRatioMode Label Not Localized
**What goes wrong:** `AspectRatioMode.label` returns Chinese strings ('原始', '拉伸', etc.) — same hardcoded problem.
**Why it happens:** Assumed enum labels were already localized.
**How to avoid:** Don't use `AspectRatioMode.label` directly in UI. Create l10n keys for each mode and map in the UI layer.
**Warning signs:** Chinese text appears in English locale.

### Pitfall 3: Breaking window_manager Singleton
**What goes wrong:** Deleting WindowManagerService breaks `window_manager` plugin's internal state if it depends on the singleton.
**Why it happens:** `window_manager` package has its own `WindowManager.instance` singleton — our `WindowManagerService` was a wrapper, not the singleton.
**How to avoid:** Verify `WindowService` (the replacement) uses `windowManager` from the package, not from the deleted class.
**Warning signs:** Window doesn't show or resize after deletion.

### Pitfall 4: Ignoring Deprecated API Warnings
**What goes wrong:** `onReorder` (playlist_panel.dart:88) and `activeColor` (video_processing_tab.dart:195) are deprecated. Future Flutter versions may remove them.
**Why it happens:** CONTEXT.md only mentioned 4 info warnings, but `flutter analyze` shows 8.
**How to avoid:** Fix all 8 warnings, not just the 4 originally noted.
**Warning signs:** Build fails after Flutter SDK upgrade.

## Code Examples

### PlatformService Proxy Implementation
```dart
// Source: kernel/services/platform_service.dart
// Replace the factory singleton pattern with proxy pattern

abstract class PlatformService {
  static PlatformService get I => _instance ?? _Proxy();
  static PlatformService? _instance;

  static bool get isInitialized => _instance != null;

  /// Initialize with explicit implementation (for testing or custom platforms)
  static void init(PlatformService impl) => _instance = impl;

  @visibleForTesting
  static void reset() => _instance = null;

  // ... abstract methods ...
}

class _Proxy implements PlatformService {
  WindowBridge get _bridge => WindowBridge.I;
  // ... all methods delegate to _bridge ...
}
```

### KeyboardHandler 'A' Key Fix
```dart
// Source: lib/ui/player/keyboard_handler.dart line 159
// BEFORE: swallowed key
if (key == LogicalKeyboardKey.keyA) {
  return KeyEventResult.handled;
}

// AFTER: wired to callback
if (key == LogicalKeyboardKey.keyA) {
  onCycleAspectRatio?.call();
  return KeyEventResult.handled;
}
```

### AspectRatio L10n Keys
```dart
// Source: lib/l10n/app_en.arb
"aspectRatioFree": "Free",
"@aspectRatioFree": { "description": "Aspect ratio mode: no constraint" },

// Source: lib/l10n/app_zh.arb
"aspectRatioFree": "自由",
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| WindowManagerService singleton | WindowService via WindowBridge | Phase 1 | Old service is dead code |
| Manual OverlayEntry | OverlayPortal | Phase 01 | CODE-05 already satisfied |
| WindowsPlatformService delegation | Proxy pattern (planned) | Phase 07 | Transparent to CustomTitleBar |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `WindowBridge.I` is always available when `PlatformService.I` is accessed | PlatformService Proxy | Low — WindowBootstrap.init() runs before runApp() |
| A2 | `AspectRatioMode.label` returns Chinese strings | AspectRatio Label | Low — verified in source code |
| A3 | No other code imports `WindowsPlatformService` | Dead Code Removal | Low — CONTEXT.md states nothing imports it |

## Open Questions

1. **AspectRatio l10n approach**
   - What we know: Two valid approaches exist (service accepts l10n param vs UI maps enum to l10n)
   - What's unclear: Which approach the planner prefers
   - Recommendation: Use enum approach — keeps service layer free of Flutter dependencies, consistent with kernel architecture

2. **dart analyze severity**
   - What we know: 8 info warnings exist, including deprecated API uses
   - What's unclear: Whether to fix deprecated APIs (may require larger refactors)
   - Recommendation: Fix all 8 — `onReorder` → `onReorderItem` is a simple API change, `activeColor` → `activeThumbColor` is a rename

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | Build/analyze | ✓ | stable | — |
| dart format | Code formatting | ✓ | — | — |
| flutter analyze | Static analysis | ✓ | — | — |
| flutter test | Test verification | ✓ | — | — |

**Missing dependencies with no fallback:** None

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in) |
| Config file | pubspec.yaml |
| Quick run command | `flutter test` |
| Full suite command | `flutter test --coverage` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CODE-01 | WindowManagerService deleted, no compile errors | smoke | `flutter analyze` | ✅ |
| CODE-02 | 'A' key triggers aspect ratio cycle | unit | `flutter test test/` | ✅ |
| CODE-03 | AspectRatio labels use l10n | visual | Manual verification | — |
| CODE-04 | dart analyze passes clean | smoke | `flutter analyze` | ✅ |
| CODE-05 | Overlay entries cleaned up | smoke | `flutter analyze` | ✅ |

### Sampling Rate
- **Per task commit:** `flutter analyze`
- **Per wave merge:** `flutter test && flutter analyze`
- **Phase gate:** `flutter analyze` clean + `flutter test` green

### Wave 0 Gaps
- None — existing test infrastructure covers phase requirements

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | no | — |
| V6 Cryptography | no | — |

This phase is code cleanup with no security-sensitive changes.

## Sources

### Primary (HIGH confidence)
- `lib/kernel/window/window_manager_service.dart` — 514 lines, verified dead code
- `lib/kernel/platform/windows_platform_service.dart` — 53 lines, verified dead code
- `lib/kernel/services/platform_service.dart` — abstract interface, verified dependency from CustomTitleBar
- `lib/kernel/bridge/window_bridge.dart` — verified NoopWindowBridge fallback exists
- `lib/ui/player/keyboard_handler.dart` — verified 'A' key swallowed at line 159
- `lib/window/aspect_ratio_service.dart` — verified hardcoded '自由' at line 63
- `flutter analyze` output — verified 8 info warnings

### Secondary (MEDIUM confidence)
- CONTEXT.md decisions — locked by user, high confidence

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — project already uses these libraries
- Architecture: HIGH — proxy pattern well-understood, verified in source
- Pitfalls: HIGH — all pitfalls verified by reading source code

**Research date:** 2026-05-14
**Valid until:** 2026-06-14 (stable — code cleanup patterns don't change rapidly)
