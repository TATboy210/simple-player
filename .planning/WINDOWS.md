---
schema_version: 1
open_count: 1
waived_count: 0
fixed_count: 0
total_count: 1
last_updated: 2026-07-23T17:35:51.126Z
---

# Broken Windows Ledger

> Cross-phase defect register. `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 25 | stub | lib/ui/dialogs/settings/tabs/general_tab.dart |  | Skeleton controls persist to PendingSettingsState only, not wired to real services | open |  | 2026-07-23T17:35:51.126Z |  |

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
  }
]
````
