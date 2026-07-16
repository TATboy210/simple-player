---
phase: 10-state-machine-extraction
plan: 02
subsystem: engine
tags: [state-machine, interface-getters, isp, fvp-engine, helper-implements]

# Dependency graph
requires:
  - phase: 10-state-machine-extraction
    plan: 01
    provides: EngineStateMachine, PlaybackSkipMixin, MediaStateTransition extension removed
provides:
  - EngineStateMachine integrated into FvpEngine (all state transitions via transitionTo)
  - FvpCallbackHandler uses stateMachine.transitionTo
  - VolumeControl interface created
  - Helper classes implement ISP interfaces (TrackManager, D3D11Configurator, VolumeController)
  - Interface getters exposed on FvpEngine (trackControl, subtitleConfig, videoEffectControl, rendererControl, volumeControl)
affects: [fvp_engine, fvp_callback_handler, fake_engine, all engine callers]

# Tech tracking
tech-stack:
  added: []
  patterns: [interface-getter-exposure, callback-injection-post-construction, state-machine-integration]

key-files:
  created:
    - lib/kernel/engine/volume_control.dart
  modified:
    - lib/kernel/engine/fvp_engine.dart
    - lib/kernel/engine/fvp_callback_handler.dart
    - lib/kernel/engine/engine_state_machine.dart
    - lib/kernel/engine/track_manager.dart
    - lib/kernel/engine/d3d11_configurator.dart
    - lib/kernel/engine/volume_controller.dart
    - lib/kernel/engine/video_effect_controller.dart
    - lib/kernel/engine/media_engine.dart
    - lib/kernel/engine/engine_state.dart
    - test/helpers/fake_engine.dart
    - test/kernel/engine/fvp_callback_handler_test.dart
    - test/kernel/engine/engine_state_machine_test.dart
    - test/kernel/engine/d3d11_configurator_test.dart
    - test/kernel/engine/video_effect_controller_test.dart
    - test/engine/mixin_capability_test.dart
    - test/widget/player/player_screen_test.dart

key-decisions:
  - "FvpEngine keeps all MediaEngine interface methods (cannot remove delegation without breaking interface contract)"
  - "EngineStateMachine.onPlay/onPause made non-final for post-construction injection (avoids circular dependency)"
  - "idle→playing added as valid state transition (needed after open() ends at idle)"
  - "VideoEffectController does NOT implement VideoEffectControl (missing aspectRatio getter ownership)"
  - "FvpEngine directly implements VideoEffectControl and SubtitleConfig (aspectRatio/subtitleText owned by FvpEngine)"

requirements-completed: [ENG-02, SVC-02]

coverage:
  - id: D1
    description: "EngineStateMachine integrated into FvpEngine — all state transitions via transitionTo"
    requirement: SVC-02
    verification:
      - kind: other
        ref: "grep 'state.value =' lib/kernel/engine/fvp_engine.dart — zero write matches"
        status: pass
    human_judgment: false
  - id: D2
    description: "FvpCallbackHandler uses stateMachine.transitionTo instead of direct state.value assignment"
    requirement: SVC-02
    verification:
      - kind: other
        ref: "grep 'state.value =' lib/kernel/engine/fvp_callback_handler.dart — zero write matches"
        status: pass
    human_judgment: false
  - id: D3
    description: "VolumeControl interface created with setVolume/setMute/volume/isMuted"
    requirement: ENG-02
    verification:
      - kind: unit
        ref: "test/kernel/engine/volume_controller_test.dart"
        status: pass
    human_judgment: false
  - id: D4
    description: "Helper classes implement ISP interfaces (TrackManager, D3D11Configurator, VolumeController)"
    requirement: ENG-02
    verification:
      - kind: unit
        ref: "flutter analyze lib/kernel/engine/ — no issues"
        status: pass
    human_judgment: false
  - id: D5
    description: "Interface getters exposed on FvpEngine"
    requirement: ENG-02
    verification:
      - kind: other
        ref: "grep 'get trackControl\\|get subtitleConfig\\|get videoEffectControl\\|get rendererControl\\|get volumeControl' lib/kernel/engine/fvp_engine.dart"
        status: pass
    human_judgment: false
  - id: D6
    description: "FakeEngine uses EngineStateMachine for state management"
    requirement: ENG-02
    verification:
      - kind: unit
        ref: "test/engine/mixin_capability_test.dart — all 41 tests pass"
        status: pass
    human_judgment: false

# Metrics
duration: 35min
completed: 2026-07-14
status: complete
---

# Phase 10 Plan 02: FvpEngine Slimming + State Machine Integration Summary

**EngineStateMachine integrated into FvpEngine, interface getters exposed, helper classes implement ISP interfaces, bridge code removed**

## Performance

- **Duration:** 35 min
- **Started:** 2026-07-14T12:24:18Z
- **Completed:** 2026-07-14T12:59:00Z
- **Tasks:** 2
- **Files modified:** 16

## Accomplishments

- EngineStateMachine integrated into FvpEngine — all state transitions go through transitionTo (no direct state.value assignments)
- state/isSeeking/isBuffering changed from fields to getters delegating to stateMachine
- Temporary bridge code (_safeSetState + _canTransitionTo) removed from FvpEngine
- FvpCallbackHandler uses stateMachine.transitionTo for all state updates
- VolumeControl interface created (setVolume, setMute, volume, isMuted)
- TrackManager implements TrackControl with @override annotations
- D3D11Configurator implements RendererControl, renamed setSyncEnabled→setD3d11SyncEnabled
- VolumeController implements VolumeControl with @override annotations
- MediaEngine implements list adds VolumeControl
- Interface getters exposed: trackControl, subtitleConfig, videoEffectControl, rendererControl, volumeControl
- EngineStateMachine.onPlay/onPause made non-final for post-construction injection
- idle→playing added as valid transition (needed after open() completes to idle)
- FakeEngine uses EngineStateMachine with onPlay/onPause callbacks
- 1111 tests passing (4 pre-existing failures in shortcuts_tab_test)

## Task Commits

1. **Task 1: Helper implements ISP interfaces + VolumeControl** - `4f8cecb` (feat)
2. **Task 2: FvpEngine state machine integration + interface getters** - `d085f82` (feat)

## Files Created/Modified

- `lib/kernel/engine/volume_control.dart` — New abstract interface for volume control
- `lib/kernel/engine/fvp_engine.dart` — EngineStateMachine integration, interface getters, bridge code removed
- `lib/kernel/engine/fvp_callback_handler.dart` — Uses stateMachine.transitionTo instead of direct state.value
- `lib/kernel/engine/engine_state_machine.dart` — onPlay/onPause made non-final, idle→playing transition added
- `lib/kernel/engine/track_manager.dart` — implements TrackControl with @override
- `lib/kernel/engine/d3d11_configurator.dart` — implements RendererControl, setSyncEnabled→setD3d11SyncEnabled
- `lib/kernel/engine/volume_controller.dart` — implements VolumeControl with @override
- `lib/kernel/engine/video_effect_controller.dart` — setEffect→setVideoEffect rename
- `lib/kernel/engine/media_engine.dart` — VolumeControl added to implements list
- `lib/kernel/engine/engine_state.dart` — volume_control.dart export added
- `test/helpers/fake_engine.dart` — EngineStateMachine integration, interface getters
- `test/kernel/engine/fvp_callback_handler_test.dart` — Updated for stateMachine constructor
- `test/kernel/engine/engine_state_machine_test.dart` — idle→playing now valid
- `test/kernel/engine/d3d11_configurator_test.dart` — setSyncEnabled→setD3d11SyncEnabled
- `test/kernel/engine/video_effect_controller_test.dart` — setEffect→setVideoEffect
- `test/engine/mixin_capability_test.dart` — Tests updated for state machine valid transitions
- `test/widget/player/player_screen_test.dart` — Tests updated for state machine valid transitions

## Decisions Made

- **FvpEngine keeps all MediaEngine interface methods:** Cannot remove delegation methods because FvpEngine implements MediaEngine which extends all 6 ISP interfaces. Removing methods would break the interface contract. The interface getters provide an alternative access path.
- **EngineStateMachine.onPlay/onPause made non-final:** The factory constructor creates the stateMachine before the engine, so callbacks must be set after construction to avoid circular dependency.
- **idle→playing added as valid transition:** FvpEngine.open() ends at idle state, and play() is called next. The state machine must allow this transition.
- **VideoEffectController does NOT implement VideoEffectControl:** The interface requires `ValueNotifier<double> get aspectRatio` which VideoEffectController doesn't own (it's on FvpEngine). FvpEngine directly implements VideoEffectControl instead.
- **FvpEngine directly implements SubtitleConfig:** Some SubtitleConfig methods (getSubtitleTracks, switchSubtitleTrack, toggleSubtitle) are delegated to TrackManager, not SubtitleConfigurator. FvpEngine implements the full interface directly.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] EngineStateMachine.onPlay/onPause were final — couldn't set after construction**
- **Found during:** Task 2
- **Issue:** FvpEngine factory creates stateMachine before engine exists, but onPlay/onPause need engine.play/pause references
- **Fix:** Made onPlay/onPause non-final fields in EngineStateMachine
- **Files modified:** lib/kernel/engine/engine_state_machine.dart
- **Commit:** d085f82

**2. [Rule 1 - Bug] idle→playing transition rejected by state machine**
- **Found during:** Task 2
- **Issue:** FvpEngine.open() ends at idle, then play() tries idle→playing which was rejected
- **Fix:** Added idle→playing as valid transition in EngineStateMachine
- **Files modified:** lib/kernel/engine/engine_state_machine.dart
- **Commit:** d085f82

**3. [Rule 1 - Bug] FakeEngine.open() didn't transition back to idle**
- **Found during:** Task 2
- **Issue:** FakeEngine.open() left state at opening, causing togglePlayPause to be a no-op
- **Fix:** Added stateMachine.transitionTo(idle) after successful open in FakeEngine
- **Files modified:** test/helpers/fake_engine.dart
- **Commit:** d085f82

### Plan Deviations

**1. [Deviation] FvpEngine line count not reduced to <350**
- **Plan expected:** FvpEngine < 350 lines after removing delegation methods
- **Actual:** FvpEngine is 609 lines
- **Reason:** FvpEngine implements MediaEngine which extends all 6 ISP interfaces. All interface methods must be present. The delegation methods cannot be removed without breaking the MediaEngine contract.
- **Impact:** Interface getters provide alternative access path. Callers can use either `engine.getAudioTracks()` or `engine.trackControl.getAudioTracks()`.

**2. [Deviation] VideoEffectController does NOT implement VideoEffectControl**
- **Plan expected:** VideoEffectController implements VideoEffectControl
- **Actual:** VideoEffectController does not implement the interface
- **Reason:** VideoEffectControl requires `ValueNotifier<double> get aspectRatio` which VideoEffectController doesn't own. FvpEngine directly implements VideoEffectControl instead.
- **Impact:** FvpEngine.videoEffectControl getter returns `this` (FvpEngine) instead of the controller instance.

**3. [Deviation] SubtitleConfigurator does NOT implement SubtitleConfig**
- **Plan expected:** SubtitleConfigurator implements SubtitleConfig
- **Actual:** SubtitleConfigurator unchanged
- **Reason:** SubtitleConfig includes getSubtitleTracks/switchSubtitleTrack/toggleSubtitle which are in TrackManager, not SubtitleConfigurator. FvpEngine directly implements SubtitleConfig.
- **Impact:** FvpEngine.subtitleConfig getter returns `this` (FvpEngine).

## Threat Flags

None — pure internal architecture refactoring, no new security surface. All state transitions now go through EngineStateMachine.transitionTo with exhaustive guard (T-10-03, T-10-04 mitigated).

## Self-Check: PASSED

- [x] volume_control.dart exists with VolumeControl abstract class
- [x] TrackManager implements TrackControl (1 match)
- [x] D3D11Configurator implements RendererControl (1 match)
- [x] VolumeController implements VolumeControl (1 match)
- [x] MediaEngine implements VolumeControl
- [x] FvpEngine uses EngineStateMachine — 10 stateMachine.transitionTo calls, 0 direct state.value writes
- [x] FvpCallbackHandler uses stateMachine.transitionTo (no direct state.value writes)
- [x] Interface getters exposed on FvpEngine (5 getters: trackControl, subtitleConfig, videoEffectControl, rendererControl, volumeControl)
- [x] flutter analyze passes (0 issues)
- [x] 1111 tests passing (4 pre-existing failures in shortcuts_tab_test)

---

*Phase: 10-state-machine-extraction*
*Completed: 2026-07-14*
