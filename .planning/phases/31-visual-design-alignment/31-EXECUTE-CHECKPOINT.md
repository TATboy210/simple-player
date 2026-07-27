---
phase: 31-visual-design-alignment
plan: all (3 plans, 3 waves)
wave: ALL 3 DONE (31-01: e0e1bd00/c1b023ac/28b92bca; 31-02: 8d4a1a08/cd6848af/d2496aaf/2737d537/64fd9f91; 31-03: no-commit verify). Verifier gaps_found→user accepted VISUAL-02 by-design (container rows exempt per D-15).
status: paused-pre-finalize (docs edited NOT committed; F12 NOT removed; stash NOT popped)
created: 2026-07-27
wave1_completed: 2026-07-28
reason: context-97pct pre-finalize. Next 3 steps: (1) commit docs — VERIFICATION.md + 31-03-SUMMARY.md + STATE.md + ROADMAP.md + REQUIREMENTS.md + perf-baseline-pre-backup.json; (2) remove F12 tool in lib/ui/player/keyboard_handler.dart (commit 4304aee4 — revert F12 to kDebugMode-only or remove perf export entirely + dart:io import); (3) git stash pop stash@{0} — resolve test/widget/settings/general_equalizer_tab_test.dart conflict (keep 31-02 committed extension) + settings_focus_navigation_test.dart FakePlaybackController(initiallyPlaying:) compile error (stash-introduced)
stash: "stash@{0} (42 tracked files: lib/kernel + lib/ui/player/player_screen.dart + pubspec + tests)"
executor_model: sonnet
spawn_mode: sequential (no worktree)
verifier_model: sonnet
---

# Phase 31 Execute Checkpoint — paused before Wave 1

Orchestrator context hit 72% after stash + plan reads + task setup.
Paused cleanly before any executor dispatch (asymmetric risk: spawn now
leaves no recovery budget for test failures or verifier gaps). Resume in
a fresh window.

## Decisions locked (AskUserQuestion, 2026-07-27)

1. **Dirty tree → Stash, execute, pop after.** DONE: `git stash push -m
   "pre-Phase-31 cross-session work (lib/kernel + tests + pubspec, 42 files)"`
   → `stash@{0}` (42 files, 975 insertions / 1645 deletions). Used plain
   `git stash push` (NO `-u`) so the 2 untracked `.planning/` docs
   (`.planning/DESIGN_PHILOSOPHY.md`, `.planning/phases/29-auto-pause-always/29-EXECUTE-CHECKPOINT.md`)
   stay in place — they don't affect execution.
2. **Profile baseline → User captures it now.** User runs
   `D:/flutter/bin/flutter run --profile -d windows`, enables PerfMonitor,
   opens Settings, drags title bar + scrolls content, saves
   `PerfMonitor.exportStats()` to
   `.planning/phases/31-visual-design-alignment/perf-baseline-pre.json`.
   This file is a Plan 31-01 Task 1 acceptance criterion AND feeds Plan
   31-03 Task 2's A/B raster comparison ("≤1 ms from recorded baseline").

## init.execute-phase 31 (verified, seconds to re-run)

- phase_found=true; phase_dir=`D:/simple_player_flutter/.planning/phases/31-visual-design-alignment`
- 3 plans (31-01/02/03), 3 incomplete, **3 waves** (1→2→3, single-plan-per-wave)
- executor_model=**sonnet** (explicit → pass `model="sonnet"` to Agent)
- verifier_model=sonnet; parallelization=true (but no parallelism — 1 plan/wave)
- branching_strategy=**none** (stay on `feat/v1.8-stability-polish-plan-02-02`)
- context_window=200000; agent_runtime=**claude** (MUST spawn gsd-executor; inline NOT authorized — no `--interactive` flag)
- tdd_mode=false; verifier_enabled=true; commit_docs=true
- phase_req_ids: VISUAL-01..05; requirements_path=`.planning/REQUIREMENTS.md`

## phase-plan-index (wave grouping)

- **Wave 1 — 31-01** (autonomous, depends_on=[]): extract `ControlBarDecoration`
  shared API + prove title-bar chrome route (Task 1, tracer) + expand to all 3
  chrome sections w/ corner-only radii + re-baseline `panel_color_test` (Task 2).
  Files: `lib/ui/shared/control_bar_decoration.dart` (new), `control_bar.dart`,
  `settings_overlay_shell.dart`, `tab_strip.dart`, 2 test files.
- **Wave 2 — 31-02** (autonomous, TDD, depends_on=[31-01]): SettingRow
  three-state (default/hover/focused/pressed) + 40px density + InkWell no-scale
  + `FocusableSettingRow.focusedBuilder`. Files: `settings_card.dart`,
  `focusable_setting_row.dart`, 2 test files (incl. `test/widget/settings/general_equalizer_tab_test.dart`).
- **Wave 3 — 31-03** (autonomous=**FALSE**, depends_on=[31-01,31-02]): Task 1
  auto (focused suite + `flutter analyze` + full-suite baseline discrimination);
  Task 2 = `checkpoint:human-verify` `gate="blocking"` — 5-step Windows profile
  visual + raster A/B check. Executor returns at Task 2; orchestrator presents to
  user; user types `approved` or reports issue.

## Anti-pattern check (passed)

No phase-level `.continue-here.md`. Milestone-level `.planning/.continue-here.md`
(8 blocking constraints) is v3.0 kernel-rewrite (Phases 15-22) — N/A to v4.5
Phase 31. No blocking anti-patterns → proceeded past `check_blocking_antipatterns`.

## safe_resume_gate (clean)

CURRENT_PLAN_ID=31-01. No production commits for 31-01/02/03, no SUMMARYs.
→ Clean resume, no duplicate-work risk. Re-dispatch is safe.

## Resume sequence (next orchestrator)

1. **Verify baseline captured**: check
   `.planning/phases/31-visual-design-alignment/perf-baseline-pre.json` exists.
   If missing → user captures it via F12 (tool已就绪, commit 4304aee4):
   `D:/flutter/bin/flutter run --profile -d windows` → open Settings panel →
   drag title bar + scroll General content → press F12 once (enables PerfMonitor
   + prompts "operate then press again") → operate ~2-3s (frames sample) →
   press F12 again (writes JSON to perf-baseline-pre.json; absolute path logged).
   Do NOT spawn 31-01 without it — Task 1 says "Before modifying production code,
   run the profile-mode baseline protocol".
   **Tool补齐 (commit 4304aee4)**: F12 guard `kDebugMode` → `kDebugMode || kProfileMode`;
   on press: idempotent `PerfMonitor.instance.enable()` + `exportStats()`;
   `frameCount==0` → prompt; `frameCount>0` → `writeAsStringSync` to
   `.planning/phases/31-visual-design-alignment/perf-baseline-pre.json`.
   keyboard_handler.dart NOT in stash@{0} → no pop conflict. analyze clean,
   keyboard_handler_test 22/22 pass.
2. **`state.begin-phase`** (validate_phase step):
   `gsd_run query state.begin-phase --phase 31 --name visual-design-alignment --plans 3`
   (flips STATE.md status → executing). NOTE: STATE.md is NOT in the stash (only
   lib/test/pubspec files are) — safe to mutate.
3. **Spawn Wave 1 — 31-01** (slim spawn, sequential mode = no `isolation="worktree"`,
   `model="sonnet"`):
   - Inject ONLY: 31-01-PLAN.md + `execute-plan.md` + `summary.md` template +
     `CLAUDE.md`. SKIP STATE/PROJECT/config/checkpoints/tdd injection (Phase 28
     halt lesson, STATE L246: fresh subagent effective window ~60K, not 200K —
     full injection left only ~9K for actual work and halted at 89%).
   - Verify: `D:/flutter/bin/flutter test test/ui/shared/control_bar_decoration_test.dart test/widgets/panel_color_test.dart` exits 0.
   - Commit each task atomically; write `31-01-SUMMARY.md` (MUST record
     `perf-baseline-pre.json` path for Plan 03).
4. **Spawn Wave 2 — 31-02** (slim, sequential, TDD). Focused tests:
   `test/ui/shared/settings_card_test.dart test/ui/shared/focusable_setting_row_test.dart test/widget/settings/general_equalizer_tab_test.dart` exit 0.
5. **Spawn Wave 3 — 31-03** (autonomous=false): Task 1 auto; Task 2 human-verify
   checkpoint → present 5-step Windows profile check to user.
6. **Post-merge gate** after each wave: `D:/flutter/bin/flutter test` on focused
   Phase 31 suite. Pre-existing baseline (judge by module boundary — Phase 31
   touches only `lib/ui/shared` + `lib/ui/dialogs/settings` + `lib/ui/player/control_bar`):
   ~57 `mdk.dll` FFI headless failures (memory `reference_mdk_dll_headless_test_failures.md`)
   + 4 dialog failures (Phase 25 SettingsNavItem / GeneralTab headless, STATE L273).
   No NEW UI test failure may be attributed to changed files.
7. **Verify**: `gsd-verifier` (sonnet) → `VERIFICATION.md`. Route on status
   (passed → complete; gaps → gap-closure; human_needed → UAT).
8. **Complete**: `gsd_run query phase.complete 31` + commit
   `ROADMAP.md`/`STATE.md`/`REQUIREMENTS.md`/`VERIFICATION.md`.
9. **Pop stash**: `git stash pop stash@{0}`. **KNOWN CONFLICT**:
   `test/widget/settings/general_equalizer_tab_test.dart` — stashed pre-Phase-31
   changes vs 31-02's committed extension. `git stash pop` does 3-way merge by
   default; if conflict, resolve by keeping 31-02's committed extension +
   reapplying stashed test changes only if still semantically relevant. Other
   41 stashed files (lib/kernel etc.) pop cleanly (no path overlap with Phase 31).

## Fallback if slim spawn halts mid-task

Switch to `/gsd-execute-phase 31 --interactive` (main session inline, Phase 28
final-success pattern STATE L262-275). Avoids subagent injection overhead
entirely; user drives profile baseline + 31-03 human-verify inline between tasks.

## Resume command

`/clear` → `/gsd-execute-phase 31`

Fresh 200K window. Re-runs init (seconds), re-discovers 3 plans/3 waves, finds
this checkpoint, verifies baseline JSON exists, then `state.begin-phase` + spawn
31-01 (slim, sequential, sonnet).
