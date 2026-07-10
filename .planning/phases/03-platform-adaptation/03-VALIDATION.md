---
phase: 03
slug: platform-adaptation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-10
---

# Phase 03 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK) |
| **Config file** | pubspec.yaml |
| **Quick run command** | `flutter test test/platform/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/platform/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | PLAT-01 | T-03-01 | IsWindow() 检查 HWND | unit | `flutter test test/platform/windows_fullscreen_driver_test.dart` | ❌ W0 | ⬜ pending |
| 03-01-02 | 01 | 1 | PLAT-01 | — | N/A | unit | `flutter test test/platform/windows_fullscreen_driver_test.dart` | ❌ W0 | ⬜ pending |
| 03-01-03 | 01 | 1 | PLAT-01 | — | N/A | unit | `flutter test test/platform/windows_fullscreen_driver_test.dart` | ❌ W0 | ⬜ pending |
| 03-02-01 | 02 | 1 | PLAT-02 | — | N/A | unit | `flutter test test/platform/macos_fullscreen_driver_test.dart` | ❌ W0 | ⬜ pending |
| 03-02-02 | 02 | 1 | PLAT-02 | — | N/A | unit | `flutter test test/platform/macos_fullscreen_driver_test.dart` | ❌ W0 | ⬜ pending |
| 03-03-01 | 03 | 1 | PLAT-03 | — | N/A | unit | `flutter test test/platform/linux_fullscreen_driver_test.dart` | ❌ W0 | ⬜ pending |
| 03-03-02 | 03 | 1 | PLAT-03 | — | N/A | unit | `flutter test test/platform/linux_fullscreen_driver_test.dart` | ❌ W0 | ⬜ pending |
| 03-04-01 | 04 | 2 | PLAT-04 | — | N/A | unit | `flutter test test/platform/fullscreen_driver_factory_test.dart` | ❌ W0 | ⬜ pending |
| 03-04-02 | 04 | 2 | PLAT-04 | — | N/A | unit | `flutter test test/platform/fullscreen_driver_factory_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/platform/windows_fullscreen_driver_test.dart` — covers PLAT-01
- [ ] `test/platform/macos_fullscreen_driver_test.dart` — covers PLAT-02
- [ ] `test/platform/linux_fullscreen_driver_test.dart` — covers PLAT-03
- [ ] `test/platform/fullscreen_driver_factory_test.dart` — covers PLAT-04

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Windows 全屏无 7px 缝隙 | PLAT-01 | 需真实窗口渲染 | `flutter run -d windows` → 播放视频 → F 全屏 → 检查四边无缝隙 |
| macOS 原生全屏动画 | PLAT-02 | 需 macOS 系统动画 | `flutter run -d macos` → F 全屏 → 确认绿色按钮动画 |
| Linux WM 兼容性 | PLAT-03 | 需多种 WM 环境 | GNOME/KDE/XFCE 下分别测试全屏进出 |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
