---
phase: 04-settings-import-export
plan: 01
subsystem: kernel/persistence
tags: [settings, import, export, json, serialization]
dependency_graph:
  requires: [settings_store, settings_validator, app_settings]
  provides: [export_data, import_result, export_settings, import_settings, apply_imported_settings]
  affects: [settings_panel_ui]
tech_stack:
  added: []
  patterns: [sealed_class, json_serialization, lenient_parsing]
key_files:
  created:
    - lib/kernel/models/export_data.dart
    - test/kernel/models/export_data_test.dart
    - test/kernel/persistence/settings_import_export_test.dart
  modified:
    - lib/kernel/persistence/settings_store.dart
decisions:
  - "playbackSpeed loaded/saved separately from main load()/saveAll() — export/import methods handle it explicitly"
  - "ImportResult as sealed class (not generic Result<T>) — matches OpenResult pattern from engine"
  - "Const ImportFailure for static error strings (lint prefer_const_constructors)"
metrics:
  duration_seconds: 533
  completed_tasks: 1
  total_tasks: 1
  files_created: 3
  files_modified: 1
status: complete
---

# Phase 4 Plan 01: Settings Import/Export Data Layer — Summary

ExportData model with metadata + full settings map serialization, plus SettingsStore export/import/apply methods with SettingsValidator integration.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create ExportData model and SettingsStore export/import methods | 1b036a8 | export_data.dart, settings_store.dart, 2 test files |

## What Was Built

### ExportData Model (`lib/kernel/models/export_data.dart`)
- `ExportData` class with 6 final fields: settingsVersion, exportedAt, appVersion, platform, settingsCount, settings
- `ExportData.fromSettings()` factory: serializes all 23 AppSettings fields + locale + themeIndex + shortcuts into a Map
- `ExportData.toMap()`: produces JSON-compatible Map with metadata envelope
- `appVersionConst = '1.0.0-rc.1'` — hardcoded to avoid package_info_plus dependency

### ImportResult Sealed Class (`lib/kernel/persistence/settings_store.dart`)
- `ImportResult` sealed base class with `ImportSuccess` and `ImportFailure` subtypes
- `ImportSuccess` carries: settings (AppSettings), locale (String), themeIndex (int), shortcuts (Map)
- `ImportFailure` carries: error (String) with human-readable description
- Follows `OpenResult` pattern from `lib/kernel/engine/open_result.dart`

### SettingsStore Methods
- `exportSettings()`: reads all settings via load()+loadLocale()+loadThemeIndex()+loadShortcuts()+loadPlaybackSpeed(), builds ExportData, returns jsonEncode string
- `importSettings(jsonString)`: parses JSON leniently (D-07), validates each field via SettingsValidator (D-08), returns ImportSuccess or ImportFailure
- `applyImportedSettings(ImportSuccess)`: persists all values via saveAll()+savePlaybackSpeed()+saveLocale()+saveThemeIndex()+saveShortcuts()

### Deviation: playbackSpeed Separate Loading
- `SettingsStore.load()` does not include playbackSpeed (it's loaded separately by `loadPlaybackSpeed()`)
- `exportSettings()` explicitly calls `loadPlaybackSpeed()` and merges via `settings.copyWith(playbackSpeed: playbackSpeed)`
- `applyImportedSettings()` explicitly calls `savePlaybackSpeed()` in addition to `saveAll()`
- This is a pre-existing architectural pattern, not a new deviation

## Tests (18 total, all passing)

### ExportData tests (5)
- toMap() returns correct structure with all metadata fields
- fromSettings() correctly maps all AppSettings fields + locale + themeIndex + shortcuts
- fromSettings() sets metadata correctly (version, appVersion, platform, exportedAt format)
- settingsCount matches number of keys in settings map
- fromSettings() with null windowX/windowY includes null in map

### Import/Export tests (13)
- exportSettings produces valid JSON with all metadata
- exportSettings includes all AppSettings fields plus locale/themeIndex/shortcuts
- exportSettings settingsCount matches actual settings map length
- importSettings with valid JSON returns ImportSuccess with correct values
- importSettings with invalid JSON returns ImportFailure
- importSettings with missing 'settings' key returns ImportFailure
- importSettings ignores unknown fields (forward compatibility)
- importSettings fills missing fields with AppSettings defaults
- importSettings validates fields through SettingsValidator (volume clamped, rotation sanitized)
- importSettings validates locale as non-empty string
- importSettings validates shortcuts as Map<String, String>
- importSettings handles null windowX/windowY gracefully
- applyImportedSettings persists all settings to SharedPreferences

## Verification Evidence

- `flutter test test/kernel/models/export_data_test.dart` — 5/5 passed
- `flutter test test/kernel/persistence/settings_import_export_test.dart` — 13/13 passed
- `flutter analyze lib/kernel/models/export_data.dart lib/kernel/persistence/settings_store.dart` — no issues
- `flutter test test/kernel/persistence/settings_store_test.dart` — 57/57 passed (no regressions)

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| playbackSpeed handled separately in export/import | load()/saveAll() don't include it — pre-existing pattern |
| ImportResult as sealed class | Matches OpenResult pattern, enables exhaustive switch |
| const ImportFailure for static errors | prefer_const_constructors lint compliance |
| Hardcoded appVersionConst | Avoids adding package_info_plus dependency |

## Known Stubs

None — all data flows are wired.

## Self-Check: PASSED

- [x] `lib/kernel/models/export_data.dart` exists
- [x] `lib/kernel/persistence/settings_store.dart` contains exportSettings, importSettings, applyImportedSettings
- [x] `test/kernel/models/export_data_test.dart` exists and passes
- [x] `test/kernel/persistence/settings_import_export_test.dart` exists and passes
- [x] Commit 1b036a8 exists in git log
