# Phase 1: 旧架构移除 - Research

**Researched:** 2026-07-13
**Domain:** Win32 FFI fullscreen, Flutter window management, code deletion
**Confidence:** HIGH

## Summary

This phase completely removes the existing multi-layer fullscreen architecture: the `FullscreenDriver` abstract interface, 3 platform-specific drivers (Windows/Linux/macOS), Win32 FFI bindings, and associated models. The codebase currently has a 3-layer architecture (after the previous milestone's simplification): `WindowService` -> `FullscreenDriver` abstraction -> platform drivers. After this phase, only `WindowService` remains, which Phase 2 will wire directly to the `fullscreen_window` package.

The deletion is straightforward — 6 source files + 3 test files to delete, 4 files with imports to update. The main risk is that `WindowService` currently depends heavily on `FullscreenDriver` (constructor injection, `_handleEnter`/`_handleLeave`, `_waitForConfirmation`, `_onNativeFullScreenChanged`). Phase 1 deletes the abstraction but leaves WindowService's fullscreen logic intact (temporarily broken) — Phase 2 rewires it to `fullscreen_window`.

**Primary recommendation:** Delete files in dependency order (tests first, then drivers, then interface), update imports in WindowService to remove deleted references, and accept that `flutter analyze` will show errors in WindowService until Phase 2 completes the rewiring.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Fullscreen enter/leave | Service (WindowService) | — | Single coordinator for all window state |
| Platform fullscreen API | fullscreen_window package | — | Native plugin handles Win32/GTK/NSWindow |
| Fullscreen state sync | Service (WindowService) | UI (ValueNotifier) | mode.value.isFullscreen is single source of truth |
| Win32 FFI bindings | DELETED in this phase | — | Replaced by fullscreen_window C++ plugin |

## Standard Stack

### Core (already present, no new dependencies)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| fullscreen_window | local (v1.3.0) | Cross-platform fullscreen API | Vendored at packages/fullscreen_window/, provides setFullScreen + onFullScreenChanged stream |
| window_manager | ^0.5.2 | Window geometry, maximize, minimize | Already used for non-fullscreen window operations |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| fullscreen_window (current) | flutter_fullscreen | flutter_fullscreen depends on window_manager, cannot solve WS_THICKFRAME 7px gap. Decision: do not introduce (D-06 from previous milestone) |

## Package Legitimacy Audit

No new packages introduced in this phase. All dependencies are existing.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| fullscreen_window | local | — | — | packages/fullscreen_window/ (vendored) | OK | Approved (local package) |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### Current Architecture (before this phase)

```
WindowService
├── FullscreenDriver (abstract interface)
│   ├── WindowsFullscreenDriver (Win32 FFI)
│   │   └── Win32FullscreenApi (static FFI calls)
│   │   └── Win32FullscreenApiWrapper (mockable wrapper)
│   ├── LinuxFullscreenDriver (fullscreen_window plugin)
│   └── MacosFullscreenDriver (fullscreen_window plugin)
├── FullscreenCapability (model)
├── FullscreenResult (sealed class)
└── Confirmation chain (_waitForConfirmation + Completer)
```

### Target Architecture (after Phase 1 + Phase 2)

```
WindowService
├── fullscreen_window package (direct calls)
│   ├── FullScreenWindow.setFullScreen(true/false)
│   ├── onFullScreenChanged stream
│   └── isFullScreen() query
└── WindowMode ValueNotifier (UI state)
```

### Recommended Project Structure (after Phase 1)

```
lib/kernel/bridge/
├── window_bridge.dart          # Abstract interface (unchanged)
├── window_service.dart         # Coordinator (imports removed, Phase 2 rewires)
├── window_mode.dart            # Enum (unchanged)
├── window_state.dart           # State container (unchanged)
├── window_persistence.dart     # Geometry save/load (unchanged)
├── display_enumerator.dart     # Display enumeration (unchanged)
└── win32/
    └── win32_display_enumerator.dart  # Keep — unrelated to fullscreen

lib/kernel/models/
├── (fullscreen_capability.dart DELETED)
├── (other models unchanged)

test/platform/
├── (windows_fullscreen_driver_test.dart DELETED)
├── (linux_fullscreen_driver_test.dart DELETED)
└── (macos_fullscreen_driver_test.dart DELETED)
```

### Anti-Patterns to Avoid

- **Deleting files without updating imports first:** Will cause `flutter analyze` errors. Update WindowService imports before deleting source files.
- **Deleting regression tests without replacement:** smoke_suite_test.dart and high_risk_suite_test.dart test fullscreen behavior. They use MockFullscreenDriver which will be deleted. Phase 4 rewrites these tests — do NOT delete them in Phase 1, just update their imports.
- **Deleting FullscreenResult prematurely:** WindowService._handleEnter/_handleLeave return `FullscreenResult`. Phase 2 will change these return types, but Phase 1 should keep the sealed class temporarily or update WindowService to not use it.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Fullscreen enter/leave | Custom FFI bindings | fullscreen_window package | Package handles Win32/GTK/NSWindow natively |
| Fullscreen state sync | Manual polling | onFullScreenChanged stream | Package provides native callback stream |

## Common Pitfalls

### Pitfall 1: WindowService Compilation Errors After Deletion
**What goes wrong:** WindowService imports fullscreen_driver.dart, all 3 platform drivers, and win32_fullscreen_ffi.dart. Deleting these files without updating WindowService causes 10+ compile errors.
**Why it happens:** Import statements reference deleted files.
**How to avoid:** Remove imports and fullscreen-related fields/methods from WindowService in the same commit as file deletion. Phase 2 adds the new fullscreen_window integration.
**Warning signs:** `flutter analyze` shows "Target of URI doesn't exist" errors.

### Pitfall 2: Regression Tests Break
**What goes wrong:** smoke_suite_test.dart and high_risk_suite_test.dart define `_MockFullscreenDriver extends FullscreenDriver`. Deleting fullscreen_driver.dart breaks these tests.
**Why it happens:** Test classes inherit from deleted abstract class.
**How to avoid:** Either (a) rewrite tests to not use FullscreenDriver, or (b) defer test updates to Phase 4 and accept test failures temporarily. Option (b) is recommended — Phase 4 explicitly handles test updates.
**Warning signs:** `flutter test test/regression/` fails with "Undefined class 'FullscreenDriver'".

### Pitfall 3: FullscreenResult Used in WindowService
**What goes wrong:** WindowService._handleEnter and _handleLeave return `FullscreenResult`. The sealed class is defined in fullscreen_driver.dart. Deleting the file breaks these methods.
**Why it happens:** FullscreenResult is co-located with FullscreenDriver in the same file.
**How to avoid:** Either (a) move FullscreenResult to a separate file, or (b) remove the return types from _handleEnter/_handleLeave in this phase (Phase 2 will replace the entire method).
**Warning signs:** `flutter analyze` shows "Undefined class 'FullscreenResult'".

### Pitfall 4: Test Helper FakeWindowService Unaffected
**What goes wrong:** Assuming FakeWindowService needs changes.
**Why it happens:** FakeWindowService implements WindowBridge (not FullscreenDriver), so it's unaffected by this deletion.
**How to avoid:** Verify FakeWindowService has no FullscreenDriver imports — confirmed: it only imports window_bridge.dart and window_mode.dart.
**Warning signs:** None — this is a non-issue, but worth verifying.

## Code Examples

### WindowService Import Cleanup

Current imports to remove from `window_service.dart`:

```dart
// REMOVE these 4 imports:
import 'fullscreen_driver.dart';
import 'platform/linux_fullscreen_driver.dart';
import 'platform/macos_fullscreen_driver.dart';
import 'platform/windows_fullscreen_driver.dart';
```

### WindowService Field/Method Removals

Fields to remove:
```dart
// REMOVE:
final FullscreenDriver? _fullscreenDriver;
final Map<int, _RestoreSnapshot> _restoreSnapshots = {};
Completer<bool>? _confirmationCompleter;
```

Methods to remove or gut:
```dart
// REMOVE entirely:
static FullscreenDriver? _createDriver()
void _onNativeFullScreenChanged(int windowId, bool isFullscreen)
Future<FullscreenResult> _handleEnter(int windowId)
Future<FullscreenResult> _handleLeave(int windowId)
Future<void> _applyDesync()
Future<void> _captureRestoreSnapshot(int windowId)
Future<void> _restoreFromSnapshot(int windowId)
Future<bool> _waitForConfirmation(bool expectedFullscreen)
```

Constructor changes:
```dart
// BEFORE:
WindowService({DisplayEnumerator? displayEnumerator, FullscreenDriver? driver})
  : _displayEnumerator = displayEnumerator ?? Win32DisplayAdapter(),
    _fullscreenDriver = driver ?? _createDriver() {
  _fullscreenDriver?.onNativeStateChanged = _onNativeFullScreenChanged;
}

// AFTER (Phase 1 — temporary, Phase 2 adds fullscreen_window):
WindowService({DisplayEnumerator? displayEnumerator})
  : _displayEnumerator = displayEnumerator ?? Win32DisplayAdapter();
```

### fullscreen_window Package API (for reference, used in Phase 2)

```dart
// From packages/fullscreen_window/lib/fullscreen_window_platform_interface.dart
abstract class FullScreenWindowPlatform extends PlatformInterface {
  Future<void> setFullScreen(bool isFullScreen);
  Stream<bool> get onFullScreenChanged => const Stream.empty();
  Future<bool> isFullScreen() async => false;
}

// Usage:
import 'package:fullscreen_window/fullscreen_window.dart';
final fullScreenWindow = FullScreenWindowPlatform.instance;
await fullScreenWindow.setFullScreen(true);  // Enter fullscreen
await fullScreenWindow.setFullScreen(false); // Exit fullscreen
fullScreenWindow.onFullScreenChanged.listen((isFs) { ... }); // State stream
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| DesktopFullscreenDriver + Factory | _createDriver() inlined | Previous milestone (2026-07-12) | 2 files deleted, platform detection inlined |
| 20x polling confirmation | Completer + single query | Previous milestone (2026-07-12) | Simpler, faster |
| _isFullscreen ValueNotifier | mode.value.isFullscreen getter | Previous milestone (2026-07-12) | Single source of truth |
| FullscreenDriver abstraction | fullscreen_window direct calls | This phase (2026-07-13) | Removes entire driver layer |

**Deprecated/outdated:**
- FullscreenDriver abstract class: replaced by fullscreen_window package API
- Win32FullscreenApi static class: replaced by fullscreen_window C++ plugin
- Win32FullscreenApiWrapper: no longer needed (no mock injection)
- FullscreenCapability model: no longer needed (package handles platform differences)
- FullscreenResult sealed class: Phase 2 may use simpler error handling

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Phase 2 will rewire WindowService to fullscreen_window before any tests run | Summary | If Phase 2 is delayed, all fullscreen tests will fail |
| A2 | FullscreenResult can be removed from WindowService without Phase 2 impact | Pitfall 3 | Phase 2 may want to reuse the sealed class — low risk, can recreate |
| A3 | Regression tests (smoke/high_risk) can be broken temporarily | Pitfall 2 | If CI blocks on test failures, this is a problem |
| A4 | The platform/ directory can be fully deleted | Architecture | If any non-fullscreen files exist in platform/, they'd be lost — verified: only fullscreen drivers exist there |

## Open Questions

1. **Should FullscreenResult be preserved or deleted?**
   - What we know: WindowService._handleEnter/_handleLeave use it. Phase 2 replaces these methods.
   - What's unclear: Whether Phase 2 will want the sealed class pattern.
   - Recommendation: Delete it. Phase 2 can create simpler error handling if needed.

2. **Should regression tests be updated in Phase 1 or deferred to Phase 4?**
   - What we know: smoke_suite_test.dart and high_risk_suite_test.dart use MockFullscreenDriver.
   - What's unclear: Whether the project tolerates broken tests between phases.
   - Recommendation: Defer to Phase 4. Phase 1 focuses on source deletion, Phase 4 handles test updates.

3. **Should the win32/ directory be kept or deleted?**
   - What we know: win32/ contains win32_fullscreen_ffi.dart (to delete) and win32_display_enumerator.dart (to keep).
   - What's unclear: Whether to delete the directory or just the file.
   - Recommendation: Delete only win32_fullscreen_ffi.dart, keep win32_display_enumerator.dart and the directory.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| flutter | Build/analyze | ✓ | (from pubspec) | — |
| fullscreen_window | Phase 2 rewiring | ✓ | local v1.3.0 | — |

**Missing dependencies with no fallback:** none
**Missing dependencies with fallback:** none

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) |
| Config file | none — uses flutter test defaults |
| Quick run command | `flutter test test/unit/kernel/bridge/window_service_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ARCH-REM-01 | fullscreen_driver.dart + fullscreen_capability.dart deleted | grep | `grep -r "fullscreen_driver\|fullscreen_capability" lib/` returns 0 | After execution |
| ARCH-REM-02 | platform/ drivers deleted | file check | `ls lib/kernel/bridge/platform/` returns empty or dir deleted | After execution |
| ARCH-REM-03 | win32_fullscreen_ffi.dart deleted | file check | `test -f lib/kernel/bridge/win32/win32_fullscreen_ffi.dart` returns false | After execution |
| ARCH-REM-04 | Old test files deleted | file check | `ls test/platform/` returns empty or dir deleted | After execution |

### Sampling Rate

- **Per task commit:** `flutter analyze lib/` (must show no errors from deleted files)
- **Per wave merge:** `flutter analyze lib/` (full static analysis)
- **Phase gate:** `flutter analyze` passes with no errors related to deleted files

### Wave 0 Gaps

- None — this is a deletion phase, no new test infrastructure needed

## Security Domain

No security-relevant code is being modified. The deleted files are window management abstractions with no authentication, authorization, or input validation concerns.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | no | — |
| V6 Cryptography | no | — |

## Sources

### Primary (HIGH confidence)
- Codebase analysis — all files read directly, dependency chains traced via grep
- Previous milestone research (`.planning/phase-1/01-RESEARCH.md`) — architecture decisions documented
- fullscreen_window package source (`packages/fullscreen_window/lib/`) — API surface verified

### Secondary (MEDIUM confidence)
- Previous milestone verification (`.planning/phases/01-fullscreen-simplification/01-VERIFICATION.md`) — confirms prior deletions

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies, deletion of existing code
- Architecture: HIGH — file dependency chain fully traced via grep
- Pitfalls: HIGH — all risk areas identified from reading WindowService source

**Research date:** 2026-07-13
**Valid until:** 2026-08-13 (stable — this is a deletion task, not dependent on external changes)
