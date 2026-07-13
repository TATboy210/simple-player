---
phase: 04-settings-import-export
plan: 02
subsystem: ui/dialogs
tags: [settings, import, export, file_picker, l10n, glass-ui]
dependency_graph:
  requires: [export_data, import_result, settings_store, l10n]
  provides: [import_export_ui, import_confirm_dialog, osd_feedback]
  affects: [settings_panel]
tech_stack:
  added: []
  patterns: [file_picker_integration, glass_dialog, sealed_class_switch, osd_service]
key_files:
  created: []
  modified:
    - lib/l10n/app_en.arb
    - lib/l10n/app_zh.arb
    - lib/l10n/app_localizations.dart
    - lib/l10n/app_localizations_en.dart
    - lib/l10n/app_localizations_zh.dart
    - lib/ui/dialogs/settings_panel.dart
decisions:
  - "FilePicker.saveFile returns String? path — write File(path).writeAsString(json) directly"
  - "FilePicker v11 uses static methods (FilePicker.pickFiles/saveFile) not .platform accessor"
  - "OSD feedback via OsdService.I.show() — global singleton, no ScaffoldMessenger dependency"
  - "Import error dialog shows detail from ImportFailure.error (JSON parse error or missing settings key)"
  - "importConfirmTitle uses l10n.importConfirmTitle not l10n.importError('') — fixed misleading title"
  - "importParseError and importFileReadError l10n keys added for specific error scenarios per D-12"
metrics:
  duration_seconds: 0
  completed_tasks: 1
  total_tasks: 1
  files_created: 0
  files_modified: 6
status: complete
---

# Phase 4 Plan 02: Settings Import/Export UI — Summary

Import/Export buttons in settings panel bottom bar, file_picker integration, glass-styled confirmation dialog, OSD feedback.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add l10n keys, Import/Export buttons, import/export handlers, confirmation dialog | d695615 | app_en.arb, app_zh.arb, 3 generated l10n files, settings_panel.dart |

## What Was Built

### l10n Keys (app_en.arb, app_zh.arb)
- 11 new keys: exportSettings, importSettings, importConfirmTitle, importConfirmMessage, importConfirmCategories, importSuccess, importError (with `{error}` placeholder), exportError, exportSuccess, importParseError (with `{error}`), importFileReadError (with `{error}`)
- Chinese translations for all keys
- `flutter gen-l10n` regenerated successfully

### Import/Export Buttons in Bottom Bar
- Layout: `[Reset] ... [Spacer] [Import] [Export] | [OK] [Cancel] [Apply]`
- Vertical divider (1px, Tokens.borderHighlight) separates Import/Export from OK/Cancel/Apply
- Both use `_BottomButton` (same style as existing action buttons)
- No keyboard shortcuts per D-02

### Export Handler (`_exportSettings`)
- `FilePicker.saveFile` with `allowedExtensions: ['json']` and default filename `settings_YYYY-MM-DD.json`
- Calls `SettingsStore.exportSettings()` then `File.writeAsString()`
- Success: OSD hint `l10n.exportSuccess`
- Failure: `on FileSystemException` and `on FormatException` — generic error OSD (D-13), detailed `debugPrint`

### Import Handler (`_importSettings`)
- `FilePicker.pickFiles` with `allowedExtensions: ['json']`
- Reads file via `File.readAsString()`, passes to `SettingsStore.importSettings()`
- Pattern-matches on sealed class: `ImportFailure` shows error dialog (D-12), `ImportSuccess` shows confirmation dialog
- File read errors caught separately with `on FileSystemException`

### Import Confirmation Dialog (`_showImportConfirmDialog`)
- Glass-styled: `BackdropFilter` + `GlassTier.normal.blurFilter` + `Tokens.bgGlass` background + `Tokens.borderHighlight` border
- Title: `l10n.importConfirmTitle`
- Content: `l10n.importConfirmMessage` + `l10n.importConfirmCategories` (category summary, not individual values — D-10)
- Cancel: plain `TextButton` per D-11
- Confirm: `TextButton` with `backgroundColor: Tokens.accent, foregroundColor: Colors.white` per D-11

### Import Apply (`_onImportConfirmed`)
- `SettingsStore.applyImportedSettings(result)` — persists all settings (D-14)
- `LocaleService.I.setLocale(result.locale)` — immediate UI update
- `ThemeService.I.setTheme(result.themeIndex)` — immediate UI update
- `setState` updates `_pendingLocale` and `_pendingThemeIndex` — panel reflects new values
- Panel stays open per D-15 (no `Navigator.pop`)
- OSD hint `l10n.importSuccess` on success

### Import Error Dialog (`_showImportErrorDialog`)
- Glass-styled (same pattern as confirmation dialog)
- Shows detailed error from `ImportFailure.error` (D-12)
- Single OK button to dismiss

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] FilePicker v11 API uses static methods**
- **Found during:** Task 1 implementation
- **Issue:** Plan specified `FilePicker.platform.saveFile()` and `FilePicker.platform.pickFiles()` but file_picker v11 uses static methods: `FilePicker.saveFile()` and `FilePicker.pickFiles()`
- **Fix:** Changed to static method calls matching codebase pattern in `player_feature.dart`
- **Files modified:** `lib/ui/dialogs/settings_panel.dart`
- **Commit:** d695615

**2. [Rule 2 - Missing functionality] Added specific error l10n keys**
- **Found during:** Task 1 implementation
- **Issue:** Plan specified `importError` for all import errors, but D-12 requires "detailed error messages" for different failure modes. A single key with `{error}` placeholder is insufficient for distinguishing JSON parse errors from file read errors.
- **Fix:** Added `importParseError` and `importFileReadError` l10n keys with `{error}` placeholders for specific error scenarios
- **Files modified:** `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`
- **Commit:** d695615

**3. [Rule 1 - Bug] Fixed importConfirmTitle usage in error dialog**
- **Found during:** Task 1 implementation
- **Issue:** Initial implementation used `l10n.importError('')` as error dialog title, which would show "Import failed: " — misleading for a dialog that just shows the error
- **Fix:** Changed to use `l10n.importConfirmTitle` as title for the error dialog, keeping the detailed error in the content area
- **Files modified:** `lib/ui/dialogs/settings_panel.dart`
- **Commit:** d695615

## Verification Evidence

- `flutter analyze lib/ui/dialogs/settings_panel.dart lib/l10n/app_en.arb lib/l10n/app_zh.arb` — no issues
- `flutter test test/kernel/persistence/settings_import_export_test.dart` — 13/13 passed
- `flutter test test/kernel/persistence/settings_store_test.dart` — 57/57 passed (no regressions)
- `flutter gen-l10n` — regenerated without errors

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Static FilePicker methods | v11 API uses static methods, matches codebase pattern |
| OSD via OsdService.I.show() | Global singleton, no ScaffoldMessenger dependency needed |
| importParseError/importFileReadError l10n keys | D-12 requires detailed error messages for different failure modes |
| importConfirmTitle for error dialog title | Clearer than empty importError placeholder |

## Known Stubs

None — all data flows are wired. Import/export handlers call real SettingsStore methods, file_picker opens real dialogs.

## Self-Check: PASSED

- [x] `lib/l10n/app_en.arb` contains exportSettings, importSettings, importConfirmTitle, importConfirmMessage, importConfirmCategories, importSuccess, importError, exportError, exportSuccess, importParseError, importFileReadError
- [x] `lib/l10n/app_zh.arb` contains Chinese translations for all keys
- [x] `lib/ui/dialogs/settings_panel.dart` imports `dart:io` and `package:file_picker/file_picker.dart`
- [x] `_buildBottomBar` includes Import and Export buttons with vertical divider
- [x] `_exportSettings` calls `FilePicker.saveFile` with `allowedExtensions: ['json']` and generates filename `settings_YYYY-MM-DD.json`
- [x] `_importSettings` calls `FilePicker.pickFiles` with `allowedExtensions: ['json']`
- [x] `_importSettings` pattern-matches on sealed class (`switch (importResult) { ImportFailure(...) => ..., ImportSuccess() => ... }`)
- [x] `_showImportConfirmDialog` uses `BackdropFilter` with `GlassTier.normal.blurFilter`, `Tokens.bgGlass` background
- [x] Confirm button uses `TextButton.styleFrom(backgroundColor: Tokens.accent, foregroundColor: Colors.white)`
- [x] `_onImportConfirmed` calls `SettingsStore.applyImportedSettings(result)` and `LocaleService.I.setLocale`/`ThemeService.I.setTheme`
- [x] `_onImportConfirmed` does NOT call `Navigator.pop` — panel stays open
- [x] OSD hints shown on success (`importSuccess`/`exportSuccess`)
- [x] Error dialogs shown on failure with detailed messages
- [x] Commit d695615 exists in git log

## Self-Check Result: PASSED

- [x] Commit d695615 exists in git log
- [x] lib/l10n/app_en.arb contains 22 import/export related entries (keys + @metadata)
- [x] lib/l10n/app_zh.arb contains 11 import/export Chinese translations
- [x] lib/ui/dialogs/settings_panel.dart contains all 5 handler methods: _exportSettings, _importSettings, _showImportErrorDialog, _showImportConfirmDialog, _onImportConfirmed
- [x] Import/Export buttons wired in _buildBottomBar at lines 671 and 673
