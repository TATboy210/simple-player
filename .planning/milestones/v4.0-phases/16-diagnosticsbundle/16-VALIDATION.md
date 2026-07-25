---
phase: 16
slug: diagnosticsbundle
# status lifecycle: draft (seeded by plan-phase §5.5) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-17
---

# Phase 16 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Seeded by `/gsd-plan-phase 16` §5.5 from `16-RESEARCH.md` `## Validation Architecture`.
> Per-task rows in §Per-Task Verification Map are populated when PLAN.md tasks exist (planner lifts the ADAPT-XX → test-file mapping below into task `<verify>`/`<acceptance_criteria>`).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (Dart VM test runner via `flutter test`); `package:test` `matcher` library for `same()` identity assertions (D25) |
| **Config file** | none dedicated — project uses default `flutter test` discovery over `test/` |
| **Quick run command** | `flutter test test/adapter/ test/diagnostics/` (scoped to new Phase 16 code once created) |
| **Full suite command** | `flutter test` (entire suite, including the 7 reused contract test files re-mounted against `KernelAdapter`) |
| **Estimated runtime** | ~60–90 seconds (existing suite baseline; adapter/diagnostics tests add negligible time) |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/adapter/ test/diagnostics/` (fast, scoped to new code)
- **After every plan wave:** Run `flutter test` (full suite — includes the reused 7-file contract suite mounted against `KernelAdapter` PLUS the pre-existing mount against raw `FvpEngine`; both must stay green since `FvpEngine` itself is untouched per D20)
- **Before `/gsd-verify-work`:** Full suite green + `wc -l` size gate + `grep` dual-source gate, all three
- **Max feedback latency:** ~90 seconds (full suite)

---

## Phase Requirements → Test Map

> Seeded from `16-RESEARCH.md` `## Validation Architecture`. Each row is a Nyquist Dimension 8 verification anchor; the planner lifts each into the relevant PLAN.md task's `<verify>`/`<acceptance_criteria>`.

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ADAPT-01 | `KernelAdapter` satisfies all 7 ISP contracts with zero behavior change vs. `FvpEngine` | contract (integration-style; mounts real `FvpEngine` inside adapter) | `flutter test test/adapter/kernel_adapter_contract_test.dart` | ❌ Wave 0 — new mount point; reuses existing `test/contracts/*.dart` bodies unchanged |
| ADAPT-01 | Full existing suite remains green after `engine = FvpEngine()` → `engine = KernelAdapter(...)` swap at `player_services.dart:87` | regression (full suite) | `flutter test` | ✅ — existing suite already covers `PlaybackController`/`VideoProcessingService` behavior transitively |
| ADAPT-02 | `DiagnosticsBundle.noop()` constructs without error; all 4 slots callable as no-ops | unit | `flutter test test/diagnostics/diagnostics_bundle_test.dart` | ❌ Wave 0 — new file |
| ADAPT-02 | `KernelLogger.error()`/`fatal()` accept both named-param shapes found in the live census (both-named, stackTrace-only, neither) | unit | `flutter test test/diagnostics/kernel_logger_test.dart` | ❌ Wave 0 — new file |
| ADAPT-03 | Every `EngineStateView` `ValueNotifier` returned by `KernelAdapter` is `same()` as the wrapped legacy engine's notifier | unit (identity, D25) | `flutter test test/adapter/kernel_adapter_identity_test.dart` | ❌ Wave 0 — new file |
| ADAPT-04 | P16 adapter has NO `_openGeneration` field (D20); single arbiter via KernelMode + D22 grep gate at 0 hits; counter migration is a P20 placeholder (D21) | static grep gate (D22, no Dart test — adapter is transparent per D20/#8 KISS) | `grep -rn '_openGeneration' lib/kernel/adapter/` (expect 0 hits) + `grep -rn 'openGeneration' lib/kernel/adapter/` (expect class-level `///` doc-comment only) | ❌ Wave 0 — gate is a shell grep, not a `flutter test` target (test file removed per D20; ADAPT-04 covered by 16-01 KernelMode arbiter + 16-05 GATE 1) |
| ADAPT-05 | `wc -l` across the 6 new files (`lib/kernel/adapter/*.dart` + `lib/kernel/diagnostics/*.dart`) sums to < 636 (old `FvpEngine` baseline) | static size gate (shell, no Dart test — D27) | `wc -l lib/kernel/adapter/*.dart lib/kernel/diagnostics/*.dart \| tail -1` (verify total < 636) | ❌ Wave 0 — gate is a shell one-liner, not a `flutter test` target |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

### Per-Task Verification Map

> Populated when PLAN.md tasks exist. Each task row carries: Task ID | Plan | Wave | Requirement (ADAPT-XX) | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status. The planner derives Task IDs and Wave assignments at plan time.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| _to be filled by planner_ | — | — | ADAPT-01..05 | — | N/A (pure delegation seam, no trust boundary — see §Security Domain) | unit/contract/regression | (see Phase Requirements → Test Map above) | ❌ Wave 0 | ⬜ pending |

---

## Wave 0 Requirements

Test stubs and audit scripts that MUST exist before Wave 1 implementation tasks can produce meaningful feedback:

- [ ] `test/adapter/kernel_adapter_contract_test.dart` — mounts the existing 7 `run*ContractTests` functions against `KernelAdapter(legacy: FvpEngine(), ...)`; covers ADAPT-01
- [ ] `test/adapter/kernel_adapter_identity_test.dart` — 13 `same()` assertions (one per `EngineStateView` notifier field); covers ADAPT-03/D25
- [ ] (No `kernel_adapter_open_generation_test.dart` — removed per D20: P16 adapter is transparent, no counter to test; #8 KISS forbids testing a no-op. ADAPT-04 covered by 16-01 KernelMode arbiter + 16-05 GATE 1 D22 grep gate)
- [ ] `test/diagnostics/diagnostics_bundle_test.dart` — covers ADAPT-02's noop-construction and cascading-dispose behavior
- [ ] `test/diagnostics/kernel_logger_test.dart` — covers D6's signature acceptance for all 3 live call shapes (both-named, stackTrace-only, neither)
- [ ] Static grep-gate script (D22) — `tool/audit/` shell script or CI step verifying 0 `_openGeneration` matches in `lib/kernel/adapter/`; follows the existing `tool/audit/inventory.sh` pattern (Phase 15 precedent)
- [ ] Static size-gate script (D27) — `wc -l` one-liner verifying the 6 new files sum to < 636; can be folded into the same audit script as the grep gate

*If none: "Existing infrastructure covers all phase requirements." — NOT the case here; 5 new test files + 2 audit gates are Wave 0 prerequisites.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| UI behavior is zero-observable-change after the `app.dart` composition-root swap (`FvpEngine` → `KernelAdapter(old, old, policyAllOld)`) | ADAPT-01 (Success Criterion 1) | Automated contract tests prove API-level zero-change; the "no UI freeze / no silent notifier detach" guarantee is a runtime property best confirmed by launching the app and playing a real file through the seam | 1. `flutter run -d windows` with the adapter wired at the composition root. 2. Open a real video file. 3. Verify play/pause/seek/volume/track-switch all respond normally (no frozen UI = D6/#6 notifier-instance forwarding holds). 4. Verify no new console errors. |

*All other phase behaviors have automated verification (see Phase Requirements → Test Map).*

---

## Security Domain

Phase 16 is a **pure delegation seam** with **noop diagnostics** — no new trust boundary, no new input surface, no secrets, no auth, no network. The `KernelAdapter` forwards 100% of calls to the existing (already-audited) `FvpEngine`; `DiagnosticsBundle` slots are no-ops by default. The `<threat_model>` block required by the security capability gate (Step 5.55) is therefore expected to record a **low-risk / no-new-attack-surface** verdict — the planner must still emit the block (gate is unconditional) but the threat enumeration will be minimal. See `16-RESEARCH.md` `## Security Domain` for the researcher's security assessment.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (5 test files + 2 audit gates listed above)
- [ ] No watch-mode flags (`flutter test` runs to completion, no `--watch`)
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter (set by validate-phase, not now)

**Approval:** pending
