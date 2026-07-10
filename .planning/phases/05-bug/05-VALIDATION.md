---
phase: 5
slug: bug
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-10
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter test |
| **Config file** | pubspec.yaml (dev_dependencies) |
| **Quick run command** | `flutter test test/` |
| **Full suite command** | `flutter test --coverage` |
| **Estimated runtime** | ~60 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/`
- **After every plan wave:** Run `flutter test --coverage`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------|-------------------|--------|
| 05-01-01 | 01 | 1 | FIX-01 | unit | `flutter test test/widget/player/video_surface_test.dart` | ⬜ pending |
| 05-01-02 | 01 | 1 | FIX-02 | unit | `flutter test test/platform/windows_fullscreen_driver_test.dart` | ⬜ pending |
| 05-02-01 | 02 | 1 | PERF-01 | unit | `flutter test test/platform/windows_fullscreen_driver_test.dart` | ⬜ pending |
| 05-02-02 | 02 | 1 | PERF-02 | unit | `flutter test test/widget/player/video_surface_test.dart` | ⬜ pending |
| 05-02-03 | 02 | 1 | PERF-03 | unit | `flutter test test/platform/windows_fullscreen_driver_test.dart` | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| 全屏切换 <100ms 无闪烁 | PERF-01/02 | 需要真实窗口测量 | 按 F 切换全屏，观察是否有黑帧/白帧 |
| 16:9 视频无黑边 | FIX-01 | 需要视觉确认 | 播放 16:9 视频全屏，观察四边 |
| 边框残留 | FIX-02 | 需要像素级检查 | 全屏时检查四角是否有边框线 |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
