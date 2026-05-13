# Simple Player Flutter

## What This Is

Flutter desktop media player for Windows, powered by fvp (MDK/FFmpeg). Kernel layer (engine, playlist, persistence, services) and UI layer (control bar, settings, playlist, keyboard) are both complete. Current focus: fixing widget-layer bugs, completing settings/fullscreen wiring, and achieving production-grade code quality.

## Core Value

Stable, efficient, secure frameless window with video playback — every control must work reliably, every visual state must be consistent, and the code must be production-grade.

## Requirements

### Validated

- ✓ FvpEngine with MDK/FFmpeg backend
- ✓ Playlist management (add, remove, reorder, 4 play modes)
- ✓ Settings persistence (SharedPreferences, debounced writes)
- ✓ PlaybackController orchestration (file ops, navigation, state monitoring)
- ✓ WindowBridge abstraction (WindowService + NoopWindowBridge)
- ✓ Keyboard handler (19-key bindings)
- ✓ ValueNotifier + ValueListenableBuilder state management
- ✓ Design system (50 tokens, Midnight theme, glass-morphism)
- ✓ Localization (EN/ZH via ARB)
- ✓ Controls overlay with auto-hide (3s fullscreen, 5s windowed)
- ✓ Volume popup with slider + mute toggle
- ✓ Speed popup with 8 preset speeds
- ✓ Progress bar with seek + buffered display
- ✓ Playlist panel with reorder + context menu
- ✓ Settings dialog (equalizer presets, audio track, video processing)
- ✓ Drag-and-drop file support
- ✓ Empty state with aurora background
- ✓ Error banner with action parsing

### Active

- [ ] Volume/Speed button highlight visible when popup open
- [ ] Fullscreen toggle works reliably (F key, button, double-click)
- [ ] Fullscreen mode persists across sessions
- [ ] Settings dialog accessible from control bar
- [ ] Code production-grade (no dead code, no hardcoded strings, proper error handling)

### Out of Scope

- Mobile platforms (Android/iOS) — desktop only
- Network streaming / DRM — local file playback only
- Custom equalizer (10-band) — 5 presets sufficient for v1
- General settings tab (language, theme) — v2

## Context

**Current codebase state (2026-05-13):**
- 64 Dart files, ~329KB total
- Kernel layer: MediaEngine (12 ValueNotifiers), FvpEngine (538 lines), Playlist, PlaybackController with mixin composition
- UI layer: 22 widget files, PlayerScreen, ControlsOverlay, ControlBar, VolumeSlider, SpeedButton, ProgressBar, PlaylistPanel, SettingsDialog
- Window layer: WindowService (457 lines), GeometryStore, AspectRatioService, Bootstrap
- Dead code: WindowManagerService (515 lines) — old implementation, should be removed

**Known bugs (from 5 rounds of debugging):**
- All 18 controlbar bugs fixed in code (setState, accentegg, ValueKey, active condition)
- User still reports highlight not visible — likely UX perception issue or overlay interaction
- Fullscreen mode not set optimistically (relies on window_manager callback)
- Settings dialog fallback text wrong (l10n.noAudioTracks for video processing)

**Architecture patterns:**
- ValueNotifier reactive state (no BLoC/Riverpod)
- OverlayEntry for popups (app-level Overlay)
- Mixin composition for PlaybackController (FileOperations + PlaybackNavigator + StateMonitor)
- C++ MethodChannel for aspect ratio (WM_SIZING) and window events

## Constraints

- **Platform**: Windows 10+ primary, Linux/macOS secondary
- **Flutter**: 3.44.0+, Dart 3.12.0+
- **Engine**: fvp 0.36.2 (MDK/FFmpeg)
- **Window**: window_manager 0.5.1
- **Performance**: 250ms position poll, 500ms persist debounce, 500ms resize debounce

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| ValueNotifier (no BLoC/Riverpod) | Lightweight, established in kernel | ✓ Good |
| OverlayEntry for popups | Correct z-order, independent positioning | ⚠️ Revisit — escapes FadeTransition |
| ValueKey(_popupOpen) | Force VLB Element rebuild on setState | ✓ Good — architecturally correct |
| accentegg for highlights | accent (#2C58F4) too dark on dark bg | ✓ Good — #66CCFF visible |
| Manual fullscreen (not setFullScreen) | setFullScreen broken on frameless | ✓ Good |

---
*Last updated: 2026-05-13 after widget layer analysis*
