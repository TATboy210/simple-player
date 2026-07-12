# Domain Pitfalls: Settings Panel & Fullscreen Refactoring

**Domain:** Flutter desktop media player
**Researched:** 2026-07-12
**Scope:** Settings panel UI/UX refactor, SettingsStore data layer, fullscreen code decoupling

## Critical Pitfalls

Mistakes that cause rewrites or major regressions.

### Pitfall 1: Fullscreen State Dual-Source Truth

**What goes wrong:** `WindowService._isFullscreen` (ValueNotifier) and `SettingsStore.isFullscreen` (SharedPreferences) diverge. After refactoring, one updates but the other does not. User sees fullscreen indicator in UI but window is windowed, or vice versa.

**Why it happens:** WindowService owns `_isFullscreen` notifier for real-time UI, while SettingsStore persists `isFullscreen` for app restart recovery. During refactoring, developers split the save/load paths and forget to keep both in sync.

**Consequences:** On next app launch, window enters fullscreen when user left it windowed (or the reverse). User loses window position/size saved before fullscreen.

**Prevention:**
- WindowService is the single owner of fullscreen state. It reads `isFullscreen` from SettingsStore only at init for recovery.
- All fullscreen transitions go through `WindowService.enterFullscreen()` / `leaveFullscreen()`. Never call `SettingsStore.saveIsFullscreen()` directly from UI.
- SettingsStore.saveIsFullscreen() is called only inside WindowService's transition methods, in a `finally` block after the transition completes.

**Detection:** If you see `SettingsStore.saveIsFullscreen` called outside `window_service.dart`, the invariant is broken.

**Phase:** Architecture phase (Phase 1) — establish the single-owner pattern before any UI work.

---

### Pitfall 2: Deferred Apply Pattern Violation (Locale/Theme in Dialog)

**What goes wrong:** Refactored settings panel calls `LocaleService.I.setLocale()` or `ThemeService.I.setTheme()` directly when user changes selection. This triggers `MaterialApp` rebuild, which destroys the dialog's State — all `_offset`, `_selectedIndex`, pending values reset to initial.

**Why it happens:** Developer treats locale/theme like other settings (volume, speed) that apply immediately. But locale/theme modify the widget tree root, which is a fundamentally different operation.

**Consequences:** Dialog closes unexpectedly or resets to initial state mid-interaction. User loses their settings changes.

**Prevention:**
- Locale and theme changes must be deferred: store pending values in `_pendingLocale` / `_pendingThemeIndex` State fields.
- Apply only on OK/Apply button press, after `Navigator.pop()`.
- Cancel restores `_originalLocale` / `_originalThemeIndex` before `pop()`.
- GeneralTab receives current values as parameters, never reads from `Localizations.localeOf(context)` directly.

**Detection:** If a settings tab widget calls `LocaleService.I.setLocale()` or `ThemeService.I.setTheme()` in its `onChanged` callback (not deferred), it will break on MaterialApp rebuild.

**Phase:** UI refactoring phase — must be preserved during any settings panel restructure.

---

### Pitfall 3: Win32 FFI Resource Leak in Fullscreen Driver

**What goes wrong:** `WindowsFullscreenDriver._savedPlacement` is a `Pointer<WindowPlacement>` allocated via FFI. If `leaveFullscreen()` throws or is never called (e.g., app crashes, window closed during fullscreen), the pointer is never freed.

**Why it happens:** FFI memory management is manual. Dart's GC does not free `Pointer` objects allocated with `calloc`/`malloc`. The `dispose()` method must free in a `finally` block.

**Consequences:** Memory leak per fullscreen enter/leave cycle. On long-running sessions with repeated fullscreen toggles, memory grows unbounded.

**Prevention:**
- Wrap `enterFullscreen` / `leaveFullscreen` in try/finally. Always free `_savedPlacement` in the finally block.
- In `dispose()`, check and free `_savedPlacement` if non-null.
- Add a defensive null-check: `_savedPlacement?.free(); _savedPlacement = null;`

**Detection:** Run with `--enable-asserts` and add a debug-mode allocation counter. If the counter grows after repeated fullscreen toggles, there is a leak.

**Phase:** Fullscreen refactoring phase — must be addressed when touching WindowsFullscreenDriver.

---

### Pitfall 4: Keyboard Shortcut Bindings Lost During Tab Consolidation

**What goes wrong:** Refactoring consolidates tabs (e.g., merging Audio+Equalizer). The `ShortcutsTab` loads bindings from `SettingsStore.loadShortcuts()` and passes changes via `onShortcutsChanged` callback. If the refactoring changes the callback chain or SettingsPanel's `_originalShortcuts` loading, custom bindings are silently lost or overwritten with defaults.

**Why it happens:** Shortcuts use a two-layer pattern: ShortcutsTab notifies via callback, SettingsPanel holds `_originalShortcuts` for cancel-restore. The `onShortcutsChanged` callback chain spans 3 widgets. Any break in the chain means changes are lost.

**Consequences:** User's custom keyboard shortcuts reset to defaults after settings panel refactoring. No error message shown.

**Prevention:**
- Preserve the callback chain: ShortcutsTab -> SettingsPanel.onShortcutsChanged -> SettingsPanel._originalShortcuts.
- On Cancel, call `widget.onShortcutsChanged?.call(_originalShortcuts)` AND `SettingsStore.saveShortcuts(_originalShortcuts)`.
- Add a test that loads custom bindings, opens settings, cancels, and verifies bindings are restored.

**Detection:** If `SettingsStore.saveShortcuts` is called from ShortcutsTab directly (bypassing SettingsPanel), the cancel-restore pattern is broken.

**Phase:** Settings panel refactoring phase — verify after any tab merge or layout change.

---

### Pitfall 5: Settings Store Migration Without Version Field

**What goes wrong:** Refactoring splits `AppSettings` (26 fields) into domain-specific configs (`PlaybackConfig`, `WindowConfig`, etc.). Old SharedPreferences keys like `volume`, `windowWidth` persist on user machines. New code reads new keys, gets defaults, and user loses all their settings.

**Why it happens:** SharedPreferences stores flat key-value pairs. There is no schema version. When you rename keys or restructure the data model, old data becomes orphaned.

**Consequences:** After app update, all user settings reset to defaults. Volume, window position, subtitle preferences, video processing settings — all gone. High user frustration.

**Prevention:**
- Add a `settingsVersion` key to SharedPreferences. Current version = 1.
- On load, check version. If missing or < current, run migration.
- Migration reads old keys and writes new keys. Keep old keys for one release cycle as fallback.
- Never delete old keys in the same release that introduces new keys. Delete in N+1 release.

**Detection:** After refactoring, check if `prefs.getString('settingsVersion')` returns null on an existing install. If so, migration is needed.

**Phase:** Settings store decomposition phase — must be the first step before any structural change.

---

## Moderate Pitfalls

### Pitfall 6: BackdropFilter Nesting Performance Collapse

**What goes wrong:** Settings panel uses `GlassContainer` (BackdropFilter) for each card. Nesting 6-8 GlassContainers in a single tab causes GPU to apply blur filter at each nesting level. On 4K displays, frame time exceeds 16ms and UI stutters.

**Why it happens:** Each `BackdropFilter` captures the pixels behind it, applies a Gaussian blur, and composites the result. Nesting means the outer blur captures already-blurred pixels, wasting GPU cycles. The current `GlassTier` system (thin/normal/thick) caches `ImageFilter` instances but does not prevent nesting overhead.

**Consequences:** Settings panel scrolls at 30fps or below on 4K displays. Users with integrated GPUs (Intel UHD) see visible stutter.

**Prevention:**
- Use a single `ClipRRect` + `BackdropFilter` at the tab content level, not per-card.
- Individual cards use `GlassContainer` with `blurEnabled: false` (container styling only, no blur).
- Only the outermost container applies blur. Inner containers get the visual style (border, background color) without re-blurring.
- Profile with Flutter DevTools > Performance. If `BackdropFilter` appears multiple times in the same frame's render tree, there is nesting.

**Detection:** Open Flutter DevTools Performance tab, scroll settings panel. If `BackdropFilter` paint operations appear 3+ times per frame, nesting is excessive.

**Phase:** UI polish phase — address after functional refactoring is complete.

---

### Pitfall 7: Over-Abstracting Settings Into Too Many Classes

**What goes wrong:** Splitting `AppSettings` into 5 config objects (`PlaybackConfig`, `WindowConfig`, `SubtitleConfig`, `VideoConfig`, `EngineConfig`) plus per-domain stores creates 10+ new files for what was 2 files. Each config needs its own `copyWith`, serialization, validation. The abstraction overhead exceeds the coupling problem it solves.

**Why it happens:** Following "single responsibility" principle too literally. The 26 fields in AppSettings are already immutable and validated. The coupling problem is in SettingsStore's 25+ static methods, not in the data model.

**Consequences:** Developer must touch 5+ files to add one new setting. Test surface area doubles. The "thin aggregate" AppSettings ends up with delegation methods that add no value.

**Prevention:**
- Split SettingsStore (the real problem) into domain-focused stores. Keep AppSettings as a single immutable class.
- If splitting AppSettings, limit to 2-3 groups max (e.g., PlaybackSettings, WindowSettings, MediaSettings). Not 5.
- Each new class must justify its existence with a concrete use case, not just "clean architecture."
- Ask: "Would a new developer understand why this class exists in 30 seconds?" If not, merge it.

**Detection:** If adding a new setting requires changes to 4+ files, the abstraction is too deep.

**Phase:** Architecture phase — decide decomposition scope before coding.

---

### Pitfall 8: Cross-Platform Fullscreen Behavior Divergence

**What goes wrong:** Refactoring WindowsFullscreenDriver (FFI) changes behavior that differs from MacosFullscreenDriver (plugin delegate) or LinuxFullscreenDriver (GTK signal). The `FullscreenDriver` interface hides these differences, but the refactoring accidentally introduces Windows-specific assumptions into shared code.

**Why it happens:** Three different implementations with three different confirmation mechanisms:
- **Windows:** FFI synchronous. No callback needed. `supportsFastPath = true`.
- **macOS:** NSWindowDelegate callback. Async. `supportsFastPath = false`.
- **Linux:** GdkWindow state-changed signal. Async with 3-level confirmation chain. `supportsFastPath = false`.

Refactoring that adds "optimistic update" logic breaks macOS/Linux where the native callback is the source of truth.

**Consequences:** On macOS, fullscreen toggle shows UI change before the native animation completes. On Linux, the 3-level confirmation chain (signal -> poll -> timeout) is bypassed, causing state mismatch on some window managers.

**Prevention:**
- Never add state mutation in the UI layer for fullscreen. All state changes come from WindowService, which receives them from the driver.
- `supportsFastPath` is the only behavioral flag. Use it, do not add platform checks.
- Test fullscreen on all three platforms before merging. A single-platform test is insufficient.

**Detection:** If you see `Platform.isWindows` in settings_panel.dart or any UI file, the abstraction is leaking.

**Phase:** Fullscreen refactoring phase — cross-platform verification required.

---

### Pitfall 9: Settings Validation Boundary Erosion

**What goes wrong:** `SettingsValidator` (pure functions, no I/O) validates all AppSettings fields. During refactoring, validation logic migrates into individual config classes or settings tabs. New fields bypass validation. Corrupt data (NaN volume, negative window size) persists to SharedPreferences and crashes on next load.

**Why it happens:** SettingsValidator was extracted specifically to centralize validation. If refactoring distributes validation back into per-field classes, the central boundary is lost. The `sanitizeDimension` / `sanitizeCoordinate` / `sanitizeRotation` methods exist because real-world data corruption has occurred (see RC-3 window geometry validation).

**Consequences:** App crashes on startup if SharedPreferences contains NaN window width (happened before, hence SettingsValidator.sanitizeDimension). Users must manually delete SharedPreferences to recover.

**Prevention:**
- SettingsValidator remains the single validation boundary. All data crosses it before entering AppSettings.
- New fields must add a validator in SettingsValidator, not inline in the config class.
- SettingsStore.load() calls SettingsValidator for every field. This pattern must not change.
- Add a fuzz test: feed random/corrupt values to SettingsStore.load(), verify it never throws.

**Detection:** If a new field in AppSettings does not have a corresponding SettingsValidator method, validation coverage has regressed.

**Phase:** Settings store decomposition phase — preserve the validator boundary.

---

### Pitfall 10: Window Position Persistence Race During Fullscreen

**What goes wrong:** WindowService saves window position/size on resize/move events with 500ms debounce. If user enters fullscreen while debounce timer is pending, the timer fires after fullscreen is active and saves the fullscreen dimensions (e.g., 3840x2160) as the "windowed" size. On next exit from fullscreen, window restores to monitor-filling size instead of the pre-fullscreen dimensions.

**Why it happens:** `_resizeDebounce` timer is independent of fullscreen state. The `onWindowResize` callback fires during fullscreen enter (the window is being resized to cover the screen). The debounce timer does not check `_isFullscreen.value` before persisting.

**Consequences:** User's carefully arranged window size and position are lost after one fullscreen cycle. Window appears maximized when it should be 1280x752.

**Prevention:**
- Cancel `_resizeDebounce` and `_resizeEndTimer` in the fullscreen enter path (before the resize begins).
- Save a snapshot of current window geometry before entering fullscreen. Restore from snapshot on exit.
- The `_RestoreSnapshot` pattern already exists in WindowService (`_restoreSnapshots` map). Ensure it is used consistently.

**Detection:** Enter fullscreen, exit fullscreen, check if window size matches pre-fullscreen size. If not, the persistence race is active.

**Phase:** Fullscreen refactoring phase — integrate with existing snapshot mechanism.

---

## Minor Pitfalls

### Pitfall 11: Settings Tab Index Hardcoding

**What goes wrong:** Sidebar navigation uses integer indices (`_selectedIndex`). Merging or reordering tabs breaks the index mapping. `GeneralTab` was index 0, but after merging Audio+Equalizer, `VideoTab` moves from index 3 to index 2.

**Prevention:** Use enum or string identifiers for tabs, not raw integers. The `_Sidebar` widget should map `TabId` to index, not the reverse.

---

### Pitfall 12: GlassContainer blurEnabled Flag Forgotten After Refactor

**What goes wrong:** `GlassContainer` has `blurEnabled` flag to skip BackdropFilter. After refactoring, new settings cards forget to set `blurEnabled: false` when nested inside another blur container. Performance degrades silently.

**Prevention:** Add a debug assertion: if a GlassContainer is a child of another GlassContainer and both have blur enabled, log a warning. Enable in debug mode only.

---

### Pitfall 13: SettingsStore Static Singleton Reset in Tests

**What goes wrong:** `SettingsStore._instance` is a static singleton with `prewarm()` / `resetPrewarm()`. Tests that forget `resetPrewarm()` leak state to subsequent tests. One test's mock SharedPreferences affects the next test's load().

**Prevention:** Add `tearDown(() => SettingsStore.resetPrewarm())` in the test group setup. Consider making this automatic via a test helper.

---

### Pitfall 14: Fullscreen Driver dispose() Ordering

**What goes wrong:** `MacosFullscreenDriver` and `LinuxFullscreenDriver` subscribe to `_plugin.onFullScreenChanged` stream in constructor. If `dispose()` cancels the subscription after the plugin is already disposed (e.g., app shutdown race), it throws. Windows driver caches HWND and monitor rects that become invalid after window destruction.

**Prevention:** `dispose()` must be idempotent and defensive. Check `_stateStreamSub != null` before cancel. Set to null after cancel. Wrap in try-catch for shutdown races.

---

### Pitfall 15: Custom Bindings Key ID vs LogicalKey Confusion

**What goes wrong:** `ShortcutsTab` stores custom bindings as `key.keyId.toString()`. `KeyboardHandler` compares against `LogicalKeyboardKey.keyName`. These are different representations of the same key. After refactoring the serialization format, old bindings fail to match.

**Prevention:** Standardize on one representation. Use `key.keyId` (numeric, stable across platforms) for storage and comparison. Never mix `keyId` and `keyName`.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| **Settings store decomposition** | Migration without version field (P5) | Add `settingsVersion` key first |
| **Settings store decomposition** | Validation boundary erosion (P9) | Keep SettingsValidator as single boundary |
| **Settings store decomposition** | Over-abstraction (P7) | Split store, keep model simple |
| **Settings panel tab consolidation** | Keyboard shortcuts lost (P4) | Preserve callback chain, add test |
| **Settings panel tab consolidation** | Tab index hardcoding (P11) | Use enum identifiers |
| **Settings panel UI refactor** | Deferred apply violation (P2) | Locale/theme deferred until OK/Apply |
| **Settings panel UI refactor** | BackdropFilter nesting (P6) | Single blur at tab level, inner cards skip blur |
| **Fullscreen decoupling** | Dual-source truth (P1) | WindowService single owner |
| **Fullscreen decoupling** | Platform divergence (P8) | Test on all 3 platforms, use supportsFastPath |
| **Fullscreen decoupling** | Position persistence race (P10) | Cancel debounce on enter, snapshot geometry |
| **Fullscreen decoupling** | FFI resource leak (P3) | try/finally for Pointer.free() |
| **Fullscreen decoupling** | dispose() ordering (P14) | Idempotent, defensive dispose |

## Sources

- Project memory: `project_fullscreen_bugs.md` — 5 bugs from prior fullscreen work (aspect ratio, channel mismatch, mode race, auto-hide timer, isResizing stuck)
- Project memory: `project_window_anti_patterns.md` — kernel coupling, god objects, over-abstraction lessons
- Project memory: `feedback_deferred_apply_dialog.md` — MaterialApp rebuild destroys dialog state
- Project memory: `project_settings_panel_redesign.md` — deferred apply pattern, OK/Cancel/Apply architecture
- Codebase: `settings_store.dart` — 25+ static save methods, SettingsValidator extraction
- Codebase: `window_service.dart` — FullscreenDriver injection, _isFullscreen ValueNotifier, _restoreSnapshots
- Codebase: `windows_fullscreen_driver.dart` — WS_THICKFRAME stripping, cached HWND/monitor rects
- Codebase: `glass_container.dart` — GlassTier enum, cached ImageFilter, blurEnabled flag
- Codebase: `keyboard_handler.dart` — customBindings map, 20+ callback parameters
- Codebase: `shortcuts_tab.dart` — onShortcutsChanged callback chain, keyId serialization
