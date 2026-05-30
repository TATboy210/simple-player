# Architecture Integration Research

**Project:** Simple Player Flutter v1.2
**Researched:** 2026-05-30
**Focus:** How v1.2 changes integrate with existing 3-layer architecture

---

## 1. FvpEngine Decomposition

### Current State

`FvpEngine` (690 lines) already uses 3 helper composition:
- `FvpCallbackHandler` — mdk callback registration, state mapping
- `PositionPoller` — 250ms timer position polling
- `TrackManager` — audio/subtitle track selection

Remaining responsibilities in the main file:
- 13 ValueNotifier declarations (~40 lines)
- Constants (network, D3D11, playback) (~20 lines)
- `_createPlayer()` + helper wiring (~25 lines)
- `_configureNetworkOptions()` — protocol-specific config (~50 lines)
- `_guardedAction()` — disposed check + try-catch (~10 lines)
- `open()` — file/URL validation, prepare, texture, media info extraction (~150 lines)
- Playback control: play/pause/stop/seekTo/skipForward/skipBack (~80 lines)
- Volume/mute control (~30 lines)
- Track delegation to TrackManager (~30 lines)
- Subtitle: external, delay, equalizer (~30 lines)
- Video effects: brightness/contrast/saturation/hue/rotate/aspect/deinterlace (~50 lines)
- D3D11 performance: sync, hardware decoding (~25 lines)
- dispose() — cleanup all notifiers + helpers (~25 lines)

### Decomposition Strategy

**Extract 2 new modules, keep FvpEngine as facade:**

| New Module | Responsibility | Lines (est.) |
|------------|---------------|--------------|
| `NetworkConfigurator` | `_configureNetworkOptions()` + protocol constants | ~70 |
| `VideoEffectsManager` | setVideoEffect, rotate, setAspectRatio, setDeinterlace + D3D11 settings | ~80 |

**FvpEngine remains:** ValueNotifiers, `_createPlayer()`, `open()`, playback control, volume, track delegation, dispose. (~450 lines)

**Why not extract more:**
- `open()` is the core method — extracting it would require passing 6+ ValueNotifiers and 3 helpers, creating a data class just for parameter passing
- Playback control (play/pause/stop/seek) are thin wrappers around `_player` — 5-10 lines each, not worth extraction
- Volume/mute logic has state coupling (auto-mute at 0) — extracting adds indirection for 15 lines

### Interface Preservation

`MediaEngine` abstract class (185 lines) is untouched. FvpEngine implements it. After decomposition:

```dart
class FvpEngine implements MediaEngine {
  // Existing ValueNotifiers (unchanged)
  // Existing helper composition (FvpCallbackHandler, PositionPoller, TrackManager)
  // NEW: NetworkConfigurator _networkConfig;
  // NEW: VideoEffectsManager _videoEffects;

  // open() delegates network config: _networkConfig.configure(url, _player)
  // Video effect methods delegate: _videoEffects.setBrightness(value, _player)
}
```

**No changes to MediaEngine interface.** No changes to FakeEngine. No changes to any consumer.

### Build Order

1. Extract `NetworkConfigurator` (pure function, no state, easy to test)
2. Extract `VideoEffectsManager` (stateless, delegates to `_player`)
3. Update FvpEngine to use new modules
4. Verify all existing tests pass (no interface change)

---

## 2. SettingsStore Simplification

### Current State

439 lines, 24+ individual save methods, all following identical pattern:

```dart
static Future<void> saveXxx(T value) => _save(
  'saveXxx',
  (p) => p.setXxx(_keyXxx, value.clamp(min, max)),
);
```

Plus `load()` (80 lines) building `AppSettings` from individual keys, and `saveAll()` (55 lines) writing all fields sequentially.

### Simplification Strategy

**Option A: Generic save with validator map (RECOMMENDED)**

```dart
// Validator registry — maps key to clamp/sanitize function
static final _validators = <String, dynamic Function(dynamic)>{
  _keyVolume: (v) => (v as double).clamp(0.0, 1.0),
  _keySubtitleFontSize: (v) => (v as double).clamp(14.0, 28.0),
  _keyVideoBrightness: (v) => (v as double).clamp(-1.0, 1.0),
  // ... etc
};

// Generic save — eliminates 20+ boilerplate methods
static Future<void> _saveValue<T>(String key, T value) => _save(
  'saveValue($key)',
  (p) async {
    final validated = _validators[key]?.call(value) ?? value;
    if (validated is double) await p.setDouble(key, validated);
    else if (validated is int) await p.setInt(key, validated);
    else if (validated is bool) await p.setBool(key, validated);
    else if (validated is String) await p.setString(key, validated);
  },
);
```

**Keep domain-specific methods for complex cases:**
- `saveWindowGeometry()` — multi-field atomic write
- `saveAll()` — batch write with null handling
- `saveShortcuts()` — JSON encode
- `loadLocale()`, `loadThemeIndex()`, `loadShortcuts()` — non-AppSettings loads

**Result:** ~20 individual save methods collapse to ~5 complex methods + generic helper.

**Option B: AppSettings.copyWith + saveAll (SIMPLER but different)**

Make `AppSettings` immutable with `copyWith`, always save via `saveAll()`:

```dart
// Instead of: SettingsStore.saveVolume(0.5)
// Do: final s = currentSettings.copyWith(volume: 0.5); SettingsStore.saveAll(s);
```

**Problem:** Requires callers to hold current settings reference. Breaks existing pattern where individual services save their own settings independently.

**Recommendation:** Option A. Preserves existing call patterns, eliminates boilerplate, keeps individual save methods as thin wrappers.

### Integration Points

- `VideoProcessingService` calls `SettingsStore.saveVideoBrightness/Contrast/Saturation/Hue/Rotation` individually with 50ms debounce
- `LocaleService` calls `SettingsStore.saveLocale()`
- `ThemeService` calls `SettingsStore.saveThemeIndex()`
- `WindowService` calls `SettingsStore.saveWindowGeometry()`
- `StateMonitor` calls `SettingsStore.saveLastFile()`

**After simplification:** Callers unchanged. Internal implementation uses generic helper.

### Build Order

1. Add `_saveValue<T>()` generic helper + validator map
2. Rewrite individual save methods as thin wrappers: `saveVolume(v) => _saveValue(_keyVolume, v)`
3. Verify all tests pass (no API change)
4. Optionally: deprecate individual methods, migrate callers to direct `_saveValue` calls

---

## 3. Singleton Migration

### Current Singletons

| Singleton | Pattern | Location | Consumers |
|-----------|---------|----------|-----------|
| `LocaleService.I` | Private constructor + static final | `lib/kernel/services/locale_service.dart` | `App`, settings dialog |
| `ThemeService.I` | Private constructor + static final | `lib/kernel/services/theme_service.dart` | `App`, settings dialog |
| `SettingsStore._cachedPrefs` | Static mutable field | `lib/kernel/persistence/settings_store.dart` | Everything |
| `ThumbnailService._impl` | Lazy static field | `lib/kernel/services/thumbnail_service.dart` | Playlist UI |
| `log` | Top-level final | `lib/kernel/utils/log.dart` | Everything |
| `win32` | Top-level final | `lib/kernel/bridge/win32_bindings.dart` | WindowService |

### Migration Strategy: Constructor Injection (NOT Service Locator)

**Why not get_it / service locator:**
- Adds dependency for a problem that doesn't exist at this scale
- Hides dependencies — you can't tell what a class needs from its constructor
- Flutter's widget tree IS a service locator via `InheritedWidget`

**Why constructor injection:**
- Explicit dependencies visible in constructor signature
- Testable — pass fakes/mocks via constructor
- No new dependencies
- Already used by `PlaybackController`, `PlayerServices`

### Migration Plan

**Phase 1: LocaleService + ThemeService (easy)**

These are only consumed by `App` (root widget) and settings dialog. Convert from singleton to instance created in `App`:

```dart
// Before
class LocaleService {
  LocaleService._();
  static final LocaleService I = LocaleService._();
  // ...
}

// After
class LocaleService {
  LocaleService();  // public constructor
  // ...
}

// In App
class _AppState extends State<App> {
  final _localeService = LocaleService();
  final _themeService = ThemeService();
  // Pass down via constructor or InheritedWidget
}
```

**Phase 2: SettingsStore (medium)**

`SettingsStore` is static class with static methods. Convert to instance with constructor-injected `SharedPreferences`:

```dart
// Before
class SettingsStore {
  static SharedPreferences? _cachedPrefs;
  static Future<void> saveVolume(double value) => _save(...);
}

// After
class SettingsStore {
  SettingsStore(this._prefs);
  final SharedPreferences _prefs;
  Future<void> saveVolume(double value) => _save(...);
}
```

**Problem:** `SettingsStore` is used by 8+ classes across all 3 layers. Converting to instance requires threading it through constructors everywhere.

**Pragmatic approach:** Keep `SettingsStore` as static for now. The `_cachedPrefs` singleton is already set once in `main.dart` and never changes. The real issue is testability — solve with `@visibleForTesting static void resetPrewarm()` (already exists).

**Phase 3: ThumbnailService (easy)**

Already has lazy `_impl`. Consumers only in playlist UI. Pass as constructor parameter to `PlaylistPanel`.

**Phase 4: log + win32 (skip)**

These are true globals — logger and FFI bindings. No benefit to injection. Keep as-is.

### Recommended Priority

1. **LocaleService + ThemeService** — low risk, high visibility, teaches the pattern
2. **ThumbnailService** — isolated consumer, easy win
3. **SettingsStore** — defer, static is acceptable for persistence layer
4. **log + win32** — skip, true globals

### Build Order

1. Make `LocaleService` + `ThemeService` constructors public
2. Create instances in `App` widget state
3. Pass to settings dialog via constructor
4. Remove `I` static accessor (breaking change, but only 2-3 consumers)
5. Repeat for `ThumbnailService`

---

## 4. FFI Safety Layer

### Current State

`WindowService` (329 lines) uses Win32 FFI via `win32_bindings.dart`:

```dart
// Direct FFI calls — no try/finally
final hwnd = await windowManager.getId();
final style = win32.getWindowLongPtr(hwnd, gwlStyle);
win32.setWindowLongPtr(hwnd, gwlStyle, newStyle);
win32.dwmExtendFrameIntoClientArea(hwnd, margins);
calloc.free(margins);
```

**Problems:**
- `calloc.free(margins)` not in `finally` block — if `dwmExtendFrameIntoClientArea` throws, memory leaks
- No timeout protection on async window operations
- `_fullscreenTransitioning` flag can get stuck if operation fails mid-way

### Safety Layer Strategy

**Add `FfiGuard` utility (NOT a wrapper class):**

```dart
/// Safe FFI execution with automatic memory cleanup
T ffiGuard<T>(Pointer pointer, T Function() action) {
  try {
    return action();
  } finally {
    calloc.free(pointer);
  }
}

/// Safe FFI execution with timeout + disposed check
Future<T> ffiGuardAsync<T>(
  bool disposed,
  Future<T> Function() action, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  if (disposed) throw StateError('Service disposed');
  return action().timeout(timeout);
}
```

### Integration Points in WindowService

**Where to add try/finally:**

1. `removeBorderImmediate()` — `calloc<Margins>()` needs `finally { calloc.free(margins) }`
2. `setFullscreen()` — `_savedFrame` allocation needs cleanup on failure
3. `setMaximized()` — `_savedMaximizeFrame` allocation needs cleanup

**Where to add timeout:**

1. `windowManager.getId()` — can hang if window not ready
2. `windowManager.getSize()` / `getPosition()` — can hang during transitions

**Where to add disposed check:**

1. All `WindowListener` callbacks — already have `if (_disposed)` guards
2. All public methods — some missing guards

### What NOT to Change

- **WindowService API** — no signature changes. Safety is internal.
- **win32_bindings.dart** — FFI type definitions are correct, no changes needed
- **MethodChannel path** — not used for critical operations (direct FFI is faster)

### Build Order

1. Add `ffiGuard` / `ffiGuardAsync` to `lib/kernel/utils/ffi_safety.dart`
2. Wrap `removeBorderImmediate()` allocations in `ffiGuard`
3. Wrap `setFullscreen()` / `setMaximized()` allocations
4. Add timeout to async window manager calls
5. Add disposed guards to any missing public methods
6. Verify WindowService tests pass

---

## Integration Summary

### New Files

| File | Layer | Purpose |
|------|-------|---------|
| `lib/kernel/engine/network_configurator.dart` | Kernel | Network stream protocol config |
| `lib/kernel/engine/video_effects_manager.dart` | Kernel | Video effect + D3D11 settings |
| `lib/kernel/utils/ffi_safety.dart` | Kernel | FFI guard utilities |

### Modified Files

| File | Change | Risk |
|------|--------|------|
| `lib/kernel/engine/fvp_engine.dart` | Delegate to new modules | LOW — no interface change |
| `lib/kernel/persistence/settings_store.dart` | Add generic save helper | LOW — internal only |
| `lib/kernel/services/locale_service.dart` | Public constructor | LOW — 2-3 consumers |
| `lib/kernel/services/theme_service.dart` | Public constructor | LOW — 2-3 consumers |
| `lib/kernel/bridge/window_service.dart` | Add ffiGuard calls | LOW — internal only |
| `lib/app.dart` | Create service instances | LOW — composition root |

### Unchanged

| File | Reason |
|------|--------|
| `lib/kernel/engine/media_engine.dart` | Interface stable |
| `lib/features/player/player_services.dart` | Already uses constructor injection |
| `lib/features/player/services/playback_controller.dart` | Already uses constructor injection |
| All UI files | No layer boundary changes |

### Build Order (Dependency-Aware)

```
Phase 1: FFI Safety (no dependencies)
  1. ffi_safety.dart
  2. WindowService ffiGuard integration

Phase 2: Engine Decomposition (no dependencies)
  3. NetworkConfigurator extraction
  4. VideoEffectsManager extraction
  5. FvpEngine delegation

Phase 3: SettingsStore (depends on nothing)
  6. Generic save helper
  7. Rewrite individual methods as wrappers

Phase 4: Singleton Migration (depends on Phase 3 for SettingsStore)
  8. LocaleService + ThemeService public constructors
  9. App widget instance creation
  10. ThumbnailService instance
```

Phases 1-3 are independent and can be parallelized. Phase 4 depends on Phase 3 only if SettingsStore is migrated (currently deferred).

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| FvpEngine decomposition | HIGH | Clear section boundaries, 3 existing helpers prove pattern works |
| SettingsStore simplification | HIGH | Pattern is obvious (20+ identical methods), generic helper is standard Dart |
| Singleton migration | MEDIUM | LocaleService/ThemeService easy, SettingsStore has 8+ consumers |
| FFI safety | HIGH | try/finally is straightforward, WindowService already has disposed guards |

## Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| FvpEngine extraction breaks callback wiring | LOW | Helpers already receive ValueNotifiers via constructor |
| SettingsStore generic loses type safety | LOW | Validator map provides runtime clamping, tests catch regressions |
| Singleton removal breaks settings dialog | LOW | Only 2-3 consumers, easy to update |
| FFI guard hides original exception | LOW | Use `rethrow` in catch, log before rethrow |
