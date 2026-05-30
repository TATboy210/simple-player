# Phase 10 Verification: Window Geometry Persistence

**Date:** 2026-05-30
**Branch:** fix/window-startup
**Requirement:** WIN-04

## Phase Goal

Window geometry persistence — restore on startup, save on close, fix double WindowService.

## Plan Summary

| Plan | Status | Description |
|------|--------|-------------|
| 10-01 | PARTIAL | WindowBootstrap class (created, but tests missing) |
| 10-02 | **GAP** | onWindowClose immediate save (NOT implemented — lost with worktree) |
| 10-03 | PASS | WindowBootstrap wiring + singleton injection |

## Must-Have Verification

### 10-01: WindowBootstrap

| Must-Have | Status | Evidence |
|-----------|--------|----------|
| `WindowBootstrap.restoreOrCenter` sets position/size when saved geometry exists on visible display | PASS | `lib/kernel/bridge/window_bootstrap.dart:35` — static method exists |
| `WindowBootstrap.restoreOrCenter` centers window when no saved position (null x/y) | PASS | Implementation uses PlatformDispatcher for display bounds |
| `WindowBootstrap.restoreOrCenter` centers window when saved position is off-screen | PASS | `_isOnVisibleDisplay` with 100px overlap check |
| `WindowBootstrap.clearFullscreenIfSaved` clears isFullscreen flag | PASS | `lib/kernel/bridge/window_bootstrap.dart:24` — calls `SettingsStore.saveIsFullscreen(false)` |
| WindowBootstrap fails open when screen_retriever throws | PASS | Try-catch falls back to center |
| 6+ test cases pass | **FAIL** | `test/kernel/bridge/window_bootstrap_test.dart` does NOT exist |
| FakeScreenRetriever test helper exists | **FAIL** | `test/helpers/fake_screen_retriever.dart` does NOT exist |

### 10-02: onWindowClose Immediate Save

| Must-Have | Status | Evidence |
|-----------|--------|----------|
| WindowService saves geometry immediately on window close event | **FAIL** | `onWindowClose` NOT found in `window_service.dart` |
| onWindowClose override captures final position even if debounce hasn't fired | **FAIL** | `_saveGeometryImmediate` NOT found in `window_service.dart` |
| Immediate save skips if WindowService is disposed | **FAIL** | Method does not exist |
| Existing 500ms debounce path unchanged | PASS | `_scheduleGeometrySave` at line 121 with 500ms Timer |

**Root Cause:** 10-02 was executed in a worktree that was cleaned up before merge. The changes were lost.

**Current State:** Only the 500ms debounce path (`_scheduleGeometrySave`) exists. If the user closes the window before the debounce timer fires, the final window position is NOT saved.

### 10-03: Singleton Injection + Startup Wiring

| Must-Have | Status | Evidence |
|-----------|--------|----------|
| Window reads saved geometry from SettingsStore before showing | PASS | `main.dart:34` — `final settings = await SettingsStore.load()` |
| Window restores maximized state on startup | PASS | `main.dart:42-44` — `if (settings.isMaximized) await windowManager.maximize()` |
| isFullscreen flag cleared on startup (D-02) | PASS | `main.dart:35` — `WindowBootstrap.clearFullscreenIfSaved(settings)` |
| WindowService created once in App (no double instantiation) | PASS | `app.dart:33` — `final WindowService _windowService = WindowService()..init()` |
| PlayerServices receives WindowService via constructor | PASS | `player_services.dart` — `PlayerServices({required this.windowService})` |
| WindowOptions no longer has hardcoded size or center | PASS | `main.dart:24-29` — only `backgroundColor`, `titleBarStyle`, `windowButtonVisibility`, `minimumSize` |
| ensureVisible() called after show() | PASS | Inside `WindowBootstrap.restoreOrCenter` |
| No `WindowService()` creation in features/ | PASS | Constructor injection chain: App -> DeferredPlayerFeature -> PlayerFeature -> PlayerServices |

## Key Link Verification

| From | To | Pattern | Status |
|------|----|---------|--------|
| `lib/main.dart` | `window_bootstrap.dart` | `WindowBootstrap.restoreOrCenter` | PASS (line 36) |
| `lib/main.dart` | `window_bootstrap.dart` | `WindowBootstrap.clearFullscreenIfSaved` | PASS (line 35) |
| `lib/app.dart` | `deferred_player_feature.dart` | `windowService: _windowService` | PASS (line 178) |
| `lib/features/player/player_services.dart` | `window_service.dart` | `required this.windowService` | PASS (constructor) |
| `window_service.dart` | `settings_store.dart` | `SettingsStore.saveWindowGeometry` in `onWindowClose` | **FAIL** (method missing) |

## WIN-04 Requirement Traceability

| Sub-Requirement | Status | Notes |
|-----------------|--------|-------|
| 窗口启动和恢复流程优化 | PASS | WindowBootstrap + main.dart wiring complete |
| 全屏/最大化/恢复动画平滑度 | PARTIAL | Maximize restore works; no immediate save on close |
| 多显示器场景边界检查 | PASS | `_isOnVisibleDisplay` with 100px overlap + `ensureVisible()` fallback |
| 窗口几何状态持久化可靠性 | **GAP** | Only debounce path exists; onWindowClose immediate save missing |

## Threat Model Status

| Threat ID | Description | Status |
|-----------|-------------|--------|
| T-10-01 | SettingsStore geometry tampering | PASS — RC-3 sanitization |
| T-10-02 | Off-screen window positioning | PASS — `_isOnVisibleDisplay` + `ensureVisible()` |
| T-10-03 | Fullscreen crash lock | PASS — `clearFullscreenIfSaved` on startup |
| T-10-04 | Geometry values on save | PARTIAL — debounce saves; no close-handler save |
| T-10-05 | Double WindowService race | PASS — singleton injection eliminates duplicate |

## Gaps

### GAP-1: onWindowClose immediate save (HIGH)

**Impact:** If user closes window within 500ms of last resize/move, final geometry is lost.
**Source:** 10-02 worktree was cleaned up before merge.
**Fix:** Re-implement `onWindowClose` override + `_saveGeometryImmediate` in `window_service.dart`.
**Effort:** ~15min

### GAP-2: WindowBootstrap tests missing (MEDIUM)

**Impact:** No automated verification of restore/center/fail-open behavior.
**Source:** 10-01 worktree was cleaned up before merge; tests were not recreated by 10-03.
**Fix:** Create `test/kernel/bridge/window_bootstrap_test.dart` and `test/helpers/fake_screen_retriever.dart`.
**Effort:** ~30min

## Verdict

**Phase 10: PARTIALLY COMPLETE**

- 10-03 (wiring + singleton) is fully implemented and verified
- 10-01 (WindowBootstrap class) is implemented but lacks tests
- 10-02 (onWindowClose immediate save) is NOT implemented — this is the critical gap

The phase goal "save on close" is not achieved. Only the debounce path exists.
