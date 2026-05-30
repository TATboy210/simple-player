---
phase: 10-window-optimization
plan: 02-GAP
type: execute
wave: 1
depends_on: []
gap_closure: true
files_modified:
  - lib/kernel/bridge/window_service.dart
autonomous: true
requirements:
  - WIN-04
must_haves:
  truths:
    - "WindowService saves geometry immediately on window close event (not just via 500ms debounce)"
    - "onWindowClose override captures final position even if resize debounce timer hasn't fired"
    - "Immediate save skips if WindowService is disposed"
    - "Immediate save works even when window is fullscreen or maximized"
    - "Existing 500ms debounce path remains unchanged"
  artifacts:
    - path: "lib/kernel/bridge/window_service.dart"
      provides: "onWindowClose override + _saveGeometryImmediate method"
      contains: "onWindowClose"
  key_links:
    - from: "lib/kernel/bridge/window_service.dart"
      to: "lib/kernel/persistence/settings_store.dart"
      via: "SettingsStore.saveWindowGeometry in _saveGeometryImmediate"
      pattern: "SettingsStore\\.saveWindowGeometry"
    - from: "lib/kernel/bridge/window_service.dart"
      to: "package:window_manager"
      via: "WindowListener.onWindowClose callback"
      pattern: "onWindowClose"
---

<objective>
Re-implement onWindowClose + _saveGeometryImmediate in window_service.dart. The original 10-02 worktree was cleaned up before merge, losing this code. Currently geometry is only saved via 500ms debounce on resize — if the user closes the window before the debounce fires, the final position is lost.

Purpose: Ensures geometry persistence reliability (WIN-04 sub-item 4). The immediate save path on close complements the debounce path.

Output: Modified window_service.dart with onWindowClose + _saveGeometryImmediate
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@lib/kernel/bridge/window_service.dart
@lib/kernel/persistence/settings_store.dart
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add onWindowClose override and _saveGeometryImmediate to WindowService</name>
  <files>lib/kernel/bridge/window_service.dart</files>
  <action>
Add two members to the WindowService class:

1. `onWindowClose()` override — Place it after the existing `onWindowResize()` callback (around line 118). It should call `_saveGeometryImmediate()` and then `windowManager.destroy()`. The `windowManager.destroy()` call ensures the window_manager package cleans up its internal state after we've saved.

2. `_saveGeometryImmediate()` private method — Place it after `_scheduleGeometrySave()` (around line 139). Behavior:
   - Guard: `if (_disposed) return;`
   - Cancel the debounce timer: `_resizeDebounce?.cancel();` (prevents duplicate save)
   - Try block: get position via `await windowManager.getPosition()`, get size via `windowSize.value`
   - Call `await SettingsStore.saveWindowGeometry(width: size.width, height: size.height, x: pos.dx, y: pos.dy, isMaximized: isMaximized.value);`
   - Note: unlike `_scheduleGeometrySave`, this does NOT skip when fullscreen or maximized — the close handler must save the current state regardless
   - Catch block: `debugPrint('WindowService: immediate geometry save failed: $e');`

Key difference from _scheduleGeometrySave:
- No fullscreen/maximized skip (close must persist the actual state)
- No debounce (immediate execution)
- Cancels pending debounce to avoid race
- Reports `isMaximized.value` from the actual notifier (not hardcoded false)
  </action>
  <verify>
    <automated>cd D:\simple_player_flutter && dart analyze lib/kernel/bridge/window_service.dart</automated>
  </verify>
  <done>
    - onWindowClose() override exists in WindowService
    - _saveGeometryImmediate() method exists with _disposed guard
    - _saveGeometryImmediate cancels debounce timer before saving
    - _saveGeometryImmediate does NOT skip fullscreen/maximized (unlike _scheduleGeometrySave)
    - SettingsStore.saveWindowGeometry called with isMaximized: isMaximized.value
    - dart analyze passes clean
  </done>
</task>

</tasks>

<verification>
1. `grep -v '^\s*//' lib/kernel/bridge/window_service.dart | grep -c "onWindowClose"` returns 1
2. `grep -v '^\s*//' lib/kernel/bridge/window_service.dart | grep -c "_saveGeometryImmediate"` returns >= 1
3. `grep -v '^\s*//' lib/kernel/bridge/window_service.dart | grep "isMaximized\.value"` includes the _saveGeometryImmediate call
4. `dart analyze lib/kernel/bridge/window_service.dart` — no errors
5. Existing tests still pass: `flutter test`
</verification>

<success_criteria>
- WindowService has onWindowClose override that calls _saveGeometryImmediate + windowManager.destroy
- _saveGeometryImmediate saves geometry immediately without debounce, does not skip fullscreen/maximized
- _saveGeometryImmediate reports isMaximized.value from notifier
- dart analyze clean
- All existing tests pass (no regression)
</success_criteria>

<output>
Create `.planning/phases/10-window-optimization/10-02-GAP-SUMMARY.md` when done
</output>
