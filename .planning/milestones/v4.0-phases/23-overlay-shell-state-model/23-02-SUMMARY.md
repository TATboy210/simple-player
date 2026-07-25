---
phase: 23-overlay-shell-state-model
plan: 02
subsystem: ui
tags: [settings-panel, overlay-shell, glass-morphism, value-notifier, tdd, keyboard-focus, drag-gesture]

# Dependency graph
requires:
  - phase: 23-overlay-shell-state-model
    plan: 01
    provides: SettingsPanelState + SettingsPanelController + SettingsPanelPlayback contract + AppleCurves
provides:
  - SettingsOverlayShell widget (glass shell + mask + title bar + close button + animation)
  - In-tree Stack mounting in PlayerScreen (D-05)
  - PlayerFeature composition root wiring for SettingsPanelController (D-02)
  - Title-bar drag with MediaQuery clamping (D-09 / PANEL-04)
  - ESC/B keyboard close with KeyEventResult.handled (D-10 / PANEL-06)
  - Responsive panel sizing min(500, w*0.8) x min(400, h*0.8) (PANEL-07)
  - D-06 cutover: removed old onSettings callback path from App/DeferredPlayerFeature/PlayerFeature
affects: [25-tabs-settings-shell, 26-settings-panel-polish]

# Tech tracking
tech-stack:
  added: []
  patterns: [in-tree-stack-overlay, focus-traversal-group-keyboard-scope, transform-translate-drag, ignore-pointer-hit-gating]

key-files:
  created:
    - lib/ui/dialogs/settings/settings_overlay_shell.dart
    - test/ui/dialogs/settings_overlay_shell_test.dart
  modified:
    - lib/ui/player/player_screen.dart
    - lib/features/player/player_feature.dart
    - lib/features/player/deferred_player_feature.dart
    - lib/app.dart
    - test/widget/player/player_screen_test.dart

key-decisions:
  - "D-05 (locked): Shell mounts as topmost Stack child in PlayerScreen content area below CustomTitleBar"
  - "D-06 cutover: Removed onSettings callback path from App/DeferredPlayerFeature/PlayerFeature; gear button now calls settingsPanelController.open"
  - "D-09: Title-bar drag uses GestureDetector.onPanUpdate with Transform.translate, clamped to MediaQuery bounds; no WindowBridge drag API"
  - "D-10: FocusTraversalGroup + autofocus Focus consumes ESC/B with KeyEventResult.handled, preventing bubble to KeyboardHandler"

patterns-established:
  - "Pattern: in-tree Stack overlay mounting — overlay shell as topmost Stack sibling below title bar, driven by ValueNotifier<bool> isOpen"
  - "Pattern: FocusTraversalGroup keyboard scope — self-managed Focus subtree that consumes modal keys (ESC/B) without interfering with global KeyboardHandler"

requirements-completed: [PANEL-01, PANEL-03, PANEL-04, PANEL-05, PANEL-06, PANEL-07]

coverage:
  - id: D1
    description: "SettingsOverlayShell renders GlassContainer(GlassTier.normal) with BackdropFilter, 设置 title, and GlassButton close"
    requirement: "PANEL-03"
    verification:
      - kind: automated_ui
        ref: "test/ui/dialogs/settings_overlay_shell_test.dart#visible shell uses GlassTier.normal BackdropFilter"
        status: pass
    human_judgment: false
  - id: D2
    description: "Title-bar drag updates dragOffset with MediaQuery clamping including undersized windows"
    requirement: "PANEL-04"
    verification:
      - kind: automated_ui
        ref: "test/ui/dialogs/settings_overlay_shell_test.dart#title-bar drag updates dragOffset"
        status: pass
    human_judgment: false
  - id: D3
    description: "Mask tap, close button, and ESC/B all close the shell; closed shell removed from hit-test tree after 200ms exit animation"
    requirement: "PANEL-05"
    verification:
      - kind: automated_ui
        ref: "test/ui/dialogs/settings_overlay_shell_test.dart#mask tap closes shell"
        status: pass
    human_judgment: false
  - id: D4
    description: "AnimatedOpacity + AnimatedScale 200ms with AppleCurves.fullscreenEnter/exit; settled endpoint scale=1.0/opacity=1.0"
    requirement: "PANEL-05"
    verification:
      - kind: automated_ui
        ref: "test/ui/dialogs/settings_overlay_shell_test.dart#settled enter endpoint is scale 1.0"
        status: pass
    human_judgment: false
  - id: D5
    description: "ESC and B close the shell with KeyEventResult.handled; fullscreen-exit observer stays uncalled"
    requirement: "PANEL-06"
    verification:
      - kind: automated_ui
        ref: "test/ui/dialogs/settings_overlay_shell_test.dart#ESC closes open panel"
        status: pass
    human_judgment: false
  - id: D6
    description: "Panel sized min(500, w*0.8) x min(400, h*0.8) with double precision; 625x500 produces exactly 500x400"
    requirement: "PANEL-07"
    verification:
      - kind: automated_ui
        ref: "test/ui/dialogs/settings_overlay_shell_test.dart#625x500 window produces 500x400 panel"
        status: pass
    human_judgment: false
  - id: D7
    description: "PlayerFeature constructs SettingsPanelController from PlaybackController, passes to PlayerScreen, disposes with feature"
    requirement: "PANEL-01"
    verification:
      - kind: unit
        ref: "test/widget/player/player_screen_test.dart (31 tests, all pass)"
        status: pass
    human_judgment: false
  - id: D8
    description: "GlassContainer blur visual effect (requires manual verification on actual display)"
    requirement: "PANEL-03"
    verification: []
    human_judgment: true
    rationale: "Headless widget tests assert BackdropFilter widget existence but cannot verify actual pixel-level blur rendering"

# Metrics
duration: 26min
completed: 2026-07-23
status: complete
---

# Phase 23 Plan 02: Settings Overlay Shell Summary

**In-tree glass overlay shell with mask/close/ESC/B lifecycle, title-bar drag clamping, responsive 500x400-or-80% sizing, wired through PlayerFeature composition root replacing the old showDialog path.**

## Performance

- **Duration:** 26 min
- **Started:** 2026-07-23T11:49:58Z
- **Completed:** 2026-07-23T12:16:12Z
- **Tasks:** 3 (advisory checkpoint + tracer + expansion)
- **Files modified:** 7

## Accomplishments

- Implemented `SettingsOverlayShell` widget with AnimatedOpacity + AnimatedScale 200ms animation using AppleCurves.fullscreenEnter/exit, GlassContainer(GlassTier.normal) panel, mask tap close, and conditional unmount after exit animation
- Wired shell into PlayerScreen as topmost Stack child below CustomTitleBar via SettingsPanelController constructor injection from PlayerFeature composition root
- Removed obsolete `onSettings` callback path from App, DeferredPlayerFeature, and PlayerFeature (D-06 cutover); old `settings_panel.dart` preserved for future deletion commit
- Added title-bar drag with Transform.translate + MediaQuery clamping, ESC/B keyboard close via FocusTraversalGroup, and responsive panel sizing (500x400 base or 80% window constraint)
- 11 widget tests covering: open/close lifecycle, mask close + playback resume, GlassTier.normal + animation endpoint, drag clamping (normal + undersized window), ESC/B close, responsive sizing (threshold + below-threshold), exit animation cleanup

## Task Commits

Each task was committed atomically:

1. **Task 1: Advisory checkpoint (D-05 Stack mounting)** - _(no commit; advisory decision auto-continued)_
2. **Task 2 RED: Failing tracer tests** - `e9e0ac1` (test)
3. **Task 2 GREEN: SettingsOverlayShell widget** - `739d181` (feat)
4. **Task 2 GREEN: Integration wiring (PlayerScreen/PlayerFeature/App)** - `9e42669` (feat)
5. **Task 3: Drag, keyboard, responsive sizing + tests** - `c2b92e2` (feat)
6. **Task 3 fix: PlayerScreen test constructions** - `a487e58` (fix)

**Plan metadata:** _(pending — this commit)_

## Files Created/Modified

- `lib/ui/dialogs/settings/settings_overlay_shell.dart` - SettingsOverlayShell widget: mask + centered GlassContainer panel + title bar with drag + ESC/B keyboard close + responsive sizing + AnimatedOpacity/AnimatedScale 200ms animation
- `test/ui/dialogs/settings_overlay_shell_test.dart` - 11 widget tests covering PANEL-03 through PANEL-07 (open/close, mask, glass, animation, drag, keyboard, sizing, hit-test cleanup)
- `lib/ui/player/player_screen.dart` - Added `settingsPanelController` required parameter, mounted Shell as topmost Stack child, replaced `onSettings` with `settingsPanelController.open`
- `lib/features/player/player_feature.dart` - Constructs SettingsPanelController from `_services.controller`, passes to PlayerScreen, disposes with feature; removed `onSettings` callback
- `lib/features/player/deferred_player_feature.dart` - Removed `onSettings` callback parameter and unused imports
- `lib/app.dart` - Removed `_showSettingsPanel` method, `settings_panel.dart` import, and `onSettings` wiring
- `test/widget/player/player_screen_test.dart` - Added `settingsPanelController` to all 12 PlayerScreen test constructions

## Decisions Made

- **D-05 (locked, advisory):** Shell mounts as topmost Stack child in PlayerScreen content area below CustomTitleBar, matching PlaylistPanel compositing pattern
- **D-06 cutover:** Removed old `onSettings` callback path; gear button now calls `settingsPanelController.open()` via PlayerActions.onSettings VoidCallback
- **Panel structure:** Title bar owns drag GestureDetector; content area has separate tap-blocking GestureDetector to prevent mask click-through; parent panel has no GestureDetector to avoid intercepting title-bar drag gestures

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Missing `settingsPanelController` in PlayerScreen test constructions**
- **Found during:** Task 3 (full `flutter analyze` verification)
- **Issue:** Adding `required settingsPanelController` to PlayerScreen broke 11 direct constructions in `player_screen_test.dart`
- **Fix:** Added `SettingsPanelController(controller)` to all 12 PlayerScreen constructions in the test file
- **Files modified:** `test/widget/player/player_screen_test.dart`
- **Verification:** `flutter analyze test/widget/player/player_screen_test.dart` → "No issues found!"
- **Committed in:** `a487e58`

**2. [Rule 1 - Bug] Parent GestureDetector opaque intercepted title-bar drag gestures**
- **Found during:** Task 3 (drag test failures — dragOffset stayed at 0.0)
- **Issue:** Parent panel `GestureDetector(behavior: HitTestBehavior.opaque, onTap: () {})` intercepted pointer events before the title bar's drag GestureDetector could participate in the gesture arena
- **Fix:** Removed parent panel GestureDetector; added separate tap-blocking GestureDetector only on the empty content area below the title bar
- **Files modified:** `lib/ui/dialogs/settings/settings_overlay_shell.dart`
- **Verification:** All 11 tests pass, including drag tests
- **Committed in:** `c2b92e2`

---

**Total deviations:** 2 auto-fixed (1 blocking — missing test parameter, 1 bug — gesture interception)
**Impact on plan:** Both fixes were necessary for correctness. No scope creep — all changes stayed within the plan's defined shell feature boundary.

## Issues Encountered

- Keyboard tests initially failed with "Timer is still pending" because close() triggers a 200ms Future.delayed for exit animation cleanup. Fixed by adding `pump(Duration(milliseconds: 250))` after close assertions.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `SettingsOverlayShell` is ready for Phase 25 to inject tab content into the panel body
- `SettingsPanelController` is wired through the composition root and ready for additional tab-level state
- Old `settings_panel.dart` (showDialog route) preserved — D-06 reserves deletion for a separate commit after full cutover verification
- No blockers identified for Phase 25

## Self-Check: PASSED

- All 7 created/modified files verified present
- All 5 task commits verified in git log
- 50 tests pass (19 settings panel + 31 player screen)
- `flutter analyze` clean on all modified files

---
*Phase: 23-overlay-shell-state-model*
*Completed: 2026-07-23*
