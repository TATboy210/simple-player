# Feature Landscape — v4.5 设置面板横向重构 + 音频功能填充

**Project:** Simple Player Flutter (fvp / MDK-FFmpeg)
**Milestone:** v4.5
**Researched:** 2026-07-25
**Mode:** Ecosystem (features dimension)
**Overall confidence:** MEDIUM

> **Confidence note on sourcing.** This environment had no working web search/fetch provider (WebSearch returned training-data fallbacks; WebFetch hit model/classifier denials; Brave API key unset; Exa MCP not registered). Player-comparison claims below are synthesized from the assistant's training knowledge of well-documented mainstream players (VLC, mpv.net, PotPlayer, IINA, MPC-HC, mpv) plus the partial WebSearch fallbacks that confirmed VLC's 4-tab simple layout, mpv.net's audio tab structure, and IINA's 8-tab panel. Treat the matrix as MEDIUM confidence — verify exact tab counts / button placements against live builds before locking pixel-level specs. Codebase-integration claims (current v4.0 state, kernel interfaces) are HIGH confidence, verified from source at `D:\simple_player_flutter\lib\`.

---

## 1. Mainstream Player Comparison Matrix (explicit deliverable)

### 1a. Settings panel layout — tab arrangement

| Player | Tab navigation style | Tab count | Audio tab name | Horizontal strip? | Notes for v4.5 |
|--------|----------------------|-----------|----------------|-------------------|----------------|
| **VLC** | Top horizontal icon+label tabs (Simple view) / left tree (Full/All view) | 4 (Simple: Interface / Audio / Video / Subtitles&OSD) | "Audio" | Yes — top strip, 4 equal-width tabs | Closest analogue to v4.5's "horizontal tab strip in panel center". Simple/All split is a pattern v4.5 does NOT need (too complex for a player overlay). |
| **mpv.net** | Top horizontal tabs (settings window) | ~6 (Player / Video / Audio / Subtitles / Key bindings / Advanced) | "Audio" | Yes — top strip with left/right overflow arrows when narrow | **Strongest reference for v4.5's L/R arrow navigation.** mpv.net shows overflow chevrons exactly like the PROJECT.md spec "tab 两端竖向圆角左右箭头". |
| **PotPlayer** | Left sidebar tree (Preferences dialog) + top sub-tabs inside some panels | Many (~10 categories) | "Audio" (sidebar node) | No — sidebar tree | Counter-example: PotPlayer's density is wrong for an overlay. Confirms v4.5's decision to drop the 200px sidebar. |
| **MPC-HC** | Top horizontal tabs (Options dialog) | ~7 (Player / Playback / DVD / Formats / Player Keys / Logo / Subtitles / Internal Filters / Switcher / Audio Switcher) | "Audio Switcher" (separate from filters) | Yes — top tabs with horizontal scroll | **Reference for audio track switching as its own concern.** MPC-HC splits "Audio Switcher" (track selection prefs) from per-file track picking — v4.5 unifies both into one Audio tab + a control-bar button. |
| **IINA** | Top horizontal tabs (macOS preferences) | 8 (General / UI / Key Bindings / Video / Audio / Subtitle / Network / Advanced) | "Audio" | Yes — top strip, macOS-native segmented style | **Reference for clean audio tab structure.** IINA Audio tab exposes: device, channel layout, volume, audio language preference, pitch correction, audio delay default. Maps 1:1 to v4.5's target audio features (EQ / balance / sync / normalization). |
| **mpv (config)** | No GUI — `mpv.conf` text sections | n/a | `[audio]`-style keys | n/a | Confirms GUI is needed; pure config is anti-pattern for a desktop player. |

**Recommendation:** Model v4.5's horizontal tab strip on **mpv.net + IINA** (top tabs with L/R overflow arrows, clean audio tab grouping). Avoid VLC's Simple/All split and PotPlayer's sidebar tree.

### 1b. Audio settings feature matrix (what each player exposes in its audio settings)

| Feature | VLC | mpv.net | PotPlayer | MPC-HC | IINA | v4.5 target | Kernel hook available? |
|---------|-----|---------|-----------|--------|------|-------------|-----------------------|
| **Equalizer (presets + bands)** | Yes (3-band + gain) | Via `af` filter chain | Yes (10-band graphical) | Yes (5-band) | Via `af` filter | **Yes — EQ/平衡/同步/标准化** | YES — `EqualizerTab` already wired to MDK `af` property (`setEqualizer`); presets already in `equalizer_tab.dart` |
| **Balance (L/R)** | Yes (Audio tab) | Via `af=pan` | Yes | No | Via `af` | Yes | PARTIAL — needs new `af=pan` or stereo-balance filter string; kernel exposes `setProperty('af', ...)` |
| **Audio sync / delay (ms)** | Yes (Audio tab, "Track sync") | Yes (audio-delay) | Yes (Audio tab) | Yes | Yes (Audio tab, default delay) | Yes | PARTIAL — MDK supports `audio-delay` property; need to expose via `MediaEngine` setter |
| **Volume normalization** | Yes ("Replay gain" mode) | Via `af=dynaudnorm`/`compand` | Yes (Normalize filter) | Yes (Normalize) | Via `af` | Yes | PARTIAL — FFmpeg `dynaudnorm`/`loudnorm` filters; wire through `af` chain like EQ presets |
| **Audio device / output module** | Yes (dropdown) | Yes | Yes | Yes | Yes | No (defer) | No — out of v4.5 scope; default device OK |
| **Default audio language preference** | Yes (en,ja,… order) | Yes | Yes | Yes | Yes (Audio tab) | Defer (v4.6+) | `track_preference_service.dart` exists; wire later |
| **Pitch correction (speed change)** | Yes | Via `af=scaletempo` | Yes | Yes | Yes | Defer | Out of v4.5 scope |
| **Audio track list (in-tab)** | No (track switch is in Playback menu) | No (right-click menu) | No (right-click menu) | No (Options > Switcher is prefs only) | No (track switch is in right-click menu) | **Yes — Audio tab lists tracks** | YES — `AudioTab` already lists tracks via `TrackControl.getAudioTracks()` |

**Key insight:** No surveyed player exposes an in-settings-tab audio track switcher — they all use a right-click/context menu or a control-bar dropdown. **v4.5's "Audio tab lists tracks" is itself a mild differentiator**, but the PROJECT.md spec wants it, and the v4.0 `AudioTab` already implements it. The control-bar audio track button (feature 6) is the standard pattern.

### 1c. Control bar audio track button — placement & pattern

| Player | Where is the track switcher? | Icon | Interaction |
|--------|------------------------------|------|-------------|
| **VLC** | Right-click menu ("Audio > Audio Track") or menubar | n/a (menu only) | Submenu checklist |
| **mpv.net** | Right-click menu or a small "Audio" pill in the OSC | headphones / waveform | Dropdown list |
| **PotPlayer** | OSC button (bottom-right, near subtitle + playlist buttons) | headphones or "A" glyph | Popup menu with track list |
| **MPC-HC** | Menubar "Play > Audio" + a control-bar button on some skins | speaker icon | Submenu |
| **IINA** | Right-click menu or a sidebar audio button in OSC | speaker.waveform | Dropdown list |
| **Universal pattern** | Control bar bottom-right region, near subtitle + open-file | headphones / speaker | Popup/dropdown with active track highlighted |

**Recommendation for v4.5 feature 6:** Place the audio track button in the control bar **bottom-right cluster, between the subtitle button (left) and the open-file button (right)**, using the `Icons.headphones` glyph (already used in `AudioTab` section header — reuse for visual consistency). Pattern: `showMenu` / `OverlayEntry` popup listing tracks with the active track marked, mirroring the existing subtitle button's UX exactly. This is the "symmetry with subtitle button" the PROJECT.md spec demands.

### 1d. Horizontal tab strip navigation — arrow + gamepad patterns

| Player | Horizontal arrows? | Gamepad LB/RB tab switch? | Keyboard hint substitution? |
|--------|--------------------|--------------------------|-----------------------------|
| **VLC** | No (all 4 tabs fit) | No (no gamepad support) | No |
| **mpv.net** | Yes — overflow chevrons appear when tabs overflow window width | No (no native gamepad) | No |
| **PotPlayer** | Sidebar tree (no horizontal arrows) | No | No |
| **IINA** | No (macOS native tabs fit) | No (no gamepad) | No |
| **Big Picture / Steam Big Picture players** | Yes — persistent L/R arrows | Yes — LB/RB standard | Yes — shows "RB/LB" glyphs when controller detected, "←/→" when keyboard |
| **Kodi (HTPC)** | Yes — persistent arrows | Yes — LB/RB | Yes — context-aware hint pills |

**Recommendation for v4.5 features 1 + 3:** No mainstream desktop player does gamepad-aware hint substitution well — this is a **legitimate differentiator** for Simple Player (driven by the Steam/SteamOS roadmap). The pattern to follow is Kodi / Big Picture: persistent vertical-rounded L/R arrows at both ends of the tab strip (always visible + clickable + keyboard Left/Right switches tab), with the **hint glyph inside the arrow fading between "RB/LB" (controller) and "←/→" (keyboard)** based on the input-mode signal. Since Steam Input API already maps gamepad to keyboard events (per PROJECT.md constraint), the input-mode signal is a *display concern only* — detect last-input-type via `HardwareKeyboard` vs raw pointer events and cross-fade the hint glyph with `AnimatedSwitcher` / `FadeTransition`.

---

## 2. Table Stakes (for a v4.5 settings panel)

Features users expect from any modern desktop media player's settings panel. Missing = panel feels incomplete or amateur.

| Feature | Why expected | Complexity | v4.5 status / notes |
|---------|--------------|------------|---------------------|
| Horizontal tab navigation | Sidebar tree feels "preferences dialog" not "player overlay"; top tabs are the player-panel norm | Low | **Target (feature 1)** — delete 200px sidebar, add horizontal strip |
| EQ / equalizer presets | Universally present in VLC / PotPlayer / MPC-HC; absence is a regression | Med | **Existing** — `EqualizerTab` already wired; needs visual realignment only |
| Audio track switching from control bar | Every surveyed player has track switching ≤2 clicks away | Med | **Target (feature 6)** — new control-bar button, symmetric to subtitle |
| Auto-pause while settings open | Player keeps running = audio plays under the panel = jarring | Low | **Target (feature 4)** — change `wasPlaying` conditional to always-pause |
| OK / Cancel / Apply (deferred apply) | Standard for settings that touch locale/theme/EQ — instant apply causes rebuild churn | Med | **Existing** — v4.0 framework has it; Audio tab must adopt it for EQ/balance changes |
| Glass / blur visual language consistent with control bar | A player whose settings panel looks like a different app breaks immersion | Med | **Target (feature 2)** — align panel colors/edges to `control_bar.dart` |
| Keyboard navigation (Tab/Arrows/Enter/Escape) | Desktop player users expect full keyboard control | Med | **Existing (v4.0)** — `FocusTraversalGroup` + SpinControl already in place |
| Subtitle delay control | Universally present (VLC/mpv.net/IINA) | Low | Defer to v4.6+ (subtitle tab) per PROJECT.md scope |

## 3. Differentiators (set Simple Player apart)

Features not expected from every player, but valued — and aligned with the project's design language.

| Feature | Value proposition | Complexity | v4.5 fit |
|---------|-------------------|------------|----------|
| **Gamepad-aware hint substitution (RB/LB ↔ ←/→ fade)** | No surveyed desktop player does this. Aligns with Steam/SteamOS roadmap. Makes the panel feel native on a TV/couch setup | Med | **Target (feature 3)** — input-mode signal drives `AnimatedSwitcher` between glyphs |
| **Top/bottom thin-glass arrows over option list** | "透看选项" — options visible through a thin blur layer at top/bottom edges with arrow glow on keyboard up/down | Med | **Target (feature 3)** — unique visual; no surveyed player does this |
| **Audio tab with in-tab track list + deep EQ** | Combines PotPlayer-style deep EQ with VLC-style track list in one place — no player in the matrix does both in one tab | Low (mostly exists) | **Target (feature 5)** — `AudioTab` already lists tracks; merge EQ/balance/sync/normalization |
| **16:9 / 50%-screen overlay (not a fixed dialog)** | Most players use a fixed-size dialog. A 16:9 proportionally-scaled overlay that adapts to screen size feels like part of the player | Med | **Target (feature 1)** — change ratio from 5:4 to 16:9 / 50% area |
| **Edge-glow + 3-state button feedback matching control bar** | Continuity with the OSC — most players' settings panels feel visually disconnected from the player chrome | Med | **Target (feature 2)** |

## 4. Anti-Features (explicitly do NOT build in v4.5)

| Anti-Feature | Why avoid | What to do instead |
|--------------|----------|--------------------|
| Simple/All preferences split (VLC pattern) | Doubles surface area; "All" view is a tree of advanced mpv/FFmpeg flags — too technical for a player overlay | One horizontal tab strip; advanced audio flags exposed via EQ preset strings only |
| Sidebar tree (PotPlayer pattern) | 200px sidebar is exactly what v4.5 removes — too dense, feels like a prefs dialog not a player | Horizontal tabs in panel center |
| Independent window for settings | Breaks overlay architecture; v4.0 overlay shell works | Keep centered overlay (PROJECT.md constraint) |
| Live-apply for EQ / balance / sync | Instant apply of `af` filter chains causes audio glitches on each keystroke; locale/theme instant-apply causes MaterialApp rebuild losing dialog state | Keep deferred-apply (OK/Cancel/Apply); wire Audio tab to the existing pending pattern |
| Audio device / output module picker | Out of v4.5 scope; default device is fine; adding it drags in platform-specific audio backend code | Defer to v4.7+ |
| Per-band graphical EQ (10-band sliders) | FFmpeg `af` EQ is preset-string based in current kernel; a full 10-band UI is a large widget for marginal value | Keep preset-list EQ (already in `EqualizerTab`); add 1-2 more presets if needed |
| Video / subtitle / playback tab feature fill | PROJECT.md explicitly defers these to v4.6+ | Keep `SettingRow` placeholders in those tabs |

## 5. Feature Dependencies

```
Feature 4 (Auto-Pause Always) ── no deps ── can ship first
   │
   └─> unblocks safe development of all other features
        (panel open no longer races playback state)

Feature 1 (Panel Layout Redesign) ── requires ──> Feature 2 (Visual Alignment)
   │                                            (colors/edges follow control bar)
   └─> provides the container Feature 3 + 5 live in

Feature 3 (Navigation Polish: L/R arrows + hint substitution)
   ├─ requires Feature 1 (horizontal strip to attach arrows to)
   └─ requires input-mode signal (detect keyboard vs gamepad last-event)

Feature 5 (Audio Settings Tab: EQ/balance/sync/normalization)
   ├─ requires Feature 1 (a tab to live in — already exists as AudioTab)
   ├─ requires kernel: TrackControl (✓ ready), VolumeControl (✓ ready),
   │   setEqualizer via af (✓ ready), audio-delay setter (MISSING — expose),
   │   normalization af chain (MISSING — wrap as preset like EQ)
   └─ requires deferred-apply (✓ v4.0 framework) for EQ/balance/sync changes

Feature 6 (Control Bar Audio Track Switching)
   ├─ requires kernel: TrackControl.getAudioTracks + switchAudioTrack (✓ ready)
   ├─ requires UI: symmetric to subtitle button (✓ pattern exists in subtitle button)
   └─ independent of Feature 5 (control-bar = quick switch; Audio tab = deep EQ)
       — can ship in parallel with Feature 5
```

**Critical dependency:** Features 2 + 3 + 5 all live *inside* the Feature 1 container. Feature 1 (panel layout redesign) is the gating phase — do it first or the others have nothing to attach to. Feature 4 (auto-pause) is a one-line policy change in `SettingsPanelController` and should ship first to make the rest safe to develop.

## 6. MVP Recommendation (v4.5 phase ordering)

**Phase order (informed by dependencies + the PROJECT.md Active list ordering):**

1. **Feature 4 — Auto-Pause Always** (first, one-line policy change, unblocks safe iteration on the rest)
2. **Feature 1 — Panel Layout Redesign** (gating container; delete sidebar, add horizontal tab strip, 16:9 / 50% area)
3. **Feature 2 — Visual Design Alignment** (apply control-bar glass/edge-glow/3-state to the new container — done immediately after the container exists so every subsequent tab fills the right look)
4. **Feature 3 — Navigation Polish** (L/R arrows + RB/LB hint substitution + top/bottom thin-glass arrows + glow feedback — depends on 1+2)
5. **Feature 5 — Audio Settings Tab** (EQ consolidation + balance + sync + normalization — kernel work + deferred-apply wiring; the heaviest single feature)
6. **Feature 6 — Control Bar Audio Track Switching** (control-bar button symmetric to subtitle — independent of 5, ships last or in parallel with 5)

**Defer to v4.6+:** Video tab feature fill, subtitle tab feature fill, playback preferences tab feature fill, audio device picker, default audio language preference wiring, pitch correction, graphical 10-band EQ.

## 7. Recommendation → Target Feature Mapping (explicit)

| v4.5 Target Feature (from PROJECT.md) | Recommended pattern (from this research) |
|----------------------------------------|------------------------------------------|
| **1. Panel Layout Redesign** | Drop VLC/PotPlayer sidebar/tree; adopt mpv.net + IINA top-horizontal-tab strip. 16:9 / 50% overlay. General tab in middle of sequence per PROJECT.md. |
| **2. Visual Design Alignment** | Pull `control_bar.dart`'s `GlassContainer` + `borderHighlight` + 3-state (rest/hover/press) into panel chrome. Option rows: no border by default, highlight on hover + select only. Tighter padding than v4.0. |
| **3. Navigation & Interaction Polish** | Persistent vertical-rounded L/R arrows at tab-strip ends (mpv.net overflow pattern, made always-on). Gamepad-aware hint substitution via `AnimatedSwitcher` between "RB/LB" and "←/→" glyphs — no surveyed player does this, it's a differentiator. Top/bottom thin-glass arrows over option list with keyboard-up/down glow (unique). |
| **4. Auto-Pause Always** | Change `SettingsPanelController` from `if (wasPlaying) pause` to unconditional pause on open; restore on close only if wasPlaying-before-open was true (so closing doesn't auto-play a paused file). |
| **5. Audio Settings Tab** | Consolidate existing `EqualizerTab` presets into Audio tab; add balance (via `af=pan`), audio sync (via MDK `audio-delay` property — needs kernel expose), volume normalization (via `af=dynaudnorm` preset). All changes go through deferred-apply (OK/Cancel/Apply). IINA Audio tab is the structural reference. |
| **6. Control Bar Audio Track Switching** | Bottom-right cluster, between subtitle (left) and open-file (right). `Icons.headphones` (reused from `AudioTab` header for consistency). `showMenu` / `OverlayEntry` popup listing `TrackControl.getAudioTracks()` with active track highlighted — mirror the existing subtitle button's popup exactly. |

## 8. Codebase integration notes (HIGH confidence — verified from source)

- **`lib/ui/dialogs/settings_panel.dart`** (945 lines) — current v4.0 panel. Has `_selectedIndex`, sidebar nav, deferred apply for locale/theme, `onAudioTrackChanged` callback already threaded through. v4.5 restructure operates here.
- **`lib/ui/dialogs/settings/audio_tab.dart`** — already lists audio tracks via `engine.getAudioTracks()`, calls `engine.switchAudioTrack(i)`, pops the dialog on selection. For v4.5 feature 5, **stop popping on selection** (deferred apply) and merge EQ/balance/sync/normalization controls in.
- **`lib/ui/dialogs/settings/equalizer_tab.dart`** — already wired to MDK `af` property via `MediaEngine.setEqualizer`, 5 presets (Off / BassBoost / VocalBoost / Rock / Classical). For v4.5 feature 5, **either merge this tab into Audio tab or keep as a sub-section of Audio tab** — PROJECT.md says "Audio Settings Tab — EQ / 平衡 / 同步 / 音量标准化", implying EQ moves under Audio.
- **`lib/kernel/engine/track_control.dart`** — `TrackControl` interface ready: `getAudioTracks()`, `switchAudioTrack(int)`, `activeAudioTracks`. Feature 6 needs no kernel work.
- **`lib/kernel/engine/volume_control.dart`** — `VolumeControl` interface ready: `setVolume`, `setMute`, `volume`/`isMuted` ValueNotifiers. Audio tab can bind to these directly.
- **Kernel gaps for feature 5:** (a) `audio-delay` is not currently exposed via a typed setter on `MediaEngine` — needs a thin method or `setProperty('audio-delay', value)` passthrough; (b) volume normalization needs an `af` preset wrapper analogous to `setEqualizer` — call it `setAudioNormalizer(bool enabled)` or fold into `setEqualizer` as an additional preset.
- **Deferred-apply pattern** — already in v4.0 (`_pendingLocale`, `_pendingThemeIndex`, `_originalShortcuts`). Audio tab must adopt the same pending/original-dual pattern for EQ preset index, balance value, sync value, normalization toggle.

## 9. Sources

| Source | Confidence | Used for |
|--------|------------|----------|
| WebSearch built-in fallback response (VLC preferences) | LOW (training-data fallback, not fresh web) | VLC 4-tab Simple layout, Audio tab grouping |
| WebSearch built-in fallback response (mpv.net) | LOW | mpv.net audio tab structure |
| WebSearch built-in fallback response (IINA) | LOW | IINA 8-tab preferences, Audio tab contents |
| Assistant training knowledge (PotPlayer, MPC-HC, Kodi, Big Picture) | MEDIUM | Control-bar button placement, gamepad LB/RB pattern, hint substitution |
| `D:\simple_player_flutter\lib\ui\dialogs\settings_panel.dart` + `settings/*.dart` | HIGH (read from source) | Current v4.0 panel state, existing wiring |
| `D:\simple_player_flutter\lib\kernel\engine\{track_control,volume_control}.dart` | HIGH (read from source) | Kernel interface readiness for features 5 + 6 |
| `.planning/PROJECT.md` | HIGH | 6 target features, scope boundaries, constraints |

**Open questions for phase-specific research later:**
- Exact MDK property name for audio-delay (`audio-delay` vs `--audio-delay`) — verify against fvp/MDK docs before implementing feature 5 sync control.
- Whether MDK's `af` chain accepts `dynaudnorm` / `loudnorm` directly (FFmpeg filter availability inside MDK's linked FFmpeg build) — verify before implementing normalization.
- Steam Input API gamepad→keyboard mapping: does it preserve enough signal for the input-mode detector to distinguish a real keyboard event from a Steam-translated gamepad event? If not, the hint substitution may need a different detection hook (e.g., a Steam Input API side-channel). Verify during feature 3 implementation.
