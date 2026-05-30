---
phase: 10-window-optimization
plan: 01-GAP
type: execute
wave: 1
depends_on: []
gap_closure: true
files_modified:
  - test/kernel/bridge/window_bootstrap_test.dart
autonomous: true
requirements:
  - WIN-04
must_haves:
  truths:
    - "restoreOrCenter sets position and size when saved geometry exists and is on visible display"
    - "restoreOrCenter centers window when saved position is off-screen"
    - "restoreOrCenter centers window when no saved position (null x/y)"
    - "clearFullscreenIfSaved clears isFullscreen flag when true"
    - "clearFullscreenIfSaved is no-op when isFullscreen already false"
    - "_clampToVisibleBounds returns original offset when window is within visible area"
    - "_clampToVisibleBounds returns centered offset when window is off-screen"
  artifacts:
    - path: "test/kernel/bridge/window_bootstrap_test.dart"
      provides: "6+ test cases for WindowBootstrap"
      min_lines: 80
  key_links:
    - from: "test/kernel/bridge/window_bootstrap_test.dart"
      to: "lib/kernel/bridge/window_bootstrap.dart"
      via: "import and test WindowBootstrap static methods"
      pattern: "WindowBootstrap"
---

<objective>
Create unit tests for WindowBootstrap. The original 10-01 worktree was cleaned up before merge, losing the test file. WindowBootstrap uses PlatformDispatcher.instance.views (dart:ui singleton) which is hard to mock directly. Strategy: test the static methods with realistic inputs, and test _clampToVisibleBounds behavior through the public API or by making it @visibleForTesting.

Purpose: Automated verification of restore/center/fail-open behavior (WIN-04 sub-items 1, 3).

Output: test/kernel/bridge/window_bootstrap_test.dart with 6+ test cases
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@lib/kernel/bridge/window_bootstrap.dart
@test/helpers/fake_window_service.dart
@test/kernel/persistence/settings_store_test.dart
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create WindowBootstrap test file with 6+ test cases</name>
  <files>test/kernel/bridge/window_bootstrap_test.dart</files>
  <action>
Create test/kernel/bridge/window_bootstrap_test.dart. Since WindowBootstrap uses PlatformDispatcher.instance.views (dart:ui singleton that cannot be easily mocked), use the following test strategy:

**Strategy A — Test _clampToVisibleBounds via @visibleForTesting:**
Add `@visibleForTesting` annotation to `_clampToVisibleBounds` in window_bootstrap.dart (make it `static Offset clampToVisibleBounds(...)` without underscore prefix, keeping backward compat with a typedef or just renaming). This allows direct testing of the bounds-checking logic without mocking PlatformDispatcher.

**Strategy B — If modifying window_bootstrap.dart is not desired:**
Test through the public API. For clearFullscreenIfSaved, use SharedPreferences.setMockInitialValues (same pattern as settings_store_test.dart). For restoreOrCenter, it calls windowManager.setPosition/setSize/center — these are hard to mock without a fake windowManager. In this case, focus tests on clearFullscreenIfSaved (testable via SharedPreferences mock) and document that restoreOrCenter requires integration testing.

**Preferred: Strategy A** — make _clampToVisibleBounds package-private and @visibleForTesting, then test it directly. This is the most valuable test surface.

Test cases (minimum 6):

1. `clampToVisibleBounds returns original offset when window is within visible area` — x=100, y=100, w=800, h=600 on a 1920x1080 screen should return Offset(100, 100)

2. `clampToVisibleBounds centers when window is off right edge` — x=1800, y=100, w=800, h=600 (x+w=2600 > 1920) should return centered offset

3. `clampToVisibleBounds centers when window is off bottom edge` — x=100, y=900, w=800, h=600 (y+h=1500 > 1080) should return centered offset

4. `clampToVisibleBounds centers when window is off left edge` — x=-700, y=100, w=800, h=600 (x+w=100 < 100 minVisible) should return centered offset

5. `clampToVisibleBounds centers when window is off top edge` — x=100, y=-500, w=800, h=600 (y+h=100 < 100 minVisible) should return centered offset

6. `clearFullscreenIfSaved clears flag when isFullscreen is true` — use SharedPreferences.setMockInitialValues with isFullscreen:true, call clearFullscreenIfSaved, verify SettingsStore.saveIsFullscreen(false) was called

7. `clearFullscreenIfSaved is no-op when isFullscreen is false` — use SharedPreferences.setMockInitialValues with isFullscreen:false, call clearFullscreenIfSaved, verify no save call

If going with Strategy A, also modify lib/kernel/bridge/window_bootstrap.dart:
- Rename `_clampToVisibleBounds` to `clampToVisibleBounds` (remove underscore)
- Add `@visibleForTesting` annotation from package:flutter/foundation.dart
- Import foundation.dart (already imported)

Use `setUp` to call `SharedPreferences.setMockInitialValues({})` and `tearDown` for cleanup. Follow the pattern from test/kernel/persistence/settings_store_test.dart.

For clampToVisibleBounds tests, pass explicit screen dimensions. NOTE: since PlatformDispatcher.instance.views.first is a singleton, the tests will use whatever the test runner provides. The clampToVisibleBounds tests should work because they use the actual display — just verify the math is correct by checking the returned Offset values are within expected ranges.
  </action>
  <verify>
    <automated>cd D:\simple_player_flutter && flutter test test/kernel/bridge/window_bootstrap_test.dart</automated>
  </verify>
  <done>
    - test/kernel/bridge/window_bootstrap_test.dart exists with 6+ test cases
    - Tests cover: on-screen position (passthrough), off-screen (center fallback), clearFullscreenIfSaved (both true and false)
    - All tests pass
    - dart analyze clean on both test file and modified source (if Strategy A)
  </done>
</task>

</tasks>

<verification>
1. `flutter test test/kernel/bridge/window_bootstrap_test.dart` — all tests pass
2. `grep -c "test(" test/kernel/bridge/window_bootstrap_test.dart` returns >= 6
3. `dart analyze test/kernel/bridge/window_bootstrap_test.dart` — no errors
4. Full suite: `flutter test` — no regressions
</verification>

<success_criteria>
- WindowBootstrap test file exists with 6+ passing test cases
- Tests verify: on-screen passthrough, off-screen centering, clearFullscreenIfSaved both paths
- dart analyze clean
- All existing 608+ tests still pass (no regression)
</success_criteria>

<output>
Create `.planning/phases/10-window-optimization/10-01-GAP-SUMMARY.md` when done
</output>
