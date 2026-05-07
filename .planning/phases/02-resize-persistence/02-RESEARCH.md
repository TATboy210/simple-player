# Phase 2: Resize & Persistence - Research

**Researched:** 2026-05-07
**Domain:** Flutter desktop window management, resize debounce, geometry persistence, edge case resilience
**Confidence:** HIGH

## Summary

Phase 2 builds on Phase 1's window chrome to add jank-free resize optimization, minimum size enforcement, geometry persistence across sessions, and edge case handling. The investigation reveals that **most of the infrastructure already exists** in `WindowManagerService` — resize debounce (`_resizeDebounceMs = 500`), `isResizing` ValueNotifier, debounced persistence (`_persistDebounceMs = 500`), fullscreen reentry guard (`_togglingFullscreen`), and bounds checking (`_clampToVisibleBounds`).

**Key finding:** 4 of 7 requirements (WB-05, WB-06, WS-03, PQ-04 partial) are already implemented in `WindowManagerService`. The remaining work is:
1. Change `minSize` from `Size(640, 360)` to `Size(1024, 576)` — one-line constant change (WS-01)
2. Add targeted unit tests for debounce timing, isResizing state transitions, and persistence round-trip (PQ-02)
3. Add edge case test coverage: DPI changes, monitor disconnect, rapid fullscreen toggle (PQ-04)
4. Fix misleading test name in existing `window_manager_service_test.dart` line 257 ("100ms" should be "500ms")

**Primary recommendation:** Change the `minSize` constant, add unit tests with `fake_async` for debounce timing verification, and expand edge case coverage. No new files or architectural changes needed.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Minimum size enforcement | Window Layer (`WindowManagerService`) | — | `minSize` constant passed to `WindowOptions` at init |
| Resize debounce (isResizing) | Window Layer (`WindowManagerService`) | UI Layer (consumer via `ValueListenableBuilder`) | `onWindowResize`/`onWindowResized` callbacks manage `_resizeEndDebounce` timer |
| Geometry persistence | Window Layer (`WindowManagerService`) | Persistence Layer (`SettingsStore`) | `_persistWindowState` queries window state, delegates to `SettingsStore.saveWindowGeometry` |
| Bounds checking | Window Layer (`WindowManagerService`) | — | `_clampToVisibleBounds` checks position against screen size |
| Fullscreen reentry guard | Window Layer (`WindowManagerService`) | — | `_togglingFullscreen` bool prevents ABA state corruption |
| isResizing degradation | UI Layer (`CustomTitleBar`) | — | `ValueListenableBuilder<bool>` on `wm.isResizing`, skips `BackdropFilter` when true |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter/foundation | SDK (3.44+) | `ValueNotifier`, `debugPrint` | Built-in, no extra dependency |
| flutter_test | SDK | Unit + widget tests with `pump(Duration)` for timer control | Built-in, supports `testWidgets` for async timer testing |
| window_manager | 0.5.1 | `WindowListener` callbacks (`onWindowResize`, `onWindowResized`, `onWindowMoved`) | Already in pubspec, provides resize lifecycle hooks |
| shared_preferences | 2.5.5 | `SharedPreferences.setMockInitialValues` for test isolation | Already in pubspec, mock support built-in |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| fake_async | SDK | `fakeAsync((async) { ... })` for deterministic timer testing | Precise debounce timing tests (alternative to `testWidgets` + `pump`) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `testWidgets` + `pump(Duration)` | `fake_async` package | `pump` works with `ValueNotifier` in widget context; `fake_async` is more precise for pure unit tests |

## Architecture Patterns

### System Architecture Diagram

```
WindowManagerService (singleton, FFI)
    |
    +-- init() -> WindowManager.ensureInitialized()
    |       |
    |       +-- SettingsStore.load() -> AppSettings (windowWidth, windowHeight, windowX, windowY, isMaximized, isFullscreen)
    |       +-- WindowOptions(size: savedSize, minimumSize: minSize)
    |       +-- windowManager.setPosition() + _clampToVisibleBounds()
    |       +-- windowManager.maximize() if saved
    |       +-- windowManager.setAlwaysOnTop() if saved
    |       +-- windowManager.show() + focus()
    |       +-- fullscreen restore if saved
    |
    +-- WindowListener callbacks
    |       |
    |       +-- onWindowResize()  -> isResizing = true (cancel pending reset)
    |       +-- onWindowResized() -> _schedulePersist() + _resizeEndDebounce (500ms -> isResizing = false)
    |       +-- onWindowMove()    -> no-op (during)
    |       +-- onWindowMoved()   -> _schedulePersist()
    |       +-- onWindowMaximize/Unmaximize -> isMaximized + _persistWindowState
    |       +-- onWindowClose()   -> _persistWindowState + destroy
    |
    +-- _persistWindowState() -> Future.wait([getSize, getPosition, isMaximized, isFullScreen])
    |       |
    |       +-- fullscreen: use cached _windowedSize/_windowedPosition
    |       +-- windowed: update cache + SettingsStore.saveWindowGeometry()
    |
    +-- _clampToVisibleBounds() -> PlatformDispatcher screen size check
    |
    +-- toggleFullscreen() -> reentry guard (_togglingFullscreen)
            |
            +-- enter: cache windowed geometry, setSize + setPosition to screen
            +-- exit: restore cached geometry
```

### Recommended File Structure

No new files needed. All changes are in existing files:

```
lib/kernel/window/window_manager_service.dart   # minSize constant change
test/kernel/window/window_manager_service_test.dart  # expanded tests
```

### Pattern 1: Resize Debounce Flow

**What:** `onWindowResize` sets `isResizing=true` immediately; `onWindowResized` starts a 500ms timer to reset it. Concurrent resize events cancel the pending reset.

**When to use:** Any glass-morphism surface that causes GPU jank during resize

**How it works in code:**
```dart
// Source: window_manager_service.dart:367-379
@override
void onWindowResize() {
  _resizeEndDebounce?.cancel(); // cancel pending reset during drag
  isResizing.value = true;
}

@override
void onWindowResized() {
  _schedulePersist(); // debounced persistence
  _resizeEndDebounce?.cancel();
  _resizeEndDebounce = Timer(
    const Duration(milliseconds: _resizeDebounceMs), // 500ms
    () => isResizing.value = false,
  );
}
```

### Pattern 2: Debounced Persistence

**What:** Continuous resize/move events are coalesced into a single `SettingsStore.saveWindowGeometry()` call 500ms after the last event.

**When to use:** Any high-frequency events that need to persist state without hammering disk

**How it works:**
```dart
// Source: window_manager_service.dart:427-434
void _schedulePersist() {
  _persistDebounce?.cancel();
  _persistDebounce = Timer(
    const Duration(milliseconds: _persistDebounceMs), // 500ms
    _persistWindowState,
  );
}
```

### Pattern 3: Fullscreen Reentry Guard

**What:** `_togglingFullscreen` bool prevents rapid F11 presses from corrupting state (ABA problem).

**When to use:** Any async state toggle that can be triggered faster than it completes

**How it works:**
```dart
// Source: window_manager_service.dart:270-299
Future<void> toggleFullscreen() async {
  if (_togglingFullscreen || _disposed) return;
  _togglingFullscreen = true;
  try {
    // ... toggle logic
  } finally {
    _togglingFullscreen = false;
  }
}
```

### Anti-Patterns to Avoid

- **Testing debounce with `Future.delayed`:** Use `testWidgets` + `pump(Duration)` or `fake_async` for deterministic timer control. Real delays make tests flaky.
- **Changing minSize without updating _sanitizeDimension:** `SettingsStore._sanitizeDimension` uses `min: 640` for width and `min: 360` for height. If `minSize` changes to 1024x576, these sanitization bounds should also be updated to prevent loading values below the new minimum.
- **Forgetting bounds check on position restore:** `_clampToVisibleBounds` already handles this, but tests should verify it works when screen size is smaller than saved position.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Window resize events | Custom WM_SIZE listener | `WindowListener.onWindowResize/onWindowResized` | window_manager handles platform differences |
| Geometry persistence | Custom file I/O | `SettingsStore.saveWindowGeometry` | Already has sanitization, debounce, error handling |
| Screen size detection | Custom FFI for monitor info | `ui.PlatformDispatcher.instance.views` | Built-in, already used in `_clampToVisibleBounds` |
| Timer-based debounce | Manual Timer management | Keep existing `_resizeEndDebounce` + `_persistDebounce` | Already production-hardened |

## Common Pitfalls

### Pitfall 1: minSize vs _sanitizeDimension Mismatch
**What goes wrong:** Changing `WindowManagerService.minSize` to 1024x576 without updating `SettingsStore._sanitizeDimension` min bounds (currently 640x360). On load, persisted values between 640-1023 would pass sanitization but violate the new minimum.
**Why it happens:** Two separate constants control the same constraint in different contexts.
**How to avoid:** Update both `minSize` in `WindowManagerService` AND the `min` parameter in `SettingsStore._sanitizeDimension` calls (lines 130-133, 198-199, 279-280).
**Warning signs:** Window loads at 800x450 (below 1024x576 minimum).

### Pitfall 2: Test Name Misleading on Debounce Duration
**What goes wrong:** Existing test at `window_manager_service_test.dart:257` says "100ms debounce" but actual constant is 500ms.
**Why it happens:** Test was likely written before the constant was changed from 100ms to 500ms.
**How to avoid:** Fix the test name to match actual behavior. The test itself works correctly (waits 600ms, which covers 500ms).
**Warning signs:** Confusion during code review.

### Pitfall 3: Fullscreen Toggle Race with Resize
**What goes wrong:** User resizes window then immediately presses F11. The `_togglingFullscreen` guard prevents reentry, but the resize debounce timer fires during fullscreen transition.
**Why it happens:** Two independent timers (`_resizeEndDebounce` and fullscreen state) can interleave.
**How to avoid:** `_togglingFullscreen` guard already prevents this. Document the interaction in tests.
**Warning signs:** `isResizing` stuck at `true` after fullscreen toggle.

### Pitfall 4: Multi-Monitor DPI Mismatch
**What goes wrong:** Window saved on high-DPI monitor, restored on low-DPI monitor. `PlatformDispatcher.instance.views.first` may return different view after monitor change.
**Why it happens:** `devicePixelRatio` changes when moving between monitors.
**How to avoid:** `_clampToVisibleBounds` already handles this by checking physical/logical bounds. Test with different DPR values.
**Warning signs:** Window appears tiny or oversized after monitor change.

## Code Examples

### Debounce Timing Test with fake_async
```dart
// Source: flutter_test SDK
import 'package:fake_async/fake_async.dart';

test('isResizing resets after 500ms debounce', () {
  fakeAsync((async) {
    final wm = WindowManagerService.I;
    wm.isResizing.value = false;

    wm.onWindowResize();
    expect(wm.isResizing.value, isTrue);

    wm.onWindowResized();

    // Not yet — only 400ms elapsed
    async.elapse(const Duration(milliseconds: 400));
    expect(wm.isResizing.value, isTrue);

    // Now — 500ms+ elapsed
    async.elapse(const Duration(milliseconds: 200));
    expect(wm.isResizing.value, isFalse);
  });
});
```

### Persistence Round-Trip Test
```dart
// Source: shared_preferences test pattern
test('window geometry persists and loads correctly', () async {
  SharedPreferences.setMockInitialValues({});

  await SettingsStore.saveWindowGeometry(
    width: 1280, height: 720, x: 100, y: 200, isMaximized: false,
  );

  final settings = await SettingsStore.load();
  expect(settings.windowWidth, 1280.0);
  expect(settings.windowHeight, 720.0);
  expect(settings.windowX, 100.0);
  expect(settings.windowY, 200.0);
  expect(settings.isMaximized, isFalse);
});
```

### Rapid Fullscreen Toggle Test
```dart
test('rapid fullscreen toggle is guarded by reentry lock', () async {
  final wm = WindowManagerService.I;
  wm.mode.value = WindowMode.windowed;

  // Simulate rapid presses — second call should be ignored
  final future1 = wm.toggleFullscreen();
  final future2 = wm.toggleFullscreen(); // guarded, returns immediately

  await future1;
  await future2;

  // State should be consistent (not corrupted ABA)
  expect(wm.mode.value, WindowMode.fullscreen);
});
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual Timer in widget | `_resizeEndDebounce` in WindowManagerService | Phase 1 infrastructure | Centralized, testable |
| Save on every event | 500ms debounced `_schedulePersist` | Existing codebase | Prevents disk thrashing |
| No reentry guard | `_togglingFullscreen` bool | Existing codebase | Prevents ABA corruption |
| No bounds check | `_clampToVisibleBounds` | Existing codebase | Handles multi-monitor edge cases |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `_resizeDebounceMs` (500ms) is the correct value for WB-06 requirement | Architecture | If requirement specifies different duration, constant needs adjustment |
| A2 | `SettingsStore._sanitizeDimension` min bounds should match `minSize` | Pitfall 1 | If not updated, window can load below minimum size |
| A3 | `fake_async` is available in the SDK without extra dependency | Standard Stack | If not, use `testWidgets` + `pump` pattern instead |

## Open Questions

1. **Should `_sanitizeDimension` min bounds be updated to match new `minSize`?**
   - What we know: Current `minSize` is 640x360, `_sanitizeDimension` uses `min: 640` for width and `min: 360` for height.
   - What's unclear: Whether updating `minSize` to 1024x576 also requires updating `_sanitizeDimension` bounds.
   - Recommendation: Yes, update both to prevent loading values below the new minimum. This is a consistency requirement.

2. **Should the test name at line 257 be fixed?**
   - What we know: Test says "100ms debounce" but constant is 500ms. Test itself works correctly.
   - What's unclear: Whether this was intentional or a stale comment.
   - Recommendation: Fix the test name to "500ms debounce" for accuracy.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | Build + test | -- | 3.44+ (beta) | -- |
| flutter_test | Unit tests | -- | SDK | -- |
| fake_async | Timer tests | -- | SDK (flutter_test includes) | Use `testWidgets` + `pump` |
| shared_preferences | Mock persistence | -- | 2.5.5 | -- |
| window_manager | FFI callbacks | -- | 0.5.1 | -- |

No external dependencies beyond what's already in pubspec.yaml.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) |
| Config file | pubspec.yaml (dev_dependencies) |
| Quick run command | `flutter test test/kernel/window/window_manager_service_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| WB-05 | isResizing skips BackdropFilter during resize | widget | `flutter test test/widget/window/custom_title_bar_test.dart` | Yes (line 93-99) |
| WB-06 | 500ms debounce before restoring glass-morphism | unit | `flutter test test/kernel/window/window_manager_service_test.dart` | Yes (line 257, name fix needed) |
| WS-01 | Minimum size 1024x576 | unit | same file + new test | Partial (test at line 87-98, needs update) |
| WS-02 | Free resize in empty state | unit | same file (minSize test) | Partial (needs new test) |
| WS-03 | Geometry persists across sessions | unit | `flutter test test/kernel/persistence/settings_store_test.dart` | Partial (needs round-trip test) |
| PQ-02 | Unit tests for debounce, isResizing, persistence | unit | combined | Partial (needs expansion) |
| PQ-04 | Edge cases: DPI, monitor disconnect, rapid toggle | unit | same file | No - needs new tests |

### Sampling Rate
- **Per task commit:** `flutter test test/kernel/window/window_manager_service_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** `flutter analyze` + `flutter test` both green

### Wave 0 Gaps
- [ ] Update `test/kernel/window/window_manager_service_test.dart`:
  - Fix test name at line 257 ("100ms" -> "500ms")
  - Update minSize test at line 87-98 (640x360 -> 1024x576)
  - Add persistence round-trip test
  - Add rapid fullscreen toggle test
  - Add DPI/bounds check test
- [ ] Update `test/kernel/persistence/settings_store_test.dart`:
  - Add window geometry round-trip test
  - Add _sanitizeDimension boundary test for new min values

## Project Constraints (from CLAUDE.md)

- Use `debugPrint()` not `print()` for logging
- Use `DesignTokens.*` (in this codebase: `Tokens.*`) for all visual values
- Errors: catch with `debugPrint` + graceful fallback (never silent `catch (_) {}`)
- Conventional commits: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`
- Chinese comments are OK (existing codebase convention)
- ValueNotifier + ValueListenableBuilder only (no Provider/Riverpod/Bloc)

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| WB-05 | During resize, BackdropFilter is skipped (isResizing notifier) | Already implemented: `WindowManagerService.onWindowResize` sets `isResizing=true`, `CustomTitleBar` listens via `ValueListenableBuilder`. Widget test exists at line 93-99. |
| WB-06 | Resize debounce (500ms) before restoring glass-morphism | Already implemented: `_resizeDebounceMs=500`, `_resizeEndDebounce` timer in `onWindowResized`. Test exists but name needs fix ("100ms" -> "500ms"). |
| WS-01 | Minimum window size 1024x576 (16:9) when no video playing | One-line change: `minSize = Size(1024, 576)`. Also update `_sanitizeDimension` min bounds in `SettingsStore`. |
| WS-02 | Window freely resizable to any aspect ratio in empty state | Already works — no aspect ratio lock in empty state. `DragToResizeArea` in `app.dart` enables resize edges when not fullscreen. |
| WS-03 | Window geometry persists across sessions via SettingsStore | Already implemented: `SettingsStore.saveWindowGeometry` + `_persistWindowState` + `_schedulePersist`. Needs round-trip test. |
| PQ-02 | Unit tests for resize debounce, isResizing state, persistence | Partially done. Needs: debounce timing test with `fake_async`, persistence round-trip, rapid toggle guard. |
| PQ-04 | Edge cases: DPI changes, monitor disconnect, rapid fullscreen toggle | `_clampToVisibleBounds` handles DPI/monitor. `_togglingFullscreen` guards rapid toggle. Needs test coverage. |
</phase_requirements>

## Sources

### Primary (HIGH confidence)
- `D:\simple_player_flutter\lib\kernel\window\window_manager_service.dart` — Full implementation with debounce, persistence, bounds checking
- `D:\simple_player_flutter\lib\kernel\persistence\settings_store.dart` — `saveWindowGeometry`, `_sanitizeDimension`, load/save
- `D:\simple_player_flutter\lib\kernel\ui\window\custom_title_bar.dart` — `ValueListenableBuilder<bool>` on `wm.isResizing`
- `D:\simple_player_flutter\test\kernel\window\window_manager_service_test.dart` — Existing tests for state transitions and debounce
- `D:\simple_player_flutter\test\kernel\persistence\settings_store_test.dart` — Existing persistence tests

### Secondary (MEDIUM confidence)
- `D:\simple_player_flutter\.planning\phases\01-window-chrome\01-RESEARCH.md` — Phase 1 architecture and patterns

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all dependencies already in pubspec, patterns proven in Phase 1
- Architecture: HIGH — WindowManagerService is production-hardened, all FFI wrapped in try-catch
- Pitfalls: HIGH — `_sanitizeDimension` mismatch risk identified from code inspection

**Research date:** 2026-05-07
**Valid until:** 2026-06-07 (stable — Flutter/window_manager APIs unlikely to change)
