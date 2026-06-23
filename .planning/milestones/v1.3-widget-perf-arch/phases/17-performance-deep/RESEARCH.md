# Research: Phase 17 — Performance Deep (Ticker + VLB)

**Date:** 2026-06-22
**Status:** Complete

## PERF-08: Ticker Lifecycle — AuroraBackground

### Current State: ALREADY IMPLEMENTED

AuroraBackground has a complete two-factor pause system:

**Factor 1 — App lifecycle:**
```dart
void didChangeAppLifecycleState(AppLifecycleState state) {
  _isRunning = state == AppLifecycleState.resumed;
  _syncTicker();
}
```

**Factor 2 — Engine state:**
```dart
void _syncTicker() {
  final engineIdle = widget.engineState?.value == MediaState.idle || widget.engineState == null;
  final shouldRun = _isRunning && engineIdle;
  // start/stop ticker
}
```

**Ticker state matrix:**

| Condition | Ticker |
|-----------|--------|
| Foreground + engine idle | Running |
| Foreground + engine playing/paused/buffering | Stopped |
| Background (any engine) | Stopped |
| No engineState provided | Runs in foreground |

**Conclusion:** PERF-08 is functionally complete. Gap: no unit tests verifying pause/resume behavior.

### Action Plan

1. Write unit tests for `_syncTicker` logic (isRunning × engineIdle matrix)
2. Verify dispose cleanup (no ticker leak)
3. Document the existing behavior in summary

---

## PERF-09: VLB Audit

### Current State: AUDIT ALREADY DONE

`controls_overlay.dart` lines 13-30 contains an explicit audit comment:
> "结论：所有实例均已优化，无需修改。"

**VLB inventory:** 22 instances across 17 files.

**Nesting analysis:**
- Deepest nesting: 4 levels (player_screen.dart: textureId → playlistVisible → state → autoHide)
- Each VLB guards independent concerns with different change frequencies
- `ValueListenableBuilder2` used for 2-notifier composition (volume, error)
- `MergedListenable` used for 3+ notifier merging (time display)

**No merge candidates** — each VLB wraps a distinct subtree with independent lifecycle.

**Conclusion:** PERF-09 audit is complete. The existing controls_overlay.dart comment serves as documentation.

### Action Plan

1. Verify the audit comment is accurate by spot-checking 3 VLB sites
2. Confirm child: parameter usage in controls_overlay.dart and settings_panel.dart
3. Document findings in summary

---

## PERF-10: OverlayEntry Optimization

### Current State: ZERO OVERLAYENTRY INSTANCES

The project uses zero manual `OverlayEntry` insertion. All popups use:
- `showMenu<String>()` — context menus (thumbnail_tile, folder_tab)
- `showDialog()` — media info, shortcuts help, settings panel

Both APIs manage overlay entries internally. No manual `Overlay.of(context).insert()` exists.

**Popup const quality:**
- `thumbnail_tile.dart` context menu: NOT const (localized strings) — correct
- `speed_button.dart` arrows: recreated in builder but StatelessWidget reconciliation — acceptable
- `controls_overlay.dart` VLB: correctly uses `child:` caching

**setState in popup code:** None found. All popup interactions use `.then()` callbacks.

**Conclusion:** PERF-10 is N/A — no OverlayEntry optimization needed.

### Action Plan

1. Document that no OverlayEntry optimization is needed
2. Verify no new OverlayEntry has been added since audit

---

## Summary

| Requirement | Status | Action |
|-------------|--------|--------|
| PERF-08 | ✅ Implemented | Add unit tests for pause/resume |
| PERF-09 | ✅ Audit done | Verify + document |
| PERF-10 | ✅ N/A | Document as not applicable |

**Phase 17 scope:** Verification, testing, and documentation. No new feature implementation.

---
*Research completed: 2026-06-22*
