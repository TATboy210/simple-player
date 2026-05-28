# Phase 1: Window Management Foundation - Pattern Map

**Mapped:** 2026-05-28
**Files analyzed:** 13 (6 new, 7 modified)
**Analogs found:** 9 / 13

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/kernel/bridge/window_service.dart` (NEW) | service | request-response + event-driven | `lib/kernel/engine/fvp_engine.dart` | exact |
| `windows/runner/window_channel.cpp` (NEW) | handler | request-response + event-driven | Flutter plugin API (no existing analog) | no-analog |
| `windows/runner/window_channel.h` (NEW) | header | — | `windows/runner/win32_window.h` | role-match |
| `windows/runner/flutter_window.cpp` (MODIFY) | handler | request-response | self (existing OnCreate/MessageHandler) | exact |
| `windows/runner/win32_window.cpp` (MODIFY) | handler | request-response | self (existing MessageHandler) | exact |
| `lib/ui/player/custom_title_bar.dart` (NEW) | component | request-response | `lib/ui/shared/glass_container.dart` | partial |
| `lib/ui/player/player_screen.dart` (MODIFY) | component | request-response | self (existing Stack compositing) | exact |
| `lib/features/player/player_services.dart` (MODIFY) | service | event-driven | self (existing composition) | exact |
| `windows/runner/CMakeLists.txt` (MODIFY) | config | — | self (existing build config) | exact |
| `lib/kernel/persistence/playlist_store.dart` (MODIFY) | service | CRUD | self (existing error handling fix) | exact |
| `lib/kernel/engine/fvp_engine.dart` (MODIFY) | service | CRUD | self (existing error handling fix) | exact |
| `lib/kernel/engine/engine_prewarm.dart` (MODIFY) | service | batch | self (existing error handling fix) | exact |
| `lib/features/player/services/subtitle_service.dart` (MODIFY) | service | file-I/O | self (existing error handling fix) | exact |

## Pattern Assignments

### `lib/kernel/bridge/window_service.dart` (NEW — service, request-response + event-driven)

**Analog:** `lib/kernel/engine/fvp_engine.dart`

**Imports pattern** (fvp_engine.dart lines 1-16):
```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
// WindowService will additionally import:
import 'package:flutter/services.dart';  // MethodChannel, EventChannel, PlatformException

import '../utils/log.dart';  // kernel-wide logger
```

**ValueNotifier state pattern** (fvp_engine.dart lines 56-96):
```dart
// FvpEngine declares ValueNotifiers as final fields with default values
@override
final ValueNotifier<int?> textureId = ValueNotifier<int?>(null);

@override
final ValueNotifier<MediaState> state = ValueNotifier<MediaState>(
  MediaState.idle,
);

@override
final ValueNotifier<int> position = ValueNotifier<int>(0);

@override
final ValueNotifier<double> volume = ValueNotifier<double>(1.0);

// WindowService should follow same pattern:
final ValueNotifier<bool> isFullscreen = ValueNotifier(false);
final ValueNotifier<bool> isAlwaysOnTop = ValueNotifier(false);
final ValueNotifier<bool> isMaximized = ValueNotifier(false);
final ValueNotifier<Size> windowSize = ValueNotifier(const Size(960, 540));
```

**`_guardedAction` pattern** (fvp_engine.dart lines 185-194):
```dart
/// 通用守卫：disposed 检查 + try-catch + debugPrint
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

// WindowService adapts to async MethodChannel calls:
// Future<void> _guardedCall(String name, Map<String, dynamic> args) async {
//   if (_disposed) return;
//   try {
//     await _channel.invokeMethod(name, args);
//   } on Exception catch (e) {
//     log.e('WindowService.$name failed', error: e);
//   }
// }
```

**Dispose pattern** (fvp_engine.dart lines 610-632):
```dart
@override
void dispose() {
  _disposed = true;
  final p = _playerInstance;
  if (p != null) {
    _positionPoller.dispose();
    _callbackHandler.dispose();
    p.textureId.removeListener(_onTextureIdChanged);
    p.dispose();
  }

  textureId.dispose();
  state.dispose();
  position.dispose();
  duration.dispose();
  volume.dispose();
  isMuted.dispose();
  isBuffering.dispose();
  subtitleText.dispose();
  buffered.dispose();
  aspectRatio.dispose();
  errorMessage.dispose();
  playbackSpeed.dispose();
}

// WindowService dispose should:
// 1. Set _disposed = true
// 2. Cancel _eventSubscription
// 3. Dispose all ValueNotifiers
```

**Error handling — `on Exception catch (e)`** (fvp_engine.dart lines 339, 358, 402):
```dart
// Every catch in FvpEngine uses `on Exception catch (e)` — never bare catch
} on Exception catch (e) {
  state.value = MediaState.error;
  _errorType = PathValidator.isUrl(trimmed)
      ? MediaErrorType.network
      : MediaErrorType.playback;
  errorMessage.value = '无法打开: ${PathUtils.basename(path)}\n$e';
}

// WindowService uses logger instead of debugPrint (D-34):
} on Exception catch (e) {
  log.e('WindowService.setFullscreen failed', error: e);
}
```

---

### `windows/runner/window_channel.cpp` (NEW — handler, request-response + event-driven)

**Analog:** No existing analog in codebase (first C++ MethodChannel handler). Pattern from RESEARCH.md code examples.

**Registration pattern** (from RESEARCH.md Pattern 1):
```cpp
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>

class WindowChannel {
 public:
  void Register(flutter::PluginRegistrarWindows* registrar, HWND hwnd);
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  HWND hwnd_ = nullptr;
  // ... command methods
};
```

**EventChannel setup** (from RESEARCH.md Pattern 2):
```cpp
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

---

### `windows/runner/window_channel.h` (NEW — header)

**Analog:** `windows/runner/win32_window.h` (lines 1-102)

**Header guard pattern** (win32_window.h lines 1-2):
```cpp
#ifndef RUNNER_WIN32_WINDOW_H_
#define RUNNER_WIN32_WINDOW_H_
```

**Class declaration pattern** (win32_window.h lines 12-100):
```cpp
#include <windows.h>
#include <flutter/method_channel.h>
#include <flutter/event_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>
#include <memory>

class WindowChannel {
 public:
  WindowChannel();
  ~WindowChannel();

  void Register(flutter::PluginRegistrarWindows* registrar, HWND hwnd);
  bool is_frameless() const { return is_frameless_; }

  // MessageHandler delegates
  LRESULT HitTest(HWND hwnd, LPARAM lparam);
  void OnResize(HWND hwnd);
  void OnClose();

 private:
  HWND hwnd_ = nullptr;
  bool is_frameless_ = false;
  bool is_fullscreen_ = false;
  // ... event sink, command methods
};
```

---

### `windows/runner/flutter_window.cpp` (MODIFY — handler, request-response)

**Analog:** Self (existing code)

**Current OnCreate** (flutter_window.cpp lines 12-31):
```cpp
bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  return true;
}

// ADD after SetChildContent (D-35):
//   window_channel_.Register(
//       flutter_controller_->engine(), GetHandle());
```

**Current MessageHandler** (flutter_window.cpp lines 41-63):
```cpp
LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

// ADD before the WM_FONTCHANGE switch:
//   if (window_channel_.is_frameless()) {
//     switch (message) {
//       case WM_NCCALCSIZE: // D-08 frameless
//       case WM_NCHITTEST:  // D-09 + D-10 resize/drag
//     }
//   }
//   switch (message) {
//     case WM_SIZE:  window_channel_.OnResize(hwnd);
//     case WM_CLOSE: window_channel_.OnClose();
//   }
```

**Header modification** (flutter_window.h lines 1-33):
```cpp
// ADD include:
#include "window_channel.h"

// ADD private member:
  WindowChannel window_channel_;
```

---

### `windows/runner/win32_window.cpp` (MODIFY — handler, request-response)

**Analog:** Self (existing MessageHandler)

**Current MessageHandler** (win32_window.cpp lines 202-256):
```cpp
LRESULT
Win32Window::MessageHandler(HWND hwnd,
                            UINT const message,
                            WPARAM const wparam,
                            LPARAM const lparam) noexcept {
  switch (message) {
    case WM_DESTROY:
      // ...
    case WM_DPICHANGED:
      // ...
    case WM_SIZE: {
      RECT rect = GetClientArea();
      if (child_content_ != nullptr) {
        MoveWindow(child_content_, rect.left, rect.top,
                   rect.right - rect.left, rect.bottom - rect.top, FALSE);
      }
      ApplyRoundedCorners(hwnd);  // Re-apply after snap/maximize/restore
      return 0;
    }
    case WM_ERASEBKGND:
      return 1;
    case WM_ACTIVATE:
      // ...
    case WM_DWMCOLORIZATIONCOLORCHANGED:
      // ...
  }
  return DefWindowProc(window_handle_, message, wparam, lparam);
}

// NOTE: WM_NCCALCSIZE and WM_NCHITTEST go in FlutterWindow::MessageHandler
// (before Win32Window::MessageHandler fallthrough), NOT here.
// FlutterWindow runs first and can intercept before the base class.
```

**ApplyRoundedCorners** (win32_window.cpp lines 28-32) — existing pattern to reuse:
```cpp
void ApplyRoundedCorners(HWND hwnd) {
  DWORD corner = DWMWCP_ROUND;
  DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE,
                        &corner, sizeof(corner));
}
// D-21: Call this after fullscreen transitions too.
```

---

### `lib/ui/player/custom_title_bar.dart` (NEW — component, request-response)

**Analog:** `lib/ui/shared/glass_container.dart` (partial — for styling reference, NOT for glassmorphism per D-11)

**Title bar button pattern** — flat/immersive, NOT GlassIconButton (D-11):
```dart
// D-11: Flat/immersive style buttons, NOT glassmorphism
// Use InkWell for hover/press feedback (per user feedback: no animation)
// Use Tokens.* for all visual values
// Title bar height: 32px (D-16)
// Transparent background, semi-transparent on hover (D-15)

// Reference: GlassButton hover/press pattern (glass_container.dart lines 109-125)
final _hovered = ValueNotifier<bool>(false);
final _pressed = ValueNotifier<bool>(false);

// But CustomTitleBar uses flat style, not GlassContainer wrapping.
// Build a simple Row with:
//   - Leading: app name text (D-27)
//   - Trailing: 3 flat buttons (minimize, maximize/restore, close)
//   - Double-click: toggle maximize/restore (D-12)
//   - Drag: HTCAPTION handled in C++ (D-10), no Flutter GestureDetector needed
```

**Tokens reference** (tokens.dart lines 1-50):
```dart
import '../theme/tokens.dart';
// Use: Tokens.textPrimary, Tokens.textSecondary, Tokens.bgHover,
//      Tokens.fontBody, Tokens.weightMedium, Tokens.spSm, etc.
```

**WindowService integration** — ValueListenableBuilder pattern:
```dart
// Build title bar visibility based on fullscreen state (D-17)
ValueListenableBuilder<bool>(
  valueListenable: windowService.isFullscreen,
  builder: (context, isFullscreen, _) {
    if (isFullscreen) return const SizedBox.shrink();
    return _TitleBarContent(/* ... */);
  },
);
```

---

### `lib/ui/player/player_screen.dart` (MODIFY — component, request-response)

**Analog:** Self (existing Stack compositing)

**Current Stack structure** (player_screen.dart lines 122-153):
```dart
Stack(
  fit: StackFit.expand,
  children: [
    VideoSurface(engine: widget.engine),
    if (widget.emptyState != null)
      ValueListenableBuilder<MediaState>(/* ... */),
    ControlsOverlay(/* ... */),
  ],
)

// ADD CustomTitleBar as a new layer ABOVE the Stack (D-13):
// Title bar is independent layer above video content.
// Position at top of the outer Stack, not inside the video Stack.
// The outer Stack structure (lines 197-224):
Stack(
  children: [
    videoContent!,        // existing Row with video + playlist
    // ADD: CustomTitleBar at top (D-13, D-14)
    if (_playlistMounted) // existing playlist panel
      IgnorePointer(/* ... */),
  ],
)
```

---

### `lib/features/player/player_services.dart` (MODIFY — service, event-driven)

**Analog:** Self (existing service composition)

**Current composition** (player_services.dart lines 1-40):
```dart
class PlayerServices {
  late final FvpEngine engine;
  late final Playlist playlist;
  late final PlaybackController controller;
  late final VideoProcessingService videoProcessing;

  final ValueNotifier<int> playlistGeneration = ValueNotifier(0);

  Future<void> init() async {
    engine = FvpEngine();
    playlist = Playlist();
    controller = PlaybackController(
      engine: engine,
      playlist: playlist,
      onNeedRebuild: () => playlistGeneration.value++,
    );
    final settings = await SettingsStore.load();
    await controller.init(settings: settings);
    videoProcessing = VideoProcessingService(engine, initialSettings: settings);
  }

  void dispose() {
    playlistGeneration.dispose();
    videoProcessing.dispose();
    controller.dispose();
    engine.dispose();
  }
}

// ADD WindowService (D-36, D-07):
//   late final WindowService windowService;
// In init():
//   windowService = WindowService();
//   windowService.init();
// In dispose():
//   windowService.dispose();
```

---

### Error Handling Fixes (PERF-02, D-32/D-33/D-34)

**Pattern source:** `lib/kernel/engine/fvp_engine.dart` — consistent `on Exception catch (e)` usage

**Fix 1: `lib/kernel/persistence/playlist_store.dart` line 168**
```dart
// BEFORE:
        } catch (_) {
          // 跳过损坏项
        }

// AFTER (D-32, D-34):
        } on Exception catch (e) {
          log.d('PlaylistStore._migrateHistory: skipping corrupt entry: $e');
        }
```

**Fix 2: `lib/kernel/engine/fvp_engine.dart` line 544**
```dart
// BEFORE:
    } on Exception catch (_) {
      return 0;
    }

// AFTER (D-34 — add logging):
    } on Exception catch (e) {
      log.d('FvpEngine.subtitleDelay parse error: $e');
      return 0;
    }
```

**Fix 3: `lib/kernel/engine/engine_prewarm.dart` line 56**
```dart
// BEFORE:
    } on Object catch (e) {
      _prewarmed = false;
      log.d('EnginePrewarm failed: $e');
    }

// AFTER (D-32 — narrow to Exception):
    } on Exception catch (e) {
      _prewarmed = false;
      log.d('EnginePrewarm failed: $e');
    }
```

**Fix 4: `lib/features/player/services/subtitle_service.dart` lines 37, 59**
```dart
// BEFORE (line 37):
    } on Object catch (e) {
      log.d('SubtitleService.detectAndLoad error: $e');
    }

// AFTER (D-32 — narrow to Exception):
    } on Exception catch (e) {
      log.d('SubtitleService.detectAndLoad error: $e');
    }

// BEFORE (line 59):
    } on Object catch (e) {
      log.d('SubtitleService.detectAndLoadSync error: $e');
    }

// AFTER (D-32 — narrow to Exception):
    } on Exception catch (e) {
      log.d('SubtitleService.detectAndLoadSync error: $e');
    }
```

---

### `windows/runner/CMakeLists.txt` (MODIFY — config)

**Analog:** Self (existing build config)

**Current sources** (CMakeLists.txt lines 9-17):
```cmake
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# ADD window_channel.cpp to the source list:
#   "window_channel.cpp"
```

---

## Shared Patterns

### ValueNotifier + ValueListenableBuilder (Reactive UI)
**Source:** `lib/kernel/engine/fvp_engine.dart` lines 56-96
**Apply to:** `window_service.dart`, `custom_title_bar.dart`
```dart
// Service declares ValueNotifiers:
final ValueNotifier<bool> isFullscreen = ValueNotifier(false);

// UI binds via ValueListenableBuilder:
ValueListenableBuilder<bool>(
  valueListenable: windowService.isFullscreen,
  builder: (context, isFullscreen, _) => /* widget */,
);
```

### `_guardedAction` / `_guardedCall` (Disposed-safe Error Handling)
**Source:** `lib/kernel/engine/fvp_engine.dart` lines 185-194
**Apply to:** `window_service.dart`
```dart
void _guardedAction(String name, void Function() action) {
  if (_disposed) return;
  try {
    action();
  } on Exception catch (e) {
    debugPrint('FvpEngine.$name error: $e');
  }
}
```

### Logger Usage
**Source:** `lib/kernel/utils/log.dart`
**Apply to:** All Dart error handling (D-34)
```dart
import '../utils/log.dart';

// Usage:
log.d('message');     // debug
log.e('message', error: e);  // error with exception
```
Note: `log` is a global `Logger` instance from the `logger` package. Use `log.e()` for errors, `log.d()` for debug messages. The `error:` named parameter passes the exception object.

### Error Handling — `on Exception catch (e)` (PERF-02)
**Source:** `lib/kernel/engine/fvp_engine.dart` (throughout)
**Apply to:** All 4 error handling fix locations + all new WindowService code
```dart
// CORRECT:
} on Exception catch (e) {
  log.e('Operation failed', error: e);
}

// WRONG (D-32 forbids):
} catch (_) { }           // swallows everything
} on Object catch (e) { } // catches Error subtypes
```

### Service Composition (Constructor Injection)
**Source:** `lib/features/player/player_services.dart` lines 1-40
**Apply to:** WindowService integration into PlayerServices
```dart
class PlayerServices {
  late final WindowService windowService;  // ADD

  Future<void> init() async {
    // ... existing init ...
    windowService = WindowService();  // ADD
    windowService.init();             // ADD
  }

  void dispose() {
    windowService.dispose();  // ADD (before engine.dispose)
    // ... existing dispose ...
  }
}
```

### C++ MessageHandler Registration
**Source:** `windows/runner/flutter_window.cpp` lines 12-31 (OnCreate), 41-63 (MessageHandler)
**Apply to:** WindowChannel registration in FlutterWindow
```cpp
// OnCreate: register after RegisterPlugins + SetChildContent
window_channel_.Register(flutter_controller_->engine(), GetHandle());

// MessageHandler: intercept before base class fallthrough
// Flutter handles first via HandleTopLevelWindowProc
// Then custom WM_NCCALCSIZE/WM_NCHITTEST handling
// Then WM_SIZE/WM_CLOSE event dispatch
// Then Win32Window::MessageHandler fallthrough
```

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `windows/runner/window_channel.cpp` | handler | request-response + event-driven | First C++ MethodChannel/EventChannel handler in codebase. Use RESEARCH.md code examples as reference. |
| `lib/ui/player/custom_title_bar.dart` | component | request-response | No existing flat/immersive title bar widget. GlassContainer exists but is explicitly NOT the pattern (D-11). Build from scratch using Tokens.* + InkWell hover feedback. |

## Metadata

**Analog search scope:** `lib/kernel/`, `lib/features/`, `lib/ui/`, `windows/runner/`
**Files scanned:** 15
**Pattern extraction date:** 2026-05-28
