---
phase: 16-token-foundation-independent-fixes
plan: 01
status: complete
completed: "2026-07-02"
---

# Summary: Phase 16 Plan 01 — Token Foundation & Independent Fixes

## What Was Built

1. **6 idle tokens** in `tokens.dart`: `controlBarBgIdle`, `controlBarBorderIdle`, `glassBorderIdle`, `controlBarTextPrimaryIdle`, `controlBarTextSecondaryIdle`, `controlBarIconIdle` — alpha 40-50% of existing tokens
2. **textSecondary WCAG fix**: alpha 0x73→0x80, contrast 4.3:1→5.3:1
3. **EdgeGlow glowIntensity**: optional `double?` parameter (default null), scales BoxShadow alpha in gradient variant and pulse amplitude in pulse variant
4. **18 tests passing**: 9 contrast tests + 9 EdgeGlow tests

## Files Modified

| File | Change |
|------|--------|
| `lib/ui/theme/tokens.dart` | +6 idle tokens, textSecondary alpha fix |
| `lib/ui/shared/edge_glow.dart` | +glowIntensity parameter, alpha scaling in gradient/pulse |
| `test/unit/theme/contrast_test.dart` | NEW — WCAG contrast + idle ratio validation |
| `test/widget/shared/edge_glow_test.dart` | NEW — glowIntensity parameter tests |

## Key Decisions

- Idle tokens use 40-50% alpha ratio (per D-02)
- glowIntensity null = preserve existing behavior (backward compatible)
- Idle secondary text contrast relaxed to 2.5:1 (23% alpha is by design)
- sRGB calculation uses `.red/.green/.blue` int getters (not linear-space `.r/.g/.b`)

## Self-Check: PASSED

- [x] 6 idle tokens exist in tokens.dart
- [x] textSecondary alpha = 0x80 (contrast >= 4.5:1)
- [x] EdgeGlow accepts glowIntensity (null/0.0/0.5/1.0)
- [x] All 18 tests pass
- [x] flutter analyze: no issues
