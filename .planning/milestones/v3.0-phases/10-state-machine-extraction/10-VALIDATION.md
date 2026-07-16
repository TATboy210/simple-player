---
phase: 10
slug: state-machine-extraction
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-14
---

# Phase 10 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK 内置) |
| **Config file** | analysis_options.yaml |
| **Quick run command** | `flutter test test/kernel/engine/engine_state_machine_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/kernel/engine/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 10-01-01 | 01 | 1 | SVC-02 | — | N/A | unit | `flutter test test/kernel/engine/engine_state_machine_test.dart` | ❌ W0 | ⬜ pending |
| 10-01-02 | 01 | 1 | SVC-02 | — | N/A | unit | 同上 | ❌ W0 | ⬜ pending |
| 10-02-01 | 02 | 1 | ENG-02 | — | N/A | 静态检查 | `wc -l lib/kernel/engine/fvp_engine.dart` | ✅ | ⬜ pending |
| 10-02-02 | 02 | 1 | ENG-02 | — | N/A | unit | `flutter test test/kernel/engine/` | 部分 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/kernel/engine/engine_state_machine_test.dart` — 覆盖 SVC-02（状态转换矩阵、transitionTo 返回值、debug 警告）
- [ ] `test/kernel/engine/playback_skip_mixin_test.dart` — 覆盖 skipForward/skipBack/setRange
- [ ] 更新 `test/helpers/fake_engine.dart` — 添加 interface getter + stateMachine
- [ ] 更新 `test/kernel/engine/fvp_callback_handler_test.dart` — 使用 stateMachine.transitionTo

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| FvpEngine 行数 < 350 | ENG-02 | 静态检查非测试 | `wc -l lib/kernel/engine/fvp_engine.dart` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
