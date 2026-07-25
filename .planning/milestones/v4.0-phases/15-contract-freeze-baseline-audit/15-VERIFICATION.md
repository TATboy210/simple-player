---
phase: 15-contract-freeze-baseline-audit
verified: 2026-07-17T20:05:00Z
status: passed
score: 4/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
human_verification_resolution: >
  RESOLVED 2026-07-17 by user decision via /gsd-execute-phase orchestrator
  AskUserQuestion: accept the DLL-provisioning item as a documented follow-up
  (recorded in test/fixtures/README.md "Native-DLL provisioning" section) and
  complete Phase 15 now. Rationale: goal-backward verdict is PASSED 4/4 with no
  BLOCKER; frozen contracts and contract tests are correct (57/57 pass, T-15-07
  open->idle->play against real tiny_valid.mp4 confirmed); only native-library
  provisioning for headless `flutter test` is an undocumented environment step,
  a tooling/repo-hygiene decision deferred to a later phase (Phase 20/21 reuse
  this gate). The human decision required by `human_verification` below has been
  made; status flipped to passed.
human_verification:
  - test: "Fresh-clone/fresh-session run of `flutter test test/engine/fvp_engine_contract_test.dart` without first manually copying native DLLs (mdk.dll, fvp.dll, ffmpeg-9.dll, libass.dll, mdk-braw.dll, mdk-nvjp2k.dll, mdk-r3d.dll, flutter_windows.dll, and 5 plugin DLLs) from `build/windows/x64/runner/Debug/` into the repo root"
    expected: "Either the test run should pass without any manual step (requires a documented/automated DLL-provisioning mechanism — e.g. a `dart_test.yaml` platform hook, a pre-test build step, or committed test-fixture DLLs), or the missing-DLL failure mode should be a documented, expected precondition (e.g. noted in test/fixtures/README.md or a CONTRIBUTING/test-setup doc) rather than a silent, undocumented dependency on a prior `flutter build windows` having been run in the same tree"
    why_human: "This is an environment/CI-provisioning decision (whether to commit DLLs as test fixtures, add a pretest script, or accept manual first-time setup as documented convention) that requires a human call on tooling/repo-hygiene tradeoffs, not a code-correctness question. Verified independently in this session: the test suite (57/57) and the T-15-07 regression gate both pass once the DLLs are copied from build/windows/x64/runner/Debug/ into the repo root — the frozen contracts and tests themselves are correct; only the native-library provisioning step for `flutter test` is undocumented/unautomated."
---

# Phase 15: Contract Freeze Baseline Audit Verification Report

**Phase Goal:** 为适配层与后续所有阶段固化稳定的行为契约与迁移基线，让适配层实现的是 frozen audited behavioral spec 而非 signature-level 猜测。
**Verified:** 2026-07-17T20:05:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth (Success Criterion) | Status | Evidence |
|---|------|--------|----------|
| 1 | Every `MediaEngine`/`EngineStateView` member has a written behavioral contract (pre/post-conditions, allowed `MediaState` transitions, error cases, modified `ValueNotifier`s), independently reviewable as a migration gate | ✓ VERIFIED | `lib/kernel/engine/engine_state_view.dart:16-19` group contract (D3) covers all 14 getters + dispose; `lib/kernel/engine/playback_control.dart` all 12 methods carry `requires:`/`ensures:`/`states:`/`modifies:`/`throws:` tags (e.g. lines 11-19 for `open()`); all 5 remaining control interfaces (`track_control.dart`, `subtitle_config.dart`, `video_effect_control.dart`, `renderer_control.dart`, `volume_control.dart`) carry tags on every member. `bash tool/audit/contract_completeness.sh` (independently re-run this session) reports **"Status: COMPLETE — every member across all 7 ISP interfaces has a contract tag"**, exit 0, 15/15+12/12+3/3+8/8+4/4+2/2+4/4 members covered. |
| 2 | Static call-site inventory complete and reproducible — `package:logger` (121 processed/30 files historically, now live 84/28), `MemoryMonitor.start/snapshot` (2 sites), `openGeneration` references all located with stable counts | ✓ VERIFIED | `tool/audit/inventory.sh` exists and independently re-run this session: exits 0, writes `15-BASELINE-AUDIT.json`/`.md`. Byte-identical reproducibility independently re-verified: `diff <(bash tool/audit/inventory.sh --stdout \| grep -v generated_at) <(...)` → empty diff. JSON shows live numbers (84 logger call sites/28 files, 2 MemoryMonitor sites, 2 openGeneration files: `fvp_engine.dart` + `playback_navigator.dart`) — the plan explicitly retired the stale 121/30 figure and never hardcodes it. |
| 3 | 9-state (PROJECT.md) vs 6-state (`engine_state_machine.dart`) discrepancy reconciled and adjudicated — frozen baseline declared, v3.0 lifecycle states to add (disposed/disposing/error-recovery) listed, no fork risk for adapter contracts | ✓ VERIFIED | `.planning/phases/15-contract-freeze-baseline-audit/15-CONTEXT.md:135-166` "P20 Lifecycle-Gap 清单（D18）" section: frozen verdict "6 态正交 MediaState + 正交 LifecyclePhase；9 态模型（PROJECT.md 陈旧）已退休" with full transition table cross-referenced against `engine_state_machine.dart:66-92`, 6-item P20 TODO list, and documented contract-vs-implementation gaps. `.planning/PROJECT.md:36` independently confirmed to no longer contain "9 态"/"~40 边"/"9 个状态" (grep returns 0 matches) and now states "6 态正交 MediaState...+ isSeeking/isBuffering 独立标志；v3.0 补充正交 LifecyclePhase{alive,disposing,disposed}". The critical `error → {idle, opening}` recover() exit is independently confirmed intact in `engine_state_machine.dart:89-90` (not closed off by any contract). |
| 4 | Interface-level (not implementation) contract tests exist and pass against the old engine, serving as the migration gate for every future capability flip | ✓ VERIFIED | 7 `test/contracts/*_contract.dart` files exist (`ls` confirms exactly 7 + runner), each a top-level `run<Iface>ContractTests(MediaEngine Function() createEngine)` — zero direct `FvpEngine(`/`FakeEngine(` instantiation (`grep -rc` returns 0 across all 7). `test/engine/fvp_engine_contract_test.dart` mounts all 7 against real `FvpEngine()` (7/7 confirmed via grep). **Independently re-ran this session** (not merely trusted from SUMMARY): `flutter test test/engine/fvp_engine_contract_test.dart` → 57/57 passed once required native DLLs were present (see Human Verification below for the DLL-provisioning gap). `flutter test ... --plain-name "open to play handoff"` independently re-run → 1 test, passes, with real decode output confirmed in stdout (`open() success — tiny_valid.mp4 320x176 10027ms`, then `play() — tiny_valid.mp4`). No skip tags found (`grep -n "requires-media\|@Tags\|skip:"` → 0 matches). |

**Score:** 4/4 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `tool/audit/inventory.sh` | BASE-02 reproducible call-site script | ✓ VERIFIED | Exists, runs (exit 0), byte-identical reproducibility confirmed independently |
| `tool/audit/contract_completeness.sh` | Dynamic contract-tag completeness checker | ✓ VERIFIED | Exists, runs (exit 0), independently re-confirmed "COMPLETE" status across all 7 interfaces (post-Plan-02 state) |
| `tool/audit/README.md` | Usage docs + --enforce placeholder | ✓ VERIFIED | Present alongside scripts |
| `.planning/phases/15-contract-freeze-baseline-audit/15-BASELINE-AUDIT.json`/`.md` | Committed snapshot | ✓ VERIFIED | Present, valid JSON, live numbers (84/28/2/2), not stale 121/30 |
| `lib/kernel/engine/engine_state_view.dart` | D3 group contract | ✓ VERIFIED | Lines 7-19: group contract above class, all 14 getters retain intent lines |
| `lib/kernel/engine/playback_control.dart` | D2 tags on 12 methods | ✓ VERIFIED | All methods carry full tag set; `open()`/`play()` explicitly freeze the open→idle→play handoff |
| `lib/kernel/engine/{track_control,subtitle_config,video_effect_control,renderer_control,volume_control}.dart` | D2 tags on all members | ✓ VERIFIED | Confirmed via contract_completeness.sh re-run: 3/3, 8/8, 4/4, 2/2, 4/4 members tagged |
| `lib/kernel/engine/fvp_engine.dart` | D4 thin notes only, no contract tags | ✓ VERIFIED | `grep -cE "^\s*///\s*(requires\|ensures\|states):"` == 0 (re-confirmed); thin mechanism notes present at open()/dispose()/_guardedAction/codec-fallback |
| `.planning/phases/15-contract-freeze-baseline-audit/15-CONTEXT.md` | P20 Lifecycle-Gap section (D18) | ✓ VERIFIED | Lines 135-166, full frozen verdict + transition table + 6-item TODO list |
| `test/contracts/*.dart` (7 files) + `contract_test_runner.dart` | Parameterized ISP contract test groups | ✓ VERIFIED | Exactly 7 `*_contract.dart` files, zero direct engine instantiation |
| `test/engine/fvp_engine_contract_test.dart` | Real-FvpEngine mount point | ✓ VERIFIED | Mounts all 7 groups against real `FvpEngine()`, 57/57 pass (independently re-run) |
| `test/fixtures/*` (5 files) | Real bad-file + happy-path fixtures | ✓ VERIFIED | `corrupted_header.mp4`, `empty_file.mp4` (0 bytes confirmed), `not_a_video.txt`, `unsupported_codec.avi`, `tiny_valid.mp4` (788KB, real decodable clip, confirmed via successful open() in gate re-run) |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `states:` tags in `playback_control.dart` | `engine_state_machine.dart:66-92` `_canTransitionTo` | Hand cross-check (D7) | ✓ WIRED | Independently spot-checked: `open()`'s documented gap (`playing`/`paused` source states lack a `→opening` edge in `_canTransitionTo`) matches the real switch exactly; `play()`'s documented gap (`completed→playing` not in table) also matches; `error → {idle, opening}` recover() exit confirmed NOT closed off by any tag |
| `contract_completeness.sh` | 7 ISP interface files | Dynamic member-signature extraction | ✓ WIRED | Independently re-run this session, correctly reports 15 members for `engine_state_view.dart` (not the stale "12"), COMPLETE status post-Plan-02 |
| `test/contracts/*_contract.dart` (parameterized `createEngine` factory) | `test/engine/fvp_engine_contract_test.dart` (real `FvpEngine()`) | 7x `run*ContractTests(() => FvpEngine())` | ✓ WIRED | Confirmed via grep (7/7) and by running the mounted suite — no fake/mock substitution at the gate |
| Frozen `throws:` tags | Behavioral assertions in `playback_control_contract.dart` | `lastError.value isA<PlayerError>` + `state.value == MediaState.error` (not `throwsA`) | ✓ WIRED | Confirmed by SUMMARY excerpt and file structure; D19 behavioral-assertion pattern honored |

### Data-Flow Trace (Level 4)

Not applicable — this phase produces documentation contracts, audit scripts, and test artifacts, not UI-rendering components with dynamic data sources.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Inventory script reproducibility | `diff <(bash tool/audit/inventory.sh --stdout \| grep -v generated_at) <(bash tool/audit/inventory.sh --stdout \| grep -v generated_at)` | Empty diff | ✓ PASS |
| Contract completeness (post-freeze) | `bash tool/audit/contract_completeness.sh` | Exit 0, "Status: COMPLETE — every member across all 7 ISP interfaces has a contract tag" | ✓ PASS |
| Full contract test suite against real FvpEngine | `flutter test test/engine/fvp_engine_contract_test.dart` | 57/57 passed (once native DLLs present — see gap below) | ✓ PASS (conditional on DLL setup) |
| T-15-07 open→idle→play regression gate (standalone) | `flutter test test/engine/fvp_engine_contract_test.dart --plain-name "open to play handoff"` | 1 test run, passed; real decode confirmed (`open() success — tiny_valid.mp4 320x176 10027ms`, then `play()`) | ✓ PASS (conditional on DLL setup) |
| `flutter analyze` on all edited engine files | `flutter analyze lib/kernel/engine/` | "No issues found!" | ✓ PASS |
| Pure-comment-diff claim (Plan 02) | `git diff bbec3e9~1 e3a7817 --stat -- lib/kernel/engine/` | 177 insertions, 1 deletion (the "6→7" ISP-count line), no logic changes | ✓ PASS |
| Debt markers in phase-modified files | `grep -n "TODO\|FIXME\|XXX\|TBD\|HACK\|PLACEHOLDER"` across `test/contracts/*.dart`, `test/engine/fvp_engine_contract_test.dart`, `lib/kernel/engine/*.dart` | 0 matches | ✓ PASS |
| D20 boundary (no timing/race tests) | `grep -n "fakeAsync"` across `test/contracts/*.dart` | 0 matches | ✓ PASS |

### Probe Execution

Not applicable — no `scripts/*/tests/probe-*.sh` convention used by this project; phase-specific verification used `tool/audit/*.sh` and `flutter test`, both covered above.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|--------------|--------|----------|
| BASE-01 | 15-02 | Frozen behavioral contracts on every MediaEngine/EngineStateView member | ✓ SATISFIED | Contract tags on all 7 interfaces, `contract_completeness.sh` reports COMPLETE |
| BASE-02 | 15-01 | Reproducible static call-site inventory (logger/MemoryMonitor/openGeneration) | ✓ SATISFIED | `inventory.sh` byte-identical reproducibility confirmed |
| BASE-03 | 15-02 | 9-vs-6 state reconciliation, lifecycle-gap list | ✓ SATISFIED | P20 Lifecycle-Gap section in CONTEXT.md, PROJECT.md corrected |
| BASE-04 | 15-03 | Interface-level contract tests passing against old engine | ✓ SATISFIED | 57/57 tests pass against real FvpEngine (independently re-run); regression gate executes and passes |

**Note:** `.planning/REQUIREMENTS.md` currently still shows `BASE-01`..`BASE-04` as `[ ] Pending` in both the checklist (lines 13-16) and the Traceability table (lines 110-113). This is a bookkeeping/tracking artifact, not evidence against goal achievement — the underlying code/test/doc evidence for all 4 requirements independently verifies as satisfied in this report. Recommend checking these off as a follow-up tracking step once this VERIFICATION.md is accepted, per the phase's own tracking-update workflow (`docs(15): update tracking after wave 1` pattern already used).

### Anti-Patterns Found

None found in phase-modified files. No `TODO`/`FIXME`/`XXX`/`TBD`/`HACK`/`PLACEHOLDER` markers; no stub returns; no empty handlers; no hardcoded empty data flowing to consumers; git diffs for Plan 02 are pure comment insertions (verified via `git diff --stat`).

### Human Verification Required

### 1. Native DLL provisioning for `flutter test` on the contract-test gate

**Test:** From a fresh clone or fresh session (no prior `flutter build windows` having populated `build/windows/x64/runner/Debug/`), run `flutter test test/engine/fvp_engine_contract_test.dart` without any manual DLL-copying step.

**Expected:** The test suite should either (a) pass without any manual step, or (b) fail with a clearly documented, expected precondition message pointing to a setup doc — not an opaque `Failed to load dynamic library 'mdk.dll'` error with no guidance.

**Why human:** This session independently reproduced the gap: running `flutter test test/engine/fvp_engine_contract_test.dart` in the actual repo working tree (no prior manual setup in this session) failed all 57 tests with `Invalid argument(s): Failed to load dynamic library 'mdk.dll': The specified module could not be found.` Copying `mdk.dll`, `fvp.dll`, `ffmpeg-9.dll`, `libass.dll`, `mdk-braw.dll`, `mdk-nvjp2k.dll`, `mdk-r3d.dll`, `flutter_windows.dll`, and 5 plugin DLLs from `build/windows/x64/runner/Debug/` into the repo root immediately fixed it — 57/57 passed, and the T-15-07 gate independently passed with real decode output. The 15-03-SUMMARY.md itself flags this ("Root-level native DLLs required for headless test execution... They remain untracked/unstaged (not part of files_modified, not covered by .gitignore — a pre-existing gap left unfixed per the scope boundary)"), so the executor was aware but explicitly deferred it as out of scope. This is a judgment call about test-infrastructure hygiene (commit DLLs as fixtures? add a pretest script? document as a one-time manual step?) that a human should decide — it does not indicate the contracts or tests themselves are wrong; every test passes correctly once the native libraries are present.

### Gaps Summary

No BLOCKER gaps. All 4 phase success criteria (SC1-SC4) and all 4 requirements (BASE-01..04) are independently verified as satisfied against the actual codebase — not merely SUMMARY claims. Contract tags are genuinely present and cross-checked against the real state machine; the 9-vs-6 reconciliation is fully documented with a frozen verdict and complete P20 TODO list; the recover() exit is confirmed intact; the contract test suite genuinely passes against the real FvpEngine including the critical open→idle→play regression gate, independently re-executed in this verification session (not merely trusted).

One WARNING-level item is routed to human verification: the contract test suite's `flutter test` invocation depends on native DLLs (`mdk.dll` and 8 others) being present in the repo root, and these are neither committed, gitignored, nor auto-provisioned — they exist only as a side effect of a prior `flutter build windows` run. This does not affect the correctness of the frozen contracts or the tests themselves (verified: once DLLs are present, all 57 tests including the T-15-07 gate pass cleanly), but it is a latent fragility for Phase 20/21's reuse of this exact test suite as a migration gate — if a future CI or fresh-clone environment lacks these DLLs, the "migration gate" will silently show as a native-library-load failure rather than a contract violation, which could be misread as a contract failure by an unfamiliar operator. Recommend either committing the DLLs as versioned test fixtures, adding a `flutter build windows` pretest step to CI, or at minimum documenting the requirement in `test/fixtures/README.md` or a test-setup doc, as a fast follow before Phase 20/21 rely on this gate.

---

*Verified: 2026-07-17T20:05:00Z*
*Verifier: Claude (gsd-verifier)*
