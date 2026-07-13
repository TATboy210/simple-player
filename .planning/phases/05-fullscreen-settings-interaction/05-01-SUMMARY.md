---
phase: 5
plan: 01
status: complete
commits:
  - "39628a9 feat(05-01): fullscreen-aware settings panel positioning"
  - "1c9d392 feat(05-01): wire WindowService into SettingsPanel from App"
files_modified:
  - lib/ui/dialogs/settings_panel.dart
  - lib/app.dart
decisions:
  - "PopScope + Focus wraps build() — ESC intercepted at dialog level, prevents Navigator.maybePop and stops propagation to outer KeyboardHandler (D-04, D-12)"
  - "AnimatedAlign replaces static Align — alignment switches between Alignment.center (fullscreen) and Alignment.topLeft (windowed) with 300ms easeOutCubic (D-01, D-03, D-05, D-08)"
  - "Padding switches: EdgeInsets.zero in fullscreen, EdgeInsets.only(left: 80, top: 48) in windowed (D-06)"
  - "_offset Transform.translate sits inside AnimatedAlign — drag offset is relative to aligned position"
  - "onPanStart/onPanUpdate set to null when isFullscreen — disables drag recognizer (D-06, D-11)"
  - "Drag indicator icon hidden in fullscreen via if (!isFullscreen) conditional (D-11)"
  - "_onModeChanged resets _offset.value = Offset.zero on mode change (D-09)"
  - "Colors.black54 barrier background unchanged (D-07)"
  - "WindowBridge passed as required constructor parameter to SettingsPanel (D-10)"
---

# Summary: 05-01 Fullscreen-Aware Settings Panel Positioning

## What Changed

**settings_panel.dart** (885 -> ~890 lines):
- Added `WindowBridge windowService` as required constructor parameter
- Added `_onModeChanged` listener: resets `_offset.value = Offset.zero` on fullscreen/windowed transitions
- Wrapped build in `PopScope(canPop: false)` + `Focus(autofocus: true, onKeyEvent: _handleEscape)` for ESC interception
- Replaced static `Align(alignment: Alignment.topLeft)` + `Transform.translate` with `ValueListenableBuilder<WindowMode>` + `AnimatedAlign` (center in fullscreen, topLeft in windowed, 300ms easeOutCubic)
- Padding switches between `EdgeInsets.zero` (fullscreen) and `EdgeInsets.only(left: 80, top: 48)` (windowed)
- Drag `GestureDetector` callbacks set to `null` when `isFullscreen` (disables drag)
- Drag indicator icon hidden in fullscreen mode
- `_handleEscape` calls `Navigator.pop` and returns `KeyEventResult.handled` to stop propagation

**app.dart** (1 line changed):
- Added `windowService: widget.windowService` to `SettingsPanel` constructor call in `_showSettingsPanel`

## Verification

- `flutter analyze lib/ui/dialogs/settings_panel.dart lib/app.dart` — no issues
- `flutter test` — 1105 passing, 9 pre-existing failures (unrelated loading issues)

## Decisions Made

| # | Decision | Rationale |
|---|----------|-----------|
| D-04 | PopScope + Focus at dialog level | Prevents ESC from reaching outer KeyboardHandler — dialog closes first, fullscreen exit preserved |
| D-09 | _onModeChanged resets offset | Drag offset is meaningless after alignment change; clean state on transition |
| D-10 | required WindowBridge parameter | Compile-time safety; no optional fallback needed since App always has it |
| D-11 | null callbacks for drag disable | Setting onPanStart/onPanUpdate to null fully disables the GestureDetector recognizer |
