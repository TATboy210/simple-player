---
phase: 35-widget-tree-baseline-behavior-recovery
plan: 02
status: complete
completed: 2026-08-11
requirements:
  - BASE-02
  - BASE-03
  - BASE-04
---

# Plan 35-02 Summary

## Completed work

- Added `test/widget/player/player_screen_window_bridge_replacement_test.dart`.
  - Uses the same `PlayerScreen` key while replacing `FakeWindowService`.
  - Verifies the injected video surface keeps its element identity.
  - Verifies title-bar pin, minimize, maximize/restore, and close callbacks route only to the replacement bridge.
  - Verifies old bridge notifier mutations no longer control the title-bar maximize icon, while the replacement bridge still does.
  - Verifies the `F` shortcut changes mode only through the replacement bridge.
- Extended `test/widget/shared/glass_button_test.dart` label-mode coverage.
  - Confirms Space before a rebuild invokes the first callback and Enter after a same-identity rebuild invokes only the replacement callback.
  - Confirms an enabled-to-disabled rebuild blocks label-button tap and keyboard activation.
  - Confirms an `onPressed: null` rebuild publishes disabled button semantics.
- No production files required modification. Existing dependency-replacement implementations in `PlayerScreen`, `CustomTitleBar`, and `GlassButton` passed the new regression tests.

## Validation

Passed:

```text
flutter test test/widget/player/player_screen_window_bridge_replacement_test.dart test/widget/player/player_screen_accessibility_resize_test.dart
flutter test test/widget/shared/glass_button_test.dart
flutter analyze
git diff --check
```

`glass_button_test.dart` passes with existing non-fatal Flutter tap hit-test warnings for disabled buttons. `git diff --check` reports only pre-existing CRLF conversion warnings for planning files; it reports no whitespace errors.

## Scope and working-tree notes

- No commit, reset, stash, checkout, or overwrite operation was performed.
- Existing user modifications were retained.
- The new bridge regression covers command callbacks, notifier isolation, and F-key routing. Title-bar drag remains implemented by the existing `GestureDetector`; automated pointer gesture dispatch was not added because this test surface nests competing gesture handlers, while the replacement-sensitive command closures are directly covered by the cached title-bar subtree.
