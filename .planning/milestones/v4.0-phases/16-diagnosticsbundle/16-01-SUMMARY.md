---
phase: 16-diagnosticsbundle
plan: 01
subsystem: kernel-adapter
tags: [strangler-fig, seam, delegation, kernel, adapter]
dependency_graph:
  requires:
    - 16-02 (DiagnosticsBundle + const .noop() factory — Wave 1, on trunk)
    - kernel/engine/media_engine.dart (7 ISP sub-interfaces)
  provides:
    - KernelAdapter (implements MediaEngine) — Strangler Fig seam
    - DelegationPolicy (7 final KernelMode fields + .all() factory)
    - KernelMode enum { legacy, migrated }
  affects:
    - Phase 17 KernelLogger real-slot activation (D3 dead-code -> live)
    - Phase 20 NewFvpEngine cutover (DelegationPolicy field flip)
    - Phase 21 seam collapse/deletion (SC4/D16)
tech_stack:
  added: []
  patterns:
    - Strangler Fig seam (per-capability ternary dispatch)
    - Identity-preserving ValueNotifier forwarding (ADAPT-03 / #6)
    - Immutable delegation policy (D15 final+recreate)
    - Single-route interface composition (VolumeControl, Pitfall 2)
key_files:
  created:
    - lib/kernel/adapter/kernel_adapter.dart (357 lines, single-file per D19)
  modified: []
decisions:
  - D19 — single-file authoritative over RESEARCH's 3-file split (KernelMode + DelegationPolicy + KernelAdapter all in kernel_adapter.dart)
  - D20/D22 — adapter has NO openGeneration counter; open() pure forwarding; counter migration deferred to P20 (STATE-02)
  - D18 — stateView is a plain KernelMode field with no extra pin (final+recreate already bounds mutation)
  - VolumeControl single-route — setVolume/setMute/volume/isMuted implemented ONCE via _policy.volume (Pitfall 2 / A2)
metrics:
  duration: ~45 min
  completed: 2026-07-18
  tasks: 3
  files_created: 1
  files_modified: 0
  line_count_kernel_adapter: 357
  line_count_total_adapter_diagnostics: 633
  budget_ceiling: 636
status: complete
---

# Phase 16 Plan 01: KernelAdapter Strangler Fig seam Summary

Built the Strangler Fig seam: a single-file `KernelAdapter implements MediaEngine`
that forwards every one of the ~44 members across MediaEngine's 7 ISP
sub-interfaces to a wrapped `legacy` or `migrated` engine selected per-capacity
by `DelegationPolicy`. Phase 16 wires deliberate dead routing —
`DelegationPolicy.all(KernelMode.legacy)` — so behavior is identical to using
`FvpEngine` directly. All three types (KernelMode, DelegationPolicy, KernelAdapter)
live in one file per D19.

## What Was Built

### Task 1 — KernelMode enum + DelegationPolicy struct (commit d5b561d)

`enum KernelMode { legacy, migrated }` — the single arbiter enum (D14/ADAPT-04).

`final class DelegationPolicy` with 7 `final KernelMode` fields named exactly
stateView, playback, track, subtitle, videoEffect, renderer, volume (one per
MediaEngine sub-interface, D14). All fields final (D15 immutability — structural
protection for Blocking Constraint #6). `stateView` is a plain field with no
extra pin/factory constraint (D18 — final+recreate already bounds it; an extra
pin would block Phase 20 partial cutover). Provides the primary
`const DelegationPolicy({required this.stateView, ...})` constructor AND the
`const DelegationPolicy.all(KernelMode mode)` factory setting all 7 fields to
the same mode (D14). Phase 16 uses `.all(KernelMode.legacy)` exclusively.

### Task 2 — KernelAdapter class shell + P20 checklist (commit db44c4a)

`class KernelAdapter implements MediaEngine` with the D12 constructor exactly:
`KernelAdapter({required MediaEngine legacy, required MediaEngine migrated,
required DelegationPolicy policy, DiagnosticsBundle bundle =
const DiagnosticsBundle.noop()})`. Stored as 4 final injected deps
(`_legacy`, `_migrated`, `_policy`, `_bundle`).

Per D17 the adapter has NO mutable state: no generation-counter field (D20 —
guards live in the old engine at fvp_engine.dart:259/267/311/320; the P16
adapter is transparent, and counter migration into the adapter is a P20 task),
no `_isMigrating` bool, no caches, no intermediate flags.

Class-level `///` doc comment mirrors `fvp_engine.dart:25-41` structure:
architecture summary + composition list, describing the Strangler Fig seam role
(transient seam, not a permanent layer, collapsed/deleted in Phase 21 per
SC4/D16). The class-level P20 migration checklist (D21/D23) lists EXACTLY 3
items, one line each with REQ-ID:
  - openGeneration unified counter migrates from legacy into adapter/tracker (STATE-02, D23a)
  - DiagnosticsBundle activation: swap noop slots to real slots (D3 dead-code -> live, D23b)
  - DelegationPolicy field flip: all-legacy -> per-capability migrated (D14/STATE-06, D23c)

D16 (kill-switch retention before adapter deletion) and D15 (engine-rebuild)
are deliberately NOT listed — they are PlayerServices/assembly concerns, not
adapter class-level (D23).

`@override void dispose()` routes per `_policy.stateView` to the active
engine's dispose AND cascades to `_bundle.dispose()` (D10). One policy-based
dispatch, no further internal branching (Phase 15 D8).

### Task 3 — 44 MediaEngine members + identity ternary dispatch (commit bf4ff23)

Implemented every abstract member across the 7 sub-interfaces using the
ternary-dispatch shape from PATTERNS.md lines 59-69:
`_policy.X == KernelMode.legacy ? _legacy.member : _migrated.member`.

- **EngineStateView (via `_policy.stateView`)** — 11 ValueNotifier getters
  (textureId, state, position, duration, isBuffering, isSeeking, subtitleText,
  buffered, aspectRatio, lastError, playbackSpeed) + `mediaInfo` getter.
  Identity-preserving: every notifier getter returns the wrapped engine's OWN
  instance directly, never rewrapped (ADAPT-03 / Blocking Constraint #6 —
  rewrapping would detach all ValueListenableBuilder listeners and freeze UI
  on cutover; this is the exact failure D25's same() test catches).
- **PlaybackControl (via `_policy.playback`)** — open, play, pause, stop,
  togglePlayPause, seekTo, setPlaybackRate, setRange, skipForward, skipBack
  (10 methods — NOT setVolume/setMute). `open()` is pure forwarding (D20): no
  counter, no guard — doc comment notes openGeneration guards live in the old
  engine and counter migration is a P20 task per the class-level checklist.
- **TrackControl (via `_policy.track`)** — getAudioTracks, switchAudioTrack,
  activeAudioTracks.
- **SubtitleConfig (via `_policy.subtitle`)** — getSubtitleTracks,
  switchSubtitleTrack, toggleSubtitle, setExternalSubtitle, setSubtitleDelay,
  setEqualizer, subtitleDelay, activeSubtitleTracks.
- **VideoEffectControl (via `_policy.videoEffect`)** — setVideoEffect, rotate,
  setAspectRatio, setDeinterlace.
- **RendererControl (via `_policy.renderer`)** — setD3d11SyncEnabled,
  setHardwareDecoding.
- **VolumeControl (via `_policy.volume`)** — setVolume, setMute, volume,
  isMuted implemented EXACTLY ONCE with an inline `//` comment explaining the
  single-route rationale: PlaybackControl.setVolume/setMute and
  EngineStateView.volume/isMuted have identical signatures, so Dart interface
  composition means one override satisfies all three parent interfaces
  simultaneously; a second branch keyed on _policy.playback or
  _policy.stateView would be unreachable dead code (RESEARCH Pitfall 2 /
  Assumption A2 — VolumeControl is the more specific interface, so it wins).

## Verification

All gates run and passed:

1. `flutter analyze lib/kernel/adapter/` — **clean**, no missing-override
   errors (all 7 ISP interfaces fully implemented).
2. `grep -rc '_openGeneration' lib/kernel/adapter/` → **0 hits** (D22 — no
   counter field; open() is pure forwarding).
3. `grep -c 'ValueNotifier(' lib/kernel/adapter/kernel_adapter.dart` →
   **0 hits** (no rewrap constructor calls in any getter body — identity
   forwarding, ADAPT-03).
4. `git diff --stat lib/kernel/engine/fvp_engine.dart` → **empty** (D20 —
   fvp_engine untouched).
5. File line count: **357** (target ~200-250, hard ceiling 636 minus 276
   already used by 16-02 = 360; 357 fits, total adapter+diagnostics = 633 <
   636 budget per D27).
6. `grep -n 'openGeneration' lib/kernel/adapter/kernel_adapter.dart` →
   **2 hits, both doc-comment lines** (D22 allows the concept name in
   class-level doc comments: the D21 P20 checklist line 85 and the open()
   transparency note line 214).
7. Single-route check: setVolume=1, setMute=1, `get volume`=1, `get isMuted`=1
   (each implemented exactly once, routed via _policy.volume, Pitfall 2).
8. Constructor presence: `enum KernelMode { legacy, migrated }`=1,
   `const DelegationPolicy.all(KernelMode mode)`=1,
   `class KernelAdapter implements MediaEngine`=1.

## Deviations from Plan

**1. [Rule 1 - Bug / DOC-01 comment-rewrite] Removed a forbidden `ValueNotifier(`
literal substring from a doc-comment example**

- **Found during:** Task 3 verification (Gate 3 — grep for `ValueNotifier(`)
- **Issue:** The class-level EngineStateView section comment contained a
  backtick-quoted `ValueNotifier(x.value)` example to illustrate the forbidden
  rewrap pattern. The negative grep `grep -c 'ValueNotifier(' ...` matched this
  doc-comment line, returning 1 instead of 0, which would have made the ADAPT-03
  grep gate ambiguous for Plan 16-05's full gate run.
- **Fix:** Rewrote the comment to describe the forbidden pattern in prose
  ("never a fresh notifier wrapping `x.value`") without the literal
  `ValueNotifier(` constructor-call substring. The semantic content
  (identity-forwarding rationale) is preserved.
- **Files modified:** lib/kernel/adapter/kernel_adapter.dart
- **Commit:** bf4ff23 (same Task 3 commit)

**2. [Rule 3 - Blocking] Trimmed bilingual doc-comment prose to fit the D27 line-count budget**

- **Found during:** Task 3 verification (Gate 5 — line count)
- **Issue:** Initial `dart format` expansion brought the file to 386 lines;
  with 16-02's 276 lines the total was 662, exceeding the 636-line hard
  ceiling (D27 — total adapter+diagnostics must stay under the old FvpEngine
  baseline).
- **Fix:** Compacted verbose bilingual doc comments while keeping ALL
  load-bearing content: the P20 migration checklist (D21), the Strangler Fig
  seam role description, the ADAPT-03 identity-forwarding rationale, the
  VolumeControl single-route rationale (Pitfall 2), the D20 open() note, and
  per-field policy role comments. Removed duplicated English restatements of
  Chinese intent lines and blank separator lines under three self-explanatory
  section headers. Final: 357 lines, total 633 < 636.
- **Files modified:** lib/kernel/adapter/kernel_adapter.dart
- **Commit:** bf4ff23 (same Task 3 commit)

Plan executed otherwise exactly as written — single-file structure (D19),
D12 constructor, D17 no-mutable-state, D18 stateView plain field, D20/D22
no-counter, VolumeControl single-route, ADAPT-03 identity forwarding, D21
class-level checklist, D10 cascading dispose.

## Known Stubs

None. The adapter is a deliberate pass-through seam — it carries no behavior
of its own, so there are no unwired data sources, placeholder returns, or
TODO/FIXME markers in the implementation. The "dead routing" (100% to legacy
via `DelegationPolicy.all(KernelMode.legacy)`) is the plan's specified Phase
16 posture, not a stub — it is intentional and becomes live in Phase 20 when
the policy flips per-capability.

The `DiagnosticsBundle` parameter defaults to `const DiagnosticsBundle.noop()`
per D12. The noop bundle is a known intentional dead carrier (D2/D3) defined
by Plan 16-02; its activation to real slots is a Phase 17/P20 task listed in
the D21 class-level checklist, not a stub in this plan.

## Threat Flags

None. The plan's `<threat_model>` declares `threat_level: low` with no
high-severity threats and no blocking mitigations. The adapter is a pure
in-process delegation seam: no new auth, input, crypto, file-system, or
external-call surface. Input validation (e.g. `String path` to `open()`)
remains the responsibility of the existing, already-audited `FvpEngine` /
`PathValidator` (unchanged — fvp_engine.dart untouched per D20). No
threat-relevant surface was introduced beyond what the threat register already
covers (T-16-01 accept, T-16-02 accept).

## Self-Check: PASSED

- File exists: FOUND `lib/kernel/adapter/kernel_adapter.dart`
- Commits: FOUND d5b561d (Task 1), db44c4a (Task 2), bf4ff23 (Task 3)
- Post-commit deletions: none (Task 3)
- Untracked files: none
- All 8 verification gates passed (analyze clean; _openGeneration=0;
  ValueNotifier( =0; fvp_engine diff empty; line count 357 under budget;
  openGeneration in 2 doc lines only; single-route members each =1;
  enum/class/factory present).
