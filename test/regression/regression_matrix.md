# Fullscreen Regression Matrix

**Branch:** feat/v1.8-stability-polish-plan-02-02
**Build:** {commit hash}
**Flags:** USE_NEW_FULLSCREEN={true|false}, USE_WINDOWS_NATIVE_FULLSCREEN={true|false}
**Date:** 2026-07-10
**Tester:** CI / Manual

## Results

| Case ID     | Platform | Scenario                                    | Type   | Priority | Result   | Evidence |
|-------------|----------|---------------------------------------------|--------|----------|----------|----------|
| FS-WIN-001  | Windows  | Enter/exit fullscreen                       | Auto   | P0       | {result} | {log}    |
| FS-WIN-002  | Windows  | Playing + fullscreen                        | Auto   | P0       | {result} | {log}    |
| FS-WIN-003  | Windows  | Paused + fullscreen                         | Auto   | P0       | {result} | {log}    |
| FS-WIN-004  | Windows  | F key vs button consistency                 | Auto   | P0       | {result} | {log}    |
| FS-WIN-005  | Windows  | ESC semantic (exit fullscreen)              | Auto   | P0       | {result} | {log}    |
| FS-WIN-006  | Windows  | Maximised -> fullscreen -> exit restore     | Auto   | P0       | {result} | {log}    |
| FS-WIN-007  | Windows  | Secondary display position restore          | Auto   | P0       | {result} | {log}    |
| FS-WIN-008  | Windows  | Multi-window isolation                      | Auto   | P0       | {result} | {log}    |
| FS-WIN-009  | Windows  | Rapid F key 10x (high-risk)                 | Auto   | P0       | {result} | {log}    |
| FS-WIN-010  | Windows  | Rapid F key 50x (high-risk)                 | Auto   | P0       | {result} | {log}    |
| FS-WIN-011  | Windows  | StateDesync recovery (fail + retry)         | Auto   | P0       | {result} | {log}    |
| FS-WIN-012  | Windows  | Minimised -> fullscreen handling            | Manual | P0       | {result} | {log}    |
| FS-MAC-001  | macOS    | Enter/exit fullscreen                       | Manual | P1       | {result} | {log}    |
| FS-MAC-002  | macOS    | Playing + fullscreen                        | Manual | P1       | {result} | {log}    |
| FS-MAC-003  | macOS    | Paused + fullscreen                         | Manual | P1       | {result} | {log}    |
| FS-MAC-004  | macOS    | Maximised -> fullscreen -> exit restore     | Manual | P1       | {result} | {log}    |
| FS-MAC-005  | macOS    | 10 consecutive toggles                      | Manual | P1       | {result} | {log}    |
| FS-MAC-006  | macOS    | ESC semantic                                | Manual | P1       | {result} | {log}    |
| FS-LIN-001  | Linux    | Enter/exit fullscreen (GNOME)               | Manual | P1       | {result} | {log}    |
| FS-LIN-002  | Linux    | Playing + fullscreen (GNOME)                | Manual | P1       | {result} | {log}    |
| FS-LIN-003  | Linux    | Paused + fullscreen (GNOME)                 | Manual | P1       | {result} | {log}    |
| FS-LIN-004  | Linux    | Maximised -> fullscreen -> exit (GNOME)     | Manual | P1       | {result} | {log}    |
| FS-LIN-005  | Linux    | 10 consecutive toggles (GNOME)              | Manual | P1       | {result} | {log}    |
| FS-LIN-006  | Linux    | ESC semantic (GNOME)                        | Manual | P1       | {result} | {log}    |

## Coverage Mapping

| Case ID     | v1 Requirement | Behavior                              |
|-------------|----------------|---------------------------------------|
| FS-WIN-001  | RST-01         | Windowed -> FS -> Exit restore        |
| FS-WIN-002  | STATE-01       | FullscreenSnapshot fields correct     |
| FS-WIN-003  | STATE-01       | FullscreenSnapshot fields correct     |
| FS-WIN-004  | ARCH-01        | FullscreenAdapter independent         |
| FS-WIN-005  | RST-01         | Windowed -> FS -> Exit restore        |
| FS-WIN-006  | RST-02         | Maximised -> FS -> Exit restore       |
| FS-WIN-007  | RST-03         | Secondary display restore             |
| FS-WIN-008  | STATE-03       | Per-window state isolation            |
| FS-WIN-009  | CMD-02         | Idempotent merge (rapid toggle)       |
| FS-WIN-010  | CMD-02         | Idempotent merge (rapid toggle 50x)   |
| FS-WIN-011  | ERR-02         | Error events notify + recovery        |
| FS-WIN-012  | RST-04         | Minimised -> FS handling              |
| FS-MAC-001  | RST-01         | Windowed -> FS -> Exit restore        |
| FS-MAC-002  | STATE-01       | FullscreenSnapshot fields correct     |
| FS-MAC-003  | STATE-01       | FullscreenSnapshot fields correct     |
| FS-MAC-004  | RST-02         | Maximised -> FS -> Exit restore       |
| FS-MAC-005  | CMD-02         | Idempotent merge                      |
| FS-MAC-006  | RST-01         | ESC exit semantic                     |
| FS-LIN-001  | RST-01         | Windowed -> FS -> Exit restore        |
| FS-LIN-002  | STATE-01       | FullscreenSnapshot fields correct     |
| FS-LIN-003  | STATE-01       | FullscreenSnapshot fields correct     |
| FS-LIN-004  | RST-02         | Maximised -> FS -> Exit restore       |
| FS-LIN-005  | CMD-02         | Idempotent merge                      |
| FS-LIN-006  | RST-01         | ESC exit semantic                     |

## Blocking Rules

| Condition                                  | Severity | Action           |
|--------------------------------------------|----------|------------------|
| P0 test failure                            | BLOCKER  | Block release    |
| StateDesync without recovery               | BLOCKER  | Block release    |
| Any platform: state corruption/unrecoverable window/freeze | BLOCKER  | Block release    |
| macOS/Linux smoke failure rate >10%        | HIGH     | Upgrade to deep test |
| P1 test failure on Windows                 | HIGH     | Should fix       |
| P1 test failure on macOS/Linux             | MEDIUM   | Fix if time permits |

## Build Configuration Record

Every test run MUST record:

| Field                              | Description                          |
|------------------------------------|--------------------------------------|
| Branch                             | Git branch name                      |
| Commit                             | Git commit hash                      |
| USE_NEW_FULLSCREEN                 | true / false                         |
| USE_WINDOWS_NATIVE_FULLSCREEN      | true / false                         |
| Flutter SDK version                | flutter --version output             |
| Date                               | YYYY-MM-DD                           |
| Tester                             | CI / manual tester name              |

## Failure Severity Levels

| Level    | Definition                                              | Blocks Release? |
|----------|---------------------------------------------------------|-----------------|
| BLOCKER  | State corruption, unrecoverable window, crash, freeze   | YES             |
| HIGH     | Functional regression, wrong restore mode, missed event | YES (should fix)|
| MEDIUM   | Edge case failure, non-critical path                    | NO (fix if time)|
| LOW      | Cosmetic, logging, documentation                       | NO              |

## Execution Strategy

| Phase              | Scope                          | Frequency              |
|--------------------|--------------------------------|------------------------|
| Per Plan commit    | Related regression subset      | Every commit           |
| Weekly             | Cross-platform smoke           | Weekly                 |
| RC gate            | Full regression matrix         | Before RC release      |

**Linux note:** Smoke tests target GNOME as primary WM. Other WMs (KDE, XFCE) are best-effort.

## Test File Mapping

| Test File                              | Case IDs Covered           |
|----------------------------------------|----------------------------|
| test/regression/high_risk_suite_test.dart | FS-WIN-009, FS-WIN-010, FS-WIN-011, FS-WIN-006, FS-WIN-008 |
| test/regression/smoke_suite_test.dart  | FS-WIN-001 ~ FS-WIN-008    |
