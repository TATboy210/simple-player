# Pitfalls Research: PlayerEngine Refactoring

> Specific to simple_player_flutter engine layer refactoring.
> Based on codebase analysis: 57 files importing `player_engine`, FvpEngine 547 lines, 13 ValueNotifiers, 5 helpers.

---

## Import Migration Pitfalls

### PIT-01: Barrel File Substitution Mismatch

**Risk: HIGH**

The external `player_engine` barrel exports exactly 8 symbols:

```
PlayerEngine (from player_engine_base.dart)
MediaState, MediaErrorType
MediaInfo, AudioTrackInfo, SubtitleTrackInfo, VideoCodecInfo
VideoEffectType
```

Every one of the 57 files does a single `import 'package:player_engine/player_engine.dart'` and relies on this barrel. When migrating, the replacement barrel file (`lib/kernel/engine/player_engine.dart`) must export the exact same 8 symbols with identical APIs. If any method signature, enum value, or type changes during migration, all 57 files break simultaneously.

**Specific failure mode**: `player_engine_base.dart` already exists locally and uses `package:simple_player_flutter/kernel/engine/...` imports. But the external package has its own copies of these types. If the local `MediaState` enum has even one different value name, runtime behavior changes silently.

**Prevention**: Before changing any import, run a symbol diff:
```bash
# Compare exported symbols from old vs new barrel
dart analyze ../widget_tree_flutter/player_engine/lib/player_engine.dart
dart analyze lib/kernel/engine/player_engine.dart
```

### PIT-02: Relative Path Depth Errors

**Risk: MEDIUM**

Files at different directory depths need different relative paths after migration:

| Location | Current import | New relative import |
|----------|---------------|-------------------|
| `lib/app.dart` | `package:player_engine/player_engine.dart` | `kernel/engine/player_engine.dart` |
| `lib/features/player/player_feature.dart` | `package:player_engine/player_engine.dart` | `../../kernel/engine/player_engine.dart` |
| `lib/ui/player/control_bar.dart` | `package:player_engine/player_engine.dart` | `../../kernel/engine/player_engine.dart` |
| `test/helpers/fake_engine.dart` | `package:player_engine/player_engine.dart` | `../../lib/kernel/engine/player_engine.dart` |

Test files need `../../lib/` prefix, which is different from lib files. A mechanical find-replace that only handles lib/ will miss 20 test files.

**Prevention**: Separate the migration into lib/ and test/ passes. Verify with `dart analyze` after each pass.

### PIT-03: Internal Engine Files Importing External Package

**Risk: HIGH**

6 engine-layer files themselves import the external package:

```
lib/kernel/engine/fvp_callback_handler.dart
lib/kernel/engine/fvp_engine.dart
lib/kernel/engine/media_opener.dart
lib/kernel/engine/mock_engine.dart
lib/kernel/engine/open_result.dart
lib/kernel/engine/track_manager.dart
lib/kernel/engine/video_effect_controller.dart
```

These are the most dangerous to migrate because they use internal types (like `mdk.Player` callbacks that reference `MediaState`). If the import changes but the file still references types from the old package path, you get a "type not found" error that looks like a missing import rather than a wrong path.

**Prevention**: Migrate these 6 files FIRST, run `dart analyze` on just the engine directory before touching any UI files.

### PIT-04: Unused Import Masking

**Risk: LOW**

Many files import the barrel for just one type (e.g., `MediaState`). After migration, if you switch to direct file imports for tree-shaking, unused imports will cause analysis warnings. The reverse is also true: some files may import `player_engine` for a type they no longer use after refactoring.

**Prevention**: After migration, run `dart fix --apply` to clean unused imports. Do NOT manually fix unused imports during the migration commit -- keep it mechanical.

### PIT-05: Circular Dependency Creation

**Risk: MEDIUM**

Current dependency flow is clean:
```
player_engine (external) --> types only (no deps on simple_player_flutter)
simple_player_flutter --> player_engine (one-way)
```

After migration, all types live inside `lib/kernel/engine/`. If any engine file imports from `lib/features/` or `lib/ui/`, a circular dependency forms. This is especially risky with helper classes that might need `PlaybackController` or service types.

**Specific risk**: `FvpCallbackHandler` currently takes `state: ValueNotifier<MediaState>` and `isBuffering: ValueNotifier<bool>` as constructor params. If you refactor it to take a `PlaybackController` reference instead, you create `kernel/engine --> features/player` circularity.

**Prevention**: Enforce unidirectional dependency: `kernel/` never imports from `features/` or `ui/`. Use dependency injection (pass ValueNotifiers, not controllers) to maintain this.

---

## Composition Refactoring Pitfalls

### PIT-06: ValueNotifier Ownership Ambiguity

**Risk: CRITICAL**

FvpEngine owns 13 ValueNotifier instances as `final` fields. When extracting helpers (VolumeController, SubtitleConfigurator, D3D11Configurator), there are two approaches:

1. **Helpers receive ValueNotifiers** (current pattern): FvpEngine owns them, passes references to helpers
2. **Helpers own ValueNotifiers**: Each helper creates and exposes its own notifiers

Approach 2 breaks the `PlayerEngine` contract because the abstract class declares `ValueNotifier<double> get volume` etc. as a flat interface. If VolumeController owns the volume notifier, FvpEngine must delegate: `ValueNotifier<double> get volume => _volumeController.volume`. This works but:

- Widget tests using `engine.volume.value = 0.5` still work (same object reference)
- But `engine.volume = ValueNotifier(0.5)` (reassignment) breaks because it's now a getter
- Any code that does `final vn = engine.volume; vn.value = ...` works fine because it's the same object

**Specific risk**: MockEngine creates its own ValueNotifier instances. If the refactoring changes how FvpEngine exposes them (getter vs field), MockEngine must match. Since MockEngine `implements PlayerEngine` (not extends), it must provide the exact same getter/field shape.

**Prevention**: Keep ValueNotifier ownership in FvpEngine. Pass them to helpers as constructor params. Never change a `final field` to a `getter` in the abstract class -- it's a breaking change for all implementors.

### PIT-07: Helper Initialization Order

**Risk: HIGH**

FvpEngine uses `late` for 5 helpers:
```dart
late FvpCallbackHandler _callbackHandler;
late PositionPoller _positionPoller;
late TrackManager _trackManager;
late MediaOpener _mediaOpener;
late VideoEffectController _videoEffectController;
```

They're initialized inside `_createPlayer()` which is called lazily via `_player` getter. Adding new helpers (VolumeController, SubtitleConfigurator, D3D11Configurator) means more `late` fields with initialization dependencies:

- D3D11Configurator needs `mdk.Player` (created first)
- SubtitleConfigurator needs `mdk.Player` + possibly `TrackManager`
- VolumeController needs `mdk.Player` + the `volume` and `isMuted` ValueNotifiers

If any helper references another helper before initialization, you get a `LateInitializationError` at runtime. This won't show up in static analysis.

**Prevention**: Initialize all helpers in `_createPlayer()` in strict dependency order. Add a `_helpersInitialized` guard bool. Test with a fresh engine instance (not reusing across tests).

### PIT-08: Callback Wiring Gaps

**Risk: HIGH**

FvpEngine wires callbacks through FvpCallbackHandler:
```dart
_callbackHandler = FvpCallbackHandler(
  p,
  state: state,
  isBuffering: isBuffering,
  onStopPositionPolling: () => _positionPoller.stop(),
);
```

The `onStopPositionPolling` callback creates a cross-helper dependency (callback handler stops the position poller). When extracting more helpers, similar cross-cutting callbacks will emerge:

- VolumeController might need to notify state changes
- SubtitleConfigurator needs to update `subtitleText` notifier
- D3D11Configurator needs to trigger re-render on config change

If you extract a helper but forget to wire a callback, the symptom is subtle: a ValueNotifier never updates, so the UI shows stale data. No error, no crash.

**Prevention**: For each helper, document its callback contract:
- What ValueNotifiers does it write to?
- What callbacks does it expose?
- What external events does it need to receive?

Wire all callbacks in `_createPlayer()`. Add integration tests that verify notifier values after state transitions.

### PIT-09: Dispose Ordering

**Risk: MEDIUM**

FvpEngine.dispose() must:
1. Stop position polling (Timer.cancel)
2. Unregister mdk callbacks
3. Dispose all 13 ValueNotifiers
4. Dispose the mdk.Player

If helpers own any of these resources, dispose must cascade correctly. Missing a dispose causes:
- Timer leak (position keeps polling a dead player)
- Memory leak (ValueNotifier listeners accumulate)
- Crash (mdk.Player accessed after native resource freed)

**Specific risk**: Current dispose does `_positionPoller.stop()` but the new helpers (VolumeController, etc.) may have their own cleanup needs. If FvpEngine.dispose() doesn't call `_volumeController.dispose()`, the mdk.Player might receive volume commands after it's freed.

**Prevention**: Each helper implements a `dispose()` method. FvpEngine.dispose() calls them in reverse initialization order. Add a `_disposed` guard in each helper.

---

## Platform-Specific Pitfalls

### PIT-10: D3D11 Property Timing

**Risk: CRITICAL**

D3D11 properties MUST be set between player creation and first `open()` call:
```dart
p.setProperty('d3d11.sync.cpu', syncMode);
p.setProperty('video.decoders', _defaultVideoDecoders);
p.setProperty('avcodec.threads', _ffmpegDecoderThreads);
p.setProperty('videoout.buffer_frames', _maxBufferFrames);
p.setProperty('reader.starts_with_key', '1');
```

If D3D11Configurator.applyDefaults() is called AFTER `open()`, the properties are ignored silently -- mdk applies them only at open time. The video will play with wrong decoder settings, wrong buffer sizes, or wrong sync mode. Symptoms: black screen, tearing, high CPU usage, or crash on certain hardware.

**Prevention**: D3D11Configurator must be called inside `_createPlayer()`, before any `open()` call. Add an assertion: `assert(!_isOpening, 'D3D11 config must be applied before open()')`.

### PIT-11: DisplayConfig Platform Channel Race

**Risk: MEDIUM**

`DisplayConfig.d3d11SyncMode()` and `DisplayConfig.getRefreshRate()` call platform channels to query monitor refresh rate. These are async by nature but used synchronously in `_applyD3d11Defaults()`. If the platform channel hasn't responded yet (cold start, slow platform), the values fall back to defaults.

**Current mitigation**: DisplayConfig likely caches the first response. But if you extract D3D11Configurator as a separate class that constructs independently, it might query DisplayConfig before the cache is warm.

**Prevention**: D3D11Configurator should receive DisplayConfig values as constructor params, not query them directly. This makes the dependency explicit and testable.

### PIT-12: mdk.Player Singleton Behavior

**Risk: HIGH**

`mdk.Player()` is a native resource with global state implications. Creating multiple mdk.Player instances can:
- Conflict on D3D11 device context (shared GPU resources)
- Cause texture ID collisions
- Lead to audio device contention

FvpEngine uses lazy initialization (`_playerInstance ??= _createPlayer()`). If the refactoring accidentally creates a second player (e.g., helper creates its own for testing), it corrupts the first player's state.

**Prevention**: mdk.Player creation stays ONLY in FvpEngine._createPlayer(). Helpers receive the player instance, never create their own. Add a singleton assertion in debug mode.

### PIT-13: Texture ID Lifecycle

**Risk: HIGH**

The texture ID flow is:
```
mdk.Player created --> textureId = null
mdk.Player.open() --> mdk internally creates D3D11 texture
_p.textureId.addListener(_onTextureIdChanged) --> copies to FvpEngine.textureId
UI reads engine.textureId --> Texture(textureId: id)
```

If you extract the texture ID forwarding to a helper, the timing must be preserved exactly. The texture ID is only valid while the mdk.Player is alive. If a helper holds a stale reference to the old texture ID after a new `open()` call, the Texture widget renders garbage or crashes.

**Prevention**: Keep `_onTextureIdChanged` in FvpEngine. It's a 1-liner: `textureId.value = _player.textureId.value`. Don't extract it.

### PIT-14: Win32 Window Manager Interactions

**Risk: MEDIUM**

The engine layer doesn't directly touch Win32 window management, but `DisplayConfig` bridges to it. If the refactoring moves DisplayConfig into a helper, and that helper is constructed before the window is fully initialized, the refresh rate query fails silently.

**Specific scenario**: App starts --> FvpEngine created --> D3D11Configurator queries DisplayConfig --> Window not yet shown --> fallback to 60Hz --> user's 144Hz monitor gets wrong sync mode.

**Prevention**: D3D11Configurator should have a `refresh()` method that re-queries DisplayConfig after window is shown. Or defer D3D11 config until first `open()`.

---

## Testing Pitfalls

### PIT-15: MockEngine Contract Drift

**Risk: CRITICAL**

MockEngine `implements PlayerEngine` (not `extends`). This means:
- Every abstract method/property in PlayerEngine MUST be implemented in MockEngine
- If you add a new abstract method to PlayerEngine, MockEngine breaks at compile time (good)
- If you change a method signature, MockEngine breaks at compile time (good)
- If you change a field to a getter in PlayerEngine, MockEngine must match (subtle)

MockEngine currently has all 13 ValueNotifiers as `final` fields, matching PlayerEngine's abstract getters. This works because Dart allows a field to satisfy a getter contract. But if PlayerEngine changes any getter to require a different implementation pattern, MockEngine must be updated.

**Specific risk**: MockEngine imports `package:player_engine/player_engine.dart`. After migration, it must import the local barrel. If MockEngine still references types from the old package (e.g., `MediaState` from the wrong import), it will compile but use a different type than the rest of the app.

**Prevention**: Migrate MockEngine FIRST. Run `dart analyze lib/kernel/engine/mock_engine.dart` in isolation. Verify all 13 ValueNotifier types match exactly.

### PIT-16: FakeEngine in Tests

**Risk: HIGH**

`test/helpers/fake_engine.dart` contains `FakeEngine implements PlayerEngine`. It's used by multiple test files. If the PlayerEngine interface changes during refactoring, FakeEngine breaks and cascades to all tests that use it.

Additionally, `test/features/player/services/subtitle_service_test.dart` has its own `_FakeEngine` class. Multiple fake implementations drift apart over time.

**Prevention**: After any PlayerEngine interface change, immediately update FakeEngine and all _FakeEngine variants. Run `flutter test` before committing.

### PIT-17: Widget Test Texture Assumptions

**Risk: MEDIUM**

Widget tests that render `VideoSurface` depend on `engine.textureId.value`. MockEngine sets this to `null` (no real texture). If the refactoring changes when textureId is set (e.g., before vs after open()), widget tests that check for texture rendering may break.

**Specific tests at risk**: `test/widget/player/controls_overlay_test.dart`, `test/golden/control_layouts_golden_test.dart`.

**Prevention**: MockEngine's texture behavior should remain: `textureId` stays null unless explicitly configured. Don't change the mock's texture lifecycle.

### PIT-18: Integration Test Engine Setup

**Risk: MEDIUM**

`test/integration/playback_flow_test.dart` imports player_engine and likely creates a full engine setup. If the engine's initialization sequence changes (new helpers, different order), integration tests that exercise the full open->play->pause->seek flow may break at different points.

**Prevention**: Run integration tests after EACH helper extraction, not just at the end. Each extraction should be a separate commit with passing tests.

### PIT-19: Test Helper Import Path Sensitivity

**Risk: LOW**

20 test files import `package:player_engine/player_engine.dart`. After migration, they need `package:simple_player_flutter/kernel/engine/player_engine.dart` or relative paths. The relative path from `test/` to `lib/kernel/engine/` is `../../lib/kernel/engine/player_engine.dart`, which is fragile -- moving any test file breaks its imports.

**Prevention**: Use package imports in tests: `import 'package:simple_player_flutter/kernel/engine/player_engine.dart'`. This is stable regardless of test file location.

---

## Flutter Desktop-Specific Gotchas

### PIT-20: Texture Widget Null Safety

**Risk: MEDIUM**

Flutter's `Texture` widget requires a valid texture ID. If `textureId.value` is:
- `null` --> Texture widget throws or renders nothing
- Stale ID (from previous open) --> renders wrong video or crashes
- Negative --> undefined behavior

During refactoring, if a helper resets textureId at the wrong time (e.g., during dispose), the Texture widget in `VideoSurface` may receive an invalid ID.

**Prevention**: Only set textureId in `_onTextureIdChanged`. Never reset it to null except in dispose.

### PIT-21: BackdropFilter Performance with Engine State

**Risk: LOW**

The control bar uses `BackdropFilter` (glass-morphism). This widget captures the layer behind it and applies a blur. If the engine's texture rendering changes timing (e.g., due to helper initialization adding latency), the BackdropFilter may capture a frame with wrong content.

This is unlikely but worth noting: D3D11Configurator initialization adds a few ms to startup. If this happens during the first frame render, the glass effect may briefly show wrong content.

**Prevention**: D3D11Configurator initialization is synchronous (just `setProperty` calls), so this risk is minimal. If it becomes async (e.g., querying hardware capabilities), defer it.

### PIT-22: ValueNotifier Listener Accumulation

**Risk: MEDIUM**

If helpers add listeners to ValueNotifiers but don't remove them in dispose, listeners accumulate across test runs. Widget tests create and dispose engines repeatedly. A leaked listener from test 1 fires in test 2, causing unexpected state changes.

**Specific pattern**: `_player.textureId.addListener(_onTextureIdChanged)` in `_createPlayer()`. If `_createPlayer()` is called multiple times (re-creation after dispose), the listener is added again without removing the old one.

**Prevention**: Track all added listeners. Remove them in dispose. Consider using `removeListener` in a `_cleanup` method called before re-creation.

---

## Prevention Strategies Summary

| Pitfall | Severity | Prevention |
|---------|----------|------------|
| PIT-01: Barrel symbol mismatch | HIGH | Symbol diff before/after migration |
| PIT-02: Relative path depth | MEDIUM | Separate lib/ and test/ migration passes |
| PIT-03: Engine internal imports | HIGH | Migrate engine files first, verify in isolation |
| PIT-05: Circular dependency | MEDIUM | Enforce unidirectional kernel/ -> features/ |
| PIT-06: ValueNotifier ownership | CRITICAL | Keep ownership in FvpEngine, pass to helpers |
| PIT-07: Helper init order | HIGH | Strict ordering in _createPlayer(), guard bool |
| PIT-08: Callback wiring gaps | HIGH | Document callback contracts, integration tests |
| PIT-09: Dispose ordering | MEDIUM | Reverse-order dispose, _disposed guards |
| PIT-10: D3D11 property timing | CRITICAL | Apply in _createPlayer() before open(), assert |
| PIT-11: DisplayConfig race | MEDIUM | Pass values as constructor params |
| PIT-12: mdk.Player singleton | HIGH | Player creation ONLY in FvpEngine |
| PIT-13: Texture ID lifecycle | HIGH | Keep _onTextureIdChanged in FvpEngine |
| PIT-14: Win32 window race | MEDIUM | Defer DisplayConfig query to first open() |
| PIT-15: MockEngine drift | CRITICAL | Migrate first, verify all 13 notifiers match |
| PIT-16: FakeEngine cascade | HIGH | Update all fakes immediately on interface change |
| PIT-17: Widget test texture | MEDIUM | Don't change mock texture lifecycle |
| PIT-18: Integration test order | MEDIUM | Run after each extraction, not just at end |
| PIT-19: Test import paths | LOW | Use package imports, not relative |
| PIT-20: Texture null safety | MEDIUM | Only set textureId in _onTextureIdChanged |
| PIT-22: Listener accumulation | MEDIUM | Track and remove all listeners in dispose |

---

## Phase Mapping

### Phase 1: Import Migration (57 files)

**Address these pitfalls in this phase:**
- PIT-01 (barrel symbol mismatch) -- verify before starting
- PIT-02 (relative path depth) -- separate lib/ and test/ passes
- PIT-03 (engine internal imports) -- migrate engine files first
- PIT-15 (MockEngine drift) -- migrate MockEngine first
- PIT-16 (FakeEngine cascade) -- update all fakes
- PIT-19 (test import paths) -- use package imports

**Gate**: `dart analyze` passes with zero errors. All existing tests pass.

### Phase 2: Helper Extraction (FvpEngine decomposition)

**Address these pitfalls in this phase:**
- PIT-06 (ValueNotifier ownership) -- keep in FvpEngine
- PIT-07 (helper init order) -- strict ordering
- PIT-08 (callback wiring gaps) -- document contracts
- PIT-09 (dispose ordering) -- reverse-order cascade
- PIT-13 (texture ID lifecycle) -- keep in FvpEngine
- PIT-22 (listener accumulation) -- track all listeners

**Gate**: FvpEngine < 200 lines. All ValueNotifiers still owned by FvpEngine. Integration tests pass.

### Phase 3: Platform Helper Extraction (D3D11, Subtitle, Volume)

**Address these pitfalls in this phase:**
- PIT-10 (D3D11 property timing) -- apply in _createPlayer()
- PIT-11 (DisplayConfig race) -- pass values as params
- PIT-12 (mdk.Player singleton) -- creation only in FvpEngine
- PIT-14 (Win32 window race) -- defer to first open()

**Gate**: D3D11Configurator is a pure function (no side effects, no async). All platform tests pass.

### Phase 4: Verification

**Address all remaining risks:**
- PIT-05 (circular dependency) -- verify with `dart analyze` dependency graph
- PIT-17 (widget test texture) -- run golden tests
- PIT-18 (integration test order) -- run full test suite
- PIT-20 (texture null safety) -- manual smoke test on Windows

**Gate**: Full `flutter test` passes. Manual smoke test on Windows with real video file.
