---
phase: 16
plan: 02
subsystem: ui/widget-layer
tags: [performance, tokens, repaint-boundary, vlb-flattening]
dependency_graph:
  requires: [16-01]
  provides: [widget-perf-tokens]
  affects: [control-bar, aurora-background, osd-overlay, transmitted-light, settings]
tech_stack:
  added: []
  patterns: [token-migration, theme-service-centralization]
key_files:
  created: []
  modified:
    - lib/ui/theme/tokens.dart
    - lib/ui/player/control_bar.dart
    - lib/ui/shared/aurora_background.dart
    - lib/ui/shared/osd_overlay.dart
    - lib/ui/shared/transmitted_light.dart
    - lib/ui/dialogs/settings_panel.dart
    - lib/ui/dialogs/settings/general_tab.dart
decisions:
  - "aurora_background.dart white gradient source (Color(0xFFFFFFFF)/Color(0x00FFFFFF)) left as-is — internal to预渲染 pipeline, gets color-filtered"
  - "settings_panel.dart and general_tab.dart theme accent colors centralized via ThemeService.accents"
metrics:
  duration: 5m
  completed: "2026-07-03T09:32:00Z"
  tasks_completed: 5
  tasks_total: 5
  files_modified: 7
status: complete
---

# Phase 16 Plan 02: Widget 层优化 Summary

**One-liner:** RepaintBoundary isolation, Opacity fix, VLB flattening, and hardcoded color migration to Tokens

## Tasks Completed

| Task | Name | Status | Notes |
|------|------|--------|-------|
| 1 | PlayerScreen RepaintBoundary 隔离 | Already done | Committed in 6d64cf6 |
| 2 | Progress Bar Opacity 修复 | Already done | Committed in 6d64cf6 |
| 3 | ValueListenableBuilder 扁平化 | Already done | Committed in 6d64cf6 |
| 4 | 硬编码颜色迁移 | Done | 7 new tokens, 7 files migrated |
| 5 | 测试验证 | Done | 880 tests pass, 9 pre-existing failures |

## Deviations from Plan

### Tasks 1-3 Already Complete

Tasks 1 (RepaintBoundary), 2 (Opacity fix), and 3 (VLB flattening) were already committed in 6d64cf6. The plan's estimated violation counts for Task 4 were higher than actual — most colors had already been migrated.

### Auto-fixed Issues

None — plan executed cleanly for Task 4.

### Scope Adjustment

The plan estimated 15+ violations in edge_glow.dart and 10 in control_bar.dart. Actual remaining violations were:
- control_bar.dart: 2 (transparent blue gradient edge)
- aurora_background.dart: 1 (noise overlay color)
- osd_overlay.dart: 1 (track color)
- transmitted_light.dart: 1 (glow purple default)
- settings_panel.dart: 1 (local theme accent copy)
- general_tab.dart: 3 (local theme accent copy)

edge_glow.dart had 0 remaining violations — all colors were already using Tokens.*.

## Key Decisions

1. **Aurora white gradient source left as-is:** `Color(0xFFFFFFFF)` / `Color(0x00FFFFFF)` in aurora_background.dart are internal to the预渲染 pipeline — they get color-filtered by `ColorFilter.mode(color, BlendMode.srcIn)`. Not design tokens.

2. **ThemeService.accents centralized:** settings_panel.dart and general_tab.dart now reference `ThemeService.accents` instead of maintaining local copies of the same color array.

3. **Removed _ThemeData class:** general_tab.dart's `_ThemeData` class was redundant — the color was the only unique field, and it's now pulled from `ThemeService.accents[i]`.

## New Tokens Added

| Token | Value | Purpose |
|-------|-------|---------|
| `Tokens.controlBarGradientEdge` | `Color(0x005082FF)` | Transparent blue for gradient edge highlight |
| `Tokens.noiseOverlay` | `Color(0x05FFFFFF)` | Aurora noise texture color (3% white) |
| `Tokens.osdTrackColor` | `Color(0x22FFFFFF)` | OSD mini progress bar track (13% white) |
| `Tokens.glowPurple` | `Color(0xFF7864DC)` | Transmitted light default glow purple |

## Test Results

- **880 tests pass** (no regressions from this plan)
- **9 pre-existing failures** (3 golden tests + 6 external subtitle tests — not caused by this plan)
- `flutter analyze`: No issues found

## Known Stubs

None.

## Threat Flags

None — all changes are pure UI token migration with no security surface.
