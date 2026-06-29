# Phase 2: Engine Composition - Research

**Researched:** 2026-06-29
**Domain:** Dart composition/delegation pattern, Flutter ValueNotifier ownership
**Confidence:** HIGH

## Summary

Phase 2 is a pure refactoring phase: activate 3 existing helper classes (VolumeController, SubtitleConfigurator, D3D11Configurator) that already exist in `lib/kernel/engine/` but are NOT imported or used by FvpEngine. The core work is delegation wiring, not creation.

Key finding: D3D11Configurator needs an `applyDefaults()` method expansion (currently only has `setSyncEnabled` + `setHardwareDecoding`), and its `defaultVideoDecoders` constant is missing `shader_resource=1` compared to FvpEngine's `_defaultVideoDecoders`. This discrepancy must be resolved during delegation.

**Primary recommendation:** Extend D3D11Configurator first (add `applyDefaults()` + fix constant), then wire delegation in FvpEngine, then add unit tests for all 3 helpers.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Volume/mute control | FvpEngine (delegation) | VolumeController (logic) | FvpEngine owns ValueNotifier fields and guard; VolumeController owns player interaction |
| Subtitle/equalizer config | FvpEngine (delegation) | SubtitleConfigurator (logic) | Same pattern: FvpEngine owns guard + lifecycle, helper owns property setting |
| D3D11 renderer config | FvpEngine (delegation) | D3D11Configurator (logic) | FvpEngine calls `applyDefaults()` at player creation; D3D11Configurator owns all 5 setProperty calls |
| ValueNotifier ownership | FvpEngine (sole owner) | Helpers (receive references) | COMP-05 CRITICAL: changing to getters breaks MockEngine |
| Lifecycle/disposal | FvpEngine (sole owner) | Helpers (no lifecycle) | `_guardedAction` stays in FvpEngine per CONTEXT.md Decision 2 |

## Standard Stack

### Core (no new packages needed)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| (none) | — | Pure Dart refactoring | No new dependencies required |

### Existing Helpers (already in codebase)

| File | Lines | Purpose | Current State |
|------|-------|---------|---------------|
| `volume_controller.dart` | 35 | Volume/mute logic | EXISTS, NOT imported by FvpEngine |
| `subtitle_configurator.dart` | 37 | Subtitle/equalizer config | EXISTS, NOT imported by FvpEngine |
| `d3d11_configurator.dart` | 37 | D3D11 sync/decoding config | EXISTS, NOT imported by FvpEngine, needs expansion |
| `display_config.dart` | 64 | Refresh rate detection | EXISTS, used by FvpEngine directly |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Delegation (final fields) | Mixins | Mixins can't hold state per-instance; delegation allows VolumeController to hold mdk.Player reference |
| Delegation (final fields) | Extension methods | Extensions can't access private _player; would require exposing it |

**Installation:** None -- all code already exists in the codebase.

## Package Legitimacy Audit

No new packages are installed. This phase is a pure code refactoring.

## Architecture Patterns

### System Architecture Diagram

```
FvpEngine (553 lines, target ~484)
  |
  |-- [ValueNotifier fields: volume, isMuted, subtitleText, etc.]
  |       (owned by FvpEngine, NOT moved)
  |
  |-- _guardedAction() (lifecycle guard, stays in FvpEngine)
  |       |
  |       |-- _volumeController.setVolume(value)   [NEW delegation]
  |       |-- _volumeController.setMute(mute)      [NEW delegation]
  |       |-- _subtitleConfigurator.setExternalSubtitle(path) [NEW delegation]
  |       |-- _subtitleConfigurator.setSubtitleDelay(ms)     [NEW delegation]
  |       |-- _subtitleConfigurator.setEqualizer(filter)     [NEW delegation]
  |       |-- _d3d11Configurator.setSyncEnabled(enabled)     [NEW delegation]
  |       |-- _d3d11Configurator.setHardwareDecoding(enabled) [NEW delegation]
  |
  |-- _createPlayer()
  |       |
  |       |-- _d3d11Configurator.applyDefaults(_player) [REPLACES _applyD3d11Defaults]
  |
  |-- [Existing delegation: _callbackHandler, _positionPoller, _trackManager, etc.]
```

### Recommended Project Structure (after refactoring)

```
lib/kernel/engine/
├── fvp_engine.dart                    # ~484 lines (delegation hub)
├── volume_controller.dart             # ~35 lines (UNCHANGED)
├── subtitle_configurator.dart         # ~37 lines (UNCHANGED)
├── d3d11_configurator.dart            # ~70 lines (EXPANDED: +applyDefaults, +constants)
├── mock_engine.dart                   # ~438 lines (UNCHANGED)
└── ... (existing files unchanged)
```

### Pattern 1: Guard + Delegate

**What:** FvpEngine wraps every helper call in `_guardedAction()` for disposed check + error handling. The helper is pure logic, no lifecycle awareness.

**When to use:** When the delegating class owns lifecycle (disposed flag, error state) but the helper owns domain logic.

**Example (from CONTEXT.md):**

```dart
@override
void setVolume(double value) {
  _guardedAction('setVolume', () {
    _volumeController.setVolume(value);
  });
}
```

### Pattern 2: ValueNotifier Reference Passing

**What:** Helper receives `ValueNotifier` references via constructor, mutates `.value` directly. FvpEngine owns the `final` field.

**When to use:** When helpers need to update shared state that UI observes, but ownership must stay in the parent for MockEngine compatibility.

**Example (from existing VolumeController):**

```dart
class VolumeController {
  VolumeController(this._player, {required this.volume, required this.isMuted});
  final mdk.Player _player;
  final ValueNotifier<double> volume;
  final ValueNotifier<bool> isMuted;
  // ... mutates volume.value and isMuted.value directly
}
```

### Anti-Patterns to Avoid

- **Moving ValueNotifier ownership to helpers:** Breaks MockEngine (438 lines), violates COMP-05
- **Moving _guardedAction into helpers:** Helpers become lifecycle-aware, coupling them to FvpEngine's dispose pattern
- **Creating new helper classes:** All 3 already exist -- the task is activation, not creation

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Volume clamping/mute-sync | Custom logic in FvpEngine | VolumeController.setVolume() | Already implemented, tested pattern |
| Subtitle property setting | Inline setProperty calls | SubtitleConfigurator | Already implemented, isolates mdk.Property API |
| D3D11 configuration | Inline _applyD3d11Defaults | D3D11Configurator.applyDefaults() | Centralizes all 5 properties, single responsibility |

**Key insight:** The existing helpers are already well-tested at the API surface level (VideoEffectController tests verify isValidRotation, validRotationDegrees as static pure functions). The new tests for VolumeController/SubtitleConfigurator should follow the same pattern: test static/pure logic where possible, test integration with mdk.Player where needed.

## Common Pitfalls

### Pitfall 1: D3D11Configurator defaultVideoDecoders Constant Mismatch
**What goes wrong:** D3D11Configurator has `defaultVideoDecoders = 'D3D11,NVDEC,FFmpeg'` but FvpEngine has `_defaultVideoDecoders = 'D3D11:shader_resource=1,NVDEC,FFmpeg'`. The `shader_resource=1` enables GPU colorspace conversion.
**Why it happens:** The two files were created independently with slightly different constants.
**How to avoid:** Update D3D11Configurator's constant to match FvpEngine's before delegation. Copy the exact string: `'D3D11:shader_resource=1,NVDEC,FFmpeg'`.
**Warning signs:** After delegation, video playback quality regression (more CPU usage, slower colorspace conversion).

### Pitfall 2: D3D11 Timing Violation (PLAT-01)
**What goes wrong:** D3D11 properties are set AFTER `open()` is called, causing them to be silently ignored by mdk.
**Why it happens:** `applyDefaults()` is called in `_createPlayer()` which returns the player before `open()`. If someone moves the call to a lazy init path, timing breaks.
**How to avoid:** Keep `applyDefaults()` call inside `_createPlayer()`, after `p` is created but before returning. The existing code structure already ensures this -- just replace `_applyD3d11Defaults(p)` with `_d3d11Configurator.applyDefaults(p)`.
**Warning signs:** Silent property ignoring, no error thrown.

### Pitfall 3: MockEngine Not Updated
**What goes wrong:** If helper delegation introduces new abstract methods or changes existing signatures, MockEngine (438 lines) must be updated.
**Why it happens:** MockEngine implements PlayerEngine interface. If interface doesn't change, MockEngine doesn't need changes.
**How to avoid:** PlayerEngine interface does NOT change in Phase 2 (no new methods, no signature changes). Verify by checking: all delegated methods already exist in PlayerEngine. MockEngine stays unchanged.
**Warning signs:** Compilation errors in test files.

### Pitfall 4: Forgetting to Wire D3D11Configurator into _createPlayer
**What goes wrong:** Delegating `setD3d11SyncEnabled` and `setHardwareDecoding` but forgetting to also wire `applyDefaults()` into the player creation path.
**Why it happens:** The two responsibilities (runtime config + default config) are in different code paths.
**How to avoid:** In `_createPlayer()`, replace `_applyD3d11Defaults(p)` with `_d3d11Configurator.applyDefaults(p)`. Both paths must use the same helper.
**Warning signs:** Default D3D11 properties not applied on first play.

## Code Examples

### Delegated setVolume (after refactoring)

```dart
// Source: CONTEXT.md delegation pattern + existing VolumeController API
@override
void setVolume(double value) {
  _guardedAction('setVolume', () {
    _volumeController.setVolume(value);
  });
}
```

### D3D11Configurator.applyDefaults (new method)

```dart
// Source: existing FvpEngine._applyD3d11Defaults (lines 146-178)
// This consolidates all 5 setProperty calls into the helper
void applyDefaults() {
  _player.setProperty('d3d11.sync.cpu', DisplayConfig.d3d11SyncMode());
  _player.setProperty('video.decoders', defaultVideoDecoders);
  _player.setProperty('avcodec.threads', _ffmpegDecoderThreads);
  _player.setProperty('videoout.buffer_frames', _maxBufferFrames);
  _player.setProperty('reader.starts_with_key', '1');
  log.d('D3D11Configurator: defaults applied');
}
```

### FvpEngine._createPlayer (after refactoring)

```dart
// Source: existing FvpEngine._createPlayer (lines 115-140)
mdk.Player _createPlayer() {
  final p = mdk.Player();
  _callbackHandler = FvpCallbackHandler(
    p,
    state: state,
    isBuffering: isBuffering,
    onStopPositionPolling: () => _positionPoller.stop(),
  );
  _positionPoller = PositionPoller(
    p,
    position: position,
    buffered: buffered,
    currentPathGetter: () => _currentPath,
  );
  _trackManager = TrackManager(p);
  _videoEffectController = VideoEffectController(p);
  _mediaOpener = MediaOpener(p, _trackManager);
  _volumeController = VolumeController(p, volume: volume, isMuted: isMuted);
  _subtitleConfigurator = SubtitleConfigurator(p);
  _d3d11Configurator = D3D11Configurator(p);

  p.textureId.addListener(_onTextureIdChanged);
  _callbackHandler.init();

  // D3D11 defaults via helper — before open()
  _d3d11Configurator.applyDefaults();

  return p;
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Inline logic in FvpEngine | Delegate to helper classes | Phase 2 | FvpEngine 553 -> ~484 lines |
| _applyD3d11Defaults as private method | D3D11Configurator.applyDefaults() | Phase 2 | Centralizes D3D11 config |
| D3D11Configurator with 2 methods | D3D11Configurator with 3 methods + constants | Phase 2 | Single responsibility for all D3D11 properties |

**Deprecated/outdated:**
- `_applyD3d11Defaults()` private method in FvpEngine: replaced by `D3D11Configurator.applyDefaults()`
- `_defaultVideoDecoders` constant in FvpEngine: moved to `D3D11Configurator.defaultVideoDecoders` (with corrected value)

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | VolumeController/SubtitleConfigurator/D3D11Configurator are NOT imported anywhere in the codebase | Summary | Low -- grep confirmed zero imports outside definition files |
| A2 | PlayerEngine interface does not change in Phase 2 (no new methods) | Pitfall 3 | Low -- CONTEXT.md and REQUIREMENTS.md confirm COMP-01..05 are internal to FvpEngine |
| A3 | MockEngine (438 lines) does not need changes | Pitfall 3 | Low -- if interface unchanged, MockEngine is unaffected |
| A4 | D3D11Configurator.applyDefaults() should be called in _createPlayer(), not lazily | Pitfall 2 | Medium -- PLAT-01 requires pre-open timing, lazy init could violate this |

## Open Questions

1. **Should D3D11Configurator constants move from FvpEngine or be duplicated?**
   - What we know: FvpEngine has `_ffmpegDecoderThreads`, `_maxBufferFrames`, `_defaultVideoDecoders`. D3D11Configurator has `defaultVideoDecoders`.
   - What's unclear: Whether to move ALL constants to D3D11Configurator or keep them as FvpEngine private constants referenced by the helper.
   - Recommendation: Move `_ffmpegDecoderThreads` and `_maxBufferFrames` to D3D11Configurator as private constants, and update `defaultVideoDecoders` to include `shader_resource=1`. This makes D3D11Configurator self-contained.

2. **Should D3D11Configurator.applyDefaults() take DisplayConfig as constructor dependency?**
   - What we know: CONTEXT.md says "新增 DisplayConfig 依赖（获取 d3d11SyncMode + refreshRate）"
   - What's unclear: Whether to inject DisplayConfig or call static methods directly.
   - Recommendation: Call `DisplayConfig.d3d11SyncMode()` statically inside `applyDefaults()` (matching current FvpEngine pattern). No constructor dependency needed -- DisplayConfig is already a singleton with static methods.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | Build/test | Yes | any | — |
| fvp package | mdk.Player API | Yes | current | — |
| Dart SDK | Compilation | Yes | 3.x | — |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:** None.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in) |
| Config file | none (uses default test discovery) |
| Quick run command | `flutter test` |
| Full suite command | `flutter test` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| COMP-01 | VolumeController delegates volume/mute | unit | `flutter test test/kernel/engine/volume_controller_test.dart -x` | NO -- Wave 0 |
| COMP-02 | SubtitleConfigurator delegates subtitle/eq | unit | `flutter test test/kernel/engine/subtitle_configurator_test.dart -x` | NO -- Wave 0 |
| COMP-03 | D3D11Configurator delegates D3D11 config | unit | `flutter test test/kernel/engine/d3d11_configurator_test.dart -x` | NO -- Wave 0 |
| COMP-04 | FvpEngine methods delegate to helpers | integration | `flutter test test/widget/player/ -x` | Existing tests cover via FakeEngine |
| COMP-05 | ValueNotifier ownership in FvpEngine unchanged | verification | `flutter test` (all existing tests pass) | Existing tests |

### Sampling Rate
- **Per task commit:** `flutter test`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/kernel/engine/volume_controller_test.dart` -- covers COMP-01 (unit tests for VolumeController)
- [ ] `test/kernel/engine/subtitle_configurator_test.dart` -- covers COMP-02 (unit tests for SubtitleConfigurator)
- [ ] `test/kernel/engine/d3d11_configurator_test.dart` -- covers COMP-03 (unit tests for D3D11Configurator, including applyDefaults)
- [ ] All existing widget/integration tests must continue passing (FakeEngine unchanged)

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V5 Input Validation | no | N/A -- no user input handling in this phase |
| V6 Cryptography | no | N/A -- no crypto operations |

This phase is a pure refactoring with no security surface changes. The `_guardedAction` pattern (disposed check + error handling) is preserved unchanged.

## Sources

### Primary (HIGH confidence)
- Codebase: `lib/kernel/engine/fvp_engine.dart` (553 lines, direct read)
- Codebase: `lib/kernel/engine/volume_controller.dart` (35 lines, direct read)
- Codebase: `lib/kernel/engine/subtitle_configurator.dart` (37 lines, direct read)
- Codebase: `lib/kernel/engine/d3d11_configurator.dart` (37 lines, direct read)
- Codebase: `lib/kernel/bridge/display_config.dart` (64 lines, direct read)
- Codebase: `lib/kernel/engine/mock_engine.dart` (438 lines, direct read)
- Context7: `/dart-lang/site-www` -- Dart delegation/wrapper patterns, constructor parameter conventions

### Secondary (MEDIUM confidence)
- `.planning/phases/02-engine-composition/02-CONTEXT.md` -- user decisions from discuss-phase

### Tertiary (LOW confidence)
- None -- all findings verified against codebase or official Dart docs

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH -- no new packages; all code exists in codebase
- Architecture: HIGH -- delegation pattern matches existing codebase conventions (VideoEffectController, TrackManager, FvpCallbackHandler)
- Pitfalls: HIGH -- D3D11 constant mismatch verified by comparing two source files; PLAT-01 timing constraint documented in REQUIREMENTS.md

**Research date:** 2026-06-29
**Valid until:** 2026-07-29 (stable -- pure refactoring, no external dependencies)
