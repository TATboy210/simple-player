---
phase: "02"
slug: "trusted-location-file-evidence"
status: ready
nyquist_compliant: true
wave_0_complete: true
created: "2026-08-30"
updated: "2026-08-30"
---

# Phase 02 — Validation Strategy

> Per-phase validation contract aligned with plans 02-01 through 02-04.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (Dart) |
| **Config file** | none — existing `pubspec.yaml` and mirrored `test/diagnostics/` layout |
| **Quick run pattern** | `D:/flutter/bin/flutter test <task-specific test files>` |
| **Diagnostics suite** | `D:/flutter/bin/flutter test test/diagnostics/` |
| **Full quality gate** | `D:/flutter/bin/flutter analyze && D:/flutter/bin/flutter test && bash tool/audit/kernel_logger_gate.sh` |
| **Focused runtime target** | under 60 seconds per task |

---

## Sampling Rate

- **After every task commit:** Run that task's focused command from the map below.
- **After each plan:** Run the plan-level focused command over only the files changed by that plan.
- **At 02-04 Task 2 final gate:** Run diagnostics, analyze, the full Flutter suite, and the kernel logger audit.
- **Before `/gsd-verify-work`:** Re-run the final quality gate and distinguish only independently reproducible repository-known headless failures; no new diagnostics failure is acceptable.
- **Max task feedback latency:** under 60 seconds; the full-suite chain is an end-of-phase gate, not the task's first feedback sample.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | Test Ownership | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|----------------|--------|
| 02-01-01 | 01 | 1 | LOG-01, LOG-02, LOG-05 | T-02-01, T-02-02, T-02-04 | accepted error/fatal 经 reporter effect、共享 formatter、UTF-8 append+flush 到真实临时文件；warning/presentation 不触碰文件 | integration | `D:/flutter/bin/flutter test test/diagnostics/error_log_file_sink_test.dart` | Task creates `error_log_file_sink_test.dart` | ⬜ pending |
| 02-01-02 | 01 | 1 | LOG-03, LOG-05 | T-02-01, T-02-02, T-02-05 | 字段不能伪造分段；raw stack 保持末段；单写者失败隔离、恢复、限流与 drain | unit + integration | `D:/flutter/bin/flutter test test/diagnostics/diagnostic_pack_formatter_test.dart test/diagnostics/error_log_file_sink_test.dart` | Task creates/extends both files | ⬜ pending |
| 02-02-01 | 02 | 2 | LOC-01 | T-02-06, T-02-09 | stored raw stack 选择首个项目帧及最多两个后续帧；malformed/foreign/async 输入安全降级 | unit | `D:/flutter/bin/flutter test test/diagnostics/error_location_test.dart` | Task creates `error_location_test.dart` | ⬜ pending |
| 02-02-02 | 02 | 2 | LOC-02 | T-02-07, T-02-08 | trusted-root containment、debug/profile ±2 行；release 与 traversal 在 I/O 前拒绝 | unit + filesystem | `D:/flutter/bin/flutter test test/diagnostics/source_line_reader_test.dart` | Task creates `source_line_reader_test.dart` | ⬜ pending |
| 02-03-01 | 03 | 3 | LOC-03 | T-02-10, T-02-11, T-02-12 | basename 与 developer full current/failed-open paths 在 intake 冻结且语义分离 | unit | `D:/flutter/bin/flutter test test/diagnostics/error_report_test.dart test/diagnostics/error_reporter_test.dart test/diagnostics/player_error_report_bridge_test.dart` | Existing tests extended | ⬜ pending |
| 02-03-02 | 03 | 3 | LOC-01, LOC-02, LOG-05 | T-02-11, T-02-13 | effect fan-out 前完成 location/source enrichment；失败/release 只降级，formatter 保留 terminal raw stack | integration | `D:/flutter/bin/flutter test test/diagnostics/error_reporter_test.dart test/diagnostics/diagnostic_pack_formatter_test.dart` | Existing + 02-01 test extended | ⬜ pending |
| 02-04-01 | 04 | 4 | LOG-04 | T-02-14, T-02-15 | 唯一默认路径为 Application Support/logs/error.log；目录幂等创建，provider/I/O 失败 typed unavailable | unit + filesystem | `D:/flutter/bin/flutter test test/diagnostics/error_log_location_test.dart` | Task creates `error_log_location_test.dart` | ⬜ pending |
| 02-04-02 | 04 | 4 | LOG-01, LOG-02, LOG-03, LOG-04, LOG-05 | T-02-15, T-02-17, T-02-18 | reporter/delegating effect/global hooks 先于 provider I/O；pending 不阻塞，late activation 不替换任何已发布 identity | integration + quality gate | `D:/flutter/bin/flutter test test/diagnostics/error_log_location_test.dart test/diagnostics/global_error_hooks_test.dart` then final gate | Existing hooks test extended; focused command precedes full gate | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky*

---

## Wave 0 Requirements

- [x] No separate Wave 0 scaffold is required: every production-code task is `tdd="true"` and creates or extends its named test before implementation.
- [x] Planned new test paths are exact and grounded: `diagnostic_pack_formatter_test.dart`, `error_log_file_sink_test.dart`, `error_location_test.dart`, `source_line_reader_test.dart`, and `error_log_location_test.dart`.
- [x] Existing Phase 1 contracts are extended in `error_report_test.dart`, `error_reporter_test.dart`, `player_error_report_bridge_test.dart`, and `global_error_hooks_test.dart`.
- [x] Every one of the eight tasks has a focused `<automated>` command; 02-04 Task 2 additionally owns the full end-of-phase gate.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Windows production path_provider location and on-disk UTF-8 evidence | LOG-04 | Unit tests inject the support-directory provider; they cannot prove the machine-specific returned directory | On Windows, trigger one error after startup, locate the path surfaced by diagnostic status, and confirm `logs/error.log` contains one readable UTF-8 appended diagnostic pack. |

This smoke check supplements automation; no plan task relies on it as its only verification.

---

## Validation Sign-Off

- [x] All eight tasks have task-specific `<automated>` verification.
- [x] Sampling continuity: every task produces an automated sample before the next task.
- [x] No unresolved `MISSING` test reference or Wave 0 dependency remains.
- [x] Planned test paths match 02-01 through 02-04 exactly.
- [x] No watch-mode flags are used.
- [x] Focused task feedback latency is under 60 seconds; slow full-suite work is reserved for the final gate.
- [x] `nyquist_compliant: true` and `wave_0_complete: true` are set in frontmatter.

**Approval:** ready for execution
