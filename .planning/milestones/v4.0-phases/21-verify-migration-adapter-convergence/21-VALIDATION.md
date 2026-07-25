---
phase: 21
slug: verify-migration-adapter-convergence
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-20
---

# Phase 21 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK bundled) |
| **Config file** | analysis_options.yaml |
| **Quick run command** | `flutter test test/regression/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~60 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/regression/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 21-01-01 | 01 | 1 | VERIFY-01 | — | N/A | unit | `flutter test test/engine/fvp_engine_contract_test.dart` | ✅ | ⬜ pending |
| 21-02-01 | 02 | 1 | VERIFY-02 | — | N/A | unit | `flutter test test/regression/dual_track_regression_test.dart` | ❌ W0 | ⬜ pending |
| 21-03-01 | 03 | 1 | VERIFY-03 | — | N/A | manual | codegraph analysis + doc | ❌ W0 | ⬜ pending |
| 21-04-01 | 04 | 2 | VERIFY-04 | — | N/A | script | `bash tool/audit/phase21_gates.sh` | ❌ W0 | ⬜ pending |
| 21-05-01 | 05 | 1 | VERIFY-05 | — | N/A | static | `flutter analyze && flutter test --coverage` | ✅/❌ | ⬜ pending |
| 21-06-01 | 06 | 2 | VERIFY-06 | — | N/A | script | `bash tool/audit/phase21_release_gate.sh` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/regression/dual_track_regression_test.dart` — covers VERIFY-02
- [ ] `test/regression/regression_fixture.dart` — shared fixture (D6)
- [ ] `test/regression/diff_report.dart` — diff collection (D7)
- [ ] `tool/audit/phase21_gates.sh` — covers VERIFY-04
- [ ] `tool/audit/phase21_release_gate.sh` — covers VERIFY-06
- [ ] `tool/audit/rollback.sh` — covers D19
- [ ] `docs/ROLLBACK.md` — covers D19
- [ ] Pre-existing analyze errors fix — covers VERIFY-05
- [ ] debugPrint cleanup in lib/kernel/ — covers VERIFY-06

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| 迁移顺序由依赖图推导 | VERIFY-03 | 需要 codegraph 分析输出人工审查 | 运行 codegraph explore，审查叶子→编排器→状态管理器→UI 绑定顺序 |
| 回退路径可用 | D16/D19 | 需要运行 rollback.sh 验证翻回 | 执行 `bash tool/audit/rollback.sh`，确认 DelegationPolicy 翻回 all-legacy |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
