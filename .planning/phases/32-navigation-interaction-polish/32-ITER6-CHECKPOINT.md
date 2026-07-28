---
phase: 32-navigation-interaction-polish
task: 0
total_tasks: 7
status: paused-pre-iter6-spawn-iter5-recheck-complete
halt_reason: orchestrator-context-budget (~55%, memory feedback_gsd_context_budget_pause hard constraint: >=60% -> checkpoint + /clear; iter6 chain (planner opus + checker sonnet) would push to ~60-63% at the halt threshold; iter5 re-check found 1 blocker + 1 warning (DOWN from iter4's 3+1 — converging, not stalling); checkpoint + fresh window preserves max margin per asymmetric-risk principle)
context_pct_at_halt: 55
step_at_halt: iter5-recheck-complete (planner iter5 commits 5b094ce/347d149/143b3d8 all on disk; checker iter5 re-verify returned ISSUES FOUND with 1 blocker + 1 warning, down from iter4's 3 blockers + 1 warning; user authorized iter6 targeted revision + chose checkpoint+/clear for max budget margin)
created: 2026-07-28
attempts: 6
planner_model: opus
checker_model: sonnet
commit_docs: true
convergence: "6->2->2->0-structurally-confirmed(iter4)->1+1(iter5 re-check) — issue count DROPPING across iterations (3 blockers -> 1 blocker); stall detection criterion (issue count not decreasing across 2 iterations) NOT triggered; iter6 warranted"
revision_commits:
  - 85e6696 (iter1: 4 BLOCKERs + 1 WARNING fixed)
  - 3689329 (iter2: 1 BLOCKER + 1 WARNING fixed)
  - d2c58ad (iter3: 1 BLOCKER attempted — two-stage gate REJECTED by checker)
  - 5671e95 (iter4: 2 BLOCKERs structurally fixed — baseline-gen Task0 + grep pathspec + consumption-only gate)
  - 5b094ce (iter5: 32-01 — grep gate direct conditional + detector test seam @visibleForTesting forTest/resetInstance + injectable clock + panel-close onPanelClosed hook + Test 13)
  - 347d149 (iter5: 32-02 — panel-close lifecycle hook wiring in _onIsOpenChanged + threat T-32-10P)
  - 143b3d8 (iter5: 32-03 — OptionListNavigationOverlay child-composition mount contract + Test 6)
remaining_blockers: 1 (dependency_correctness — Wave1 uses token Wave2 creates) + 1 warning (claude_md_compliance — plans don't require /// docs for new public types)
---

# Phase 32 — ITER6 checkpoint (paused @ ~55% orchestrator context, iter5 re-check complete, iter6 spawn deferred to fresh window)

> **STATUS (2026-07-28, post-iter5-recheck):** iter5 planner COMPLETE (3 atomic
> commits `5b094ce`/`347d149`/`143b3d8` — fixed all 3 iter4 blockers + 1 warning:
> grep gate `$?` pipeline → direct conditional; singleton test seam
> `@visibleForTesting forTest/resetInstance` + injectable `DateTime Function()`
> clock + isolated instances; OptionListNavigationOverlay child-composition mount;
> panel-close `onPanelClosed` hook). iter5 checker RE-VERIFY returned
> `## ISSUES FOUND` with **1 blocker + 1 warning** — DOWN from iter4's 3 blockers
> + 1 warning. **Converging, not stalling** (issue count dropped 3→1; stall
> detection criterion = "issue count not decreasing across 2 iterations" is NOT
> triggered). The new blocker is concrete + narrow (dependency-cycle: move 1
> token's creation from Wave 2 to Wave 1). The warning is additive (acceptance
> criteria for `///` docs). iter6 warranted + user authorized. **Checker re-spawn
> NOT executed** — halted at ~55% per memory `feedback_gsd_context_budget_pause`
> (iter6 chain would push to ~60-63% at the halt threshold). Fresh window must
> spawn planner (iter6) + checker (re-verify) to confirm PASSED before post-PASS.

## Convergence analysis (why iter6 is justified, not a stall)

| Check round | Blockers | Warnings | Notes |
|---|---:|---:|---|
| iter4 re-check | 3 | 1 | grep gate `$?` + singleton test seam + overlay mount contract |
| iter5 re-check | 1 | 1 | dependency_correctness (NEW) + claude_md_compliance (NEW) |

Issue count DROPPED (3→1 blocker). The iter5 issues are DIFFERENT from iter4's
(fixed iter4's 3, surfaced 1 new dependency-cycle + 1 docs warning). This is
normal convergence as fixes surface adjacent issues — NOT a stall. Stall
detection (per 32-CHECKER-CHECKPOINT revision procedure) triggers only when
issue count does NOT decrease across 2 consecutive iterations. Not triggered here.

## Fresh-window lean procedure (iter6)

1. `/clear` (fresh 200K window).
2. Read THIS file (`32-ITER6-CHECKPOINT.md`). iter5 plans are on disk (commits
   `5b094ce`/`347d149`/`143b3d8`); do NOT re-spawn planner from scratch, do NOT
   re-run `/gsd-plan-phase 32`. The ONLY remaining step is:
   - **Step A:** spawn `gsd-planner` (opus, sync, `run_in_background=false`) with
     the VERBATIM revision prompt in "## VERBATIM iter6 revision prompt" below
     (targets ONLY the 1 blocker + 1 warning; preserve_constraints block lists
     13 items that must NOT regress).
   - **Step B:** re-spawn `gsd-plan-checker` (sonnet, sync, `run_in_background=false`)
     with the VERBATIM checker prompt in "## VERBATIM checker prompt (unchanged
     from iter4)" below (same 12 Phase 32 hard-constraint checks — the plans must
     still satisfy all of them after iter6 edits).
3. After checker returns:
   - **`## VERIFICATION PASSED`** → proceed to post-PASS procedure (step 4).
   - **`## ISSUES FOUND`** → this is iter 7 territory. Do NOT auto-spawn iter 7.
     Use `AskUserQuestion` to offer: (a) iter 7 targeted revision (only if new
     issues are concrete + narrow + budget allows + convergence continues),
     (b) Proceed anyway (accept documented residual, go to post-PASS),
     (c) Abandon. Default recommend (a) only if issues are as concrete as iter6's
     were (1 dependency-cycle + 1 docs warning) AND issue count still dropping;
     else (b). **Stall check:** if iter7 issue count ≥ iter6's (1 blocker),
     recommend (b) Proceed anyway or (c) Abandon — the plan is unlikely to fully
     converge and the residual may be acceptable for a shell-only verify gate.
4. **Post-PASS procedure (after PASSED or after choosing Proceed anyway):**
   See `32-CHECKER-CHECKPOINT.md` "## Post-spawn procedure" steps 3-7 (UNCHANGED
   — same post-PASS: create `32-VALIDATION.md` from `32-RESEARCH.md` L353+
   `## Validation Architecture` using template
   `$HOME/.claude/gsd-core/templates/VALIDATION.md`; update STATE.md frontmatter
   `status: planned`, `completed_plans` 9→12, `total_plans` 10→13, `percent`
   43→~57; update ROADMAP.md Phase 32 plans list; cleanup 4 one-time artifacts
   (`32-PLAN-CHECKPOINT.md`, `32-RESEARCH-CHECKPOINT.md`, `32-CHECKER-CHECKPOINT.md`,
   `32-ITER6-CHECKPOINT.md` (this file) — all untracked/plain `rm` except
   `32-CHECKER-CHECKPOINT.md` which is tracked → use `git rm`); commit
   `docs(32): finalize phase plan`; do NOT auto-advance — tell user `/clear` →
   `/gsd-execute-phase 32`).

**Context budget estimate (fresh 200K):** ~30% baseline + ~5% iter6 chain
(planner opus spawn ~3K prompt echo + ~5K return + checker sonnet re-spawn ~4K
prompt echo + ~5K return = ~17K = ~8.5%) + ~5% post-PASS = ~43% peak, ~57%
margin. Very safe. (Compare: this resume window halted at ~55% BEFORE the iter6
chain — fresh window has 25% more margin than continuing here.)

## Why paused (not spawned iter6 in this resume window)

Memory `feedback_gsd_context_budget_pause` (user hard constraint, 2026-07-26):
`gsd-plan-phase` / `gsd-execute-phase` at ≥60% orchestrator context halts
before spawning a subagent chain. This resume window is at ~55% after loading
STATE.md (342 lines) + HANDOFF.json + 32-CHECKER-CHECKPOINT.md + iter4 checker
spawn + iter5 planner spawn + iter5 checker re-verify spawn. The iter6 chain
(planner opus + checker sonnet, uncertain-length if checker finds new issues)
would push to ~60-63% — at/above the halt threshold. The previous window
halted at 67% doing exactly this kind of planner+checker chain. Per memory's
"How to apply" + asymmetric risk (mid-halt state worse; checkpoint has no
downside): write checkpoint + `/clear` → spawn iter6 from fresh. User chose
this path (option (a) in the AskUserQuestion).

## What's already done (do NOT redo in fresh window)

- ✅ iter4 structural fix (commit `5671e95`): 32-01 Task0 baseline-gen + grep
  pathspec + 32-03 consumption-only 6-step gate
- ✅ iter5 planner spawned (opus, sync) with revision prompt — fixed all 3
  iter4 blockers + 1 warning; 3 atomic commits `5b094ce`/`347d149`/`143b3d8`
- ✅ iter5 plans verified on disk (structural validation: 0 errors, 0 warnings)
- ✅ iter5 checker re-verify spawned (sonnet, sync) — returned ISSUES FOUND
  with 1 blocker + 1 warning (this checkpoint captures those for iter6)
- ✅ iter5 self-verification confirmed all 4 iter4 issues resolved + 10/10
  preserve_constraints intact (before the iter5 re-check surfaced the new
  dependency-cycle + docs warning)

## The 1 blocker + 1 warning to fix in iter6 (from iter5 re-check)

### Blocker 1 — `dependency_correctness` (32-01 Task 1 + 32-02 Task 1)

**Description:** 32-01 Task 1 (Wave 1 TRACER) implements `InputModeDetector`
using `Tokens.inputModeIdleTimeoutSec` for its production default. But that
token is only created by 32-02 Task 1, which DEPENDS ON 32-01 (Wave 2 depends
on Wave 1). So the Wave 1 tracer cannot compile or pass its required analyzer
gate before its dependency (Wave 2) executes — circular dependency, breaks
tracer-first TDD chain.

**Fix (checker-provided):** Move creation of `Tokens.inputModeIdleTimeoutSec`
into 32-01 Task 1 (the tokens file is already in that task's `files` list),
and remove it from 32-02 Task 1's scope and acceptance criteria. Keep 32-02
responsible only for `tabArrowRadius`, `tabArrowWidth`, `hintFadeDuration`.
This restores the stated Wave 1 → Wave 2 dependency order.

### Warning 1 — `claude_md_compliance` (all 3 plans)

**Description:** `CLAUDE.md` requires `///` documentation for every public
class, mixin, and non-trivial function, plus inline rationale for non-obvious
timer/lifecycle logic. The plans create public `InputModeDetector`,
`InputMode`, `ArrowDirection`, `TabArrowButton`, `InputModeHint`,
`OptionListNavigationOverlay`, and introduce timer/close lifecycle behavior,
but their actions and acceptance criteria do not require these comments.

**Fix (checker-provided):** Add explicit acceptance criteria to the relevant
tasks requiring Dart `///` doc comments for all new public types/non-trivial
public APIs and rationale comments for injected-clock use, timer cancellation,
panel-close lifecycle, and the no-second-blur composition boundary.

## VERBATIM iter6 revision prompt (spawn gsd-planner with this, do NOT re-derive)

Spawn parameters:
- `Agent(prompt=<below>, subagent_type="gsd-planner", model="opus", description="Revise Phase 32 plans iter 6")`
- `run_in_background=false` (sync)
- After spawn, STOP and wait for return (orchestrator rule — no concurrent work).

---REVISION-PROMPT-START---
<revision_context>
**Phase:** 32 — navigation-interaction-polish (v4.5)
**Mode:** iter 6 targeted revision — DO NOT replan from scratch. iter5 plans are structurally sound; fix ONLY the 1 blocker + 1 warning below.

**Background:** iter1-5 progression: 6→2→2→0-structurally-confirmed(iter4)→1+1(iter5 re-check). Converging (issue count DROPPING 3→1 blocker), not stalling. iter5 fixed the 3 iter4 blockers + 1 warning (grep gate `$?` pipeline → direct conditional; singleton test seam `@visibleForTesting forTest/resetInstance` + injectable `DateTime Function() clock` + isolated instances; OptionListNavigationOverlay child-composition mount; panel-close `onPanelClosed` hook). iter5 re-check found 1 NEW blocker + 1 warning (different issues — convergence as fixes surface adjacent issues). These are concrete + narrow — make targeted edits, preserve everything else.

<files_to_read>
- D:/simple_player_flutter/.planning/phases/32-navigation-interaction-polish/32-01-PLAN.md (Wave 1 TRACER — has blocker 1: needs Tokens.inputModeIdleTimeoutSec creation moved here)
- D:/simple_player_flutter/.planning/phases/32-navigation-interaction-polish/32-02-PLAN.md (Wave 2 — has blocker 1: remove Tokens.inputModeIdleTimeoutSec from scope; shares warning 1)
- D:/simple_player_flutter/.planning/phases/32-navigation-interaction-polish/32-03-PLAN.md (Wave 3 — shares warning 1)
- D:/simple_player_flutter/.planning/phases/32-navigation-interaction-polish/32-RESEARCH.md (MEDIUM confidence; Validation Architecture L353+; Pitfalls 1-5, Patterns 1-4)
- D:/simple_player_flutter/.planning/phases/32-navigation-interaction-polish/32-PLAN-OUTLINE.md (wave/coverage matrix)
- D:/simple_player_flutter/CLAUDE.md (Tokens.*, ValueNotifier, no Provider, debugPrint, file<500 lines, no !/late/as, @visibleForTesting idioms, conventional commits, Comment Policy)
- D:/simple_player_flutter/.planning/ROADMAP.md (Phase 32 section: 7 success criteria, blocking constraints)
- D:/simple_player_flutter/.planning/REQUIREMENTS.md (NAV-01..07)
</files_to_read>

<checker_issues_to_fix>
```yaml
issues:
  - plan: "32-01"
    dimension: "dependency_correctness"
    severity: "blocker"
    task: 1
    description: >-
      Task 1 uses Tokens.inputModeIdleTimeoutSec in the Wave 1
      InputModeDetector default, but 32-02 Task 1—dependent on 32-01—is the
      task that creates that token. The Wave 1 tracer cannot compile or pass
      its analyzer verification before Wave 2 executes.
    fix_hint: >-
      Create Tokens.inputModeIdleTimeoutSec in 32-01 Task 1 and remove that
      token from 32-02 Task 1's scope and acceptance criteria. Leave the
      visual tab/hint tokens in 32-02.

  - plan: null
    dimension: "claude_md_compliance"
    severity: "warning"
    description: >-
      Plans create public types and non-trivial timer/lifecycle behavior but
      do not explicitly require the Dart doc comments and rationale comments
      mandated by CLAUDE.md.
    fix_hint: >-
      Add task acceptance criteria requiring /// documentation for new public
      types and APIs, plus inline why-comments for injected-clock, timer
      cancellation, panel-close, and single-blur decisions.
```
</checker_issues_to_fix>

<preserve_constraints>
The following iter4+iter5 fixes and Phase 32 hard constraints MUST be preserved (do NOT regress):
1. 32-01 Task 0 baseline-gen (pre-tracer, runs at execute startpoint on clean Phase 31 tree, COMMITS immutable artifact 32-baseline-failures.txt) — iter4 structural fix, KEEP.
2. 32-01 Task 2 grep gate — iter5 fixed to direct `if git grep ...; then ... else status=$?; if [ "$status" -eq 1 ] PASS / else FAIL exit "$status" fi` conditional; pathspec `':(exclude)test/**' 'lib/**'` preserved — KEEP the iter5 form, do NOT revert to the broken `$?` pipeline.
3. 32-03 consumption-only 6-step gate (CONSUMES the pre-committed baseline artifact, does NOT regenerate) — iter4 structural fix, KEEP.
4. 32-01 Task 1 singleton test seam — iter5 added `@visibleForTesting InputModeDetector.forTest({...})` factory + `@visibleForTesting resetInstance()` + private constructor with injectable `DateTime Function() clock` (default `DateTime.now`) + `recordPointerActivity`/timer callback read `_clock()` + singleton lifecycle rules (13 tests use isolated `forTest` instances, production `instance` never disposed) + Test 13 (panel-close cancellation) — KEEP all iter5 test-seam additions.
5. 32-03 Task 1 OptionListNavigationOverlay child-composition mount — iter5 unified to `OptionListNavigationOverlay(child: SingleChildScrollView(...))` with overlay solely owning the Stack — KEEP this contract, do NOT revert to the contradictory sibling/child dual model.
6. 32-01/02 panel-close `onPanelClosed` hook — iter5 added (cancels gamepad-detection + glow-reset timers, resets arrowGlow to null, does NOT dispose the singleton; wired in 32-02 `_onIsOpenChanged` when isOpen flips false) + threat T-32-06/T-32-10P — KEEP.
7. NAV-04 + NAV-07 atomic in 32-01 same wave (←/→ escape to KeyboardHandler → seek ±5s regression prevention).
8. No new BackdropFilter in option-list overlay (NAV-05: Container(color: Tokens.bgGlass)).
9. No new FocusTraversalGroup (would break settings_focus_navigation_test.dart L173-186 >=4 assertion).
10. Tracer-first: 32-01 Task 1 type="tracer" tdd=true.
11. threat_model STRIDE in each PLAN (arrow-leak-to-seek=Tampering, timer-after-dispose=DoS, nested-blur=DoS).
12. D-01..09 locked decisions honored (heuristic NOT key-routing; onPointerHover primary; InputMode preference/effective split; single blur owner; gameButton12/13 kept; zero new deps/FFI; NAV-04+07 atomic; no new FocusTraversalGroup; shortcuts tab pointer-only toggle).
13. Plan 03 autonomous=FALSE with checkpoint:human-verify (Steam Input dual-mode + profile raster A/B).
</preserve_constraints>

<revision_instructions>
Make TARGETED edits to fix ONLY the 2 issues. Do NOT replan, do NOT restructure waves, do NOT change requirements mapping. For each fix:

- **Blocker 1 (dependency_correctness, 32-01 Task 1 + 32-02 Task 1):** Move creation of `Tokens.inputModeIdleTimeoutSec` into 32-01 Task 1 (the tokens file is already in that task's `files` list), and remove it from 32-02 Task 1's scope and acceptance criteria. 32-02 keeps only `tabArrowRadius`, `tabArrowWidth`, `hintFadeDuration`. This restores Wave 1 → Wave 2 dependency order (Wave 1 tracer can compile before Wave 2 executes). Update both plans' task action + acceptance_criteria + must_haves accordingly. The InputModeDetector production default `idleTimeout=Duration(seconds: Tokens.inputModeIdleTimeoutSec)` in 32-01 Task 1 now references a token created in the SAME task — no cross-wave dependency.

- **Warning 1 (claude_md_compliance, all 3 plans):** Add explicit acceptance criteria to the relevant tasks requiring: (a) `///` documentation for all new public types (InputModeDetector, InputMode, ArrowDirection, TabArrowButton, InputModeHint, OptionListNavigationOverlay) and non-trivial public APIs; (b) inline why-comments for injected-clock use (`fakeAsync` advances `Timer` but NOT `DateTime.now()` — that's WHY the clock is injected), timer cancellation, panel-close lifecycle, and single-blur composition boundary. Reference CLAUDE.md "Comment Policy (MANDATORY — write comments WHILE coding)" section.

Commit each plan's fix as an isolated atomic commit (conventional: `docs(32): revise plan 0X per checker iter 6 — <short rationale>`), matching the iter1-5 commit style (iter1 `85e6696`, iter2 `3689329`, iter3 `d2c58ad`, iter4 `5671e95`, iter5 `5b094ce`/`347d149`/`143b3d8`). Do NOT touch STATE.md / ROADMAP.md / lib/ (planner-revision is isolated to .planning/phases/32-*/). commit_docs=true authorized.
</revision_instructions>

<expected_output>
Return:
1. A concise per-plan summary of what changed (which task / action / acceptance_criteria was edited, before→after gist for each of the 2 fixes).
2. Commit SHAs of the atomic revision commits.
3. Self-verification: confirm each of the 2 checker issues is resolved AND all 13 preserve_constraints are intact.
4. `## PLANNING COMPLETE (iter 6 revised)` marker.
</expected_output>
</revision_context>
---REVISION-PROMPT-END---

## VERBATIM checker prompt (unchanged from iter4 — same 12 Phase 32 hard-constraint checks)

Spawn parameters:
- `Agent(prompt=<below>, subagent_type="gsd-plan-checker", model="sonnet", description="Re-verify Phase 32 plans iter 6")`
- `run_in_background=false` (sync)
- After spawn, STOP and wait for return.

This prompt is UNCHANGED from `32-CHECKER-CHECKPOINT.md` "## VERBATIM constructed checker prompt" — the 12 Phase 32 hard constraints are the same (the plans must still satisfy all of them after iter6 edits). Reproduced verbatim below for self-contiguity.

---CHECKER-PROMPT-START---
<verification_context>
**Phase:** 32
**Phase Goal:** Add end-cap rounded L/R tab arrows, input-mode-aware hint substitution (keyboard vs gamepad), and top/bottom thin-glass option-list arrows with keyboard glow feedback — the only new v4.5 infrastructure lives here.
**Mode:** standard

<files_to_read>
- D:/simple_player_flutter/.planning/phases/32-navigation-interaction-polish/32-PLAN-OUTLINE.md (wave/plan map, NAV coverage matrix, dependency graph)
- D:/simple_player_flutter/.planning/phases/32-navigation-interaction-polish/32-01-PLAN.md (Wave 1 TRACER — NAV-02, NAV-04, NAV-07; atomic)
- D:/simple_player_flutter/.planning/phases/32-navigation-interaction-polish/32-02-PLAN.md (Wave 2 — NAV-01, NAV-03)
- D:/simple_player_flutter/.planning/phases/32-navigation-interaction-polish/32-03-PLAN.md (Wave 3 — NAV-05, NAV-06; blocking checkpoint)
- D:/simple_player_flutter/.planning/ROADMAP.md (Phase 32 section ~L130-146: goal, 7 success criteria, blocking constraints)
- D:/simple_player_flutter/.planning/REQUIREMENTS.md (NAV-01..07 ~L39-47)
- D:/simple_player_flutter/.planning/phases/32-navigation-interaction-polish/32-RESEARCH.md (MEDIUM confidence; Validation Architecture L353+; Pattern 1-4, Pitfall 1-5, Binding Impact Surface, Open Questions)
- D:/simple_player_flutter/CLAUDE.md (Tokens.*, ValueNotifier, no Provider, debugPrint, Chinese comments OK, conventional commits, file<500 lines, no !/late/as)
</files_to_read>

**Phase requirement IDs (MUST ALL be covered):** NAV-01, NAV-02, NAV-03, NAV-04, NAV-05, NAV-06, NAV-07

**Project instructions:** Read ./CLAUDE.md — verify plans honor project guidelines.
**Project skills:** Check .claude/skills/ directory if exists — verify plans account for project skill rules.

<phase32_specific_checks>
Beyond standard plan-quality checks (frontmatter, tasks with read_first/action/verify/acceptance_criteria, must_haves, threat_model, waves, dependencies), verify these Phase 32 hard constraints:

1. **Requirement coverage:** NAV-01..07 all mapped to plan frontmatter `requirements` field. Planner claims all 7 covered — verify in each PLAN.md frontmatter and outline coverage matrix.

2. **Tracer-first:** 32-01-PLAN.md Task 1 has `type="tracer"` and `tdd=true`.

3. **NAV-04 + NAV-07 atomic:** Both requirements in 32-01 (same plan, same wave). Deleting `gameButtonLeft1`/`gameButtonRight1` bindings AND single-root `Focus(onKeyEvent: _handleKeyEvent)` catching all arrows MUST land together — else ←/→ escapes to KeyboardHandler → seek ±5s regression.

4. **grep gate executable:** 32-01 contains the gate `git grep -nE 'gameButtonLeft1|gameButtonRight1' -- ':(exclude)test/**' 'lib/**'` returning zero. Run it to confirm it is executable AND passes (planner deleted the bindings in the plan; verify the plan's acceptance_criteria includes this gate).

5. **threat_model present:** Each PLAN.md has a `<threat_model>` block covering STRIDE: arrow-leak-to-seek=Tampering, timer-after-dispose=DoS, nested-blur=DoS.

6. **No new BackdropFilter in option-list overlay (NAV-05):** 32-03's `option_list_navigation_overlay.dart` uses `Container(color: Tokens.bgGlass)`, NOT a second BackdropFilter (Pitfalls 3+5).

7. **No new FocusTraversalGroup:** Plans don't add FocusTraversalGroup (would break `settings_focus_navigation_test.dart` L173-186 >=4 assertion).

8. **Stale fake repair:** 32-01 repairs `settings_focus_navigation_test.dart` L16-21 stale fake (initiallyPlaying→initialState) — verify it's in a task's action/acceptance_criteria.

9. **Live-verify grep targets + test paths concrete:** New test files named in plans: `input_mode_detector_test.dart`, `settings_tab_strip_test.dart`, `input_mode_hint_test.dart`, `option_list_navigation_overlay_test.dart`. Deleted/replaced: `settings_overlay_shell_test.dart` L574-651 gameButton tests. Verify these are concrete intentions in plan tasks.

10. **Plan 03 blocking checkpoint:** 32-03 has `autonomous=FALSE` with a `checkpoint:human-verify` gate for Windows Steam Input dual-mode + profile raster A/B (mirrors 31-03 Task 2 structure).

11. **Locked decisions honored:** D-01..09 (heuristic NOT key-routing; onPointerHover primary; InputMode preference/effective split; single blur owner; gameButton12/13 kept; zero new deps/FFI; NAV-04+07 atomic; no new FocusTraversalGroup; shortcuts tab pointer-only toggle) — verify plans don't violate.

12. **VALIDATION.md note:** `32-VALIDATION.md` does NOT exist yet (§5.5 skipped during checkpoint-resume). This is an orchestrator gap, NOT a plan defect — do NOT block on it. Flag as INFO/WARNING at most. The orchestrator creates it post-verify from RESEARCH.md ## Validation Architecture.
</phase32_specific_checks>
</verification_context>

<expected_output>
- ## VERIFICATION PASSED — all checks pass (proceed to step 13)
- ## ISSUES FOUND — structured issue list with BLOCKER / WARNING severity (triggers revision loop)
</expected_output>
---CHECKER-PROMPT-END---

## Post-iter6 procedure (checker → PASSED → post-PASS / ISSUES → AskUserQuestion)

After the iter6 checker returns:

1. **`## VERIFICATION PASSED`:** proceed to post-PASS procedure (see `32-CHECKER-CHECKPOINT.md` "## Post-spawn procedure" steps 3-7, UNCHANGED — create `32-VALIDATION.md`, update STATE.md frontmatter + ROADMAP, cleanup 4 one-time artifacts including THIS file, commit, tell user `/clear` → `/gsd-execute-phase 32`).

2. **`## ISSUES FOUND` (iter 7 territory):** Do NOT auto-spawn iter 7. Use `AskUserQuestion` to offer:
   - (a) iter 7 targeted revision — ONLY if new issues are concrete + narrow + budget allows + convergence continues (issue count still dropping). Recommend this only if iter7 issues are as narrow as iter6's (1 dependency-cycle + 1 docs warning).
   - (b) Proceed anyway — accept documented residual, go to post-PASS. Recommend this if iter7 issue count ≥ iter6's (stall detected) OR if issues are narrow verify-gate gaps (not code defects).
   - (c) Abandon — drop Phase 32 plans.
   - **Stall check (CRITICAL):** if iter7 issue count ≥ iter6's (1 blocker), the plan is unlikely to fully converge. Recommend (b) Proceed anyway or (c) Abandon over (a) iter7 — at some point the residual is acceptable for a shell-only verify gate (the iter4 precedent: residual_note is acceptable when structurally mitigated + low-risk).

## One-time artifacts to delete after checker passes (post-PASS step)

- `32-PLAN-CHECKPOINT.md` (untracked — planner-spawn checkpoint, superseded)
- `32-RESEARCH-CHECKPOINT.md` (untracked — research-spawn checkpoint, superseded)
- `32-CHECKER-CHECKPOINT.md` (TRACKED — use `git rm`; iter4 checker checkpoint, superseded by iter6)
- `32-ITER6-CHECKPOINT.md` (this file — TRACKED after this commit; iter6 checkpoint, delete after PASSED)

All four are one-time artifacts. Post-PASS deletes them to close the loop. Do NOT delete `./.continue-here.md` (repo root) — unrelated v1.6-era file, user decides.

## STATE.md staleness (intentional, deferred to post-PASS)

STATE.md is currently `M` (modified, stale research-only-window frontmatter, uncommitted) — per HANDOFF.json decision "STATE.md left stale this session, correction deferred to post-PASS" (avoid context-budget risk of STATE body surgery). The frontmatter shows `completed_phases: 3` / `percent: 43` but actual is 4 / ~57 (body L318 11th-resume entry corrected, frontmatter not). This iter6 checkpoint is the AUTHORITATIVE current-state record; STATE.md full correction happens in post-PASS step (update frontmatter `status: planned`, `completed_plans` 9→12, `total_plans` 10→13, `percent` 43→~57, + Session Continuity entry for iter1-6).

## Next-window lean procedure (summary)

1. `/clear` (fresh 200K window).
2. Read THIS file (`32-ITER6-CHECKPOINT.md`) — frontmatter + STATUS + Fresh-window lean procedure + the 2 verbatim prompts.
3. Spawn `gsd-planner` (opus, sync, `run_in_background=false`) with the VERBATIM iter6 revision prompt (---REVISION-PROMPT-START--- to ---REVISION-PROMPT-END---). Expected: `## PLANNING COMPLETE (iter 6 revised)`.
4. Spawn `gsd-plan-checker` (sonnet, sync, `run_in_background=false`) with the VERBATIM checker prompt (---CHECKER-PROMPT-START--- to ---CHECKER-PROMPT-END---). Expected: `## VERIFICATION PASSED` or `## ISSUES FOUND`.
5. PASSED → post-PASS (reference `32-CHECKER-CHECKPOINT.md` post-spawn steps 3-7 + cleanup THIS file). ISSUES → AskUserQuestion (iter7/proceed/abandon) with stall check.

**Budget:** fresh ~30% baseline + iter6 chain ~8.5% + post-PASS ~5% = ~43% peak, ~57% margin. Safe.
