# Phase 11: Performance Optimization - Research

**Researched:** 2026-05-30
**Domain:** Player performance tuning, rendering pipeline optimization, high-refresh-rate display support
**Confidence:** HIGH

## Summary

Phase 11 targets four performance areas: PositionPoller polling strategy, ThumbnailService LRU cache, D3D11 sync mode intelligence, and rendering pipeline audit. The codebase analysis reveals clear optimization opportunities in each area.

PositionPoller uses a fixed 250ms Timer.periodic that polls even when paused (stopped in FvpEngine.pause, but the timer architecture is wasteful). The ThumbnailService LRU cache uses Map + List with O(n) `_touch()` and `_evictIfNeeded()` operations -- replacing with LinkedHashMap gives O(1). The D3D11 sync mode is hardcoded to `d3d11.sync.cpu=1` (safe sync) and could benefit from intelligent switching based on display refresh rate. The rendering pipeline has been analyzed in prior research (fvp C++ plugin uses query fence, not Flush -- already optimized).

**Primary recommendation:** Focus on application-layer optimizations (PositionPoller, ThumbnailService, refresh-rate-aware D3D11 config) since the C++ plugin layer (fvp) already has query fence optimization. Avoid forking fvp -- the 0.37.1 upgrade may include further improvements.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Position polling | Kernel/Engine | -- | PositionPoller is engine-layer, no UI involvement |
| Thumbnail caching | Kernel/Services | -- | ThumbnailService is pure data layer |
| D3D11 sync config | Kernel/Engine | Kernel/Bridge | FvpEngine sets MDK properties; WindowBridge detects refresh rate |
| Rendering pipeline | Kernel/Engine (fvp) | UI/Player (VideoSurface) | fvp C++ plugin owns texture pipeline; VideoSurface owns widget tree |
| Display refresh rate detection | Kernel/Bridge | -- | Win32 FFI for EnumDisplaySettings |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| fvp | 0.36.2 (0.37.1 available) | MDK/FFmpeg video engine | Already in use, query fence already applied |
| dart:ffi | SDK built-in | Win32 API calls for refresh rate | Zero dependency, already used in win32_bindings.dart |
| flutter/painting | SDK built-in | LinkedHashMap for O(1) LRU | Standard Dart collection |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| window_manager | 0.5.1 | Window handle access | For monitorFromWindow in refresh rate detection |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| LinkedHashMap LRU | `lru_cache` package | Unnecessary dependency for ~20 lines of code |
| Win32 FFI refresh rate | `screen_retriever` package | Adds dependency for single API call |
| fvp 0.37.1 upgrade | Stay on 0.36.2 | 0.37.1 may have perf improvements; low-risk upgrade |

**Installation:** No new packages needed. All optimizations use Dart SDK built-ins and existing dependencies.

**Version verification:**
- fvp 0.36.2: verified via `flutter pub deps` [VERIFIED: flutter pub deps]
- fvp 0.37.1 available: verified via `flutter pub outdated` [VERIFIED: flutter pub outdated]
- dart:ffi: SDK built-in, version matches Dart 3.13.0 [VERIFIED: flutter pub deps]

## Package Legitimacy Audit

> No new packages are installed in this phase. All optimizations use existing dependencies.

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| fvp | pub.dev | 3+ years | established | github.com/nicmusic/fvp | N/A (Dart) | Already installed, upgrade to 0.37.1 optional |
| dart:ffi | Dart SDK | N/A | N/A | N/A | N/A | Built-in, no install needed |

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

*slopcheck is npm-only; Dart packages verified via `flutter pub deps` and pub.dev.*

## Architecture Patterns

### System Architecture Diagram

```
                    ┌─────────────────────────────────────┐
                    │         Display Refresh Rate         │
                    │    (Win32 EnumDisplaySettings)       │
                    └──────────────┬──────────────────────┘
                                   │ Hz value
                                   v
┌──────────────┐    ┌──────────────────────────────────────┐
│ PositionPoller│    │         FvpEngine                     │
│  250ms Timer  │───>│  d3d11.sync.cpu (0 or 1)             │
│  → ValueNotifier│   │  video.decoders                      │
└──────────────┘    │  → mdk.Player.setProperty()           │
                    └──────────────┬───────────────────────┘
                                   │ MDK properties
                                   v
                    ┌──────────────────────────────────────┐
                    │     fvp C++ Plugin (fvp_plugin.cpp)    │
                    │  CopyResource + Query Fence            │
                    │  → Flutter TextureRegistrar            │
                    └──────────────┬───────────────────────┘
                                   │ DXGI shared handle
                                   v
                    ┌──────────────────────────────────────┐
                    │     VideoSurface (Flutter Widget)      │
                    │  Texture widget + FittedBox.contain    │
                    └──────────────────────────────────────┘
```

### Recommended Project Structure

```
lib/kernel/
├── engine/
│   ├── position_poller.dart      # OPTIMIZE: adaptive polling interval
│   ├── fvp_engine.dart           # OPTIMIZE: refresh-rate-aware D3D11 config
│   └── display_config.dart       # NEW: refresh rate detection + D3D11 policy
├── services/
│   └── thumbnail_service.dart    # OPTIMIZE: LinkedHashMap LRU
└── bridge/
    └── win32_bindings.dart       # EXTEND: EnumDisplaySettings for refresh rate
```

### Pattern 1: Adaptive Position Polling

**What:** Reduce polling frequency when playback is stable (no seek, no speed change), increase when user is actively seeking.

**When to use:** Timer-based polling where the polled value changes predictably (monotonically increasing position during playback).

**Example:**
```dart
// Current: fixed 250ms interval
static const _pollIntervalMs = 250;

// Proposed: adaptive interval based on state
static const _activePollMs = 100;    // seeking or speed change
static const _normalPollMs = 250;    // steady playback
static const _idlePollMs = 1000;     // paused (if needed for buffered updates)

void _updateInterval(int ms) {
  _timer?.cancel();
  _timer = Timer.periodic(Duration(milliseconds: ms), (_) => _poll());
}
```

**Source:** [ASSUMED] -- adaptive polling is a standard pattern, no specific MDK documentation needed.

### Pattern 2: LinkedHashMap LRU Cache

**What:** Replace Map+List with LinkedHashMap for O(1) LRU operations.

**When to use:** Any LRU cache where access patterns are frequent (ThumbnailService.getThumbnail called on every playlist item hover).

**Example:**
```dart
// Source: Dart SDK LinkedHashMap documentation
// Before: Map + List (O(n) touch/evict)
static final _cache = <String, ImageProvider>{};
static final _order = <String>[];
static void _touch(String filePath) {
  _order.remove(filePath);  // O(n)
  _order.add(filePath);
}

// After: LinkedHashMap (O(1) touch/evict)
static final _cache = LinkedHashMap<String, ImageProvider>();
static void _touch(String filePath) {
  final value = _cache.remove(filePath);  // O(1)
  if (value != null) _cache[filePath] = value;  // O(1), moves to end
}
```

### Pattern 3: Refresh-Rate-Aware D3D11 Config

**What:** Detect display refresh rate via Win32 API and set d3d11.sync.cpu accordingly.

**When to use:** At player creation time and on display change events.

**Example:**
```dart
// Win32 API for refresh rate detection
// Source: Microsoft Docs - EnumDisplaySettings
typedef EnumDisplaySettingsNative = Int32 Function(
    Pointer<Utf16>, Uint32, Pointer<DEVMODE>);
typedef EnumDisplaySettingsDart = int Function(
    Pointer<Utf16>, int, Pointer<DEVMODE>);

int getDisplayRefreshRate(int hwnd) {
  final hMonitor = win32.monitorFromWindow(hwnd, monitorDefaultToNearest);
  // ... get monitor device name via GetMonitorInfoW + MONITORINFOEX
  // ... call EnumDisplaySettings with ENUM_CURRENT_SETTINGS
  // ... return devMode.dmDisplayFrequency
}

// Policy: async on 120Hz+, sync on 60Hz
void _applyD3d11Defaults(mdk.Player p) {
  final refreshRate = DisplayConfig.getRefreshRate();
  final useAsync = refreshRate >= 120;
  p.setProperty('d3d11.sync.cpu', useAsync ? '0' : '1');
}
```

### Anti-Patterns to Avoid

- **Don't fork fvp for Tier 2 optimizations:** The C++ plugin already uses query fence (not Flush). Triple buffering and fence improvements require fvp fork -- defer to upstream.
- **Don't add packages for single API calls:** Win32 refresh rate detection needs 2-3 FFI function bindings, not a `screen_retriever` package.
- **Don't poll faster than display refresh:** PositionPoller at 100ms is already faster than most displays. Going below 100ms wastes CPU with no visual benefit.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| LRU cache | Custom doubly-linked list | LinkedHashMap (Dart SDK) | Built-in, O(1) remove+reinsert, tested |
| Refresh rate detection | Platform channel to C++ | dart:ffi EnumDisplaySettings | 3 FFI bindings, already have win32_bindings.dart |
| Timer management | Custom timer wheel | Timer.periodic + adaptive interval | Standard Dart, sufficient for single-player scenario |

**Key insight:** All three optimizations are achievable with Dart SDK built-ins. No new packages, no C++ forks, no platform channels.

## Runtime State Inventory

> Not a rename/refactor phase. Omitting.

## Common Pitfalls

### Pitfall 1: Refresh Rate Detection Race Condition
**What goes wrong:** Display refresh rate is detected at startup, but user connects external monitor or changes display settings at runtime.
**Why it happens:** EnumDisplaySettings returns current settings at call time, not a live subscription.
**How to avoid:** Re-detect refresh rate when `onWindowResize` fires (debounced) or when `window_manager` reports display change. Cache the value with a staleness check.
**Warning signs:** D3D11 sync mode doesn't match actual display refresh rate after monitor switch.

### Pitfall 2: LinkedHashMap Iteration Order
**What goes wrong:** Assuming LinkedHashMap iteration order is insertion order (it is, but only for Dart's implementation).
**Why it happens:** LinkedHashMap spec guarantees insertion order, but developers may confuse it with HashMap.
**How to avoid:** Use `remove(key)` + `[]= value` pattern to "move to end" -- this is the standard LRU touch operation. Document that iteration order = access order.
**Warning signs:** LRU eviction removes wrong entries.

### Pitfall 3: PositionPoller Adaptive Interval Jitter
**What goes wrong:** Frequent interval changes cause visible jitter in progress bar updates.
**Why it happens:** Changing Timer.periodic interval mid-playback creates a gap where no poll occurs.
**How to avoid:** Only change interval on state transitions (play/pause/seek), not on every position update. Use `_poll()` immediately after interval change to avoid gap.
**Warning signs:** Progress bar "jumps" after seek or speed change.

### Pitfall 4: d3d11.sync.cpu=0 Tearing on Low-End GPUs
**What goes wrong:** Async mode causes visible screen tearing on integrated GPUs.
**Why it happens:** Without CPU-GPU sync, MDK may write to the shared texture while Flutter reads it.
**How to avoid:** Default to sync mode (d3d11.sync.cpu=1) and only switch to async when refresh rate >= 120Hz AND the user enables it. Add a settings toggle for manual override.
**Warning signs:** Horizontal tear lines during fast motion scenes.

## Code Examples

Verified patterns from official sources:

### LinkedHashMap LRU Touch Operation
```dart
// Source: Dart SDK - dart:collection LinkedHashMap
import 'dart:collection';

class LruCache<K, V> {
  LruCache(this._maxSize);
  final int _maxSize;
  final _map = LinkedHashMap<K, V>();

  V? get(K key) {
    final value = _map.remove(key);
    if (value != null) _map[key] = value; // move to end
    return value;
  }

  void put(K key, V value) {
    _map.remove(key);
    _map[key] = value;
    if (_map.length > _maxSize) {
      _map.remove(_map.keys.first); // evict oldest
    }
  }
}
```

### Win32 EnumDisplaySettings FFI
```dart
// Source: Microsoft Docs - EnumDisplaySettingsW
// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-enumdisplaysettingsw

// DEVMODE struct (partial, only display frequency fields)
final class DEVMODE extends Struct {
  @Array(32)
  external Array<Utf16> dmDeviceName;
  @Uint16()
  external int dmSize;
  // ... padding ...
  @Uint32()
  external int dmDisplayFrequency;
  // ... other fields ...
}

// Constants
const enumCurrentSettings = 0; // ENUM_CURRENT_SETTINGS

// FFI binding
typedef EnumDisplaySettingsWNative = Int32 Function(
    Pointer<Utf16>, Uint32, Pointer<DEVMODE>);
typedef EnumDisplaySettingsWDart = int Function(
    Pointer<Utf16>, int, Pointer<DEVMODE>);
```

### Adaptive Polling Pattern
```dart
// Source: Standard Timer.periodic pattern
class PositionPoller {
  Timer? _timer;
  int _currentIntervalMs = 250;

  void _updateInterval(int newIntervalMs) {
    if (_currentIntervalMs == newIntervalMs) return;
    _currentIntervalMs = newIntervalMs;
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(milliseconds: _currentIntervalMs),
      (_) => _poll(),
    );
    _poll(); // immediate poll to avoid gap
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Flush() after CopyResource | Query fence (End + GetData) | fvp 0.36.2 (already applied) | Reduced GPU pipeline drain |
| Fixed 250ms polling | Adaptive polling | Phase 11 (this phase) | Lower CPU in steady state |
| Map+List LRU | LinkedHashMap LRU | Phase 11 (this phase) | O(1) instead of O(n) |
| Hardcoded d3d11.sync.cpu=1 | Refresh-rate-aware config | Phase 11 (this phase) | Async on 120Hz+ displays |

**Deprecated/outdated:**
- fvp 0.36.2: 0.37.1 available, may contain performance improvements. Check changelog before upgrading.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | mdk.Player has no position callback (only polling) | PositionPoller | If callback exists, could eliminate polling entirely |
| A2 | EnumDisplaySettings returns current refresh rate reliably | D3D11 sync | Some drivers may report incorrect values |
| A3 | d3d11.sync.cpu=0 is safe on 120Hz+ displays | D3D11 sync | May still tear on some 120Hz panels |
| A4 | LinkedHashMap.remove+[]= is O(1) | LRU cache | Verified by Dart SDK docs, low risk |
| A5 | fvp 0.37.1 is backward-compatible with 0.36.2 | fvp upgrade | Need to check changelog before upgrading |
| A6 | Display refresh rate doesn't change during playback session | D3D11 sync | Monitor hotplug could invalidate cached value |

## Open Questions

1. **Does mdk.Player support position callbacks?**
   - What we know: FvpCallbackHandler registers onStateChanged and onMediaStatus callbacks. Position is polled via Timer.
   - What's unclear: Whether mdk.Player has an onPositionChanged event or similar callback.
   - Recommendation: Check fvp 0.37.1 changelog and mdk.Player API. If callback exists, eliminate polling entirely.

2. **Is fvp 0.37.1 backward-compatible?**
   - What we know: Current version 0.36.2, latest 0.37.1.
   - What's unclear: Breaking changes in 0.37.x.
   - Recommendation: Read CHANGELOG.md for 0.37.0 and 0.37.1 before upgrading. Run full test suite after upgrade.

3. **Should refresh rate detection be cached or live?**
   - What we know: EnumDisplaySettings is a synchronous Win32 call.
   - What's unclear: Performance cost of calling it on every resize event.
   - Recommendation: Cache with 5-second staleness. Re-detect on window move to different monitor.

4. **What does the rendering pipeline audit entail?**
   - What we know: fvp C++ plugin uses CopyResource + query fence. No Flush().
   - What's unclear: Whether there are application-layer rendering inefficiencies (widget rebuilds, texture allocation).
   - Recommendation: Audit VideoSurface widget tree for unnecessary rebuilds. Check if RepaintBoundary is optimally placed.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| fvp | D3D11 sync, rendering | ✓ | 0.36.2 (0.37.1 avail) | -- |
| dart:ffi | Win32 refresh rate | ✓ | SDK 3.13.0 | -- |
| Win32 EnumDisplaySettings | Refresh rate detection | ✓ | user32.dll (Windows 11) | Hardcode 60Hz assumption |
| LinkedHashMap | LRU cache | ✓ | SDK built-in | -- |
| Timer.periodic | Position polling | ✓ | SDK built-in | -- |

**Missing dependencies with no fallback:** none

**Missing dependencies with fallback:** none

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK built-in) |
| Config file | none (default flutter_test config) |
| Quick run command | `flutter test` |
| Full suite command | `flutter test` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PERF-04 | PositionPoller adaptive interval | unit | `flutter test test/kernel/engine/position_poller_test.dart` | Yes (minimal) |
| PERF-04 | ThumbnailService O(1) LRU | unit | `flutter test test/kernel/services/thumbnail_service_test.dart` | Yes (minimal) |
| PERF-04 | D3D11 sync mode switching | unit | `flutter test test/kernel/engine/fvp_engine_test.dart` | No (Wave 0) |
| PERF-04 | Refresh rate detection | unit | `flutter test test/kernel/bridge/display_config_test.dart` | No (Wave 0) |
| PERF-04 | Rendering pipeline audit | manual | N/A (document findings) | N/A |

### Sampling Rate

- **Per task commit:** `flutter test` (quick run)
- **Per wave merge:** `flutter test` (full suite)
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `test/kernel/engine/position_poller_test.dart` -- expand beyond compilation check; test adaptive interval behavior
- [ ] `test/kernel/services/thumbnail_service_test.dart` -- add LRU ordering tests (eviction order, touch-to-end)
- [ ] `test/kernel/engine/fvp_engine_test.dart` -- test D3D11 config application (may need FakeEngine mock)
- [ ] `test/kernel/bridge/display_config_test.dart` -- test refresh rate detection (mock Win32 FFI)

## Security Domain

> security_enforcement is enabled (absent from config = enabled).

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | -- |
| V3 Session Management | no | -- |
| V4 Access Control | no | -- |
| V5 Input Validation | no | Performance tuning only, no user input |
| V6 Cryptography | no | -- |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| FFI pointer leak in refresh rate detection | Information Disclosure | Use Arena/try/finally for DEVMODE allocation (same pattern as Phase 9) |

**Assessment:** This phase has minimal security surface. The only new FFI call (EnumDisplaySettings) follows the same safe allocation patterns established in Phase 9.

## Sources

### Primary (HIGH confidence)
- `lib/kernel/engine/position_poller.dart` -- current implementation, 250ms fixed interval [VERIFIED: codebase]
- `lib/kernel/services/thumbnail_service.dart` -- current LRU implementation, Map+List [VERIFIED: codebase]
- `lib/kernel/engine/fvp_engine.dart` -- D3D11 sync config, _applyD3d11Defaults() [VERIFIED: codebase]
- `fvp-0.36.2/windows/fvp_plugin.cpp` -- query fence already applied, CopyResource pattern [VERIFIED: pub cache]
- `lib/kernel/bridge/win32_bindings.dart` -- existing FFI bindings pattern [VERIFIED: codebase]
- `.planning/phases/03-performance-optimization/PERFORMANCE.md` -- prior Phase 3 perf work [VERIFIED: codebase]
- MEMORY: reference_fvp_performance_bottlenecks -- 9 bottlenecks ranked [VERIFIED: prior research]
- MEMORY: reference_fvp_optimization_plan -- 3-tier optimization plan [VERIFIED: prior research]

### Secondary (MEDIUM confidence)
- Dart SDK LinkedHashMap documentation -- O(1) remove+insert [CACHED: Dart SDK]
- Microsoft Docs EnumDisplaySettingsW -- refresh rate API [CACHED: Microsoft Docs]

### Tertiary (LOW confidence)
- Adaptive polling interval pattern -- standard pattern, no specific source [ASSUMED]
- d3d11.sync.cpu=0 safety on 120Hz+ -- no hardware test data available [ASSUMED]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all components are existing dependencies, no new packages
- Architecture: HIGH -- follows existing patterns (ValueNotifier, FFI bindings, Timer)
- Pitfalls: MEDIUM -- refresh rate detection and D3D11 async safety need hardware validation

**Research date:** 2026-05-30
**Valid until:** 2026-06-13 (14 days -- fvp upgrade cadence is fast-moving)
