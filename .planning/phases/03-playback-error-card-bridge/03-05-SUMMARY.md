---
phase: 03-playback-error-card-bridge
plan: 05
subsystem: ui/player
tags: [error-injection, debug-shortcut, kDebugMode, l10n, osd, gap-closure]
requires:
  - 03-01 (ErrorCardHost 全局挂载 + D-12 flushPresentation)
  - 03-03 (D-02 severity 路由 + D-11 徽标快照 effects 接线)
  - main.dart 组合根先行 ErrorReporterImpl.init（生产 intake 必可达前提）
provides:
  - 开发用错误注入入口（Ctrl+Shift+I，kDebugMode 门控）——合成错误经 ErrorReporterImpl.I 公开 intake 走全真实链路
  - 注入触发 OSD pill 反馈 + F1 帮助 debug 条目（l10n shortcutDebugInjectError）
affects:
  - lib/ui/player/shortcuts_help_dialog.dart（零改动——shortcutDefinitions 单一数据源自动渲染新条目）
tech-stack:
  added: []
  patterns:
    - kDebugMode 编译期门控 dev-only 入口（与 Ctrl+Shift+D 调试导出先例平行；collection-if 使 release F1 帮助自动折叠）
    - 计数后缀差异化 8 字段语义身份以绕过 reporter 10s 去重窗（payload-only 合成 StateError，绝不 throw）
key-files:
  created:
    - test/widget/player/keyboard_handler_debug_injection_test.dart（6 用例全链路 widget 测试）
  modified:
    - lib/ui/player/keyboard_handler.dart（static 注入计数器 + Ctrl+Shift+I 分支 + _injectTestError（reportPlatformSafely + OSD 反馈）+ shortcutDefinitions debug 条目）
    - lib/l10n/app_en.arb / lib/l10n/app_zh.arb（shortcutDebugInjectError 键）
    - lib/l10n/app_localizations.dart / app_localizations_en.dart / app_localizations_zh.dart（flutter gen-l10n 再生）
key-decisions:
  - 注入走 ErrorReporterImpl.I.reportPlatformSafely 现有公开 intake（零 kernel 改动、零 forTesting 构造器进生产路径）；reporter 未初始化不加守卫（main.dart 组合根先于 runApp，与 error_card_host.dart 直接用 .I 先例一致）
  - 合成 message 带「调试注入的合成错误 #N」计数后缀：每次按键语义身份互异，绕过 _dedupeWindow 10s 合并窗，快速连按每次出新卡
  - OSD 反馈文本用 dev-only 中文字面量（仅 kDebugMode 可达，与 speed_button '1x' 同类不进 l10n）；F1 帮助条目进 l10n（用户可见帮助文案）
  - 测试断言用相对计数递增而非绝对序号——static 计数器按设计跨 debug 会话存活，绝对 #1/#2 断言在套件内必然脆弱
requirements-completed:
  - G-03-1
coverage:
  - deliverable: 组合键 → 卡片全链路（按键 → intake → FIFO → presentation → Host → Card）
    verification: "flutter test test/widget/player/keyboard_handler_debug_injection_test.dart — 6/6 全绿（组合键用例断言 ErrorCard 恰一张 + 合成消息文本）"
  - deliverable: 去重绕过（双按两卡、各自 occurrenceCount == 1）
    verification: "双按用例断言 queuedReports 长度 2、message 互异且计数严格递增、occurrenceCount 均 1"
  - deliverable: 反馈与可发现性（OSD pill + F1 帮助条目）
    verification: "OSD 用例断言 OsdService.I.message.value?.text == '已注入测试错误' 且 icon == Icons.bug_report；帮助用例断言 shortcutDefinitions 含 'Ctrl+Shift+I' 条目"
  - deliverable: 真实链路语义（source/severity）
    verification: "字段用例断言 queuedReports.single.source == ErrorSource.platformDispatcher 且 severity == ErrorSeverity.error（D-02 error 级上常驻卡片）"
  - deliverable: 单键 I 无副作用（无误触发）
    verification: "bare-I 用例断言 queuedReports 为空且无 ErrorCard"
  - deliverable: release/MSIX 排除（kDebugMode 编译期门控）
    verification: "代码审查级证据：注入分支与 shortcutDefinitions collection-if 均由编译期 const kDebugMode 折叠，release 构建物理不含该入口（T-03-05-01 mitigation）"
  - deliverable: 实机按键观察（debug 会话 flutter run -d windows 下 Ctrl+Shift+I 弹卡 + error.log/徽标同步）
    verification: human_judgment: true — physical keyboard focus not exercisable headless — final closure evidence comes from UAT re-test（/gsd-verify-work 复测 UAT Test 1 收口 G-03-1）
gap_ids: [G-03-1]
gap_closure: true
duration: 920s（约 15 分钟）
completed: 2026-08-31
status: complete
actuals:
  tokens: 4060
  tasks: 3
  commits: 3
---

# Phase 3 Plan 05: 开发用错误注入入口（G-03-1 gap closure）Summary

**One-liner:** Ctrl+Shift+I（kDebugMode 门控）构造带计数后缀的合成错误，经 `ErrorReporterImpl.I.reportPlatformSafely` 现有公开 intake 走 FIFO → presentation → ErrorCardHost → ErrorCard + 捕获徽标 + error.log 全真实链路，伴随 OSD「已注入测试错误」pill 与 F1 帮助 debug 条目，快速连按绕过 10s 去重窗每次出新卡——补上 UAT 实测缺失的开发用触发入口，零 kernel 改动、零 media_kit 接触。

## Performance

- **Duration:** 920s（Task 1 RED→GREEN + Task 2 反馈/l10n + Task 3 全量质量门）
- **Quality gates:** flutter analyze **0 error**（59 info 均预存风格项）；`flutter test` 全项目 **1319 用例全绿**（无任何失败，headless 基线鉴别不适用）；`bash tool/audit/kernel_logger_gate.sh` **GATE 1+2 PASS**
- **改动面自检:** git diff 三个任务提交共 7 文件（UI 快捷键文件 + l10n ARB/生成物 + 新测试文件），**零 kernel/原生文件、零删除、零 media_kit 接触**；ValueNotifier 惯例未破坏（未引入新状态库）
- **预存脏文件:** .mcp.json / pubspec.yaml / pubspec.lock / .planning/state.json / .planning/agent-history.json 全程未触碰、未暂存

## Accomplishments

1. **Task 1（RED a5974960 → GREEN a267a966）**：新建 `test/widget/player/keyboard_handler_debug_injection_test.dart`（复用 error_card_host_test.dart 的单例重建惯例与 buildMountHarness 语义副本），RED 3 用例失败证明入口缺失；GREEN 在 keyboard_handler.dart 的 Ctrl+Shift+D 调试块后仿其结构新增 kDebugMode 门控 Ctrl+Shift+I 分支 + `static _debugInjectedErrorCount` 计数器 + `_injectTestError()`（StateError 合成载荷 + StackTrace.current → reportPlatformSafely），4/4 转绿。
2. **Task 2（2abb2645）**：`_injectTestError` 尾部追加 `OsdService.I.show('已注入测试错误', icon: Icons.bug_report)` 触发确认（循 error_card.dart:155 / error_card_host.dart:168 先例）；ARB 双语新增 `shortcutDebugInjectError` 并 `flutter gen-l10n` 再生三个 committed 生成物；shortcutDefinitions 尾部追加 `if (kDebugMode) ('Ctrl+Shift+I', ...)` collection-if 条目（shortcuts_help_dialog.dart:27 单一数据源自动渲染，帮助对话框零改动）；测试扩展至 6 用例（OSD text/icon 断言 + 帮助条目断言 + 三个触发注入的用例补 OSD hold-timer 排水防 pending timer）。
3. **Task 3**：全项目质量门收尾（见 Performance），改动面结构自检通过。

## Task Commits

| Task | Commit | Description |
| ---- | ------ | ----------- |
| 1 RED | a5974960 | test(03-05): add failing test for Ctrl+Shift+I debug error injection (G-03-1) |
| 1 GREEN | a267a966 | feat(03-05): implement Ctrl+Shift+I synthetic error injection through real reporter chain (G-03-1) |
| 2 | 2abb2645 | feat(03-05): add OSD injection feedback and F1 help entry with l10n regeneration |
| 3 | （无独立 commit——纯质量门验证，改动已在 Task 1/2 提交内收口） | — |

## Files Created/Modified

**Created:**
- `test/widget/player/keyboard_handler_debug_injection_test.dart` — 6 用例：组合键全链路 / 双按去重绕过（相对计数递增断言）/ source+severity 字段 / OSD pill 反馈 / F1 帮助条目 / 单键 I 无误触发

**Modified:**
- `lib/ui/player/keyboard_handler.dart` — static `_debugInjectedErrorCount`（dev-only 计数器）+ Ctrl+Shift+I kDebugMode 分支 + `_injectTestError()`（真实 intake + OSD 反馈）+ shortcutDefinitions debug collection-if 条目
- `lib/l10n/app_en.arb` / `lib/l10n/app_zh.arb` — `shortcutDebugInjectError` 键（英文带 @description，对齐 shortcutPlayPause 格式）
- `lib/l10n/app_localizations.dart` / `app_localizations_en.dart` / `app_localizations_zh.dart` — `flutter gen-l10n` 再生（未手工编辑生成物）

## Decisions Made

- **Intake 选择**：`reportPlatformSafely`（platformDispatcher 来源 + error 级）——与合成 StateError 载荷天然匹配，D-02 下 error 级直上常驻卡片不走 warning OSD 分流。
- **去重绕过机制**：计数后缀进 message（语义身份 8 字段 record 之一），每按必异——不依赖 eventId（eventId 由 reporter 生成器分配，调用方无法控制）。
- **不加初始化守卫**：生产中 main.dart 组合根先于 runApp 完成 `ErrorReporterImpl.init`，与 error_card_host.dart 直接访问 `.I` 的既有先例一致；守卫反而会在错误配置下静默吞掉注入。
- **测试相对断言**：static 计数器按设计跨测试存活（debug 会话语义），双按用例断言「第二条计数严格大于第一条」而非绝对 #1/#2。
- **OSD 文本不进 l10n**：注入确认 pill 仅 kDebugMode 可达，属 dev-only 字面量（speed_button '1x' 同类）；F1 帮助条目进 l10n（用户可见帮助文案，中英双语）。

## Deviations from Plan

**1. [Rule 1 - Test correctness] RED 阶段双按用例绝对计数断言在套件运行下脆弱**
- **Found during:** Task 1 GREEN（实现正确后全文件运行仍有 1 失败）
- **Issue:** 测试断言 `contains('#1')`/`contains('#2')` 绝对序号，但 `static _debugInjectedErrorCount` 按设计跨测试存活（组合键用例先消耗 #1），套件内第二用例实际产出 #2/#3；单测隔离运行则通过。实现行为正确，是测试断言超出计划行为规格（计划原文只要求「两条 message 互不相同（计数递增）」）。
- **Fix:** 改为相对断言——提取 message 尾部 `#N` 计数，断言第二条严格递增 + message 互异 + occurrenceCount 均 1。
- **Files modified:** test/widget/player/keyboard_handler_debug_injection_test.dart
- **Verification:** 全文件 6/6 全绿（原 4 用例 + Task 2 扩展 2 用例）
- **Commit:** a267a966

**Total deviations:** 1（无 Rule 4 架构决策；无认证门）

**Impact:** 零——测试断言精度修正，生产行为与计划规格完全一致。

## Issues Encountered

- **编辑近失误（未落盘）**：Task 2 编辑 shortcutDefinitions 时误将既有 `l10n.shortcutMediaKeys` 改名为不存在的 `shortcutMetadata`，下一个 Edit 立即发现并还原（mediaKeys 键原样保留 + 正确追加新条目）；该错误从未进入任何 commit 或验证运行。
- **flutter gen-l10n 提示**：运行输出 "To use the command line arguments, delete the l10n.yaml file"——仅为 l10n.yaml 存在时的信息性提示，再生正常（生成物 grep 验证 shortcutDebugInjectError 三文件齐全）。
- **headless 基线**：本次全项目 `flutter test` 1319 用例零失败，memory 记载的 mdk.dll FFI 预存失败基线在本环境未复现，无需基线鉴别。

## Known Stubs

None — 注入链路全真实（reporter intake → FIFO → presentation → Host → Card + effects 快照 + error.log），无占位数据、无未接线组件。

## Next Phase Readiness

- **G-03-1 实机收口**：widget 测试无法证明实机键盘焦点与窗口交互——最终证据由 `/gsd-verify-work` 对 UAT Test 1（VER-04 实机冒烟）复测收口：debug 会话 `flutter run -d windows` 按 Ctrl+Shift+I 观察卡片弹出、OSD pill、error.log 与捕获徽标同步。
- **Phase 3 全部 4 计划 + 1 gap-closure 计划完成**：错误链路（Phase 1 捕获 → Phase 2 定位与文件证据 → Phase 3 卡片呈现）+ 开发用触发入口齐备，具备进入 Phase 4（日志可配置路径）条件。
- **零遗留风险项**：本计划无 stub、无未运行 verify、无 deferred 代码项（实机复测属验证流程而非代码缺口）。

## Self-Check: PASSED

- 7/7 计划触及文件存在（FOUND）
- 3/3 任务 commit 存在于 git log（a5974960 / a267a966 / 2abb2645）
- 质量门实测：analyze 0 error；flutter test 1319 全绿；kernel_logger_gate GATE 1+2 PASS

---

*Phase: 3-播放错误桥与非模态卡片 | Gap closure: G-03-1 | Completed: 2026-08-31*
