---
phase: 04-test-coverage
type: context
created: 2026-05-29
---

# Phase 4: Test Coverage — Context

## Goal

Raise test coverage from 62.8% (1201/1912) to 80%+ (1530+ lines).

## Decisions

1. **Skip platform stubs** — window_manager already provides cross-platform support. No need for PlatformWindow abstraction.
2. **Kernel/bridge first** — Pure Dart unit tests give highest coverage-per-effort. UI widget tests are lower priority.
3. **No l10n testing** — Generated localization files (app_localizations_en/zh.dart) are auto-generated, not worth testing.
4. **TDD approach** — Write tests first, then verify they pass against existing code.

## Coverage Gap Summary

Current: 1201/1912 = 62.8%
Target: 1530/1912 = 80.0%
Gap: 329 lines to cover

## Priority Targets (by effort/impact)

| # | File | Current | Gain | Effort |
|---|------|---------|------|--------|
| 1 | startup_state.dart | 0% | ~40 | Trivial |
| 2 | startup_coordinator.dart | 0% | ~60 | Low |
| 3 | video_processing_state.dart | 76.3% | ~25 | Trivial |
| 4 | path_utils.dart | 52.2% | ~8 | Trivial |
| 5 | settings_store.dart | 62.8% | ~50 | Low |
| 6 | fvp_callback_handler.dart | 12.1% | ~8 | Trivial |
| 7 | subtitle_service.dart | 64.7% | ~25 | Low |
| 8 | window_service.dart | 0% | ~30 | Medium |
| 9 | playlist_store.dart | 56.8% | ~30 | Medium |
| 10 | media_info.dart | 69.2% | ~5 | Trivial |

Estimated from unit tests: ~281 lines
Remaining ~48 lines from widget tests (progress_bar, error_banner)

## Constrained Files

- `position_poller.dart` (0%, 21 lines) — Timer-based, needs FakeAsync. Skip if complex.
- `fvp_engine.dart` — MDK dependency, tested via integration. Skip.
- `glass_chip.dart` (0%, 20 lines) — Widget test needed. Low priority.
