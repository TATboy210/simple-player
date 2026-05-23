# Domain Pitfalls

**Domain:** Flutter Desktop Media Player (Win32 + fvp/MDK)
**Researched:** 2026-05-23
**Overall confidence:** HIGH (project-specific lessons from 18+ real bugs, memory files, and source analysis)

## Critical Pitfalls

### Pitfall 1: BackdropFilter Wrong Layer Caching

**What goes wrong:** BackdropFilter renders into an offscreen texture every frame. Without RepaintBoundary, the entire ancestor tree repaints when any child changes, multiplying GPU readback cost. With RepaintBoundary in the wrong position, the cache captures too much (wastes memory) or too little (defeats the purpose).

**Why it happens:** BackdropFilter triggers a saveLayer on the GPU. Flutter's repaint system doesn't automatically isolate BackdropFilter from sibling repaints. Developers add RepaintBoundary but wrap the wrong subtree.

**Consequences:** Title bar frame drops (the exact user-visible symptom in this project). Each BackdropFilter costs ~2-4ms GPU readback at 1080p. Stacking 3-5 BackdropFilters (title bar + control bar + playlist + popups) compounds to 10-20ms, exceeding 16.6ms frame budget.

**Prevention:**
1. Always wrap BackdropFilter's *child* in RepaintBoundary (already done in GlassContainer -- good)
2. Never wrap BackdropFilter *itself* in RepaintBoundary -- this caches the blur effect but still triggers readback on parent repaint
3. Use `respectResizeState` pattern: disable BackdropFilter during resize/move (already implemented -- preserve this)
4. Limit sigma: `glassBlurThin` (8) for title bar, `glassBlur` (16) for control bar, `glassBlurThick` (24) for dialogs -- never exceed 24

**Detection:** Profile with `--profile` flag. If `flutter_rasterizer` thread shows >4ms per frame during idle, BackdropFilter layer cache is thrashing.

**Phase:** PERF-01 (title bar frame drops). Must profile before optimizing -- the 18 control bar bugs prove that guessing causes more problems than measuring.

---

### Pitfall 2: ValueNotifier Cascading Rebuilds

**What goes wrong:** MediaEngine exposes 8+ independent ValueNotifiers (textureId, state, position, duration, volume, isMuted, isBuffering, subtitleText). Each ValueListenableBuilder rebuilds its subtree independently. When position updates at 4Hz (250ms poller) and state changes simultaneously, multiple rebuilds cascade in a single frame.

**Why it happens:** ValueNotifier.notifyListeners() schedules a rebuild for every listener. With 8 notifiers and widgets listening to 3-4 each, a single frame can trigger 12+ rebuilds. No Selector/filtering mechanism exists in raw ValueNotifier pattern.

**Consequences:** CPU time wasted rebuilding unchanged subtrees. Position slider rebuilds when only volume changed. Control bar rebuilds when subtitle text changed. The effect compounds with BackdropFilter (each rebuild may invalidate the blur cache).

**Prevention:**
1. Scope listeners narrowly -- a widget should listen to ONLY the notifier it renders
2. Use `Selector` equivalent: wrap ValueListenableBuilder with a condition that checks if the value actually changed before rebuilding
3. Group tightly coupled state: volume + isMuted into a single `ValueNotifier<VolumeState>`, position + duration into `ValueNotifier<PositionState>` -- reduces notifier count from 8 to 4-5
4. For position updates, use `ValueListenableBuilder` with a custom `child` parameter for static parts

**Detection:** Add `debugPrint` in build methods during profiling. If a widget's build fires >30 times/second when idle, it's listening to the wrong notifier.

**Phase:** PERF-03 (reduce ValueNotifier excessive rebuilds). Group related state BEFORE profiling to avoid false positives.

---

### Pitfall 3: Win32 FFI HWND Validity

**What goes wrong:** `FullscreenController.init()` calls `_getForegroundWindow()` to cache HWND. If called before the window is fully created, or after the window is destroyed, HWND is 0 or stale. Subsequent `SetWindowLongPtrW` / `SetWindowPos` with invalid HWND causes silent failure or crash.

**Why it happens:** `getForegroundWindow` returns whatever window has focus at call time. During startup, the Flutter window may not yet be foreground. During disposal, the window handle may already be freed by the OS.

**Consequences:** Fullscreen toggle silently does nothing (style changes go to wrong window). Or crash with access violation in `SetWindowPos`. The `_windowedRect` cache stores geometry of a now-invalid window.

**Prevention:**
1. Validate HWND != 0 after `_getForegroundWindow()` -- throw or return early
2. Use `window_manager`'s `WindowManager` to get HWND reliably instead of raw `GetForegroundWindow`
3. Cache HWND in `WindowService.init()` after `setAsFrameless()` completes (the init sequence already does this via Completer)
4. Never call FFI functions after `_disposed = true` -- add guard in FullscreenController

**Detection:** Log HWND value on init. If it's 0 or changes unexpectedly between calls, the window handle is invalid.

**Phase:** PERF-01 (fullscreen interaction with title bar). The 5 fullscreen bugs (aspect ratio blocks, channel mismatch, mode race, auto-hide timer, isResizing stuck) all stem from HWND lifecycle issues.

---

### Pitfall 4: fvp D3D11 Sync Stall (d3d11.sync.cpu=1)

**What goes wrong:** fvp defaults to `d3d11.sync.cpu=1`, forcing CPU-GPU synchronization every frame. This blocks the Flutter raster thread waiting for D3D11 to complete, adding 2-5ms per frame.

**Why it happens:** fvp sets this in `video_player_mdk.dart:274` as a safe default. It ensures CopyResource reads a completed frame, but destroys GPU pipeline parallelism.

**Consequences:** At 60fps, the 16.6ms frame budget loses 2-5ms to sync stalls. Combined with BackdropFilter readback, frame drops become inevitable during video playback + glassmorphism UI.

**Prevention:**
1. Set `d3d11.sync.cpu=0` in `FVP.registerWith()` global options (Tier 1 optimization from fvp_optimization_plan)
2. Test on target hardware -- integrated GPUs may show tearing with sync disabled
3. If tearing occurs, keep sync=1 but also set `shader_resource=1` to offload YUV->RGB to GPU

**Detection:** Profile with GPU-Z or RenderDoc. If `CopyResource` appears as a blocking call in the frame timeline, sync.cpu=1 is the cause.

**Phase:** PERF-02 (fvp D3D11 rendering pipeline). This is a 1-line change with high impact -- do it first.

---

### Pitfall 5: Mutex Race in fvp Texture Handoff

**What goes wrong:** fvp's render callback (MDK thread) and descriptor callback (Flutter raster thread) share a single `scoped_lock(mtx)`. When MDK renders at display refresh rate, the two threads compete for the lock every frame, causing jitter.

**Why it happens:** `fvp_plugin.cpp` lines 62-64 (descriptor) and 74-78 (render) both acquire the same mutex. The critical section includes CopyResource + Flush, which are GPU-bound and hold the lock for 1-3ms.

**Consequences:** Frame timing becomes non-deterministic. Some frames wait 0.5ms for the lock, others wait 3ms. The visible symptom is micro-stutter during smooth playback.

**Prevention:**
1. Application layer: cannot fix directly (requires fvp fork)
2. Mitigate by reducing frame rate demands: use `snapshotDebounce` pattern for thumbnails/previews
3. Long-term: implement triple-buffer in fvp fork (Tier 2 optimization -- eliminates 90% of lock contention)

**Detection:** If playback stutters at exactly the monitor refresh rate (not content framerate), mutex contention is the likely cause.

**Phase:** PERF-02 (fvp D3D11 rendering pipeline). Tier 2 optimization -- requires fork, so plan for it but don't block on it.

## Moderate Pitfalls

### Pitfall 6: ValueListenableBuilder Element Reuse Blocks setState

**What goes wrong:** When a `ValueListenableBuilder` wraps a widget that also uses `setState`, changing setState-driven state doesn't trigger a rebuild because Flutter reuses the Element (same type + same listenable reference). The builder closure captures stale state.

**Why it happens:** Flutter's reconciliation algorithm matches Elements by type and key. If neither changes, the existing Element is reused and its builder is NOT re-invoked with the new closure.

**Consequences:** Volume/Speed button highlight not appearing when popup opens. This exact bug was found in Round 4 of the control bar bug hunt (bug #18). Fix required `key: ValueKey(_popupOpen)` to force Element recreation.

**Prevention:**
1. When a `ValueListenableBuilder`'s builder depends on setState-driven state, add `key: ValueKey(stateVariable)`
2. Prefer lifting state into the ValueNotifier instead of mixing setState + ValueListenableBuilder
3. If mixing is unavoidable, use a single `ChangeNotifier` that owns all related state

**Detection:** Button color/opacity doesn't change when expected. Debug by adding print in builder -- if builder doesn't fire on setState, Element reuse is the cause.

**Phase:** PERF-03 (ValueNotifier rebuild optimization). This is a structural issue, not a performance issue.

---

### Pitfall 7: Fullscreen + Aspect Ratio Interaction

**What goes wrong:** `AspectRatioService` locks ratio to video dimensions on play. `WM_SIZING` handler enforces this ratio during fullscreen resize. The window cannot cover the full screen because the ratio constraint prevents it from matching the monitor's aspect ratio.

**Why it happens:** Two independent systems (aspect ratio lock and fullscreen toggle) fight each other. The ratio service doesn't know about fullscreen transitions.

**Consequences:** Fullscreen toggle fails or shows letterboxing. This was bug #1 in the fullscreen bug analysis -- the most fundamental fullscreen bug.

**Prevention:**
1. Always unlock aspect ratio BEFORE entering fullscreen (already fixed in FullscreenController.enter())
2. Restore ratio AFTER exiting fullscreen (already fixed in FullscreenController.exit())
3. C++ `WM_SIZING` handler must skip constraint when window covers monitor (already fixed)
4. Test: every fullscreen toggle test must verify ratio is preserved after round-trip

**Detection:** Fullscreen doesn't cover taskbar, or window has letterboxing in fullscreen.

**Phase:** Already fixed. Include in regression test suite (TEST-01).

---

### Pitfall 8: Completer Race in Window Lifecycle

**What goes wrong:** `WindowService` uses `Completer<void>? _initCompleter` to guard async initialization. If `dispose()` is called before `init()` completes, or if `init()` is called twice, the Completer either never completes (hangs) or completes after disposal (crash).

**Why it happens:** Multiple boolean guards (`_initialized`, `_disposed`, `_togglingFullscreen`, `_closing`) manage lifecycle state. The order of checking these guards matters -- checking `_disposed` before `_initialized` vs. the reverse leads to different behavior.

**Consequences:** App hangs on close (Completer never completes). Or crash when a Future completes after the widget tree is disposed.

**Prevention:**
1. Always complete Completer in a `finally` block -- never let it leak
2. Check `_disposed` FIRST in every async operation
3. Use `_initCompleter?.future ?? Future.value()` pattern for safe awaiting
4. The 500ms debounce persistence pattern helps -- debounce window events to avoid racing with dispose

**Detection:** App hangs on window close. Or "setState called after dispose" errors in console.

**Phase:** ARCH-01 (WindowService deduplication). The race condition exists in all 3 platform services -- fixing it once in the base mixin fixes it everywhere.

---

### Pitfall 9: Silent Exception Swallowing

**What goes wrong:** `catch (_)` blocks silently discard exceptions. `fvp_engine.dart:538` returns 0 for subtitle delay on any parse error. `playlist_store.dart:136` skips corrupted items silently. No logging, no user feedback.

**Why it happens:** Defensive coding adds catch blocks but doesn't invest in error reporting. The `catch (_)` pattern looks safe but hides real problems.

**Consequences:** Users report "subtitle delay doesn't work" with no diagnostic data. Playlist corruption goes unnoticed until data loss. Debugging production issues becomes impossible.

**Prevention:**
1. Replace all `catch (_)` with `catch (e) { debugPrint('...'); }` at minimum
2. For user-facing operations, surface errors via OSD or error banner
3. Reserve `catch (_)` only for truly ignorable cases with a comment explaining why
4. Add error type to `MediaErrorType` enum for structured error reporting

**Detection:** Grep for `catch (_)` in codebase. Each occurrence needs justification.

**Phase:** Early cleanup -- can be done in any phase as a code quality task.

---

### Pitfall 10: PlaylistStore Non-Atomic Write

**What goes wrong:** `_flush` writes JSON directly to the target file. If the app crashes or loses power during write, the file is partially written and corrupted on next read.

**Why it happens:** The 3-attempt retry loop mitigates transient I/O errors but not crashes. No write-to-temp-then-rename pattern is used.

**Consequences:** Playlist data loss on crash. Users lose their history and folder groupings.

**Prevention:**
1. Write to `path.tmp` first, then `File.rename()` to target (atomic on Windows NTFS)
2. Keep one backup of the previous version (`path.bak`)
3. On read failure, try backup before giving up

**Detection:** Corrupted playlist JSON after app crash. Test by killing process during flush.

**Phase:** ARCH-02 (ThumbnailService refactor scope could include persistence hardening).

## Minor Pitfalls

### Pitfall 11: Static Singleton State Leaks in Tests

**What goes wrong:** `ThumbnailService`, `OsdService` use static mutable state. Test runs share state, causing non-deterministic failures.

**Prevention:** Convert to instance-based services. Use `setUp`/`tearDown` to create fresh instances per test.

**Phase:** TEST-03 (unit tests for untested layers).

---

### Pitfall 12: Overlay Popup Escaping FadeTransition

**What goes wrong:** Volume/Speed popups use `OverlayEntry` at the app-level Overlay. They don't fade with the control bar's `FadeTransition` because they're not in the same subtree.

**Prevention:** Use local `Overlay` within ControlsOverlay, or close popups before hiding the bar.

**Phase:** PERF-01 (control bar rendering optimization).

---

### Pitfall 13: Golden Test Flakiness on Desktop

**What goes wrong:** Golden tests for glassmorphism UI depend on BackdropFilter rendering, which varies by GPU, driver version, and Impeller/Skia backend. Golden files generated on one machine fail on another.

**Prevention:**
1. Use `tester.runAsync` for golden tests that need real rendering
2. Set a tolerance threshold (`matchesGoldenFile` with `tolerance`)
3. Generate goldens in CI with pinned GPU/driver (or use software rendering)
4. Consider snapshot testing without pixel comparison -- just verify widget tree structure

**Phase:** TEST-02 (golden tests). Plan for flakiness from day 1.

---

### Pitfall 14: Platform Channel Mocking Gaps

**What goes wrong:** Window operations use `window_manager` plugin which calls native code. Unit tests can't call native code, so either all window tests are skipped or the mock surface is incomplete.

**Prevention:**
1. `WindowBridge` abstraction already exists -- inject `NoopWindowBridge` or `_FakeWindowBridge` in tests (pattern already in window_service_test.dart)
2. For integration tests, use real `WindowService` on Windows CI runner
3. Document which behaviors are untestable without native (fullscreen style manipulation, monitor rect query)

**Phase:** TEST-01 (integration tests) and TEST-03 (window layer tests).

---

### Pitfall 15: MFT Decoder D3D Version Mismatch

**What goes wrong:** `platform_decoders.dart` uses `MFT:d3d=1` (D3D9) while fvp defaults to D3D11 rendering. This creates a D3D9->D3D11 surface conversion on every frame.

**Prevention:** Change to `MFT:d3d=11` to align with the rendering path. Already documented in fvp optimization plan as Tier 1, P0 priority.

**Phase:** PERF-02 (fvp D3D11 rendering pipeline). 1-line fix.

---

### Pitfall 16: Popup Overlay GestureDetector Intercepts Button Taps

**What goes wrong:** Full-screen `GestureDetector(HitTestBehavior.translucent)` on popup overlay intercepts taps on the button area. User clicks button, overlay GestureDetector fires first, closes popup. User perceives highlight as "not working" because it only shows for one frame.

**Why it happens:** App-level Overlay sits above ControlsOverlay. The popup's GestureDetector covers the entire screen for "tap outside to close" behavior, but this also covers the button that opened it.

**Consequences:** 5 rounds of bug fixes (18 bugs) applied correct code, but user still reports highlight not visible. Root cause is architectural, not a code bug.

**Prevention:**
1. Use local Overlay (within ControlsOverlay) instead of app-level Overlay
2. Or close popups when control bar auto-hides
3. Or use `HitTestBehavior.deferToChild` with explicit hit test regions

**Phase:** PERF-01 (title bar / control bar rendering). Architectural fix needed.

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| PERF-01: Title bar frame drops | Optimizing BackdropFilter without profiling first -- might be ValueNotifier rebuilds | Profile with `--profile` + Timeline. Measure before changing. |
| PERF-01: Control bar | Popup overlay architecture (Pitfall #16) cannot be fixed by optimizing individual widgets | Fix overlay pattern before optimizing rendering |
| PERF-02: fvp D3D11 | Setting d3d11.sync.cpu=0 causes tearing on some GPUs | Test on 3+ hardware configs before shipping |
| PERF-02: fvp D3D11 | Changing MFT:d3d version may break on old drivers | Add fallback chain: D3D11 -> D3D9 -> FFmpeg |
| PERF-03: ValueNotifier | Grouping notifiers breaks existing listeners that depend on granular updates | Audit all ValueListenableBuilder usages before grouping |
| PERF-03: ValueNotifier | Using Selector/filtering adds complexity without measurable benefit if rebuilds are cheap | Profile first -- if rebuilds <1ms, don't optimize |
| ARCH-01: WindowService | Extracting base mixin may introduce subtle behavior differences between platforms | Test all 3 platforms after extraction |
| ARCH-02: ThumbnailService | Converting static to instance requires updating all call sites | Use find-references, not grep -- Dart analyzer is more reliable |
| TEST-01: Integration tests | Platform channel mocking makes integration tests brittle | Use real native code on Windows CI, mock on other platforms |
| TEST-02: Golden tests | BackdropFilter goldens are GPU-dependent | Use tolerance thresholds, generate in CI only |
| Any phase | Forgetting to check `_disposed` before async operations | Add lint rule or static analysis check |

## Sources

- Project memory: `project_window_anti_patterns.md` (Completer race, debounce pattern, over-abstraction)
- Project memory: `project_fullscreen_bugs.md` (5 fullscreen bugs, aspect ratio interaction)
- Project memory: `project_controlbar_bugs.md` (18 control bar bugs across 5 rounds)
- Project memory: `widget_highlight_analysis.md` (overlay GestureDetector intercept)
- Project memory: `reference_fvp_performance_bottlenecks.md` (9 fvp bottlenecks ranked)
- Project memory: `reference_fvp_optimization_plan.md` (3-tier optimization plan)
- Project memory: `reference_fvp_source_structure.md` (fvp_plugin.cpp analysis, D3D11 parameters)
- Project memory: `project_impeller_migration.md` (Impeller risk matrix for BackdropFilter)
- Codebase concerns: `.planning/codebase/CONCERNS.md` (tech debt, fragile areas, scaling limits)
- Source: `lib/ui/shared/glass_container.dart` (GlassContainer + GlassTier implementation)
- Source: `lib/window/fullscreen_controller.dart` (Win32 FFI patterns)
- Source: `lib/kernel/engine/fvp_engine.dart` (8 ValueNotifiers, FvpEngine structure)
- Source: `test/window/window_service_test.dart` (existing test patterns)
