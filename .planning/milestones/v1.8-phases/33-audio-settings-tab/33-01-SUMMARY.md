# 33-01 Summary — Audio EQ Preset Tab + af-Chain Compositor + Deferred Commit Seam

**Status:** ✅ Complete (code + headless tests committed)
**Commit:** `3c600a7`

## Delivered

### Data layer
- **AudioFilterCompositor** (`lib/ui/dialogs/settings/audio_filter_compositor.dart`, new): deterministic `compose(AudioSettings, AudioFilterAvailability) → String`. Chain order EQ→pan→adelay→dynaudnorm. Unavailable runtime filters omitted + debugPrint warned. EQ presets: `['', 'bass=g=10', 'treble=g=5', 'bass=g=8,treble=g=6', 'bass=g=3,treble=g=4']`.
- **AudioSettings** (immutable value object): eqPresetIndex/balance/syncMs/normalization + copyWith.
- **AudioFilterAvailability**: pan/adelay/dynaudnorm bools; `allSupported` sentinel; `probe({applyFilter})` injects applier (engine-agnostic, headless-testable; catches Exception only, propagates Error subtypes).
- **AudioCommitCallback** typedef: `void Function(AudioSettings)`.

### Persistence
- **SettingsValidator**: 3 bounds (`audioEqPresetMax=4`, `audioBalance ±1.0`, `audioSyncMsMax=10000`) + 3 validators.
- **SettingsStore**: 4 keys + 4 load/4 save, validator-bounded, safe defaults (0/0.0/0/false), exception log + fallback.

### Orchestration
- **SettingsPanelController**: ctor accepts `audioDefaults` + `onAudioCommit`; `open()` registers 4 audio keys; `commitPending()` builds AudioSettings snapshot from `pending.current()` (post-commit returns committed values), invokes callback once; Cancel → `cancelPending()` zero-calls.
- **PlayerFeature** (composition root): `_init()` loads 4 audio values from SettingsStore → injects controller; `_applyAudioSettings` composes af string → `engine.setEqualizer` (existing seam, **no engine interface change**) → `unawaited` sequential persistence.

### UI
- **EqualizerTab** (replaces Phase 25 skeleton): StatefulWidget, 5-preset selector via `pending.update('eqPresetIndex', i)`; check_circle/radio_button_unchecked Icon indicator (avoids Flutter 3.32+ deprecated `Radio.groupValue`/`onChanged`).

## Tests (53 headless, all pass)
- `audio_filter_compositor_test.dart` (27): EQ presets, pan/adelay/dynaudnorm boundaries, chain order, unavailable omission, probe (incl. Error propagation).
- `settings_store_audio_test.dart` (19): 4-key round-trip + clamp + defaults.
- `audio_tab_test.dart` (7): controller open/register/commit/cancel + EqualizerTab widget tap.
- `audio_filter_runtime_smoke_test.dart` (target-Windows only, not run headless): probe via real `FvpEngine.setEqualizer`.

## Validation gates
- ✅ `flutter analyze` — no errors in 33-01 files (only pre-existing baseline infos).
- ✅ 3 headless test files — 53/53 pass.
- ⏳ Runtime gate (Task #6): user runs smoke on target Windows + **manual auditory check** for pan/adelay/dynaudnorm. probe 局限: `_guardedAction` swallows recoverable Exception → probe may return true even if MDK rejects. **Auditory confirmation is authoritative** — all 3 filters must be audibly applied; any unavailable must find an equivalent supported path before phase completion (no partial omission).

## Env note
`flutter pub get` required before `flutter test` — kernel compiler needs fresh `package_config.json` (analyzer tolerates stale). Symptom: `Matrix4 isn't a type` from SDK painting libs.

## Decisions honored
- **Q2 Option A**: single `AudioCommitCallback`, synchronous (Apply/OK buttons call `commitPending()` synchronously).
- **No partial omission**: unavailable filters omitted from af string but original user values unchanged + warned.
- **No engine interface change**: reused existing `setEqualizer(String)`.
