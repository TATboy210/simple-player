# Architecture Patterns — Cross-Platform Window Management

**Domain:** Flutter desktop cross-platform window management
**Researched:** 2026-06-23
**Confidence:** HIGH (based on current codebase analysis + ecosystem knowledge)

## Recommended Architecture

### Current Architecture (Windows-Only)

The existing codebase has a clean layered architecture with well-defined seams for cross-platform extension:

```
UI Layer (ValueListenableBuilder)
    |
    v
WindowBridge (abstract interface: 4 ValueNotifiers + 6 commands)
    |
    v
WindowService (thin coordinator, implements WindowBridge)
    |-- WindowState (pure state container: mode/windowSize/isResizing/isAlwaysOnTop)
    |-- WindowPersistence (debounce + write lock, wraps SettingsStore)
    |-- FullscreenController (mutex + rollback, injects PlatformFullscreen)
    |       |-- PlatformFullscreen (abstract: enter() -> Snapshot, exit(Snapshot))
    |       |       +-- Win32PlatformFullscreen (FFI user32.dll, WS_THICKFRAME fix)
    |       |-- WindowOps (abstract: getPosition/setSize/etc, injectable for tests)
    |       +-- RealWindowOps (delegates to window_manager)
    |
    v
window_manager package (cross-platform: Win/Mac/Linux)
```

**Key files:**
- `lib/kernel/bridge/window_bridge.dart` — abstract interface (26 lines)
- `lib/kernel/bridge/window_service.dart` — coordinator (262 lines)
- `lib/kernel/bridge/fullscreen_controller.dart` — mutex + rollback (167 lines)
- `lib/kernel/bridge/platform_fullscreen.dart` — platform abstraction (43 lines)
- `lib/kernel/bridge/window_state.dart` — state container (47 lines)
- `lib/kernel/bridge/window_persistence.dart` — debounce persistence (78 lines)
- `lib/kernel/bridge/win32/win32_platform_fullscreen.dart` — Win32 FFI impl (140 lines)

### Component Boundaries for Cross-Platform

The architecture already has the right abstraction seams. The work is adding concrete implementations, not restructuring.

```
+-----------------------------------------------------------------------+
|  UI Layer (unchanged -- depends only on WindowBridge interface)        |
|  CustomTitleBar, ControlsOverlay, KeyboardHandler, PlayerScreen       |
+----------------------------------+------------------------------------+
                                   | WindowBridge (abstract)
+----------------------------------+------------------------------------+
|  WindowService (thin coordinator -- minor platform factory change)    |
|  +---------------+ +------------------+ +-------------------------+  |
|  | WindowState    | | WindowPersistence| | FullscreenController    |  |
|  | (platform-     | | (platform-       | | (platform-agnostic,    |  |
|  |  agnostic)     | |  agnostic)       | |  injects PlatformFS)   |  |
|  +---------------+ +------------------+ +------------+------------+  |
+-------------------------------------------------------+--------------+
                                                        | PlatformFullscreen
                                                        | (abstract)
                              +-------------------------+--------------+
                              |                        |               |
                    +---------+---------+  +-----------+-----+  +------+---------+
                    | Win32PlatformFS    |  | MacosPlatformFS |  | LinuxPlatformFS|
                    | (exists, FFI)      |  | (new)           |  | (new)          |
                    +-------------------+  +-----------------+  +----------------+
```

**Platform isolation points (what changes per platform):**

| Component | Windows (exists) | macOS (new) | Linux (new) |
|-----------|-----------------|-------------|-------------|
| `PlatformFullscreen` impl | `Win32PlatformFullscreen` (FFI user32.dll) | `MacosPlatformFullscreen` (NSWindow) | `LinuxPlatformFullscreen` (GTK/GdkWindow) |
| `window_manager` calls | All work | All work (uses NSWindow internally) | All work (uses GTK internally) |
| Aspect ratio lock | C++ `WM_SIZING` (8-edge support) | NSWindow `willResize` delegate or manual | Not natively supported, manual only |
| Frameless window | C++ `WM_NCCALCSIZE` + `setAsFrameless` | `window_manager` `TitleBarStyle.hidden` | `window_manager` `TitleBarStyle.hidden` |
| DPI awareness | `WM_DPICHANGED` + `GetDpiForWindow` | Retina auto-handled by NSWindow | `GdkMonitor` or `PlatformDispatcher` |
| Window corner rounding | `DWMWA_WINDOW_CORNER_PREFERENCE` (Win11) | Native NSWindow corners | Native GTK corners |
| Refresh rate detection | `GetDeviceCaps(VREFRESH)` or `EnumDisplaySettings` | `NSScreen.maximumFramesPerSecond` | `GdkMonitor` or hardcoded 60Hz |

## Data Flow

### Window mode change (e.g., fullscreen toggle)

```
User presses F
  -> KeyboardHandler.onKeyEvent
  -> WindowService.setMode(WindowMode.fullscreen)
  -> FullscreenController.setFullscreen(true)
    -> mutex check (_isAnimating)
    -> _saveWindowState() via WindowOps (position, size)
    -> PlatformFullscreen.enter() -> FullscreenSnapshot
      -> [Win32] FFI: GetWindowLongPtr -> remove WS_THICKFRAME|WS_CAPTION -> SetWindowPos
      -> [macOS]  NSWindow.toggleFullScreen or NSWindow.styleMask manipulation
      -> [Linux]  gtk_window_fullscreen or GdkWindow property
    -> state.mode.value = WindowMode.fullscreen
  -> UI rebuilds via ValueListenableBuilder (hide title bar, resize controls)
```

### OS-driven state change (e.g., user drags window to maximize)

```
OS sends maximize event
  -> window_manager WindowListener callback
  -> WindowService.onWindowMaximize()
  -> state.mode.value = WindowMode.maximized
  -> UI rebuilds
```

### Window close with persistence

```
User clicks close
  -> WindowService.onWindowClose()
  -> _saveGeometry() (get position + size from window_manager)
  -> WindowPersistence.saveWindowGeometry() (debounce 150ms + write lock)
  -> SettingsStore.saveWindowGeometry() (SharedPreferences)
  -> dispose() + windowManager.destroy()
```

## Patterns to Follow

### Pattern 1: PlatformFullscreen Strategy (already exists)

**What:** Abstract `PlatformFullscreen` interface with `enter() -> FullscreenSnapshot` and `exit(FullscreenSnapshot)`. Each platform provides a concrete implementation. `FullscreenController` is platform-agnostic.

**When:** Any platform-specific window operation that needs rollback on failure.

**Example (existing Win32 implementation):**
```dart
class Win32PlatformFullscreen implements PlatformFullscreen {
  @override
  bool get requiresStyleSave => true;

  @override
  Future<FullscreenSnapshot> enter() {
    final hwnd = _getHwnd();
    final style = _getWindowLongPtr(hwnd, _gwlStyle);
    _setWindowLongPtr(hwnd, _gwlStyle, (style & ~_wsCaption & ~_wsThickframe) | _wsVisible);
    final screenW = _getSystemMetrics(0);
    final screenH = _getSystemMetrics(1);
    _setWindowPos(hwnd, _hwndTop, 0, 0, screenW, screenH, _swpFrameChanged | _swpNoZOrder);
    return Future.value(FullscreenSnapshot(windowStyle: style, position: Offset.zero, size: Size.zero));
  }

  @override
  void exit(FullscreenSnapshot snapshot) {
    final hwnd = _getHwnd();
    _setWindowPos(hwnd, _hwndTop, snapshot.position.dx.toInt(), snapshot.position.dy.toInt(),
        snapshot.size.width.toInt(), snapshot.size.height.toInt(), _swpFrameChanged | _swpNoZOrder);
    _setWindowLongPtr(hwnd, _gwlStyle, snapshot.windowStyle);
  }
}
```

### Pattern 2: Platform Factory with Graceful Degradation

**What:** `_createPlatformFullscreen()` in WindowService returns the correct implementation based on `Platform.isX`. Unsupported platforms throw `UnsupportedError` (not silently fail).

**When:** Adding new platform implementations.

**Example:**
```dart
PlatformFullscreen _createPlatformFullscreen() {
  if (Platform.isWindows) return Win32PlatformFullscreen();
  if (Platform.isMacOS) return MacosPlatformFullscreen();
  if (Platform.isLinux) return LinuxPlatformFullscreen();
  throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
}
```

### Pattern 3: WindowOps Injection for Testability

**What:** `WindowOps` abstract class wraps `window_manager` calls. `FullscreenController` accepts `WindowOps` via constructor injection. Tests use `FakeWindowOps`.

**When:** Any new code that needs to call window_manager from bridge layer.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Abstracting `window_manager` away further

**What:** Adding another abstraction layer between WindowService and window_manager.

**Why bad:** `window_manager` IS the cross-platform abstraction. Adding another layer doubles maintenance surface with zero benefit. The `WindowOps` abstraction in FullscreenController is sufficient for testability.

**Instead:** Use `window_manager` directly in WindowService. Use `PlatformFullscreen` only for operations that `window_manager` cannot handle (like WS_THICKFRAME removal on Windows).

### Anti-Pattern 2: Platform-specific code in WindowService

**What:** Putting `Platform.isWindows` checks or platform-specific logic in WindowService body.

**Why bad:** WindowService is a thin coordinator. Platform differences belong in `PlatformFullscreen` implementations.

**Instead:** The factory `_createPlatformFullscreen()` is the ONLY place `Platform.isX` checks should appear in bridge code.

### Anti-Pattern 3: Feature parity pressure

**What:** Implementing all features on all platforms before shipping any.

**Why bad:** Aspect ratio lock via C++ `WM_SIZING` is Windows-only with no macOS/Linux native equivalent. Forcing parity delays shipping.

**Instead:** Ship macOS first (highest user overlap with Flutter desktop), then Linux. Aspect ratio lock on Linux can be deferred if the manual constraint proves unreliable.

### Anti-Pattern 4: Conditional imports for platform detection

**What:** Using `import 'stub.dart' if (dart.library.io)` for window management.

**Why bad:** All desktop platforms are `dart:io`. Conditional imports add complexity with no benefit for window management code.

**Instead:** Use `dart:io Platform.isX` (already used in WindowService).

## Scalability Considerations

| Concern | At current scale | With cross-platform |
|---------|-----------------|---------------------|
| Platform code | 1 file (140 lines) | 3 files (~300 lines total) |
| Testing surface | 1 platform | 3 platforms, CI matrix |
| window_manager quirks | Known (WS_THICKFRAME) | Unknown per platform, needs discovery |
| Aspect ratio | C++ native (8-edge) | Varies: native on Win, manual on Mac/Linux |
| Fullscreen rollback | Tested (Win32 FFI) | Needs per-platform validation |

## Suggested Build Order

**Phase 1: macOS PlatformFullscreen** (2-3 days)
- Add `MacosPlatformFullscreen` implementing `PlatformFullscreen`
- Uses `NSWindow.styleMask` manipulation or `windowManager.setFullScreen()` (macOS handles WS_THICKFRAME gap natively)
- Update `_createPlatformFullscreen()` factory in WindowService
- Test fullscreen enter/exit/rollback on macOS
- **Why first:** macOS is the most common second platform for Flutter desktop apps, and NSWindow fullscreen is well-documented

**Phase 2: Linux PlatformFullscreen** (2-3 days)
- Add `LinuxPlatformFullscreen` implementing `PlatformFullscreen`
- X11: `gtk_window_fullscreen()` via FFI or `windowManager.setFullScreen()`
- Wayland: same GTK API, but compositor-dependent behavior
- Update factory
- **Why second:** Linux has more compositor fragmentation (X11 vs Wayland vs tiling WMs), needs more testing surface

**Phase 3: Aspect Ratio Lock Cross-Platform** (2-4 days)
- Current: C++ `WM_SIZING` in `windows/runner/flutter_window.cpp` — Windows only
- macOS: `NSWindowWillResizeNotification` delegate or manual constraint in `WindowListener.onWindowResize`
- Linux: Manual constraint in `onWindowResize` (no native equivalent)
- Extract `AspectRatioConstraint` as an injectable component like `PlatformFullscreen`
- **Why separate:** Aspect ratio lock is optional functionality, not blocking basic window management

**Phase 4: Platform Detection and Graceful Degradation** (1-2 days)
- `DisplayConfig` currently hardcoded to 60Hz — add macOS (`NSScreen.maximumFramesPerSecond`) and Linux (`GdkMonitor`) detection
- DPI scaling: macOS auto-handles Retina, Linux varies by compositor
- Ensure `window_manager` minimum size constraints work cross-platform

**Phase 5: Build System and CI** (1-2 days)
- macOS: `macos/` runner, entitlements for window management, code signing
- Linux: `linux/` runner, GTK3/4 dependency, Flatpak/snap packaging
- CI matrix: build + test on all three platforms

## Open Questions for Phase-Specific Research

1. **macOS fullscreen + Spaces behavior:** Does `NSWindow.toggleFullScreen` work correctly with Flutter's texture rendering, or does it need the same manual style manipulation as Win32?
2. **Linux Wayland fullscreen:** Which compositors support `gtk_window_fullscreen` reliably? (GNOME/Mutter yes, Sway/Wlroots uncertain)
3. **Aspect ratio on macOS:** Can `NSWindowWillResizeNotification` be hooked from Dart FFI, or does it require a C++ plugin?
4. **window_manager on Linux:** Does `setFullScreen()` produce the same 7px gap issue as on Windows, or does GTK handle it correctly?

## Sources

- Current codebase: `lib/kernel/bridge/` (9 files, all analyzed)
- Memory: `project_window_cross_platform.md` (confirms window_manager is cross-platform)
- Memory: `project_full_architecture.md` (5-layer architecture reference)
- Memory: `project_layer8_window_analysis.md` (WindowService analysis, 3 replacement options)
- Flutter embedder architecture: `shell/platform/{windows,darwin,linux}/` in flutter/engine
- window_manager package: pub.dev, leanflutter, supports Win/Mac/Linux natively
