---
phase: 15-contract-freeze-baseline-audit
plan: 01
subsystem: infra
tags: [ripgrep, bash, static-analysis, contract-testing, baseline-audit]

# Dependency graph
requires:
  - phase: 15-contract-freeze-baseline-audit
    provides: D-numbered locked decisions (D1-D23) from discuss-phase, RESEARCH.md pitfalls
provides:
  - "tool/audit/inventory.sh — reproducible, script-based BASE-02 call-site baseline (logger usage, MemoryMonitor calls, openGeneration references)"
  - "tool/audit/contract_completeness.sh — dynamic per-ISP-interface contract-tag completeness check (7 interfaces, ready to gate Plan 02's contract authoring)"
  - "Committed BASELINE-AUDIT.json/.md snapshot with LIVE numbers (84/28 logger call sites/files, not the stale 121/30)"
  - "v2.1-pre-snapshot watermark on all 7 .planning/codebase/*.md files"
  - "PROJECT.md state-machine description corrected from stale '9 状态 ~40 边' to the frozen 6-state orthogonal model + LifecyclePhase"
affects: [15-contract-freeze-baseline-audit-plan-02, 15-contract-freeze-baseline-audit-plan-03, phase-17-enforce-gate]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pure-counting-function / print-exit-logic separation in bash audit scripts (D23) to support a future Phase 17 --enforce flag without rewriting counting logic"
    - "rg/grep-P backend abstraction shim (_backend_match_only/_backend_files_only/_backend_lines_excluding) for environments where ripgrep is not a real standalone binary"
    - "Sorted-array JSON serialization for byte-identical reproducibility (excluding generated_at timestamp)"

key-files:
  created:
    - tool/audit/inventory.sh
    - tool/audit/contract_completeness.sh
    - tool/audit/README.md
    - .planning/phases/15-contract-freeze-baseline-audit/15-BASELINE-AUDIT.json
    - .planning/phases/15-contract-freeze-baseline-audit/15-BASELINE-AUDIT.md
  modified:
    - .planning/PROJECT.md
    - .planning/codebase/ARCHITECTURE.md
    - .planning/codebase/CONCERNS.md
    - .planning/codebase/TESTING.md
    - .planning/codebase/STACK.md
    - .planning/codebase/STRUCTURE.md
    - .planning/codebase/CONVENTIONS.md
    - .planning/codebase/INTEGRATIONS.md

key-decisions:
  - "Logger call-site baseline is 84 call sites / 28 files (LIVE), not the historical 121/30 figure — that number was stale and is never hardcoded in the script"
  - "MemoryMonitor.start/.snapshot count excludes lib/kernel/utils/memory_monitor.dart itself (self-referential doc-comment usage examples would otherwise be false-positively counted)"
  - "openGeneration references scanned recursively across all of lib/ rather than assumed to live only in fvp_engine.dart — playback_navigator.dart independently has its own _openGeneration counter"
  - "contract_completeness.sh includes VolumeControl as the 7th ISP interface (matches media_engine.dart's implements clause), correcting D14's original 6-group enumeration in CONTEXT.md"
  - "engine_state_view.dart dynamically reports 15 members (13 ValueNotifier getters + mediaInfo + dispose), not the stale 12 in CONTEXT.md"
  - "All 6 capability interfaces (not EngineStateView) correctly report 'missing contracts' at this stage since Plan 02 (which writes the contracts) has not run yet — this is the expected, correct result"

requirements-completed: [BASE-02]

coverage:
  - id: D1
    description: "tool/audit/inventory.sh produces a reproducible, script-based BASE-02 call-site baseline (logger/MemoryMonitor/openGeneration), never hardcoding historical counts"
    requirement: "BASE-02"
    verification:
      - kind: automated_ui
        ref: "bash tool/audit/inventory.sh (exit 0, valid JSON+MD written)"
        status: pass
      - kind: automated_ui
        ref: "diff <(bash tool/audit/inventory.sh --stdout | grep -v generated_at) <(bash tool/audit/inventory.sh --stdout | grep -v generated_at) — empty diff"
        status: pass
    human_judgment: false
  - id: D2
    description: "tool/audit/contract_completeness.sh dynamically extracts and checks D2 contract tags across all 7 ISP interfaces (including VolumeControl), correctly reporting engine_state_view.dart as 15 members"
    verification:
      - kind: automated_ui
        ref: "bash tool/audit/contract_completeness.sh; test $? -le 1 — exit 1, engine_state_view.dart reports 15 members"
        status: pass
    human_judgment: false
  - id: D3
    description: "All 7 .planning/codebase/*.md files watermarked as v2.1-pre-snapshot; PROJECT.md stale '9 状态 ~40 边' description corrected to the frozen 6-state model + LifecyclePhase"
    verification:
      - kind: automated_ui
        ref: "grep -l 'v2.1 前快照' .planning/codebase/*.md | wc -l == 7; grep -cE '9 态|~40 边|9 个状态' .planning/PROJECT.md == 0"
        status: pass
    human_judgment: false

duration: 55min
completed: 2026-07-17
status: complete
---

# Phase 15 Plan 01: Contract Freeze Baseline Audit Summary

**Reproducible bash+ripgrep baseline audit scripts replacing the stale "121 call sites/30 files" logger figure with a live-verified 84/28, plus a dynamic 7-interface contract-completeness checker and stale-map watermarking.**

## Performance

- **Duration:** 55 min
- **Started:** 2026-07-16T21:05:00Z
- **Completed:** 2026-07-17T05:39:00Z (across compaction boundary)
- **Tasks:** 3
- **Files modified:** 13 (5 created + 8 modified)

## Accomplishments
- `tool/audit/inventory.sh` — script-based, reproducible BASE-02 call-site baseline covering package:logger-style calls, `MemoryMonitor.start()/.snapshot()` production sites, and `openGeneration`/`_openGeneration` references, with byte-identical reproducibility verified across two consecutive runs
- `tool/audit/contract_completeness.sh` — dynamic per-member D2-contract-tag completeness check across all 7 MediaEngine ISP interfaces (correctly including the previously-omitted `VolumeControl`), proving dynamic (not hand-counted) extraction by correctly reporting `engine_state_view.dart` at 15 members
- Committed `15-BASELINE-AUDIT.json`/`.md` snapshot with LIVE numbers (84 logger call sites / 28 files, 2 MemoryMonitor call sites, 2 openGeneration files) as the D21 rerunnable-script-plus-snapshot artifact
- All 7 `.planning/codebase/*.md` files watermarked as pre-v2.1-refactor snapshots requiring LIVE/codegraph verification (D22)
- `.planning/PROJECT.md`'s stale "9 状态 ~40 边" state-machine description corrected to the frozen 6-state orthogonal `MediaState` model plus the new orthogonal `LifecyclePhase`

## Task Commits

Each task was committed atomically:

1. **Task 1: Build tool/audit/inventory.sh** - `d72e0d4` (feat)
2. **Task 2: Build tool/audit/contract_completeness.sh** - `97818f4` (feat)
3. **Task 3: Watermark stale maps + correct PROJECT.md** - `54804f1` (docs)

**Plan metadata:** committed as part of this SUMMARY (see below)

## Files Created/Modified
- `tool/audit/inventory.sh` - BASE-02 reproducible call-site baseline script (rg/grep-P backend shim, sorted-array JSON output, --stdout flag for reproducibility testing)
- `tool/audit/contract_completeness.sh` - dynamic ISP-interface contract-tag completeness checker across 7 interfaces
- `tool/audit/README.md` - usage docs for both scripts + D23 --enforce evolution placeholder + documented rg/grep-P fallback behavior
- `.planning/phases/15-contract-freeze-baseline-audit/15-BASELINE-AUDIT.json` - machine-readable baseline snapshot (84/28 logger, 2/2 MemoryMonitor, 2 openGeneration files)
- `.planning/phases/15-contract-freeze-baseline-audit/15-BASELINE-AUDIT.md` - human-readable baseline table (all numbers sourced from JSON, zero hand-typed counts)
- `.planning/PROJECT.md` - corrected stale state-machine description (line 36)
- `.planning/codebase/ARCHITECTURE.md`, `CONCERNS.md`, `TESTING.md`, `STACK.md`, `STRUCTURE.md`, `CONVENTIONS.md`, `INTEGRATIONS.md` - v2.1-pre-snapshot watermark added at top of each

## Decisions Made
- Used the LIVE-verified 84/28 logger figure (not the stale historical 121/30) as the script's live output, never hardcoded — this is the entire point of BASE-02
- Excluded `lib/kernel/utils/memory_monitor.dart` from its own call-site count (self-referential doc-comment usage examples would otherwise inflate the count)
- Scanned all of `lib/` recursively for `openGeneration`/`_openGeneration` rather than assuming a single known file, correctly discovering 2 files (`fvp_engine.dart` and `playback_navigator.dart`)
- Included `VolumeControl` as the 7th ISP interface in `contract_completeness.sh`, correcting an omission in the original D14 6-group enumeration
- Confirmed all 6 capability interfaces correctly report "missing contracts" at this stage (expected pre-Plan-02 result, not a bug)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added rg/grep-P backend compatibility shim to both audit scripts**
- **Found during:** Task 1 (building `tool/audit/inventory.sh`)
- **Issue:** `rg` is not installed as a genuine standalone binary in this Windows Git-Bash environment — it exists only as an interactive bash function injected by Claude Code that shells out to the Claude binary, and is not exported to subshells/scripts by default. A standalone `bash tool/audit/inventory.sh` invocation (exactly what the plan's acceptance criteria run) failed with `rg: command not found`.
- **Fix:** Added `command -v rg` detection setting `AUDIT_BACKEND` to `"rg"` or `"grep"`, with three shim functions (`_backend_match_only`, `_backend_files_only`, `_backend_lines_excluding`) dispatching to either `rg --type dart`/`-g '!...'` syntax or `grep -rP`/`grep -rPl`/`grep -rnP --exclude=...` (PCRE mode) as appropriate. Verified both backends produce identical counts (84/28 logger, 2/2 MemoryMonitor, 2 openGeneration files) before finalizing. Applied independently to both `inventory.sh` and `contract_completeness.sh`. Documented in `tool/audit/README.md`.
- **Files modified:** tool/audit/inventory.sh, tool/audit/contract_completeness.sh, tool/audit/README.md
- **Verification:** `bash tool/audit/inventory.sh` and `bash tool/audit/contract_completeness.sh` both run standalone with correct, backend-agnostic output
- **Committed in:** d72e0d4, 97818f4 (part of Task 1/2 commits)

**2. [Rule 1 - Bug] Suppressed false-fatal exit on legitimate zero-match grep/rg results**
- **Found during:** Task 1 (debugging `bash tool/audit/inventory.sh` silent EXIT=1 failure)
- **Issue:** Under `set -euo pipefail`, a legitimate zero-match result (e.g., the `logServices`/`logUi` logger prefixes currently have 0 usages in the codebase) causes `rg`/`grep` to return exit code 1, which propagated up through command substitution and terminated the whole script — even though zero matches is a correct, expected result, not an error.
- **Fix:** Appended `|| true` inside each `_backend_*` shim function body so a legitimate "zero matches" result is absorbed rather than treated as fatal.
- **Files modified:** tool/audit/inventory.sh
- **Verification:** `bash tool/audit/inventory.sh` now exits 0 and correctly reports `logServices: 0, logUi: 0` in the breakdown rather than crashing
- **Committed in:** d72e0d4 (part of Task 1 commit)

**3. [Rule 1 - Bug] Fixed JSON array indentation nesting**
- **Found during:** Task 1 (reviewing generated JSON output)
- **Issue:** `"locations": [...]` array items were emitted at the same indent level as their own opening/closing brackets rather than nested one level deeper — still valid JSON but visually inconsistent with the rest of the output.
- **Fix:** Changed the `indent` parameter passed to `_to_json_array()` inside `format_json()` from 4 spaces to 6 spaces, correctly nesting array items under their parent key.
- **Files modified:** tool/audit/inventory.sh
- **Verification:** `bash tool/audit/inventory.sh --stdout | head -30` shows clean, properly nested JSON; confirmed still valid via `node -e "JSON.parse(...)"`
- **Committed in:** d72e0d4 (part of Task 1 commit)

---

**Total deviations:** 3 auto-fixed (2 Rule 1 bug fixes, 1 Rule 3 blocking-issue fix)
**Impact on plan:** All three fixes were necessary for the scripts to run standalone and produce correct/valid output, matching the plan's own acceptance criteria (`bash tool/audit/inventory.sh` must exit 0). No scope creep — script design and interfaces are unchanged from the plan's specification; only execution-environment compatibility was addressed.

## Issues Encountered
- Plan's `read_first` section referenced `lib/kernel/models/media_state.dart`, but the actual file lives at `lib/kernel/engine/media_state.dart`. Purely informational context-gathering discrepancy — did not block any task, worked around by reading the correct path directly.
- Initial `Edit` call on `.planning/PROJECT.md` failed with "File has not been read yet" because the file had only been viewed via `Bash sed`, not the `Read` tool. Resolved by calling `Read` on the file first, then re-issuing the `Edit` call successfully.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- BASE-02 satisfied: reproducible, script-based call-site baseline committed with LIVE numbers, no hardcoded historical figures anywhere in the scripts or docs
- `tool/audit/contract_completeness.sh` is ready to serve as Plan 02's acceptance gate once contracts are authored — currently correctly reports all 6 capability interfaces as missing contracts (expected pre-Plan-02 state)
- Stale codebase maps clearly flagged (D22) so future phases don't trust their specific paths/class names without LIVE verification
- No blockers for Plan 02 (contract authoring) or Plan 03 (contract tests)
- This plan touched zero `lib/` source files, so `flutter analyze` is unaffected by construction

---
*Phase: 15-contract-freeze-baseline-audit*
*Completed: 2026-07-17*

## Self-Check: PASSED

All created files verified present on disk (tool/audit/inventory.sh, tool/audit/contract_completeness.sh, tool/audit/README.md, 15-BASELINE-AUDIT.json, 15-BASELINE-AUDIT.md, 15-01-SUMMARY.md, PROJECT.md, and all 7 .planning/codebase/*.md files). All recorded commit hashes (d72e0d4, 97818f4, 54804f1, 0a69242) confirmed present in git log.
