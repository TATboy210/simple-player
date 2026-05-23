# Architecture Research: Flutter Desktop Player Refactoring

**Domain:** Desktop media player (Flutter + fvp/MDK + Win32 FFI)
**Researched:** 2026-05-23
**Confidence:** HIGH (based on direct codebase analysis, not external sources)

---

## 1. Platform Service Abstraction (WindowService Triplication)

### Current State

Three near-identical files, each ~280-300 lines:

| File | Lines | Platform-Specific Code |
|------|-------|----------------------|
| `window_service.dart` | 302 | `FullscreenController` (Win32 FFI), force layout after frameless, `windowButtonVisibility: false` |
| `macos_window_service.dart` | 286 | `windowManager.setFullScreen()`, `windowButtonVisibility: true` (traffic lights), `AspectRatioService.I.unlock()` before fullscreen |
| `linux_window_service.dart` | 279 | `windowManager.setFullScreen()`, `windowButtonVisibility: false` |

**What is actually identical (90%+):**
- `init()`: EnsureInitialized, loadAndClamp, WindowOptions, waitUntilReadyToShow, setMinimumSize, setPosition, maximize, setPreventClose, setAsFrameless, show, focus, addListener
- `dispose()`: Disposed guard, wait for initCompleter, flush persistence, dispose state/persistence
- `minimize()`, `toggleMaximize()`, `close()`, `startDragging()`, `toggleAlwaysOnTop()`: Identical try-catch patterns
- All `_WindowListener` callbacks: Identical except fullscreen enter/leave
- All reactive state delegation to `WindowStateService`
- All lifecycle guards: `_initialized`, `_disposed`, `_initCompleter`, `_togglingFullscreen`, `_closing`

**What actually differs (3 places):**
1. `init()` WindowOptions: `windowButtonVisibility` (false vs true for macOS traffic lights)
2. `init()` after frameless: Windows calls `FullscreenController.restoreThickFrame()` + force layout
3. `toggleFullscreen()`/`exitFullscreen()`: Windows uses `FullscreenController.enter()/exit()`, macOS/Linux use `windowManager.setFullScreen()`, macOS also unlocks aspect ratio before entering

### Recommended Approach: Base Mixin with Platform Hooks

Use a mixin (not abstract class) because the platform services already compose `WindowStateService` and `WindowPersistenceService` -- a mixin lets them keep their field ownership while sharing logic.

```
mixin WindowServiceBase implements WindowBridge {
  // Provides: _initialized, _disposed, _initCompleter, _togglingFullscreen, _closing
  // Provides: _state, _persistence (from WindowStateService, WindowPersistenceService)
  // Provides: all reactive state delegation
  // Provides: minimize, toggleMaximize, close, startDragging, toggleAlwaysOnTop
  // Provides: dispose

  // Platform hooks (override in concrete classes):
  bool get windowButtonVisibility;          // macOS: true, others: false
  Future<void> onAfterFrameless();          // Windows: restoreThickFrame + force layout
  Future<void> platformToggleFullscreen(bool entering);
  Future<void> platformExitFullscreen();
}
```

**Concrete implementations shrink to ~40-60 lines each:**
- `WindowsWindowService with WindowServiceBase`: Override `onAfterFrameless` (FullscreenController), `platformToggleFullscreen` (FullscreenController), `windowButtonVisibility` (false)
- `MacosWindowService with WindowServiceBase`: Override `platformToggleFullscreen` (setFullScreen + aspect ratio unlock), `windowButtonVisibility` (true)
- `LinuxWindowService with WindowServiceBase`: Override `platformToggleFullscreen` (setFullScreen), `windowButtonVisibility` (false)

**The `_WindowListener` also deduplicates:** Move to the base mixin, override only `onWindowEnterFullScreen`/`onWindowLeaveFullScreen` if needed (currently identical across all three).

### Build Order

1. Extract `WindowServiceBase` mixin from `WindowService` (Windows is the most complex, use as source)
2. Refactor `WindowService` to use `WindowServiceBase` -- verify all existing tests pass
3. Refactor `MacosWindowService` and `LinuxWindowService`
4. Delete duplicated code

---

## 2. Mixin Composition Patterns

### Current Pattern (PlaybackController)

```
PlaybackController with FileOperations, PlaybackNavigator, StateMonitor
```

Each mixin declares abstract members that the controller satisfies:
```dart
mixin FileOperations {
  MediaEngine get engine;        // satisfied by PlaybackController.engine
  Playlist get playlist;         // satisfied by PlaybackController.playlist
  Future<void> playIndex(int index);  // satisfied by PlaybackNavigator.playIndex
  void savePlaylist();           // satisfied by PlaybackController.savePlaylist
}
```

**Strengths of this pattern:**
- Clear separation of concerns: file ops, navigation, state monitoring
- Each mixin is independently testable (via a test class that satisfies abstract members)
- The controller is small (42 lines) -- it just wires dependencies

**Risks identified:**
- Implicit coupling: mixins share mutable state through abstract member contracts, not explicit interfaces
- `openGeneration` in `PlaybackNavigator` is accessed across mixin boundaries
- Order-dependent initialization: `StateMonitor.init()` must be called after engine is set

### Recommendation: Keep This Pattern, Improve Documentation

The mixin composition is well-structured. The 3-mixin split maps to real domain boundaries (files, navigation, lifecycle). Do NOT refactor to separate classes -- the current pattern avoids callback hell and keeps the orchestrator thin.

**Improvements:**
1. Add a `PlaybackControllerContract` abstract class documenting all shared members
2. Move `openGeneration` to the controller (not a mixin) since it's cross-cutting state
3. Document the initialization order requirement in the controller

---

## 3. Dependency Injection Without a DI Framework

### Current Patterns

The codebase uses 3 distinct DI patterns:

**Pattern A: Static Injection (WindowBridge)**
```dart
abstract class WindowBridge {
  static WindowBridge? _instance;
  static WindowBridge get I => _instance ?? _noop;
  static void inject(WindowBridge impl) => _instance = impl;
}
```
Used by: `WindowBridge`, consumed everywhere via `WindowBridge.I`

**Pattern B: Private Constructor Singleton (AspectRatioService)**
```dart
class AspectRatioService {
  AspectRatioService._();
  static final AspectRatioService I = AspectRatioService._();
}
```
Used by: `AspectRatioService`, `ThumbnailService`, `OsdService`

**Pattern C: Constructor Injection (PlaybackController, services)**
```dart
PlaybackController({required this.engine, required this.playlist, ...})
VideoProcessingService(this._engine, {required AppSettings initialSettings})
```
Used by: `PlaybackController`, `VideoProcessingService`, `WindowPersistenceService`, `WindowGeometryStore`

### Recommendation: Standardize on Constructor Injection, Keep WindowBridge Static

**Constructor injection** (Pattern C) is the right default:
- Explicit dependencies, easy to test (pass fakes)
- No hidden global state
- Works perfectly with the existing `App.initState()` wiring

**Keep WindowBridge static injection** (Pattern A) because:
- Window is a true application singleton (one window per process)
- Used in 15+ places across UI layer -- constructor threading would create massive callback drilling
- The `NoopWindowBridge` fallback provides safe degradation
- Already testable via `WindowBridge.inject(fake)`

**Convert singletons to constructor injection** (Pattern B -> C):
- `ThumbnailService`: Static mutable state prevents testing. Convert to instance with `ThumbnailProvider` injected.
- `OsdService`: Same issue. Convert to instance, pass to widgets that need it.
- `AspectRatioService`: Borderline. It depends on `windowManager` which is a global. Keep as singleton but add an injectable `WindowManagerAdapter` for testing.

### Testing Implications

| Service | Current Testability | After Refactor |
|---------|-------------------|---------------|
| PlaybackController | GOOD (constructor injection) | GOOD |
| WindowBridge | GOOD (static inject) | GOOD |
| ThumbnailService | BAD (static state leaks) | GOOD (instance) |
| OsdService | BAD (static singleton) | GOOD (instance) |
| AspectRatioService | BAD (depends on windowManager global) | OK (adapter pattern) |
| FvpEngine | GOOD (FakeEngine exists) | GOOD |

---

## 4. Testing Architecture for Platform-Dependent Code

### Current State

- 32 test files exist
- `FakeEngine` (354 lines) implements `MediaEngine` -- comprehensive, hand-written, with call tracking
- `_FakeWindowBridge` in test files -- minimal, no call tracking
- No integration tests, no golden tests
- `FullscreenController` untestable (requires Win32 HWND)
- `WindowService` untestable (requires `window_manager` plugin)

### Recommended Testing Strategy

**Layer 1: Abstract Interface Tests (test the contract, not the platform)**

Test `WindowBridge` behavior through `NoopWindowBridge` or a `FakeWindowBridge`:
- Already partially done in `window_service_test.dart`
- Expand: test state transitions (windowed -> fullscreen -> windowed), debounce timing, close guard

**Layer 2: Service Logic Tests (extract platform-independent logic)**

`WindowStateService` and `WindowPersistenceService` are already separated and testable:
- `WindowStateService`: Test resize debounce timing, state transitions
- `WindowPersistenceService`: Test debounce, in-flight guard, flush semantics
- These are currently untested -- add tests immediately

**Layer 3: Platform Adapter Tests (mock the platform calls)**

For `FullscreenController`: Create a `Win32Adapter` interface:
```dart
abstract class Win32Adapter {
  int getWindowLongPtr(int hwnd, int index);
  void setWindowLongPtr(int hwnd, int index, int value);
  int getForegroundWindow();
  // ...
}
```
Then test `FullscreenController` logic with a fake adapter. The real adapter is a thin FFI wrapper.

**Layer 4: Integration Tests (require real platform)**

Only for: fullscreen toggle on actual Windows, window geometry persistence round-trip, drag-and-drop file handling. Mark with `@Tags(['integration'])` and skip in CI.

### Mocking Strategy

Use hand-written fakes over mockito for:
- `MediaEngine` (already done: `FakeEngine`)
- `WindowBridge` (expand existing `_FakeWindowBridge` with call tracking)
- `Win32Adapter` (new, for FullscreenController tests)
- `ThumbnailProvider` (new, for ThumbnailService tests)

Use mockito only for:
- `SharedPreferences` (complex interface, many methods)
- `window_manager` `WindowManager` (external package, stable API)

---

## 5. Legacy Code Removal Strategies

### Dead Code Identified

| File | Lines | Status | Action |
|------|-------|--------|--------|
| `lib/models/playlist_item.dart` | 26 | Dead -- superseded by `lib/kernel/models/playlist_item.dart` (72 lines with timestamp/position/duration) | DELETE |
| `lib/kernel/services/macos_thumbnail_provider.dart` | ~20 | Stub returning null | Keep but add `debugPrint` warning |
| `lib/kernel/services/subtitle_service.dart:60,65` | 2 TODOs | Non-functional features | Remove from public API or implement |

### Removal Strategy

**For `lib/models/playlist_item.dart`:**
1. Verify no imports exist (grep for `import.*models/playlist_item` excluding `kernel/models`)
2. Delete the file
3. Run `flutter analyze` to confirm no breakage

**For stub providers:**
- Do NOT delete -- they serve as platform fallback documentation
- Add `debugPrint('[ThumbnailProvider] macOS thumbnails not implemented')` so users know it's expected
- Keep in the platform switch in `ThumbnailService._provider`

**For unused abstractions:**
- `ThumbnailProvider` abstract class: Keep (needed for cross-platform thumbnail extraction)
- `NoopThumbnailProvider`: Keep (safety fallback)

### Prevention

Add a CI check: `dart analyze --fatal-infos` catches unused imports. Add a custom lint rule or periodic audit for dead files in `lib/models/` (the old location).

---

## Component Boundaries (Post-Refactoring)

```
┌─────────────────────────────────────────────────────────────────┐
│                         UI Layer                                 │
│  PlayerScreen, ControlsOverlay, PlaylistPanel, SettingsPanel    │
│  Consumes: PlaybackController, MediaEngine, WindowBridge.I      │
├──────────────────────────┬──────────────────────────────────────┤
│    Service Layer         │         Window Layer                 │
│  PlaybackController      │  WindowServiceBase (mixin)           │
│  (3 mixins)              │  Windows/Mac/Linux (40-60 lines)     │
│  VideoProcessingService  │  FullscreenController (Win32 FFI)    │
│  ThumbnailService (inst) │  WindowStateService (shared)         │
│  OsdService (inst)       │  WindowPersistenceService (shared)   │
├──────────────────────────┴──────────────────────────────────────┤
│                       Kernel Layer                               │
│  MediaEngine (abstract)  Playlist  Persistence  Models           │
│  FvpEngine (concrete)    Scanner   SettingsStore                 │
│  AspectRatioService      PathValidator                           │
├─────────────────────────────────────────────────────────────────┤
│                    Bridge / Native Layer                          │
│  WindowBridge (abstract + static inject)                         │
│  flutter_window.cpp (C++ Win32 MethodChannel)                    │
└─────────────────────────────────────────────────────────────────┘
```

### Data Flow (Unchanged)

1. **Playback:** User -> FilePicker/Drop -> `PlaybackController.openAndPlay()` -> `PlaybackNavigator.playIndex()` -> `FvpEngine.open()` -> `PositionPoller` -> `ValueNotifier` -> UI rebuilds
2. **Window:** User -> TitleBar button -> `WindowBridge.I.minimize()` -> `WindowService` -> `window_manager` / `FullscreenController`
3. **Settings:** User -> SettingsPanel -> deferred state -> Apply -> `SettingsStore.save()` -> `VideoProcessingService`

---

## Suggested Build Order for Architecture Refactoring

### Phase 1: Window Service Deduplication (ARCH-01)
- Extract `WindowServiceBase` mixin
- Refactor all 3 platform services
- ~200 lines removed, single source of truth for lifecycle/error handling

### Phase 2: Test Infrastructure for Window Layer (TEST-03)
- Create `FakeWindowBridge` with call tracking (expand existing)
- Add `Win32Adapter` interface for `FullscreenController` testability
- Add tests for `WindowStateService`, `WindowPersistenceService`, `GeometryStore`

### Phase 3: Singleton Cleanup (ARCH-02)
- Convert `ThumbnailService` to instance-based
- Convert `OsdService` to instance-based
- Wire through constructor injection in `App.initState()`

### Phase 4: Legacy Removal (ARCH-03)
- Delete `lib/models/playlist_item.dart`
- Audit for other dead code

### Phase 5: Settings Panel Split (CONCERNS)
- Split `settings_card.dart` (754 lines) into 3 files

---

## Pitfalls to Avoid

| Pitfall | Why It Happens | Prevention |
|---------|---------------|------------|
| Over-abstracting WindowService | Temptation to create a full `PlatformWindowAdapter` interface | Use mixin -- the platforms share 90% of code, not 50% |
| Breaking the mixin chain | Modifying one mixin without checking abstract member contracts | Run full test suite after any mixin change |
| Losing NoopWindowBridge safety | Removing the fallback during DI refactor | Always keep `NoopWindowBridge` as default |
| Testing through platform calls | Trying to unit test `FullscreenController` with real Win32 | Extract `Win32Adapter` interface, test logic only |
| Premature state management migration | Tempting to switch to Riverpod/Bloc during refactor | Stay with ValueNotifier -- optimize within existing pattern |

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Window deduplication approach | HIGH | Directly analyzed all 3 files, diff is clear |
| Mixin composition recommendation | HIGH | Analyzed all 3 mixins + controller, pattern is sound |
| DI standardization | HIGH | Mapped all 4 DI patterns in codebase, recommendations are conservative |
| Testing strategy | MEDIUM | FakeEngine is proven, but Win32Adapter pattern is untested in this codebase |
| Legacy removal | HIGH | Dead model confirmed via file comparison |

---

*Architecture research: 2026-05-23*
