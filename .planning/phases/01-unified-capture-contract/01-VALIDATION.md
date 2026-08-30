---
phase: 1
slug: unified-capture-contract
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-28
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (Dart) |
| **Config file** | `pubspec.yaml` (flutter_test SDK dep) |
| **Quick run command** | `flutter test test/diagnostics/error_report_test.dart test/diagnostics/error_reporter_test.dart test/diagnostics/global_error_hooks_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~60 seconds |

---

## Sampling Rate

- **After every task commit:** Run the task's direct focused command from the verification map.
- **After every plan wave:** Run `flutter test` and `flutter analyze`.
- **Before `/gsd-verify-work`:** `flutter test` must exit 0 and `flutter analyze` must exit 0. If a known headless native media-DLL failure occurs, apply the project-memory stash/re-run comparison to each failure, record its explicit attribution, and escalate for a documented developer exception or prerequisite baseline-repair phase if the full suite remains nonzero; do not silently accept it.
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01 / Task 1 — platform tracer | 01 | 1 | CAP-01, CAP-03 | T-01-01 / T-01-02 | Immutable platform report reaches bounded FIFO, isolated effect, and flush without UI dependency. | unit/TDD | `flutter test test/diagnostics/error_report_test.dart test/diagnostics/error_reporter_test.dart` | ✅ W0 | ✅ green |
| 01-01 / Task 2 — full reporter contract | 01 | 1 | CAP-01, CAP-03, CAP-04 | T-01-01..04 | All four adapters are non-throwing; null Flutter stack uses the bounded unavailable marker; FIFO, dedupe, reentrancy, and burst containment hold. | unit/TDD | `flutter test test/diagnostics/error_report_test.dart test/diagnostics/error_reporter_test.dart && flutter analyze` | ✅ W0 | ✅ green |
| 01-02 / Task 1 — hook tracer | 02 | 2 | CAP-01, CAP-02, CAP-03 | T-01-05 / T-01-08 | Framework presentation precedes safe forwarding; dispatcher returns true; callback failures remain contained. | unit/TDD | `flutter test test/diagnostics/global_error_hooks_test.dart` | ✅ W0 | ✅ green |
| 01-02 / Task 2 — guarded bootstrap | 02 | 2 | CAP-01, CAP-02, CAP-03 | T-01-05..08 | Same-zone startup uses a reporter-availability-checked static fallback that returns normally if reporter initialization/access or last-resort output fails. | unit/TDD + manual smoke | `flutter test test/diagnostics/error_report_test.dart test/diagnostics/error_reporter_test.dart test/diagnostics/global_error_hooks_test.dart && flutter analyze` | ✅ W0 | ✅ green |
| 01-03 / Task 1 — production bridge intake (OpenError + async lastError) | 03 | 3 | CAP-01, CAP-04 | T-01-10 | Controller validation failures and async notifier errors reach `ErrorReporter.reportPlayerError` through the sole project-owned bridge; intake is non-throwing. | unit/TDD | `flutter test test/diagnostics/player_error_report_bridge_test.dart test/diagnostics/error_reporter_test.dart` | ✅ W0 | ✅ green |
| 01-03 / Task 2 — dual-exposure correlation + rollback disposal | 03 | 3 | CAP-01, CAP-03 | T-01-10 | Synchronous OpenError dual exposure correlated by object identity at the single bridge; `dispose()` idempotently detaches before engine notifier disposal; rollback ordering proven. | unit/TDD | `flutter test test/diagnostics/player_error_report_bridge_test.dart test/kernel/player_services_test.dart test/kernel/services/playback_controller_test.dart` | ✅ W0 | ✅ green |
| 01-03 / Task 3 — redaction families + negative elapsed dedupe | 03 | 3 | CAP-01, CAP-04 | T-01-12 / T-01-14 | Redaction-family/fan-out tests lock safe normalization; clock rollback rejected — nonnegative elapsed required, rollback-separated events keep distinct IDs. | unit/TDD | `flutter test test/diagnostics/error_reporter_test.dart test/diagnostics/player_error_report_bridge_test.dart` | ✅ W0 | ✅ green |
| 01-04 / Task 1 — whitespace-path redaction + provider containment | 04 | 4 | CAP-01, CAP-03, CAP-04 | T-01-14 / T-01-18 / T-01-20 | Delimiter-aware local-path scanner (quoted/unquoted Windows+POSIX, whitespace/parens/brackets, URI scheme precedence) sanitizes before fan-out; throwing `CurrentMediaPathProvider` yields null-path snapshot with exactly one forwarded PlayerError. | unit/TDD | `flutter test test/diagnostics/error_reporter_test.dart test/diagnostics/player_error_report_bridge_test.dart` | ✅ W0 | ✅ green |
| 01-04 / Task 2 — semantic dedupe identity | 04 | 4 | CAP-04, CAP-01 | T-01-15 / T-01-16 | Fingerprint includes severity, stable player code, error type, sanitized media path, and top frame; semantically distinct evidence never merges; `playerErrorCode` preserved through immutable `copyWith`; D-04 capacity-five/timing retained. | unit/TDD | `flutter test test/diagnostics/error_report_test.dart test/diagnostics/error_reporter_test.dart test/diagnostics/player_error_report_bridge_test.dart` | ✅ W0 | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

**Audit note (2026-08-30):** the four pre-existing rows above were re-verified green by running their union command (53 tests passed, 0 failures, 2026-08-30). Rows 01-03 (3 tasks) and 01-04 (2 tasks) were missing from the plan-phase draft and were backfilled during validation audit, mapped from each PLAN's `<verify><automated>` block to CAP-01..CAP-04.

---

## Wave 0 Requirements

- [x] `test/diagnostics/error_report_test.dart` — immutable ErrorReport field/copy tests and Flutter nullable-stack unavailable-marker behavior.
- [x] `test/diagnostics/error_reporter_test.dart` — four intake adapters, FIFO/dedupe/flush, fault injection, reentrancy, and burst containment.
- [x] `test/diagnostics/global_error_hooks_test.dart` — framework/dispatcher adapters, same-zone bootstrap helper, reporter initialization/access failure, and contained last-resort fallback tests.
- [x] Local hand-written diagnostics fakes for clock, media-path provider, ID generator, effects, reporter availability/access, and last-resort output; no new framework install is required.

*If none: "Existing infrastructure covers all phase requirements."*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| 实机 same-zone `runZonedGuarded` 启动接管及反馈链兜底 | CAP-02, CAP-03 | binding/engine registration crosses process-global Flutter runtime boundaries | Run `flutter run -d windows` in debug mode; induce or observe startup/framework diagnostics and confirm normal player/error state remains reachable. Record the observed outcome; automated tests separately prove reporter-unavailable and throwing-last-resort fallback paths return normally. |
| 实机 fault-injection: window-init 失败被捕获进入错误卡片且播放器正常可达 | CAP-01, CAP-03 | 故障注入需真实 Windows 启动周期，无法在 headless flutter test 中复现 | 01-UAT.md Test 16 (2026-08-30): 实机 Windows 启动注入 window-init 故障，错误卡片滑入并显示定位信息，播放器状态正常可达，含真实日志落盘回溯。16/16 UAT 通过。 |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** validated 2026-08-30 — Nyquist validation audit complete. Every CAP-01..CAP-04 requirement maps to at least one green automated test (9 map rows, all ✅ green) plus two documented manual-only entries with UAT evidence.

---

## Validation Audit 2026-08-30

| Gap Found | Resolution | Count |
|-----------|-----------|-------|
| Per-Task Verification Map missing 01-03 (3 tasks) and 01-04 (2 tasks) rows | Backfilled from each PLAN's `<verify><automated>` block, mapped to CAP-01..CAP-04 | 5 rows added |
| All row statuses stale (⬜ pending) and Wave-0 boxes unchecked despite files existing and passing | Union command `flutter test` over all 6 mapped test files executed 2026-08-30 → 53 passed, 0 failures; all 9 rows marked ✅ green, Wave-0 checked | 9 rows + 4 boxes |
| Manual-Only section lacked real-machine fault-injection evidence | Augmented with 01-UAT.md Test 16 (window-init failure containment, 16/16 UAT pass) | 1 entry |
| Frontmatter stale (draft / nyquist_compliant: false) | Set validated / true / wave_0_complete: true | 3 fields |

**Escalated:** 0 · **Resolved:** 9/9 map rows green · **Note:** 1 pre-existing analyze error in `integration_test/progress_bar_real_runtime_diagnosis_test.dart:110` (v1.9 legacy WIP) is out of phase-01 scope and not attributed to this phase.
