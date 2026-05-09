# Architecture Patterns — Flutter Desktop Media Player

**Domain:** Frameless window media player on Flutter desktop (Windows primary)
**Researched:** 2026-05-09
**Confidence:** HIGH (based on working reference project D:\player_flutter + codebase analysis)

## Recommended Architecture

### System Layering

```
┌─────────────────────────────────────────────────────────────┐
│                      App Shell (main.dart + app.dart)        │
│   Bootstrap: fvp.registerWith() → SharedPreferences prewarm  │
│   → PlatformService.init() → runApp(App())                   │
├─────────────────────────────────────────────────────────────┤
│                    Window Management Layer                    │
│   WindowManagerService (singleton) + AspectRatioService      │
│   Wraps window_manager package + native MethodChannel         │
├─────────────────────────────────────────────────────────────┤
│                    UI Composition Layer                       │
│   PlayerScreen → Stack[VideoSurface, ControlsOverlay,        │
│                    EmptyState, OSD, ErrorBanner]              │
│   CustomTitleBar (36px, drag, auto-hide when playing)        │
├─────────────────────────────────────────────────────────────┤
│                    Business Logic Layer                       │
│   PlaybackController (3 mixins: FileOperations,              │
│     PlaybackNavigator, StateMonitor)                         │
│   VideoProcessingService (7 ValueNotifiers)                  │
├─────────────────────────────────────────────────────────────┤
│                    Engine Abstraction Layer                   │
│   MediaEngine (abstract, 13 ValueNotifiers)                  │
│   FvpEngine (fvp/MDK, FFmpeg + D3D11)                        │
│   Helpers: FvpCallbackHandler, PositionPoller, TrackManager  │
├─────────────────────────────────────────────────────────────┤
│                    Persistence Layer                          │
│   SettingsStore (SharedPreferences) + PlaylistStore (JSON)   │
├─────────────────────────────────────────────────────────────┤
│                    Platform Layer                             │
│   PlatformService (factory singleton) → WindowsPlatformService│
└─────────────────────────────────────────────────────────────┘
```

## Window Management Architecture

### Pattern: Singleton Service with ValueNotifier State

**Recommendation:** WindowManagerService as a singleton wrapping `window_manager` package.

**Why singleton, not DI:**
- Window manager is a global native resource (one window per process)
- `window_manager` package itself uses global state (`WindowManager.instance`)
- No benefit from multiple instances or mock injection at runtime
- Matches `PlatformService.I` pattern already established in codebase

**Reference implementation:** `D:\player_flutter\lib\kernel\window\window_manager_service.dart` (516 lines)

**Key design decisions:**

| Decision | Choice | Rationale |
|----------|--------|-----------|
| State exposure | `ValueNotifier<WindowMode>`, `ValueNotifier<bool>` for isMaximized/isAlwaysOnTop/isResizing | Aligns with project's ValueNotifier pattern, UI rebuilds via ValueListenableBuilder |
| Fullscreen | Manual `setSize` + `setPosition`, NOT `setFullScreen()` | `setFullScreen()` is broken on frameless windows — causes border flash |
| Persistence | 500ms debounce on window geometry writes | Prevents disk thrashing during drag/resize |
| Close safety | `setPreventClose(true)` + `onWindowClose` → persist → `destroy()` | Ensures disk writes complete before process exit |
| Resize detection | `onWindowResize` (start) + `onWindowResized` (end) with debounce | `isResizing` ValueNotifier lets UI degrade rendering (skip BackdropFilter) during resize |
| Bounds check | On restore, verify saved position has >=100px visible on current screen | Handles multi-monitor → single-monitor, DPI changes |

**Lifecycle sequence:**
```
main() → WindowManagerService.init()
  1. windowManager.ensureInitialized()
  2. Load saved geometry from SettingsStore
  3. WindowOptions(size, minSize, center, backgroundColor: black, titleBarStyle: hidden)
  4. waitUntilReadyToShow callback:
     a. setPosition + clampToVisibleBounds
     b. Restore maximize/alwaysOnTop
     c. setPreventClose(true)
     d. _prepareFramelessFirstFrame() — setAsFrameless + setHasShadow + forceRedraw
     e. show() + focus()
     f. Restore fullscreen (if saved)
     g. addListener(this)
  5. Await initCompleter (ensures window is ready before returning)
```

**Fullscreen reentry guard:** `_togglingFullscreen` bool prevents rapid F11 from corrupting ABA state. Optimistic update (set mode first, rollback on failure).

### AspectRatioService — Native MethodChannel Bridge

**Pattern:** Singleton with MethodChannel to native WM_SIZING handler.

**Why MethodChannel, not Flutter-level constraints:**
- Flutter's `AspectRatio` widget constrains child size, not window size
- Native WM_SIZING intercepts the actual Windows resize messages
- Produces pixel-perfect aspect ratio enforcement during drag-resize
- No Flutter rebuild overhead during resize

**Reference:** `D:\player_flutter\lib\kernel\window\aspect_ratio_service.dart` (69 lines)

**Design:**
- `_current` tracks active ratio (0 = unlocked)
- `setAspectRatio(ratio)` invokes MethodChannel, rolls back on failure
- `cycleRatio()` cycles: 16:9 → 4:3 → 21:9 → free → 16:9
- `currentLabel` provides display text for UI

**Integration point:** App listens to `engine.aspectRatio` changes → calls `AspectRatioService.I.setAspectRatio(ratio)`. When no video loaded, locks to 16:9.

## Engine Abstraction Layer

### Pattern: Abstract Interface + Concrete Implementation + Helper Composition

**Recommendation:** MediaEngine as abstract class with ValueNotifier getters, FvpEngine as sole production implementation composed from 3 helpers.

**Why this works:**
- UI never touches fvp/mdk directly — depends only on MediaEngine contract
- Testing: can create FakeEngine implementing MediaEngine
- Helpers decompose FvpEngine's 555 lines into focused units

**Component breakdown:**

| Component | Responsibility | Lines (ref) |
|-----------|---------------|-------------|
| `MediaEngine` | Abstract interface: 13 ValueNotifiers + command methods | ~176 |
| `FvpEngine` | fvp/MDK implementation, owns mdk.Player | ~555 |
| `FvpCallbackHandler` | mdk callback registration, state mapping, main-thread dispatch via SchedulerBinding | ~100 |
| `PositionPoller` | 250ms timer polling for playback position | ~60 |
| `TrackManager` | Audio/subtitle track selection and switching | ~80 |

**ValueNotifier inventory (13 on MediaEngine):**
`textureId`, `state`, `position`, `duration`, `volume`, `isMuted`, `isBuffering`, `subtitleText`, `buffered`, `aspectRatio`, `errorMessage`, `playbackSpeed`, `activeDecoder`

**Critical threading pattern:** mdk callbacks arrive on native threads. `FvpCallbackHandler` uses `SchedulerBinding.addPostFrameCallback` to dispatch state changes to the Dart main thread. This prevents UI corruption from off-thread ValueNotifier mutations.

## UI Composition Patterns

### Pattern: Stack Compositing with Positioned Overlays

**Recommendation:** Single `Stack` with layered children, each responsible for one concern.

**Layer order (bottom to top):**

```
Stack(fit: StackFit.expand)
├── VideoSurface          # Texture widget, always present
├── EmptyState            # Shown when state == idle (aurora bg + open button)
├── ControlsOverlay       # Bottom control bar + OSD + error banner
│   ├── ControlBar        # Glass-morphism transport controls
│   ├── ErrorBanner       # Error messages (positioned above control bar)
│   └── _OsdBubble        # Volume/mute floating pill
└── [DragDrop overlay]    # Optional: visual feedback during file drag
```

**Why Stack, not Overlay/OverlayEntry:**
- Stack children share the same BuildContext (can access Theme, Localization)
- OverlayEntry requires Overlay.of(context) and manual insertion/removal
- Stack is simpler for fixed-position overlays
- RepaintBoundary on each layer isolates repaint regions

### ControlsOverlay — Auto-Hide with Mouse/State Interaction

**Pattern:** AnimationController + Timer-based auto-hide with state-aware behavior.

**Behavior matrix:**

| Engine State | Controls Visibility | Auto-Hide |
|-------------|--------------------|-----------| 
| idle | Always visible | Never |
| loading/playing | Show, then hide after delay | 5s windowed, 3s fullscreen |
| paused/stopped/completed/error | Always visible | Never |

**Gesture handling:**
- Single tap on empty area → hide controls (250ms delay to detect double-tap)
- Double-tap → toggle fullscreen
- Mouse move → show controls + reset hide timer
- Mouse enter → show, mouse exit → schedule hide
- ControlBar buttons have own GestureDetector → win gesture arena, don't trigger hide

**Throttle:** `_hoverThrottle = 100ms` prevents setState on every pixel of mouse movement.

### GlassContainer — Resize-Aware BackdropFilter

**Pattern:** Conditional BackdropFilter that degrades during window resize.

**Why:** `BackdropFilter` is expensive on Windows during resize (re-renders blur every frame). `isResizing` ValueNotifier from WindowManagerService triggers fallback to plain color.

**Implementation:**
```dart
ValueListenableBuilder<bool>(
  valueListenable: PlatformService.I.isResizing,
  builder: (_, resizing, child) {
    if (resizing) return ClipRRect(child: child); // No blur
    return ClipRRect(
      child: BackdropFilter(filter: blur, child: child),
    );
  },
)
```

### CustomTitleBar — 36px Frameless Title Bar

**Pattern:** GestureDetector for drag + double-tap maximize, with auto-hide when playing.

**Key details:**
- Height: 36px (Win11 standard 32px + 4px touch target)
- No BackdropFilter (pure color + border line) — eliminates resize jitter
- `onPanStart: (_) => wm.startDragging()` for window drag
- `onDoubleTap: () => wm.toggleMaximize()`
- Auto-hide: `AnimatedSlide(offset: playing ? Offset(0, -1) : Offset.zero)`
- Window controls: minimize, maximize, close, always-on-top pin, aspect ratio cycle

### VideoSurface — Texture Rendering

**Pattern:** `FittedBox(fit: BoxFit.contain)` wrapping `Texture(textureId: id)`.

**Critical:** Aspect ratio is applied via `SizedBox` dimensions, not Flutter's `AspectRatio` widget. This ensures the texture scales correctly within the available space.

```dart
FittedBox(
  fit: BoxFit.contain,
  child: SizedBox(
    width: ratio >= 1 ? ratio * 1000 : 1000,
    height: ratio >= 1 ? 1000 : 1000 / ratio,
    child: Texture(textureId: id),
  ),
)
```

**Scroll wheel:** `Listener(onPointerSignal)` for volume control (not GestureDetector — doesn't consume the event).

## Data Flow

### Playback Request Path

```
User action (file picker / drag-drop / keyboard)
  → FileOperations.openAndPlay(path)
    → PathValidator.validate(path) [security check]
    → Playlist.add(path) [returns index]
    → PlaybackNavigator.playIndex(idx)
      → engine.open(path) [FvpEngine sets media, prepare(), waits for texture]
      → FvpCallbackHandler maps mdk state → MediaEngine.state ValueNotifier
      → PositionPoller.start() [250ms timer]
      → engine.play()
  → UI rebuilds via ValueListenableBuilder on engine.state, position, duration, etc.
```

### Aspect Ratio Flow

```
engine.open(path) completes
  → engine.aspectRatio.value updates (video dimensions detected)
  → App._onAspectRatioChanged listener fires
  → AspectRatioService.I.setAspectRatio(ratio)
  → MethodChannel → native WM_SIZING handler
  → Window resize constrained to video ratio
```

### Window State Persistence Flow

```
Window resize/move event
  → WindowManagerService.onWindowResized() / onWindowMoved()
  → _schedulePersist() [500ms debounce]
  → _persistWindowState()
    → Future.wait([getSize, getPosition, isMaximized, isFullScreen])
    → SettingsStore.saveWindowGeometry(...)
  → On exit: onWindowClose() → persist → destroy()
```

### Auto-Advance Flow

```
mdk.MediaStatus.end detected
  → FvpCallbackHandler sets state = MediaState.completed
  → StateMonitor._onStateChanged()
  → Playlist.mode check:
    - loopSingle → replay current
    - otherwise → playNext()
  → PlaybackNavigator.playNext() → Playlist.peekNext() → playIndex()
```

## Suggested Build Order

Based on dependency analysis between components:

### Phase 1: Window Shell (no video dependencies)

**Build these first — they have no dependency on engine/UI:**

1. **WindowManagerService** — singleton, init lifecycle, frameless setup, fullscreen toggle, persistence
   - Dependencies: window_manager package, SettingsStore (existing)
   - Blocks: CustomTitleBar, GlassContainer resize-awareness

2. **AspectRatioService** — MethodChannel bridge, ratio cycling
   - Dependencies: WindowManagerService (for isResizing)
   - Blocks: VideoSurface integration, title bar ratio button

3. **CustomTitleBar** — 36px bar with window controls
   - Dependencies: WindowManagerService (startDragging, toggleMaximize, minimize, close)
   - Blocks: PlayerScreen layout

### Phase 2: Video Surface (engine integration)

4. **VideoSurface** — Texture rendering with aspect ratio
   - Dependencies: MediaEngine (textureId, aspectRatio ValueNotifiers)
   - Blocks: PlayerScreen, ControlsOverlay

5. **PlayerScreen** — Main composition layout
   - Dependencies: CustomTitleBar, VideoSurface, ControlsOverlay, EmptyState
   - Blocks: Everything wired together

### Phase 3: Controls & Overlays

6. **ControlsOverlay** — auto-hide control bar with state-aware behavior
   - Dependencies: MediaEngine state, AnimationController
   - Blocks: Final polish

7. **GlassContainer** — resize-aware BackdropFilter
   - Dependencies: WindowManagerService.isResizing
   - Blocks: ControlBar, OSD, EmptyState glass effects

8. **EmptyState** — idle screen with aurora background
   - Dependencies: MediaEngine.state, GlassContainer
   - Blocks: DropHandler visual feedback

### Phase 4: Input & Polish

9. **DropHandler** — desktop_drop file drag-and-drop
   - Dependencies: PathValidator (existing)
   - Blocks: File opening UX

10. **KeyboardHandler** — 14-key bindings (existing, needs wiring)
    - Dependencies: MediaEngine, WindowManagerService
    - Blocks: Keyboard UX

### Dependency Graph

```
WindowManagerService ──→ AspectRatioService
         │                      │
         ├──→ CustomTitleBar    ├──→ VideoSurface
         │                      │
         ├──→ GlassContainer ───┤
         │                      │
         └──→ PlayerScreen ◄────┘
                │
                ├──→ ControlsOverlay
                ├──→ EmptyState
                └──→ DropHandler
```

**Critical path:** WindowManagerService → CustomTitleBar → PlayerScreen → ControlsOverlay

**Parallel track:** AspectRatioService → VideoSurface (can be built alongside window shell)

## Anti-Patterns to Avoid

### 1. Using setFullScreen() on Frameless Windows

**What:** Calling `windowManager.setFullScreen(true)` on a frameless window.
**Why bad:** Causes border flash, incorrect sizing, inconsistent state on Windows.
**Instead:** Manual `setSize(screenSize)` + `setPosition(Offset.zero)` + `setHasShadow(false)`.

### 2. BackdropFilter Without Resize Guards

**What:** Always rendering BackdropFilter during window resize.
**Why bad:** GPU usage spikes to 100% on Windows, causes visible lag/jank.
**Instead:** Check `isResizing` ValueNotifier, skip BackdropFilter during resize, use plain color fallback.

### 3. Persisting Window Geometry on Every Event

**What:** Writing to SharedPreferences on every `onWindowResize`/`onWindowMove` callback.
**Why bad:** Hundreds of disk writes during a single drag operation.
**Instead:** 500ms debounce timer, merge consecutive events into single write.

### 4. Mixing Window State with Playback State

**What:** Putting fullscreen/maximize/alwaysOnTop state in the engine or controller.
**Why bad:** Window concerns are orthogonal to playback — coupling creates unnecessary rebuilds.
**Instead:** WindowManagerService owns window state independently. UI subscribes to both separately.

### 5. OverlayEntry for In-App Overlays

**What:** Using `OverlayEntry` for controls, OSD, error banners.
**Why bad:** Requires manual insertion/removal, loses BuildContext for Theme/Localization, complex lifecycle.
**Instead:** Stack with Positioned children — simpler, context-aware, animation-friendly.

### 6. Direct window_manager Access from UI

**What:** Widgets calling `windowManager.minimize()` directly.
**Why bad:** Bypasses state management, no error handling, no persistence coordination.
**Instead:** All window operations go through WindowManagerService, which handles errors + state + persistence.

## Scalability Considerations

| Concern | Current Scale (single window) | If Multi-Window |
|---------|-------------------------------|-----------------|
| WindowManagerService singleton | Works perfectly | Would need per-window instances |
| ValueNotifier state | 13 on engine + 7 on video processing + 4 on window | Would need scoped state per window |
| SharedPreferences | Single instance, prewarmed | Thread-safe, works across isolates |
| MethodChannel | Single channel | Would need per-window channel routing |

**Assessment:** Single-window architecture is correct for a media player. No multi-window needed.

## Sources

- **Reference project:** `D:\player_flutter` — full working implementation, all patterns verified in production use
- **Current codebase:** `D:\simple_player_flutter` — kernel complete, architecture documented in `.planning/codebase/ARCHITECTURE.md`
- **window_manager package:** pub.dev/window_manager — frameless window management for Flutter desktop
- **fvp package:** pub.dev/fvp — MDK/FFmpeg-based video player for Flutter
- **desktop_drop package:** pub.dev/desktop_drop — OS-level file drag-and-drop

---
*Architecture research: 2026-05-09*
