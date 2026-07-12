# Phase 1: 全屏代码简化 - Research

**Researched:** 2026-07-12
**Domain:** Win32 FFI fullscreen, Flutter window management, code simplification
**Confidence:** HIGH

## Summary

This phase simplifies the fullscreen code architecture by reducing abstraction layers from 4 to 3, establishing WindowService as the single source of truth for fullscreen state, and evaluating the `flutter_fullscreen` package. The current architecture has two redundant layers (`DesktopFullscreenDriver` and `DesktopFullscreenDriverFactory`) that can be deleted. The Win32 FFI core (509 lines FFI + 459 lines driver) must be preserved — it solves the WS_THICKFRAME 7px gap that `window_manager` cannot.

The fullscreen state persistence via `SettingsStore.saveIsFullscreen` is dead code: the save method exists but `_loadImpl()` never reads it back, and `WindowService` never calls it. This confirms the D-08 decision to remove it.

**Primary recommendation:** Delete `DesktopFullscreenDriver` + `DesktopFullscreenDriverFactory`, inline platform detection into `WindowService.init()`, use `FullscreenResult` sealed class for error handling, simplify confirmation chain to callback + single timeout query.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Delete DesktopFullscreenDriver (window_manager fallback driver), macOS/Linux directly call fullscreen_window native code. Layers 4->3.
- **D-02:** Delete DesktopFullscreenDriverFactory, platform detection logic inlined to WindowService.init(). Remove one file and one indirection layer.
- **D-03:** WindowsFullscreenDriver (459 lines) and Win32FullscreenFfi (509 lines) stay separate. FFI bindings independently testable, clear responsibilities, merged ~900 lines exceeds best practice.
- **D-04:** Also clean up internal redundant abstractions: CommandQueue anti-reentrant, 7 error types simplify to sealed class, over-abstracted state machine delete.
- **D-05:** macOS/Linux directly use packages/fullscreen_window/ native code (113 lines C++ macOS, 182 lines C Linux), no extra abstraction layer.
- **D-06:** Do NOT introduce flutter_fullscreen package. Reason: internally depends entirely on window_manager, cannot solve WS_THICKFRAME 7px gap, user confirmed win32 package causes one-frame stutter. Windows keeps custom Win32 FFI.
- **D-07:** Output flutter_fullscreen evaluation document to `.planning/research/`, includes comparison table, reasons for not using, conditions for considering adoption. Satisfies FULL-02.
- **D-08:** WindowService is isFullscreen only owner, exposed via ValueNotifier. SettingsStore deletes saveIsFullscreen/isFullscreen related getter/setter. Satisfies FULL-03.
- **D-09:** Fullscreen state needs persistence, managed by WindowService (not SettingsStore). Restore fullscreen state on startup.
- **D-10:** Window geometry snapshot/restore logic stays inside WindowService (_restoreSnapshot), not moved to driver layer.
- **D-11:** Error handling uses sealed class (FullscreenResult: Success/Failure) + auto-restore window state. Replaces existing 7 error type classifications.
- **D-12:** Confirmation chain simplification: keep callback confirmation as primary path, after timeout simplify to single query (instead of 20 polls), delete _confirmByWindowId complex mapping.
- **D-13:** WindowService stays as-is, not split. May exceed 500 lines after merging fullscreen state, but responsibilities are cohesive (fullscreen + resize + persistence + geometry all belong to window management).
- **D-14:** Keep WindowBridge abstract interface (4 states + 7 commands), for testing and macOS/Linux platform implementations.
- **D-15:** WindowService injects persistence interface via constructor, for testing and decoupling SettingsStore direct dependency.
- **D-16:** Simplify resize debounce to single Timer (currently has _resizeDebounce and _resizeEndTimer two timers), reduce Timer/Completer interaction complexity.

### Claude's Discretion
None — all decisions explicitly chosen by user.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FULL-01 | 全屏代码层数减少 — 合并分散逻辑，降低 FullscreenDriver/WindowService/SettingsStore 之间的间接层 | Current architecture has 4 layers (FullscreenDriver abstraction, DesktopFullscreenDriver fallback, DesktopFullscreenDriverFactory, WindowService). Delete 2 layers (D-01, D-02). Win32 FFI core preserved (D-03). |
| FULL-02 | 评估 flutter_fullscreen 包适用性 — 对比现有 Win32 FFI 实现，决定是否引入或保持自研 | flutter_fullscreen v1.2.0 fully depends on window_manager, cannot solve WS_THICKFRAME 7px gap. Decision: do not introduce (D-06). Evaluation document deliverable (D-07). |
| FULL-03 | 全屏状态单一数据源 — WindowService 作为唯一 owner，移除 SettingsStore 中的全屏相关状态 | SettingsStore.saveIsFullscreen is dead code (save exists, load doesn't read it). WindowService._isFullscreen is already the de facto owner. Clean up dead code (D-08). |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Fullscreen enter/leave | Kernel/Driver | — | Platform-specific Win32 FFI / fullscreen_window native calls |
| Fullscreen state tracking | Kernel/WindowService | — | Single ValueNotifier owner, UI reads via AnimatedBuilder |
| Fullscreen state persistence | Kernel/WindowService | — | WindowService manages via WindowPersistence (D-09, D-15) |
| Window geometry snapshot/restore | Kernel/WindowService | — | _restoreSnapshot lives in WindowService (D-10) |
| Platform detection | Kernel/WindowService | — | Inlined into WindowService.init() (D-02) |
| Fullscreen UI reaction | UI/PlayerScreen | — | AnimatedBuilder on windowService.mode, isFullscreen param to ControlsOverlay |

## Standard Stack

### Core (no new dependencies)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| window_manager | ^0.5.2 (existing) | Window positioning, geometry, frameless setup | Already integrated, version-pinned |
| dart:ffi | SDK | Win32 direct API calls | Zero dependency, zero latency |
| package:ffi | SDK | FFI helpers (calloc, Utf16) | Standard Dart FFI companion |
| fullscreen_window | local package | macOS/Linux native fullscreen | Vendored at packages/fullscreen_window/, 702 lines |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter/scheduler.dart | SDK | SchedulerPhase check for UI thread safety | _updateOnUIThread pattern |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom Win32 FFI | flutter_fullscreen package | Cannot solve WS_THICKFRAME 7px gap, depends on window_manager (D-06) |
| Custom Win32 FFI | win32 package | User confirmed causes one-frame stutter on fullscreen |
| FullscreenDriver abstraction | Direct driver calls in WindowService | Lose testability (mock injection) and macOS/Linux platform abstraction |

**Installation:** No new packages. Phase is pure code deletion/simplification.

## Package Legitimacy Audit

No new packages installed in this phase. Existing dependencies verified:

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| window_manager | npm/pub | 3+ yrs | 500K+ | github.com/leanflutter/window_manager | OK | Approved (existing) |
| fvp | pub | 2+ yrs | — | github.com/nickaknudson/fvp | OK | Approved (existing, version-pinned) |
| fullscreen_window | local | — | — | packages/fullscreen_window/ (vendored) | OK | Approved (local package) |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### Current Architecture (4 layers — before)

```
User Input (F key / double-click)
    │
    ▼
PlayerScreen → WindowService.setMode(WindowMode.fullscreen)
    │                    │
    │                    ├── _handleEnter(windowId)
    │                    │       │
    │                    │       ├── _captureRestoreSnapshot()
    │                    │       ├── driver.enterFullscreenFast()  ← Windows FFI path
    │                    │       │   or driver.enterFullscreen()   ← macOS/Linux path
    │                    │       ├── _waitForConfirmation()
    │                    │       │       ├── Completer + 500ms timeout
    │                    │       │       └── 20x polling fallback (2s worst case)
    │                    │       └── _applyDesync() on failure
    │                    │
    │                    └── _isFullscreen.value = true
    │
    ▼
WindowBridge.mode → ValueNotifier<WindowMode> → AnimatedBuilder rebuild
```

**Driver selection (current — DesktopFullscreenDriverFactory):**
```
DesktopFullscreenDriverFactory.create()
    ├── Windows + USE_WINDOWS_NATIVE_FULLSCREEN=true → WindowsFullscreenDriver (FFI)
    │       └── HWND invalid or FFI exception → fallback DesktopFullscreenDriver (window_manager)
    ├── Windows (default) → DesktopFullscreenDriver (window_manager)
    ├── macOS → MacosFullscreenDriver (fullscreen_window plugin)
    ├── Linux → LinuxFullscreenDriver (fullscreen_window plugin)
    └── Other → DesktopFullscreenDriver (window_manager)
```

### Target Architecture (3 layers — after)

```
User Input (F key / double-click)
    │
    ▼
PlayerScreen → WindowService.setMode(WindowMode.fullscreen)
    │                    │
    │                    ├── _handleEnter()
    │                    │       │
    │                    │       ├── _captureRestoreSnapshot()
    │                    │       ├── _driver.enterFullscreenFast()  ← Windows FFI
    │                    │       │   or _driver.enterFullscreen()   ← macOS/Linux
    │                    │       └── _waitForConfirmation()
    │                    │               ├── Callback confirmation (500ms)
    │                    │               └── Single query fallback (no 20x poll)
    │                    │
    │                    └── FullscreenResult sealed class
    │
    ▼
WindowBridge.mode → ValueNotifier<WindowMode> → AnimatedBuilder rebuild
```

**Driver selection (target — inlined in WindowService.init()):**
```
WindowService.init()
    ├── Platform.isWindows → WindowsFullscreenDriver (FFI, always)
    │       └── _ensureValidHwnd() guard inline
    ├── Platform.isMacOS → MacosFullscreenDriver (fullscreen_window)
    ├── Platform.isLinux → LinuxFullscreenDriver (fullscreen_window)
    └── Other → throw UnsupportedError (no fallback needed)
```

### Recommended Project Structure (after phase)

```
lib/kernel/bridge/
├── window_bridge.dart              # Abstract interface (kept)
├── window_service.dart             # Coordinator (expanded ~500 lines)
├── window_mode.dart                # WindowMode enum (kept)
├── window_state.dart               # Immutable state container (kept)
├── window_persistence.dart         # Geometry persistence (simplified)
├── fullscreen_driver.dart          # Abstract driver interface (kept)
├── platform/
│   ├── windows_fullscreen_driver.dart  # Win32 FFI driver (kept, 459 lines)
│   ├── macos_fullscreen_driver.dart    # macOS driver (kept)
│   └── linux_fullscreen_driver.dart    # Linux driver (kept)
├── win32/
│   ├── win32_fullscreen_ffi.dart       # FFI bindings (kept, 509 lines)
│   └── win32_display_enumerator.dart   # Display enumeration (kept)
└── display_config.dart             # Display config (kept)

DELETED:
├── desktop_fullscreen_driver.dart          # window_manager fallback (D-01)
└── desktop_fullscreen_driver_factory.dart  # Factory class (D-02)
```

### Pattern: FullscreenResult Sealed Class (D-11)

Replace the current bool return + 7 error type approach with a sealed class following the existing `OpenResult` pattern:

```dart
// Source: existing pattern in lib/kernel/engine/open_result.dart
sealed class FullscreenResult {
  const FullscreenResult();
}

final class FullscreenSuccess extends FullscreenResult {
  const FullscreenSuccess();
}

final class FullscreenFailure extends FullscreenResult {
  /// Whether the window state was automatically restored.
  final bool restored;
  const FullscreenFailure({this.restored = false});
}
```

**Usage in WindowService:**
```dart
Future<FullscreenResult> _handleEnter() async {
  try {
    await _driver.enterFullscreenFast();
    _isFullscreen.value = true;
    return const FullscreenSuccess();
  } on Exception catch (e) {
    debugPrint('[WindowService] fullscreen enter failed: $e');
    _isFullscreen.value = false;
    await _restoreFromSnapshot();
    return const FullscreenFailure(restored: true);
  }
}
```

### Pattern: Simplified Confirmation Chain (D-12)

Current: Completer + 500ms timeout + 20x polling (2s worst case)
Target: Callback confirmation (500ms) + single query fallback

```dart
Future<bool> _waitForConfirmation(bool expectedFullscreen) async {
  // Level 1: Wait for native callback (500ms)
  final confirmed = await _confirmationCompleter.future.timeout(
    const Duration(milliseconds: 500),
    onTimeout: () => false,
  );
  if (confirmed) return true;

  // Level 2: Single query check (no 20x polling)
  final actual = await _driver.queryFullscreen();
  return actual == expectedFullscreen;
}
```

### Pattern: Single Resize Timer (D-16)

Current: `_resizeDebounce` (100ms) + `_resizeEndTimer` (500ms) — two timers with cancel/recreate logic
Target: Single `_resizeTimer` (500ms) — debounce window size updates, isResizing set on first event, cleared on timer expiry

```dart
Timer? _resizeTimer;

void onWindowResize() {
  if (_disposed || _skipNextResize || _isProgrammaticResize) return;
  _state.isResizing.value = true;
  _resizeTimer?.cancel();
  _resizeTimer = Timer(const Duration(milliseconds: 500), () {
    if (_disposed) return;
    windowManager.getSize().then((size) {
      if (!_disposed && size != _state.windowSize.value) {
        _state.windowSize.value = Size(
          math.max(size.width, 854),
          math.max(size.height, 513),
        );
      }
      _state.isResizing.value = false;
    });
  });
}
```

### Anti-Patterns to Avoid

- **Dual state source for fullscreen:** `WindowService._isFullscreen` and `WindowService._state.mode` must stay in sync. After cleanup, derive `isFullscreen` from `mode.value.isFullscreen` instead of maintaining a separate `ValueNotifier<bool>`.
- **Dead persistence code:** `SettingsStore.saveIsFullscreen` is called by `WindowPersistence` but `_loadImpl` never reads it back. Remove the dead code path entirely.
- **Fallback to DesktopFullscreenDriver on Windows:** The current factory falls back to `window_manager` on HWND invalid. Instead, log an error and skip fullscreen capability — no silent fallback to a worse implementation.
- **20x polling loop:** The current `_waitForConfirmation` polls 20 times at 100ms intervals. Replace with single query check after callback timeout.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Platform detection | Custom Platform.isXXX branching in factory | Inline in WindowService.init() | Single file, no factory indirection |
| Error classification | 7 enum types for fullscreen errors | Sealed class (FullscreenResult) | Exhaustive matching, follows OpenResult pattern |
| Confirmation state tracking | Map<int, _PendingConfirmation> with requestId | Single Completer<bool> | Single-window app, no need for multi-window tracking |

**Key insight:** The current architecture has 6 internal classes/types for fullscreen error handling and confirmation. The simplified version needs 2 (FullscreenResult + single Completer). The complexity was designed for multi-window scenarios that don't exist in a single-window media player.

## Common Pitfalls

### Pitfall 1: Deleting DesktopFullscreenDriver Before Updating All Callers
**What goes wrong:** `main.dart` calls `DesktopFullscreenDriverFactory.create()`. Deleting the factory without updating `main.dart` causes compile error.
**Why it happens:** Factory is the entry point for driver creation.
**How to avoid:** Update `main.dart` to pass platform detection to `WindowService` constructor, or move detection into `WindowService.init()`.
**Warning signs:** Compile errors on `DesktopFullscreenDriverFactory` import.

### Pitfall 2: WindowsFullscreenDriver Fallback Removal
**What goes wrong:** Current factory falls back to `DesktopFullscreenDriver` when HWND is invalid. Removing this fallback means fullscreen silently fails on edge cases (service mode, remote desktop).
**Why it happens:** HWND can be 0 in special environments.
**How to avoid:** Keep the HWND validity check in `WindowsFullscreenDriver` itself, but return `FullscreenFailure` instead of falling back to a different driver.
**Warning signs:** Fullscreen does nothing on Windows in remote desktop sessions.

### Pitfall 3: Confirmation Chain Race Condition
**What goes wrong:** Simplifying from multi-window confirmation map to single Completer can cause race conditions if `setMode` is called rapidly.
**Why it happens:** Single Completer gets overwritten before previous operation completes.
**How to add a guard:** Check if a fullscreen operation is already in progress (`_isTransitioning` flag) and return early or cancel previous.
**Warning signs:** Fullscreen state flips rapidly between windowed and fullscreen.

### Pitfall 4: _isFullscreen vs mode.value Desync
**What goes wrong:** `WindowService` has both `_isFullscreen` (ValueNotifier<bool>) and `_state.mode` (ValueNotifier<WindowMode>). They can get out of sync.
**Why it happens:** `_isFullscreen` is set in `_handleEnter/Leave`, `mode` is set in `setMode` and `_onNativeFullScreenChanged`.
**How to avoid:** After cleanup, remove `_isFullscreen` entirely and derive from `mode.value.isFullscreen`. Or keep `_isFullscreen` as the single source and derive `mode` from it.
**Warning signs:** UI shows fullscreen controls but window is windowed, or vice versa.

### Pitfall 5: Resize Timer Consolidation Breaking Auto-Hide
**What goes wrong:** `ControlsOverlay` uses `isResizing` to suppress auto-hide during resize. Changing the timer pattern can break this.
**Why it happens:** `_resizeEndTimer` sets `isResizing = false` after 500ms of no resize events. Merging timers must preserve this behavior.
**How to avoid:** Single timer sets `isResizing = true` on first event, `false` on expiry. Same behavior, simpler implementation.
**Warning signs:** Auto-hide triggers during window resize, causing control bar flicker.

## Code Examples

### WindowService.init() — Inlined Platform Detection (D-02)

```dart
// In WindowService — replaces DesktopFullscreenDriverFactory.create()
static FullscreenDriver? _createDriver() {
  if (Platform.isWindows) {
    return _createWindowsDriver();
  }
  if (Platform.isMacOS) {
    return MacosFullscreenDriver();
  }
  if (Platform.isLinux) {
    return LinuxFullscreenDriver();
  }
  return null; // Unsupported platform
}

static FullscreenDriver? _createWindowsDriver() {
  try {
    final driver = WindowsFullscreenDriver();
    final api = driver.apiForTesting;
    final hwnd = api.getFlutterHwnd();
    if (hwnd == 0 || !api.isWindow(hwnd)) {
      debugPrint('[WindowService] HWND invalid ($hwnd), fullscreen disabled');
      return null;
    }
    return driver;
  } on Exception catch (e) {
    debugPrint('[WindowService] WindowsFullscreenDriver init failed: $e');
    return null;
  }
}
```

### main.dart — Simplified Initialization

```dart
// Before:
final driver = DesktopFullscreenDriverFactory.create();
final windowService = WindowService(fullscreenDriver: driver);

// After:
final windowService = WindowService(); // Driver created internally in init()
```

### FullscreenResult Usage in setMode

```dart
@override
Future<void> setMode(WindowMode target) async {
  if (_disposed || target == _state.mode.value) return;
  switch (target) {
    case WindowMode.windowed:
      if (_state.mode.value == WindowMode.fullscreen) {
        _state.mode.value = WindowMode.windowed;
        final result = await _handleLeave();
        if (result is FullscreenFailure) {
          _state.mode.value = WindowMode.fullscreen;
        }
      } else if (_state.mode.value == WindowMode.maximized) {
        await windowManager.unmaximize();
      }
    case WindowMode.fullscreen:
      _state.mode.value = WindowMode.fullscreen;
      final result = await _handleEnter();
      if (result is FullscreenFailure) {
        _state.mode.value = WindowMode.windowed;
      }
    // ... other cases
  }
}
```

## Runtime State Inventory

> This is a rename/refactor phase — fullscreen state ownership is being consolidated.

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | SharedPreferences key `isFullscreen` (bool) — saved by `SettingsStore.saveIsFullscreen`, never loaded back by `_loadImpl` | Remove save method, remove key constant. Dead code. |
| Live service config | None — fullscreen state is runtime-only via `WindowService._isFullscreen` ValueNotifier | No action needed |
| OS-registered state | None — Win32 window styles (WS_THICKFRAME etc.) are runtime-only, set/removed per fullscreen toggle | No action needed |
| Secrets/env vars | None — no fullscreen-related env vars | No action needed |
| Build artifacts | None — no fullscreen-related build artifacts | No action needed |

**Key finding:** `SettingsStore.saveIsFullscreen` is dead code. The method exists (line 228) and `WindowPersistence.saveIsFullscreen` calls it (line 53), but `SettingsStore._loadImpl()` never reads `_keyIsFullscreen` back into `AppSettings`. The `AppSettings.isFullscreen` field defaults to `false` and is never populated from SharedPreferences. This confirms D-08: remove the dead persistence path.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| DesktopFullscreenDriver (window_manager) | WindowsFullscreenDriver (Win32 FFI) | v1.5 (D-P05) | WS_THICKFRAME 7px gap solved |
| SC_MAXIMIZE for fullscreen | SetWindowPos atomic update | v1.5 (D-P06) | No frame flash |
| No focus recovery | setForegroundWindow + setFocus | v1.5 (D-P07) | Focus restored after leave |
| TopMost leak | HWND_NOTOPMOST cleanup | v1.5 (D-P08) | No always-on-top residue |
| 12 FFI calls (standard path) | 5 FFI calls (fast path) | v1.6 (PERF-03) | 58% fewer FFI round-trips |
| 20x polling confirmation | Callback + single query | This phase (D-12) | 2s worst case -> ~500ms |
| 7 error types | Sealed class (FullscreenResult) | This phase (D-11) | Exhaustive matching, simpler |
| DesktopFullscreenDriverFactory | Inlined in WindowService | This phase (D-02) | One fewer file, one fewer layer |

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| user32.dll | Win32 FFI | ✓ | Windows 11 | — |
| Flutter SDK | Build | ✓ | 3.x | — |
| window_manager | WindowService | ✓ | ^0.5.2 | — |
| fullscreen_window (local) | macOS/Linux drivers | ✓ | local package | — |

**Missing dependencies with no fallback:** none
**Missing dependencies with fallback:** none

## Validation Architecture

> nyquist_validation is enabled in config.json.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (Dart SDK) |
| Config file | analysis_options.yaml |
| Quick run command | `flutter test test/platform/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FULL-01 | Layers reduced from 4 to 3 | unit | `flutter test test/platform/windows_fullscreen_driver_test.dart` | ✅ |
| FULL-01 | DesktopFullscreenDriver deleted | unit | Verify no imports of deleted file | Wave 0 |
| FULL-02 | flutter_fullscreen evaluation document exists | manual | Check `.planning/research/` | Wave 0 |
| FULL-03 | SettingsStore.saveIsFullscreen removed | unit | Verify no references to removed method | Wave 0 |
| FULL-03 | WindowService owns fullscreen state | unit | `flutter test test/platform/` | ✅ |
| — | Fullscreen enter/leave regression | unit | `flutter test test/platform/windows_fullscreen_driver_test.dart` | ✅ |
| — | Confirmation chain works | unit | `flutter test test/platform/` | ✅ |

### Sampling Rate
- **Per task commit:** `flutter test test/platform/`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/window_service_init_test.dart` — covers inlined platform detection (D-02)
- [ ] `test/fullscreen_result_test.dart` — covers sealed class exhaustive matching (D-11)
- [ ] Verify deletion: no test files import `desktop_fullscreen_driver.dart` or `desktop_fullscreen_driver_factory.dart`

### Existing Test Coverage
- `test/platform/windows_fullscreen_driver_test.dart` — 765 lines, covers FFI driver
- `test/platform/macos_fullscreen_driver_test.dart` — macOS driver
- `test/platform/linux_fullscreen_driver_test.dart` — Linux driver
- `test/platform/fullscreen_driver_factory_test.dart` — Factory tests (will need update after D-02)

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Desktop media player, no auth |
| V3 Session Management | no | No sessions |
| V4 Access Control | no | No access control |
| V5 Input Validation | yes | Window style values validated before FFI calls (existing pattern) |
| V6 Cryptography | no | No crypto operations |

### Known Threat Patterns for Win32 FFI

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| FFI memory leak | Denial of Service | calloc.free() in finally blocks (existing pattern, verified) |
| Invalid HWND access | Tampering | isWindow() check before FFI calls (existing pattern) |
| Style bit corruption | Elevation of Privilege | Defensive verification after setWindowLong (existing pattern) |

## Sources

### Primary (HIGH confidence)
- Direct codebase reading: `window_service.dart` (451 lines), `windows_fullscreen_driver.dart` (459 lines), `win32_fullscreen_ffi.dart` (509 lines), `fullscreen_driver.dart` (55 lines), `desktop_fullscreen_driver.dart` (52 lines), `desktop_fullscreen_driver_factory.dart` (100 lines)
- Memory reference: `reference_flutter_fullscreen_package.md` — flutter_fullscreen v1.2.0 reverse analysis
- Memory reference: `reference_fullscreen_window_reverse.md` — fullscreen_window v1.2.1 reverse analysis
- Architecture docs: `.planning/codebase/ARCHITECTURE.md`, `CONCERNS.md`, `STRUCTURE.md`
- Context docs: `.planning/phase-1/01-CONTEXT.md` — all 16 locked decisions

### Secondary (MEDIUM confidence)
- Existing test files: `test/platform/` — confirms current test coverage

### Tertiary (LOW confidence)
- None — all findings verified against source code

## Assumptions Log

> All claims in this research were verified against source code or existing memory references. No assumptions needed.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| — | No assumptions | — | — |

## Open Questions

1. **Should `_isFullscreen` be removed in favor of deriving from `mode.value.isFullscreen`?**
   - What we know: Both `_isFullscreen` and `_state.mode` exist and can desync
   - What's unclear: Whether all consumers use `_isFullscreen` directly or go through `mode`
   - Recommendation: Remove `_isFullscreen`, add `isFullscreen` getter to WindowService that returns `mode.value.isFullscreen`. This eliminates dual state source.

2. **How to handle `AppSettings.isFullscreen` field after removing persistence?**
   - What we know: `AppSettings.isFullscreen` exists but is never populated from SharedPreferences
   - What's unclear: Whether any code reads `AppSettings.isFullscreen`
   - Recommendation: Remove the field from `AppSettings` if no code reads it. Keep if needed for settings export (Phase 4).

3. **Should `WindowPersistence.saveIsFullscreen` be kept for D-09 (WindowService manages persistence)?**
   - What we know: Current `saveIsFullscreen` calls `SettingsStore.saveIsFullscreen` (dead code)
   - What's unclear: Whether D-09 intends a different persistence mechanism
   - Recommendation: Keep `WindowPersistence` but change `saveIsFullscreen` to use a WindowService-owned persistence key, not SettingsStore.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all dependencies are existing, no new packages
- Architecture: HIGH — direct codebase reading, verified against source
- Pitfalls: HIGH — based on existing CONCERNS.md + code analysis + memory references

**Research date:** 2026-07-12
**Valid until:** 2026-08-12 (30 days — stable codebase, incremental refactor)
