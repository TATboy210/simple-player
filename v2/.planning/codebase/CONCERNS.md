# Codebase Concerns

**Analysis Date:** 2026-06-19
**Analyzer Status:** 1 error, 1 warning, 4 infos

## CRITICAL (1)

### C++ Null Pointer Crash in FlutterWindow::MessageHandler

- Issue: `WM_FONTCHANGE` handler dereferences `current_controller_` after `OnDestroy()` has set it to nullptr.
- File: `windows/runner/flutter_window.cpp`
- Impact: Application crash on font change message after window destruction.
- Fix: Add null check before accessing `current_controller_` in `WM_FONTCHANGE` handler.

## HIGH (3)

### CMakeLists Typo

- Issue: `${MPPV_INCLUDE_DIR}` (double P) should be `${MPV_INCLUDE_DIR}` in CMakeLists.txt.
- File: `windows/runner/CMakeLists.txt`
- Impact: Build may silently fail to find mpv include directory.

### Static Mutable g_surface_desc in C++ Render Plugin

- Issue: Global static `g_surface_desc` shared between render thread and Flutter raster thread without synchronization.
- File: `windows/plugins/video_render/` (C++ layer)
- Impact: Data race between render thread and Flutter raster thread. Potential corruption of video surface descriptor.

### ANGLE D3D11 Device Lifetime

- Issue: Raw `reinterpret_cast` of mpv_handle from Dart int64. No COM `AddRef` on D3D11 device pointer.
- File: C++ render plugin layer
- Impact: If mpv releases the D3D11 device before Flutter finishes rendering, use-after-free crash.

## MEDIUM (5)

### Platform Lock-in — Windows-Only C++ Render Layer

- Issue: Video render plugin uses D3D11 + ANGLE directly. Not portable to macOS/Linux without rewrite.
- File: `windows/plugins/video_render/`
- Impact: Limits cross-platform expansion. Core player logic is portable but rendering is Windows-only.

### FFI Memory Safety

- Issue: Silent `catch (e) {}` in event poll loop. `late` handle without null safety. Use-after-free risk if `dispose()` called during active operation.
- File: `lib/infra/mpv/mpv_adapter.dart` (lines 136-138)
- Fix: Log caught exceptions via `AppLogger.error()`. Stop event loop on repeated failures. Initialize handle to `nullptr`.

### Test Coverage Gaps

- Coverage: 4 test files (~175 lines) covering only data classes. Zero coverage on all infrastructure/UI layers.
- Missing: MpvAdapter (HIGHEST RISK), MpvBindings, WindowService, PlayerFeature, WindowFeature, PlayerScreen, TitleBar, AppLogger.
- Priority: MpvAdapter > PlayerFeature > WindowService > Widgets.

### glReadPixels Performance

- Issue: Full GPU→CPU→GPU copy per frame via `glReadPixels`. At 4K60fps this is ~2GB/s bandwidth waste.
- File: C++ render plugin (ANGLE layer)
- Impact: Performance bottleneck on high-resolution video. Consider zero-copy texture sharing.

### Stale Widget Test

- Issue: `test/widget_test.dart` references non-existent `MyApp` class (leftover from Flutter template).
- File: `test/widget_test.dart`
- Fix: Update test to use actual `App` class or remove.

## LOW (6)

### Analyzer Not Using Strict Mode

- Issue: `analysis_options.yaml` uses default `flutter_lints/flutter.yaml` without `strict-casts: true` or `strict-inference: true`.
- File: `analysis_options.yaml`

### EventBus Never Disposed on App Exit

- Issue: `EventBus.dispose()` is never called. StreamController leaks on app exit.
- File: `lib/main.dart`, `lib/infra/event_bus/event_bus.dart`

### PlayerFeature Subscription Not Cancelled

- Issue: `_bus.on<PlayerCommand>().listen()` subscription stored nowhere. Cannot cancel on dispose.
- File: `lib/feature/player/player_feature.dart`

### Dual Fullscreen APIs

- Issue: Both `window_manager` and `flutter_fullscreen` are dependencies. Potential API conflict.
- File: `pubspec.yaml`, `lib/infra/window/window_service.dart`

### MpvCommand Empty Args Not Validated

- Issue: `mpvCommand()` accepts empty args list without validation. May cause undefined mpv behavior.
- File: `lib/infra/mpv/mpv_adapter.dart`

### No mpv Scripting Lockdown

- Issue: mpv's scripting/extension system not explicitly disabled. Potential security vector if user loads malicious media.
- File: `lib/infra/mpv/mpv_adapter.dart` (init sequence)
- Fix: Set `script=no` and `load-scripts=no` during init.

## Resolved Since v1

- ~~ValueNotifier-based state~~ → EventBus + sealed class events
- ~~Kernel/Features/UI 3-layer~~ → Core/Infra/Feature/UI 4-layer event-driven
- ~~fvp/MDK engine~~ → mpv FFI bindings
- ~~SharedPreferences~~ → Removed (MVP phase)
- ~~Deferred loading~~ → Removed (simplified startup)

---

*Concerns audit: 2026-06-19 — 1 CRITICAL, 3 HIGH, 5 MEDIUM, 6 LOW*
