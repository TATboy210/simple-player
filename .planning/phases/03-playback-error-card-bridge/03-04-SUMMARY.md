---
phase: 03-playback-error-card-bridge
plan: 04
subsystem: ui/player + kernel/diagnostics
tags: [error-card, migration, deletion, MIG-01, D-07, D-09]
requires:
  - 03-01 (ErrorCardHost 全局挂载形态)
  - 03-02 (FIFO 头部展示 + l10nKey 解析迁移)
  - 03-03 (severity 路由 + 徽标轮播)
provides:
  - 单一错误展示路径（ErrorCard 经 PlayerErrorReportBridge → ErrorReporter）
  - MIG-01 等效覆盖测试（卡片路径集成证据）
affects:
  - lib/ui/player/player_video_controls.dart（无横幅挂载）
  - lib/kernel/models/player_error.dart（doc comment 指向 ErrorCard）
tech-stack:
  added: []
  patterns:
    - 删前双路径等效判定（同一断言 helper 对新旧 harness 各跑一遍）
    - grep 门（case-sensitive `ErrorBanner` 字面量零匹配）作为删除收尾硬门
key-files:
  created:
    - test/widget/player/error_banner_equivalence_test.dart（Task 1，269 行 → 收窄后 231 行卡片路径集成证据）
  modified:
    - lib/ui/player/player_video_controls.dart（移除 import + Positioned 挂载子树，替换为 ErrorCardHost 指向注释）
    - lib/kernel/models/player_error.dart（l10nKey doc comment 消费方改为 ErrorCard，D7 键格式保留）
    - lib/ui/player/error_card.dart（迁移基线 doc comment 措辞更新——计划外 Rule 3 修复）
  deleted:
    - lib/ui/player/error_banner.dart（142 行旧横幅）
    - test/widget/player/error_banner_test.dart（旧断言基线，已由等效测试继承）
key-decisions:
  - 旧横幅删除经 Task 1 双路径等效证明 + Task 2 用户批准（D-07 不可逆门）；动作按钮（reopen/retry）按 D-09 不迁移
  - error_card.dart 的 ErrorBanner doc comment 字面量同步改为「旧横幅（legacy banner）」措辞——grep 门扫全部 lib/ test/，残留会使门自失败（Rule 3）
  - 等效测试文件名保留 error_banner_ 前缀（snake_case 小写，不匹配 case-sensitive grep 门），作为删除历史的可检索锚点
requirements-completed:
  - MIG-01
coverage:
  - deliverable: MIG-01 等效覆盖测试（删前双路径判定）
    verification: "flutter test test/widget/player/error_banner_equivalence_test.dart — Task 1 (372b10a9) 双路径 6 用例全绿"
  - deliverable: ErrorBanner 全量删除（widget + test + 挂载 + doc 引用）
    verification: "grep -rq ErrorBanner lib/ test/ → 零匹配；git diff HEAD~1 HEAD --diff-filter=D 仅两目标文件"
  - deliverable: 卡片路径集成证据（收窄后等效测试）
    verification: "flutter test test/widget/player/ → 313 用例全绿（含收窄后 6 用例）"
  - deliverable: 全量质量门
    verification: "flutter analyze → 0 error（59 info 均预存风格项）；bash tool/audit/kernel_logger_gate.sh → GATE 1+2 PASS"
duration: 4 min（Task 3 续接会话；Task 1 时长记于前次会话）
completed: 2026-08-31
status: complete
actuals:
  tokens: 11000
  tasks: 3
  commits: 2
---

# Phase 3 Plan 04: ErrorBanner 删除收尾 Summary

**One-liner:** 旧错误横幅（142 行 widget + 测试 + 挂载子树 + doc 引用）经删前双路径等效证明与用户批准后全量删除，错误展示收敛为 ErrorCard 单一路径，四重质量门（grep 零残留 / analyze 0 error / 313 测试全绿 / kernel_logger_gate）收尾。

## What Was Built

MIG-01 收官三任务链：

1. **Task 1（commit 372b10a9）**：`test/widget/player/error_banner_equivalence_test.dart` —— 删除前对旧横幅路径（FakeEngine 直连）与卡片路径（FakeEngine → 真实 PlayerErrorReportBridge → ErrorReporterImpl → ErrorCardHost）同时断言同一组代表性 PlayerError case（fileNotFound / unsupportedFormat / playFailed / unknown + pathTraversal isFatal）给出相同 l10n 消息与可辨认严重级。等效 = 消息 + 严重级可见性（D-09）；动作按钮不迁移；occurrenceCount 为新路径增量能力（非等效破坏项）。
2. **Task 2（人工门）**：用户批准删除（选项 A）。
3. **Task 3（commit 0805618b）**：执行删除 + 质量门收尾（本 SUMMARY 主体）。

## Task Commits

| Task | Commit | Description |
| ---- | ------ | ----------- |
| 1 | 372b10a9 | test(03-04): add MIG-01 dual-path equivalence suite (pre-deletion gate, D-07/D-09) |
| 2 | — | checkpoint:human-verify（用户批准，无 commit） |
| 3 | 0805618b | feat(03-04): delete legacy error banner — single card path closeout (MIG-01/D-07) |

## Quality Gates (Task 3 收尾)

| Gate | Command | Result |
| ---- | ------- | ------ |
| 残留引用 | `grep -rq ErrorBanner lib/ test/` | PASS — 零匹配 |
| 目录测试 | `flutter test test/widget/player/` | PASS — 313 用例全绿 |
| 静态分析 | `flutter analyze` | PASS — 0 error（59 info 为预存风格项，非本计划引入） |
| 日志红线 | `bash tool/audit/kernel_logger_gate.sh` | PASS — GATE 1+2 |

Headless 预存失败基线：本次 widget/player 目录运行无任何失败，无需基线鉴别。

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] error_card.dart:101 doc comment 残留 ErrorBanner 字面量**
- **Found during:** Task 3 删除后 grep 门预检
- **Issue:** 计划 `files_modified` 未列出 `lib/ui/player/error_card.dart`，但其迁移基线 doc comment 含 `ErrorBanner` 字面量（"03-04 删除 ErrorBanner 后零解析能力缺口"），删除后会使 grep 门自失败。
- **Fix:** 同步改写为「旧横幅（legacy banner，03-04 已删除）」措辞；顺带把同注释块内的小写 `error_banner.dart` 引用一并改为措辞描述（该处不触门，仅为准确性）。零语义变更。
- **Files modified:** lib/ui/player/error_card.dart
- **Commit:** 0805618b

### Intentional Plan-Following Notes

- player_video_controls.dart 挂载位置留下一行指向注释（ErrorCardHost 全局挂载语义），替代被删的中文注释行——便于后续维护者定位新路径，不属挂载残留。
- 等效测试文件名保留 `error_banner_` 前缀：snake_case 小写不匹配 case-sensitive grep 门（`ErrorBanner`），且为删除历史保留可检索锚点；文件内措辞一律「旧横幅/legacy banner」。

## Requirements Completed

- [x] MIG-01 —— 旧 ErrorBanner 在新卡片被证明对同一引擎错误给出等效可见反馈（消息 + 严重级）后干净移除，错误展示仅剩单一卡片路径。

## Deferred Items

- Windows 实机冒烟（卡片显示期间控件命中/全屏显示）——登记 VER-04 待办（widget 测试无法证明实机 hit-testing/全屏行为，项目 memory 既有结论）。

## Self-Check: PASSED
