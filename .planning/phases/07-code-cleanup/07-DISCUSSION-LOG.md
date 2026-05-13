# Phase 4: Code Cleanup - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-14
**Phase:** 07-code-cleanup
**Areas discussed:** Dead code removal scope, CustomTitleBar crash fix

---

## Dead Code Removal Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Full stack delete | Delete WindowManagerService + WindowsPlatformService + PlatformService + kernel/AspectRatioService + CustomTitleBar. ~760 lines. | |
| Safe delete only | Delete WindowManagerService (514 lines) + WindowsPlatformService (53 lines). Keep PlatformService and kernel/AspectRatioService (CustomTitleBar depends on them). | ✓ |
| Migrate then delete | Migrate CustomTitleBar to WindowBridge first, then delete full old stack. | |

**User's choice:** Safe delete only — remove WindowManagerService + WindowsPlatformService (567 lines)
**Notes:** User chose conservative approach. CustomTitleBar still depends on PlatformService and kernel/AspectRatioService, so those stay.

---

## CustomTitleBar Crash Fix

| Option | Description | Selected |
|--------|-------------|----------|
| Proxy pattern | PlatformService internally delegates to WindowBridge.I. CustomTitleBar zero changes. | ✓ |
| Migrate CustomTitleBar | Change CustomTitleBar imports from PlatformService to WindowBridge directly. | |
| Both | Proxy first for safety, then migrate gradually, then delete PlatformService. | |

**User's choice:** Proxy pattern — PlatformService delegates to WindowBridge.I transparently
**Notes:** This is the minimal-change approach. CustomTitleBar code stays untouched. The proxy auto-discovers WindowBridge.I on first access, no init() call needed.

---

## Claude's Discretion

- A key callback wiring (CODE-02): not discussed, planner has full discretion
- AspectRatio label localization (CODE-03): not discussed, planner picks approach
- dart analyze warnings (CODE-04): not discussed, planner decides whether to fix info-level warnings
- Overlay cleanup (CODE-05): noted as already satisfied by Phase 01 OverlayPortal migration

## Deferred Ideas

- Full PlatformService removal (requires CustomTitleBar migration)
- kernel/AspectRatioService removal (requires CustomTitleBar migration)
- CustomTitleBar → WindowBridge migration (future cleanup phase)
