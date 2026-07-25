# Domain Pitfalls — v4.5 设置面板横向重构 + 音频功能填充

**Domain:** Flutter desktop media player — settings panel horizontal-tab redesign + audio feature backfill
**Researched:** 2026-07-25
**Confidence:** HIGH (grounded in live code: `settings_overlay_shell.dart`, `settings_panel_controller.dart`, `control_bar.dart`, `keyboard_handler.dart`, `pending_settings.dart`, `right_button_group.dart`, `playback_controller.dart`)

---

## Critical Pitfalls

These cause rewrites, broken UX, or regressions in existing playback if missed.

---

### Pitfall 1: `keyboard_handler.dart` ←/→ seek ±5s collides with tab switching ONLY when settings panel is closed

**What goes wrong:** `keyboard_handler.dart` lines 120–127 hard-bind `arrowLeft`/`arrowRight` to `onSeekBackward`/`onSeekForward` (±5s seek). `settings_overlay_shell.dart` `_handleKeyEvent` (lines 423–433) also binds the same keys to `prevTab`/`nextTab`. Both are `Focus` `onKeyEvent` handlers.

**Why it's NOT actually a conflict (but a trap if re-implemented wrong):** The panel's `FocusTraversalGroup` + `Focus(autofocus: true)` (shell line 223) **captures** arrow keys when the panel is open — `_handleKeyEvent` returns `KeyEventResult.handled`, preventing bubble to the outer `KeyboardHandler`. The architecture researcher confirmed this. **The pitfall is in REMOVAL:** if a v4.5 refactor moves tab-switching to a sibling Focus node (e.g. an arrow-button Focus widget separate from the option list), the unhandled arrows in the option list will bubble up and seek the video. Symptom: user presses ↓ at end of option list → video seeks forward 5s instead of doing nothing.

**Consequences:** Silent video seek while user is editing audio EQ; user notices only after closing panel; position drift breaks "auto-pause + resume" contract.

**Prevention:**
- Keep ONE `FocusTraversalGroup` wrapping the WHOLE panel (shell line 222) with a single root `Focus(autofocus, onKeyEvent: _handleKeyEvent)` that returns `handled` for ALL recognized keys (←/→/↑/↓/ESC/B/LB/RB) — never let arrows escape the subtree.
- For arrow-button widgets (竖向圆角左右箭头), use `onTap`/`InkWell` — NOT their own `Focus` `onKeyEvent` — to avoid splitting the focus tree. The root handler still routes ←/→ to nextTab/prevTab.
- Add a widget test: open panel, press ↓ at bottom of option list, assert `onSeekForward` NOT called (spy on `PlayerActions.onSeekForward`).

**Detection:** `flutter test` with a fake `KeyboardHandler` counting seek invocations; fail if >0 while panel isOpen.

---

### Pitfall 2: Auto-pause "always" strategy races with `openGeneration` + end-of-media + manual pause

**What goes wrong:** v4.5 changes `_wasPlaying` guard to "always pause on open, always resume on close". Three sub-races:

1. **Loading/buffering race:** User opens panel while `MediaState` is `loading` or `buffering` (not `playing`). `engine.pause()` on a non-playing engine is a no-op, but on close `engine.play()` starts playback the user never started. Result: a paused-at-loading media suddenly starts playing.
2. **End-of-media resume:** Track finished (`MediaState.ended` or `paused` at EOF) when panel opened. Close calls `play()` → engine replays from start or no-ops. User expectation: stay paused.
3. **Manual-pause before open:** User pressed Space (paused manually), then opens settings. v4.5 "always pause" → pause() (no-op, already paused). Close → play() resumes — **violates user intent** (they paused on purpose).
4. **openGeneration guard:** `playback_controller.dart` `open()` has an `openGeneration` counter (line 34, 200). If user opens settings panel mid-load, then closes, `play()` fires concurrently with the engine's own open() → state machine confusion.

**Consequences:** Unexpected playback start; EOF replay; violates user intent; engine state machine conflict.

**Prevention:**
- **Don't drop the snapshot — widen it.** Replace `bool _wasPlaying` with `MediaState _preOpenState` (snapshot `engine.state.value` BEFORE pause). On close: only call `play()` if `_preOpenState == MediaState.playing`. This is "always pause, resume-if-was-playing" — semantically what the PROJECT.md "always pause" actually means (auto-pause always engages, but resume respects original state).
- Add `MediaState.ended` and `MediaState.loading` to the NO-RESUME set explicitly.
- For `openGeneration`: `SettingsPanelPlayback` is already a thin forwarder that does NOT touch `openGeneration` (controller line 200). Keep it that way — do NOT call `engine.open()` or `engine.stop()` from settings code.
- Guard close() with a state re-check: `if (_playback.isPlaying == false && _preOpenState != playing) skip resume`.

**Detection:** Widget test: load media → wait for `loading` state → open panel → close → assert `play()` NOT called. Same for EOF state.

---

### Pitfall 3: BackdropFilter stacking — desktop glassmorphism perf cliff at ≥3 layers

**What goes wrong:** v4.5 visual alignment to control bar = `BackdropFilter` on the panel. Already in `settings_overlay_shell.dart` via `GlassContainer(tier: GlassTier.normal)`. But v4.5 ADDS:
- Thin glass overlay on top/bottom arrow buttons ("透看选项" — see-through options) → another `BackdropFilter`.
- Option row selected-state glass highlight → another `BackdropFilter` per selected row.
- Hover glass highlight → more.

`control_bar.dart` (the design north star) uses ONE `BackdropFilter` (line 215) gated by `opacity < 0.01` skip (line 223) and a `RepaintBoundary` (line 210). On Windows desktop, each `BackdropFilter` is a GPU readback. 3+ stacked = frame drops during scroll/drag.

**Consequences:** Jank during tab drag, option scroll, or hover; RSS spike; dev machine fine but Steam Deck / low-end laptop stutters.

**Prevention:**
- **Reuse the control_bar pattern exactly:** ONE `BackdropFilter` per panel (the GlassContainer), `RepaintBoundary` outside it. Arrow-button "thin glass" = use `GlassTier.subtle` (or a new lighter tier) as a `Container(color: Tokens.bgGlass)` with NO `BackdropFilter` — it paints over the panel's already-blurred background, faking the glass-without-actually-blurring. The "透看选项" effect comes from translucency, not a second blur pass.
- Gate `BackdropFilter` on `resizing` flag (shell line 49 already accepts `ValueListenable<bool>? resizing` → forwards to `GlassContainer` which skips blur when resizing) — keep this.
- Cap stacked `BackdropFilter` count at 2 (panel + 1 arrow overlay) and only if perf testing on target hardware shows <1ms impact.
- For hover/selected glass: use `EdgeGlow` + `Container(color: bgGlass)` — never `BackdropFilter`.

**Detection:** Profile with `PerfMonitor` (existing, MEMORY.md) during drag; assert frame time <16ms on a low-end target.

---

### Pitfall 4: Horizontal `TabBar` overflow on narrow panels — 7 equal-width tabs don't fit at 400px

**What goes wrong:** v4.0 shell `_buildTabBar` (lines 253–280) uses `Row` + `Expanded` × 7 + fixed `SettingsNavItem`. PROJECT.md says v4.5 changes ratio from 5:4 (clamp 400–600) to **16:9 / 50% screen area**. At 50% of a 1920-wide display = 960px panel → fine. But on a 1024-wide secondary monitor / windowed mode, panel ≈ 512px → 7 tabs × ~73px each = labels truncate. At 800px breakpoint (`Tokens.breakpointResponsive`), `isCompact` kicks in (shell line 219) but only shrinks font/spacing — doesn't fix label truncation. On Steam Deck (1280×800 windowed), panel ≈ 640px → "均衡器"/"快捷键" truncate.

**Consequences:** Truncated tab labels; can't read which tab is active; accessibility failure.

**Prevention:**
- **Don't use 7 equal-width tabs at all widths.** Switch to `TabBar` (Material) with `isScrollable: true` when `width < threshold` — it auto-scrolls and gives native overflow arrows (which double as the "竖向圆角左右箭头" design intent — see Pitfall 5).
- Or keep custom `Row` but: (a) at compact width, hide labels show icon-only (like `NavigationRail`); (b) use `Flexible` not `Expanded` so tabs can shrink-to-fit.
- Add `LayoutBuilder` to choose layout strategy — but per the LayoutBuilder-vs-MediaQuery feedback memory, use ONE source per widget. Panel already uses `MediaQuery.sizeOf(context)` (shell line 216) — keep MediaQuery, don't mix in LayoutBuilder.
- Define explicit breakpoints in `Tokens`: `tabIconOnlyWidth`, `tabScrollWidth`, `tabFullWidth`.

**Detection:** Widget test at 400/512/640/960/1920 widths; assert no `TextOverflow.ellipsis` on tab labels.

---

### Pitfall 5: "竖向圆角左右箭头" — RepaintBoundary placement and arrow-button animation repaint scope

**What goes wrong:** The v4.5 arrow buttons (tab strip ends, persistent + clickable + keyboard ←/→) animate (glow on key press, "渐入/渐退" hint fade). If placed OUTSIDE the panel's `RepaintBoundary` (shell line 221), every arrow glow repaint walks up to the PlayerScreen and triggers video surface repaint. If placed INSIDE without their own `RepaintBoundary`, their animation repaints the whole tab strip + content area.

**Consequences:** Video surface flicker during tab switch; frame drops; GPU readback storms.

**Prevention:**
- Each arrow button gets its OWN `RepaintBoundary` wrapping ONLY the animated subtree (glow + icon). Pattern from `control_bar.dart` line 201 (`RepaintBoundary(child: content)`) applied at button level.
- Use `AnimatedBuilder` + `Tween` for glow — NOT `setState` (which would rebuild the whole tab strip).
- The fade hint substitution ("手柄→RB/LB 渐入 / 方向键渐退") should drive a single `Animation<double>` on a `ValueListenable<InputMode>` — wrap the hint in its own `RepaintBoundary` so the cross-fade doesn't repaint the tab strip.

**Detection:** `RepaintBoundary` debug paint; frame-time assertion during rapid ←/→ presses.

---

## Moderate Pitfalls

---

### Pitfall 6: Steam Input API LB/RB auto-map to keyboard ←/→ — DOUBLE-FIRES tab switch

**What goes wrong:** Steam Input API maps gamepad LB/RB to keyboard ←/→ (per PROJECT.md "无 Flutter 侧适配层"). But `settings_overlay_shell.dart` `_handleKeyEvent` ALSO binds `gameButtonLeft1`/`gameButtonRight1` (lines 451–458) directly. So pressing LB on a Steam-mapped controller fires BOTH the keyboard ← event (from Steam remapping) AND the gamepad ← event (from raw hardware). Tab switches TWICE (or 0→6→5 net, depending on order).

**Consequences:** Tab navigation skips every other tab; user perceives "LB didn't work, presses again" → overshoots.

**Prevention:**
- **Remove the direct gamepad key bindings from `_handleKeyEvent`** (lines 436–445). Rely solely on Steam Input's keyboard remapping. The `_isLeftShoulder`/`_isRightShoulder` code becomes dead — delete it.
- Keep an escape hatch: if Steam Input is NOT running (user launched .exe directly), gamepad events arrive as `gameButtonLeft1` raw. Detect this with a `ValueListenable<bool> _steamInputActive` (set by a platform check) and only then bind raw gamepad keys. Otherwise rely on ←/→.
- Test: unplug Steam Input, press LB → assert tab switches once.

**Detection:** Widget test injecting both `arrowLeft` and `gameButtonLeft1` in sequence; assert only ONE `prevTab` call.

---

### Pitfall 7: Input mode detection reliability — gamepad connect/disconnect timing

**What goes wrong:** v4.5 "输入模式感知提示置换" needs to know if the user is on gamepad or keyboard to show RB/LB vs ←/→ hints. Detection options:
- `RawKeyboardListener` / `HardwareKeyboard.instance` — tells you the LAST input device type, but gamepad-as-keyboard (via Steam) looks IDENTICAL to a real keyboard.
- `widget.gamepad` / `win32` raw XInput polling — accurate but adds a platform dep.

**Consequences:** Hint shows "←/→" while user holds gamepad → confusion; or flickers between modes.

**Prevention:**
- **Simplest reliable heuristic:** Default to keyboard hint. Show gamepad hint ONLY when a `KeyDownEvent` with `LogicalKeyboardKey.gameButton*` arrives (i.e. raw gamepad event bypassed Steam). When a non-game-button key arrives, switch back to keyboard hint. Debounce 500ms to prevent flicker.
- Do NOT try to detect "is a gamepad connected" — that's a platform channel rabbit hole. Let the LAST input event type drive the hint.
- Store the mode in a `ValueNotifier<InputMode>` on the controller (not on the shell widget — survives tab switches).

**Detection:** Manual test: press key → see ←/→ hint; press LB (no Steam) → see RB/LB hint within 500ms.

---

### Pitfall 8: Deferred apply — tab switch then close doesn't flush pending

**What goes wrong:** `PendingSettingsState` (pending_settings.dart) is a pure Dart map — tab switches don't clear it. So pending IS preserved across tab switches (good). BUT:

1. **v4.5 only fills the audio tab** — PROJECT.md says video/subtitle/playback tabs stay as `SettingRow` placeholders. If a placeholder tab has a stale `register()` from v4.0 (shell `open()` line 51–52 registers `locale`/`themeIndex`), and v4.5 adds audio `register('eq', ...)` etc., the OK/Apply button must flush ALL registered keys — not just the current tab's.
2. **Apply-then-Cancel semantics:** `pending.commit()` updates `_originals` (line 46). If user Apply on audio tab, switches to general tab, Cancel — the general tab's pending is also rolled back to its ORIGINAL (pre-open), losing the audio Apply. PROJECT.md says "Apply-then-Cancel 以已提交值为基准" — but the current `cancel()` (line 55) returns `_originals` which WAS updated by commit. So Cancel after Apply is a no-op (returns committed values). This is correct, but the **widget** must re-read `current()` after Cancel to refresh the display — `PendingSettingsState` is not a `ChangeNotifier`, so widgets won't auto-refresh.
3. **Audio EQ live-preview vs deferred:** EQ slider changes should probably preview live (user hears the change) but only commit on OK. If live-previewing via `engine.setAudioEq()` directly, then Cancel must ROLLBACK the engine too — `pending.cancel()` only rolls back the map, not the engine. **This is the biggest deferred-apply pitfall.**

**Consequences:** EQ preview can't be undone; settings silently lost on tab switch + close; OK doesn't flush all tabs.

**Prevention:**
- For audio EQ: do NOT live-preview through the engine. Show the slider value as a NUMBER; apply only on OK/Apply. If live-preview is a hard requirement (PRODUCT decision), snapshot the engine's pre-open EQ state in the controller and restore on Cancel — `pending.cancel()` returns the original map; the controller's close() then calls `engine.setAudioEq(originalEq)`.
- After ANY `commit()`/`cancel()`, the shell must `setState()` on the content area so `IndexedStack` children re-read `current()`. Currently `_buildButtonBar` (line 368) calls commit/cancel but does NOT trigger content rebuild — the `IndexedStack` children read `pending.current()` once at build. Add a `ValueNotifier<int>` `pendingVersion` on the controller bumped on every commit/cancel; content area listens and rebuilds.
- Test: open panel, change EQ, switch to general tab, switch back, assert EQ slider shows changed value; press Cancel, assert slider returns to original.

**Detection:** Widget test covering tab-switch-then-Cancel and Apply-then-Cancel flows.

---

### Pitfall 9: Control bar audio track button — dropdown positioning (OverlayEntry vs PopupMenu)

**What goes wrong:** v4.5 adds an audio track button to `right_button_group.dart` between subtitle and playlist (symmetry with subtitle button per PROJECT.md). Existing subtitle button uses `GlassButton.iconOnly(onPressed: actions.onOpenSubtitle)`. The audio track popup needs to list tracks (variable count, scrollable).

- `PopupMenuButton` — Material-styled, doesn't match glass design language; fixed positioning (below button); can't be themed to glass without overriding `PopupMenuThemeData`.
- `OverlayEntry` + custom `Positioned` widget — full design control, glass-themed, but MUST handle: (a) dismiss on outside tap; (b) dismiss on ESC; (c) positioning relative to button (button moves on window resize → overlay must follow or close); (d) route transition.
- **Symmetry pitfall:** subtitle button has NO popup in `right_button_group.dart` (it just calls `onOpenSubtitle` — likely a file picker). If audio button opens a glass dropdown but subtitle button doesn't, they're NOT symmetric.

**Consequences:** Design inconsistency; popup orphaned on window move; ESC doesn't close; focus trap leaks to background.

**Prevention:**
- Use `OverlayEntry` with a `GlassContainer`-styled dropdown (matches design language). Pattern: see existing `playlist_panel.dart` floating window for the glass-overlay pattern.
- Use `LinkedScrollScrollView` / `CompositedTransformTarget` + `CompositedTransformFollower` so the dropdown follows the button on window resize.
- Close on: ESC key, outside-tap (`TapRegion`), route-pop, window resize (`WidgetsBinding.instance.window.onMetricsChanged`).
- **For symmetry:** if subtitle button is just a file-open trigger, the audio button should ALSO be a file-open trigger (open external audio) — OR the subtitle button should get its own glass dropdown for embedded subtitle tracks. Decide per PRODUCT; don't ship half-symmetric.
- Focus: wrap dropdown in `FocusTraversalGroup` with `autofocus` on first track; ESC handled by dropdown's own `Focus.onKeyEvent`, not the panel's.
- **Both popups open at once:** if user opens audio dropdown then clicks subtitle button, the audio dropdown must close first. Use a single `OverlayEntry`-manager `ValueNotifier<int>` on the player screen that closes any open overlay before opening another.

**Detection:** Widget test: open audio dropdown, press ESC, assert closed; open audio dropdown, click subtitle, assert audio dropdown closed.

---

### Pitfall 10: 16:9 ratio + 50% screen area — responsive clamp values and multi-monitor

**What goes wrong:** PROJECT.md says "16:9 ratio / 占屏约 50% 面积". But:
- 50% of screen AREA ≠ 50% of screen width. 50% area = √0.5 ≈ 0.707 × width × 0.707 × height. On 1920×1080 → ~1357×764. That's NOT 16:9 (1357/764 ≈ 1.78 ✓, 16:9 = 1.778 — coincidentally close, but only because the screen itself is 16:9).
- On a 16:10 monitor (1920×1200), 50% area panel = 1357×849, ratio 1.60 — NOT 16:9. Conflict between "16:9" and "50% area" constraints.
- Multi-monitor: `display_enumerator.dart` (existing, per MEMORY.md `project_multi_monitor_ffi.md`) already clamps window position to the work area. Panel dragOffset clamping in shell `_onDragUpdate` (line 510) uses `MediaQuery` (window-relative), NOT the monitor work area — panel can be dragged to the wrong monitor.
- Window resize: panel sizing uses `MediaQuery.sizeOf(context)` (shell line 216) — updates on window resize. But if user shrinks window while panel open, panel may exceed window bounds.

**Consequences:** Panel doesn't match design ratio on non-16:9 monitors; panel draggable off-screen on multi-monitor; panel overflows on window shrink.

**Prevention:**
- **Pick ONE primary constraint:** "16:9 ratio, width = min(50% screen width, screen height × 16/9)". On 16:9 screen, width = 50% screen width (since height × 16/9 ≈ width × 0.5 only on 16:9 screens). On 16:10 screen, height-bounded: width = screenHeight × 1.778, which is < 50% area. This keeps 16:9 always.
- Define in `Tokens`: `panelAspectRatio = 16/9`, `panelWidthRatio = 0.5` (max), `panelMinWidth = 400`, `panelMaxWidth = 960`. Clamp width to `[min, min(max, screenH × 16/9)]`.
- For multi-monitor drag: use `display_enumerator`'s work-area Rect (existing FFI) to clamp `dragOffset`, not `MediaQuery`. Add a `ValueNotifier<Rect>` `workArea` on the controller updated on monitor change.
- For window resize while open: add `WidgetsBinding.instance.addSizedStructureChangedListener` → if new window < panel size, shrink panel (respect min) and re-center.

**Detection:** Widget test at 16:9, 16:10, 21:9, 4:3 screen ratios; assert panel stays 16:9.

---

## Minor Pitfalls

---

### Pitfall 11: `FocusTraversalGroup` tab strip vs option list — traversal order

**What:** v4.0 has ONE `FocusTraversalGroup` for the whole panel (shell line 222). v4.5 adds arrow buttons + option list. Default `ReadingOrderTraversalPolicy` may jump focus: tab → arrow button → option row → button bar — not the intended "tab strip then option list" order.
**Prevention:** Use an explicit `FocusTraversalPolicy` (e.g. `OrderedTraversalPolicy`) with `order` map, OR nest two `FocusTraversalGroup`s (tab strip group, option list group) so Tab cycles within each.

---

### Pitfall 12: Glass blur radius consistency between panel and control bar

**What:** `control_bar.dart` uses `GlassTier.normal.blurFilter` (line 215). Panel shell uses `GlassContainer(tier: GlassTier.normal)` (shell line 226). Same tier → same blur — good. But v4.5 adds arrow-button "thin glass" overlay (Pitfall 3) which needs a DIFFERENT blur radius to look distinct. If hardcoded, drifts from `Tokens`.
**Prevention:** Add `GlassTier.subtle` (or `GlassTier.overlay`) to `glass_container.dart` with its own `blurFilter` and `bgGlass` color in `Tokens`. Never hardcode blur radius in widget code.

---

### Pitfall 13: `IndexedStack` keeps all 7 tabs alive — memory + initial build cost

**What:** shell `_buildContent` (line 297) uses `IndexedStack` → all 7 tabs build on panel open. v4.5 fills the audio tab with real widgets (EQ sliders etc.) → build cost rises. v4.0 placeholder tabs were cheap.
**Prevention:** Lazy `IndexedStack` pattern — wrap each tab in a `Builder` + a `bool _built` set; only build on first show. Or use `Offstage` + `keepAlive`. Trade-off: tab switch first-show has a build cost.

---

### Pitfall 14: `Future.delayed` exit-animation unload races with rapid toggle

**What:** shell `_onIsOpenChanged` (line 130) uses `Future.delayed(200ms)` to unload after close animation. If user toggles open→close→open within 200ms, the delayed callback fires while panel is open — but the `if (!_controller.state.isOpen.value ...)` guard (line 131) prevents unload. Still, the `Future` is not cancelled — minor leak. On rapid toggle (5+ times), 5 futures pile up.
**Prevention:** Store the `Timer` from `Future.delayed` and cancel on re-open. Or use `Ticker` instead of `Future.delayed` for animation-driven unmount.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Panel layout redesign | 16:9 vs 50%-area conflict on non-16:9 monitors (Pitfall 10) | Pick 16:9 as primary, cap width by screen height |
| Visual design alignment | BackdropFilter stacking perf cliff (Pitfall 3) | One BackdropFilter per panel, fake thin-glass with translucency |
| Navigation polish — arrow buttons | RepaintBoundary placement + video surface repaint (Pitfall 5) | Per-button RepaintBoundary, AnimatedBuilder not setState |
| Navigation polish — hint fade | Input mode detection unreliable (Pitfall 7) | Last-input-event heuristic, 500ms debounce |
| Auto-pause always | End-of-media / loading state resume race (Pitfall 2) | Widen snapshot to MediaState, only resume if was playing |
| Audio settings tab | EQ live-preview can't be undone (Pitfall 8) | No live-preview, or snapshot engine state for rollback |
| Control bar audio button | Dropdown orphaned on window move (Pitfall 9) | CompositedTransformFollower + resize listener |
| Steam Input LB/RB | Double-fire with raw gamepad bindings (Pitfall 6) | Delete raw gamepad bindings, rely on Steam remapping |
| Keyboard ←/→ conflict | Arrows escape panel focus subtree (Pitfall 1) | Single root Focus onKeyEvent, return handled for all |
| Tab overflow | 7 labels truncate at 400–640px width (Pitfall 4) | isScrollable TabBar or icon-only compact mode |

---

## Cross-Cutting Risks

1. **Scope creep:** v4.5 explicitly defers video/subtitle/playback tabs (PROJECT.md Out of Scope). Don't be tempted to "fill just one real option" in those tabs — stay placeholder. Filling one means testing all.
2. **v4.0 framework churn:** shell.dart is 517 lines (near the 500-line guideline in CLAUDE.md). Adding arrow buttons + input-mode logic + glass overlays risks pushing it past 800. Plan to EXTRACT: `_buildTabBar` → `tab_strip.dart`, `_buildContent` → `tab_content.dart`, `_handleKeyEvent` → `panel_key_bindings.dart`. Do this BEFORE adding v4.5 features, not after.
3. **Tokens centralization:** v4.5 adds many visual values (arrow button radius, hint fade duration, glass-tier overlay blur, panel aspect ratio). All must land in `tokens.dart` — no magic numbers in widget code (per CLAUDE.md "All visual values via Tokens.*").

---

## Sources

- **Live code (HIGH confidence):**
  - `lib/ui/dialogs/settings/settings_overlay_shell.dart` — v4.0 horizontal tab strip, `_handleKeyEvent`, `_onDragUpdate` clamping
  - `lib/ui/dialogs/settings/settings_panel_controller.dart` — `open()`/`close()` `_wasPlaying` snapshot, `pending.register`
  - `lib/ui/player/control_bar.dart` — design north star, single `BackdropFilter` + `RepaintBoundary` + `opacity < 0.01` skip pattern
  - `lib/ui/player/keyboard_handler.dart` — arrowLeft/right seek ±5s bindings
  - `lib/ui/player/right_button_group.dart` — existing subtitle button pattern (file-open, no dropdown)
  - `lib/ui/dialogs/settings/pending_settings.dart` — `commit()`/`cancel()` semantics, pure Dart (not ChangeNotifier)
  - `lib/kernel/services/playback_controller.dart` — `openGeneration` guard (line 34, 200), `SettingsPanelPlayback` thin forwarder (line 197–215)
- **Sibling researchers (HIGH, cross-checked):**
  - Architecture researcher: v4.0 horizontal `_buildTabBar` exists, 88px sidebar (not 200px), `AudioConfig` ISP gap (no `setAudioDelay`/`setBalance`/normalization)
  - Features researcher: mpv.net + IINA top-horizontal-tab strip is reference, Steam Input maps gamepad→keyboard, LB/RB fade-hint is differentiator
- **MEMORY.md (HIGH, prior project context):**
  - `project_multi_monitor_ffi.md` — `display_enumerator` work-area clamp pattern
  - `feedback_layoutbuilder_vs_mediaquery.md` — one size source per widget
  - `project_controlbar_glass_checkpoint.md` — glass blur consistency requirements
- **Project standards (HIGH):**
  - `CLAUDE.md` — `Tokens.*` enforcement, file <500 lines, `RepaintBoundary` for perf, `debugPrint` not `print`, no `!`/`late`/`as`
  - `feedback_comment_while_coding.md` — comments while coding
