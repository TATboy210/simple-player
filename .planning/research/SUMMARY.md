# Project Research Summary: PlayerEngine Refactoring

## Key Findings

1. **The external `player_engine` dependency is a pure liability.** It is a 1:1 copy of local types exported via a barrel file. 57 Dart files import it, but the local barrel at `lib/kernel/engine/player_engine.dart` already exports the identical 8 symbols. Removing it is a mechanical find-and-replace with near-zero risk and eliminates path coupling to `../widget_tree_flutter/player_engine`.

2. **FvpEngine is already well-composed but inconsistently.** Five helpers (FvpCallbackHandler, PositionPoller, TrackManager, MediaOpener, VideoEffectController) are properly wired, but three more (D3D11Configurator, SubtitleConfigurator, VolumeController) exist as extracted classes that FvpEngine duplicates inline instead of delegating to. Finishing this delegation shrinks FvpEngine from ~547 to ~350 lines with no API change.

3. **The PlayerEngine abstract interface is the architectural keystone.** It enables MockEngine for widget tests (no real media), clean engine swaps (future media_kit/libmpv), and UI isolation (widgets never import fvp/mdk). Removing it would be a mistake -- the abstraction has concrete test and portability value.

4. **ValueNotifier ownership is the most dangerous refactoring surface.** FvpEngine owns 13 ValueNotifiers as `final` fields. If helpers are refactored to own their notifiers instead, the PlayerEngine abstract contract breaks for all implementors (MockEngine, FakeEngine). Ownership must stay in FvpEngine; helpers receive references.

5. **D3D11 property timing is a silent failure.** D3D11 properties (`d3d11.sync.cpu`, `video.decoders`, etc.) must be set between player creation and the first `open()` call. If applied after `open()`, mdk ignores them silently -- the video plays with wrong decoder settings, causing black screen, tearing, or high CPU with no error message.

## Stack Recommendations

| Choice | Recommendation | Rationale |
|--------|---------------|-----------|
| **State management** | Keep ValueNotifier | Flutter-native, simpler than Streams for single-subscriber UI binding, 57 files already depend on it |
| **Engine abstraction** | Keep abstract PlayerEngine | Enables MockEngine, future engine swaps, UI isolation |
| **Interface split strategy** | Mixins (TrackControl, VideoEffects, RendererConfig) | Backward compatible, progressive adoption via `if (engine is TrackControl)`, no wrapper boilerplate |
| **External dependency** | Remove `player_engine` path dependency entirely | 1:1 copy adds no value, causes import path confusion |
| **Helper pattern** | Composition (helpers receive mdk.Player + ValueNotifiers) | Each helper independently testable, FvpEngine becomes thin coordinator |
| **Future engine option** | media_kit (libmpv) as future option, not now | Lacks D3D11 sync control; evaluate when Linux/macOS becomes primary |
| **Import style** | Package imports (`package:simple_player_flutter/...`) | Stable across file moves, works from any directory depth |

## Feature Analysis

### Table Stakes (must preserve unchanged)

| Category | Scope | Key Risk |
|----------|-------|----------|
| Playback controls | 10 methods, 5 ValueNotifiers (state, position, duration, volume, isMuted) | 8+ widgets consume state; signature changes break all |
| Track management | 5 methods + 3 getters, 2 data models (AudioTrackInfo, SubtitleTrackInfo) | AudioTab, KeyboardHandler depend on exact API |
| Video effects | 6 methods, 1 enum (VideoEffectType) | VideoProcessingService uses diff-based sync |
| Media info | 7 ValueNotifiers, 3 plain getters, 4 data models (MediaInfo, VideoCodecInfo, MediaState, MediaErrorType) | MediaInfoDialog, ErrorBanner, ProgressBar |
| D3D11 integration | 2 methods (setD3d11SyncEnabled, setHardwareDecoding) | Windows-only; must allow no-op on other platforms |
| Engine lifecycle | dispose + EnginePrewarm | _disposed guard on every method must survive |
| Adaptive position polling | 3-tier timer (100ms/250ms/500ms) | ProgressBar animation depends on update frequency |
| Network streams | NetworkConfigurator (RTSP/RTMP/SRT/HTTP) | Protocol-specific FFmpeg params |
| MockEngine | Full interface compliance, configurable delays, event recording | Test backbone for 18+ test files |

### Differentiators (architecture improvements the refactoring enables)

- **Engine decomposition**: FvpEngine 547 -> ~200 lines (thin coordinator)
- **Interface segregation via mixins**: Narrower interfaces reduce coupling, enable focused mocks
- **State machine formalization**: Explicit MediaState transitions prevent illegal combinations
- **Error recovery**: Automatic retry for network errors, HW->SW codec fallback
- **Platform abstraction**: D3D11Configurator behind interface enables macOS/Linux engines

### Anti-Features (must NOT do)

- Do NOT replace ValueNotifiers with Streams/ChangeNotifier/Bloc (breaks 57 consumers)
- Do NOT change method signatures (e.g., `open()` must stay `Future<void>`)
- Do NOT add required constructor params to PlayerEngine (breaks lazy init)
- Do NOT remove `_disposed` guard pattern (causes use-after-dispose crashes)
- Do NOT make `open()` synchronous (blocks UI thread)
- Do NOT remove MockEngine (test backbone)

## Architecture Direction

### Target Structure

```
lib/kernel/engine/
  player_engine.dart          # Barrel export
  player_engine_base.dart     # Core interface: state + playback control only
  fvp_engine.dart             # Thin coordinator (~200 lines)
  capabilities/               # Optional mixin interfaces
    track_control.dart
    video_effects.dart
    renderer_config.dart
  helpers/                    # FvpEngine internal helpers
    track_manager.dart, video_effect_controller.dart,
    subtitle_configurator.dart, volume_controller.dart,
    d3d11_configurator.dart, network_configurator.dart,
    fvp_callback_handler.dart, position_poller.dart, media_opener.dart
  models/                     # Data classes (unchanged)
  mock_engine.dart
  engine_prewarm.dart
```

### Interface Hierarchy

- **PlayerEngine** (abstract): 12 ValueNotifiers + 8 core methods + 3 getters + dispose. 90% of UI code only needs this.
- **TrackControl** (mixin on PlayerEngine): audio/subtitle track switching
- **VideoEffects** (mixin on PlayerEngine): brightness/contrast/hue/saturation/rotate/rate
- **RendererConfig** (mixin on PlayerEngine): D3D11/hardware decode config
- FvpEngine: `class FvpEngine extends PlayerEngine with TrackControl, VideoEffects, RendererConfig`
- MockEngine: implements core PlayerEngine only (no mixin stubs)

### Component Boundaries

- **UI -> Engine**: Read-only via ValueNotifier. Commands via PlaybackController.
- **PlaybackController -> Engine**: All playback commands. Never touches helpers.
- **FvpEngine -> Helpers**: Each helper owns one concern. FvpEngine coordinates.
- **Helpers -> mdk.Player**: Direct FFI calls. No cross-helper dependencies.
- **kernel/ never imports features/ or ui/**: Unidirectional dependency enforced.

### Build Order

| Phase | Goal | Risk | Effort |
|-------|------|------|--------|
| 1. Import migration | Remove external `player_engine` dependency | Low | 15 min |
| 2. Wire remaining helpers | Connect D3D11Configurator, SubtitleConfigurator, VolumeController | Low | 30 min each |
| 3. Interface split | Extract capability mixins from flat PlayerEngine | Medium | 2-3 hours |
| 4. Slim FvpEngine | Move remaining inline logic to helpers | Low | 1 hour |
| 5. Clean MockEngine | Remove mixin stubs, keep core only | Low | 30 min |

Each phase is independently shippable. No phase depends on a later phase.

## Critical Pitfalls

### 1. ValueNotifier Ownership (CRITICAL)

FvpEngine owns 13 ValueNotifier instances as `final` fields. If helpers are refactored to own their notifiers, the PlayerEngine abstract contract breaks for MockEngine and FakeEngine. **Prevention**: Keep ownership in FvpEngine, pass references to helpers as constructor params. Never change a `final field` to a `getter` in the abstract class.

### 2. D3D11 Property Timing (CRITICAL)

D3D11 properties must be set between player creation and first `open()`. If applied after, mdk ignores them silently -- no error, just wrong behavior (black screen, tearing, high CPU). **Prevention**: D3D11Configurator.applyDefaults() called inside `_createPlayer()`, with `assert(!_isOpening)` guard.

### 3. MockEngine Contract Drift (CRITICAL)

MockEngine `implements PlayerEngine` (not extends). Every interface change must be reflected in MockEngine, FakeEngine, and any `_FakeEngine` variants in test files. **Prevention**: Migrate MockEngine first. Run `dart analyze` on engine directory in isolation before touching UI files. Update all fakes immediately on interface change.

### 4. Helper Initialization Order (HIGH)

Five helpers use `late` initialization inside `_createPlayer()`. Adding three more creates dependency chains (D3D11Configurator needs mdk.Player, VolumeController needs ValueNotifiers). Missing initialization order causes `LateInitializationError` at runtime with no static analysis warning. **Prevention**: Strict ordering in `_createPlayer()`, `_helpersInitialized` guard bool.

### 5. Callback Wiring Gaps (HIGH)

FvpCallbackHandler has an `onStopPositionPolling` callback creating cross-helper dependency. New helpers will need similar wiring (VolumeController state changes, SubtitleConfigurator subtitleText updates). Missing a callback means a ValueNotifier never updates -- stale UI data with no error. **Prevention**: Document callback contracts per helper. Wire all in `_createPlayer()`. Integration tests verify notifier values after state transitions.

## Implications for Roadmap

1. **Phase 1 (import migration) should be the first commit.** It is mechanical, low-risk, and eliminates the biggest source of confusion (dual import paths). Gate: `flutter analyze` + `flutter test` pass with zero errors.

2. **Phase 2 (wire remaining helpers) should come before interface split.** The three unwired helpers are already extracted and tested. Wiring them is mechanical delegation with no API change. This reduces FvpEngine to ~350 lines, making the subsequent interface split cleaner.

3. **Phase 3 (interface split via mixins) is the highest-risk phase.** It changes the PlayerEngine contract that 57 files depend on. Mitigate by: adding mixins alongside existing methods first (additive), updating FvpEngine/MockEngine, then removing duplicate methods from base. Fallback: keep flat interface but use extension methods.

4. **Phase 4-5 (slim FvpEngine, clean MockEngine) are low-risk polish.** Internal only, no API changes. Can be done incrementally.

5. **Testing must happen after each phase, not just at the end.** Each extraction should be a separate commit with passing tests. Run integration tests after EACH helper extraction.

6. **media_kit migration is deferred.** The composition pattern makes a future swap feasible (only FvpEngine and helpers change, UI untouched), but media_kit lacks D3D11 sync control. Evaluate when Linux/macOS support becomes primary.

## Sources

- `.planning/research/STACK.md` -- Import migration, composition patterns, testing strategy, Flutter desktop specifics, anti-patterns
- `.planning/research/FEATURES.md` -- Table stakes features, differentiators, anti-features, UI consumption map, dependency graph
- `.planning/research/ARCHITECTURE.md` -- Current/target architecture, component boundaries, data flow, build order, reference architectures (IINA, VLC, media_kit, mpv)
- `.planning/research/PITFALLS.md` -- 22 specific pitfalls across import migration, composition, platform, and testing dimensions with prevention strategies
