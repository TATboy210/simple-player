---
status: pass
phase: 20-control-bar-subtraction
score: 4/4
verified: 2026-07-04
---

# Verification — Phase 20: Technical Debt Cleanup

## Success Criteria

| # | Criterion | Status |
|---|-----------|--------|
| SC1 | `flutter analyze` 0 errors, 0 warnings | ✅ PASS |
| SC2 | `flutter test` 905+ passing, 0 failures | ✅ PASS (905 passed, 0 failed) |
| SC3 | Color API migrated to `.r/.g/.b/.a` | ✅ PASS |
| SC4 | All `const` constructors complete | ✅ PASS |

## Requirement Traceability

| REQ | Status | Evidence |
|-----|--------|----------|
| TECH-01 | ✅ SATISFIED | `PlayerServices.create()` at `player_services.dart:19` |
| TECH-02 | ✅ SATISFIED | `flutter analyze` 0 `deprecated_member_use` |
| TECH-03 | ✅ SATISFIED | 905 tests passing, 0 failures (gap closure 20-02) |
| TECH-04 | ✅ SATISFIED | 0 info issues: @override, imports, const all done |

## Gaps

### Gap 1: external_subtitle_test race condition (6 tests) — ✅ FIXED (20-02)

**Root cause**: `SubtitleService.detectAndLoad()` is called via `unawaited()` in `playback_navigator.dart:54` (fire-and-forget). Tests assert `setExternalSubtitleCallCount == 1` immediately after `playIndex(0)` returns, but async detection hasn't completed yet. Additionally, `tearDown` deletes temp directory before detection finishes → `PathNotFoundException`.

**Applied fix**:
1. Added `await Future<void>.delayed(200ms)` in 6 tests to wait for async completion
2. Fixed production bug: `detectAndLoad()` missing `return` after first match (inconsistent with `detectAndLoadSync()`)

## Verified

- ✅ 0 errors, 0 warnings, 0 info (`flutter analyze`)
- ✅ Color API: `.r/.g/.b/.a` in contrast_test + tokens_test
- ✅ @override: 31 methods in mock_engine
- ✅ overridden_fields: ignore_for_file in fvp_engine + fake_engine
- ✅ unnecessary_import: removed from fvp_engine + mock_engine
- ✅ const constructors: glass_container_test
- ✅ showDialog<void>: app.dart + player_screen.dart
