---
phase: 25
slug: performance-quick-wins
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-06
---

# Phase 25 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK built-in) |
| **Config file** | pubspec.yaml dev_dependencies |
| **Quick run command** | `flutter test test/widget/shared/glass_container_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test` (affected test files)
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 25-01-01 | 01 | 1 | PERF-03 | T-25-02 | N/A | unit | `flutter test test/widget/shared/glass_container_test.dart` | ✅ | ⬜ pending |
| 25-01-01 | 01 | 1 | PERF-04 | — | N/A | source | `grep "tapJitterThreshold" lib/ui/player/controls_overlay.dart` | — | ⬜ pending |
| 25-01-02 | 01 | 1 | PERF-01 | T-25-01 | N/A | widget | `flutter test test/widget/shared/glass_container_test.dart` | ✅ | ⬜ pending |
| 25-01-02 | 01 | 1 | PERF-02 | — | N/A | widget | `flutter test test/widget/player/control_bar_test.dart` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No new test files needed — existing glass_container_test.dart and control_bar_test.dart cover PERF-01 through PERF-03. PERF-04 is a source-level extraction verifiable by grep.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| 控制栏淡蓝辉光视觉效果 | D-15~D-18 | 色值需在实际显示器上确认 | 运行 app，观察控制栏 playing/idle 状态颜色是否与午夜蓝背景融合 |
| resize 渐变视觉平滑度 | PERF-01 | 150ms 渐变是否足够平滑需主观判断 | 拉伸窗口，观察控制栏毛玻璃淡出/淡入是否无跳变 |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
