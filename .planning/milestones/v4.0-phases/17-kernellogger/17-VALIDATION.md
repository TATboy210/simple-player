---
phase: 17
slug: kernellogger
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-19
---

# Phase 17 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK built-in) |
| **Config file** | analysis_options.yaml (strict-casts/strict-inference/strict-raw-types) |
| **Quick run command** | `flutter test test/diagnostics/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/diagnostics/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 17-01-01 | 01 | 1 | LOG-01 | T-17-01 | Zero package:logger in kernel | unit + grep | `flutter test test/diagnostics/kernel_logger_test.dart` + `tool/audit/kernel_logger_gate.sh` | Partial | ⬜ pending |
| 17-01-02 | 01 | 1 | LOG-02 | — | N/A | unit | `flutter test test/diagnostics/kernel_logger_test.dart` | Needs extension | ⬜ pending |
| 17-01-03 | 01 | 1 | LOG-05 | — | N/A | unit | `flutter test test/diagnostics/kernel_logger_test.dart` | Needs new tests | ⬜ pending |
| 17-02-01 | 02 | 2 | LOG-04 | — | N/A | grep + compile | `flutter analyze` + `tool/audit/kernel_logger_gate.sh` | Gate script needed | ⬜ pending |
| 17-03-01 | 03 | 2 | LOG-01, LOG-04 | — | N/A | grep | `tool/audit/kernel_logger_gate.sh --enforce` | Gate script needed | ⬜ pending |
| 17-04-01 | 04 | 3 | LOG-03 | T-17-03 | Release zero debugPrint | build | `flutter build windows --release` | Manual only | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/diagnostics/kernel_logger_test.dart` — extend with DevToolsSink/DebugPrintSink/NullSink tests, KernelLoggerImpl.init() + .I accessor tests
- [ ] `tool/audit/kernel_logger_gate.sh` — new CI grep gate script (lib/kernel/** zero import package:logger)
- [ ] Migration script in `tool/audit/` — automated batch replacement of 78 call sites

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Release build zero debugPrint | LOG-03 | Requires --release build + smoke check | `flutter build windows --release`, grep binary for debugPrint strings |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
