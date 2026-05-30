# Feature Landscape: v1.2 Improvements

**Domain:** Flutter desktop media player (Win32 FFI, fvp/MDK engine)
**Researched:** 2026-05-30
**Confidence:** HIGH (codebase analysis + existing patterns)

## Table Stakes

Features the v1.2 milestone explicitly targets. Missing any = incomplete milestone.

### 1. FFI Pointer Lifecycle Safety

**Why Expected:** SEC-01 in PROJECT.md. WindowService has 6 `calloc` calls with manual `free()` — `_savedFrame`, `_savedMaximizeFrame`, margins, MonitorInfo. One leaked free path in `_exitFullscreen()` when `_savedFrame` is null after an exception leaves native memory orphaned. `dispose()` only frees `_savedMaximizeFrame`, not `_savedFrame`.

**Current State:**
- `WindowService._enterFullscreen()`: allocates `_savedFrame` (Rect), margins (Margins), mi (MonitorInfo). Each `calloc.free()` is called inline — but if an exception occurs between alloc and free, the pointer leaks.
- `WindowService.maximize()`: allocates frame + `_savedMaximizeFrame` + mi. Same pattern.
- No `Arena`, `NativeFinalizer`, or `Finalizer` usage anywhere in the codebase (confirmed via grep).
- `_savedFrame` is a field (`Pointer<Rect>?`) — freed in `_exitFullscreen()` and `dispose()` only for `_savedMaximizeFrame`.

**Complexity:** Medium

**Recommended Pattern: Arena for scoped allocations + try/finally for field-held pointers**

```dart
// Scoped allocations (margins, MonitorInfo) — use Arena
using((Arena arena) {
  final margins = arena<Margins>()
    ..ref.left = -1
    ..ref.right = -1
    ..ref.top = -1
    ..ref.bottom = -1;
  win32.dwmExtendFrameIntoClientArea(hwnd, margins);
  // auto-freed when scope exits
});

// Field-held pointers (_savedFrame, _savedMaximizeFrame) — use try/finally
try {
  _savedFrame = calloc<Rect>();
  // ... use _savedFrame ...
} on Exception catch (e) {
  if (_savedFrame != null) {
    calloc.free(_savedFrame!);
    _savedFrame = null;
  }
  rethrow;
}
```

**Why not NativeFinalizer:** NativeFinalizer requires a `Finalizable` Dart object wrapping the native pointer. For short-lived Win32 structs (Rect, Margins, MonitorInfo) used in a single method call, Arena is simpler. For long-lived pointers (`_savedFrame` that persists across fullscreen enter/exit), `try/finally` is the idiomatic Dart pattern — the pointer lifetime is tied to a logical operation, not a Dart object's GC.

**Dependencies:** `package:ffi` (already a transitive dependency via fvp)

---

### 2. Input Validation Hardening

**Why Expected:** SEC-02 in PROJECT.md. PathValidator exists but is incomplete.

**Current State:**
- `PathValidator.validate()`: checks empty, URL, path traversal (`../`, `..\\`, UNC `\\`, `~`), null byte, extension whitelist.
- Missing: URL structure validation (no `Uri.tryParse`), no path length limit, no symlink resolution, no check for control characters.
- `FvpEngine.open()` does file existence check but passes URL straight to MDK without structural validation.

**Complexity:** Low-Medium

**Recommended additions:**

```dart
// URL structural validation — prevent injection
static String? validateUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return 'Invalid URL: $url';
  if (!_urlSchemes.any((s) => url.startsWith(s))) {
    return 'Unsupported protocol: ${uri.scheme}';
  }
  // Block file:// and data: schemes
  if (uri.scheme == 'file' || uri.scheme == 'data') {
    return 'Blocked protocol: ${uri.scheme}';
  }
  return null;
}

// Path length limit (Windows MAX_PATH = 260, UNC = 32767)
static const _maxPathLength = 1024; // reasonable desktop limit

// Control character check (bytes < 0x20 except tab/newline)
static bool _hasControlChars(String s) =>
    s.runes.any((r) => r < 0x20 && r != 0x09 && r != 0x0A && r != 0x0D);
```

**Dependencies:** None (pure Dart)

---

### 3. Structured Debug Logging

**Why Expected:** DBG-01 in PROJECT.md. Current logging is basic (`logger` package with PrettyPrinter).

**Current State:**
- `lib/kernel/utils/log.dart`: 135 lines. Global `Logger` instance. Debug=console, Release=console+rotating file.
- No structured categories, no performance timing, no diagnostic zones.
- Logging calls use `[ClassName]` prefix convention but no formal structure.

**Complexity:** Medium

**Recommended approach — incremental enhancement, not replacement:**

**a) Add `Timeline` tracing for performance-critical paths:**
```dart
import 'dart:developer';

Future<void> open(String path) async {
  final task = TimelineTask()..start('FvpEngine.open');
  try {
    // ... existing open logic ...
    task.finish(arguments: {'path': path, 'duration_ms': duration.value});
  } finally {
    // task.finish already called above, but guard against early return
  }
}
```

**b) Add log categories via named logger instances:**
```dart
// lib/kernel/utils/log.dart — add category factory
Logger createLog(String category) => Logger(
  printer: PrettyPrinter(methodCount: 0, ...),
  // same config, but category name enables filtering
);
```

**c) Keep the `logger` package** — it already provides levels, file rotation, and pretty printing. Don't replace with `dart:developer` log() — that's for DevTools, not production logging.

**Why not replace the logging system:** The existing `logger` + `_RotatingFileOutput` is solid. The improvement is adding `Timeline` for perf paths and structured context, not rewriting the output layer.

**Dependencies:** None (`dart:developer` is core Dart)

---

### 4. Large File Decomposition

**Why Expected:** ARCH-01 in PROJECT.md. `fvp_engine.dart` is 690 lines.

**Current State of large files:**
| File | Lines | Already Extracted | Remaining Concern |
|------|-------|-------------------|-------------------|
| `fvp_engine.dart` | 690 | FvpCallbackHandler, PositionPoller, TrackManager | Network config (50 lines), open() method (150 lines), video effects (30 lines) |
| `settings_store.dart` | 439 | None | 25+ individual save methods, load() is 95 lines |
| `window_service.dart` | 328 | None | Fullscreen + maximize logic, FFI pointer management |

**Complexity:** Medium

**Recommended decomposition strategy:**

**a) `fvp_engine.dart` (690 -> ~400): Extract `NetworkConfigurator`**
- `_configureNetworkOptions()` (50 lines) + protocol-specific constants -> `network_configurator.dart`
- `_applyD3d11Defaults()` (15 lines) -> same file or stays (too small to extract alone)
- `open()` stays — it's the core orchestration, splitting would hurt readability

**b) `settings_store.dart` (439 -> ~200): Generic save pattern**
- Current: 25+ `saveX(value)` methods that all follow `_save('name', (p) => p.setTYPE(key, clamp(value)))`.
- Extract: `_saveTyped<T>(String key, T value, T Function(T) clamp)` or use `AppSettings.copyWith` + `saveAll`.
- The `saveAll` method already exists and handles all fields. Individual saves can delegate to it:
```dart
static Future<void> saveVolume(double value) async {
  final current = await load();
  await saveAll(current.copyWith(volume: value.clamp(0.0, 1.0)));
}
```

**c) `window_service.dart` (328 -> ~250): Extract fullscreen/maximize FSM**
- `_enterFullscreen` + `_exitFullscreen` + `setFullscreen` + fullscreen state -> `fullscreen_manager.dart` (mixin or separate class)
- `maximize` + `restore` -> same file or `maximize_manager.dart`

**Anti-pattern to avoid:** `part/part of` directives. Dart's official guidance discourages them for file splitting — use composition/imports instead.

**Dependencies:** None (pure refactoring)

---

### 5. Singleton-to-DI Migration

**Why Expected:** ARCH-03 in PROJECT.md. 6 static mutable singletons identified.

**Current singletons:**
| Singleton | Pattern | Mutable State | Files Using |
|-----------|---------|---------------|-------------|
| `LocaleService.I` | `static final I = LocaleService._()` | `ValueNotifier<Locale>` | 5 files |
| `ThemeService.I` | `static final I = ThemeService._()` | `ValueNotifier<int>` | 5 files |
| `SettingsStore._cachedPrefs` | Static mutable field | `SharedPreferences?` | 15+ files |
| `ThumbnailService._impl` | Lazy static | `ThumbnailProvider?` + LRU cache | 3 files |
| `PerfMonitor.instance` | `static final _instance` | Metrics counters | 2 files |
| `OsdService.I` | `static final I = OsdService._()` | Overlay state | 3 files |

**Complexity:** High (touches 21+ files)

**Recommended approach: Incremental constructor injection, not `get_it`**

The project explicitly states "no Provider/Riverpod/Bloc" — adding `get_it` would be a new dependency that contradicts this constraint. Instead:

**Phase 1: Make singletons accept injection (backward compatible)**
```dart
class LocaleService {
  LocaleService({SettingsStore? settingsStore})
      : _settingsStore = settingsStore ?? SettingsStore();
  final SettingsStore _settingsStore;
  // ... remove static final I, keep as convenience
  static LocaleService? _default;
  static LocaleService get I => _default ??= LocaleService();
}
```

**Phase 2: Inject via constructor at composition root**
```dart
// PlayerServices (already the composition root) — inject dependencies
class PlayerServices {
  late final LocaleService localeService;
  late final ThemeService themeService;

  Future<void> init() async {
    localeService = LocaleService();
    themeService = ThemeService();
    // ... rest of init
  }
}
```

**Phase 3: Remove static `I` getters** (after all call sites migrated)

**Why not get_it:** The codebase uses `ValueNotifier` + manual composition via `PlayerServices`. Adding `get_it` introduces a service locator that hides dependencies. Constructor injection is simpler, testable, and consistent with the existing `PlayerServices` composition root pattern.

**Why incremental:** `LocaleService.I` and `ThemeService.I` are used in 5+ UI files each. Big-bang migration risks regressions. The backward-compatible `_default` getter allows gradual migration.

**Dependencies:** None (pure refactoring)

---

## Differentiators

Features that improve quality of life beyond the milestone requirements.

### 6. Fullscreen Timeout Protection

**Value:** Prevents fullscreen from getting stuck if Win32 API hangs or `_fullscreenTransitioning` flag gets stuck.

**Complexity:** Low

**Implementation:** Add a timeout timer to `setFullscreen()`:
```dart
Future<void> setFullscreen(bool value) async {
  if (_fullscreenTransitioning) return;
  _fullscreenTransitioning = true;
  final timeout = Timer(const Duration(seconds: 3), () {
    if (_fullscreenTransitioning) {
      _fullscreenTransitioning = false;
      log.e('WindowService: fullscreen transition timed out');
    }
  });
  try {
    if (value) await _enterFullscreen();
    else await _exitFullscreen();
  } finally {
    timeout.cancel();
    _fullscreenTransitioning = false;
  }
}
```

**Dependencies:** None

---

### 7. SettingsStore Key-Value Generic Pattern

**Value:** Reduces 439-line file to ~200 lines by eliminating 25+ boilerplate save methods.

**Complexity:** Low

**Implementation:**
```dart
// Generic typed save with clamping
static Future<void> _saveValue<T>(
  String key, T value, T Function(T) sanitize,
) => _save(key, (p) async {
  final safe = sanitize(value);
  if (safe is double) await p.setDouble(key, safe);
  else if (safe is int) await p.setInt(key, safe);
  else if (safe is bool) await p.setBool(key, safe);
  else if (safe is String) await p.setString(key, safe);
});

// Usage
static Future<void> saveVolume(double value) =>
    _saveValue(_keyVolume, value, (v) => v.clamp(0.0, 1.0));
```

**Dependencies:** None

---

### 8. Performance Timeline Tracing

**Value:** Enables Flutter DevTools timeline analysis for startup, open, and seek operations.

**Complexity:** Low

**Implementation:** Wrap 3-5 key methods with `TimelineTask`:
- `FvpEngine.open()` — measures load + prepare + texture time
- `PlaybackController.openAndPlay()` — end-to-end open latency
- `WindowService._enterFullscreen()` — fullscreen transition time

**Dependencies:** None (`dart:developer`)

---

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| `get_it` / service locator | Contradicts "no state management library" constraint; hides dependencies | Constructor injection via PlayerServices composition root |
| `part/part of` for file splitting | Dart officially discourages; creates hidden coupling | Separate files with explicit imports |
| Replace `logger` package | Working well, 135 lines, rotation implemented | Enhance with Timeline tracing, don't replace |
| Full Riverpod/Bloc migration | Out of scope per PROJECT.md | ValueNotifier preserved |
| NativeFinalizer for short-lived FFI structs | Over-engineering for 1-method-scoped pointers | Arena for scoped, try/finally for field-held |
| Custom FFI memory allocator | Unnecessary complexity | Use `calloc` from `package:ffi` (already imported) |

## Feature Dependencies

```
FFI Pointer Safety (1) ──> no dependencies (standalone)
Input Validation (2) ──> no dependencies (standalone)
Debug Logging (3) ──> no dependencies (standalone)
File Decomposition (4) ──> can be done in parallel with 1-3
Singleton-to-DI (5) ──> depends on 4 (SettingsStore simplification reduces migration surface)
Fullscreen Timeout (6) ──> depends on 1 (uses same try/finally pattern)
SettingsStore Generic (7) ──> standalone, simplifies 5
Timeline Tracing (8) ──> depends on 3 (uses same log infrastructure)
```

## MVP Recommendation

Prioritize in this order:
1. **FFI Pointer Safety (1)** — prevents memory leaks in production, highest risk
2. **Input Validation (2)** — security hardening, low effort high value
3. **Fullscreen Timeout (6)** — 20 lines, prevents stuck state
4. **SettingsStore Generic (7)** — reduces code surface, simplifies DI migration
5. **File Decomposition (4)** — fvp_engine + settings_store splitting
6. **Singleton-to-DI (5)** — incremental migration, start with LocaleService + ThemeService
7. **Debug Logging (3)** — Timeline tracing for 3-5 methods
8. **Timeline Tracing (8)** — DevTools integration

Defer: None — all are table stakes for v1.2.

## Complexity Summary

| Feature | Complexity | Files Changed | Risk |
|---------|-----------|---------------|------|
| FFI Pointer Safety | Medium | 2 (window_service, win32_bindings) | Low — additive, doesn't change behavior |
| Input Validation | Low-Medium | 2 (path_validator, fvp_engine) | Low — additive checks |
| Debug Logging | Medium | 3-5 (log.dart, fvp_engine, playback_controller) | Low — additive |
| File Decomposition | Medium | 4-6 (fvp_engine, settings_store, window_service + new files) | Medium — refactoring risk |
| Singleton-to-DI | High | 21+ files | Medium — behavioral change across codebase |
| Fullscreen Timeout | Low | 1 (window_service) | Low — additive guard |
| SettingsStore Generic | Low | 1 (settings_store) | Low — internal refactor |
| Timeline Tracing | Low | 3-5 (same as debug logging) | Low — additive |

## Sources

- Codebase analysis: `lib/kernel/bridge/window_service.dart` (328 lines, 6 calloc sites)
- Codebase analysis: `lib/kernel/engine/fvp_engine.dart` (690 lines, 3 helpers extracted)
- Codebase analysis: `lib/kernel/persistence/settings_store.dart` (439 lines, 25+ save methods)
- Codebase analysis: `lib/kernel/utils/log.dart` (135 lines, logger + rotation)
- Codebase analysis: `lib/kernel/services/path_validator.dart` (92 lines)
- Codebase analysis: 6 singleton patterns across 21+ consuming files
- Dart FFI docs: `dart:ffi` Arena, NativeFinalizer, calloc patterns (HIGH confidence)
- Flutter architecture: ValueNotifier + composition root pattern (existing codebase convention)
- Project constraints: PROJECT.md — "no Provider/Riverpod/Bloc", "ValueNotifier preserved"
