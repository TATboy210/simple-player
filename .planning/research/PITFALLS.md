# Domain Pitfalls: v1.2 Refactoring Risks

**Domain:** Flutter desktop media player refactoring
**Researched:** 2026-05-30
**Overall confidence:** HIGH (based on codebase analysis + established Dart/FFI patterns)

---

## 1. FFI try/finally Around Existing Pointer Code

### Pitfall 1a: Pointer Lifetime Assumption Breakage

**What goes wrong:** Wrapping FFI calls in try/finally can free pointers that are still referenced by other code paths. In `WindowService`, `_savedFrame` and `_savedMaximizeFrame` are allocated in one method and freed in a different method (`_exitFullscreen` / `restore` / `dispose`). Adding try/finally to `_enterFullscreen` that frees `_savedFrame` on exception would break `_exitFullscreen` which assumes the pointer is still valid.

**Why it happens:** The current code has implicit pointer ownership transfer: `_enterFullscreen` allocates `_savedFrame`, then `_exitFullscreen` reads and frees it. try/finally makes ownership boundaries explicit, but if the "finally" frees the pointer, the consumer method gets a use-after-free.

**Consequences:** Crash or undefined behavior when `_exitFullscreen` tries to read `_savedFrame.ref.left` after it was already freed by a try/finally in `_enterFullscreen`.

**Prevention:**
- Map pointer ownership BEFORE adding try/finally. Draw a lifecycle diagram: allocate -> use -> free. Each pointer must have exactly ONE owner at any time.
- For `_savedFrame`: owner is `_enterFullscreen` (alloc) -> `_exitFullscreen` (free). The try/finally in `setFullscreen` already correctly resets `_fullscreenTransitioning` without touching pointers.
- Add try/finally only to SHORT-LIVED pointers (allocated and freed within the same method scope), like the `frame`, `margins`, and `mi` temporaries in `_enterFullscreen`.

**Detection:** After adding try/finally, run the test suite. Any `StateError` or pointer access violation in `_exitFullscreen` or `restore` signals ownership conflict.

**Code reference:** `window_service.dart` lines 165-173 (`_savedFrame` alloc), 217-228 (`_savedFrame` free), 258-266 (`_savedMaximizeFrame` alloc), 305-306 (`_savedMaximizeFrame` free).

### Pitfall 1b: Double-Free on Exception Path

**What goes wrong:** If `_enterFullscreen` throws after allocating `_savedFrame` but before the method completes, and the existing `setFullscreen` try/finally resets state, a subsequent `_exitFullscreen` call may attempt to free `_savedFrame` again (if the pointer was partially set).

**Why it happens:** The guard `_savedFrame = null` on line 231 only runs if `_exitFullscreen` completes normally. If `_exitFullscreen` itself throws at line 218 (`setWindowPos`), the pointer leaks AND a retry could double-free.

**Prevention:**
```dart
// SAFE: null-check-then-free with immediate null
if (_savedFrame != null) {
  final ptr = _savedFrame!;
  _savedFrame = null;  // null BEFORE free
  calloc.free(ptr);
}
```
- Always null the reference BEFORE calling `calloc.free`, not after.
- This prevents double-free even if `calloc.free` throws (which it shouldn't, but defensive).

**Detection:** Add a test that simulates `_exitFullscreen` failure (mock `windowManager.getId()` to throw), then verify `dispose()` does not crash.

### Pitfall 1c: Arena Allocator Misuse

**What goes wrong:** Using `package:ffi`'s `Arena` allocator for pointers that outlive the Arena scope. Arena frees everything on scope exit, which is correct for temporaries but destroys long-lived pointers like `_savedFrame`.

**Prevention:** Only use Arena for truly temporary allocations (the `frame`, `margins`, `mi` pointers in `_enterFullscreen`/`_exitFullscreen`). Keep manual `calloc`/`free` for `_savedFrame` and `_savedMaximizeFrame` since they cross method boundaries.

**Phase:** SEC-01 (FFI memory safety)

---

## 2. Decomposing FvpEngine (690 lines)

### Pitfall 2a: Interface Breakage Cascade

**What goes wrong:** `MediaEngine` is a 185-line abstract interface with 30+ members. `FvpEngine` is the only production implementation, but `FakeEngine` (376 lines) also implements it. Extracting methods from `FvpEngine` into sub-classes requires either: (a) the sub-class holds a reference to `mdk.Player`, breaking the `MediaEngine` abstraction, or (b) a new internal interface is created, adding indirection.

**Why it happens:** `FvpEngine` mixes playback control, network configuration, track management, video effects, and D3D11 settings. These all need `_player` (the `mdk.Player` instance). Extracting `NetworkConfigurator` or `VideoEffectController` means they need the player reference, creating a new coupling surface.

**Consequences:** If extraction creates a new internal interface (e.g., `_PlayerAccessor`), every test that mocks `FakeEngine` must also mock the accessor. If extraction passes `mdk.Player` directly, the sub-classes become platform-specific and untestable with `FakeEngine`.

**Prevention:**
- Extract BEHAVIOR + STATE together. `NetworkConfigurator` should own the network-related constants and the `_configureNetworkOptions` method, receiving `mdk.Player` as a method parameter (not constructor injection).
- Keep `MediaEngine` interface unchanged. The decomposition is internal to `FvpEngine` — callers never see the sub-classes.
- Each extracted class should be independently testable with a mock player object, NOT through `FakeEngine`.

**Detection:** If any test file changes during decomposition, the extraction is leaking internals.

### Pitfall 2b: State Fragmentation

**What goes wrong:** `FvpEngine` has 12 `ValueNotifier` fields. If `VideoEffectController` is extracted, it might need access to `errorMessage` (for error reporting) and `state` (for state transitions). This creates a dependency from the sub-class back to the parent, defeating the purpose of extraction.

**Why it happens:** Error handling in `_guardedAction` updates both `errorMessage` and `_errorType`. If video effect methods are extracted, they need this error reporting mechanism.

**Prevention:**
- Extract an `ErrorHandler` mixin or callback pattern:
```dart
typedef ErrorCallback = void Function(String message, MediaErrorType type);

class VideoEffectController {
  final mdk.Player _player;
  final ErrorCallback _onError;
  // ...
}
```
- The parent `FvpEngine` passes its error handler to the sub-class.
- ValueNotifiers stay on `FvpEngine`. Sub-classes update state through callbacks, not direct ValueNotifier access.

**Detection:** If an extracted class imports `media_engine.dart` or holds a `ValueNotifier` reference, it has state fragmentation.

### Pitfall 2c: Breaking the _guardedAction Pattern

**What goes wrong:** `FvpEngine._guardedAction` wraps every operation with `_disposed` check + try-catch + error logging. Extracting methods means each sub-class needs its own guard, or the guard is lost.

**Prevention:** Extract `_guardedAction` into a shared utility (or keep it on `FvpEngine` and have sub-classes call back to it):
```dart
// On FvpEngine
void _guardedAction(String name, void Function() action) { ... }

// Sub-class calls parent's guard via callback
class D3D11Configurator {
  final mdk.Player _player;
  final void Function(String, void Function()) _guarded;
  // ...
  void setSyncEnabled(bool enabled) {
    _guarded('setD3d11SyncEnabled', () { ... });
  }
}
```

**Phase:** ARCH-01 (fvp_engine decomposition)

---

## 3. Migrating Singletons to DI

### Pitfall 3a: Test Breakage from Missing Reset

**What goes wrong:** The 6 singletons (`LocaleService.I`, `ThemeService.I`, `OsdService.I`, `PerfMonitor.instance`, `EnginePrewarm._prewarmed`, `ThumbnailService._cache`) use `static final` initialization. Tests that call `reset()` (where it exists) work. Tests that DON'T call `reset()` leak state. Migrating to DI without updating ALL test setUp/tearDown breaks tests that relied on implicit singleton lifecycle.

**Why it happens:** Singletons hide initialization. DI makes it explicit. A test that previously worked because `LocaleService.I` was already initialized from a prior test will fail when DI requires explicit registration.

**Prevention:**
- BEFORE migrating: Add `reset()` to every singleton that lacks it (`OsdService.I`, `EnginePrewarm`). Verify all tests call reset in tearDown.
- Migrate ONE singleton at a time. Run full test suite after each.
- Keep the static accessor (`X.I`) as a convenience that delegates to the DI container during production and to a test double during tests:
```dart
class LocaleService {
  static LocaleService get I => _di.get<LocaleService>();
  // ...
}
```

**Detection:** Run `flutter test` after each singleton migration. Any `StateError: Locale not initialized` or similar signals missing DI registration.

### Pitfall 3b: Circular Dependencies

**What goes wrong:** `LocaleService` depends on `SettingsStore` (static methods). `ThemeService` depends on `SettingsStore`. `SettingsStore` depends on `SharedPreferences` (static prewarm). If DI wiring requires constructor injection, and `SettingsStore` becomes non-static, then `LocaleService` -> `SettingsStore` -> `SharedPreferences` is a chain. If any service in the chain also needs `LocaleService` (e.g., for error messages), you get a cycle.

**Why it happens:** The current static pattern hides the dependency graph. DI makes it explicit, and cycles that were invisible become compile errors.

**Prevention:**
- Map the dependency graph BEFORE migration:
```
LocaleService -> SettingsStore -> SharedPreferences
ThemeService  -> SettingsStore -> SharedPreferences
OsdService    -> (no deps)
PerfMonitor   -> (no deps)
EnginePrewarm -> fvp (external)
ThumbnailService -> (no deps, static cache only)
```
- Migrate LEAF nodes first (OsdService, PerfMonitor) — they have no deps and no cycle risk.
- Keep `SettingsStore` as static methods. It's a utility, not a service. Converting it to injectable would force all dependents to accept it as a constructor parameter, adding noise for no benefit.

**Detection:** If `dart analyze` reports import cycles after migration, the DI graph has a cycle.

### Pitfall 3c: get_it vs Constructor Injection Inconsistency

**What goes wrong:** Mixing `get_it` service locator with constructor injection creates two dependency mechanisms. Some classes get deps via constructor, others via `GetIt.I<T>()`. Tests must now mock both patterns.

**Prevention:** Pick ONE mechanism:
- **Constructor injection** for all services (preferred — explicit, testable).
- **get_it** only at the composition root (main.dart) for wiring.
- NEVER call `GetIt.I<T>()` inside business logic. Always receive deps via constructor.

**Phase:** ARCH-03 (singleton migration)

---

## 4. Adding Validation to URL/Path Handling

### Pitfall 4a: False Rejection of Valid URLs

**What goes wrong:** `Uri.tryParse()` is stricter than FFmpeg's URL parser. Valid media URLs that FFmpeg handles correctly may fail Dart's `Uri` validation:
- `rtsp://user:pass@host/path` (credentials in URL)
- `srt://host:port?mode=caller&latency=50000` (query params with special chars)
- URLs with unencoded spaces (FFmpeg tolerates them)
- `udp://239.0.0.1:1234` (multicast — valid but no path component)

**Why it happens:** The current `PathValidator.isUrl()` only checks prefix (`startsWith`), which is permissive. Replacing it with `Uri.tryParse()` structural validation would reject URLs that FFmpeg handles fine.

**Prevention:**
- Keep prefix-based scheme detection (`isUrl`). Do NOT replace with `Uri.tryParse`.
- Add structural validation ONLY for http/https URLs (where `Uri.tryParse` is reliable):
```dart
static bool isValidUrl(String url) {
  if (!isUrl(url)) return false;
  // Only validate HTTP/HTTPS structure
  if (url.startsWith('http://') || url.startsWith('https://')) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.host.isNotEmpty;
  }
  // RTSP/RTMP/SRT/UDP/TCP — trust FFmpeg's parser
  return true;
}
```
- Never reject a URL that the current code accepts. Validation should only ADD checks for obviously malformed input (empty host, null bytes).

**Detection:** Add test cases for every URL scheme in `_urlSchemes`. If any existing test URL fails validation, the check is too strict.

### Pitfall 4b: Path Length False Rejection on Long Filenames

**What goes wrong:** Adding MAX_PATH (260) validation rejects valid paths on modern Windows with long path support enabled. Windows 10+ with registry key `LongPathsEnabled` supports paths up to 32,767 characters. FFmpeg also handles long paths.

**Why it happens:** The 260-char limit is a legacy Win32 API constraint, not a filesystem constraint. `File.exists()` in Dart handles long paths correctly.

**Prevention:**
- Do NOT add path length validation. `File.exists()` already handles invalid paths gracefully.
- If you must add a safety limit, use 32,767 (not 260).
- The current code's `File.exists()` check in `FvpEngine.open()` is sufficient.

**Detection:** Test with a 300-character path. If it's rejected, the limit is too low.

### Pitfall 4c: Null Byte Injection Already Handled

**What goes wrong:** Adding redundant null byte checks when `PathValidator.isPathTraversal` already checks for `\x00`. Over-validation adds maintenance burden and can conflict (one check rejects, another allows).

**Prevention:** The existing `PathValidator.isPathTraversal` at line 69 already checks `path.contains('\x00')`. Do not add duplicate checks. Focus validation effort on areas that are ACTUALLY missing (URL structure for http/https).

**Phase:** SEC-02 (input validation)

---

## 5. Adding Timeout Guards to Async Operations

### Pitfall 5a: Fullscreen Transition Timeout Race

**What goes wrong:** The `_fullscreenTransitioning` boolean guard (line 145) has no timeout. Adding a `Timer` that resets it after N seconds creates a race: if the timer fires AND the real transition completes, both paths execute, potentially calling `_exitFullscreen` while `_enterFullscreen` is still running.

**Why it happens:** The timer callback and the `finally` block in `setFullscreen` both set `_fullscreenTransitioning = false`. If the timer fires first, the guard is released, allowing a concurrent `setFullscreen(!value)` call that starts `_exitFullscreen` while the original `_enterFullscreen` is still awaiting `windowManager.getId()`.

**Consequences:** Both `_enterFullscreen` and `_exitFullscreen` run concurrently, both call `setWindowPos`, and the window flickers or ends up in an inconsistent state.

**Prevention:**
```dart
Timer? _fullscreenTimeout;

Future<void> setFullscreen(bool value) async {
  if (_fullscreenTransitioning) return;
  _fullscreenTransitioning = true;
  _fullscreenTimeout?.cancel();
  _fullscreenTimeout = Timer(const Duration(seconds: 2), () {
    if (_fullscreenTransitioning) {
      debugPrint('WindowService: fullscreen transition timed out');
      _fullscreenTransitioning = false;
    }
  });
  try {
    if (value) {
      await _enterFullscreen();
    } else {
      await _exitFullscreen();
    }
  } finally {
    _fullscreenTimeout?.cancel();
    _fullscreenTransitioning = false;
  }
}
```
- The `finally` block cancels the timer. If the timer already fired, the `finally` still runs (setting `_fullscreenTransitioning = false` again is idempotent).
- The timer callback checks `_fullscreenTransitioning` before resetting, avoiding unnecessary state changes.

**Detection:** Test with a simulated slow `windowManager.getId()` (add 3-second delay in FakeWindowService). Verify the timeout fires and subsequent calls work.

### Pitfall 5b: Future.timeout vs Manual Timer

**What goes wrong:** Using `Future.timeout()` on the Win32 API calls in `_enterFullscreen`/`_exitFullscreen` throws `TimeoutException`, which the existing try/finally in `setFullscreen` catches. But the Win32 API call (e.g., `setWindowPos`) is a synchronous FFI call — it doesn't return a Future. `Future.timeout()` only works on async operations.

**Why it happens:** `win32.setWindowPos(...)` is a synchronous native call. Wrapping it in `Future.timeout()` has no effect — the timeout never fires because the call blocks the isolate.

**Prevention:**
- For synchronous FFI calls, timeout must be implemented at the C++ level (not Dart).
- For async operations (`windowManager.getId()`, `windowManager.getSize()`), `Future.timeout()` works correctly.
- The fullscreen transition timeout should guard the OVERALL operation (the boolean flag), not individual FFI calls.

**Detection:** If adding `Future.timeout()` to a synchronous FFI call and the test shows the timeout never fires, this pitfall is active.

### Pitfall 5c: open() Prepare Timeout Already Exists

**What goes wrong:** `FvpEngine.open()` already has `_prepareTimeoutSeconds = 10` and `_textureTimeoutSeconds = 5` timeouts (lines 274, 351). Adding a SECOND timeout at a higher level (e.g., in `PlaybackController`) creates nested timeouts where the outer timeout fires before the inner one, causing confusing error messages.

**Prevention:**
- Do NOT add redundant timeouts. The existing `prepare().timeout()` and `updateTexture().timeout()` are sufficient.
- If adding a timeout guard to `setFullscreen`, it should be the ONLY timeout for that operation.
- Document which layer owns the timeout for each async operation.

**Detection:** If two timeouts can fire for the same operation, one is redundant.

**Phase:** SEC-01 (fullscreen timeout), SEC-02 (URL validation)

---

## Cross-Cutting Pitfalls

### Pitfall X1: SettingsStore Refactor Breaks Load/Save Symmetry

**What goes wrong:** `SettingsStore.load()` returns an `AppSettings` with 20+ fields, each with clamped defaults. `saveXxx()` methods write individual fields. Simplifying to "serialize entire object" breaks the per-field try-catch isolation — one corrupted field no longer prevents loading other fields.

**Prevention:** If switching to bulk serialization, keep per-field validation in the deserializer. The `_sanitizeDimension`/`_sanitizeCoordinate`/`_sanitizeRotation` helpers must survive the refactor.

**Phase:** ARCH-02 (SettingsStore simplification)

### Pitfall X2: FakeEngine Must Track New Sub-Class Calls

**What goes wrong:** After extracting `NetworkConfigurator` from `FvpEngine`, tests that verify `_configureNetworkOptions` behavior (6 protocol branches) must now either: test `NetworkConfigurator` directly (preferred) or keep testing through `FvpEngine` (which means `FakeEngine` needs updating).

**Prevention:** Test extracted sub-classes directly with a mock `mdk.Player`. Do NOT update `FakeEngine` to mirror internal decomposition — `FakeEngine` tests the `MediaEngine` interface, not internals.

**Phase:** ARCH-01 (fvp_engine decomposition)

### Pitfall X3: dispose() Order Sensitivity

**What goes wrong:** `FvpEngine.dispose()` disposes 12 ValueNotifiers + 3 helpers. If decomposition moves some ValueNotifiers to sub-classes, the dispose order matters — disposing a ValueNotifier that a sub-class still references causes `A dismissed ChangeNotifier was used` error.

**Prevention:** Sub-classes should NOT own ValueNotifiers. Only `FvpEngine` disposes them. Sub-classes receive ValueNotifiers as constructor parameters (read-only access).

**Phase:** ARCH-01

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| SEC-01: FFI try/finally | Pointer ownership conflict with `_savedFrame`/`_savedMaximizeFrame` | Map ownership before adding try/finally. Only wrap SHORT-LIVED pointers. |
| SEC-01: Fullscreen timeout | Timer + finally race condition | Cancel timer in finally. Timer callback checks guard before resetting. |
| SEC-02: URL validation | False rejection of RTSP/RTMP/SRT/UDP URLs | Keep prefix-based detection. Only validate http/https structure. |
| SEC-02: Path length | Rejecting valid long paths on modern Windows | Do NOT add MAX_PATH=260 limit. Rely on `File.exists()`. |
| ARCH-01: FvpEngine split | Interface breakage cascade to FakeEngine | Internal decomposition only. MediaEngine interface unchanged. |
| ARCH-01: State fragmentation | Sub-classes reaching back to parent ValueNotifiers | Sub-classes receive callbacks, not ValueNotifier refs. |
| ARCH-02: SettingsStore | Breaking per-field try-catch isolation | Keep per-field validation in bulk serializer. |
| ARCH-03: Singleton DI | Test breakage from missing reset/registration | Migrate one singleton at a time. Run full suite after each. |
| ARCH-03: Circular deps | SettingsStore static -> DI constructor mismatch | Keep SettingsStore static. Migrate leaf singletons first. |

---

## Sources

- Codebase analysis: `window_service.dart` (328 lines), `fvp_engine.dart` (690 lines), `settings_store.dart` (439 lines), `path_validator.dart` (92 lines), `media_engine.dart` (185 lines)
- Test helpers: `fake_engine.dart` (376 lines), `fake_window_service.dart` (73 lines)
- Anti-pattern memory: `project_window_anti_patterns.md` (kernel coupling, god objects, over-abstraction lessons)
- Concerns audit: `.planning/codebase/CONCERNS.md` (FFI memory safety, singleton anti-pattern)

---

*Pitfall analysis: 2026-05-30*
