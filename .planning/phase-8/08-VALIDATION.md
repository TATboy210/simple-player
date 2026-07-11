---
phase: 8
slug: delete-abstraction
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-11
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (Dart) |
| **Config file** | pubspec.yaml |
| **Quick run command** | `flutter test test/regression/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter analyze && flutter test test/regression/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 08-01-01 | 01 | 1 | SIMPLIFY-01 | T-08-01 | DesktopFullscreenAdapter 无 model import | source | `flutter analyze lib/kernel/bridge/desktop_fullscreen_adapter.dart` | ✅ | ⬜ pending |
| 08-01-02 | 01 | 1 | SIMPLIFY-01, SIMPLIFY-02 | T-08-02 | WindowService/main 无残留 import + 9 文件删除 | source + smoke | `flutter analyze && grep -r "fullscreen_adapter\|fullscreen_command_queue\|fullscreen_snapshot\|fullscreen_error\|fullscreen_event\|fullscreen_request" lib/` | ✅ | ⬜ pending |
| 08-01-03 | 01 | 1 | SIMPLIFY-03 | T-08-SC | flutter analyze 零 error + flutter test 全通过 | regression | `flutter analyze && flutter test` | ✅ | ⬜ pending |
| 08-02-01 | 02 | 2 | SIMPLIFY-02 | — | smoke_suite 无删除类型引用 | source | `flutter test test/regression/smoke_suite_test.dart` | ✅ | ⬜ pending |
| 08-02-02 | 02 | 2 | SIMPLIFY-02 | — | high_risk + e2e 无删除类型引用 | source | `flutter test test/regression/high_risk_suite_test.dart test/regression/fullscreen_e2e_test.dart` | ✅ | ⬜ pending |
| 08-02-03 | 02 | 2 | SIMPLIFY-03 | T-08-SC | 全量回归通过 | regression | `flutter test` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- Existing infrastructure covers all phase requirements (flutter_test already configured)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| 残留 import 检查 | SIMPLIFY-02 | grep 需要人工确认排除不相关匹配 | `grep -r "fullscreen_adapter\|fullscreen_command_queue\|fullscreen_snapshot\|fullscreen_error\|fullscreen_event\|fullscreen_request" lib/` 返回空 |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
