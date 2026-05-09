# Feature Landscape

**Domain:** Desktop media player (Windows primary)
**Researched:** 2026-05-09
**Reference:** D:\player_flutter (complete working implementation)
**Current state:** Kernel complete, UI layer empty (app.dart = "Ready" placeholder)

## Table Stakes

Features users expect from any desktop media player. Missing any = users switch to VLC/mpv.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Video playback (play/pause/stop) | Core purpose | Low | Kernel exists: `FvpEngine.togglePlayPause()`, `stop()` |
| Seek bar with time display | Navigate media | Medium | `ProgressBar` + `_TimeRangeDisplay` in reference; needs drag-to-seek, hover thumbnails optional |
| Volume control with mute | Audio management | Low | `engine.setVolume()`, `engine.setMute()` exist in kernel |
| File open dialog | Load media | Low | `file_picker` package; kernel `FileOperations.openFile()` exists |
| Drag-and-drop files | Windows UX expectation | Medium | `desktop_drop` package; `DropHandler` in reference with path validation |
| Keyboard shortcuts | Power users, accessibility | Medium | 19 shortcuts in reference; kernel `KeyboardHandler` maps to engine methods |
| Fullscreen toggle | Immersive viewing | High | Frameless window requires manual `setSize`/`setPosition` (not `setFullScreen`); F11 + double-click |
| Playlist panel | Queue management | Medium | `PlaylistPanel` in reference: drag reorder, right-click menu, tabs (playlist/history) |
| Window controls (min/max/close) | Basic window management | Low | `TitleBarControls` in reference; `PlatformService` abstraction exists |
| Aspect ratio handling | Video display correctness | High | `AspectRatioService` via MethodChannel to native WM_SIZING; cycle button in title bar |
| Subtitle display | Accessibility, i18n | Medium | `engine.toggleSubtitle()`, subtitle delay adjustment (`]`/`[` keys) |
| Error handling with recovery | Graceful degradation | Low | `ErrorBanner` in reference; engine `MediaState.error` + retry |

## Differentiators

Features that elevate Simple Player above "just another player." Competitive advantage.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Aurora breathing background | Premium idle-state visual (Apple/Spotify-inspired) | Medium | `AuroraBackground` with 3 Lissajous blobs, pre-rendered Image cache, auto-pause during playback |
| Glass-morphism controls | Modern, immersive UI | Medium | `BackdropFilter` + `bgGlass`; resize-time degradation to solid color for perf |
| Auto-hiding controls overlay | Maximum video real estate | Medium | `ControlsOverlay`: mouse-movement show, timed hide (3s fullscreen / 5s windowed), idle=persistent |
| OSD floating pill | Non-intrusive feedback (volume, speed) | Low | `_OsdBubble` with glass background; appears on volume/mute change, fades after 1s |
| Playback speed control | Power user feature | Low | `SpeedButton` with 8 presets (0.5x-4x); custom `OverlayEntry` popup with animation |
| Play modes (4 modes) | Flexible playback | Low | Sequential, single repeat, list repeat, shuffle; `PlayMode` enum exists in kernel |
| Resume playback (breakpoints) | Continue where left off | Medium | `PlaylistItem.positionMs` persisted; shown as subtitle in playlist panel; `PlaylistStore` saves |
| Always-on-top pin | Multitasking | Low | `PlatformService.toggleAlwaysOnTop()`; pin icon in title bar |
| Responsive layout | Works at any window size | Medium | Breakpoint 600dp: wide=Row (panel right), narrow=overlay (panel slides in) |
| Media info dialog | Transparency about file properties | Low | `MediaInfoDialog`: resolution, codec, audio tracks, subtitle tracks, duration |
| Right-click context menu | Desktop-native UX | Low | Play, copy path, properties, remove; per-playlist-item |
| Auto-hide title bar when playing | Maximum immersion | Low | `AnimatedSlide` up when `isPlaying`; mouse hover top 4px restores |
| Localization (EN/ZH) | Chinese market primary | Low | ARB-based; `AppLocalizations` with 80+ keys already defined |
| Equalizer presets | Audio customization | Low | 5 presets (Off, Bass Boost, Vocal, Rock, Classical); `engine.setEqualizer()` in kernel |
| Audio track switching | Multi-language content | Low | `engine.getAudioTracks()`, `switchAudioTrack()` in kernel; `SettingsDialog` tab |
| Tabular figures for time | Professional typography | Low | `fontFeatures: [FontFeature.tabularFigures()]` prevents layout shift on time update |

## Anti-Features

Features to explicitly NOT build. Each has a clear reason.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Network streaming | Scope creep; fvp supports it but security surface (SSRF) is unaddressed | Local files only for v1; if needed later, add dedicated URL validator + sandbox |
| DRM content | Licensing complexity, not needed for local files | Not applicable |
| Mobile platforms (Android/iOS) | Desktop-first; different UX paradigms, different window management | Focus Windows; Linux/macOS secondary |
| Audio-only player (just_audio) | fvp handles all media; redundant dependency | Use fvp for audio files too |
| Custom theme system | Single Midnight theme is compile-time const; theming adds complexity for no user value | Keep `ThemeConfig` as single immutable object |
| Plugin/extension system | Over-engineering for a focused player | Hard-code features; refactor when real extension need emerges |
| Media library / file browser | Scope creep; users have Explorer | Playlist panel + file picker + drag-drop is sufficient |
| Video filters / effects (UI) | Kernel supports `VideoEffectType` but UI is premature | Wire `VideoProcessingService` later when kernel is stable |
| System tray integration | Adds complexity; users expect Alt+F4 to close | Standard close behavior |
| Windows context menu ("Open with") | Registry manipulation; installer dependency | File picker + drag-drop covers open flow |
| Mini-player / compact mode | Different layout paradigm; doubles UI surface area | Full player only |
| Casting (Chromecast/DLNA) | Network dependency, protocol complexity | Out of scope entirely |
| Bookmarking system | Breakpoints in playlist already handle resume | `PlaylistItem.positionMs` + persistence |
| Audio visualization | GPU overhead, marginal value for video player | Aurora background provides visual interest in idle state |
| Screenshot capture | Feature creep; Win+Shift+S exists | Not needed |

## Feature Dependencies

```
Frameless Window → Custom Title Bar → Window Controls
                                   → Always-on-Top Pin
                                   → Auto-Hide Title Bar

Fullscreen Toggle → Controls Overlay (auto-hide timing)
                  → Keyboard Handler (ESC exit)

Video Surface (Texture) → Controls Overlay
                        → Progress Bar
                        → Aspect Ratio Service

Drag-and-Drop → Empty State (drag hover animation)
              → Playlist (add dropped files)

Playlist Model → Playlist Panel
              → Play Modes
              → Resume Playback (breakpoints)

Settings Store → Window State Persistence
              → Volume/Mute Persistence

Engine State → Controls Overlay (visibility logic)
            → Aurora Background (pause during playback)
            → Error Banner
            → OSD Overlay

Keyboard Handler → All engine actions (19 shortcuts)
                → Help Dialog (shortcut definitions)
```

## MVP Recommendation

### Phase 1: Window Shell (Critical Foundation)

Build the frameless window, custom title bar, and fullscreen toggle. Everything else depends on having a working window.

1. Frameless window (`setAsFrameless` + `setHasShadow`)
2. Custom title bar (36px, drag, window controls)
3. Window state persistence (size, position, maximized)
4. Fullscreen toggle (manual setSize/setPosition)
5. Always-on-top pin

### Phase 2: Video Playback Core

Wire the existing kernel engine to the UI. User sees video, can control it.

1. Video surface (Texture widget from fvp)
2. Controls overlay with auto-hide
3. Progress bar with seek
4. Volume control + mute
5. Playback speed button
6. OSD overlay for volume feedback
7. Error banner with retry

### Phase 3: Content Management

User can load and manage media files.

1. File open dialog
2. Drag-and-drop support
3. Empty state with aurora background
4. Playlist panel (tabs, reorder, context menu)
5. Play modes (4 modes)
6. Resume playback (breakpoints)

### Phase 4: Polish & Advanced

Differentiators and edge cases.

1. Aspect ratio service (MethodChannel to WM_SIZING)
2. Keyboard shortcuts (19 bindings + help dialog)
3. Media info dialog
4. Equalizer presets
5. Audio track switching
6. Subtitle display + delay adjustment
7. Responsive layout (600dp breakpoint)
8. Localization (EN/ZH)

### Defer to v2

- Video processing UI (kernel exists, UI deferred)
- Custom equalizer sliders (presets sufficient for v1)
- AB loop button (kernel supports, UI can wait)
- Subtitle overlay positioning

## Sources

- D:\player_flutter reference implementation (all features verified in code)
- PROJECT.md requirements and scope definitions
- Desktop media player feature expectations (VLC, MPC-HC, mpv comparison)
