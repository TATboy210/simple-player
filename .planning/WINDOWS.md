---
schema_version: 1
open_count: 5
waived_count: 0
fixed_count: 0
total_count: 5
last_updated: 2026-08-30T17:24:10.426Z
---

# Broken Windows Ledger

> Cross-phase defect register. With `workflow.windows_enforce` enabled, `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 25 | stub | lib/ui/dialogs/settings/tabs/general_tab.dart |  | Skeleton controls persist to PendingSettingsState only, not wired to real services | open |  | 2026-07-23T17:35:51.126Z |  |
| 2 | 31 | deviation | lib/ui/shared/focusable_setting_row.dart |  | Disabled rows retain a transparent one-pixel border slot to preserve 40px geometry | open |  | 2026-07-27T17:28:04.854Z |  |
| 3 | 31 | deviation | test/widget/settings/general_equalizer_tab_test.dart |  | Consumer regression tests rebased from stale pre-Phase-28 APIs while retaining glass and header coverage | open |  | 2026-07-27T17:28:05.584Z |  |
| 4 | 31 | unrun-verify | .planning/STATE.md |  | Full flutter analyze remains blocked by 114 pre-existing kernel bridge and stash-related diagnostics outside Phase 31-02 paths | open |  | 2026-07-27T17:28:31.722Z |  |
| 5 | 03 | stub | lib/ui/player/error_card.dart | 86 | 计数徽标 onTap 为空占位,徽标轮览接线归 03-03 | open |  | 2026-08-30T17:24:10.426Z |  |

````json
[
  {
    "id": 1,
    "kind": "stub",
    "phase": "25",
    "file": "lib/ui/dialogs/settings/tabs/general_tab.dart",
    "line": null,
    "description": "Skeleton controls persist to PendingSettingsState only, not wired to real services",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-07-23T17:35:51.126Z",
    "resolved_at": null
  },
  {
    "id": 2,
    "kind": "deviation",
    "phase": "31",
    "file": "lib/ui/shared/focusable_setting_row.dart",
    "line": null,
    "description": "Disabled rows retain a transparent one-pixel border slot to preserve 40px geometry",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-07-27T17:28:04.854Z",
    "resolved_at": null
  },
  {
    "id": 3,
    "kind": "deviation",
    "phase": "31",
    "file": "test/widget/settings/general_equalizer_tab_test.dart",
    "line": null,
    "description": "Consumer regression tests rebased from stale pre-Phase-28 APIs while retaining glass and header coverage",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-07-27T17:28:05.584Z",
    "resolved_at": null
  },
  {
    "id": 4,
    "kind": "unrun-verify",
    "phase": "31",
    "file": ".planning/STATE.md",
    "line": null,
    "description": "Full flutter analyze remains blocked by 114 pre-existing kernel bridge and stash-related diagnostics outside Phase 31-02 paths",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-07-27T17:28:31.722Z",
    "resolved_at": null
  },
  {
    "id": 5,
    "kind": "stub",
    "phase": "03",
    "file": "lib/ui/player/error_card.dart",
    "line": 86,
    "description": "计数徽标 onTap 为空占位,徽标轮览接线归 03-03",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-30T17:24:10.426Z",
    "resolved_at": null
  }
]
````
