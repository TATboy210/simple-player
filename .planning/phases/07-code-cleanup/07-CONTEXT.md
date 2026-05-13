# Phase 4: Code Cleanup - Context

**Gathered:** 2026-05-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Remove dead code, fix the swallowed 'A' key, localize hardcoded Chinese strings, clean up dart analyze warnings, and ensure all overlay entries are properly disposed. Goal: codebase is production-grade with no dead code, no hardcoded strings, no swallowed keys, proper cleanup.

Requirements: CODE-01 through CODE-05 from REQUIREMENTS.md.

</domain>

<decisions>
## Implementation Decisions

### Dead Code Removal (CODE-01)
- **D-01:** Delete `lib/kernel/window/window_manager_service.dart` (514 lines) — replaced by `lib/window/window_service.dart`
- **D-02:** Delete `lib/kernel/platform/windows_platform_service.dart` (53 lines) — only consumer of WindowManagerService, nothing imports it
- **D-03:** Keep `lib/kernel/services/platform_service.dart` (abstract interface) — CustomTitleBar depends on it
- **D-04:** Keep `lib/kernel/window/aspect_ratio_service.dart` — CustomTitleBar depends on it
- **D-05:** Total removal: ~567 lines across 2 files

### CustomTitleBar Crash Fix (prerequisite for CODE-01)
- **D-06:** Use proxy pattern: `PlatformService` internally delegates to `WindowBridge.I` instead of crashing with `StateError`
- **D-07:** CustomTitleBar gets zero code changes — the proxy is transparent
- **D-08:** Implementation: Replace `PlatformService` singleton with a `_Proxy` class that forwards all calls to `WindowBridge.I`. Remove the `init()` factory pattern — the proxy auto-discovers `WindowBridge.I` on first access.

### KeyboardHandler 'A' Key (CODE-02)
- **D-09:** Add `onCycleAspectRatio` callback prop to KeyboardHandler
- **D-10:** Wire it in player_screen.dart to `AspectRatioService.I.cycleRatio()`
- **D-11:** The shortcutDefinitions list already has `'A' → l10n.aspectRatio` — no change needed there

### AspectRatio Label Localization (CODE-03)
- **D-12:** Use l10n key approach: add `aspectRatioFree` l10n key (en: "Free", zh: "自由")
- **D-13:** Change `currentLabel` in `lib/window/aspect_ratio_service.dart` to return 'Free'/'自由' via l10n — BUT this requires the service to accept an l10n parameter or callback, which violates the service layer (no Flutter/l10n dependency)
- **D-14:** Alternative: keep `currentLabel` returning the Chinese string but expose a `currentRatioIndex` or enum that the UI can map to l10n. The kernel version already uses `AspectRatioMode.label` — migrate window version to use the same enum.
- **D-15:** Decision deferred to planner — both approaches are valid. Planner should pick based on code structure.

### dart analyze (CODE-04)
- **D-16:** 4 info-level warnings: `unnecessary_getters_setters` (playlist.dart:33), `unnecessary_underscores` (volume_slider.dart:119, video_processing_tab.dart:82). Fix if trivial, skip if style-only.

### Overlay Cleanup (CODE-05)
- **D-17:** Already satisfied by Phase 01 OverlayPortal migration. OverlayPortal auto-disposes on widget removal. Verify no manual OverlayEntry remains.

### Claude's Discretion
- A key callback naming and placement (D-09 to D-11)
- AspectRatio label approach (D-12 to D-15) — planner has flexibility
- Whether to fix the 4 dart analyze info warnings (D-16)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Dead Code
- `lib/kernel/window/window_manager_service.dart` — 514 lines to delete
- `lib/kernel/platform/windows_platform_service.dart` — 53 lines to delete
- `lib/kernel/services/platform_service.dart` — abstract interface to proxy (NOT delete)
- `lib/kernel/bridge/window_bridge.dart` — target interface for proxy delegation

### CustomTitleBar
- `lib/kernel/ui/window/custom_title_bar.dart` — uses PlatformService.I (line 22), AspectRatioService.I (line 120-126)
- `lib/ui/player/player_screen.dart:126` — instantiates CustomTitleBar (non-fullscreen only)

### KeyboardHandler
- `lib/ui/player/keyboard_handler.dart` — 'A' key at handled-but-no-op (line ~113), shortcutDefinitions declares 'A' → l10n.aspectRatio

### AspectRatio
- `lib/window/aspect_ratio_service.dart` — active version, hardcoded '自由' at line 63
- `lib/kernel/window/aspect_ratio_service.dart` — dead duplicate, uses AspectRatioMode.label
- `lib/kernel/models/aspect_ratio_mode.dart` — enum with label getter (already localized?)

### L10n
- `lib/l10n/app_en.arb` — English strings source
- `lib/l10n/app_zh.arb` — Chinese strings source

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `WindowBridge` interface — already has NoopWindowBridge fallback, perfect proxy target
- `AspectRatioMode` enum — has `.label` getter, could replace hardcoded strings
- `KeyboardHandler` callback pattern — established pattern for adding new key actions
- `OverlayPortal` — already used for popups, auto-cleans on dispose

### Established Patterns
- Singleton proxy: `PlatformService.I` → `_Proxy` → `WindowBridge.I` (transparent to callers)
- Callback prop pattern: KeyboardHandler has 18 callback props, adding one more is trivial
- l10n key addition: same pattern as Phase 06 (ARB files → flutter gen-l10n → use in code)

### Integration Points
- `PlatformService._Proxy` must implement all 10 methods of the abstract interface
- `KeyboardHandler.onCycleAspectRatio` must be wired in `player_screen.dart:89-117`
- `AspectRatioService.currentLabel` is used as tooltip in `CustomTitleBar:125`

</code_context>

<specifics>
## Specific Ideas

- User chose conservative dead code removal: only delete files with zero external dependencies
- User chose proxy pattern for PlatformService fix (not migration of CustomTitleBar)
- User deferred A key, l10n, and dart analyze discussions — planner has full discretion on these

</specifics>

<deferred>
## Deferred Ideas

- Full migration of CustomTitleBar from PlatformService to WindowBridge (deferred to future cleanup)
- Removal of kernel/AspectRatioService (deferred — CustomTitleBar depends on it)
- Removal of PlatformService abstract interface (deferred — CustomTitleBar depends on it)

</deferred>

---

*Phase: 07-code-cleanup*
*Context gathered: 2026-05-14*
