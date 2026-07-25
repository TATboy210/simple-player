# 21-01-SUMMARY: Contract Test Verification on Phase 20 FvpEngine

## Status: BLOCKED

## Pre-existing Compilation Fixes Applied

Before tests could compile, two pre-existing issues were fixed (not Phase 20 regressions):

### 1. `KernelLogger.I` undefined getter (24 files)

**Root cause:** Phase 17-02 migration (commit `204bedf`) changed 24 kernel files from `log.dart` to `kernel_logger.dart`, referencing `KernelLogger.I`. However, the `I` static getter only existed on `KernelLoggerImpl`, not the abstract `KernelLogger` class.

**Fix:** Added a forwarding static getter on `KernelLogger`:
```dart
static KernelLoggerImpl get I => KernelLoggerImpl.I;
```

**Files affected:** All 24 kernel files using `KernelLogger.I`.

### 2. Import ordering violations (2 files)

**Root cause:** `d3d11_configurator.dart` and `startup_coordinator.dart` had declarations (`final log = ...`) appearing before import/export directives.

**Fix:** Moved all directives before declarations in both files.

## Test Execution Result

```
flutter test test/engine/fvp_engine_contract_test.dart → exit 1
```

**All 7 contract test groups FAIL** with:
```
Invalid argument(s): Failed to load dynamic library 'mdk.dll': The specified module could not be found.
```

### Affected Contract Groups

| # | Contract Group | Status |
|---|---------------|--------|
| 1 | EngineStateView | BLOCKED — mdk.dll not found |
| 2 | PlaybackControl | BLOCKED — mdk.dll not found |
| 3 | TrackControl | BLOCKED — mdk.dll not found |
| 4 | SubtitleConfig | BLOCKED — mdk.dll not found |
| 5 | VideoEffectControl | BLOCKED — mdk.dll not found |
| 6 | RendererControl | BLOCKED — mdk.dll not found |
| 7 | VolumeControl | BLOCKED — mdk.dll not found |

### Root Cause

The `fvp` package uses FFI to load `mdk.dll` (native MDK/FFmpeg) at `Player()` construction time. In headless `flutter test` environment, the native library is not on the DLL search path. This is a known pre-existing environment limitation (documented in MEMORY.md as "mdk.dll Headless Test Failures").

The chain: `FvpEngine()` → `Player()` (fvp) → `Libmdk._load` → `DynamicLibrary.open('mdk.dll')` → **File not found**.

### Not a Phase 20 Regression

- Phase 20 changes (TransitionResult, OpenGenerationTracker, DelegationPolicy, PlayerServices bundle injection) are not involved in the failure
- The failure occurs at FFI library load time, before any engine logic executes
- The same failure would occur on any unmodified version of FvpEngine

## Conclusion

Contract test verification cannot proceed in this headless environment. The test requires a Windows desktop environment with `mdk.dll` on the PATH (typically available after `flutter build windows` or by placing the DLL in the project directory).

### Recommended Next Steps

1. Build the project once (`flutter build windows`) to place `mdk.dll` in the build output
2. Add the build output directory to PATH, or copy `mdk.dll` to the project root
3. Re-run: `flutter test test/engine/fvp_engine_contract_test.dart`

## Compilation Fixes Summary

| File | Issue | Fix |
|------|-------|-----|
| `lib/kernel/diagnostics/kernel_logger.dart` | `KernelLogger.I` undefined | Added static forwarding getter |
| `lib/kernel/engine/d3d11_configurator.dart` | Import after declaration | Reordered directives |
| `lib/kernel/startup/startup_coordinator.dart` | Export after declaration | Reordered directives |
