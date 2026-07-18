---
phase: 16-diagnosticsbundle
plan: 03
subsystem: composition-root
tags: [strangler-fig, seam, kernel-adapter, wiring, adapt-01, adapt-02]
dependency_graph:
  requires:
    - 16-01 (KernelAdapter, DelegationPolicy, KernelMode — lib/kernel/adapter/kernel_adapter.dart)
    - 16-02 (DiagnosticsBundle.noop() — lib/kernel/diagnostics/diagnostics_bundle.dart)
  provides:
    - PlayerServices.engine now backed by KernelAdapter at runtime (composition-root swap)
  affects:
    - Every downstream consumer of PlayerServices.engine (PlaybackController, VideoProcessingService,
      UI ValueListenableBuilders) — untouched at the source level, now transparently routed through
      the adapter (0 casts, 0 convenience-getter usages per prior cast audit)
    - Phase 20 cutover (migrated slot flips from `fvp` to `NewFvpEngine`, policy flips per-capability)
tech_stack:
  added: []
  patterns:
    - Strangler Fig composition-root swap (single call-site change, drop-in via MediaEngine interface)
    - Same-instance dual-slot injection (legacy/migrated both point at the one FvpEngine, D13/D19)
key_files:
  created: []
  modified:
    - lib/kernel/player_services.dart (import + init() swap only; field decl and dispose() untouched)
decisions:
  - "Same fvp instance passed to both legacy and migrated params — zero extra native resources
    (no duplicate mdk.Player/texture/ValueNotifier), per D13/D19 RECOMMENDED approach"
  - "Bundle param omitted entirely at the call site — relies on KernelAdapter's own
    `bundle = const DiagnosticsBundle.noop()` constructor default (D10/D12); no DiagnosticsBundle
    import needed in player_services.dart since the analyzer did not require the type visible"
  - "late final MediaEngine engine field declaration left byte-for-byte unchanged — KernelAdapter
    implements MediaEngine satisfies the existing static type with zero downstream diff"
metrics:
  duration: ~20 min
  completed: 2026-07-18
  tasks: 1
  files_modified: 1
  lines_changed: "+12/-1"
status: complete
---

# Phase 16 Plan 03: Wire KernelAdapter at composition root Summary

Minimal-diff swap at the single composition root (`PlayerServices.init()`): replaced
`engine = FvpEngine();` with a `KernelAdapter` wrapping one `FvpEngine` instance passed
as both `legacy` and `migrated`, `policy: const DelegationPolicy.all(KernelMode.legacy)`,
and the constructor-default noop `DiagnosticsBundle`. This is the entire application-code
integration surface for Phase 16 — no other file constructs an engine.

## What Changed

**`lib/kernel/player_services.dart`**

1. Added one import: `import 'adapter/kernel_adapter.dart';` (brings `KernelAdapter`,
   `DelegationPolicy`, `KernelMode` — all three live in the single adapter file per D19).
   No `diagnostics_bundle.dart` import was needed — the analyzer did not require the
   `DiagnosticsBundle` type visible in this file since the bundle param is omitted and
   defaults inside `KernelAdapter`'s own constructor.
2. Replaced the single line `engine = FvpEngine();` inside `init()` with:
   ```dart
   final fvp = FvpEngine();
   engine = KernelAdapter(
     legacy: fvp,
     migrated: fvp,
     policy: const DelegationPolicy.all(KernelMode.legacy),
   );
   ```
   preceded by a Chinese comment (matching surrounding comment density) explaining the
   Strangler Fig seam: same-instance legacy/migrated in Phase 16 because `NewFvpEngine`
   doesn't exist yet, all-legacy routing means behavior is identical to the pre-adapter
   code, and Phase 20 is where `migrated` flips to a real `NewFvpEngine` and the policy
   flips per-capability.
3. Nothing else changed: the `late final MediaEngine engine` field declaration (line 55),
   the rest of `init()` (playlist/controller/settings/videoProcessing wiring), and
   `dispose()` are byte-for-byte identical to before.

## Verify Results

- `flutter analyze lib/kernel/player_services.dart` — **No issues found!**
- `grep -q 'DelegationPolicy.all(KernelMode.legacy)' lib/kernel/player_services.dart` — **PASS**
- `grep -q 'late final MediaEngine engine' lib/kernel/player_services.dart` — **PASS**
- `git diff lib/kernel/player_services.dart` — confirmed the diff touches only the new
  import line and the `init()` swap (+12/-1); field declarations and `dispose()` untouched.
- `git diff --stat lib/kernel/engine/fvp_engine.dart` — empty (D20 confirmed, no fvp_engine
  edits made by this plan).
- Full regression suite (`flutter test`): **1275 passing, 57 failing.** All 57 failures are
  in `test/engine/fvp_engine_contract_test.dart` and are **pre-existing on the unmodified
  base commit** (verified via `git stash` / re-run on the pristine tree before this edit) —
  they fail with `Invalid argument(s): Failed to load dynamic library 'mdk.dll': The
  specified module could not be found.`, an environment/native-library limitation of this
  worktree's test runner, unrelated to the KernelAdapter wiring. Zero new failures introduced
  by this change — satisfies ADAPT-01's regression gate (behavior unchanged).

## Deviations from Plan

**None** — plan executed exactly as written. One incidental cleanup: `flutter analyze`
triggered a `flutter pub get` which regenerated line-ending-only diffs in
`macos/Flutter/GeneratedPluginRegistrant.swift`, `windows/flutter/generated_plugin_registrant.cc`,
`windows/flutter/generated_plugin_registrant.h`, and `windows/flutter/generated_plugins.cmake`
(CRLF/LF churn, zero content change per `git diff --stat`). These were reverted with
`git checkout --` before committing since they are out of scope for this plan (not files_modified
in the plan frontmatter) and carried no functional diff.

## Self-Check

- `lib/kernel/player_services.dart` — FOUND, contains `KernelAdapter(`, `legacy: fvp`,
  `migrated: fvp`, `DelegationPolicy.all(KernelMode.legacy)`.
- Commit `0c95e07` — FOUND in `git log --oneline`.

## Self-Check: PASSED
