---
phase: 16-diagnosticsbundle
plan: 02
subsystem: kernel/diagnostics
tags: [diagnostics, carrier, noop-skeleton, strangler-fig]
dependency-graph:
  requires: []
  provides:
    - lib/kernel/diagnostics/kernel_logger.dart (KernelLogger, NullKernelLogger)
    - lib/kernel/diagnostics/memory_monitor_slot.dart (MemoryMonitorSlot, NullMemoryMonitorSlot)
    - lib/kernel/diagnostics/metrics_slot.dart (MetricsSlot, NullMetricsSlot)
    - lib/kernel/diagnostics/event_log_slot.dart (EventLogSlot, NullEventLogSlot)
    - lib/kernel/diagnostics/diagnostics_bundle.dart (DiagnosticsBundle + .noop() factory)
  affects:
    - Plan 16-01 (KernelAdapter constructor uses DiagnosticsBundle.noop() as default)
tech-stack:
  added: []
  patterns:
    - "Const noop factory pattern (abstract interface + const Null* impl)"
    - "DI-container cascading dispose (mirrors PlayerServices.dispose())"
key-files:
  created:
    - lib/kernel/diagnostics/kernel_logger.dart
    - lib/kernel/diagnostics/memory_monitor_slot.dart
    - lib/kernel/diagnostics/metrics_slot.dart
    - lib/kernel/diagnostics/event_log_slot.dart
    - lib/kernel/diagnostics/diagnostics_bundle.dart
  modified: []
decisions:
  - "Followed PATTERNS.md verbatim copy sources for all 4 interfaces + carrier (D1/D4/D5/D6/D7/D9/D10/D11)"
  - "KernelLogger capped at exactly 6 methods, no LogLevel/sink/redaction/formatting (D7)"
  - "3 remaining slots use loose return types (Object?/Map<String,Object?>/List<Map<String,Object?>>) to avoid coupling to MemorySnapshot/EngineEvent concrete types (D9/D10)"
  - "DiagnosticsBundle.dispose() cascades to memoryMonitor/metrics/eventLog only — logger excluded (no dispose in D7-capped contract)"
metrics:
  duration: "~15 minutes"
  completed: 2026-07-18
status: complete
---

# Phase 16 Plan 02: DiagnosticsBundle Skeleton Summary

Built the 5-file `lib/kernel/diagnostics/` subpackage: 4 minimal abstract slot interfaces
(KernelLogger, MemoryMonitorSlot, MetricsSlot, EventLogSlot) each with a const `Null*` noop
implementation, plus the `DiagnosticsBundle` final-class carrier with a `const .noop()` factory
and cascading dispose — all deliberate dead code with zero Phase 16 consumers.

## What Was Built

**Task 1 — KernelLogger + NullKernelLogger** (`kernel_logger.dart`, 68 lines)
`abstract class KernelLogger` with exactly 6 methods: `trace`/`debug`/`info`/`warn` (single
positional `String message`), `error`/`fatal` (both carry `{Object? error, StackTrace?
stackTrace}` per the D6 84-call-site census — 3 of 84 live `.e()` sites pass named args in 2
shapes). `final class NullKernelLogger implements KernelLogger` is `const`-constructible with
empty bodies for all 6 methods. D8 level-mapping table (log*.t/d/i/w/e/f -> trace/debug/info/
warn/error/fatal) documented in the class-level doc comment. No `LogLevel` enum, sink
interface, redaction API, or formatting added (D7) — that machinery is Phase 17's job hidden
behind this interface.

**Task 2 — 3 slot interfaces + Null impls** (`memory_monitor_slot.dart` 40 lines,
`metrics_slot.dart` 64 lines, `event_log_slot.dart` 45 lines)
- `MemoryMonitorSlot`: `start({Duration? interval})`, `stop()`, `snapshot() -> Object?`,
  `dispose()`. Traced from `MemoryMonitor`'s public API but converted from static-singleton to
  instance-method contract (D10); `snapshot()` returns loose `Object?` to avoid coupling to
  the concrete `MemorySnapshot` type.
- `MetricsSlot`: `recordOpen`, `recordSeek`, `recordFrameDrop`, `recordDecodeError`,
  `recordBufferUnderrun`, `reset`, `toJson() -> Map<String, Object?>`, `dispose()`. Traced
  from `EngineMetrics`'s `record*` verbs; internal counter fields (framesDropped,
  `_totalSeekTime`) intentionally NOT exposed on the interface (D10).
- `EventLogSlot`: `add(String type, [Map<String, Object?>? data])`, `entries ->
  List<Map<String, Object?>>`, `clear()`, `toJson() -> List<Map<String, Object?>>`,
  `dispose()`. Traced from `EngineEventLog`'s ring buffer; `entries`/`toJson` loosened off the
  concrete `EngineEvent` type (D10).

All 3 `Null*` implementations are `const`-constructible, no-op every mutating method, and
return null/empty defaults from readers. None of the 3 interfaces declare a `static` member;
none import or reference `MemorySnapshot`/`MetricSample`/`EngineEvent` concrete types (D9/D10
verified via grep — only doc-comment mentions of those type names remain, no actual code
coupling).

**Task 3 — DiagnosticsBundle carrier** (`diagnostics_bundle.dart`, 59 lines)
`final class DiagnosticsBundle` with 4 final slot fields (`logger`, `memoryMonitor`, `metrics`,
`eventLog`). Primary `const DiagnosticsBundle({required this.logger, required
this.memoryMonitor, required this.metrics, required this.eventLog})` constructor. `const
DiagnosticsBundle.noop()` factory wires all 4 `Null*` slots — this is the sole const factory
and the value Plan 16-01's `KernelAdapter` constructor uses as its `bundle` parameter default.
`dispose()` cascades to `memoryMonitor.dispose()`, `metrics.dispose()`, `eventLog.dispose()`
(mirrors `PlayerServices.dispose()` at player_services.dart:99-109); `logger` is excluded from
the cascade since it has no `dispose` method in its D7-capped contract.

## Verification

- `flutter analyze lib/kernel/diagnostics/` — clean, no issues found across all 5 files.
- `const DiagnosticsBundle.noop()` compiles as a const value (verified via grep + successful
  analyze — enables the const default in `KernelAdapter`'s constructor per Plan 16-01).
- No `static` member on any of the 3 slot interfaces or KernelLogger (grep verified — only
  doc-comment prose mentions "static singleton" as contrast, no actual `static` keyword usage
  in code).
- No import/reference of `MemorySnapshot`/`MetricSample`/`EngineEvent` concrete types in any
  slot contract (grep verified — only doc-comment mentions).
- Total size: 276 lines across the 5 files (kernel_logger.dart 68, memory_monitor_slot.dart 40,
  metrics_slot.dart 64, event_log_slot.dart 45, diagnostics_bundle.dart 59). Slightly above the
  ~230-line target noted in the plan, driven by bilingual DOC-01 doc comments (Chinese intent +
  English contract) required by CLAUDE.md's comment policy — well within the ADAPT-05 636-line
  budget ceiling (full multi-plan gate deferred to Plan 16-05).

## Deviations from Plan

None — plan executed exactly as written. All method signatures, class shapes, and const
factory wiring copied verbatim from PATTERNS.md lines 158-186 (KernelLogger), 205-224
(MemoryMonitorSlot), 284-310 (DiagnosticsBundle), with the same pattern extended to
MetricsSlot/EventLogSlot per the plan's inline specification (Task 2 action block).

The only addition beyond the plan's minimal code is bilingual `///` doc comments on every
public class and member per CLAUDE.md's mandatory comment policy — this pushed total line
count from the plan's "~230 lines" estimate to 276, still comfortably inside the 636-line
ADAPT-05 ceiling.

## Known Stubs

All 5 files in this plan are intentional stubs by design (D2/D3) — every `Null*`
implementation is a deliberate no-op with zero behavior, and `DiagnosticsBundle` has zero
consumers until Phase 20's `NewFvpEngine`. This is not a defect; it is the plan's explicit
objective (building a construction-injected home for future diagnostics capabilities).

## Threat Flags

None. This plan introduces no new trust boundary, network endpoint, auth path, file access
pattern, or schema change — all 4 slot interfaces are pure in-memory no-op contracts with
empty method bodies (per the plan's own `<threat_model>` T-16-02/T-16-03, disposition:
accept, threat_level: low).

## Self-Check: PASSED

All 5 created files verified present on disk; all 3 task commit hashes verified in git log.
