# Phase 1: Window Management Foundation - Context

**Gathered:** 2026-05-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Build self-managed window control via MethodChannel + Win32 C++ FFI. Deliver: fullscreen, always-on-top, resize, position, frameless window with custom title bar, and fix error handling anti-patterns. Windows primary implementation with macOS/Linux stubs deferred to Phase 4.

</domain>

<decisions>
## Implementation Decisions

### MethodChannel Protocol Design
- **D-01:** Single MethodChannel `com.simple_player/window` with string command dispatch (not multiple channels)
- **D-02:** EventChannel `com.simple_player/window_events` for streaming window events from C++ to Dart
- **D-03:** PlatformException with error codes `{code: string, message: string}` for error passing
- **D-04:** C++ handler files in `windows/runner/` directory (window_channel.cpp/h), not separate directory
- **D-05:** 7 core commands: `setFullscreen(bool)`, `setAlwaysOnTop(bool)`, `setSize(w,h)`, `setPosition(x,y)`, `setMinSize(w,h)`, `setFrameless(bool)`, `getTitleBarBounds()`
- **D-06:** 5 event types: `onResize(Size)`, `onMove(Position)`, `onFullscreenChange(bool)`, `onClose`, `onMinimize`
- **D-07:** WindowService class wraps MethodChannel calls + EventChannel listener, exposes `ValueNotifier<WindowState>` for UI integration via ValueListenableBuilder

### Frameless Window Implementation
- **D-08:** WM_NCCALCSIZE (return 0) approach for frameless window, not SetWindowLong WS_CAPTION removal
- **D-09:** WM_NCHITTEST for 8-direction resize edges, 8px edge width
- **D-10:** WM_NCHITTEST HTCAPTION return for title bar drag region
- **D-11:** Standard 3 buttons (minimize/maximize/close) on right side, flat/immersive style — NOT GlassIconButton style
- **D-12:** Double-click title bar toggles maximize/restore (Windows standard behavior)
- **D-13:** Title bar as independent layer above video content (not embedded in video Stack)
- **D-14:** Title bar always visible, no auto-hide
- **D-15:** Transparent title bar, semi-transparent background on hover
- **D-16:** Title bar height 32px (Windows 11 standard)
- **D-17:** Fullscreen mode hides title bar
- **D-18:** CustomTitleBar widget independent of ControlsOverlay (separate widget, separate visibility logic)
- **D-19:** Window minimum size: larger than 640x360 in 16:9 ratio
- **D-20:** Default initial window size: 960x540 (540p)
- **D-21:** Windows 11 native rounded corners via DWMWA_WINDOW_CORNER_PREFERENCE = DWMWCP_DEFAULT
- **D-22:** Use existing Flutter app icon for taskbar (no custom icon)
- **D-23:** Title bar theme follows app theme (Tokens.*) for cross-platform consistency — no DWM dark mode API
- **D-24:** Window centered on every startup (no position persistence)
- **D-25:** No visible window border (fully frameless)
- **D-26:** No window shadow
- **D-27:** Title bar displays app name only, not current file name
- **D-28:** Aurora background when no video is playing (existing behavior preserved)
- **D-29:** No window state persistence — no save/restore of position, size, fullscreen, or always-on-top
- **D-30:** Free window resize, no aspect ratio lock
- **D-31:** Preserve Windows snap layout functionality

### Error Handling (PERF-02)
- **D-32:** Replace all `catch (_)` and `on Object catch` with `on Exception catch (e)` + logger
- **D-33:** Fix scope: 4 known locations + global search for additional occurrences
- **D-34:** Use `logger` package (already a dependency) for error logging, not debugPrint

### C++ Integration
- **D-35:** Register MethodChannel handler in `FlutterWindow::OnCreate` (alongside existing DPI/dark mode setup)

### Dart Architecture
- **D-36:** WindowService placed at `lib/kernel/bridge/window_service.dart` (kernel layer, no UI dependency)

### Title Bar Widget
- **D-37:** CustomTitleBar at `lib/ui/player/custom_title_bar.dart` as independent file

### Claude's Discretion
- WindowState data class structure (which fields, ValueNotifier wrapping)
- C++ error code enum values
- EventChannel event map structure
- WindowService initialization sequence within StartupCoordinator

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Architecture & Stack
- `.planning/codebase/ARCHITECTURE.md` — 3-layer architecture (Kernel/Features/UI), state management patterns, cross-layer dependency rules
- `.planning/codebase/STACK.md` — Flutter 3.44 beta, fvp 0.36.2, C++17 Windows runner, D3D11 rendering
- `.planning/codebase/INTEGRATIONS.md` — fvp/MDK engine integration, Win32 runner structure, startup sequence

### Requirements & Concerns
- `.planning/REQUIREMENTS.md` — WIN-01, WIN-02, WIN-03, PERF-02, PLATFORM-01 requirement specs
- `.planning/codebase/CONCERNS.md` — #1 platform files deleted, #3 catch(_) swallows errors, #4 on Object catch
- `.planning/ROADMAP.md` — Phase 1 goal, success criteria, requirement traceability

### Windows Runner (existing C++ code)
- `windows/runner/flutter_window.cpp` — FlutterWindow class, OnCreate, existing DPI/dark mode setup
- `windows/runner/flutter_window.h` — FlutterWindow header
- `windows/runner/main.cpp` — WinMain, window creation
- `windows/runner/CMakeLists.txt` — Build configuration for runner

### Existing Dart Code (patterns to follow)
- `lib/kernel/engine/media_engine.dart` — Abstract interface pattern (model for PlatformWindow)
- `lib/kernel/engine/fvp_engine.dart` — `_guardedAction` error handling pattern, ValueNotifier usage
- `lib/features/player/services/playback_controller.dart` — Service composition pattern
- `lib/ui/player/controls_overlay.dart` — Auto-hide pattern, widget caching
- `lib/ui/player/player_screen.dart` — Stack compositing, layout structure
- `lib/ui/shared/glass_container.dart` — Glassmorphism components (NOT for title bar, but for reference)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ValueNotifier<WindowState>` pattern: same as engine state notifiers (position, volume, etc.)
- `ValueListenableBuilder` widget: standard pattern for reactive UI updates
- `Tokens.*` design system: all visual constants for title bar styling
- `logger` package: already a dependency, use for error logging
- `AuroraBackground` widget: existing empty-state background

### Established Patterns
- Abstract interface → concrete implementation: MediaEngine/FvpEngine pattern applies to PlatformWindow
- Service composition: PlaybackController composes sub-modules — WindowService should follow same pattern
- `_guardedAction` in FvpEngine: disposed-safe error handling — consider similar pattern for WindowService
- ValueNotifier + ValueListenableBuilder: standard reactive pattern throughout codebase

### Integration Points
- `StartupCoordinator`: window initialization must fit into existing phase-based init sequence
- `PlayerScreen`: CustomTitleBar layers above video in the Stack
- `ControlsOverlay`: independent from CustomTitleBar but shares screen space
- `SettingsStore`: window geometry fields exist but will NOT be used (no persistence decision)

</code_context>

<specifics>
## Specific Ideas

- Title bar buttons: flat/immersive style, NOT the GlassIconButton glassmorphism look. User explicitly rejected GlassIconButton style for title bar.
- Window always centered on startup — no position memory. Simple and predictable.
- No window state persistence at all — simplifies WIN-02 significantly (just center + defaults on startup)
- User chose "每次居中" (center every time) — no saved position restoration needed
- User chose 540p (960x540) as default window size — smaller than typical media player defaults

</specifics>

<deferred>
## Deferred Ideas

- DPI change events: user chose not to include onDpiChange in EventChannel (deferred to future if needed)
- Display change events: user chose not to include onDisplayChange for multi-monitor scenarios
- Full implementation of macOS/Linux stubs: deferred to Phase 4 (PLATFORM-02)

</deferred>

---

*Phase: 01-Window Management Foundation*
*Context gathered: 2026-05-28*
