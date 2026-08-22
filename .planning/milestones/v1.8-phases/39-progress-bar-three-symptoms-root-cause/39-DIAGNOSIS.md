# Phase 39 Progress-Bar Diagnosis

## Observed symptoms

- **PROG-01:** A non-zero duration is required before `ProgressBar` enables seek, slider semantics, and the live preview. The real Windows run proves the raw Player, `MediaKitPlayerPort`, and `PlayerControlsState` receive duration, but the production `ControlBar` shell omits the timeline.
- **PROG-02:** Seek and apparent seek rollback must be diagnosed without regressing the existing event-driven v2 hold behavior. The Task 1 fake tracer proves the intended state-to-progress handoff can issue taps and drags after delayed duration arrival.
- **PROG-03:** Hover preview needs both a non-zero duration and pointer delivery to `ProgressBar`. Task 1 proves two hover coordinates update the self-drawn preview and separately proves an opaque sibling can intercept pointer events.

## Data-chain map

```text
Player.stream.duration/position
  -> MediaKitPlayerPort.duration/position
  -> PlayerControlsState.init() -> durationMs/positionMs
  -> _createControlBarViewModel() -> vm.duration/vm.position
  -> ControlBarTimeline.build() -> ProgressBar
  -> _ProgressBarState.build() -> slider semantics, seek, hover preview
```

The real test subscribes to raw Player streams before `MediaKitPlayerPort` exists. It then proves the intended direct `ControlBarTimeline` path and separately mounts the production `ControlBar` shell. This distinguishes transport evidence from the production composition boundary.

## Evidence matrix

| Layer / candidate | Evidence | Result |
| --- | --- | --- |
| Raw Player stream | `[P39] #12` contains `raw.player.stream.duration observed value=10026`; position was observed before port creation at `#2`. | Observed; fixture/harness valid. |
| Port subscription | `#5` subscription, `#13` `port.stream.duration observed value=10026`, and `#10` position. | Observed; port forwarding is ruled out. |
| State initialization | `#14` `state.durationMs observed value=10026`; `#11` state position. | Observed; `PlayerControlsState.init` is ruled out for the active source. |
| ViewModel / intended timeline | `#8` and `#9` show stable notifier identity; Task 1 direct tree reaches `ProgressBar`. | Observed; `_createControlBarViewModel` and `ControlBarTimeline.build` work when composed. |
| Intended widget | `#15`–`#17` show non-zero widget duration/position and slider semantics. | Observed; `_ProgressBarState.build` is not the first loss. |
| Production shell composition | `#18` records `production.timeline.insertion missing-after-deadline`. Task 1 shell tracer also finds neither `ControlBarTimeline` nor `ProgressBar`. | First failing production edge. |
| Source replacement / stale subscriptions | Task 1 `port-to-state replacement` preserves notifier identity and rejects old-port events. | `updateSources` timing ruled out by fake isolation. |
| Pointer hit testing | Task 1 `pointer-hit` proves tap, drag, two hover x values, and an opaque sibling interception condition. | Pointer path is a distinct downstream concern, not this first boundary. |

## Real Windows evidence

Command used from the worktree root:

```text
mkdir -p .planning/milestones/v1.8-phases/39-progress-bar-three-symptoms-root-cause/.tmp && set -o pipefail && D:/flutter/bin/flutter test integration_test/progress_bar_real_runtime_diagnosis_test.dart -d windows --reporter expanded 2>&1 | tee .planning/milestones/v1.8-phases/39-progress-bar-three-symptoms-root-cause/.tmp/39-real-runtime.log
```

Full continuous `[P39]` trace:

```text
[P39] #1 fixture.open started basename=tiny_valid.mp4
[P39] #2 raw.player.stream.position observed value=0
[P39] #3 raw.player.stream.duration observed-zero value=0
[P39] #4 fixture.open observed basename=tiny_valid.mp4
[P39] #5 port.subscribe observed
[P39] #6 port.snapshot.duration observed-zero value=0
[P39] #7 port.snapshot.position observed value=0
[P39] #8 viewModel.notifier.identity observed duration=395860990 position=790314983
[P39] #9 timeline.notifier.identity observed duration=395860990 position=790314983
[P39] #10 port.stream.position observed value=302
[P39] #11 state.positionMs observed value=302
[P39] #12 raw.player.stream.duration observed value=10026
[P39] #13 port.stream.duration observed value=10026
[P39] #14 state.durationMs observed value=10026
[P39] #15 widget.durationMs observed value=10026
[P39] #16 widget.positionMs observed value=8452
[P39] #17 widget.semantics observed slider=true
[P39] #18 production.timeline.insertion missing-after-deadline
[P39] #19 diagnosis.firstBrokenBoundary=lib/ui/player/control_bar_layout.dart:ControlBarLayout._buildLayout observed
[P39] #20 diagnosis.positionCrossEvidence observed
```

## First broken link

The unique first broken link is `lib/ui/player/control_bar_layout.dart:ControlBarLayout._buildLayout`.

Adjacent evidence is ordered: the intended widget receives duration and exposes semantics at **#15–#17**, while the exact production `ControlBar` shell reports no `ControlBarTimeline` insertion at **#18**. The evaluator records that unique result at **#19**. Upstream transport has already been proven by raw duration **#12**, port duration **#13**, and state duration **#14**. Therefore no port, state, ViewModel, timeline-forwarding, or `ProgressBar` rendering patch can repair the production shell until `_buildLayout` composes the timeline.

## Ruled-out candidates

- `lib/ui/player/media_kit_player_port.dart:MediaKitPlayerPort.duration` is not broken: raw and port duration both emit `10026` ms at #12 and #13.
- `lib/ui/player/player_video_controls.dart:PlayerControlsState.init` is not broken for the active source: state duration emits `10026` ms at #14; Task 1 also isolates replacement behavior.
- `lib/ui/player/player_video_controls.dart:_createControlBarViewModel` is not broken: #8 and #9 preserve the same duration/position notifier identities.
- `lib/ui/player/control_bar_timeline.dart:ControlBarTimeline.build` and `lib/ui/player/progress_bar.dart:_ProgressBarState.build` are not first breaks: direct intended composition produces non-zero widget values and slider semantics at #15–#17.
- Native fixture or MDK harness failure is ruled out: fixture open completed at #4 and raw duration is non-zero at #12.

## Protected behavior

- Preserve C event-driven v2 seek-hold: after drag end, hold the local drag value until `position` reaches the seek target within `Tokens.progressSeekArriveToleranceMs`; retain `Tokens.progressSeekHoldTimeoutMs` only as the failure/slow-seek backstop. Do not restore a fixed delayed clear.
- Preserve the boundary between static `AppTooltip` affordances and `ProgressBar`'s self-drawn real-time preview bubble. The preview follows pointer x and duration; static tooltips must not substitute for it.
- The Task 1 tracer remains the non-FFI regression proof for delayed duration, replacement isolation, tap/drag, and pointer hit behavior.

## Plan 02 repair contract

1. Modify `lib/ui/player/control_bar_layout.dart:ControlBarLayout._buildLayout` to insert `ControlBarTimeline` into the current production content layout, using the existing `vm`, `resizing`, `onSeekStart`, and `onSeekEnd` inputs. Do not add a second controls tree or restore `ControlsOverlay`.
2. Keep `lib/ui/player/player_video_controls.dart:_createControlBarViewModel` notifier identity stable across stream events and source replacement; Plan 02 must not recreate the two data notifiers.
3. Keep `lib/ui/player/control_bar_timeline.dart:ControlBarTimeline.build` forwarding `vm.duration`, `vm.position`, and `vm.onSeek` directly to `ProgressBar`.
4. With `P39_POST_REPAIR=true`, the retained Windows integration diagnostic must require `production.timeline.insertion observed`; it must still require a non-zero `raw.player.stream.duration`, log all layers, and fail on a non-unique boundary.
5. Re-run `test/widget/player/progress_bar_data_chain_diagnosis_test.dart` so delayed arrival, source replacement, C seek-hold, and pointer-hit evidence remain protected.
