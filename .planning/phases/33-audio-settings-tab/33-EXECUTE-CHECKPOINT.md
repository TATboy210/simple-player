---
phase: 33-audio-settings-tab
attempts: 1
created: 2026-07-30
halt_reason: context_budget_67pct
step_at_halt: pre-implementation (zero lib/ changes; 2 user decisions locked, source exploration done)
mode: interactive-inline
runtime_gate: user-runs-on-target-windows
---

# Phase 33 Execute Checkpoint

> Lean resume artifact. Read THIS + the 3 PLAN files only (skip STATE full history to save ~10K).
> Prior session's worktree-isolation attempt failed (lost .git); this session chose **no isolation, main worktree, interactive inline**.

## User decisions locked (AskUserQuestion, 2026-07-30)

1. **Runtime gate = "我在 Windows 真机跑"**: Implement ALL code + headless tests first. Then user runs
   `audio_filter_runtime_smoke_test.dart` on target Windows with a media file (with audio track) and reports
   whether `pan` / `adelay` / `dynaudnorm` each apply or throw. Phase completes ONLY if all 3 apply.
   Any unavailable → find equivalent supported route, implement, target-Windows test before completing
   (plan policy: **no partial omission**). Headless env cannot produce this evidence (mdk.dll FFI load
   failures — see memory `reference_mdk_dll_headless_test_failures.md`).
2. **Execution mode = "Interactive inline"**: Main session executes 3 plans sequentially with task checkpoints.
   No subagent spawn (Phase 28 precedent: 3 spawn halts → interactive inline succeeded). No worktree isolation
   (3 plans are strictly sequential wave1→2→3, each depends_on previous — zero parallelism benefit).

## Resume procedure (fresh 200K window)

1. `/clear` → continue Phase 33 execution (read this checkpoint + 33-01/02/03-PLAN.md).
2. Execute **33-01** inline, TDD:
   - Task 1: create `test/ui/dialogs/settings/audio_filter_runtime_smoke_test.dart` (target-Windows, do NOT run headless)
     + immutable `AudioFilterAvailability` result type owned by PlayerFeature composition root + composition seam.
   - Task 2: `AudioSettings` value object + `AudioFilterCompositor` (5 presets, EQ→balance→delay→normalization order,
     accepts availability result, omits unavailable segment + debugPrint warning) + `SettingsStore` 4 namespaced audio
     keys + `SettingsValidator` bounds + `SettingsPanelController` `AudioCommitCallback` seam + `PlayerFeature`
     registration + `EqualizerTab` deferred selector + 3 headless test files.
   - Run focused headless tests (must pass) + `flutter analyze` (must exit 0). Commit atomically. Write `33-01-SUMMARY.md`.
3. Execute **33-02** (balance + sync sliders + pan/adelay composition) → tests + commit + SUMMARY.
4. Execute **33-03** (normalization + full-chain + `flutter test --coverage` + genhtml + analyze) → commit + SUMMARY.
5. **Runtime gate**: hand user the smoke-test command + media guidance. Wait for target-Windows result.
6. All 3 filters apply → `gsd-verifier` + phase completion. Any unavailable → equivalent-route plan before completion.
7. Delete this checkpoint file after phase completion (one-shot artifact, Phase 28/30/32 precedent).

## Key source findings (do NOT re-explore — verbatim signatures)

### `setEqualizer` route (existing, no interface change needed)
- `FvpEngine.setEqualizer(String afFilter)` → `_guardedAction('setEqualizer', () => _subtitleConfigurator.setEqualizer(afFilter))`
- `SubtitleConfigurator.setEqualizer(String afFilter)` → `_player.setProperty('af', afFilter)`
- `KernelAdapter.setEqualizer(String preset)` → `_targetFor('setEqualizer').setEqualizer(preset)` (per-method routing)
- `MediaEngine` interface declares `setEqualizer` (KernelAdapter @override confirms). **PlayerFeature calls
  `engine.setEqualizer(composedString)` — the existing entry. Add NOTHING to MediaEngine/SubtitleConfig/FvpEngine.**
- Legacy root-level `lib/ui/dialogs/settings/equalizer_tab.dart` (NOT `tabs/`) uses `SubtitleConfig.setEqualizer` —
  NOT rendered, MUST remain untouched (plan Q3).

### `PendingSettingsState` (lib/ui/dialogs/settings/pending_settings.dart) — pure Dart, no notifier
- `void register(String key, dynamic originalValue)` — set original snapshot (panel open).
- `void update(String key, dynamic value)` — record user edit.
- `dynamic current(String key) => _pending[key] ?? _originals[key]` — display value.
- `Map<String,dynamic> commit()` — returns changes, clears _pending, writes _originals (Apply-then-Cancel baseline).
- `Map<String,dynamic> cancel()` — returns originals, clears _pending.
- `bool get hasChanges`, `void dispose()`.

### `SettingsPanelController` (lib/ui/dialogs/settings/settings_panel_controller.dart)
- Ctor: `SettingsPanelController(this._playback)` — `_playback: SettingsPanelPlayback` (pause()/play()/isPlaying).
- Fields: `state: SettingsPanelState`, `pending: PendingSettingsState`.
- `open()`: sets `state.selectedTab.value = defaultTabIndex` (3), snapshots `_preOpenState`, `_playback.pause()`,
  registers 'locale'/'themeIndex' via `pending.register(...)`, sets `state.isOpen.value = true`.
  **→ Add audio registration here: `eqPresetIndex`(0), `balance`(0.0), `syncMs`(0), `normalization`(false)
  from SettingsStore loaded/raw defaults.**
- `commitPending() => pending.commit()` — returns changes Map. **→ After commit, build AudioSettings snapshot
  from committed-or-current values, invoke `AudioCommitCallback` exactly once per Apply/OK.**
- `cancelPending() => pending.cancel()`. `close()` restores play if was playing, `pending.dispose()`.
- `static const int tabCount = 7`, `defaultTabIndex = 3`.

### Tab structure (lib/ui/dialogs/settings/tab_content.dart)
- 7-child explicit IndexedStack, order: **[EQ(0), Audio(1), Video(2), General(3), Shortcuts(4), About(5), Performance(6)]**.
- `tab_content.dart` imports `tabs/equalizer_tab.dart` — Phase 33 replaces THIS skeleton (80 lines).
- `tabs/audio_tab.dart` (index 1) is the SECOND AudioTab — MUST remain untouched (scope boundary, 33-03 Test 5).

### `SettingsStore` (lib/kernel/persistence/settings_store.dart) — static, exception-logging + safe defaults
- Pattern (from `loadTrackPreferences`/`saveTrackPreferences` via TrackPreferenceService): `try { ... } on Exception catch (e) { _log.e('...failed: $e'); return safeDefault; }`.
- Existing `_key*` constants (e.g. `_keySubtitleTrackIndex`, `_keySubtitleDelay`). **→ Add `_keyAudioEqPreset='audioEqPreset'`,
  `_keyAudioBalance='audioBalance'`, `_keyAudioSyncMs='audioSyncMs'`, `_keyAudioNormalization='audioNormalization'` +
  typed load/save methods with defaults `0`, `0.0`, `0`, `false`.**
- `SettingsValidator` (lib/kernel/persistence/settings_validator.dart): **→ Add `audioEqPreset` (0..4),
  `audioBalance` (-1.0..1.0), `audioSyncMs` (0..10000) bounds.**

### EQ preset table (fixed, in-code — compositor must use exactly these in index order)
- index 0: `''` (empty), 1: `bass=g=10`, 2: `treble=g=5`, 3: `bass=g=8,treble=g=6`, 4: `bass=g=3,treble=g=4`
- Canonical chain order: **EQ → balance(pan) → delay(adelay) → normalization(dynaudnorm)**.

### Filter strings (exact — from RESEARCH.md + plans)
- pan (balance): `pan=stereo|c0=${leftGain.toStringAsFixed(2)}*c0|c1=${rightGain.toStringAsFixed(2)}*c1`;
  `leftGain=clamp(1.0-balance,0,1)`, `rightGain=clamp(1.0+balance,0,1)`; omit segment at balance==0.0.
- adelay (sync): `adelay=<ms>|<ms>`; ms is the validated direct nonnegative value (NO `abs()`); omit at 0.
  Delay-only range 0..10000 (FFmpeg adelay cannot advance audio → positive always means "later").
- dynaudnorm (normalization): `dynaudnorm=f=500:g=15:p=0.95`; omit when false.
- Full representative chain (rock, balance 0.3, sync 200, norm on):
  `bass=g=8,treble=g=6,pan=stereo|c0=0.70*c0|c1=1.00*c1,adelay=200|200,dynaudnorm=f=500:g=15:p=0.95`

### Commit seam (plan Q2 = Option A)
- Inject typed `AudioCommitCallback?` into `SettingsPanelController`. `PlayerFeature` registers it at the manual
  composition root. On `commitPending()`, controller builds `AudioSettings` snapshot from committed-or-current
  values, invokes callback exactly once per Apply/OK. Callback (PlayerFeature): compose via `_buildAfString`
  (accepts availability result) → `engine.setEqualizer(composed)` once → sequential `saveAudio*` of 4 raw values.
  `unawaited` only if existing button-bar requires void callback; logged recoverable errors, never swallowed.

## Test files to create (headless, fakes-based, NO mdk.dll)
- `test/kernel/audio/audio_filter_compositor_test.dart` — deterministic composition (presets, pan edges, adelay bounds, chain order, normalization, availability omission).
- `test/kernel/persistence/settings_store_audio_test.dart` — 4 keys round-trip + clamp bounds.
- `test/ui/dialogs/settings/audio_tab_test.dart` — deferred-apply: pending updates, Apply/OK one call, Cancel zero calls.
- `test/ui/dialogs/settings/audio_filter_runtime_smoke_test.dart` — TARGET-WINDOWS ONLY (loads media, probes pan/adelay/dynaudnorm via real engine). Do NOT run headless.

## Existing tests to follow as patterns
- `test/kernel/persistence/settings_store_test.dart`, `test/ui/dialogs/settings_panel_controller_test.dart`,
  `test/ui/dialogs/settings_overlay_shell_test.dart`. 7-child IndexedStack contract asserted in `settings_tab_content_test.dart` + `settings_overlay_shell_test.dart`.

## Operational state
- Branch: `feat/v1.8-stability-polish-plan-02-02`, HEAD `291c2187`.
- Working tree: `M .planning/STATE.md` (prior session's phase 32→33 transition + this checkpoint note) + `?? .planning/phases/32-navigation-interaction-polish/32-VERIFICATION.md` (Phase 32 artifact, unrelated, leave).
- **Zero lib/ changes** — Phase 33 implementation has NOT started.
- Flutter: `D:/flutter/bin/flutter` (not in PATH, use full path). `--concurrency=1` for focused audio tests.
- Media fixture: `test/fixtures/tiny_valid.mp4` exists but may lack audio track — user may need own media for smoke.
- **3 stale orphan worktrees** under `.claude/worktrees/agent-*` (Phase 22/23 era, dirty generated plugin-registrant files). Not blocking (main-worktree execution). Optional cleanup: `git worktree remove --force` each after confirming no unique source work.
- Pre-existing test failures (NOT regressions): `fvp_engine_contract_test.dart` ~57 mdk.dll FFI load failures (headless); settings_nav_item_test (Phase 25); settings_tab_content_test DropdownButton (GeneralTab headless). Judge by module boundary.

## Context-budget rationale (why paused at 67%)
- 33% remaining insufficient for even 33-01's full TDD cycle (write 3 test files RED → implement ~7 files → run tests
  → iterate → analyze → commit → SUMMARY). Starting would halt mid-TDD leaving half-written files — strictly worse
  than clean checkpoint (asymmetric risk, validated ~10× in STATE history). User's memory
  `feedback_gsd_context_budget_pause` hard-constrains 60%+ starts. All hard-won source findings preserved above so
  fresh window skips re-exploration.
