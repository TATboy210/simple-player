---
phase: 07-integration-golden-tests
plan: 02
status: complete
completed_at: "2026-05-30T10:30:00+08:00"
---

# 07-02 Summary: Golden Tests

## What Changed

### Golden Test Infrastructure
- `test/golden/golden_comparator.dart` — `TolerantGoldenComparator` extending `LocalFileComparator`
  - Per-channel pixel tolerance (default 5%)
  - Max mismatch rate (default 1% of pixels)
  - First-run auto-creates golden files
  - `enableTolerantGoldens()` helper for setUp
  - `wrapForGolden()` helper with consistent dark background (0xFF1A1A2E)

### Glass Widget Golden Tests (7 tests)
- `test/golden/glass_widgets_golden_test.dart`
  - GlassContainer: thin, normal, thick tiers (blurEnabled: false)
  - GlassButton: label mode, icon-only mode
  - GlassChip: selected, unselected states

### Control Layout Golden Tests (7 tests)
- `test/golden/control_layouts_golden_test.dart`
  - ControlBar: idle, playing, fullscreen states (enableBlur: false)
  - ProgressBar: empty (no duration), half progress
  - VolumeControls: full volume, muted

### Golden Baselines (15 PNGs)
- `test/golden/goldens/` — 15 baseline images committed

## Key Decisions

- Extended `LocalFileComparator` (not `GoldenFileComparator`) — provides `getGoldenBytes()`, `basedir`, `update()` delegation
- Used `blurEnabled: false` / `enableBlur: false` — BackdropFilter cannot render in Flutter test environment
- Per-channel tolerance (not just diffPercent) — catches specific color channel drift from GPU differences
- Dark background `0xFF1A1A2E` matches player theme for consistent golden images

## Verification

- 596 tests passing (582 existing + 14 new golden)
- Golden regression check passes (re-run without --update-goldens)
- `dart analyze` clean on all new files (3 info-level const suggestions only)
