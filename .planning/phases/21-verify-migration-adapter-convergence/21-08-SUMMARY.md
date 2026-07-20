---
phase: 21-verify-migration-adapter-convergence
plan: 08
subsystem: kernel
tags: [test, adapter, coverage, kernel]
dependency:
  requires: ["21-03"]
  provides: ["VERIFY-05"]
  affects: ["kernel/adapter"]
tech_stack:
  added: []
  patterns: ["FakeEngine test pattern", "DelegationPolicy routing verification"]
key_files:
  created:
    - test/kernel/adapter/kernel_adapter_routing_test.dart
    - test/kernel/adapter/delegation_policy_test.dart
  modified: []
decisions:
  - "Use KernelLoggerImpl.init() in setUpAll for EngineStateMachine tests"
  - "setMute/setD3d11SyncEnabled route via _targetFor (migratedMethods), not capability fields"
metrics:
  duration: "12min"
  completed: "2026-07-20"
  tasks: 2
  files: 2
status: complete
---

# Phase 21 Plan 08: KernelAdapter & DelegationPolicy Coverage Summary

Pure Dart unit tests for KernelAdapter routing logic and DelegationPolicy construction, lifting kernel/ coverage from 55% toward 80%.

## What Was Built

- **kernel_adapter_routing_test.dart** (26 tests): Per-method routing via `migratedMethods`, per-capability field routing (stateView/volume/track/subtitle/videoEffect/renderer), `DelegationPolicy.all()` constructor, dispose behavior (legacy vs migrated engine + bundle cascade), DiagnosticsBundle forwarding, identity-preserving ValueNotifier forwarding (ADAPT-03)
- **delegation_policy_test.dart** (14 tests): `all()` constructor (legacy/migrated), per-field constructor with mixed modes, `migratedMethods` contains/empty/immutable behavior, const constructibility, KernelMode enum validation

## Key Decisions

1. **KernelLoggerImpl.init() required**: `EngineStateMachine.transitionTo` calls `KernelLoggerImpl.I` internally. Tests must call `KernelLoggerImpl.resetForTesting()` + `KernelLoggerImpl.init()` in `setUpAll`.
2. **Per-method vs per-capability routing**: Methods like `setMute`, `setD3d11SyncEnabled` use `_targetFor()` (checks `migratedMethods`), not the capability field directly. Capability fields (stateView, volume getters) route via `_policy.<field>`. Tests correctly model this dual routing.
3. **copyWith extension for DelegationPolicy**: Since `DelegationPolicy` is a `final class` with all-final fields, a test-only `copyWith` extension enables selective field overrides without polluting production code.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed AudioTrackInfo constructor parameters**
- **Found during:** Task 1
- **Issue:** Plan used `AudioTrackInfo(id: 0, name: 'Track 0')` but actual constructor uses `index` and `language` fields, not `id` and `name`
- **Fix:** Changed to `AudioTrackInfo(index: 0, language: 'en')` with correct field assertions
- **Files modified:** `test/kernel/adapter/kernel_adapter_routing_test.dart`

**2. [Rule 2 - Missing] Added KernelLoggerImpl initialization**
- **Found during:** Task 1
- **Issue:** `EngineStateMachine.transitionTo` calls `KernelLoggerImpl.I` which throws `StateError` if not initialized. Plan did not mention this requirement.
- **Fix:** Added `KernelLoggerImpl.resetForTesting()` + `KernelLoggerImpl.init()` in `setUpAll`
- **Files modified:** `test/kernel/adapter/kernel_adapter_routing_test.dart`

**3. [Rule 1 - Bug] Corrected setMute/setD3d11SyncEnabled routing model**
- **Found during:** Task 1
- **Issue:** Tests initially assumed `setMute` routes via `_policy.volume` field and `setD3d11SyncEnabled` via `_policy.renderer`. In reality, these methods use `_targetFor()` (per-method routing via `migratedMethods`), while only the ValueNotifier getters route via capability fields.
- **Fix:** Updated test setup to use `migratedMethods: {'setMute'}` and `migratedMethods: {'setD3d11SyncEnabled'}` respectively
- **Files modified:** `test/kernel/adapter/kernel_adapter_routing_test.dart`

## Known Stubs

None — all tests exercise real KernelAdapter/DelegationPolicy code paths.

## Threat Flags

None — test-only changes, no new production surface.

## Self-Check: PASSED
