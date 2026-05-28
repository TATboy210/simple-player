# Phase 1: Window Management Foundation - Research

**Researched:** 2026-05-28
**Domain:** Win32 MethodChannel, Flutter desktop C++ plugin, frameless window
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- D-01: Single MethodChannel `com.simple_player/window` with string command dispatch
- D-02: EventChannel `com.simple_player/window_events` for streaming window events
- D-03: PlatformException with error codes `{code: string, message: string}`
- D-04: C++ handler files in `windows/runner/` directory (window_channel.cpp/h)
- D-05: 7 core commands: `setFullscreen(bool)`, `setAlwaysOnTop(bool)`, `setSize(w,h)`, `setPosition(x,y)`, `setMinSize(w,h)`, `setFrameless(bool)`, `getTitleBarBounds()`
- D-06: 5 event types: `onResize(Size)`, `onMove(Position)`, `onFullscreenChange(bool)`, `onClose`, `onMinimize`
- D-07: WindowService wraps MethodChannel + EventChannel, exposes `ValueNotifier<WindowState>`
- D-08: WM_NCCALCSIZE (return 0) for frameless window
- D-09: WM_NCHITTEST for 8-direction resize edges, 8px edge width
- D-10: WM_NCHITTEST HTCAPTION return for title bar drag region
- D-11: 3 standard buttons (min/max/close), flat/immersive style, NOT GlassIconButton
- D-12: Double-click title bar toggles maximize/restore
- D-13: Title bar as independent layer above video content
- D-14: Title bar always visible, no auto-hide
- D-15: Transparent title bar, semi-transparent background on hover
- D-16: Title bar height 32px
- D-17: Fullscreen mode hides title bar
- D-18: CustomTitleBar independent of ControlsOverlay
- D-19: Window minimum size > 640x360 in 16:9
- D-20: Default initial window size 960x540
- D-21: Windows 11 native rounded corners via DWMWA_WINDOW_CORNER_PREFERENCE
- D-22: Use existing Flutter app icon for taskbar
- D-23: Title bar theme follows app theme (Tokens.*)
- D-24: Window centered on every startup (no position persistence)
- D-25: No visible window border (fully frameless)
- D-26: No window shadow
- D-27: Title bar displays app name only
- D-28: Aurora background when no video playing (existing behavior)
- D-29: No window state persistence
- D-30: Free window resize, no aspect ratio lock
- D-31: Preserve Windows snap layout functionality
- D-32: Replace all `catch (_)` and `on Object catch` with `on Exception catch (e)` + logger
- D-33: Fix scope: 4 known locations + global search
- D-34: Use `logger` package for error logging
- D-35: Register MethodChannel handler in `FlutterWindow::OnCreate`
- D-36: WindowService at `lib/kernel/bridge/window_service.dart`
- D-37: CustomTitleBar at `lib/ui/player/custom_title_bar.dart`

### Claude's Discretion
- WindowState data class structure (which fields, ValueNotifier wrapping)
- C++ error code enum values
- EventChannel event map structure
- WindowService initialization sequence within StartupCoordinator

### Deferred Ideas (OUT OF SCOPE)
- DPI change events (onDpiChange) — not in EventChannel
- Display change events (onDisplayChange) — not for multi-monitor
- Full macOS/Linux stubs — deferred to Phase 4 (PLATFORM-02)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| WIN-01 | Build MethodChannel window management layer | C++ handler pattern in windows/runner/, Dart WindowService wrapping MethodChannel |
| WIN-02 | Window state persistence and restoration | CONTEXT.md D-29 overrides: NO persistence, center on startup + defaults only |
| WIN-03 | Frameless window with custom title bar | WM_NCCALCSIZE + WM_NCHITTEST patterns, 32px title bar, flat buttons |
| PERF-02 | Fix error handling anti-patterns | 5 locations identified: playlist_store:168, fvp_engine:544, engine_prewarm:56, subtitle_service:37,59 |
| PLATFORM-01 | Windows MethodChannel implementation | C++ in windows/runner/, Win32 API calls, DPI-aware |
</phase_requirements>

## Summary

Phase 1 builds the self-managed window control layer from scratch, replacing the deleted `window_manager` dependency. The implementation splits into two tiers: a C++ MethodChannel/EventChannel handler in `windows/runner/` that calls Win32 APIs directly, and a Dart `WindowService` class in `lib/kernel/bridge/` that wraps the platform channel with `ValueNotifier<WindowState>` for reactive UI binding.

The existing codebase already has the infrastructure for this: `win32_window.cpp` handles WM_SIZE, WM_DPICHANGED, dark mode, and rounded corners. The new C++ handler extends `FlutterWindow::MessageHandler` to intercept WM_NCCALCSIZE (frameless), WM_NCHITTEST (resize/drag), and dispatch events via EventChannel. The Dart side follows the established `FvpEngine` pattern: abstract interface with ValueNotifiers, `_guardedAction` error handling, and service composition.

A significant simplification from the original plan: D-29 eliminates all window state persistence. No save/restore of position, size, fullscreen, or always-on-top. The window centers on every startup with default 960x540 size. This removes the need for SettingsStore integration and multi-monitor clamping logic from WIN-02.

**Primary recommendation:** Implement in 3 waves: (1) C++ MethodChannel handler + Dart WindowService skeleton, (2) Frameless window + WM_NCHITTEST resize/drag, (3) CustomTitleBar widget + error handling fixes.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Window geometry control (setSize, setPosition) | C++ (windows/runner/) | Dart (WindowService) | Win32 API calls must be native; Dart wraps with ValueNotifier |
| Frameless window (WM_NCCALCSIZE) | C++ (windows/runner/) | — | Win32 message handler, cannot be done from Dart |
| Resize/drag hit-testing (WM_NCHITTEST) | C++ (windows/runner/) | — | Win32 message handler, per-pixel cursor regions |
| Window state (fullscreen, alwaysOnTop, maximized) | C++ (windows/runner/) | Dart (WindowState) | C++ owns truth via Win32; Dart mirrors via EventChannel |
| Title bar UI (CustomTitleBar) | Dart (lib/ui/player/) | — | Pure Flutter widget, calls WindowService methods |
| Event streaming (resize, move, close) | C++ (EventChannel) | Dart (WindowService) | C++ detects Win32 messages; Dart receives via EventChannel |
| Error handling fixes | Dart (kernel/features) | — | Pure Dart code changes, no platform dependency |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter SDK | 3.44.0-0.3.pre (beta) | Framework | Already in use |
| `flutter/services.dart` | SDK | MethodChannel, EventChannel, PlatformException | Built-in, zero dependency |
| Win32 API | Windows SDK | SetWindowPos, MonitorFromWindow, GetWindowRect, DwmSetWindowAttribute | Direct OS control, no third-party |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `logger` | ^2.5.0 | Error logging | Already a dependency, use for all error handling fixes |
| `ffi` | ^2.1.4 | FFI utilities | Already a dependency, available if needed for Win32 types |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Self-built MethodChannel | `window_manager` package | Was previously used and removed; self-built gives full control, no external dependency |
| Self-built MethodChannel | `bitsdojo_window` | Good reference but adds dependency; self-built is simpler for our needs |
| WM_NCCALCSIZE frameless | SetWindowLong WS_CAPTION removal | CONTEXT.md D-08 locked to WM_NCCALCSIZE; more robust, preserves snap layouts |

**Installation:** No new packages needed. All dependencies already in pubspec.yaml.

## Package Legitimacy Audit

No new packages are installed in this phase. All dependencies (`logger`, `ffi`, Flutter SDK services) are already present in `pubspec.yaml`.

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| logger | npm/PyPI | — | — | — | N/A | Already installed |
| ffi | npm/PyPI | — | — | — | N/A | Already installed |

*No new packages to audit.*

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│  Dart UI Layer                                           │
│  ┌──────────────┐  ┌──────────────┐                     │
│  │ CustomTitleBar│  │PlayerScreen  │                     │
│  │ (32px, flat)  │  │(Stack layers)│                     │
│  └──────┬───────┘  └──────┬───────┘                     │
│         │                  │                             │
│         ▼                  ▼                             │
│  ┌──────────────────────────────┐                       │
│  │  WindowService               │                       │
│  │  ValueNotifier<WindowState>  │                       │
│  │  MethodChannel calls         │                       │
│  │  EventChannel listener       │                       │
│  └──────────────┬───────────────┘                       │
├─────────────────┼───────────────────────────────────────┤
│  Platform Channel│ (MethodChannel + EventChannel)        │
│  com.simple_player/window                                │
│  com.simple_player/window_events                         │
├─────────────────┼───────────────────────────────────────┤
│  C++ Layer       │                                      │
│  ┌───────────────▼──────────────────┐                   │
│  │  WindowChannel (window_channel.cpp)                  │
│  │  - HandleMethodCall (7 commands)                     │
│  │  - EventSink (5 event types)                         │
│  │  - Win32 API calls                                   │
│  └───────────────┬──────────────────┘                   │
│                  │                                       │
│  ┌───────────────▼──────────────────┐                   │
│  │  FlutterWindow::MessageHandler   │                   │
│  │  - WM_NCCALCSIZE → frameless     │                   │
│  │  - WM_NCHITTEST → resize/drag    │                   │
│  │  - WM_SIZE → EventChannel event  │                   │
│  │  - WM_CLOSE → EventChannel event │                   │
│  └──────────────────────────────────┘                   │
│                                                         │
│  Win32 APIs: SetWindowPos, MonitorFromWindow,           │
│              GetWindowRect, DwmSetWindowAttribute       │
└─────────────────────────────────────────────────────────┘
```

### Recommended Project Structure
```
lib/kernel/bridge/
├── window_service.dart      # WindowService class + WindowState
├── window_channel.dart      # MethodChannel/EventChannel wrappers (optional, could be in window_service.dart)

lib/ui/player/
├── custom_title_bar.dart    # CustomTitleBar widget (flat/immersive buttons)

windows/runner/
├── window_channel.cpp       # C++ MethodChannel handler + EventChannel
├── window_channel.h         # Header
├── flutter_window.cpp       # Modified: register handler in OnCreate, extend MessageHandler
├── win32_window.cpp         # Modified: WM_NCCALCSIZE + WM_NCHITTEST in MessageHandler
```

### Pattern 1: MethodChannel Command Dispatch (C++)

The C++ handler receives method calls from Dart and dispatches to Win32 APIs. Follows the standard Flutter Windows plugin pattern.

```cpp
// windows/runner/window_channel.cpp
// Source: Flutter Windows plugin API (flutter/method_channel.h)

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>

class WindowChannel {
 public:
  void Register(flutter::PluginRegistrarWindows* registrar);
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  HWND hwnd_ = nullptr;
  flutter::EncodableValue SetFullscreen(bool fullscreen);
  flutter::EncodableValue SetAlwaysOnTop(bool alwaysOnTop);
  flutter::EncodableValue SetSize(double w, double h);
  flutter::EncodableValue SetPosition(double x, double y);
  flutter::EncodableValue SetMinSize(double w, double h);
  flutter::EncodableValue SetFrameless(bool frameless);
  flutter::EncodableValue GetTitleBarBounds();
};
```

**When to use:** All window operations go through this single channel. Dart sends method calls, C++ executes Win32 APIs and returns results.

### Pattern 2: EventChannel Event Streaming (C++)

Events flow from C++ to Dart via EventChannel. The C++ side holds an EventSink reference and pushes events when Win32 messages arrive.

```cpp
// EventChannel setup in Register()
auto event_channel = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
    registrar->messenger(), "com.simple_player/window_events",
    &flutter::StandardMethodCodec::GetInstance());

auto handler = std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
    [this](const auto* args, auto&& events) -> auto {
        event_sink_ = std::move(events);
        return nullptr;
    },
    [this](const auto* args) -> auto {
        event_sink_ = nullptr;
        return nullptr;
    });
event_channel->SetStreamHandler(std::move(handler));
```

**When to use:** For push-based events (resize, move, fullscreen change, close, minimize). The Dart side listens via `EventChannel.receiveBroadcastStream()`.

### Pattern 3: WindowService with ValueNotifier (Dart)

```dart
// lib/kernel/bridge/window_service.dart
// Source: Follows FvpEngine pattern (lib/kernel/engine/fvp_engine.dart)

class WindowService {
  static const _channel = MethodChannel('com.simple_player/window');
  static const _eventChannel = EventChannel('com.simple_player/window_events');

  // ─── State (ValueNotifier pattern from FvpEngine) ───
  final ValueNotifier<bool> isFullscreen = ValueNotifier(false);
  final ValueNotifier<bool> isAlwaysOnTop = ValueNotifier(false);
  final ValueNotifier<bool> isMaximized = ValueNotifier(false);
  final ValueNotifier<Size> windowSize = ValueNotifier(const Size(960, 540));

  StreamSubscription<dynamic>? _eventSubscription;

  void init() {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(_handleEvent);
  }

  void _handleEvent(dynamic event) {
    final map = event as Map;
    switch (map['event'] as String) {
      case 'onResize':
        final w = (map['width'] as num).toDouble();
        final h = (map['height'] as num).toDouble();
        windowSize.value = Size(w, h);
      case 'onFullscreenChange':
        isFullscreen.value = map['fullscreen'] as bool;
      // ... other events
    }
  }

  Future<void> setFullscreen(bool value) async {
    try {
      await _channel.invokeMethod('setFullscreen', {'fullscreen': value});
    } on Exception catch (e) {
      log.e('WindowService.setFullscreen failed', error: e);
    }
  }

  // ... other methods

  void dispose() {
    _eventSubscription?.cancel();
    isFullscreen.dispose();
    isAlwaysOnTop.dispose();
    isMaximized.dispose();
    windowSize.dispose();
  }
}
```

**When to use:** All UI code interacts with WindowService, never directly with MethodChannel. ValueNotifiers enable ValueListenableBuilder in widgets.

### Pattern 4: WM_NCCALCSIZE Frameless Window (C++)

```cpp
// In FlutterWindow::MessageHandler or Win32Window::MessageHandler
// Source: Microsoft docs - WM_NCCALCSIZE
// https://learn.microsoft.com/en-us/windows/win32/winmsg/wm-nccalcsize

case WM_NCCALCSIZE: {
  if (wParam == TRUE && is_frameless_) {
    // Remove all non-client area — window becomes fully frameless
    // Preserve WS_THICKFRAME for resize capability
    auto params = reinterpret_cast<NCCALCSIZE_PARAMS*>(lParam);
    // Adjust to remove title bar but keep resize borders
    params->rgrc[0].top += 1; // Minimal top inset for resize cursor
    return 0;
  }
  break;
}
```

**When to use:** When `setFrameless(true)` is called from Dart. The C++ side sets `is_frameless_ = true` and handles WM_NCCALCSIZE to remove the title bar.

### Pattern 5: WM_NCHITTEST Resize + Drag (C++)

```cpp
// Source: Microsoft docs - WM_NCHITTEST
// https://learn.microsoft.com/en-us/windows/win32/inputdev/wm-nchittest

case WM_NCHITTEST: {
  if (!is_frameless_) break;

  POINT pt = {GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam)};
  ScreenToClient(hwnd, &pt);

  RECT rc;
  GetClientRect(hwnd, &rc);

  const int edge = 8; // D-09: 8px resize edge

  // 8-direction resize detection
  bool left = pt.x < edge;
  bool right = pt.x >= rc.right - edge;
  bool top = pt.y < edge;
  bool bottom = pt.y >= rc.bottom - edge;

  if (top && left) return HTTOPLEFT;
  if (top && right) return HTTOPRIGHT;
  if (bottom && left) return HTBOTTOMLEFT;
  if (bottom && right) return HTBOTTOMRIGHT;
  if (left) return HTLEFT;
  if (right) return HTRIGHT;
  if (top) return HTTOP;
  if (bottom) return HTBOTTOM;

  // D-10: Title bar drag region (32px from top)
  if (pt.y < 32) return HTCAPTION;

  return HTCLIENT;
}
```

**When to use:** When frameless mode is active. This enables both resize edges and title bar drag without WS_CAPTION.

### Anti-Patterns to Avoid

- **Singleton WindowService:** The old code used `WindowService.instance` singleton. The new design uses constructor injection — WindowService is created in PlayerServices and passed down. This follows the existing FvpEngine/PlaybackController pattern.
- **window_manager dependency:** Was removed. Do NOT re-introduce. Self-built MethodChannel is the locked approach.
- **GlassIconButton in title bar:** D-11 explicitly rejects this. Use flat/immersive style buttons.
- **Window state persistence:** D-29 eliminates this. No save/restore logic needed.
- **Bare `catch (_)` or `on Object catch`:** D-32 requires `on Exception catch (e)` + logger.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Window event streaming | Custom StreamController + polling | Flutter EventChannel | Built-in, handles lifecycle, type-safe codec |
| Win32 message handling | Raw dart:ffi calls to user32.dll | C++ MethodChannel handler | FFI is fragile for message pumps; C++ has direct HWND access |
| Window geometry queries | Dart FFI to GetWindowRect | C++ handler returns via MethodChannel | Single source of truth, DPI-aware in C++ |
| Error logging | debugPrint for errors | `logger` package | Already a dependency, structured output, log levels |
| Resize hit-testing | Dart-side MouseRegion + GestureDetector | WM_NCHITTEST in C++ | OS-level, pixel-perfect, respects DPI scaling |

**Key insight:** The Flutter embedder's C++ layer already owns the HWND and message pump. Trying to intercept Win32 messages from Dart via FFI fights the embedder architecture. The MethodChannel/EventChannel pattern is the designed integration point.

## Common Pitfalls

### Pitfall 1: WM_NCCALCSIZE Breaking Snap Layouts
**What goes wrong:** Returning 0 from WM_NCCALCSIZE removes all non-client area, which can break Windows snap layouts (Win+Arrow keys).
**Why it happens:** WS_CAPTION must be preserved (or WS_THICKFRAME) for snap to work.
**How to avoid:** Keep WS_THICKFRAME in window style. In WM_NCCALCSIZE, only adjust the top inset minimally (1px) rather than zeroing everything. D-31 requires snap preservation.
**Warning signs:** Win+Left/Right arrows don't snap the window.

### Pitfall 2: WM_NCHITTEST Coordinate Space Confusion
**What goes wrong:** Resize edges don't work or trigger in wrong locations.
**Why it happens:** WM_NCHITTEST lParam gives screen coordinates; client-relative calculation requires ScreenToClient.
**How to avoid:** Always call `ScreenToClient(hwnd, &pt)` before comparing against client rect. Use `GetClientRect` (not `GetWindowRect`) for the reference rect.
**Warning signs:** Resize only works on one edge, or edges are offset.

### Pitfall 3: EventChannel Sink Lifetime
**What goes wrong:** Events stop flowing after hot restart or widget rebuild.
**Why it happens:** EventChannel's onListen/onCancel lifecycle — if the Dart listener is cancelled and re-listened, the C++ sink reference may be stale.
**How to avoid:** Store the EventSink in the C++ handler. On onCancel, set it to null. On onListen, update it. Check for null before sending events.
**Warning signs:** Window resizes but UI doesn't update after hot restart.

### Pitfall 4: FlutterWindow::MessageHandler Precedence
**What goes wrong:** WM_NCCALCSIZE or WM_NCHITTEST messages are consumed by Flutter before reaching custom handler.
**Why it happens:** `FlutterWindow::MessageHandler` calls `flutter_controller_->HandleTopLevelWindowProc` first, which may return a result for some messages.
**How to handle:** Check if `HandleTopLevelWindowProc` returns a result. If it does, respect it. If not, fall through to custom handling. For WM_NCCALCSIZE and WM_NCHITTEST, Flutter typically doesn't handle them, so the fallthrough works.
**Warning signs:** Frameless mode has no effect.

### Pitfall 5: Fullscreen + Frameless State Confusion
**What goes wrong:** Entering fullscreen from frameless mode leaves artifacts or wrong window style.
**Why it happens:** Fullscreen typically uses SetWindowPos to cover the monitor + removes WS_CAPTION. Frameless also modifies the non-client area. Combining them requires careful state management.
**How to avoid:** Track `is_frameless_` and `is_fullscreen_` as separate booleans. In fullscreen, save and restore the pre-fullscreen window style. The C++ handler should have a clear state machine: normal → frameless → fullscreen transitions.
**Warning signs:** Exiting fullscreen shows wrong window style, title bar appears/disappears incorrectly.

### Pitfall 6: DWMWA_WINDOW_CORNER_PREFERENCE Reset
**What goes wrong:** Rounded corners disappear after maximize/restore.
**Why it happens:** Windows 11 DWM resets DWMWA_WINDOW_CORNER_PREFERENCE during snap/maximize/restore transitions.
**How to avoid:** Re-apply `DWMWCP_ROUND` in WM_SIZE handler. The existing `ApplyRoundedCorners()` function in `win32_window.cpp` already does this — extend it to run after fullscreen transitions too.
**Warning signs:** Square corners after maximizing and restoring.

## Code Examples

### Registering MethodChannel in FlutterWindow::OnCreate

```cpp
// windows/runner/flutter_window.cpp
// Source: Existing OnCreate pattern + Flutter plugin registration

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) return false;

  RECT frame = GetClientArea();
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) return false;

  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // D-35: Register window channel handler
  window_channel_.Register(
      flutter_controller_->engine(),
      GetHandle());  // Pass HWND for Win32 API calls

  return true;
}
```

### Extending FlutterWindow::MessageHandler for WM_NCCALCSIZE

```cpp
// windows/runner/flutter_window.cpp
LRESULT FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                                       WPARAM const wparam,
                                       LPARAM const lparam) noexcept {
  // Let Flutter handle first
  if (flutter_controller_) {
    auto result = flutter_controller_->HandleTopLevelWindowProc(
        hwnd, message, wparam, lparam);
    if (result) return *result;
  }

  // Custom handling for frameless window
  if (window_channel_.is_frameless()) {
    switch (message) {
      case WM_NCCALCSIZE:
        // D-08: Frameless via WM_NCCALCSIZE
        if (wParam == TRUE) {
          // Preserve resize borders (WS_THICKFRAME handles this)
          // Only remove the title bar height
          auto params = reinterpret_cast<NCCALCSIZE_PARAMS*>(lParam);
          params->rgrc[0].top += 1;
          return 0;
        }
        break;

      case WM_NCHITTEST: {
        // D-09 + D-10: Resize edges + drag region
        return window_channel_.HitTest(hwnd, lparam);
      }
    }
  }

  // Dispatch to EventChannel for events
  switch (message) {
    case WM_SIZE:
      window_channel_.OnResize(hwnd);
      break;
    case WM_CLOSE:
      window_channel_.OnClose();
      break;
  }

  // Existing handling
  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
```

### Dart WindowService Initialization

```dart
// lib/kernel/bridge/window_service.dart
// Source: Follows FvpEngine._guardedAction pattern

class WindowService {
  WindowService();

  static const _channel = MethodChannel('com.simple_player/window');
  static const _eventChannel = EventChannel('com.simple_player/window_events');

  bool _disposed = false;
  StreamSubscription<dynamic>? _eventSubscription;

  // ─── State (ValueNotifier pattern) ───

  final ValueNotifier<bool> isFullscreen = ValueNotifier(false);
  final ValueNotifier<bool> isAlwaysOnTop = ValueNotifier(false);
  final ValueNotifier<bool> isMaximized = ValueNotifier(false);
  final ValueNotifier<Size> windowSize = ValueNotifier(const Size(960, 540));

  /// Initialize event listener
  void init() {
    _eventSubscription = _eventChannel
        .receiveBroadcastStream()
        .listen(_handleEvent, onError: (e) {
      log.e('WindowService event stream error', error: e);
    });
  }

  void _handleEvent(dynamic event) {
    if (_disposed) return;
    final map = event as Map;
    switch (map['event'] as String) {
      case 'onResize':
        windowSize.value = Size(
          (map['width'] as num).toDouble(),
          (map['height'] as num).toDouble(),
        );
      case 'onFullscreenChange':
        isFullscreen.value = map['fullscreen'] as bool;
      // ... other events
    }
  }

  // ─── Commands (guardedAction pattern from FvpEngine) ───

  Future<void> _guardedCall(String name, Map<String, dynamic> args) async {
    if (_disposed) return;
    try {
      await _channel.invokeMethod(name, args);
    } on Exception catch (e) {
      log.e('WindowService.$name failed', error: e);
    }
  }

  Future<void> setFullscreen(bool value) =>
      _guardedCall('setFullscreen', {'fullscreen': value});

  Future<void> setAlwaysOnTop(bool value) =>
      _guardedCall('setAlwaysOnTop', {'alwaysOnTop': value});

  Future<void> setSize(double width, double height) =>
      _guardedCall('setSize', {'width': width, 'height': height});

  Future<void> setPosition(double x, double y) =>
      _guardedCall('setPosition', {'x': x, 'y': y});

  Future<void> setMinSize(double width, double height) =>
      _guardedCall('setMinSize', {'width': width, 'height': height});

  Future<void> setFrameless(bool value) =>
      _guardedCall('setFrameless', {'frameless': value});

  Future<Rect> getTitleBarBounds() async {
    if (_disposed) return Rect.zero;
    try {
      final result = await _channel.invokeMethod('getTitleBarBounds');
      final map = result as Map;
      return Rect.fromLTWH(
        (map['x'] as num).toDouble(),
        (map['y'] as num).toDouble(),
        (map['width'] as num).toDouble(),
        (map['height'] as num).toDouble(),
      );
    } on Exception catch (e) {
      log.e('WindowService.getTitleBarBounds failed', error: e);
      return Rect.zero;
    }
  }

  void dispose() {
    _disposed = true;
    _eventSubscription?.cancel();
    isFullscreen.dispose();
    isAlwaysOnTop.dispose();
    isMaximized.dispose();
    windowSize.dispose();
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `window_manager` package | Self-built MethodChannel | Phase 1 (this phase) | Full control, no external dependency |
| Singleton `WindowService.instance` | Constructor injection via PlayerServices | Phase 1 | Testable, follows FvpEngine pattern |
| Window state persistence (SettingsStore) | Center on startup + defaults (D-29) | Phase 1 | Simpler, no save/restore logic |
| `catch (_)` / `on Object catch` | `on Exception catch (e)` + logger | Phase 1 (PERF-02) | Proper error handling |

**Deprecated/outdated:**
- `window_manager` package: removed from pubspec, all references deleted
- `lib/window/window_service.dart` (old): deleted, 372 lines of singleton + window_manager code
- `lib/ui/shared/resize_notifier.dart` (old): deleted, replaced by EventChannel events
- `lib/ui/shared/resize_aware_builder.dart` (old): deleted

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Flutter's HandleTopLevelWindowProc does NOT consume WM_NCCALCSIZE or WM_NCHITTEST | Pitfall 4 | If Flutter handles these messages, custom frameless/resize won't work. Mitigation: test early in Wave 1. |
| A2 | EventChannel works correctly on Flutter 3.44 beta Windows | Pattern 2 | Beta SDK may have EventChannel bugs. Mitigation: fallback to MethodChannel polling if needed. |
| A3 | WS_THICKFRAME alone (without WS_CAPTION) preserves snap layouts | Pitfall 1 | If snap requires WS_CAPTION, need different approach. Mitigation: test Win+Arrow early. |
| A4 | WM_NCCALCSIZE returning 0 with WS_THICKFRAME keeps 1px resize border visible | Pattern 4 | May need different inset values. Mitigation: visual testing on Win11. |
| A5 | The `logger` package log.e() API accepts `error:` named parameter | Code Examples | API may differ. Mitigation: check logger 2.5.0 docs. |

## Open Questions

1. **FlutterWindow vs Win32Window MessageHandler split**
   - What we know: `FlutterWindow::MessageHandler` calls `HandleTopLevelWindowProc` first, then falls through to `Win32Window::MessageHandler`. The existing WM_SIZE, WM_DPICHANGED handling is in `Win32Window`.
   - What's unclear: Should WM_NCCALCSIZE/WM_NCHITTEST be in `FlutterWindow::MessageHandler` (before fallthrough) or in `Win32Window::MessageHandler` (after)?
   - Recommendation: Put in `FlutterWindow::MessageHandler` — it runs first, and these messages need to intercept before Flutter sees them. The WindowChannel handler needs HWND access, which FlutterWindow has.

2. **WindowChannel ownership and lifetime**
   - What we know: The C++ handler needs to live as long as the window. It needs HWND and EventSink.
   - What's unclear: Should WindowChannel be a member of FlutterWindow, or a separate object?
   - Recommendation: Member of FlutterWindow. It's created in OnCreate (after HWND exists) and destroyed in OnDestroy. The HWND is passed at construction.

3. **Fullscreen implementation approach**
   - What we know: Fullscreen needs to cover the entire monitor, remove title bar, hide taskbar.
   - What's unclear: Should we use `SetWindowPos` with monitor rect, or `SetWindowLong` style changes, or both?
   - Recommendation: Save current window rect + style. Set `WS_POPUP` style. `SetWindowPos` to monitor rect with `SWP_FRAMECHANGED`. Restore on exit. This is the standard Win32 fullscreen pattern.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All | ✓ | 3.44.0-0.3.pre (beta) | — |
| Windows SDK | C++ compilation | ✓ | (via Visual Studio) | — |
| Visual Studio C++ | C++ compilation | ✓ | (existing build works) | — |
| `logger` package | Error handling | ✓ | ^2.5.0 | debugPrint fallback |
| `ffi` package | Win32 types | ✓ | ^2.1.4 | Not needed if using C++ handler |

**Missing dependencies with no fallback:** None — all required tools are available.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in) |
| Config file | none — standard flutter test |
| Quick run command | `flutter test` |
| Full suite command | `flutter test --coverage` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| WIN-01 | WindowService sends correct MethodChannel calls | unit | `flutter test test/window/window_service_test.dart` | ❌ Wave 0 |
| WIN-02 | Window centers on startup with defaults | unit | `flutter test test/window/window_service_test.dart` | ❌ Wave 0 |
| WIN-03 | Frameless window + CustomTitleBar renders | widget | `flutter test test/widget/window/custom_title_bar_test.dart` | ❌ Wave 0 |
| PERF-02 | Error handling uses on Exception catch | static | `dart analyze --fatal-infos` | ✓ (built-in) |
| PLATFORM-01 | C++ handler registered in OnCreate | integration | Manual: `flutter run -d windows` | — |

### Sampling Rate
- **Per task commit:** `flutter test test/window/` (window-specific tests)
- **Per wave merge:** `flutter test` (full suite)
- **Phase gate:** Full suite green + `dart analyze --fatal-infos` + manual `flutter run -d windows` smoke test

### Wave 0 Gaps
- [ ] `test/window/window_service_test.dart` — covers WIN-01, WIN-02 (mock MethodChannel)
- [ ] `test/widget/window/custom_title_bar_test.dart` — covers WIN-03 (widget test)
- [ ] `test/helpers/fake_window_channel.dart` — mock MethodChannel for WindowService tests

## Sources

### Primary (HIGH confidence)
- `windows/runner/flutter_window.cpp` — existing OnCreate, MessageHandler patterns
- `windows/runner/win32_window.cpp` — WM_SIZE, WM_DPICHANGED, UpdateTheme, ApplyRoundedCorners
- `lib/kernel/engine/fvp_engine.dart` — `_guardedAction` pattern, ValueNotifier usage, error handling
- `lib/features/player/player_services.dart` — service composition, init/dispose lifecycle
- CONTEXT.md D-01 through D-37 — all locked decisions

### Secondary (MEDIUM confidence)
- Flutter Windows plugin API — MethodChannel/EventChannel C++ patterns (training knowledge)
- Microsoft WM_NCCALCSIZE docs — frameless window technique
- Microsoft WM_NCHITTEST docs — resize edge and drag region detection

### Tertiary (LOW confidence)
- A1-A5 assumptions in Assumptions Log — based on training knowledge, need early validation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all dependencies exist, Flutter SDK available
- Architecture: HIGH — follows established FvpEngine/PlaybackController patterns
- Pitfalls: MEDIUM — Win32 message handling edge cases need early testing
- C++ integration: MEDIUM — Flutter 3.44 beta Windows embedding behavior needs validation

**Research date:** 2026-05-28
**Valid until:** 2026-06-11 (14 days — Flutter beta may update)
