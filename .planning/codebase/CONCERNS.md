# Technical Concerns

**Analysis Date:** 2026-05-07

## Legacy / Dead Code

### Duplicate Root-Level Modules

**Files:**
- `lib/models/playlist_item.dart` — older version missing `timestamp`, `positionMs`, `durationMs` fields
- `lib/utils/time_utils.dart` — identical copy of `lib/kernel/utils/time_utils.dart`

**Risk:** Confusion about which version to import. Kernel tests use kernel versions; root-level versions are unused but committed.

**Fix:** Delete both root-level files. Update any imports to use `lib/kernel/` paths.

### test/unit/ Misalignment

**Files:**
- `test/unit/platform_service_test.dart`
- `test/unit/perf/startup_parallel_init_test.dart`
- `test/unit/kernel/engine/media_engine_extension_test.dart`

**Risk:** These tests live outside the `test/kernel/` mirror structure. Discoverability suffers.

**Fix:** Relocate to `test/kernel/` to match the source tree.

## Architectural Concerns

### Static Singletons

**Affected:** `SettingsStore`, `WindowManagerService`, `AspectRatioService`, `PlatformService`

**Pattern:**
```dart
class WindowManagerService {
  WindowManagerService._();
  static final WindowManagerService I = WindowManagerService._();
}
```

**Risk:** Prevents running multiple instances. Unit tests require `@visibleForTesting reset()` calls in setUp/tearDown. Forgetting to reset causes test pollution.

**Mitigation:** Existing singletons have `reset()` methods. New services should prefer constructor injection.

### Global Mutable State

**Locations:**
- `SettingsStore._cachedPrefs` — prewarmed SharedPreferences instance
- `MotionUtils._reducedMotion` — static bool, set once at startup
- `PlaybackController.currentFileName` — shared ValueNotifier across mixins

**Risk:** Hidden dependencies between tests. Test order can affect outcomes.

**Mitigation:** `SettingsStore.resetPrewarm()` in setUp/tearDown. `MotionUtils` is set-once.

### No Centralized State Store

**Pattern:** Each service owns its own `ValueNotifier` instances. No single source of truth.

**Risk:** State consistency depends on correct listener wiring. Missed updates = stale UI.

**Mitigation:** Kernel isolation reduces surface area. `PlaybackController` orchestrates cross-service state.

## Concurrency Risks

### openGeneration Counter

**Location:** `lib/kernel/services/playback_navigator.dart:31`

**Pattern:** Incrementing integer counter to discard stale async open requests.

**Risk:** If `openGeneration` overflows (unlikely with Dart's int range), stale requests could execute. More practically, if a new open starts before the previous one's `prepare()` timeout (10s), the old request is discarded but the native mdk player may still be in a transitional state.

**Mitigation:** `_disposed` flag in `FvpEngine` provides a second safety net.

### Debounce Timer Races

**Locations:**
- `PlaylistStore` — 300ms debounce for persistence
- `WindowManagerService` — 500ms debounce for window state persistence
- `VideoProcessingService` — 50ms debounce for effect persistence

**Risk:** Rapid mutations can cause the debounce timer to reset indefinitely, delaying persistence. If the app exits during the debounce window, unsaved state is lost.

**Mitigation:** `PlaylistStore._flush()` uses atomic write (`.tmp` rename). `WindowManagerService._persistInFlight` Completer prevents concurrent writes.

### Native Thread Callbacks

**Location:** `lib/kernel/engine/fvp_callback_handler.dart:36`

**Pattern:** mdk callbacks arrive on native threads, dispatched to Dart main thread via `SchedulerBinding.instance.addPostFrameCallback`.

**Risk:** If the engine is disposed between callback arrival and main-thread dispatch, the callback executes on a disposed engine.

**Mitigation:** `_disposed` guard in `_guardedAction()`. Callbacks check state before acting.

## Performance Concerns

### Position Poller Interval

**Location:** `lib/kernel/engine/position_poller.dart`

**Pattern:** 250ms `Timer.periodic` polling playback position.

**Risk:** On low-end machines or during heavy I/O, timer jitter could cause UI stutter. 4 updates/sec may feel laggy for seek bar.

**Mitigation:** `ValueNotifier` only notifies listeners when the value actually changes (Dart's built-in optimization). Could reduce to 100ms if needed.

### SharedPreferences Prewarm

**Location:** `lib/kernel/persistence/settings_store.dart`

**Pattern:** `SharedPreferences.getInstance()` called early in `main()` and cached.

**Risk:** If prewarm fails silently, all subsequent reads return defaults. No retry mechanism.

**Mitigation:** `load()` has try-catch with fallback to `AppSettings()` defaults.

### Playlist JSON Serialization

**Location:** `lib/kernel/persistence/playlist_store.dart`

**Pattern:** Full playlist serialized to JSON on every mutation (debounced 300ms).

**Risk:** Large playlists (1000+ items) could cause noticeable serialization delay.

**Mitigation:** Debounce prevents serialization on every keystroke. Atomic write prevents corruption.

## Security Concerns

### Path Traversal

**Location:** `lib/kernel/services/path_validator.dart`

**Pattern:** Validates paths against extension whitelist and detects `..` traversal.

**Coverage:** Applied at `FileOperations.openAndPlay()` and `PlaybackNavigator.playIndex()`.

**Risk:** If a malicious playlist file is loaded, paths within it go through `PlaylistStore.load()` → `Playlist.fromJson()` without validation. Validation only happens at play time.

**Mitigation:** Validation at play time prevents execution of malicious paths. Playlist persistence is local-only (no network input).

### No Input Sanitization on Playlist Names

**Risk:** Playlist item names derived from file paths via `PathUtils.basename()`. No length limit or character filtering.

**Mitigation:** UI layer should truncate display. Not a security risk for local desktop app.

## Testing Gaps

### No Widget/UI Tests

**Current:** All tests are unit tests against kernel logic. No widget tests for UI components.

**Risk:** UI regressions undetected. ValueListenableBuilder wiring issues not caught.

**Mitigation:** Kernel isolation means business logic is well-tested. UI is relatively thin (delegates to kernel).

### No Integration/E2E Tests

**Current:** No tests that exercise the full open→play→seek→stop pipeline with real or mocked engine.

**Risk:** Integration bugs between services (e.g., PlaybackController + FvpEngine) not caught.

**Mitigation:** `FakeEngine` provides realistic enough behavior for unit-level integration.

### FakeEngine Maintenance

**Location:** `test/helpers/fake_engine.dart`

**Risk:** As `MediaEngine` interface grows, `FakeEngine` must be updated manually. Missing methods cause compile errors (good) but incomplete behavior (bad).

**Mitigation:** Dart's type system enforces interface compliance. `@override` annotations make intent clear.

## Window Management Concerns

### Frameless Window Edge Cases

**Location:** `lib/kernel/window/window_manager_service.dart`

**Pattern:** Custom `WM_NCCALCSIZE` handling in C++ runner for frameless window.

**Risk:** Windows DPI changes, monitor connect/disconnect, or remote desktop sessions can cause unexpected window behavior.

**Mitigation:** `onWindowResized()` debounces and persists. `_exitFullscreenInternal()` restores windowed geometry.

### Fullscreen State Machine

**Pattern:** `WindowMode` enum with `windowed`, `fullscreen`, `maximized` states.

**Risk:** Rapid toggling between fullscreen and windowed could leave the window in an inconsistent state if native calls fail.

**Mitigation:** `setFullscreen()` has try-catch with rollback on failure.

## Dependency Risks

### fvp Plugin

**Dependency:** `package:fvp` — Flutter Video Player based on MDK/FFmpeg.

**Risk:** FFI bindings tightly coupled to specific MDK version. Plugin updates could break compatibility.

**Mitigation:** Pinned version in `pubspec.lock`. `MediaEngine` abstract interface isolates UI from engine changes.

### window_manager Plugin

**Dependency:** `package:window_manager` — Flutter window management.

**Risk:** Platform-specific behavior differences. Windows-only testing.

**Mitigation:** `PlatformService` abstract interface allows platform-specific implementations.

---

*Concerns analysis: 2026-05-07*
