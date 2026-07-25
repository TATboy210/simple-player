# Architecture Patterns — v4.5 Settings Panel Horizontal Refactor + Audio Fill

**Domain:** Flutter desktop media player (fvp/MDK) settings panel UX overhaul + audio feature fill
**Researched:** 2026-07-25
**Overall confidence:** HIGH (grounded in live code read; one GAP flagged for kernel audio sync/balance)

---

## Recommended Architecture

v4.5 builds on the **v4.0 modular framework already shipped in `lib/ui/dialogs/settings/`** (Phase 23–27: `SettingsOverlayShell` + `SettingsPanelController` + `SettingsPanelState` + `PendingSettingsState`). That framework is the consolidation target — NOT the legacy `lib/ui/dialogs/settings_panel.dart`. The overlay shell already implements ~70% of the v4.5 horizontal-tab target; v4.5 finishes the remaining 30% (end-cap arrows, color unification, ratio change, input-mode hints, always-pause, audio tab fill, control-bar audio button).

```
PlayerScreen (Stack)
├── …video surface / control bar / playlist…
└── SettingsOverlayShell (always-mounted Stack sibling, isOpen-driven)
    ├── Mask (Colors.black54, tap → close)
    └── Center → AnimatedScale + AnimatedOpacity + Transform.translate(dragOffset)
        └── GlassContainer(normal) + RepaintBoundary + FocusTraversalGroup
            └── SizedBox(width, height) Column:
                ├── TitleBar (44px, drag region, close button)       [v4.5: color → controlBar]
                ├── TabBar (horizontal, 64/56px, 7 SettingsNavItem)  [v4.5: + end-cap arrows, color → controlBar, input-mode hints]
                ├── Content (IndexedStack, 7 tabs, TweenAnimationBuilder fade)  [v4.5: AudioTab filled]
                └── ButtonBar (Cancel/Apply/OK, bgGlass)             [v4.5: color → controlBar]
```

### Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|-----------------|-------------------|
| `SettingsPanelController` | open/close/toggle lifecycle, nextTab/prevTab, holds `state` + `pending` | `SettingsPanelPlayback` (kernel boundary), `SettingsOverlayShell` (reads state) |
| `SettingsPanelState` | 3 ValueNotifiers: `isOpen`, `selectedTab`, `dragOffset` | Controller owns; shell + tests read |
| `PendingSettingsState` | Deferred-apply map: register/update/current/commit/cancel | Tabs write via `update`; ButtonBar calls `commit`/`cancel` |
| `SettingsOverlayShell` | Overlay render tree (mask + panel + animations + key handling) | Controller (reads `state`), `PlayerScreen` (mounted as Stack sibling) |
| `SettingsPanelPlayback` (kernel boundary) | `isPlaying` / `pause()` / `play()` only | `PlaybackController` implements; controller depends on this seam, NOT `MediaEngine` |
| `InputModeDetector` (NEW v4.5) | Infers `InputMode { keyboard, gamepad }` from `HardwareKeyboard` events | TabBar end-cap hints, OSD hints subscribe |
| `AudioTab` (v4.5 fill) | EQ / balance / sync / normalization; writes to `pending` | `MediaEngine` (TrackControl + VolumeControl + SubtitleConfig.setEqualizer), `PendingSettingsState` |
| `ControlBar` audio track button (NEW) | Quick popup track switch | `PlayerActions.onOpenAudioTrack`, `TrackControl.getAudioTracks/switchAudioTrack` |

### Data Flow

- **Open panel:** `PlayerActions.onSettings` → `SettingsPanelController.open()` → snapshot `_wasPlaying` → `pause()` (v4.5: always) → `state.isOpen = true` → `SettingsOverlayShell` mounts via `ValueListenableBuilder<bool>` → `FocusTraversalGroup` grabs keyboard scope.
- **Tab switch:** `←/→` or `RB/LB` (already routed in `_handleKeyEvent`) → `controller.nextTab/prevTab` → `state.selectedTab` → `IndexedStack` swaps + `TweenAnimationBuilder` 200ms fade.
- **Edit setting:** Tab widget calls `pending.update('eq', value)` — no immediate engine write. `Apply` → `commitPending()` → service writes (`setEqualizer`, etc.). `OK` → commit + close. `Cancel` → `cancelPending()` (restores originals) + close.
- **Close panel:** `close()` → `state.isOpen = false` → shell runs 200ms exit anim (`IgnorePointer` immediately shields hits) → unmounts → `play()` (resume) → `dragOffset = zero`.

---

## Critical Finding: Two Parallel Panel Implementations (Consolidate First)

**This is the single most important architectural fact for v4.5.** The codebase contains TWO settings panel code paths:

| Path | File | Layout | Size | Pause strategy | Audio tab |
|------|------|--------|------|----------------|-----------|
| **Legacy (old)** | `lib/ui/dialogs/settings_panel.dart` | 88px vertical `_Sidebar` (NOT 200px as PROJECT.md claims) + content + bottom bar | `SizedBox(600, 480)` fixed | none (no controller) | Pops dialog on track switch (`Navigator.pop`) |
| **Framework (v4.0, target)** | `lib/ui/dialogs/settings/settings_overlay_shell.dart` + `settings_panel_controller.dart` + `settings_panel_state.dart` + `pending_settings.dart` | Horizontal `_buildTabBar` (7 equal-width `SettingsNavItem`, 64/56px) + `IndexedStack` content + Cancel/Apply/OK bar | `_panelWidth = windowWidth × panelWidthRatio` clamp [400,600]; height = width × `panelHeightRatio` (5:4 → 600×480) | `wasPlaying` snapshot → conditional pause/resume via `SettingsPanelPlayback` | `AudioTab(pending:)` — keeps panel open |

**PROJECT.md's "200px left sidebar" description is stale** — the actual legacy sidebar is 88px, and the v4.0 framework already moved to a horizontal tab bar. The v4.5 "delete 200px sidebar → horizontal tab" work is **already 70% done** in the overlay shell path.

**Recommendation:**
1. v4.5 Phase 1 should **delete `lib/ui/dialogs/settings_panel.dart`** (the legacy path) and consolidate entirely onto `lib/ui/dialogs/settings/`. Verify no callers remain (grep `SettingsPanel(` — currently `settings_panel.dart` exports `SettingsPanel` widget; `player_screen.dart` uses `SettingsOverlayShell`, so the legacy widget may already be orphaned or only used by tests). This removes ~750 lines of duplicate layout code and eliminates the "which panel?" ambiguity.
2. The `settings/` framework path is the v4.5 refactor substrate. All v4.5 layout work targets `SettingsOverlayShell`.

**Confidence:** HIGH — verified by reading both files end-to-end.

---

## Patterns to Follow

### Pattern 1: Overlay Shell as Stack Sibling (NOT showDialog)
**What:** `SettingsOverlayShell` is mounted inside `PlayerScreen`'s content `Stack` as a sibling to the video surface / control bar, driven by `ValueListenableBuilder<bool>` on `state.isOpen`. It is NOT a `showDialog`/`Navigator.push` modal.
**When:** Always for settings panel — the panel must coexist with the player tree (for drag, for control-bar color sampling, for not losing player state).
**Why:** `showDialog` creates a new route that rebuilds `MaterialApp` on locale/theme change, losing dialog state (the exact bug v4.0's deferred-apply fixed). Stack-sibling mount keeps the panel inside the player tree.
**Example:** see `player_screen.dart:303` — `SettingsOverlayShell(controller: …)`.

### Pattern 2: Service-Seam Pause Boundary (`SettingsPanelPlayback`)
**What:** `SettingsPanelController` does NOT depend on `MediaEngine`/`PlaybackController` directly. It depends on the narrow `SettingsPanelPlayback` interface (`isPlaying` / `pause` / `play`) declared in `playback_controller.dart:37`.
**When:** Anytime UI-side lifecycle needs to pause/resume playback.
**Why:** Avoids racing the `openGeneration` open guard in `PlaybackController` (the controller coordinates track advancement; a direct `MediaEngine.pause` call from UI would bypass its state machine). The seam keeps the boundary surgical.
**Code:**
```dart
abstract interface class SettingsPanelPlayback {
  bool get isPlaying;
  void pause();
  void play();
}
```

### Pattern 3: Deferred-Apply via `PendingSettingsState` (Pure Data)
**What:** Tabs write user edits into `PendingSettingsState.update(key, value)` — a plain Dart class (NOT `ValueNotifier`/`ChangeNotifier`) holding `_pending` + `_originals` maps. `Apply` calls `commit()` (writes to originals, clears pending, returns diff). `Cancel` calls `cancel()` (clears pending, returns originals).
**When:** Any setting whose live mutation would rebuild `MaterialApp` (locale, theme) or cause engine reconfiguration mid-playback (EQ, balance, normalization). All audio tab settings qualify.
**Why:** Pure-data container avoids `IndexedStack`-level cascade rebuilds; the tab widget calls `setState` locally after `update` to refresh its own row.

### Pattern 4: `IndexedStack` + `TweenAnimationBuilder` Tab Persistence
**What:** Content area is `IndexedStack(index: selectedTab, children: [7 tabs])`. Each tab is wrapped in `TweenAnimationBuilder<double>` that fades opacity 0→1 on selection.
**When:** All 7 tabs — they stay mounted (state preserved) and only fade.
**Why:** `IndexedStack` keeps tab subtrees alive (scroll position, form state) across tab switches; the fade gives the v4.5 "渐入渐出" requirement for free.

### Pattern 5: `FocusTraversalGroup` + `onKeyEvent` Self-Scoped Keyboard
**What:** `_buildPanel` wraps the panel in `FocusTraversalGroup` + `Focus(autofocus: true, onKeyEvent: _handleKeyEvent)`. `_handleKeyEvent` returns `KeyEventResult.handled` for ESC/B/←/→/LB/RB, preventing bubble to `KeyboardHandler` (which would seek ±5s).
**When:** Any overlay that needs its own keymap.
**Why:** Keeps the panel's 20+ key shortcuts localized; the player's `KeyboardHandler` stays clean.

### Pattern 6: `RepaintBoundary` Isolation
**What:** Panel root is `RepaintBoundary`-wrapped; `_buildBlur` skips `BackdropFilter` when `opacity.value < 0.01` (exit anim tail) to avoid GPU readback stalls.
**When:** Any glass panel mounted over a video surface.
**Why:** Prevents the panel's per-frame repaint from cascading into the video texture layer.

---

## v4.5 Migration Map (Layout → Code)

| v4.5 Target | Current State in `settings/` framework | v4.5 Work |
|-------------|----------------------------------------|-----------|
| Delete 200px left sidebar → horizontal tab strip in panel middle | Horizontal `_buildTabBar` ALREADY EXISTS (7 `SettingsNavItem`, 64/56px, `bgGlass` back) | No structural change — only visual polish (color, end-cap arrows). Legacy `settings_panel.dart` to delete. |
| 16:9 / ~50% screen area | 5:4 ratio (`panelWidthRatio` × clamp [400,600], height = width × `panelHeightRatio` → 600×480) | Add tokens: `panelAreaRatio = 0.5` (50% screen area), `panelAspect = 16/9`. Compute width from area, height from aspect. Update `_panelWidth`/`_panelHeight`. |
| General tab to middle position | Tab order: General(0), EQ(1), Audio(2), Video(3), Shortcuts(4), About(5), Performance(6) | Reorder `_tabIcons`/`_tabLabels` so General sits mid-sequence. Decide canonical order (e.g., Audio, EQ, General, Video, Shortcuts, Performance, About). |
| Color unification to control bar color | Panel uses `Tokens.bgGlass` (title bar, tab bar, button bar) | Swap to `Tokens.controlBarBg` + `controlBarBorderWhite` + `glowOuterRing` (4-shadow decoration from `ControlBar._decorationPlaying`). Extract a shared `ControlBarDecoration` token/widget. |
| End-cap rounded L/R arrow buttons | Tab bar is a bare `Row` of 7 `Expanded` items, no end caps | Wrap tab `Row` in a `Row` with two `TabArrowButton`s (rounded, persistent, `onTap → prevTab/nextTab`). They overlay the tab strip edges. |
| Input-mode-aware hint substitution (RB/LB ↔ ←/→) | Key handling already routes both; NO visual hint swap, NO input-mode detector | NEW `InputModeDetector` (ValueNotifier<InputMode>) listening to `HardwareKeyboard`. End-cap arrows + tab hints subscribe and swap label/icon. |
| Auto-pause always (open = pause, close = resume) | `wasPlaying` snapshot → conditional pause; `close` resumes only if `wasPlaying` | Change `open()`: always `pause()` (drop the `if (_wasPlaying)` guard). **Keep `_wasPlaying` for the `close()` resume decision** (see Pitfall 1). Boundary `SettingsPanelPlayback` unchanged. |
| Audio tab fill (EQ / balance / sync / normalization) | `AudioTab` only does track switching (reads `getAudioTracks`, calls `switchAudioTrack`) | Extend `AudioTab`: EQ rows (reuse `SubtitleConfig.setEqualizer`), balance (GAP — needs new kernel method or `AudioConfig` ISP), sync delay (GAP — pattern from `SubtitleConfig.setSubtitleDelay` but needs `setAudioDelay`), normalization (via EQ string or new method). |
| Control bar audio track button (symmetric with subtitle) | `RightButtonGroup` has openFile / openSubtitle / playlist / settings / fullscreen | Add `PlayerActions.onOpenAudioTrack`. Add `GlassButton.iconOnly(icon: Icons.audiotrack)` adjacent to subtitle button. Popup pattern mirrors subtitle (showMenu/OverlayEntry with track list). |

---

## Kernel Interface Touch Points (Audio Tab)

The v3.0 ISP decomposition gives the audio tab these surfaces via `MediaEngine`:

| Feature | ISP Interface | Method/Member | Status |
|---------|---------------|---------------|--------|
| Track list | `TrackControl` | `getAudioTracks()` → `List<AudioTrackInfo>` | Available, used by current `AudioTab` |
| Track switch | `TrackControl` | `switchAudioTrack(int trackId)` | Available |
| Active tracks | `TrackControl` | `activeAudioTracks` getter | Available |
| Volume | `VolumeControl` | `volume` ValueNotifier<double> + `setVolume(double)` | Available |
| Mute | `VolumeControl` | `isMuted` ValueNotifier<bool> + `setMute(bool)` | Available |
| EQ preset | `SubtitleConfig` | `setEqualizer(String preset)` (af filter syntax) | Available, used by `EqualizerTab` |
| **Audio sync delay** | — | — | **GAP.** `SubtitleConfig` has `setSubtitleDelay(int)` / `subtitleDelay` getter. NO audio equivalent exists. MDK/FFmpeg supports audio delay. Needs new `setAudioDelay(int)` method — either add to `SubtitleConfig` (misnamed) or create a new `AudioConfig` ISP. **Recommend: new `AudioConfig` ISP** (clean separation, mirrors `SubtitleConfig`). |
| **L/R balance** | — | — | **GAP.** No kernel interface. Needs `setBalance(double)` (-1.0 L … +1.0 R) on the new `AudioConfig` ISP, delegating to an af filter in `FvpEngine`. |
| **Volume normalization** | — | — | **Partial.** Can be approximated via `setEqualizer` with a compressor filter string, but a dedicated `setNormalize(bool)` / `setNormalizeTarget(double)` is cleaner. Add to `AudioConfig` ISP. |

**Architectural recommendation:** Introduce a new `AudioConfig` ISP interface (mirrors `SubtitleConfig`'s shape) holding `setEqualizer` (move from `SubtitleConfig` for cohesion, or duplicate), `setAudioDelay(int)` / `audioDelay` getter, `setBalance(double)` / `balance` getter, `setNormalize(bool)` / `normalizeEnabled` getter. `FvpEngine implements AudioConfig`. `MediaEngine` composite type adds `AudioConfig` to its `implements` list. This is a small, additive kernel change — no regression risk to v3.0 contracts (Phase 15 baseline). Flag for phase-specific research in the Audio Tab phase.

---

## Control Bar Audio Track Button — Placement & Symmetry

**Where:** `lib/ui/player/right_button_group.dart` — the right cluster of `ControlBar._buildButtonRow`. Current order: `openFile` → `openSubtitle` → `togglePlaylist` → `settings` → `toggleFullscreen`.

**Symmetry target:** the audio track button mirrors the subtitle button (`onOpenSubtitle`, `Icons.subtitles`). Recommended insertion **immediately before** `onOpenSubtitle` (left of it) so the pair reads "audio | subtitle" — both media-track selectors grouped together, distinct from file/playlist/settings.

**Callback:** add `final VoidCallback? onOpenAudioTrack;` to `PlayerActions` (mirrors `onOpenSubtitle`). Wire in `PlayerScreen.build()` to a handler that opens a popup.

**Popup pattern:** the subtitle button currently opens a popup (the codebase uses both `showMenu` and `OverlayEntry` patterns — see `right_click_quick_menu` memory). For the audio track button, use the SAME popup primitive the subtitle button uses, to keep the two track-selectors visually identical. The popup lists `engine.getAudioTracks()` with active marker, tap → `engine.switchAudioTrack(i)` + `onAudioTrackChanged?.call(i)` (the existing `SettingsPanel.onAudioTrackChanged` callback records preference). Popup does NOT close any panel (unlike the legacy `AudioTab` which called `Navigator.pop`).

**GlassButton three-state:** reuse `GlassButton.iconOnly` (already used by all right-group buttons) — it has the control-bar three-state (default/hover/press) the v4.5 design north star requires. No new widget needed for the button itself.

**Conditional visibility:** show the audio track button only when `engine.getAudioTracks().length > 1` (mirrors how subtitle button should behave). Add a `ValueListenableBuilder` on a track-count notifier, OR compute in `PlayerScreen.build()` and pass via `PlayerActions` (simpler, less reactive — acceptable since track list only changes on file open).

---

## Auto-Pause Strategy Change — Architectural Impact

**Current (`SettingsPanelController.open`):**
```dart
_wasPlaying = _playback.isPlaying;   // snapshot BEFORE pause
if (_wasPlaying) _playback.pause();   // conditional pause
state.isOpen.value = true;
```
**Current (`close`):**
```dart
state.isOpen.value = false;
if (_wasPlaying) _playback.play();   // resume only if was playing
```

**v4.5 target ("open = pause always, close = resume"):** two valid readings.

**Reading A (literal):** `open()` always pauses; `close()` always resumes. **Pitfall:** this resumes a user who had *manually paused* before opening the panel — surprising, breaks the "I paused it, leave it paused" contract. The `SettingsPanelPlayback.play()` call would un-pause them.

**Reading B (recommended):** `open()` always pauses (drop the `if (_wasPlaying)` guard on the pause side); `close()` resumes only if `_wasPlaying` was true (i.e., the user was playing before the panel-induced pause). `_wasPlaying` field is retained but its semantics shift from "should I pause?" to "should I resume?".

**Recommendation: Reading B.** It matches the PROJECT.md intent ("面板开启即暂停，关闭恢复") without the un-pause surprise. The change is a 1-line edit in `open()` (delete the `if` guard around `pause()`) and zero changes in `close()`.

**Boundary impact:** `SettingsPanelPlayback` interface (`isPlaying`/`pause`/`play`) — UNCHANGED. `PlaybackController` implementation — UNCHANGED. Blast radius: `SettingsPanelController.open()` body only. Tests: update the existing `wasPlaying`-conditional test to assert always-pause; add a case for "user paused → open → close → still paused".

**Confidence:** HIGH.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Reviving `showDialog` for the Panel
**What:** Using `showDialog(...)` / `Navigator.push` to mount the settings panel.
**Why bad:** Rebuilds `MaterialApp` on locale/theme change, losing panel state + deferred-apply map. This is the exact bug v4.0 fixed.
**Instead:** Keep the `SettingsOverlayShell` as a `PlayerScreen` Stack sibling driven by `state.isOpen`.

### Anti-Pattern 2: Calling `MediaEngine` Directly from `SettingsPanelController`
**What:** Having the controller import `MediaEngine` and call `pause()`/`play()` on the engine.
**Why bad:** Races the `openGeneration` open guard in `PlaybackController`; bypasses the state machine; couples UI lifecycle to engine internals.
**Instead:** Depend only on `SettingsPanelPlayback` (the narrow seam). Already the case — preserve it.

### Anti-Pattern 3: Making `PendingSettingsState` a `ChangeNotifier`
**What:** Refactoring `PendingSettingsState` to extend `ChangeNotifier` and have tabs subscribe.
**Why bad:** `IndexedStack` keeps all 7 tab subtrees mounted; a notifier would cascade-rebuild every tab on any single edit. Performance regression + rebuild loops.
**Instead:** Keep it pure-Dart; tabs call `setState` locally after `update`.

### Anti-Pattern 4: Direct `setEqualizer`/`setBalance` Writes from Tab Widgets
**What:** Tab row widgets calling `engine.setEqualizer(...)` immediately on user edit.
**Why bad:** Breaks deferred-apply (OK/Apply/Cancel) contract; live EQ reconfiguration mid-playback can cause audio glitches; Cancel cannot undo.
**Instead:** Tab writes to `pending.update('eq', preset)`. `Apply`/`OK` → `commitPending()` → service layer writes to engine.

### Anti-Pattern 5: Hardcoding Audio Delay in `SubtitleConfig`
**What:** Adding `setAudioDelay` to `SubtitleConfig` because "it's already the delay interface."
**Why bad:** Violates ISP — `SubtitleConfig` is named for subtitles; audio delay on it misleads callers and future maintainers.
**Instead:** Create a new `AudioConfig` ISP for audio-specific controls (delay, balance, normalization).

### Anti-Pattern 6: A Second `InputModeDetector` per Widget
**What:** Each tab/end-cap arrow rolling its own gamepad-vs-keyboard detection.
**Why bad:** Duplicated state, drift, inconsistent hints.
**Instead:** One `InputModeDetector` singleton (or `ValueListenable<InputMode>`) at the panel root; all hints subscribe.

---

## Scalability Considerations

| Concern | 100 tracks | 10K tracks | 1M tracks |
|---------|------------|------------|-----------|
| Track list popup rendering | `ListView` fine | `ListView.builder` (lazy) | Page + search filter (unlikely in media player) |
| Tab count | 7 fixed tabs, `IndexedStack` keeps all alive — fine | 7 is the design ceiling; beyond 12 tabs the horizontal strip overflows | N/A — cap at 7–9; use sub-tabs if more |
| Deferred-apply map size | <20 keys — `Map` fine | <200 keys — still fine | N/A — settings are bounded |
| `RepaintBoundary` isolation | One panel — fine | One panel — fine | N/A |

The panel is a single-instance overlay; the real scalability axis is **track list size**, solved by `ListView.builder` in the popup (and in `AudioTab` if it ever lists tracks inline). v4.5 should use `ListView.builder` from the start for the control-bar audio popup even if current files have <10 tracks.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Legacy panel deletion | Hidden caller of `SettingsPanel` widget (test or feature) | `grep -r "SettingsPanel(" lib/ test/` first; migrate any caller to `SettingsOverlayShell`; delete in a separate commit |
| Ratio change 5:4 → 16:9 / 50% area | Existing tests assert `600×480` panel size (shell `panelKey` sizing) | Update `_panelWidth`/`_panelHeight` + tokens; rewrite size-assertion tests; add golden re-baseline |
| Color unification to control bar | `Tokens.bgGlass` is used in MANY places (title bar, tab bar, button bar, dialog backgrounds) — blanket swap leaks outside the panel | Scope the swap to `SettingsOverlayShell` only (local constants or a `PanelDecoration` wrapper), NOT global `Tokens` |
| Always-pause change | Reading A (literal always-resume) un-pauses a user who paused manually — UX regression | Use Reading B: always pause on open, resume on close only if `_wasPlaying` was true |
| Audio tab — audio sync delay | No kernel `setAudioDelay` exists | Add `AudioConfig` ISP + `FvpEngine` impl; defer to phase-specific research if af filter syntax for audio delay is unclear |
| Audio tab — balance | No kernel `setBalance` exists | Same — `AudioConfig.setBalance(double)`; verify MDK `af=pan` or `balance` filter support in FvpEngine |
| Control bar audio button popup | Popup pattern drift between subtitle and audio popups (different primitives, different animation) | Extract a shared `TrackPopupMenu` widget used by both subtitle and audio buttons |
| Input-mode hints | `HardwareKeyboard` events fire on every key; a naive detector re-flips on modifier keys | Debounce: only flip to `gamepad` on `gameButton*` keys, flip back to `keyboard` on any non-game `LogicalKeyboardKey`; hold state in a `ValueNotifier` |

---

## Confidence Assessment

| Area | Confidence | Reason |
|------|------------|--------|
| Two-panel consolidation finding | HIGH | Read both files end-to-end; verified `player_screen.dart:303` uses `SettingsOverlayShell` |
| Horizontal tab strip already shipped | HIGH | `_buildTabBar` in `settings_overlay_shell.dart:253` confirmed |
| Auto-pause change blast radius | HIGH | `SettingsPanelPlayback` seam read; only `open()` body changes |
| Audio tab EQ surface | HIGH | `SubtitleConfig.setEqualizer` confirmed (used by `EqualizerTab`) |
| Audio tab sync delay / balance / normalization | MEDIUM | Confirmed GAP in kernel; `AudioConfig` ISP recommendation is sound but MDK af-filter support for audio delay/balance needs phase-specific verification in `FvpEngine` |
| Control bar audio button placement | HIGH | `RightButtonGroup` + `PlayerActions` read; symmetry with subtitle button is mechanical |
| Input-mode detector | MEDIUM | No existing component; `HardwareKeyboard` API is stable but the debounce/hysteresis policy needs validation |

---

## Gaps to Address (Phase-Specific Research)

1. **Audio delay kernel surface** — does `FvpEngine` (MDK SDK) expose audio delay natively, or must it be an `af=adelay` filter string? Read `fvp_engine.dart` + MDK docs in the Audio Tab phase. (Memory note: `reference_fvp_performance_bottlenecks` and `fvp_plugin.cpp` 193-line analysis exist.)
2. **Balance kernel surface** — MDK `af=pan`/`balance` filter support. Same phase.
3. **Volume normalization** — MDK `af=acompressor`/`dynaudnorm` filter support, or native MDK property. Same phase.
4. **Subtitle button popup primitive** — read `right_click_quick_menu` memory + subtitle button handler in `PlayerScreen` to confirm whether `showMenu` or `OverlayEntry` is the established pattern; extract shared `TrackPopupMenu`.
5. **Legacy `settings_panel.dart` callers** — `grep` before deletion to confirm zero production callers (tests may need migration).
6. **Input-mode detection policy** — review `HardwareKeyboard` + Flutter's `DefaultPlatform`/`HardwareKeyboard.deviceType` (if exposed) for a cleaner signal than key-event inference.

---

## Sources

- `D:\simple_player_flutter\.planning\PROJECT.md` — v4.5 target features, validated/active requirements, key decisions (HIGH)
- `D:\simple_player_flutter\lib\ui\dialogs\settings_panel.dart` — legacy 88px-sidebar panel (HIGH, read end-to-end)
- `D:\simple_player_flutter\lib\ui\dialogs\settings\settings_overlay_shell.dart` — v4.0 horizontal-tab framework (HIGH, read end-to-end)
- `D:\simple_player_flutter\lib\ui\dialogs\settings\settings_panel_controller.dart` — open/close/toggle + wasPlaying pause/resume (HIGH)
- `D:\simple_player_flutter\lib\ui\dialogs\settings\settings_panel_state.dart` — 3 ValueNotifiers (HIGH)
- `D:\simple_player_flutter\lib\ui\dialogs\settings\pending_settings.dart` — deferred-apply pure-data container (HIGH)
- `D:\simple_player_flutter\lib\kernel\engine\media_engine.dart` — composite ISP interface (HIGH)
- `D:\simple_player_flutter\lib\kernel\engine\track_control.dart` — audio track list/switch (HIGH)
- `D:\simple_player_flutter\lib\kernel\engine\volume_control.dart` — volume/mute (HIGH)
- `D:\simple_player_flutter\lib\kernel\engine\subtitle_config.dart` — subtitle delay + EQ preset (reusable pattern) (HIGH)
- `D:\simple_player_flutter\lib\kernel\services\playback_controller.dart:37` — `SettingsPanelPlayback` seam (HIGH)
- `D:\simple_player_flutter\lib\ui\player\control_bar.dart` — design north star, 4-shadow decoration, `controlBarBg` tokens (HIGH)
- `D:\simple_player_flutter\lib\ui\player\right_button_group.dart` — audio button insertion point (HIGH)
- `D:\simple_player_flutter\lib\ui\player\player_actions.dart` — `PlayerActions` callback bag, `onOpenSubtitle` symmetry model (HIGH)
- `D:\simple_player_flutter\lib\ui\dialogs\settings\audio_tab.dart` — current track-list tab (legacy, pops dialog) (HIGH)
- `D:\simple_player_flutter\lib\ui\shared\settings_card.dart` — `SettingRow` + `SettingSwitchRow` + `SettingSpinRow` (HIGH)
