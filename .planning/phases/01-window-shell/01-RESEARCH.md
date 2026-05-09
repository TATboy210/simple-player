# Phase 1: Window Shell - Research

**Researched:** 2026-05-09
**Domain:** Flutter desktop frameless window, custom title bar, window state management
**Confidence:** HIGH

## Summary

Phase 1 delivers the visual container: a stable, flicker-free frameless window with custom title bar, aspect ratio lock, fullscreen toggle, and state persistence. The reference project at `D:\player_flutter` provides a proven, working implementation of all 15 requirements (WIN-01 through WIN-15). The current project has the kernel layer complete but the UI layer is empty ("Ready" placeholder).

The C++ runner already has both the `forceRedraw` and `aspect_ratio` MethodChannels wired up. `SettingsStore` already has all persistence methods for window geometry. The `window_manager` 0.5.1 and `dynamic_color` packages are already in pubspec.yaml. The primary work is Dart-side: creating `WindowManagerService`, `AspectRatioService`, `CustomTitleBar`, extending `PlatformService`, and wiring everything in `app.dart`.

**Primary recommendation:** Port patterns directly from `D:\player_flutter` reference project. The architecture is proven. Do not reinvent — adapt.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Frameless window setup | API/Backend (Dart) | Native C++ (runner) | window_manager controls Win32 window style |
| Custom title bar UI | Browser/Client (Flutter) | — | Pure widget tree, no server involvement |
| Aspect ratio enforcement | Native C++ (runner) | API/Backend (Dart) | WM_SIZING is native Win32 message |
| Fullscreen toggle | API/Backend (Dart) | — | Manual setSize/setPosition, no native code needed |
| Window state persistence | API/Backend (Dart) | — | SharedPreferences, debounced writes |
| Bounds check on restore | API/Backend (Dart) | — | PlatformDispatcher screen size query |
| Always-on-top | API/Backend (Dart) | — | window_manager.setAlwaysOnTop |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| window_manager | 0.5.1 (pinned) | Frameless window, window controls, event listener | Flutter's de facto desktop window management. Pinned exact to avoid breaking changes. |
| dynamic_color | ^1.8.1 | System accent color for close button hover | D-01 decision: follow system theme, not hardcoded red |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| shared_preferences | ^2.5.5 | Window geometry persistence | Already used by SettingsStore |
| flutter/services | SDK | MethodChannel for native WM_SIZING | Aspect ratio enforcement |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| window_manager | bitsdojo_window | bitsdojo has different API surface, no WindowListener, would require rework |
| Manual fullscreen (setSize+setPosition) | setFullScreen() | setFullScreen is broken on frameless windows — documented in reference |
| Native WM_SIZING aspect ratio | Flutter AspectRatio widget | Flutter-level constraint causes resize jitter; native WM_SIZING is smooth |

**Installation:** Already installed. No additional `flutter pub get` needed.

## Architecture Patterns

### System Architecture Diagram

```
User Input (drag/resize/F11/pin)
         |
         v
  CustomTitleBar (Widget)
    |       |
    |   GestureDetector → startDragging / toggleMaximize
    |   _TitleBarButton  → minimize / close / toggleAlwaysOnTop
    |
    v
  PlatformService (abstract interface)
    |   ValueNotifier<WindowMode> mode
    |   ValueNotifier<bool> isMaximized
    |   ValueNotifier<bool> isAlwaysOnTop
    |   ValueNotifier<bool> isResizing
    |
    v
  WindowManagerService (singleton, implements PlatformService)
    |   window_manager package → Win32 API
    |   500ms debounce → SettingsStore → SharedPreferences
    |   fullscreen reentry guard
    |   bounds check on restore
    |
    v
  AspectRatioService (singleton)
    |   MethodChannel 'com.simple_player/aspect_ratio'
    |
    v
  FlutterWindow (C++ runner)
    |   WM_SIZING handler → enforces aspect ratio
    |   forceRedraw channel → first frame fix
```

### Recommended Project Structure

```
lib/kernel/
├── window/
│   ├── window_manager_service.dart   # Singleton, 516 lines (ported from reference)
│   └── aspect_ratio_service.dart     # Singleton, MethodChannel wrapper
├── platform/
│   ├── windows_platform_service.dart # Delegates to WindowManagerService
│   └── linux_platform_service.dart   # Existing
├── services/
│   └── platform_service.dart         # Extended with window control methods
├── ui/
│   └── window/
│       └── custom_title_bar.dart     # 36px title bar, buttons
└── ...
```

### Pattern 1: WindowManagerService Singleton

**What:** Singleton service wrapping `window_manager` package with production hardening
**When to use:** All window operations go through this service, never directly to `window_manager`
**Example (from reference):**

```dart
// Source: D:\player_flutter\lib\kernel\window\window_manager_service.dart
class WindowManagerService implements WindowListener {
  WindowManagerService._();
  static final WindowManagerService I = WindowManagerService._();

  final mode = ValueNotifier<WindowMode>(WindowMode.windowed);
  final isAlwaysOnTop = ValueNotifier<bool>(false);
  final isMaximized = ValueNotifier<bool>(false);
  final isResizing = ValueNotifier<bool>(false);

  static const minSize = Size(640, 360);
  static const _persistDebounceMs = 500;
  static const _resizeDebounceMs = 500;

  // Guards
  bool _togglingFullscreen = false;  // RC-5: reentry guard
  bool _closing = false;              // RC-1: double-close guard
  Completer<void>? _initCompleter;    // RC-9: init lifecycle
  Completer<void>? _closeCompleter;   // RC-1: close lifecycle
  Completer<void>? _persistInFlight;  // RC-7: concurrent persist guard
  Timer? _persistDebounce;
  Timer? _resizeEndDebounce;
  Size _windowedSize = Size.zero;
  Offset _windowedPosition = Offset.zero;
}
```

**Key hardening patterns:**
- `_togglingFullscreen` guard prevents rapid F11 ABA state corruption (WIN-09)
- `_closing` guard prevents double-close from onWindowClose
- `_initCompleter` / `_closeCompleter` ensure dispose() waits for async operations
- `_persistInFlight` prevents concurrent SharedPreferences writes
- `_persistDebounce` merges continuous resize/move into single write (WIN-11)
- `_resizeEndDebounce` delays isResizing=false by 500ms after last resize event (WIN-03)

### Pattern 2: Frameless First Frame Fix

**What:** Sequence to prevent white flash on frameless window startup
**When to use:** Always — called once during init
**Example (from reference):**

```dart
// Source: D:\player_flutter\lib\kernel\window\window_manager_service.dart
Future<void> _prepareFramelessFirstFrame() async {
  await windowManager.setAsFrameless();
  await windowManager.setHasShadow(true);

  if (!Platform.isWindows) return;

  // Force WM_SIZE to trigger Flutter relayout
  try {
    final size = await windowManager.getSize();
    if (size.width > 0 && size.height > 0) {
      await windowManager.setSize(size);
    }
  } on Exception catch (e) {
    debugPrint('[WindowManager] force layout after frameless failed: $e');
  }

  // Force redraw at correct frameless client area size
  try {
    await _redrawChannel.invokeMethod('forceRedraw');
  } on MissingPluginException {
    // Channel not registered (hot reload race), safe to skip
  } catch (e) {
    debugPrint('[WindowManager] forceRedraw error: $e');
  }
}
```

### Pattern 3: Fullscreen Toggle (Manual, Not setFullScreen)

**What:** Manual fullscreen via setSize + setPosition because setFullScreen is broken on frameless
**When to use:** Always for frameless windows
**Example (from reference):**

```dart
// Source: D:\player_flutter\lib\kernel\window\window_manager_service.dart
Future<void> toggleFullscreen() async {
  if (_togglingFullscreen || _disposed) return;
  _togglingFullscreen = true;
  try {
    if (mode.value == WindowMode.fullscreen) {
      await _exitFullscreenInternal();
    } else {
      _windowedSize = await windowManager.getSize();
      _windowedPosition = await windowManager.getPosition();
      mode.value = WindowMode.fullscreen; // optimistic update
      try {
        await windowManager.setHasShadow(false);
        final screen = ui.PlatformDispatcher.instance.views.first;
        final screenW = screen.physicalSize.width / screen.devicePixelRatio;
        final screenH = screen.physicalSize.height / screen.devicePixelRatio;
        await windowManager.setPosition(Offset.zero);
        await windowManager.setSize(Size(screenW, screenH));
        await SettingsStore.saveIsFullscreen(true);
      } on Exception catch (e) {
        mode.value = WindowMode.windowed; // rollback
        debugPrint('[WindowManager] enterFullscreen failed: $e');
      }
    }
  } finally {
    _togglingFullscreen = false;
  }
}
```

### Pattern 4: Custom Title Bar with StatefulWidget Buttons

**What:** 36px title bar with local-state hover buttons to prevent resize rebuilds
**When to use:** Always — StatelessWidget title bar, StatefulWidget buttons
**Example (from reference):**

```dart
// Source: D:\player_flutter\lib\kernel\ui\window\custom_title_bar.dart
class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _hovered = false; // Local state — no global ValueNotifier

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: 46,  // D-04 says 36x36 but reference uses 46x36
            height: 36,
            color: _hovered ? hoverColor : Colors.transparent,
            child: Icon(widget.icon, size: 16, color: iconColor),
          ),
        ),
      ),
    );
  }
}
```

### Anti-Patterns to Avoid

- **setFullScreen() on frameless:** Broken — causes incorrect sizing. Use manual setSize+setPosition.
- **Global ValueNotifier for button hover:** Causes unnecessary rebuilds during resize. Use StatefulWidget local state.
- **Skipping forceRedraw:** First frame renders at wrong size (8px border from TitleBarStyle.hidden).
- **Skipping reentry guard on fullscreen:** Rapid F11 causes ABA state corruption.
- **Writing persistence on every resize event:** Causes disk thrashing. Always debounce 500ms.
- **Skipping bounds check on restore:** Multi-monitor to single-monitor switch leaves window off-screen.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Window management | Custom Win32 calls | window_manager package | Handles cross-platform, DPI, edge cases |
| Aspect ratio enforcement | Flutter AspectRatio widget | Native WM_SIZING MethodChannel | Flutter-level causes resize jitter |
| System accent color | Hardcoded colors | dynamic_color package | D-01: follow system theme |
| Window geometry persistence | Custom file I/O | SharedPreferences + SettingsStore | Already implemented with sanitization |

## Common Pitfalls

### Pitfall 1: White Flash on Startup
**What goes wrong:** Frameless window shows white background for 1-2 frames before Flutter renders
**Why it happens:** setAsFrameless() called after show(), or no forceRedraw
**How to avoid:** Call setAsFrameless + setHasShadow BEFORE show(), then forceRedraw via MethodChannel
**Warning signs:** Brief white flash when app starts

### Pitfall 2: Resize Button Flicker
**What goes wrong:** Title bar buttons redraw/flash during window resize
**Why it happens:** Global state triggers full widget tree rebuild during resize
**How to avoid:** Use StatefulWidget local state for hover, RepaintBoundary on button group, ValueListenableBuilder for precise rebuild
**Warning signs:** Buttons visually flicker when dragging window edges

### Pitfall 3: Fullscreen State Corruption
**What goes wrong:** Rapid F11 presses cause window to be in inconsistent fullscreen/windowed state
**Why it happens:** Async toggle without reentry guard — two toggles interleave
**How to avoid:** `_togglingFullscreen` boolean guard, check at entry, reset in finally block
**Warning signs:** Window stuck in wrong state after rapid F11

### Pitfall 4: Window Lost After Monitor Change
**What goes wrong:** Window appears off-screen after disconnecting a monitor
**Why it happens:** Saved position refers to disconnected monitor
**How to avoid:** `_clampToVisibleBounds` check on restore — if window has <100px visible, center it
**Warning signs:** Window invisible after reconnecting laptop from docking station

### Pitfall 5: Persist Write Amplification
**What goes wrong:** Hundreds of SharedPreferences writes during resize drag
**Why it happens:** Writing on every onWindowResize event
**How to avoid:** 500ms debounce timer, cancel on new event, write once after settling
**Warning signs:** UI lag during resize, excessive disk I/O

## Code Examples

### WindowListener Registration

```dart
// Source: D:\player_flutter\lib\kernel\window\window_manager_service.dart
windowManager.addListener(this);

@override
void onWindowResize() {
  _resizeEndDebounce?.cancel();
  isResizing.value = true;
}

@override
void onWindowResized() {
  _schedulePersist();
  _resizeEndDebounce?.cancel();
  _resizeEndDebounce = Timer(
    const Duration(milliseconds: 500),
    () => isResizing.value = false,
  );
}

@override
void onWindowMoved() {
  _schedulePersist();
}

@override
void onWindowClose() {
  if (_closing) return;
  _closing = true;
  _closeCompleter = Completer<void>();
  _persistDebounce?.cancel();
  _persistWindowState().then((_) {
    return windowManager.destroy();
  }).then((_) {
    _closeCompleter!.complete();
  }).catchError((Object e) {
    debugPrint('[WindowManager] close sequence failed: $e');
    if (!_closeCompleter!.isCompleted) {
      _closeCompleter!.completeError(e);
    }
  });
}
```

### Bounds Check

```dart
// Source: D:\player_flutter\lib\kernel\window\window_manager_service.dart
Future<void> _clampToVisibleBounds(Size savedSize, Offset savedPosition) async {
  try {
    final view = ui.PlatformDispatcher.instance.views.first;
    final screenW = view.physicalSize.width / view.devicePixelRatio;
    final screenH = view.physicalSize.height / view.devicePixelRatio;
    const double minVisible = 100;

    final isOffScreen = savedPosition.dx + savedSize.width < minVisible ||
        savedPosition.dy + savedSize.height < minVisible ||
        savedPosition.dx > screenW - minVisible ||
        savedPosition.dy > screenH - minVisible;

    if (isOffScreen) {
      await windowManager.center();
    }
  } on Exception catch (e) {
    debugPrint('[WindowManager] bounds check failed: $e');
  }
}
```

### AspectRatioService

```dart
// Source: D:\player_flutter\lib\kernel\window\aspect_ratio_service.dart
class AspectRatioService {
  AspectRatioService._();
  static final AspectRatioService I = AspectRatioService._();

  static const _channel = MethodChannel('com.simple_player/aspect_ratio');
  static const ratio16x9 = 16.0 / 9.0;
  static const ratio4x3 = 4.0 / 3.0;

  double _current = 0.0;
  double get current => _current;

  Future<void> setAspectRatio(double ratio) async {
    if (_current == ratio) return;
    final previous = _current;
    _current = ratio;
    try {
      await _channel.invokeMethod('setAspectRatio', ratio);
    } on Exception catch (e) {
      _current = previous;
      debugPrint('[AspectRatio] setAspectRatio($ratio) failed: $e');
    }
  }

  Future<void> lock16x9() => setAspectRatio(ratio16x9);

  static const _cycleRatios = [ratio16x9, ratio4x3, 21.0 / 9.0, 0.0];

  Future<void> cycleRatio() async {
    final idx = _cycleRatios.indexOf(_current);
    final next = _cycleRatios[(idx + 1) % _cycleRatios.length];
    await setAspectRatio(next);
  }
}
```

## Runtime State Inventory

Not applicable — this is a greenfield UI phase, not a rename/refactor.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| setFullScreen() | Manual setSize+setPosition | Known broken on frameless | Must use manual approach |
| Flutter AspectRatio widget | Native WM_SIZING | Reference project proven | Smoother resize |
| Material icons | Win11 CustomPainter icons | D-03 decision | Cleaner look |
| 46px button width | 36x36px button size | D-04 decision | Match title bar height |
| Hardcoded close hover red | dynamic_color system accent | D-01 decision | Follow system theme |

**Deprecated/outdated:**
- `window_manager` 0.4.x: 0.5.1 is current pinned version in pubspec

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | AspectRatioService needs a `ratioNotifier` ValueNotifier for the title bar cycle button UI | Code Examples | Reference has it but current project tokens don't include it; may need to add |
| A2 | The reference project uses 46px button width despite D-04 saying 36x36 | Code Examples | D-04 overrides: use 36x36 per user decision |
| A3 | WindowManagerService should implement PlatformService (not be a separate service) | Architecture | Reference does this; alternative is separate singleton |
| A4 | The `_TitleBarButton` should use AnimatedContainer with 80ms duration, not 150ms as D-05 states | Code Examples | Reference uses 80ms; D-05 says 150ms — follow D-05 |
| A5 | `window_manager` 0.5.1 supports all methods used (setAsFrameless, setHasShadow, setPreventClose, waitUntilReadyToShow) | Standard Stack | Pinned version; reference uses same version |

## Open Questions

1. **PlatformService architecture: should WindowManagerService implement PlatformService directly, or should WindowsPlatformService delegate to it?**
   - What we know: Reference project has PlatformService as the interface, WindowManagerService as the implementation
   - What's unclear: Current project has separate PlatformService + WindowsPlatformService
   - Recommendation: Extend PlatformService with window methods, create WindowManagerService implementing it. Replace WindowsPlatformService in main.dart.

2. **Title bar tokens: reference project's custom_title_bar uses `Tokens.titleBarBg`, `Tokens.titleBarBorder`, `Tokens.titleBarHover`, `Tokens.closeHoverBg` — these don't exist in current project's tokens.dart**
   - What we know: Current tokens.dart has 50 tokens but missing title bar-specific colors
   - What's unclear: Should these be added to tokens.dart or defined inline?
   - Recommendation: Add to tokens.dart following existing pattern. Use DesignTokens convention from CLAUDE.md.

3. **Button width: D-04 says 36x36, reference uses 46x36**
   - What we know: User explicitly decided 36x36 in D-04
   - What's unclear: None
   - Recommendation: Follow D-04 — use 36x36.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All | ✓ | 3.44.0+ (beta) | — |
| window_manager | WindowManagerService | ✓ | 0.5.1 (pinned) | — |
| dynamic_color | Close button system accent | ✓ | ^1.8.1 | Hardcode fallback color |
| SharedPreferences | SettingsStore | ✓ | ^2.5.5 | — |
| C++ runner channels | forceRedraw, aspect_ratio | ✓ | Already wired | — |

**Missing dependencies with no fallback:** None

**Missing dependencies with fallback:** None

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) + fake_async ^1.0.0 |
| Config file | none — standard flutter_test |
| Quick run command | `flutter test` |
| Full suite command | `flutter test --coverage` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| WIN-01 | setAsFrameless before show | Integration | Manual — requires window_manager | N/A |
| WIN-02 | Title bar renders at 36px | Widget | `flutter test test/kernel/ui/window/custom_title_bar_test.dart` | Wave 0 |
| WIN-03 | isResizing guard prevents button rebuild | Widget | Widget test with isResizing=true | Wave 0 |
| WIN-04 | Drag calls startDragging | Widget | Mock PlatformService, verify call | Wave 0 |
| WIN-05 | Double-tap calls toggleMaximize | Widget | Mock PlatformService, verify call | Wave 0 |
| WIN-06 | Aspect ratio lock 16:9 idle | Unit | `flutter test test/kernel/window/aspect_ratio_service_test.dart` | Wave 0 |
| WIN-07 | WM_SIZING enforces ratio | Integration | Manual — requires native window | N/A |
| WIN-08 | Fullscreen toggle setSize/setPosition | Unit | Mock windowManager, verify calls | Wave 0 |
| WIN-09 | Reentry guard blocks rapid F11 | Unit | Toggle twice rapidly, verify single state change | Wave 0 |
| WIN-10 | State persists on close | Unit | Verify SettingsStore calls | Wave 0 |
| WIN-11 | 500ms debounce | Unit | fake_async, verify single write after 500ms | Wave 0 |
| WIN-12 | Bounds check centers off-screen window | Unit | Mock PlatformDispatcher, verify center() | Wave 0 |
| WIN-13 | Min size 640x360 | Unit | WindowOptions minimumSize check | Wave 0 |
| WIN-14 | Always-on-top toggle | Unit | Mock windowManager, verify setAlwaysOnTop | Wave 0 |
| WIN-15 | forceRedraw first frame | Integration | Manual — requires native window | N/A |

### Sampling Rate
- **Per task commit:** `flutter test test/kernel/window/`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/kernel/window/window_manager_service_test.dart` — covers WIN-08, WIN-09, WIN-10, WIN-11, WIN-12, WIN-13, WIN-14
- [ ] `test/kernel/window/aspect_ratio_service_test.dart` — covers WIN-06
- [ ] `test/kernel/ui/window/custom_title_bar_test.dart` — covers WIN-02, WIN-03, WIN-04, WIN-05
- [ ] `test/helpers/fake_window_manager.dart` — shared mock for window_manager package
- [ ] Extend `test/helpers/fake_platform_service.dart` — add window control methods

## Security Domain

Not applicable — Phase 1 is window chrome only, no user input handling, no network, no file operations. Security requirements (SEC-01 through SEC-03) are Phase 3.

## Sources

### Primary (HIGH confidence)
- `D:\player_flutter\lib\kernel\window\window_manager_service.dart` — 516 lines, proven working implementation
- `D:\player_flutter\lib\kernel\window\aspect_ratio_service.dart` — 69 lines, MethodChannel pattern
- `D:\player_flutter\lib\kernel\ui\window\custom_title_bar.dart` — 228 lines, title bar + buttons
- `D:\player_flutter\windows\runner\flutter_window.cpp` — C++ WM_SIZING handler, forceRedraw channel
- `D:\simple_player_flutter\windows\runner\flutter_window.cpp` — Already has both channels wired
- `D:\simple_player_flutter\lib\kernel\persistence\settings_store.dart` — Already has all persistence methods

### Secondary (MEDIUM confidence)
- window_manager 0.5.1 pinned in pubspec.yaml — verified via `flutter pub outdated`

### Tertiary (LOW confidence)
- AspectRatioService `ratioNotifier` — referenced in custom_title_bar.dart but not visible in aspect_ratio_service.dart source; may be a ValueNotifier<double> added separately

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — window_manager and dynamic_color already in pubspec, proven in reference
- Architecture: HIGH — directly porting from working reference project
- Pitfalls: HIGH — all pitfalls documented from reference project's production experience

**Research date:** 2026-05-09
**Valid until:** 2026-06-09 (30 days — stable stack, window_manager pinned)
