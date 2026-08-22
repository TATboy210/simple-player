# Phase 35 Widget Tree and Behavior Baseline

**Recorded:** 2026-08-11  
**Scope:** BASE-01, BASE-02, BASE-03  
**Method:** local Git history was inspected with read-only `git log`, `git show`, and `git diff` commands. No historical source was checked out, restored, reset, staged, or committed.

## Protected Working-Tree Snapshot

The execution-start `git status --short` contained pre-existing changes in planning documents, player UI source, helpers, and tests. The Phase 35-protected UI/test subset was:

- `lib/ui/player/center_controls.dart`
- `lib/ui/player/control_bar.dart`
- `lib/ui/player/control_bar_actions.dart`
- `lib/ui/player/control_bar_layout.dart`
- `lib/ui/player/control_bar_title.dart`
- `lib/ui/player/player_screen.dart`
- `lib/ui/player/player_video_controls.dart`
- `lib/ui/shared/glass_container.dart`
- `lib/ui/window/custom_title_bar.dart`
- `test/widget/player/player_video_controls_test.dart`

The following untracked PNG files are a protected inventory only. Their contents were not read and none was deleted, staged, or committed:

- `114514-upscaled.png`
- `devtools-current.png`
- `devtools-live-performance.png`
- `devtools-performance.png`

`git diff --check` reported no whitespace errors. It emitted only Git's pre-existing LF-to-CRLF working-copy warnings for planning documents.

## Historical Boundaries

| Boundary | Read-only evidence | Behavior interpretation |
|---|---|---|
| `e0083842^..e0083842` | `refactor(player): unify controls and remove legacy fullscreen plugin`; changed `player_screen.dart`, `player_video_controls.dart`, player actions/keyboard actions, fake video controls, and lifecycle tests; deleted `packages/fullscreen_window`. | Establishes the controls-builder direction and removes the former fullscreen plugin from recovery candidates. |
| `e0083842..f590cce2` | `refactor: stabilize player resize and control rendering`; deleted `lib/ui/player/controls_overlay.dart` and its test, substantially revised PlayerScreen, PlayerVideoControls, ControlBar, GlassContainer, resize behavior, and widget tests. | This is the architectural break from the old overlay tree to direct controls inside `Video.controls`; preserve the new tree rather than revert files wholesale. |
| `f590cce2..6e0edbb8` | `refactor(custom_title_bar): optimize PC window mode transitions for smooth rendering`; only `lib/ui/window/custom_title_bar.dart` changed in the scoped UI/test surface. | Retains the cached static title row, local mode listeners, and repaint isolation as the current title-bar stabilization baseline. |
| `6e0edbb8..HEAD` | The scoped implementation remains at the stabilized structure; the subsequent committed Phase 35 research commit is planning-only. | No historical source snapshot after this boundary authorizes replacing the current controls architecture. |
| Current unstaged diff | The protected subset lists nine UI source files and `player_video_controls_test.dart` as modified. It adds 337 and removes 127 lines across the source subset; the test has 729 additions. | These are user-owned, uncommitted increments and are audit inputs only. They are not recovery targets and were not overwritten. |

## Per-File Behavior Matrix

| File / test surface | `e0083842` direction | `f590cce2` direction | `6e0edbb8` / current stable behavior | Classification |
|---|---|---|---|---|
| `lib/ui/player/player_screen.dart` | Routes controls through a `Video.controls` builder and adds actions/keyboard support. | Removes the old overlay composition and anchors resize-safe video composition. | `_buildVideoSurface()` passes `controls: _buildControls`; `_buildControls()` calls `playerVideoControls(...)`; injected test surfaces use `PlayerVideoControls` with a fake port. | Preserve current stable composition. |
| `lib/ui/player/player_video_controls.dart` | Introduces the route-aware video controls adapter and focused lifecycle tests. | Becomes the direct control layer with route-local fullscreen and subtitle behavior. | `PlayerControlsState` maintains port subscriptions; route-local `VideoControlsPort` handles fullscreen and subtitle padding; `deactivate`/`activate` detach and restore external listeners. | Preserve current stable composition; targeted fixes only when a failing lifecycle test authorizes one. |
| `lib/ui/player/control_bar.dart` | Participates in the post-plugin direct controls path. | Is retained while the old overlay is deleted; rendering and resize behavior are localized. | `PlayerVideoControls._buildControlBar()` creates `ControlBar`, passing local state/listenables, auto-hide callbacks, fullscreen callback, and resize signal. | Preserve current stable composition. |
| `lib/ui/shared/glass_container.dart` | No fullscreen-plugin responsibility. | Updated alongside rendering stabilization. | `GlassContainer` and `GlassButton` retain stable ancestor/filter behavior; cached activation action invokes the current `widget.onPressed`. | Preserve current stable behavior; callback regression repair only if a test fails. |
| `lib/ui/window/custom_title_bar.dart` | Not the controls-routing seam. | Participates in resize/control rendering stabilization. | Caches static title controls, rebuilds them when the `WindowBridge` changes, and isolates dynamic mode state with local listeners and a repaint boundary. | Preserve the `6e0edbb8` stabilization. |
| `test/widget/player/player_video_controls_test.dart` | Adds fake-port and route/lifecycle coverage. | Expands source replacement, subtitle, resize, auto-hide, and route-keyboard regression coverage. | Current tests assert eight stream subscriptions, old-source isolation, reparent behavior, inactive guards, current-route F/ESC semantics, and filter identity. | Regression evidence; do not relax assertions. |
| `test/widget/player/player_screen_accessibility_resize_test.dart` | Not present at the initial controls-unification boundary. | Added with resize stabilization. | Injected fake controls and a test surface prove player semantics and surface element identity survive repeated resize sessions. | Regression evidence. |
| `test/widget/shared/glass_button_test.dart` | Relevant callback-cache behavior follows `d0ba3898`, preceding this phase boundary. | Retained as shared-control coverage. | Icon-only path verifies callback replacement; label rendering/tap/disabled behavior is covered. | Keep existing coverage; label callback replacement remains a Plan 02 test gap. |
| `test/widget/player/controls_overlay_test.dart` | Historical old-tree test. | Deleted together with `ControlsOverlay`. | No current production path refers to it. | Deleted architecture; forbidden from restoration. |

## Locked Current Main Path

The production main path is confirmed from current source, not inferred from a historical snapshot:

```text
PlayerScreen
  -> Video.controls: _buildControls
  -> playerVideoControls(VideoState, ...)
  -> PlayerVideoControls
  -> PlayerVideoControls._buildControlBar()
  -> ControlBar
```

Source evidence:

- `lib/ui/player/player_screen.dart`: `_buildVideoSurface()` creates `Video` with `controls: _buildControls`; `_buildControls(VideoState)` delegates to `playerVideoControls`.
- `lib/ui/player/player_video_controls.dart`: `playerVideoControls` wraps the current `VideoState` in `MediaKitVideoControlsPort` and constructs `PlayerVideoControls`.
- `lib/ui/player/player_video_controls.dart`: `_buildControlBar()` constructs `ControlBar` using current route state and local listenables.

## Explicit Exclusions and Recovery Rule

The following are not recovery candidates:

1. `ControlsOverlay` and its test: removed by `f590cce2`; reconnecting it would create competing control/lifecycle trees.
2. The old `fullscreen_window` plugin: deleted by `e0083842`; it must not return as a replacement for the route-local `VideoControlsPort` flow.
3. `media_kit` / `libmpv`: external media capabilities are not modified by Phase 35.
4. The protected untracked PNG files: no visual claim or recovery choice is based on their contents.

A historical implementation may be considered only after a concrete current behavior regression has a failing automated test. The permitted response is a minimal file/method-level repair that preserves the locked main path; whole-tree restoration is prohibited.

## BASE-03 Automated Behavior Matrix

The following targeted command completed successfully on this working tree:

```text
flutter test test/widget/shared/glass_button_test.dart test/widget/player/player_video_controls_test.dart test/widget/player/player_screen_accessibility_resize_test.dart test/widget/player/player_screen_stop_empty_state_test.dart test/widget/player/player_keyboard_actions_test.dart test/widget/player/drop_handler_test.dart test/integration/controls_flow_test.dart test/integration/error_propagation_test.dart
```

Result: **79 tests passed**. The quick gate did not initialize real MDK/libmpv and did not emit an `mdk.dll` or FFI failure, so detached-HEAD worktree isolation was not needed.

| User behavior | Automated evidence |
|---|---|
| Play/pause and keyboard play/pause | `player_video_controls_test.dart` verifies control actions and Space; `player_keyboard_actions_test.dart` verifies the window keyboard route. |
| Seek | `player_video_controls_test.dart` verifies left/right actions; `controls_flow_test.dart` verifies engine control state. |
| Volume and mute | `controls_flow_test.dart` verifies set-volume clamping and mute behavior; controls-state tests verify engine routing. |
| Playback speed | `controls_flow_test.dart` verifies speed state; controls-state tests verify rate port routing. |
| Subtitle padding | `player_video_controls_test.dart` verifies initial padding, source replacement, reparenting, mounted guard, and disposal isolation. |
| Fullscreen and ESC | `player_video_controls_test.dart` verifies F toggles the current route port, ESC exits only the current fullscreen route, and window-state ESC does not invoke route operations. |
| Empty state and open-file delay | `player_screen_stop_empty_state_test.dart` verifies media unload precedes the empty state and both button/O-key share the delayed gate. |
| Error propagation and recovery actions | `error_propagation_test.dart` verifies engine error to ErrorBanner display, dismissal/recovery, and file/playback/codec/network actions. |
| Drag/drop | `drop_handler_test.dart` verifies entered/exited hover state, empty-drop behavior, and overlay wiring. Real OS file-drop remains Phase 38 manual/native scope. |
| Keyboard shortcuts | `player_keyboard_actions_test.dart` and `player_video_controls_test.dart` verify the focused route/window action mappings. |
| Window mode state | `controls_flow_test.dart` verifies fullscreen/windowed mode updates through the fake WindowBridge; PlayerScreen resize tests use `FakeWindowService`. |
| Resize identity and semantics | `player_screen_accessibility_resize_test.dart` verifies repeated resize sessions retain core semantics and the injected surface element identity. |
| GlassButton activation semantics | `glass_button_test.dart` verifies Space/Enter activation, latest icon-only callback after rebuild, disabled behavior, semantics, and focus traversal. |

Additional independent gates:

| Command | Result |
|---|---|
| `flutter analyze` | Passed: `No issues found!` |
| `git diff --check` | Passed: no whitespace errors; only pre-existing CRLF conversion warnings for planning files |

## Reproducible Phase 35 Gate

Run the targeted command above, then independently run:

```text
flutter analyze
git diff --check
```

If a future quick gate reports `mdk.dll`/FFI failures, preserve the full failure list and rerun the identical command from a temporary detached-HEAD worktree before classifying it as pre-existing. Do not stash, reset, checkout, restore, skip, delete assertions, or weaken matchers to change the result.

## Baseline Conclusion

The current direct control path is the behavior baseline. Current UI stabilization and user-owned unstaged changes must be preserved. The only allowed Phase 35 recovery work is a failing-test-authorized, minimal repair within the current `Video.controls -> PlayerVideoControls -> ControlBar` architecture.
