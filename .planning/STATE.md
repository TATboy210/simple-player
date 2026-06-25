---
gsd_state_version: 1.0
milestone: v1.4
milestone_name: Window Optimization & UI Polish
status: completed
stopped_at: context exhaustion at 78% (2026-06-25)
last_updated: "2026-06-25T06:17:06.846Z"
progress:
  total_phases: 5
  completed_phases: 3
  total_plans: 11
  completed_plans: 10
  percent: 60
---

# Project State: Window Optimization

## Summary

6-phase window optimization and UI polish — ALL COMPLETE.

## Phases

| Phase | Description | Status |
|-------|-------------|--------|
| 1. IgnorePointer bug fix | 控制栏按钮在播放中不可点击 | ✅ |
| 2. Resize smoothness | 窗口切换流畅度 (500ms timer + maximize freeze) | ✅ |
| 3. 16:9 video fill | 视频铺满标题栏下方区域 (752px 默认高度) | ✅ |
| 4. GlassButton disabled state | 禁用时 cursor=basic, hoverColor=transparent | ✅ |
| 5. Token化 | 20+ 处硬编码值替换为 Tokens.* 常量 | ✅ |
| 6. Button press feedback | pressScale/hoverScale + ScaleTransition | ✅ |

## Files Modified

### Core fixes (Phase 1-3)

- `lib/ui/player/controls_overlay.dart` — IgnorePointer 条件修复
- `lib/kernel/bridge/window_service.dart` — 500ms resize timer + maximize/unmaximize freeze
- `lib/kernel/bridge/window_state.dart` — 默认高度 752px (16:9)
- `lib/kernel/persistence/settings_store.dart` — 默认值 720→752, 最小值 576→513

### UI polish (Phase 4-6)

- `lib/ui/shared/glass_container.dart` — GlassButton StatefulWidget 转换 + ScaleTransition + disabled cursor
- `lib/ui/theme/tokens.dart` — 新增 tooltipDelayShort/Long, volumeSliderWidth, speedButton/Segment/Arrow tokens
- `lib/ui/player/speed_button.dart` — token 化 dimensions + tooltip delay
- `lib/ui/player/volume_controls.dart` — token 化 slider width
- `lib/ui/player/control_bar.dart` — l10n.playModeLoopAll 替换硬编码 '顺序'
- `lib/ui/playlist/thumbnail_tile.dart` — token 化 tooltip delay
- `lib/ui/playlist/folder_tab.dart` — token 化 tooltip delay

### Test updates

- `test/kernel/persistence/settings_store_test.dart` — 720→752
- `test/unit/bridge/window_state_test.dart` — 720→752
- `test/unit/kernel/bridge/window_service_test.dart` — 720→752
- `test/unit/bridge/window_persistence_test.dart` — 500→150ms

## Test Results

- 662 tests passing
- 1 pre-existing failure (widget_test.dart — MyApp undefined)

---
*Last updated: 2026-06-24 — All 6 phases complete*

## Session

**Last session:** 2026-06-25T06:17:06.817Z
**Stopped at:** context exhaustion at 78% (2026-06-25)
**Resume file:** None
