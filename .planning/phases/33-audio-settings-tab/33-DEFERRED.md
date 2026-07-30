# Phase 33 — DEFERRED (af route unverified at runtime)

**Date:** 2026-07-30
**Decision owner:** User
**Status:** Phase 33 deferred · Phase 34 skipped · v4.5 milestone wrapped

## What happened

Phase 33 shipped 3 plans of code + headless tests + SUMMARY (all committed), then hit the
runtime gate. The user ran the audio filters on the target Windows machine and reported
**「完全无法使用」** — none of `pan` / `adelay` / `dynaudnorm` (and likely `bass`/`treble` EQ
too) produced any audible effect after Apply/OK.

Per the user's product decision (2026-07-30), Phase 33 is **deferred, not completed**. The
previously locked hard constraint "no partial feature omission is acceptable" is **withdrawn
by the user** — they chose to stop rather than pursue an equivalent supported route. Phase 34
(Control-Bar Audio Track Switching) is **skipped**. v4.5 milestone wraps here.

## Root cause (strong suspect, UNVERIFIED — user chose not to confirm)

The `setProperty('af', afFilter)` route in `subtitle_configurator.dart:79-81` almost certainly
does not wire into fvp 0.37.2's audio filter pipeline. Evidence:

1. **"af already works" was never audibly verified.** RESEARCH.md (confidence MEDIUM) claimed
   the route was "proven working" based on the legacy `EqualizerTab` using `bass=g=N`. But
   `FvpEngine.setEqualizer` wraps the call in `_guardedAction` (try-catch + debugPrint), which
   **silently swallows recoverable Exceptions**. So "proven" only ever meant "call doesn't
   crash" — MDK can reject/ignore the property and the app stays quiet. No auditory evidence
   ever existed. The runtime gate was specifically the check that would have caught this.
2. **Property-name asymmetry.** Video filters use `video.avfilter`
   (`video_effect_controller.dart:70`, MDK-native naming). By symmetry the audio property
   should be `audio.avfilter`, NOT `af` (an mpv alias). RESEARCH L183 explicitly forbade
   `audio.avfilter` and locked `af` — on the unverified premise that `af` works. This is the
   leading suspect: MDK likely ignores the `af` key entirely, so the filter string never
   reaches libavfilter.
3. **Self-contradicting source comment.** `subtitle_configurator.dart:71-77` documents the
   format as `af=lavfi=[equalizer=...]` with `;`-separated chains and a `lavfi` bridge — but
   the implementation passes a bare comma-separated string (`bass=g=8,treble=g=6,...`). Even
   if the property name is correct, the syntax may be wrong (mpv simple-filtergraph vs MDK
   lavfi-wrapped). The comment and the code disagree.

**Net:** the failure is most likely a property-name and/or syntax mismatch, NOT a missing
FFmpeg filter compilation. fvp's bundled FFmpeg almost certainly has `pan`/`adelay`/`dynaudnorm`
(they're standard libavfilter); they're just never being invoked because the property key is
wrong.

## What was delivered (kept on disk, NOT reverted)

All committed and retained for future reuse:

| Commit | Content |
|---|---|
| (33-01 code+tests) | `AudioFilterAvailability` probe type + `AudioSettings` VO + `AudioFilterCompositor` (5 presets, EQ→pan→adelay→dynaudnorm) + `SettingsStore` 4 audio keys + `SettingsValidator` bounds + `AudioCommitCallback` seam + `EqualizerTab` deferred selector + 3 headless test files |
| (33-02 code+tests) | balance + sync sliders + pan/adelay composition + tests |
| `c479e820` (33-03) | normalization Switch + full-chain commit/cancel integration tests |
| `2c72a0b7` | stale `general_equalizer_tab_test` fix for Phase 33 EqualizerTab structure |
| `bdd6e833` | 33-03-SUMMARY |

The UI, compositor, persistence, and deferred-apply wiring are complete and headless-tested
(121/121 focused suite green). **Only the final engine-application step is broken** — the af
string is composed correctly but the property it's written to doesn't take effect.

## How to resume (future session)

The fix is likely a 1-line property-name change + one auditory confirmation. Ordered steps:

1. **Try `audio.avfilter` first** (cheapest, leading suspect). In
   `subtitle_configurator.dart:80`, change `_player.setProperty('af', afFilter)` →
   `_player.setProperty('audio.avfilter', afFilter)`. On target Windows, play a file with an
   audio track, select 「摇滚」 preset, click 应用, confirm bass boost is audible. If yes →
   root cause confirmed, Phase 33 unblocked.
2. **If `audio.avfilter` also silent**, try the lavfi-wrapped syntax the source comment
   describes: `lavfi=[bass=g=8,treble=g=6]` (with `;` chain separator if multiple lavfi
   blocks). The bare comma syntax may be mpv-only.
3. **If syntax is right but filters still silent**, verify the linked FFmpeg actually compiled
   `af_pan` / `af_adelay` / `af_dynaudnorm` (RESEARCH's original open question). fvp 0.37.2
   bundle inspection or a `player.setProperty('log', 'all')` trace during apply would reveal
   MDK's filter-graph log.
4. **Reinstate the runtime gate.** The `audio_filter_runtime_smoke_test.dart` probe is
   necessary-but-not-sufficient (probe ≠ audible effect, due to `_guardedAction` swallow).
   The authoritative gate remains human auditory check of all 3 filters — same as today.
5. Once all 3 filters audibly apply, run `gsd-verifier` and close Phase 33 properly.

## Why the user chose to stop instead

Informed of the `audio.avfilter` suspect and offered a 30-second verification, the user chose
**「保留代码+deferred 收尾」** — preserve the work, mark deferred, wrap v4.5. Rationale
respected: the user judged the audio-feature direction not worth further pursuit at this time.
The deferred code + this root-cause record mean a future session can resume in minutes, not
re-derive from scratch.

## Artifacts

- `33-EXECUTE-CHECKPOINT.md` — deleted at wrap (stale: claimed "zero lib changes" but 3 plans
  shipped). Root-cause knowledge lives here now.
- `33-RESEARCH.md` — retained; its MEDIUM confidence and Assumptions A1–A3 (filter
  availability unverified) are now empirically validated as real risks, not hypothetical.
- `audio_filter_runtime_smoke_test.dart` — retained; still the correct probe scaffold for
  resume step 4.
