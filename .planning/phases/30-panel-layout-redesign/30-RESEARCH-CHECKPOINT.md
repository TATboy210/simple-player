# Phase 30 — Research-Only Spawn Checkpoint

**Paused:** 2026-07-26
**Reason:** auto-mode safety classifier (kimi-k3) temporarily unavailable AND context window at 68% (32% remaining) — `feedback_gsd_context_budget_pause` pattern: write checkpoint, do not force spawn.
**Workflow:** `/gsd-plan-phase 30 --research-phase 30` (research-only mode, §5.0 falls through to "Spawn gsd-phase-researcher")

## State at pause

- `has_research` = **false** (no `30-RESEARCH.md` exists yet) → §5.0 auto-use-existing branch did NOT fire → spawn path confirmed
- `has_context` = true (`30-CONTEXT.md` exists, 8 CF + D-01..06 locked)
- `phase_status` = "Pending"
- `phase_req_ids` = `LAYOUT-01, LAYOUT-02, LAYOUT-03, LAYOUT-04, LAYOUT-05`
- `researcher_model` = **sonnet**
- `research_enabled` = true; `nyquist_validation_enabled` = true; `commit_docs` = true
- `context_window` = 200000 (< 500000 → NO cross-phase context enrichment needed)
- `agent-skills gsd-phase-researcher` query returned **empty** → `${AGENT_SKILLS_RESEARCHER}` placeholder resolves to empty string; no skill block to inject
- Research hook `fragment.inline` from `loop render-hooks plan:pre --raw` captured below, filled with actual values

## Paths (from INIT JSON)

| Field | Value |
|-------|-------|
| phase_dir | `D:/simple_player_flutter/.planning/phases/30-panel-layout-redesign` |
| context_path | `D:/simple_player_flutter/.planning/phases/30-panel-layout-redesign/30-CONTEXT.md` |
| state_path | `D:/simple_player_flutter/.planning/STATE.md` |
| roadmap_path | `D:/simple_player_flutter/.planning/ROADMAP.md` |
| requirements_path | `D:/simple_player_flutter/.planning/REQUIREMENTS.md` |
| research_path (target) | `D:/simple_player_flutter/.planning/phases/30-panel-layout-redesign/30-RESEARCH.md` |

## Resume action

In a fresh session (after `/clear`), spawn the researcher synchronously with the EXACT prompt below:

```
Agent(
  subagent_type="gsd-phase-researcher",
  model="sonnet",
  run_in_background=false,
  description="Research Phase 30",
  prompt=<FILLED_PROMPT_BELOW>
)
```

After the researcher returns `## RESEARCH COMPLETE`:
1. Verify `30-RESEARCH.md` exists on disk
2. If `commit_docs` is true and the researcher did not already commit, run:
   `node "C:/Users/35490/.claude/gsd-core/bin/gsd-tools.cjs" query commit "docs(30): create phase research" --files "D:/simple_player_flutter/.planning/phases/30-panel-layout-redesign/30-RESEARCH.md"`
3. Print the §5.1 Research-Only Early Exit summary and exit cleanly. Do NOT continue to planner / plan-checker / verifier — `RESEARCH_ONLY=true` skips all of them.

Re-run commands for diagnostics if needed:
- `node "C:/Users/35490/.claude/gsd-core/bin/gsd-tools.cjs" query init.plan-phase 30`
- `node "C:/Users/35490/.claude/gsd-core/bin/gsd-tools.cjs" loop render-hooks plan:pre --raw`

## Filled researcher prompt (copy verbatim into Agent `prompt`)

<objective>
Research how to implement Phase 30: panel-layout-redesign
Answer: "What do I need to know to PLAN this phase well?"
</objective>

<files_to_read>
- D:/simple_player_flutter/.planning/phases/30-panel-layout-redesign/30-CONTEXT.md (USER DECISIONS from /gsd-discuss-phase — 8 Carried-Forward CF-01..08 + D-01..06 are LOCKED, do NOT re-litigate)
- D:/simple_player_flutter/.planning/REQUIREMENTS.md (Project requirements — LAYOUT-01..05)
- D:/simple_player_flutter/.planning/STATE.md (Project decisions and history — Phase 28/29 complete records)
- D:/simple_player_flutter/.planning/ROADMAP.md (Phase 30 detail + v4.5 milestone context)
</files_to_read>

<additional_context>
**Phase description (from ROADMAP.md L62-74):**

### Phase 30: Panel Layout Redesign
**Goal**: Re-containerize the settings overlay to 16:9 / ~50% screen area with the General tab in the middle of the tab sequence and multi-monitor drag clamping.
**Depends on**: Phase 28 (split shell provides the sizing seam); Phase 29 (safe to iterate with always-pause active)
**Requirements**: LAYOUT-01, LAYOUT-02, LAYOUT-03, LAYOUT-04, LAYOUT-05
**Success Criteria** (what must be TRUE):
  1. Panel sized by `width = min(0.5 × screenW, screenH × 16/9)` clamped to `[400, 960]` — 16:9 as primary constraint, 50% area as secondary (PRODUCT decision固化 per LAYOUT-02)
  2. General (通用) tab rendered at the MIDDLE position of the 7-tab sequence (not first/last)
  3. Multi-monitor drag clamps to `display_enumerator` work-area (not `MediaQuery`); panel never lands on a non-primary monitor's bezel gap
  4. Panel upper/middle/lower vertical structure uses unified control-bar color (coordinated with VISUAL-01 in Phase 31)
  5. Size-assertion widget tests re-baselined to the 16:9 formula; existing tab-strip tests still green
**Blocking Constraints honored**: overlay mode (16:9 / 50% area, not standalone window); Windows primary; multi-monitor clamp via existing FFI (no new deps); Tokens.* (no hardcoded sizes)

**Phase requirement IDs (MUST address):** LAYOUT-01, LAYOUT-02, LAYOUT-03, LAYOUT-04, LAYOUT-05

**Project instructions:** Read ./CLAUDE.md (project root) — follow project-specific guidelines strictly:
- All visual values via `Tokens.*` (no hardcoded colors/fonts/spacing) — the `[400, 960]` clamp bounds MUST be promoted to named `Tokens.*` constants (e.g. `Tokens.panelWidthMin`, `Tokens.panelWidthMax`) per CF-06
- `debugPrint()` not `print()`; errors caught with `debugPrint` + graceful fallback (never silent `catch (_) {}`)
- Conventional commits; Chinese comments OK (existing codebase convention)
- ValueNotifier + ValueListenableBuilder (no Provider/Riverpod/Bloc)
- Strict Dart: avoid `!`/`late`/`as`; prefer `?.`/`??`/pattern matching; `final` locals; `required` ctor params
- Files < 500 lines, functions < 50 lines

**Project skills:** Check .claude/skills/ directory if it exists. Read SKILL.md files and account for project skill patterns.
</additional_context>

<research_focus>
This phase is flagged in ROADMAP.md L170 as "standard patterns (skip `--research-phase`)" but the user explicitly invoked `--research-phase 30`, so produce a real RESEARCH.md. Focus on what the planner needs to write concrete `<action>` / `<acceptance_criteria>` / `<read_first>` blocks:

1. **Sizing seam — verify ACTUAL current code** at `lib/ui/dialogs/settings/settings_overlay_shell.dart` around the sizing logic (CONTEXT.md says §172-179 but VERIFY the real line numbers and current formula — it may be `width = windowWidth × 0.8, clamp [400,600]` / `height = width × 0.8` + an 800px breakpoint from Phase 27). Document the EXACT current code the planner will replace.

2. **`display_enumerator` work-area FFI — verify the EXISTING interface** the planner will call for real-time drag clamping (D-03):
   - `lib/kernel/bridge/display_enumerator.dart` (abstract interface)
   - `lib/kernel/bridge/win32/win32_display_enumerator.dart` (Win32 EnumDisplayMonitors impl)
   - `lib/kernel/bridge/screen_utils.dart` + `lib/kernel/bridge/window_service.dart` (work-area FFI consumers)
   - Document the exact method signatures, return types, and how the existing fullscreen snap queries/caches work-area (D-03 says reuse the same path, NOT a parallel mechanism).

3. **Tab reorder seam — verify current tab order** at `lib/ui/dialogs/settings/tab_strip.dart` (CONTEXT.md says §36 comment "7 个 tab 图标 General/EQ/Audio/Video/Shortcuts/About/Performance") AND the `IndexedStack` child order in `lib/ui/dialogs/settings/tab_content.dart`. D-01 target sequence = `[EQ, Audio, Video, General, Shortcuts, About, Performance]` (General index 0 → 3). Document exact current order + the reorder edit.

4. **SC#5 test re-baseline targets** — locate `test/.../settings_responsive_integration_test.dart` and `test/.../settings_tab_content_test.dart`. Document the EXISTING size-assertion values (Phase 27 `height=width×0.8` + 800px breakpoint) that must be re-baselined to the 16:9 formula. Note the headless `flutter test` mdk.dll FFI caveat from memory (reference_mdk_dll_headless_test_failures) — ~57 pre-existing failures are NOT regressions;鉴别方法 = stash + re-run.

5. **Tokens promotion** — `lib/ui/theme/tokens.dart` (CONTEXT.md §12 `bgGlass` / §31 `glowOuterRing` / §57 `controlBarBg` etc.). Document where `Tokens.panelWidthMin = 400` / `Tokens.panelWidthMax = 960` should be added (find the existing panel/sizing token section to match style).

6. **Phase 30/31 boundary (D-02)** — researcher must confirm Phase 30 does structural color unification ONLY (same token across upper/middle/lower, keep `bgGlass`); `controlBarBg`/`controlBarBorderWhite`/`glowOuterRing` switch is Phase 31. Document the exact decoration code in `settings_overlay_shell.dart` upper/middle/lower structure that the planner unifies.

7. **Reversibility (D-04)** — the 16:9 + clamp formula change is rated `costly` to reverse (undo requires re-baselining SC#5 tests back to Phase 27 formula + restoring 800px breakpoint branch). Record this for the planner's reversibility gate.

Use Context7 MCP (`/wang-bin/fvp` for fvp, `/websites/api_flutter_dev` for Flutter API) ONLY if a specific API question arises (e.g., `IndexedStack` reorder semantics, `Stack` overlay positioning). Do NOT do broad library research — this phase reuses existing in-codebase patterns. Most answers come from reading the codebase files above.
</research_focus>

<locked_decisions_reminder>
The 8 Carried-Forward decisions (CF-01 size formula, CF-02 aspect ratio, CF-03 overlay mode, CF-04 display_enumerator FFI source, CF-05 General tab index 3, CF-06 tokens only, CF-07 vertical structure unify target, CF-08 always-pause live) and D-01..06 (tab reorder, Phase 30/31 boundary, real-time clamp, height=width×9/16 + abandon 800px breakpoint, resize re-clamp, keep RepaintBoundary) are LOCKED in CONTEXT.md. Research HOW to implement them, do NOT re-open WHAT was decided. If a locked decision looks wrong based on code evidence, flag it as a `## Risk` / `## Assumption` — do not silently override.
</locked_decisions_reminder>

<validation_architecture>
**Nyquist validation is ENABLED** (`nyquist_validation_enabled: true`). RESEARCH.md MUST include a `## Validation Architecture` section so the planner-time §5.5 step can lift it into `VALIDATION.md`. For Phase 30 this means:
- Identify the sampling-relevant signals: panel width/height at various screen sizes (4K 3840×2160, 1920×1080, 1366×768, small 800×600 — the four cases in CONTEXT.md `<specifics>`), General tab index, work-area clamp activation during drag.
- Specify what tests/assertions verify each Success Criterion (SC#1 size formula, SC#2 General middle position, SC#3 multi-monitor clamp, SC#4 vertical structure unify, SC#5 size-assertion re-baseline).
- Note the headless `flutter test` mdk.dll FFI caveat — which tests can run headless vs need a real Windows display.
</validation_architecture>

<output>
Write to: D:/simple_player_flutter/.planning/phases/30-panel-layout-redesign/30-RESEARCH.md

Return ONE of these markers as the LAST line of your response:
- `## RESEARCH COMPLETE` — RESEARCH.md written successfully
- `## RESEARCH BLOCKED` — blocker encountered (state what's blocked and what context is needed)
</output>
