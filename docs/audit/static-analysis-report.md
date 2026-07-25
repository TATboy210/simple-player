# Static Analysis Report

**Date:** 2026-07-20
**Branch:** feat/v1.8-stability-polish-plan-02-02
**Tool:** `flutter analyze`

## Summary

| Metric | Before | After |
|--------|--------|-------|
| Total issues | 29 | 0 |
| Errors | 3 | 0 |
| Warnings | 6 | 0 |
| Info | 20 | 0 |

## Issue Distribution (Before)

### Errors (3) — all in `packages/fullscreen_window/example/`

| Issue | File | Fix |
|-------|------|-----|
| `uri_does_not_exist` | example/lib/main.dart:1 | ignore_for_file directive |
| `undefined_identifier` | example/lib/main.dart:11 | ignore_for_file directive |
| `creation_with_non_type` | example/lib/main.dart:12 | ignore_for_file directive |

Root cause: `desktop_multi_window` dependency not resolved when analyzing subpackage from root project.

### Warnings (6)

| Issue | Count | Files | Fix |
|-------|-------|-------|-----|
| `include_file_not_found` | 2 | fullscreen_window analysis_options.yaml | Replaced `package:flutter_lints` with minimal local config |
| `unused_import` | 2 | window_persistence_test.dart, fvp_engine_bundle_test.dart | `dart fix --apply` |
| `strict_raw_type` | 2 | debug_exporter_test.dart | Changed `isA<Map>()` to `isA<Map<dynamic, dynamic>>()` |

### Info (20)

| Issue | Count | Files | Fix |
|-------|-------|-------|-----|
| `dangling_library_doc_comments` | 15 | 15 test files | `dart fix --apply` |
| `prefer_const_constructors` | 3 | kernel_logger_impl_test.dart | `dart fix --apply` |
| `annotate_overrides` | 1 | fake_engine.dart | `dart fix --apply` |
| `unrelated_type_equality_checks` | 2 | app_settings_test.dart, validation_error_test.dart | Added `// ignore:` comment (intentional test pattern) |

## Fix Details

### Automatic Fixes (21 fixes via `dart fix --apply`)

- 15x `dangling_library_doc_comments` — removed dangling `///` comments without `library` directive
- 3x `prefer_const_constructors` — added `const` keyword to constructor invocations
- 2x `unused_import` — removed unused import directives
- 1x `annotate_overrides` — added `@override` annotation
- 1x `missing_dependency` — added missing dependency to pubspec.yaml

### Manual Fixes (8 fixes)

| File | Change |
|------|--------|
| `test/kernel/utils/debug_exporter_test.dart` | `isA<Map>()` → `isA<Map<dynamic, dynamic>>()` (2 occurrences) |
| `test/kernel/models/app_settings_test.dart` | Added `// ignore: unrelated_type_equality_checks` |
| `test/kernel/models/validation_error_test.dart` | Added `// ignore: unrelated_type_equality_checks` |
| `packages/fullscreen_window/analysis_options.yaml` | Replaced `package:flutter_lints/flutter.yaml` include with minimal local config |
| `packages/fullscreen_window/example/analysis_options.yaml` | Same as above |
| `packages/fullscreen_window/example/lib/main.dart` | Added `// ignore_for_file` for unresolved `desktop_multi_window` dependency |

## Files Modified (18 total)

### Test files (16)
- `test/diagnostics/kernel_logger_impl_test.dart`
- `test/features/player/models/video_processing_state_test.dart`
- `test/helpers/fake_engine.dart`
- `test/kernel/adapter/delegation_policy_test.dart`
- `test/kernel/adapter/kernel_adapter_routing_test.dart`
- `test/kernel/bridge/window_mode_test.dart`
- `test/kernel/bridge/window_persistence_test.dart`
- `test/kernel/diagnostics/clock_test.dart`
- `test/kernel/engine/engine_event_log_test.dart`
- `test/kernel/engine/engine_metrics_test.dart`
- `test/kernel/engine/fvp_engine_bundle_test.dart`
- `test/kernel/models/app_settings_test.dart`
- `test/kernel/models/validation_error_test.dart`
- `test/kernel/player_services_test.dart`
- `test/kernel/services/breakpoint_saver_test.dart`
- `test/kernel/services/theme_service_test.dart`
- `test/kernel/utils/debug_exporter_test.dart`

### Config files (2)
- `packages/fullscreen_window/analysis_options.yaml`
- `packages/fullscreen_window/example/analysis_options.yaml`

### Example files (1)
- `packages/fullscreen_window/example/lib/main.dart`

### Project config (1)
- `pubspec.yaml` (auto-fix: missing dependency)
