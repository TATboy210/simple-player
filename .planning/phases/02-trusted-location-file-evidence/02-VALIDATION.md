---
phase: "02"
slug: "trusted-location-file-evidence"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-08-30"
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (Dart) |
| **Config file** | none — existing pubspec/test layout |
| **Quick run command** | `flutter test test/diagnostics/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~60 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/diagnostics/`
- **After every plan wave:** Run `flutter test && flutter analyze`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-xx | 01 | 1 | LOC-01/05 | — | 首项目帧+2次级帧提取，畸形栈不抛 | unit | `flutter test test/diagnostics/` | ❌ W0 | ⬜ pending |
| 02-01-xx | 01 | 1 | LOC-02 | — | 越界/不可读路径降级不崩溃 | unit | `flutter test test/diagnostics/` | ❌ W0 | ⬜ pending |
| 02-02-xx | 02 | 1 | LOC-03 | — | 媒体路径快照冻结不可变 | unit | `flutter test test/diagnostics/` | ❌ W0 | ⬜ pending |
| 02-02-xx | 02 | 1 | LOG-01~05 | — | 即时追加/UTF-8/写失败降级/单写者 | unit | `flutter test test/diagnostics/` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/diagnostics/source_locator_test.dart` — LOC-01/LOC-02 stubs
- [ ] `test/diagnostics/file_sink_test.dart` — LOG-01~05 stubs（临时目录注入）
- [ ] 沿用既有 test/helpers/ fake 惯例

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| 真机 Windows 实际日志文件落点与 UTF-8 内容 | LOG-04 | path_provider 真实目录无法在单测中验证 | 实机触发一次错误，打开 %APPDATA% 对应 ApplicationSupport/logs/error.log 检查追加与编码 |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
