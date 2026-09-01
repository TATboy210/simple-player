---
phase: 03-playback-error-card-bridge
plan: 06
subsystem: ui-player-error-card
tags: [error-card, keyboard-dispatch, gap-closure, uat-fix, flutter-widget]
gap_ids: [G-03-2, G-03-3, G-03-4]
gap_closure: true
requires:
  - 03-05-PLAN (G-03-1 注入入口四件套 — 本 plan 移除对象)
  - WindowBridge.mode ValueListenable (kernel/window_bridge, 只读消费)
provides:
  - HardwareKeyboard 全局回退快捷键分发（dead-keyboard 修复，双守卫不吞键）
  - 错误卡片窗口化/全屏双定位（窗口化 = 视频区上缘 44.0，全屏 = D-10 12.0）
  - 无调试注入入口的源码面（kDebug 构建同样不含）
affects:
  - UAT Test 2/3/4 可复测（/gsd-verify-work）
  - 后续全屏焦点回落域（player_video_controls.dart:466-468 已知问题域）的行为面
actuals:
  tokens: 14146 # realized diff 56582 chars / 4；estimate 70000（规划保守高估）
  tasks: 3
  commits: 7 # 6 task commits (3×RED + 3×GREEN) + 1 metadata commit
tech-stack:
  added: [] # 零新依赖、零 pubspec 变更
  patterns:
    - HardwareKeyboard.instance.addHandler 回退式全局分发（先于焦点分发运行，注册/注销配对）
    - 双路径共享分发函数（焦点路径与回退路径共用同一匹配实现，语义零漂移）
    - KernelLogger isInitialized 探针守卫埋点（WR-02 先例）
    - Tokens 单源常量定位（titleBarHeight 同源编译期常量替代 GlobalKey 布局回调）
key-files:
  created:
    - test/widget/player/keyboard_handler_global_dispatch_test.dart (7 用例：死键盘×2 + 守卫矩阵×4 + 生命周期×1)
    - test/widget/player/error_card_mount_position_test.dart (3 用例：窗口化/全屏/tear-off 缺省)
  modified:
    - lib/ui/player/keyboard_handler.dart (StatefulWidget 化 + 回退分发 + 共享分发函数 + 守卫 + 埋点)
    - lib/app.dart (buildErrorCardMount 可选 mode 参数 + VLB 双定位 + App 传入 windowService.mode)
    - lib/l10n/app_en.arb / app_zh.arb (移除 shortcutDebugInjectError)
    - lib/l10n/app_localizations.dart / app_localizations_en.dart / app_localizations_zh.dart (flutter gen-l10n 再生)
    - test/widget/player/keyboard_handler_test.dart (新增「注入入口已移除」absence group 2 用例)
  deletions:
    - test/widget/player/keyboard_handler_debug_injection_test.dart (6 用例全部针对被移除入口)
key-decisions:
  - 回退式（非无差别全局替换）分发：焦点分发保持主路径，仅当按键无法沿焦点链送达 handler 子树时由全局回退接管——dead-keyboard 修复与「不吞键」约束同时成立（规划期锁定，实现期经守卫矩阵 7 用例证明）
  - 守卫判定以「主焦点的 ModalRoute 祖先 + 与 handler 自路由同一性 + scope/常规节点区分」实现：其他路由（对话框/全屏 route）自洽消费各自按键（含其 route scope——防止对话框内 F1 堆叠），自路由 scope 滞留/无路由祖先/primaryFocus null 才接管
  - EditableText 守卫补祖先查找分支：探针证明 `context.widget is EditableText` 对 TextField 永不匹配（焦点节点由内部 Focus 件附着，context.widget 是 Focus 包装件）
  - 卡片窗口化定位用 Tokens.titleBarHeight 同源编译期常量偏移，弃用 GlobalKey/布局回调（零新耦合、精度足够——标题栏高度恒定）
  - F1 帮助对话框打开后按键所有权移交对话框路由（守卫矩阵的对偶面）：死键盘复现用例将 Space/ESC 断言置于 F1 之前
requirements-completed:
  - CARD-02 # 挂载 Positioned 结构与 hit-test 穿透语义保持（仅 top 值随 mode 变化），verbatim from PLAN frontmatter requirements: [CARD-02]
coverage:
  - deliverable: G-03-4 注入入口移除
    verification: "keyboard_handler_test 24/24 全绿（含 2 个新 absence 用例）；负向 grep 门 GATE-PASS（shortcutDebugInjectError / _injectTestError / _debugInjectedErrorCount 在 lib/ 与测试零残留；注入测试文件已删）；flutter gen-l10n 再生三生成物同步"
    human_judgment: false
  - deliverable: G-03-3 全局回退分发
    verification: "keyboard_handler_global_dispatch_test 7/7（外层 Focus 滞留 / unfocus(scope) 自路由 scope 滞留两死态 F1/Space/ESC 可达；Slider 方向键、面板 ESC、对话框按键不吞、F1 不堆叠、根 Overlay TextField 文本守卫、卸载后零陈旧回调）；keyboard_handler_test 24/24 既有语义零改动回归"
    human_judgment: false
  - deliverable: G-03-2 卡片双定位
    verification: "error_card_mount_position_test 3/3（窗口化 dy==44.0 / 全屏 dy==12.0 / tear-off 缺省 dy==44.0，dx==18.0）；error_card_host_test 14/14 + error_card_test 17/17 + error_banner_equivalence_test 6/6 既有挂载/等效断言零改动"
    human_judgment: false
  - deliverable: 全项目回归
    verification: "flutter analyze 0 error 0 warning（61 info 全预存）；flutter test 全项目 1325 passed / 0 failed（基线 1319 − 6 删除 + 2 absence + 7 dispatch + 3 mount = 1325，精确对账）；基线运行先于任何改动执行（1319 全绿），无预存失败需排除"
    human_judgment: false
  - deliverable: 实机复验（UAT re-test）
    verification: "窗口化下报错卡片不压标题栏；全屏进出循环后 F1 弹帮助；Ctrl+Shift+I 无响应——自动化无法证明窗口/焦点实机行为"
    human_judgment: true
    rationale: "UAT Test 2/3/4 的原始 issue 均来自实机（flutter run -d windows）；死键盘根因域（焦点回落边界）与窗口 hit-test 无法在 headless 测试完全复现，须 /gsd-verify-work 实机复测"
duration: 64 min
completed: 2026-08-31
status: complete
---

# Phase 3 Plan 06: UAT 三 Gap 收口（卡片定位 / 全局回退分发 / 注入入口移除）Summary

**一句话：** 三 gap 同 plan 顺序收口——错误卡片窗口化下移 32px 到视频区上缘（单源常量定位）、快捷键获得 HardwareKeyboard 回退分发治 dead-keyboard（守卫矩阵证明不吞键）、调试注入入口四件套+l10n key 用后即撤；全项目 1325 测试全绿、analyze 0 error。

## Performance

- 计划 estimate 70000 tokens → 实际 diff 56582 chars ≈ 14146 tokens（规划保守高估，删除型改动 + 测试 harness 复用既有模式压低了实际量）
- 3 tasks 全部按 TDD RED→GREEN 两段提交（6 task commits + 1 metadata）
- 基线全量测试先于任何改动运行（1319 全绿），终验 1325 全绿——每一步红绿转变得以精确对账，无预存失败干扰归因

## Accomplishments

- **G-03-4（Task 1）**：移除 Ctrl+Shift+I 注入分支、静态注入计数器、`_injectTestError` 方法、shortcutDefinitions collection-if 帮助条目、`shortcutDebugInjectError` l10n key（双 ARB + 三生成物再生）、注入测试文件（6 用例）。Ctrl+Shift+D 调试导出（FEAT 既有能力）不受影响。负向 grep 门证明 lib/ 零残留。
- **G-03-3（Task 2）**：KeyboardHandler 改 StatefulWidget，initState/dispose 配对注册/注销 HardwareKeyboard 全局回退 handler；按键匹配主体提取为单一共享分发函数（焦点路径 + 回退路径共用，语义永不漂移）；回退仅在焦点链无法送达时接管（primaryFocus null / 滞留自路由 scope / 无路由祖先），其他路由（对话框/全屏 controls）与文本输入链一律放行；KernelLogger 接管/放行埋点以 isInitialized 探针守卫（未初始化环境零 StateError）。
- **G-03-2（Task 3）**：`buildErrorCardMount` 增可选 `mode`（ValueListenable\<WindowMode\>），VLB 订阅窗口模式——窗口化/最大化时卡片顶缘 = `Tokens.titleBarHeight + Tokens.spMd`（44.0，标题栏 32.0 之下=视频区上缘），全屏保持 D-10（12.0）；tear-off 缺省路径确定为窗口化偏移；App 既有 windowService.mode 直传，零新增 plumbing。

## Task Commits

| Task | Type | Commit | 内容 |
| ---- | ---- | ------ | ---- |
| 1 | RED | 5ce17d41 | absence 测试：快捷键定义无注入条目 + 组合键回调全 0 |
| 1 | GREEN | df0c770e | 注入四件套 + l10n key + 注入测试文件全量移除 |
| 2 | RED | 0f4b48b2 | 死键盘复现×2（+5 −2：守卫用例先行全绿锁定契约） |
| 2 | GREEN | c5c23305 | 双路径回退分发 + 守卫 + 埋点，1325 全绿 |
| 3 | RED | 30eb3131 | 挂载位置回归 harness（mode 参数缺失 = 编译期 RED） |
| 3 | GREEN | 4a4444b6 | buildErrorCardMount 双定位 + App 接线 |
| — | docs | （本次提交） | SUMMARY + STATE + ROADMAP |

## Files Created / Modified / Deleted

- **Created:** `test/widget/player/keyboard_handler_global_dispatch_test.dart`、`test/widget/player/error_card_mount_position_test.dart`
- **Modified:** `lib/ui/player/keyboard_handler.dart`、`lib/app.dart`、`lib/l10n/app_en.arb`、`lib/l10n/app_zh.arb`、`lib/l10n/app_localizations.dart`、`lib/l10n/app_localizations_en.dart`、`lib/l10n/app_localizations_zh.dart`、`test/widget/player/keyboard_handler_test.dart`
- **Deleted:** `test/widget/player/keyboard_handler_debug_injection_test.dart`

## Decisions Made

- **回退式分发锁定**：规划期已核对 Slider（FocusableActionDetector 快捷键调节）、播放列表面板（Focus+ESC）、对话框内部组件后排除无差别全局替换；实现期守卫矩阵 7 用例实证该取舍。
- **守卫的 route 同一性设计**：探针发现 `unfocus(scope)` 后 primaryFocus 滞留在路由 FocusScopeNode（有 ModalRoute 祖先但分发必死）——守卫将 scope 节点与其所属路由绑定判定：自路由 scope = 接管（死键盘救援），他路由 scope = 放行（对话框内 F1 不堆叠）。这比计划原文的「ModalRoute 存在且 ≠ 自路由」表述多覆盖了自路由 scope 滞留态（正是全屏循环后焦点回落的真实形态）。
- **单源常量定位**：`_errorCardWindowedTop = Tokens.titleBarHeight + Tokens.spMd` 顶层 const，注释记录弃用 GlobalKey 方案的依据（custom_title_bar.dart:98 同源 SizedBox 常量，标题栏高度恒定）。
- **死态测试的断言序**：F1 弹出对话框后按键所有权合法移交对话框路由（回退守卫的对偶面），故外层 Focus 滞留用例先断言 Space/ESC 再断言 F1。

## Deviations from Plan

**[Rule 1 - Bug] EditableText 守卫对 TextField 永不匹配（探针证实）**
- **Found during:** Task 2 实现期（探针测试）
- **Issue:** 现行守卫 `primaryFocus.context.widget is EditableText` 在 TextField 上恒 false——TextField 焦点节点由内部 `Focus` 件附着，`FocusNode.context.widget` 是 Focus 包装件而非 EditableText；守卫矩阵的根 Overlay TextField 用例要求该守卫真实生效。
- **Fix:** 守卫补 `findAncestorWidgetOfExactType<EditableText>()` 祖先查找分支，焦点路径与回退路径共用（对焦点路径是行为修正：子树内文本框不再可能被 Space 劫持——生产中 handler 子树内无文本框，无回归面）。
- **Files modified:** lib/ui/player/keyboard_handler.dart
- **Verification:** 守卫矩阵 TextField 用例绿（前置断言证明祖先查找命中）
- **Commit:** c5c23305

**[Rule 1 - Test design] 「controller.text 含空格」断言 headless 不可复现**
- **Found during:** Task 2 RED 期（探针测试）
- **Issue:** widget 测试不经 IME，物理 Space 键不会真实写入 TextField 文本（探针证实 text 保持 ""）——计划 Test 6 的文本写入断言在 flutter_test 下无法成立。
- **Fix:** 改断言「回退不消费」（`sendKeyDownEvent` 返回 false）+ playPause 计数 0 + 前置断言证明主焦点在 EditableText 焦点链内——不吞键语义完整保留，仅不可观测的文本写入部分以非消费断言替代。
- **Files modified:** test/widget/player/keyboard_handler_global_dispatch_test.dart
- **Verification:** 用例绿且 RED 期即通过（守卫先行锁定）
- **Commit:** 0f4b48b2 (RED) / c5c23305 (GREEN)

**[Rule 3 - Blocker] UnfocusDisposition 无 root 成员；「primaryFocus 为 null」为瞬态**
- **Found during:** Task 2 RED 期（探针编译失败）
- **Issue:** 计划 Test 2 写明「unfocus 到 root disposition」——Flutter 3.47 的 UnfocusDisposition 只有 scope / previouslyFocusedChild；且 FocusManager 会把 null primaryFocus 自动回落到 rootScope，「primaryFocus 为 null」在生产不可稳定构造。
- **Fix:** 死态用例改为 `unfocus(scope)` 后滞留在自路由 FocusScopeNode（探针证实为真实可构造的死键盘形态，与 UAT 全屏循环后的焦点回落边界同族）；守卫覆盖该态（自路由 scope → 接管），同时覆盖 rootScope（无路由祖先）与瞬时 null。
- **Files modified:** test/widget/player/keyboard_handler_global_dispatch_test.dart、lib/ui/player/keyboard_handler.dart
- **Verification:** 死态用例 RED→GREEN 转变
- **Commit:** 0f4b48b2 / c5c23305

**[测试结构] 死键盘用例断言顺序调整**
- **Found during:** Task 2 GREEN 期
- **Issue:** 计划配方 F1→Space→ESC 同序断言：F1 弹出对话框后主焦点移交对话框路由（守卫矩阵要求的行为），同批后续 Space/ESC 断言落在对话框态而非死键盘态。
- **Fix:** Space/ESC 先按、F1 收尾——三个键全部在死键盘态断言，弹窗可见性收尾。
- **Files modified:** test/widget/player/keyboard_handler_global_dispatch_test.dart
- **Verification:** 7/7 全绿
- **Commit:** c5c23305

**Total deviations: 4**（全部 Rule 1/3 级自动修复，无 Rule 4 架构决策、无 checkpoint）
**Impact:** 修复方向与计划完全一致；守卫实现比计划原文更精确地覆盖了自路由 scope 滞留态（即 UAT 根因域）；无范围蔓延，零 kernel/零 media_kit/零 windows/ 接触保持。

## Issues Encountered

- 长期记忆中的 headless 预存失败基线（mdk.dll FFI ~57 失败等）已失效：本次基线全量 1319 全绿、终验 1325 全绿，无需排除名单——计划的「flutter test 全绿」字面达成。
- `.planning/current-agent-id.txt` 运行时产物出现在 untracked 列表——非本 plan 范围，保持 untracked 未提交。

## Next Phase Readiness

- Phase 3 UAT Test 2/3/4 三个 gap 的代码面修复全部落地，可由 `/gsd-verify-work` 实机复测（coverage 表 human_judgment 行）。
- 实机复验清单：① 窗口化触发错误 → 卡片不压标题栏（顶缘=视频区上缘）；② 全屏进出循环后按 F1 → 帮助弹出（error.log 应出现「键盘全局回退接管」debug 记录）；③ Ctrl+Shift+I → 无响应；④ 全屏内卡片仍在窗口左上角（D-10）。
- Phase 4（日志位置/设置）不受影响；`_errorCardWindowedTop` 为 UI 层私有常量，无跨 phase 契约。

---

*Gap closure plan 03-06 complete — G-03-2 / G-03-3 / G-03-4 closed 2026-08-31*

## Self-Check: PASSED

- Created files verified on disk: keyboard_handler_global_dispatch_test.dart、error_card_mount_position_test.dart（连同 modified 的 keyboard_handler.dart / app.dart）
- 全部 7 个 commit 哈希在 git log 中确认：5ce17d41 / df0c770e / 0f4b48b2 / c5c23305 / 30eb3131 / 4a4444b6 / 880aafe7
- 删除项确认：keyboard_handler_debug_injection_test.dart 已不在磁盘（git 历史 df0c770e 保留恢复点）
- 禁改文件确认未触碰未暂存：.mcp.json、pubspec.yaml、pubspec.lock、.planning/state.json、.planning/agent-history.json
- 终验复核：flutter analyze 0 error / 0 warning；flutter test 1325 passed / 0 failed
