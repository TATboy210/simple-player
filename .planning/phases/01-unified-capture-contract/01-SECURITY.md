---
phase: "01"
slug: "unified-capture-contract"
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
created: "2026-08-30"
---

# Phase 01 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.
> Register authored at plan time (4 × `<threat_model>` blocks, T-01-01..T-01-21 incl. supplemental T-01-SC); verified post-implementation at ASVS L1.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Flutter/runtime/player error → reporter | Exception type, message, stack text, and PlayerError context are untrusted diagnostic payloads. | Unbounded text, stacks, paths, player codes |
| Reporter → effects/listeners | Extension effects and ValueNotifier listeners can throw or recursively invoke reporting. | Event callbacks, reentrant intake |
| Reporter → future presentation host | A pre-runApp queue crosses to a later UI readiness boundary without synchronous UI work now. | Queued ErrorReport snapshot |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-01-01 | Denial of Service | error_reporter | high | mitigate | Bounded text/stack/frame limits + 5-item FIFO; queue eviction (error_reporter.dart:45-53, 274-288); duplicate-storm tests | closed |
| T-01-02 | Denial of Service | error_reporter | high | mitigate | `_isReporting` reentrancy guard reset in `finally` (:210-237); publication/effects separately contained (:392-425); fault tests | closed |
| T-01-03 | Information Disclosure | error_reporter | medium | mitigate | Input-derived message/stack/media-path sanitized and bounded before `ErrorReport` construction (:249-270); no telemetry transport exists | closed |
| T-01-04 | Tampering | error_reporter | medium | mitigate | Payloads treated as bounded opaque strings; redact-then-bound (:251-255, 371-378); typed record dedupe identity (:328-343); no accepted-report logging effect | closed |
| T-01-05 | Denial of Service | global_error_hooks | high | mitigate | Framework presentation and reporter forwarding independently contained; platform handler always returns true (global_error_hooks.dart:69-102); callback-containment tests | closed |
| T-01-06 | Repudiation | main bootstrap | medium | mitigate | Handled window-init failure retains `windowInitError`, logs original error/stack, forwards exactly once (main.dart:52-60); UAT Test 16 evidence | closed |
| T-01-07 | Tampering | main bootstrap | medium | mitigate | `runZonedGuarded` established before startup work; reporter initialized before hook install (main.dart:27-39); setter-injection tests | closed |
| T-01-08 | Information Disclosure | global_error_hooks | medium | mitigate | Adapter forwards `FlutterErrorDetails` and exact platform error/stack to reporter interface only; no interpretation/persistence (:69-94) | closed |
| T-01-09 | Information Disclosure | diagnostic_redactor | high | mitigate | `DiagnosticRedactor` invoked before construction/queue/effects/presentation (error_reporter.dart:249-270); redaction at diagnostic_redactor.dart:12-39; e2e fan-out tests | closed |
| T-01-10 | Tampering | player_error_report_bridge | medium | mitigate | Bridge suppresses only `identical` notifier/callback PlayerError objects (:31-50); same-message distinct-object test coverage | closed |
| T-01-11 | Denial of Service | player_error_report_bridge | high | mitigate | Exactly one `MediaEngine.lastError` listener, idempotent removal (:14-22, 37-42); disposed before controller/engine teardown (player_services.dart:181-191) | closed |
| T-01-12 | Repudiation | error_reporter | medium | mitigate | Dedupe merges only when elapsed is non-negative and ≤ 10s (:296-311); rollback regression test | closed |
| T-01-13 | Elevation of Privilege | diagnostics subsystem | low | accept | Immutable local diagnostic text receives no command execution, HTML interpretation, remote transport, or path-based filesystem action — see Accepted Risks | open (below high threshold) |
| T-01-14 | Information Disclosure | diagnostic_redactor | high | mitigate | Delimiter-aware scan preserves legal whitespace/parens/brackets in local-path tokens, retains basename only (:53-105, 189-194); quoted/unquoted tests | closed |
| T-01-15 | Tampering | error_reporter | high | mitigate | FIFO identity = source + severity + runtime type + structured player code + sanitized message/media-path + top frame (:328-343); semantic-separation tests | closed |
| T-01-16 | Repudiation | error_report | medium | mitigate | `ErrorReport.playerErrorCode` immutable and copy-preserved (error_report.dart:70-105); exhaustive sealed-error projection (error_reporter.dart:345-354) | closed |
| T-01-17 | Denial of Service | diagnostic_redactor | medium | mitigate | Single forward scanner with monotonic index (:23-39); reporter snapshots bounded (:50-53, 385-390) | closed |
| T-01-18 | Spoofing | diagnostic_redactor | medium | mitigate | Non-file URI schemes rejected before local-path recognition (:42-50, 149-160); scheme-preservation tests | closed |
| T-01-19 | Elevation of Privilege | diagnostics subsystem | low | accept | Same rationale as T-01-13 — retained diagnostic strings have no execution/interpretation/transport/filesystem sink in Phase 01 — see Accepted Risks | open (below high threshold) |
| T-01-20 | Denial of Service | player_error_report_bridge | high | mitigate | Optional media metadata independently contained, falls back to null (:53-70); provider failure still yields exactly one forwarding call (test :92-112). Bridge's broad `on Object` is the planned CAP-03 containment (keeps player callbacks non-throwing), not an unmitigated condition | closed |
| T-01-SC | Tampering | diagnostics subsystem | high | mitigate | No package-manager or process-launch invocation exists anywhere in lib/kernel/diagnostics/ or its composition wiring in main.dart | closed |

*Status: open · closed · open — below high threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above workflow.security_block_on count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-01 | T-01-13 | Phase 01 diagnostics retain local, immutable diagnostic strings that are never passed to any command execution, HTML/markdown interpretation, remote transport, or path-based filesystem operation. The subsystem's only sinks are the in-memory FIFO and future UI presentation. Risk of privilege elevation via retained text is therefore structural: no sink exists to elevate into. Revisit if a future phase introduces file export (Phase 02 落盘) or clipboard effects — that phase must re-verify this threat. | Security auditor (gsd-security-auditor) + orchestrator, per plan-time `accept` disposition | 2026-08-30 |
| AR-02 | T-01-19 | Same rationale as AR-01: the accept disposition was authored at plan time for the post-redaction retained-evidence path (basename-only media path + bounded message/frame text). No execution, interpretation, transport, or filesystem sink touches retained strings in Phase 01. Same re-verification trigger as AR-01 applies for Phase 02 file-sink introduction. | Security auditor (gsd-security-auditor) + orchestrator, per plan-time `accept` disposition | 2026-08-30 |

*Accepted risks do not resurface in future audit runs.*
*Re-verification trigger: Phase 02 (可信定位与文件证据) introduces a FileSink — T-01-13/T-01-19 must be re-audited there, since retained diagnostic text will then cross into a filesystem sink.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-30 | 21 | 19 | 2 (low, accepted per plan-time disposition, documented above) | gsd-security-auditor (ASVS L1, block_on: high) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-08-30
