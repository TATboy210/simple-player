---
phase: 28-settings-shell-split-legacy-deletion
plan: 01
status: paused-pre-spawn
created: 2026-07-26
attempts: 3
halt_reason: orchestrator context exhaustion before spawn (67% pre-spawn, same threshold as 2nd attempt)
head: eee0aac
---

# Phase 28 Execute Checkpoint — Pre-spawn (2nd attempt)

## Current State

- **Working tree**: clean except `M .planning/STATE.md` (state.begin-phase update, expected)
- **HEAD**: `eee0aac` (no new commits since plan creation)
- **Plan**: `28-01-PLAN.md` (3 tasks, 1 wave, autonomous, tracer-first) — **not executed**
- **No SUMMARY**, `settings_panel.dart` still exists, no extracted files created
- **Executor halted safely with zero changes** (gsd-executor sonnet, 52K tokens, 3 tool uses)

## Root Cause — Fresh subagent injection overhead

Executor reported 89% context after loading only `28-01-PLAN.md` + `STATE.md`.
`subagent_tokens=52453` (52K) vs reported 89% implies the fresh subagent window
is **far smaller than 200K** (~60K if 52K ≈ 87%). Injection budget consumed:

- `execute-plan.md` workflow (~25K, similar scale to `execute-phase.md` 1676 lines)
- `summary.md` + `checkpoints.md` + `tdd.md` templates (~10K)
- Project `CLAUDE.md` (~15K — full architecture + Dart rules + Context7 + codegraph)
- `STATE.md` (244 lines, v2.1→v4.5 full session history — high density)
- `PROJECT.md` + `config.json` + `.claude/skills/`
- gsd-executor agent definition system prompt

This is a **systemic GSD subagent injection issue**, not a Phase 28 problem.

## User Decision — Slim spawn mode (chosen)

Re-spawn `gsd-executor` (sonnet, sequential) with a **slimmed executor prompt**:

### Slim injection strategy

**Keep (required):**
- `28-01-PLAN.md` (the plan — has read_first lists, behaviors, acceptance criteria, grep gates)
- `execute-plan.md` workflow (execution protocol — cannot omit)
- `summary.md` template (SUMMARY format)
- `CLAUDE.md` project instructions (Tokens.*, debugPrint, no bang/late/as, strict analysis)

**Omit (reduce injection):**
- `STATE.md` — executor does NOT need v2.1→v4.5 session history. Orchestrator owns STATE writes; executor only needs "phase 28, plan 01, sequential mode" (already in prompt).
- `PROJECT.md` — executor does not need full project background
- `config.json` — executor does not need config
- `checkpoints.md` — `autonomous=true`, no checkpoint task, omit
- `tdd.md` — `tdd_mode=false`, omit (Task 1/2 tdd="true" is task-level RED-GREEN guidance, not capability hook)
- `.claude/skills/` — omit unless PLAN references a specific skill

**Also shorten** the orchestrator-injected `<files_to_read>` block to only the kept files.

### Risk assessment

If fresh subagent window is truly ~60K, even slimmed injection (~50K: execute-plan 25K + CLAUDE 15K + system prompt 10K) may still hit 80%+. **Slim spawn may halt again.**

## Fallback — if slim spawn halts again

**Switch to `--interactive` mode**: `/gsd-execute-phase 28 --interactive`

- Orchestrator (main session, 200K window) runs 3 tasks **inline** — no subagent spawning, no injection overhead
- 67% startup + 33% remaining (post-/clear) ≈ 66K available for actual work
- Each task ends with a user checkpoint — can pause between tasks
- Orchestrator already knows project specifics (Tokens, `D:/flutter/bin/flutter` full path, codegraph MCP, CLAUDE.md rules)
- Task 1+2 fit in 33%; if Task 3 exceeds budget, checkpoint and resume next window
- Most recoverable path — no subagent injection risk

## Next window procedure

```
1. /clear
2. /gsd-execute-phase 28
   - Orchestrator: read this checkpoint, apply slim injection strategy
   - If slim spawn halts again → present --interactive fallback to user
3. (If interactive) /clear → /gsd-execute-phase 28 --interactive
```

## What executor will do (when it succeeds)

Task 1 (tracer, tdd): extract `tab_strip.dart` from `settings_overlay_shell.dart`,
prove 7-tab selection end-to-end via existing `settings_overlay_shell_test.dart`.
Task 2 (tdd): extract `tab_content.dart` (IndexedStack + 7 tabs + 200ms opacity)
+ `panel_key_bindings.dart` (ESC/B/arrows/gamepad routing).
Task 3: delete `settings_panel.dart` (945 lines), grep gate `grep -r "SettingsPanel(" lib/ test/`
returns zero, update stale comments in `settings_button.dart`/`general_tab.dart`/`shortcuts_tab.dart`.
Each file <300 lines, shell <500 lines, pubspec unchanged, `D:/flutter/bin/flutter test` green.

## 3rd Attempt Halt (2026-07-26) — Orchestrator budget, zero spawn

- **User chose "Checkpoint, fresh window"** via AskUserQuestion (safest path).
- **Orchestrator at 67% before any work or spawn** — same threshold that triggered the 2nd attempt's halt at 68%. System reminder: "Avoid starting new complex work."
- **Budget math for slim spawn in this window**: orchestrator loading (execute-phase.md 1676 lines + STATE.md 250 lines + plan 200 lines + CLAUDE.md + system prompt + agent registry) already consumed 67%; remaining 33% cannot cover the full post-spawn flow (executor dispatch + return + spot-check + post-merge `flutter test` gate + verifier spawn + phase completion + STATE/ROADMAP writes).
- **Slim spawn subagent risk unchanged**: subagent effective window ~60K (per 2nd attempt: 52K tokens = 89%); slim injection ~50K (execute-plan 25K + CLAUDE 15K + system prompt 10K) → only ~9K for 3 refactor tasks. Likely halts again.
- **Zero code changes this attempt**: HEAD still `eee0aac`, working tree still `M .planning/STATE.md` + untracked checkpoint. Safe to pause.

### Recommendation for next fresh window

**`/clear` → `/gsd-execute-phase 28`** — fresh 200K window. Two viable paths:

1. **Slim spawn** (user's prior preference): apply slim injection (PLAN + CLAUDE + execute-plan + summary only; omit STATE/PROJECT/config/checkpoints/tdd). Works IF subagent window is larger than 2nd attempt's ~60K; still risks 80%+ halt.
2. **`--interactive` inline** (most recoverable, recommended given 3rd halt): orchestrator runs 3 tasks inline in main session. No subagent injection overhead. Fresh window has full budget for Task 1+2+3 + post-merge test gate. Each task ends with user checkpoint.

**Lean orchestrator tip for next window**: after `/clear`, read ONLY the checkpoint + `28-01-PLAN.md` + execute-phase.md. Skip re-reading full STATE.md (250 lines of v2.1→v4.5 session history) — the checkpoint carries the necessary state. Saves ~10K orchestrator budget for the post-spawn flow.
