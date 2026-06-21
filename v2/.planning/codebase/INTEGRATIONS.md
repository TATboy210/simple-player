# v2 Integrations

**Analysis Date:** 2026-06-19

## 1. mpv FFI Integration

### MpvBindings (136 lines)
- Raw FFI to libmpv-2.dll via `DynamicLibrary.open()`
- 12 function typedefs (Native/Dart pairs): mpv_create, mpv_initialize, mpv_command, mpv_wait_event, mpv_set_property_string, mpv_get_property, mpv_observe_property, mpv_set_option_string, mpv_terminate_destroy, mpv_free, mpv_error_string, mpv_render_context
- MpvEvent struct, MpvFormat/MpvEventId/MpvError constants
- Cross-platform library loading (Windows .dll, Linux .so, macOS .dylib)

### MpvAdapter (221 lines)
- High-level Dart wrapper around MpvBindings
- 16ms `Timer.periodic` event polling loop (replaces `mpv_set_wakeup_callback`)
- Property observation via `mpv_observe_property` with reply_userdata routing
- FFI memory management: `calloc/free` in `try/finally` blocks
- EventBus integration: fires PlayerEvents on mpv state changes

### Data Flow
```
UI → bus.fire(PlayerCommand) → PlayerFeature → MpvAdapter → mpv FFI
mpv FFI → MpvAdapter._pollEvents → _handleEvent → bus.fire(PlayerEvent) → UI
```

## 2. mpv Render Plugin (C++)

### mpv_render_plugin.cpp (446 lines)
- **Largest file in project**
- D3D11 + ANGLE rendering pipeline
- `mpv_render_context` integration for GPU-accelerated video
- Flutter TextureRegistrar for surface registration
- glReadPixels for frame transfer (performance concern at 4K60)

### Architecture
```
mpv (decode) → ANGLE (GL→D3D11) → glReadPixels → Flutter Texture → Screen
```

## 3. window_manager Integration

### WindowService (188 lines)
- Wraps `window_manager` package with `WindowListener` mixin
- Frameless window: `TitleBarStyle.hidden`, `windowButtonVisibility: false`
- Resize debounce: 100ms timer prevents feedback loops
- Fullscreen animation guard: 300ms `_isAnimating` lock
- Screen clamping: ensures at least 100px visibility on any edge

### Window Events
```
Native window event → WindowListener callback → _bus.fire(WindowEvent) → UI StreamBuilder
```

## 4. flutter_fullscreen Integration

- Used in `WindowService.setFullscreen()` for platform-native fullscreen
- `FullScreen.ensureInitialized()` called in `init()`
- `FullScreen.setFullScreen(bool)` for enter/exit
- `FullScreen.isFullScreen` for state query

## 5. AppLogger Integration

- 4 static levels: debug/info/warn/error
- Debug mode: `debugPrint()` only (no file I/O)
- Release mode: rotating file output to `APPDATA/SimplePlayer/logs/`
- 2MB file limit, 5 archive retention
- Timestamp-based log filenames

## Integration Map

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  Flutter UI  │────→│   EventBus   │────→│  mpv FFI    │
│  (Widgets)   │←────│  (Pub-Sub)   │←────│  (Native)   │
└─────────────┘     └──────────────┘     └─────────────┘
                           │
                    ┌──────┴──────┐
                    │             │
              ┌─────▼─────┐ ┌────▼──────┐
              │ WindowMgr  │ │  Logger   │
              │ (Platform) │ │  (File)   │
              └───────────┘ └───────────┘
```

---

*Integrations analysis: 2026-06-19 — CodeGraph + Understand-Anything*
