---
phase: 16-diagnosticsbundle
plan: 05
subsystem: tool/audit
tags: [audit, grep-gate, size-budget, ci-automatable, strangler-fig]
dependency-graph:
  requires:
    - lib/kernel/adapter/kernel_adapter.dart (Plan 16-01)
    - lib/kernel/diagnostics/*.dart (Plan 16-02)
    - lib/kernel/engine/fvp_engine.dart (baseline, read live)
  provides:
    - tool/audit/phase16_gates.sh (GATE 1 D22, GATE 2 D27)
  affects: []
tech-stack:
  added: []
  patterns:
    - "Self-locating script (SCRIPT_DIR -> REPO_ROOT), mirrors tool/audit/inventory.sh"
    - "Live-read baseline (no hardcoded counts) — drift-proof per inventory.sh design principle"
    - "grep-gate CI-automatable non-zero exit, per LOG-01 precedent"
key-files:
  created:
    - tool/audit/phase16_gates.sh
  modified: []
decisions:
  - "GATE 1b classifies a match as doc-comment-safe by checking the trimmed line content starts with '///' — matches inventory.sh's readable-shell-string-manipulation style rather than invoking a second grep pass"
  - "WARNING threshold hardcoded at 575 (the plan's own literal derivation of ~480 + 20% ≈ 576, rounded to the plan's stated '575' trigger) — this is a threshold constant, not a measured count, so hardcoding it does not violate the no-hardcoded-counts principle (only measured counts/baseline must be live-read)"
  - "chmod +x plus git update-index --chmod=+x used together since the worktree filesystem is Windows (exec bit not natively tracked) — inventory.sh itself is 100644 in the index for comparison, this script is 100755 per the plan's explicit executable requirement"
metrics:
  duration: "~20 minutes"
  completed: 2026-07-18
status: complete
---

# Phase 16 Plan 05: Diagnostics/Adapter Audit Gates Summary

Added `tool/audit/phase16_gates.sh` — a single re-runnable, self-locating shell script with two
static structural gates (D22 grep gate, D27 wc gate) enforcing ADAPT-04 sc4 (no dual
openGeneration data source) and ADAPT-05 (size budget), mirroring the Phase 15
`tool/audit/inventory.sh` convention.

## What Was Built

**Task 1 — `tool/audit/phase16_gates.sh`** (148 lines, executable)

Self-locating via `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` then
`REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"`, `set -euo pipefail`, `--stdout` flag for
interface parity with `inventory.sh` (this script has no side effects either way — no file
writes, pure stdout). Bilingual (Chinese/English) header comment explains both gates and
references D20/D22/D27/ADAPT-04/ADAPT-05 and the LOG-01 grep-gate precedent.

**GATE 1 (D22)** — runs two checks against `lib/kernel/adapter/`:
- (a) `grep -rn '_openGeneration'` must return 0 hits — any hit means the adapter smuggled in
  a counter field/reference (D20/D22 violation). Currently 0 hits.
- (b) `grep -rn 'openGeneration'` (no leading underscore) matches must ALL live inside `///`
  doc-comment lines. Implemented by extracting each match's `file:line:content`, trimming
  leading whitespace off `content`, and asserting it starts with `///`. Any match failing this
  check (a field, method body, import) is a violation. Currently the only 2 matches are both
  `///` doc-comment lines: the D21 class-level migration checklist (line 85) and the `open()`
  method's transparent-forwarding doc comment (line 214) — both pass.

Both checks print the offending/matched lines for auditability; on success prints a one-line
GATE 1 PASS summary plus the doc-comment matches found (for traceability).

**GATE 2 (D27)** — reads the baseline live via `wc -l < fvp_engine.dart` (currently 636, never
hardcoded), sums the 6 production files (`lib/kernel/adapter/*.dart` +
`lib/kernel/diagnostics/*.dart`) via per-file `wc -l`, prints the per-file breakdown, and
asserts `total < baseline`. Currently: adapter 357 + diagnostics (59+45+68+40+64=276) = 633
lines vs. 636 baseline (633 < 636 — PASSES, ~3-line headroom as anticipated by the plan's
"D27 headroom reality" note). Since 633 exceeds the D26 20%-deviation warning threshold (575,
derived from the plan's ~480 LOC midpoint estimate), the script prints a non-fatal WARNING
recommending a senior-architect/red-team re-challenge — this fires correctly on the current
tree and does not affect the exit code (still `< baseline`, so GATE 2 still PASSES / exit 0).

## Verification

Ran `bash tool/audit/phase16_gates.sh` on the clean tree — exit code 0, both gates PASS:

```
GATE 1 PASS (D22): 0 '_openGeneration' hits; all 'openGeneration' matches are inside /// doc comments.
  (doc-comment matches, for auditability):
    lib/kernel/adapter/kernel_adapter.dart:85:///   - openGeneration unified counter migrates from legacy into adapter/tracker (STATE-02, D23a)
    lib/kernel/adapter/kernel_adapter.dart:214:  /// 纯转发 — openGeneration 守卫驻留于旧引擎 (fvp_engine.dart:259/267/311/320),

GATE 2 (D27) per-file breakdown:
    357  lib/kernel/adapter/kernel_adapter.dart
    59   lib/kernel/diagnostics/diagnostics_bundle.dart
    45   lib/kernel/diagnostics/event_log_slot.dart
    68   lib/kernel/diagnostics/kernel_logger.dart
    40   lib/kernel/diagnostics/memory_monitor_slot.dart
    64   lib/kernel/diagnostics/metrics_slot.dart
  Total: 633 lines. Baseline (live wc -l fvp_engine.dart): 636 lines.
WARNING (D26 escalation): total (633) exceeds the 20%-deviation threshold (575) vs the ~480 estimate — still under the 636 ceiling, but recommend a senior-architect/red-team re-challenge (D26/D27 escalation).
GATE 2 PASS (D27): total (633) < baseline (636).
```

Also verified `--stdout` flag produces identical output (no divergent behavior since the
script has no side effects in either mode).

**Break-and-revert confirmation (per plan `<verification>`):**

1. **GATE 1 break:** Temporarily added `int _openGeneration = 0;` field to `KernelAdapter` in
   `lib/kernel/adapter/kernel_adapter.dart`. Re-ran the script — GATE 1 correctly FAILED with
   exit code 1, printing both offending lines (the underscore-prefixed field literal under
   check (a), and the same line again under check (b) since it also matches the non-underscore
   pattern and is not inside a `///` comment). GATE 2 was unaffected (independent check, still
   PASSED with total 634). Reverted the field via Edit — confirmed `git status --short` shows
   no diff in `kernel_adapter.dart` afterward.

2. **GATE 2 break:** Temporarily appended 5 comment-only lines
   (`// TEMP-BREAK-TEST-LINE-{1..5}`) to the end of `lib/kernel/diagnostics/diagnostics_bundle.dart`.
   Re-ran the script — GATE 2 correctly FAILED with exit code 1, printing the full per-file
   breakdown (total 638 >= baseline 636) and the failure message. GATE 1 was unaffected
   (independent check, still PASSED). Reverted the appended lines via Edit — confirmed
   `git status --short` shows no diff in `diagnostics_bundle.dart` afterward.

3. **Final clean re-run:** After both reverts, `git status --short` showed only the new
   untracked `tool/audit/phase16_gates.sh` (no residual diffs in adapter/diagnostics files).
   Re-ran the script one final time before committing — both gates PASS, exit code 0 (identical
   output to the first clean run above).

Only the clean `tool/audit/phase16_gates.sh` was committed — no break-test artifacts landed in
git history.

## Deviations from Plan

None — plan executed exactly as written. The script mirrors `inventory.sh`'s self-locating +
`set -euo pipefail` + `--stdout` conventions, reads the D27 baseline live, and implements both
grep/wc gates exactly as specified in the plan's `<action>` block. The `lib/kernel/adapter/`
and `lib/kernel/diagnostics/` files were touched only transiently during the mandated
break-and-revert verification steps and were fully reverted before the commit (confirmed via
`git status --short` showing zero diff in those files at commit time) — no changes to those
directories are part of this plan's committed diff.

## Threat Flags

None. This plan introduces no new trust boundary, network endpoint, auth path, file access
pattern, or schema change — the script is read-only + stdout audit tooling with a single file
artifact (per the plan's own `<threat_model>`, threat_level: low, both T-16-06 and T-16-05
dispositioned as "mitigate" and addressed by the live-read baseline design and the GATE 2
WARNING escalation respectively).

## Self-Check: PASSED

`tool/audit/phase16_gates.sh` verified present on disk at
`D:\simple_player_flutter\.claude\worktrees\agent-aff7fa3b859503786\tool\audit\phase16_gates.sh`.
Commit `0ca261a` verified in `git log --oneline`.
