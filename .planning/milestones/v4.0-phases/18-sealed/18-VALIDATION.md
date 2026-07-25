---
phase: 18
slug: sealed
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-19
---

# Phase 18 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK) |
| **Config file** | pubspec.yaml (dev_dependencies) |
| **Quick run command** | `flutter test test/kernel/models/player_error_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/kernel/models/player_error_test.dart test/widget/player/error_banner_test.dart`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 18-01-01 | 01 | 1 | ERR-01 | — | ErrorContext + isFatal + l10nKey + recoverable enums | unit | `flutter test test/kernel/models/player_error_test.dart` | ✅ (extend) | ⬜ pending |
| 18-01-02 | 01 | 1 | ERR-02 | — | isFatal = !code.recoverable, no silent Error catch | unit | `flutter test test/kernel/models/player_error_test.dart` | ✅ (extend) | ⬜ pending |
| 18-02-01 | 02 | 2 | ERR-03 | T-18-01 | Three-step catch pattern (construct + assign + log) | unit | `flutter test test/kernel/engine/fvp_engine_error_test.dart` | ❌ W0 | ⬜ pending |
| 18-03-01 | 03 | 2 | ERR-04 | — | ErrorBanner uses l10nKey, not raw sealed object | widget | `flutter test test/widget/player/error_banner_test.dart` | ✅ (extend) | ⬜ pending |
| 18-04-01 | 04 | 3 | ERR-05 | — | mdk callback errors marshalled with callbackStackTrace | unit | `flutter test test/kernel/engine/fvp_callback_handler_error_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/kernel/engine/fvp_engine_error_test.dart` — covers ERR-03 (three-step pattern verification)
- [ ] Extend `test/kernel/engine/fvp_callback_handler_test.dart` — covers ERR-05 (thread marshalling with ErrorContext)
- [ ] Extend `test/kernel/models/player_error_test.dart` — add ErrorContext/isFatal/l10nKey/recoverable tests
- [ ] Extend `test/widget/player/error_banner_test.dart` — add l10nKey translation tests

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| ErrorContext path redaction in UI | ERR-04 | Visual verification of l10nKey fallback | Trigger file-not-found error, verify ErrorBanner shows localized message without internal path |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
