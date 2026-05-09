# Simple Player Flutter

## What This Is

A Flutter desktop media player for Windows (primary) with Linux/macOS support. Kernel layer (engine, playlist, persistence, services) is complete. Current focus: building the window shell and UI layer on top of existing kernel, referencing proven patterns from D:\player_flutter.

## Core Value

Stable, efficient, secure frameless window with video playback — the window must never flicker, crash, or leak memory. Everything else is secondary.

## Requirements

### Validated

- ✓ FvpEngine with MDK/FFmpeg backend — existing
- ✓ Playlist management (add, remove, reorder, play modes) — existing
- ✓ Settings persistence (SharedPreferences) — existing
- ✓ PlaybackController orchestration (file ops, navigation, state monitoring) — existing
- ✓ PlatformService abstraction (Windows/Linux) — existing
- ✓ Keyboard handler (14-key bindings) — existing
- ✓ ValueNotifier + ValueListenableBuilder state management — existing
- ✓ Design system (50 tokens, Midnight theme, glass-morphism) — existing
- ✓ Localization (EN/ZH via ARB) — existing

### Active

- [ ] Frameless window with custom title bar (36px, drag, window controls)
- [ ] Aspect ratio lock (16:9 idle, video ratio when playing, cycle button)
- [ ] Windows snap layouts support
- [ ] Fullscreen toggle (F11, manual setSize/position for frameless)
- [ ] Window state persistence (size, position, maximized, fullscreen, always-on-top)
- [ ] VideoSurface rendering (Texture widget from fvp engine)
- [ ] Controls overlay (play/pause, seek bar, volume, playlist toggle)
- [ ] Drag-and-drop file support (desktop_drop)
- [ ] File picker integration (file_picker)
- [ ] Empty state with open file button
- [ ] AspectRatioService via MethodChannel to native WM_SIZING
- [ ] VideoProcessingService wiring (currently dead code)
- [ ] Security hardening (URL validation, input bounds, SSRF protection)
- [ ] Performance optimization (dirty flags, batch writes, position poll tuning)

### Out of Scope

- Mobile platforms (Android/iOS) — desktop only for v1
- Streaming/DRM — local file playback only
- Audio-only player (just_audio) — fvp handles all media
- Network media streaming — local files only for v1
- Custom equalizer UI — kernel supports it but UI deferred to v2

## Context

**Existing codebase state:**
- Kernel layer complete: FvpEngine (555 lines), Playlist, PlaybackController, SettingsStore, PlaylistStore
- UI layer empty: app.dart renders "Ready" placeholder
- 11 unused dependencies in pubspec.yaml (window_manager, glass_kit, shadcn_flutter, etc.)
- Previous planning phases 1-3 (window chrome, resize, playback-aware sizing) deleted from working tree

**Reference project:** D:\player_flutter — full working implementation with:
- WindowManagerService (singleton, 500ms debounce, bounds check, fullscreen reentry guard)
- AspectRatioService (MethodChannel to native WM_SIZING, ratio cycling)
- CustomTitleBar (36px, drag, auto-hide when playing)
- PlayerScreen (responsive layout, keyboard handler, controls overlay)
- C++ runner (frameless first frame prep, forceRedraw channel)

**Key architectural decisions from reference:**
- Frameless window: `setAsFrameless()` + `setHasShadow(true)` before `show()`
- Fullscreen: manual `setSize` + `setPosition` (not `setFullScreen` — broken on frameless)
- Aspect ratio: native MethodChannel to WM_SIZING (not Flutter-level constraint)
- State: ValueNotifier + ValueListenableBuilder (no Provider/Riverpod/BLoC)
- Persistence: 500ms debounce on window geometry, SharedPreferences single-instance prewarm

**Known tech debt:**
- FvpEngine 555 lines — needs decomposition (MediaInfoParser, VideoEffectMixin)
- SettingsStore all-static — hard to test, no DI
- PlaylistStore all-static — timer leaks across tests
- 13 separate ValueNotifiers — consider grouping into state objects
- PlaybackController mixin chain — acceptable but implicit dependencies

## Constraints

- **Platform**: Windows 10+ primary (D3D11), Linux/macOS secondary
- **Flutter**: 3.44.0+ (beta channel), Dart 3.12.0+
- **Engine**: fvp 0.36.2 (MDK/FFmpeg, pre-1.0 — breaking changes possible)
- **Window**: window_manager 0.5.1 (pinned exact — consider updating)
- **Performance**: 250ms position poll, 500ms persist debounce, 500ms resize debounce
- **Security**: No SSRF protection, weak URL validation, unbounded subtitle delay

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Frameless window from start | Immersive media player UX, no system chrome | — Pending |
| AspectRatioService via MethodChannel | Native WM_SIZING is more reliable than Flutter-level constraints | — Pending |
| Keep fvp over media_kit | Lowest latency on Windows (D3D11 direct rendering) | — Pending |
| ValueNotifier pattern (no BLoC/Riverpod) | Already established in kernel, lightweight, sufficient for this scope | — Pending |
| Reference D:\player_flutter patterns | Proven working implementation, avoid reinventing | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-09 after initialization*
