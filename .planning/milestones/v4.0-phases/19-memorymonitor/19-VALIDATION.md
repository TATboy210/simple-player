---
phase: 19
slug: memorymonitor
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-20
---

# Phase 19 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK) |
| **Config file** | `test/` directory |
| **Quick run command** | `flutter test test/diagnostics/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/diagnostics/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|-------------|--------|
| 19-01-01 | 01 | 1 | MEM-01 | N/A | unit | `flutter test test/diagnostics/memory_monitor_test.dart` | ❌ W0 | ⬜ pending |
| 19-01-02 | 01 | 1 | MEM-02 | N/A | unit | `flutter test test/diagnostics/memory_monitor_test.dart` | ❌ W0 | ⬜ pending |
| 19-02-01 | 02 | 1 | MEM-03 | N/A | unit | `flutter test test/diagnostics/memory_snapshot_test.dart` | ❌ W0 | ⬜ pending |
| 19-03-01 | 03 | 2 | MEM-04 | N/A | static | `grep -r 'MemoryMonitor\._' lib/` returns 0 | N/A | ⬜ pending |
| 19-04-01 | 04 | 2 | MEM-05 | N/A | unit | `flutter test test/diagnostics/diagnostics_bundle_test.dart` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/diagnostics/memory_monitor_test.dart` — covers MEM-01, MEM-02 (FakeRssProvider/FakeClock based)
- [ ] `test/diagnostics/memory_snapshot_test.dart` — covers MEM-03 (data class tests, move from existing test/unit/kernel/utils/)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Atomic commit integrity | MEM-04 | Git history discipline — cannot be automated | Verify single commit contains shim + migration + shim removal |
| Zero playback interference | MEM-02 | Integration behavior across subsystems | Run playback, confirm MemoryMonitor never touches PlaybackController/MediaState |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
