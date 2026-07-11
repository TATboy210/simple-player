# Current Fullscreen Architecture Analysis

**Date:** 2026-07-11
**Scope:** All fullscreen-related code in `lib/` and `test/`

## Summary Verdict

The fullscreen implementation spans **4,368 lines of source code** and **3,555 lines of tests** across **18 source files** and **8 test files**. For a single boolean operation (enter/exit fullscreen), this is **over-engineered by a factor of ~5x**. The core problem: the architecture was designed for multi-window, multi-display, multi-mode scenarios that the app does not use. A single-window desktop media player needs ~800-1000 lines, not 4,368.

---

## File Inventory

### Source Files (lib/)

| File | Lines | What It Does |
|------|-------|-------------|
| `lib/kernel/bridge/fullscreen_adapter.dart` | 68 | Abstract interface for fullscreen management |
| `lib/kernel/bridge/fullscreen_driver.dart` | 134 | Abstract interface for platform-native fullscreen ops |
| `lib/kernel/bridge/fullscreen_command_queue.dart` | 258 | Per-window command serialization queue with Completer chain |
| `lib/kernel/bridge/desktop_fullscreen_adapter.dart` | 520 | Concrete adapter: command queue + state readback + restore + event broadcast |
| `lib/kernel/bridge/desktop_fullscreen_driver.dart` | 133 | window_manager-based driver (fallback) |
| `lib/kernel/bridge/desktop_fullscreen_driver_factory.dart` | 100 | Platform driver factory with compile-time flag selection |
| `lib/kernel/bridge/platform/windows_fullscreen_driver.dart` | 608 | Win32 FFI driver: WS_THICKFRAME removal, focus recovery, TopMost cleanup |
| `lib/kernel/bridge/platform/macos_fullscreen_driver.dart` | 212 | macOS driver: fullscreen_window plugin + NSWindowDelegate callback |
| `lib/kernel/bridge/platform/linux_fullscreen_driver.dart` | 246 | Linux driver: fullscreen_window plugin + GDK state-changed signal |
| `lib/kernel/bridge/win32/win32_fullscreen_ffi.dart` | 509 | Win32 FFI bindings: 14 function lookups, struct definitions, static API class |
| `lib/kernel/bridge/window_mode.dart` | 19 | WindowMode enum (windowed/maximized/fullscreen/minimized) |
| `lib/kernel/models/fullscreen_snapshot.dart` | 127 | Immutable state snapshot: phase + effectiveMode + restoreMode + error |
| `lib/kernel/models/fullscreen_error.dart` | 145 | Sealed error hierarchy: 7 error types with equality/hashCode |
| `lib/kernel/models/fullscreen_event.dart` | 108 | Sealed event hierarchy: 7 event types for lifecycle stream |
| `lib/kernel/models/fullscreen_request.dart` | 51 | Sealed request hierarchy: Enter/Leave/Toggle commands |
| `lib/kernel/models/fullscreen_capability.dart` | 32 | Platform capability flags (multi-window, multi-display, exclusive) |
| `lib/kernel/bridge/window_service.dart` | 380 | Window coordinator (fullscreen is ~60 lines of this) |
| `lib/ui/player/player_screen.dart` | 417 | Main screen (fullscreen toggle is ~15 lines of this) |
| `lib/ui/player/controls_overlay.dart` | 301 | Control overlay (fullscreen-aware auto-hide is ~20 lines of this) |

**Total source lines (fullscreen-specific):** ~3,248 lines (excluding WindowService/PlayerScreen/ControlsOverlay which share responsibilities)
**Total source lines (all listed):** 4,368 lines

### Test Files (test/)

| File | Lines | What It Tests |
|------|-------|--------------|
| `test/kernel/bridge/fullscreen_adapter_test.dart` | 651 | Abstract adapter contract tests |
| `test/kernel/bridge/fullscreen_command_queue_test.dart` | 536 | Command queue serialization, merge, timeout |
| `test/kernel/bridge/desktop_fullscreen_adapter_test.dart` | 777 | Concrete adapter: enter/leave/restore/desync/confirmation |
| `test/platform/windows_fullscreen_driver_test.dart` | 804 | Win32 FFI driver tests |
| `test/platform/macos_fullscreen_driver_test.dart` | 251 | macOS driver tests |
| `test/platform/linux_fullscreen_driver_test.dart` | 273 | Linux driver tests |
| `test/platform/fullscreen_driver_factory_test.dart` | 130 | Factory selection tests |
| `test/integration/fullscreen_e2e_test.dart` | 133 | End-to-end integration tests |

**Total test lines:** 3,555 lines (~172 test cases)

---

## Architecture Layers

The current implementation has **5 abstraction layers**:

```
Layer 5: UI (PlayerScreen, ControlsOverlay)
   |
   v
Layer 4: WindowService (coordinator, mode sync)
   |
   v
Layer 3: FullscreenAdapter (abstract interface)
   |
   v
Layer 2: DesktopFullscreenAdapter (command queue + state machine + event broadcast)
   |
   v
Layer 1: FullscreenDriver (abstract interface)
   |
   v
Layer 0: Platform Driver (WindowsFullscreenDriver / MacosFullscreenDriver / LinuxFullscreenDriver / DesktopFullscreenDriver)
```

### Data Flow: Toggle Fullscreen (F key)

```
1. PlayerScreen: onToggleFullscreen callback
2. WindowService.setMode(fullscreen) — optimistic mode update + rollback on error
3. FullscreenAdapter.setFullscreen(true) — enqueues to FullscreenCommandQueue
4. FullscreenCommandQueue — serializes, merges duplicates, resolves toggle
5. DesktopFullscreenAdapter._executeCommand — captures restore snapshot, updates phase
6. FullscreenDriver.enterFullscreen() — platform-specific native call
7. Three-tier confirmation: native callback (500ms) → polling (100ms x 20) → timeout
8. On confirm: update snapshot (phase=stable), broadcast event
9. WindowService._onFullscreenEvent → sync mode ValueNotifier
10. PlayerScreen rebuilds via AnimatedBuilder on mode notifier
```

---

## Complexity Assessment

### Abstractions and Interfaces

| Abstraction | Purpose | Necessary? |
|------------|---------|-----------|
| `FullscreenAdapter` (abstract) | UI-facing interface | **Debatable** — only one implementation exists |
| `FullscreenDriver` (abstract) | Platform abstraction | **Yes** — 3 platform drivers + 1 fallback |
| `FullscreenCommandQueue` | Command serialization | **Overkill** — single-window app has no concurrency |
| `FullscreenSnapshot` (5 fields) | State container | **Overkill** — 5 fields for what is essentially a bool |
| `FullscreenPhase` (5 states) | State machine | **Overkill** — entering/leaving states serve macOS animation delay |
| `FullscreenError` (7 types) | Error hierarchy | **Overkill** — 4 of 7 types are never used in practice |
| `FullscreenEvent` (7 types) | Event stream | **Overkill** — only Entered/Left/ForcedChange matter |
| `FullscreenRequest` (3 types) | Command types | **Overkill** — toggle resolves to enter/leave in the queue |
| `FullscreenCapability` | Platform features | **Unused** — no UI decision depends on this |
| `WindowMode` enum | Window state | **Yes** — but duplicates FullscreenMode |
| `WindowPlacement` FFI struct | Win32 save/restore | **Yes** — core to Windows fullscreen |
| `Win32FullscreenApiWrapper` | Mock wrapper | **Yes** — enables testability |

### State Variables in DesktopFullscreenAdapter

```dart
final Map<int, ValueNotifier<FullscreenSnapshot>> _snapshots;  // per-window state
final Map<int, _RestoreSnapshot> _restoreSnapshots;             // per-window restore
final Map<int, _PendingConfirmation> _confirmByWindowId;        // per-window confirmation
int _nextRequestId;                                              // monotonic request ID
bool _disposed;                                                  // lifecycle flag
FullscreenCommandQueue _queue;                                   // command queue
StreamController<FullscreenEvent> _events;                       // event broadcast
```

That is **7 state fields** plus the internal state of `_WindowQueue` (3 more) to manage what is fundamentally `bool isFullscreen + Rect savedBounds`.

### What the UI Actually Needs

From `player_screen.dart` and `controls_overlay.dart`, the UI consumes exactly:

1. `windowService.mode` — a `ValueNotifier<WindowMode>` to know if fullscreen
2. `windowService.setMode(WindowMode.fullscreen / .windowed)` — to toggle
3. `isFullscreen` bool — passed to ControlsOverlay for auto-hide behavior

That's it. The entire 4,368-line fullscreen system ultimately serves these three touch points.

---

## Over-Engineering Analysis

### Problem 1: Multi-Window Support Without Multi-Window

Every data structure is `Map<int, ...>` keyed by `windowId`. The app has exactly one window (`windowId = 0`). The command queue maintains per-window queues. The snapshot state is per-window. The confirmation signals are per-window. This adds ~30% complexity for a feature that does not exist.

**Lines wasted:** ~200 (command queue per-window logic, Map<int, ...> everywhere)

### Problem 2: Three-Tier Confirmation Chain for Synchronous Operations

The Windows FFI driver (`supportsFastPath = true`) performs synchronous operations. The confirmation chain (native callback → polling → timeout) exists for macOS/Linux where fullscreen has a ~700ms animation. But the entire chain is wired through the adapter even for Windows, just to be bypassed by the fast-path flag.

**Lines wasted:** ~150 (confirmation registration, timeout logic, polling loop)

### Problem 3: Command Queue for Non-Concurrent Operations

`FullscreenCommandQueue` serializes commands with merge logic, timeout management, and drain semantics. In practice: user presses F, fullscreen happens. There is no scenario where commands queue up. The queue adds ~258 lines for behavior that `await` alone provides.

**Lines wasted:** ~258 (entire command queue)

### Problem 4: Excessive Model Types

- `FullscreenPhase` (5 states) — only `stable` matters; `entering`/`leaving` serve macOS animation delay that the UI already handles via `isFullscreen` bool
- `FullscreenError` (7 types) — only `platformFailure` is ever constructed in production code
- `FullscreenEvent` (7 types) — only `Entered`, `Left`, `ForcedChange` are consumed by WindowService
- `FullscreenRequest` (3 types) — `ToggleFullscreen` is resolved in the queue, never reaches the driver
- `FullscreenCapability` — never consumed by any UI decision

**Lines wasted:** ~300 (unnecessary types, equality/hashCode implementations)

### Problem 5: Restore Snapshot Complexity

The adapter captures window position/size/maximized state before entering fullscreen and restores it on exit. This is correct behavior, but the implementation involves a `_RestoreSnapshot` class, `captureSnapshot()` batch optimization, and per-window storage — for a single-window app that could use a simple `Rect? _savedBounds`.

**Lines wasted:** ~50 (over-abstracted restore)

### Problem 6: Two Parallel State Systems

`WindowService.mode` (WindowMode enum) and `FullscreenAdapter.snapshot` (FullscreenSnapshot) track the same information with different types. The adapter events are listened to by WindowService to sync its mode. This creates two sources of truth that must be kept in sync — the optimistic update + rollback pattern in `setMode()` exists solely to paper over this dual-state problem.

**Lines wasted:** ~80 (sync logic, event mapping, rollback)

---

## What a Minimal Implementation Looks Like

For a single-window desktop media player, the fullscreen system needs:

1. **Platform abstraction** (~150 lines) — `FullscreenDriver` interface + 3 platform implementations
2. **Win32 FFI bindings** (~400 lines) — `win32_fullscreen_ffi.dart` (this is well-written, keep it)
3. **Simple coordinator** (~100 lines) — enter/leave with save/restore bounds, no queue, no state machine
4. **UI integration** (~20 lines) — already exists in PlayerScreen/ControlsOverlay

**Estimated minimal:** ~670 lines (vs current 3,248 lines of fullscreen-specific code)

That is a **~5x reduction**.

### What to Keep

| Component | Keep? | Reason |
|-----------|-------|--------|
| `win32_fullscreen_ffi.dart` | **Yes** | Core Win32 bindings, well-tested |
| `windows_fullscreen_driver.dart` | **Yes** | WS_THICKFRAME fix, focus recovery, TopMost cleanup |
| `macos_fullscreen_driver.dart` | **Yes, simplify** | Remove callback plumbing, keep plugin calls |
| `linux_fullscreen_driver.dart` | **Yes, simplify** | Remove callback plumbing, keep plugin calls |
| `desktop_fullscreen_driver.dart` | **Yes** | Fallback driver, thin |
| `fullscreen_driver.dart` | **Yes, simplify** | Remove capabilities/captureSnapshot/onNativeStateChanged |
| `fullscreen_adapter.dart` | **Delete** | Only one implementation, no polymorphism needed |
| `fullscreen_command_queue.dart` | **Delete** | Unnecessary serialization |
| `desktop_fullscreen_adapter.dart` | **Merge into WindowService** | Coordinator logic belongs with window management |
| `fullscreen_snapshot.dart` | **Delete** | Replace with simple bool + Rect? |
| `fullscreen_error.dart` | **Delete** | Use try/catch with single error type |
| `fullscreen_event.dart` | **Delete** | Use ValueNotifier callback |
| `fullscreen_request.dart` | **Delete** | Direct method calls |
| `fullscreen_capability.dart` | **Delete** | Not consumed anywhere |
| `window_mode.dart` | **Keep** | Already in use by WindowService |
| `desktop_fullscreen_driver_factory.dart` | **Simplify** | Keep platform selection, remove compile-time flags |

### What to Delete

The following 6 files can be entirely deleted:

1. `fullscreen_adapter.dart` (68 lines) — abstract interface with one implementation
2. `fullscreen_command_queue.dart` (258 lines) — unnecessary serialization
3. `fullscreen_snapshot.dart` (127 lines) — replace with bool + Rect?
4. `fullscreen_error.dart` (145 lines) — 7 types for 1 used
5. `fullscreen_event.dart` (108 lines) — 7 types for 3 used
6. `fullscreen_request.dart` (51 lines) — 3 types for 2 used

**Lines deleted:** 757 lines

---

## Dependency Graph

```
main.dart
  └─ DesktopFullscreenDriverFactory.create()
       ├─ WindowsFullscreenDriver (if USE_WINDOWS_NATIVE_FULLSCREEN)
       │    └─ Win32FullscreenApi (win32_fullscreen_ffi.dart)
       ├─ MacosFullscreenDriver
       │    └─ fullscreen_window plugin
       ├─ LinuxFullscreenDriver
       │    └─ fullscreen_window plugin
       └─ DesktopFullscreenDriver (fallback)
            └─ window_manager package
  └─ DesktopFullscreenAdapter(driver)
       ├─ FullscreenCommandQueue
       └─ FullscreenSnapshot / FullscreenEvent / FullscreenError / FullscreenRequest
  └─ WindowService(fullscreenAdapter)
       └─ listens to adapter events → syncs WindowMode
            └─ PlayerScreen reads WindowService.mode
```

---

## Test Coverage Observations

The test suite is **disproportionately large** (3,555 test lines for 4,368 source lines, ratio 0.81). This is typical of over-abstracted code — the abstractions create surface area that needs testing.

Key test observations:
- `desktop_fullscreen_adapter_test.dart` (777 lines) — tests confirmation chain, desync recovery, restore strategy — complexity that exists only because of the abstraction
- `fullscreen_command_queue_test.dart` (536 lines) — tests merge logic, timeout, drain — all unnecessary if the queue is removed
- `fullscreen_adapter_test.dart` (651 lines) — tests abstract contract — only meaningful if multiple implementations exist

If the architecture is simplified, **~2,000 lines of tests can be deleted** along with the source code.

---

## State Management Approach

Current: **Dual ValueNotifier system**

```
WindowService.mode: ValueNotifier<WindowMode>  ← UI reads this
DesktopFullscreenAdapter._snapshots: Map<int, ValueNotifier<FullscreenSnapshot>  ← internal state machine
```

The two systems are synced via event subscription (`_onFullscreenEvent`). The WindowService also does optimistic updates (`_state.mode.value = WindowMode.fullscreen` before awaiting the adapter) with rollback on error.

Recommended: **Single ValueNotifier**

```dart
// In WindowService:
ValueNotifier<bool> isFullscreen;  // UI reads this
Rect? _savedBounds;  // restore on exit
```

---

## Conclusion

The fullscreen system is over-engineered for a single-window media player. The architecture was designed for a hypothetical multi-window, multi-display scenario that the app does not support. The core issues are:

1. **5 abstraction layers** where 2 would suffice
2. **Command queue** for non-concurrent operations
3. **7-field state machine** for what is a boolean
4. **7 error types** where 1 is used
5. **Dual state systems** requiring sync logic
6. **Per-window data structures** for a single-window app

The Win32 FFI layer (`win32_fullscreen_ffi.dart` + `windows_fullscreen_driver.dart`) is well-written and solves real problems (7px border gap, focus recovery, TopMost cleanup). This should be preserved. The abstraction layers above it can be collapsed.
