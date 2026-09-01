---
phase: 03-playback-error-card-bridge
plan: 02
subsystem: ui/player/diagnostics-presentation
tags: [error-card, expand-collapse, hit-test, focus-isolation, severity-colors, l10n-migration, tdd]
requires:
  - "ErrorCardHost + ErrorCard 折叠视图（03-01，本计划向展开区扩展）"
  - "ErrorReport 不可变契约（location/sourceLines/rawStackTrace/mediaPath，Phase 2）"
  - "ErrorReporterImpl.diagnosticLogPath（ValueListenable<String?>，Phase 2 FileSink）"
  - "Wave 0 l10n errorCard* 13 key（03-01 预置，本计划零新增 key）"
provides:
  - "ErrorCard 完整折叠/展开双态（CARD-03 五段详情 + D-04 整卡点击/chevron）"
  - "_resolveMessage l10nKey 解析（error_banner 13 key 逐项一致的 MIG-01 迁移基线）"
  - "Tokens.warning/dangerFatal 严重级语义色（D-03）+ errorCardExpandedMaxWidth"
  - "CARD-01 手动关闭（onClose → dismissCurrent 唯一接线）+ CARD-02 双向 hit-test 套件"
affects:
  - "03-03：徽标轮览接线（onTap: () {} 占位点已标）/复制包/warning→OsdService 路由"
  - "03-04：MIG-01 删除 ErrorBanner（消息解析能力已就位，等效覆盖按 D-09 口径）"
tech-stack:
  added: []
  patterns:
    - "l10nKey 键重建：playerErrorCode（file:xxx）→ 'error.file.xxx' 后走与旧横幅逐项一致的 switch —— ErrorReport 快照上复刻 sealed 类解析能力"
    - "展开区 Flexible + SingleChildScrollView 防溢出：bounded 环境内 min-size Column 的长文本段必须可滚动"
    - "纯呈现测试直接构造不可变 ErrorReport 快照（intake 产不出的 severity/key 边界用例）"
key-files:
  created:
    - test/widget/player/error_card_test.dart
  modified:
    - lib/ui/player/error_card.dart
    - lib/ui/player/error_card_host.dart
    - lib/ui/theme/tokens.dart
key-decisions:
  - "l10nKey 解析走键重建而非携带 PlayerError：report.playerErrorCode ('file:fileNotFound') → 'error.file.fileNotFound'，13 key switch 与 error_banner.dart 逐项一致（diff 验证），unknown fallback raw message；D-09 动作按钮块确认未迁移"
  - "展开区用 Flexible+SingleChildScrollView 而非固定 maxHeight：卡片挂载于 Positioned(left,top)，可滚动天然尊重窗口剩余高度，测试环境（Scaffold body bounded）与生产一致"
  - "mediaPath 展示在 intake 脱敏（redactPathValue→basename）之上再做防御性 basename 截取（兼容 URL 原样值），fullMediaPath/failedOpenPath 任何段都不渲染（T-03-05/D-07）"
  - "关闭按钮用 GestureDetector+Semantics 而非 GlassButton/InkWell 焦点体系；ExcludeFocus 由 03-01 已建，本计划补行为断言（primaryFocus 不变 + descendantsAreFocusable:false）"
  - "诊断日志路径读取内聚在卡片（ErrorReporterImpl.I.diagnosticLogPath?.value，isInitialized 守卫），与 OsdService.I 同为 UI 层单例消费先例"
requirements-completed:
  - CARD-01
  - CARD-02
  - CARD-03
coverage:
  - kind: test
    ref: "test/widget/player/error_card_test.dart 'collapsed shows localized message, severity dot and basename'"
    status: pass
    human_judgment: false
    note: "CARD-03 折叠三要素：真实 intake 的 FileError → l10nKey 解析为「文件不存在」+ danger 色点 + 媒体 basename；raw message 与完整路径不出现"
  - kind: test
    ref: "test/widget/player/error_card_test.dart 'whole-card tap expands five sections in D-04 order'"
    status: pass
    human_judgment: false
    note: "整卡点击展开五段（定位/源码行/调用栈/日志路径/重复）+ getTopLeft 递增锁死 D-04 段序 + chevron 翻转 + 再点收起；rawStackTrace 逐字符 SelectableText 断言"
  - kind: test
    ref: "test/widget/player/error_card_test.dart 'null location degrades to location-unavailable text'"
    status: pass
    human_judgment: false
    note: "D-05 fallback：location null → 「定位不可用」，其余段不缺不抛错，源码行段随之省略"
  - kind: test
    ref: "test/widget/player/error_card_test.dart 'full media path never rendered in visible tree (T-03-05)'"
    status: pass
    human_judgment: false
    note: "T-03-05/D-07：携带 fullMediaPath 的报告在折叠+展开两态可见树均 findsNothing，basename 照常"
  - kind: test
    ref: "test/widget/player/error_card_test.dart 'unknown l10nKey falls back to raw message'"
    status: pass
    human_judgment: false
    note: "未知 key fallback raw message（MIG-01 解析基线完备性）"
  - kind: test
    ref: "test/widget/player/error_card_test.dart 'warning and fatal severities map to dedicated tokens (D-03)'"
    status: pass
    human_judgment: false
    note: "D-03 三值 token 映射：fatal→dangerFatal（真实 intake pathTraversal）、warning→warning（直构快照）、error→danger"
  - kind: test
    ref: "test/widget/player/error_card_test.dart 'log path renders from diagnosticLogPath when available'"
    status: pass
    human_judgment: false
    note: "diagnosticLogPath 有值显示路径 / 无值（默认 init）降级「日志文件不可用」双路径"
  - kind: test
    ref: "test/widget/player/error_card_test.dart 'taps inside the card do not reach widgets below; taps outside pass through'"
    status: pass
    human_judgment: false
    note: "CARD-02 双向边界：卡内点击探针不触发且卡片展开（吸收）；卡外点击探针触发且卡片态不变（穿透）"
  - kind: test
    ref: "test/widget/player/error_card_test.dart 'tap on route content above the navigator still hits while card visible (D-10)'"
    status: pass
    human_judgment: false
    note: "D-10：不透明 route push 后 route 探针可命中，卡片仍可见（挂载层不吞 Navigator 命中）"
  - kind: test
    ref: "test/widget/player/error_card_test.dart 'card persists across frames with no auto-hide timer'"
    status: pass
    human_judgment: false
    note: "CARD-01 常驻：推进 10s 多帧卡片不消失（源码 grep 无 Timer/showDialog/autofocus 复核）"
  - kind: test
    ref: "test/widget/player/error_card_test.dart 'close button dismisses current and advances the FIFO'"
    status: pass
    human_judgment: false
    note: "CAP-04：关闭推进到队首下一项（乙 + 「1 错误」），再关归零卡片消失"
  - kind: test
    ref: "test/widget/player/error_card_test.dart 'primary focus unchanged after taps on collapsed, expanded and close button'"
    status: pass
    human_judgment: false
    note: "T-03-07：autofocus 基准节点在折叠/展开/SelectableText/关闭四类点击后 primaryFocus same()"
  - kind: test
    ref: "test/widget/player/error_card_test.dart 'card subtree has no focusable nodes and no GlassButton/FocusableActionDetector'"
    status: pass
    human_judgment: false
    note: "结构断言：卡子树无 GlassButton/FocusableActionDetector；宿主 Focus canRequestFocus:false + descendantsAreFocusable:false"
  - kind: verify-command
    ref: "flutter test test/widget/player/error_card_test.dart --plain-name expand"
    status: pass
    human_judgment: false
    note: "Task 1 focused 命令退出 0（7 用例）"
  - kind: verify-command
    ref: "flutter test test/widget/player/error_card_test.dart --plain-name hit-test"
    status: pass
    human_judgment: false
    note: "Task 2 focused 命令退出 0（2 用例）"
  - kind: verify-command
    ref: "flutter test test/widget/player/error_card_test.dart test/widget/player/error_card_host_test.dart"
    status: pass
    human_judgment: false
    note: "计划 verification：19 用例全绿（13 新 + 6 宿主回归）"
  - kind: verify-command
    ref: "flutter analyze"
    status: pass
    human_judgment: false
    note: "0 error / 0 warning；59 个 info 全部预存（与 03-01 基线同数）"
  - kind: verify-command
    ref: "flutter test（全量 1312 用例）"
    status: pass
    human_judgment: false
    note: "全绿 exit 0 —— headless mdk.dll 预存基线本次未触发，本计划零回归"
  - kind: manual-smoke
    ref: "VER-04 Manual-Only：Windows 实机 hit-test 与全屏冒烟（卡片显示期控制栏/标题栏/全屏 route 实机命中）"
    status: pending
    human_judgment: true
    note: "widget test 无法复现宿主窗口与 media_kit 全屏 route 的真实命中；按 03-VALIDATION 归 Phase 3 收尾统一执行（doc comment 已注明）"
duration: 25
completed: 2026-08-31
status: complete
actuals:
  tokens: 9400
  tasks: 2
  commits: 4
---

# Phase 3 Plan 02: 卡片展开详情与严格命中边界（CARD-01/02/03）Summary

**One-liner:** ErrorCard 从「能看到」升级为「能定位」且「不妨碍操作」——整卡点击展开定位/源码行/调用栈/日志路径/重复五段（D-04 段序）、严重级三值语义色 token、l10nKey 13 key 解析迁移基线，以及常驻手动关、零焦点抢占与卡内外双向 hit-test 边界（含 D-10 route 命中）。

## Performance

- **Estimate:** 55000 tokens / 2 tasks（confidence: low）
- **Actual:** ~9400 tokens（chars/4，4 个 commit 合计 872 insertions / 62 deletions）/ 2 tasks / 4 commits / 25 min
- 估算偏差主因：03-01 的宿主/挂载/ExcludeFocus 骨架可直接扩展，本计划实际只改卡片呈现与一处接线；TDD 双 RED/GREEN 节奏无返工。

## Accomplishments

- **CARD-03 展开详情五段齐备**：整卡点击切换折叠/展开（StatefulWidget 内部状态 + chevron 指示），展开区按 D-04 Phase 2 段序渲染定位（file:line member）→ 源码行（lineNumber: text 逐行）→ 调用栈（rawStackTrace 逐字符 SelectableText）→ 日志路径（diagnosticLogPath 值 / 降级文案）→ 重复信息（次数 + 首末时间 ISO8601）。段序由 getTopLeft 递增断言锁死。
- **D-03 语义色分层零新视觉体系**：新增 `Tokens.warning`（amber）与 `Tokens.dangerFatal`（danger 加深），双语注释；`_severityColor` switch 表达式映射三值，severity 色点 + GlassContainer border 同色分层。
- **MIG-01 迁移基线落位**：`_resolveMessage` 在 `playerErrorCode` 快照上重建 l10nKey 后，13 key switch 与 error_banner.dart **逐项一致**（grep diff 验证）+ unknown fallback raw message；D-09 动作按钮块确认未迁移。03-04 删除 ErrorBanner 后无解析能力缺口。
- **T-03-05/D-07 脱敏边界测试锁死**：携带 fullMediaPath 的报告在折叠+展开两态可见树均 findsNothing；mediaPath 在 intake 脱敏之上再做防御性 basename 截取（兼容 URL 原样值）。
- **CARD-01 常驻手动关**：关闭按钮（GestureDetector + errorCardClose 语义）→ 宿主 `onClose → ErrorReporterImpl.I.dismissCurrent()` 唯一接线；多报告关闭推进队首下一项（CAP-04）、单报告归零；无自动隐藏 Timer（源码 grep + 多帧推进测试双证）。
- **零焦点抢占**：宿主 ExcludeFocus（03-01 已建）+ 卡内零 GlassButton/FocusableActionDetector；autofocus 基准节点在折叠/展开/SelectableText/关闭四类点击后 `primaryFocus same()`。
- **CARD-02/D-10 命中边界**：卡内点击下层探针不触发且卡片吸收（展开），卡外点击穿透；不透明 route 之上 route 内容可命中且卡片可见。

## Task Commits

| Task | Commit | Type | Content |
|------|--------|------|---------|
| 1 (RED) | dbefc1e | test(03-02) | expand 组 7 用例（折叠三要素/五段段序/null 降级/路径脱敏/unknown fallback/严重级映射/日志路径） |
| 1 (GREEN) | 5204d6cd | feat(03-02) | ErrorCard 展开双态 + severity token + l10nKey 解析 + Flexible 滚动防溢出 |
| 2 (RED) | f0b0d80b | test(03-02) | hit-test/close/focus 三组 6 用例（RED 断点：error-card-close 缺失） |
| 2 (GREEN) | 351cf97e | feat(03-02) | 关闭按钮 + onClose → dismissCurrent 宿主接线 |

## Files Created/Modified

**Created:** `test/widget/player/error_card_test.dart`（13 用例：expand 7 + hit-test 2 + close 2 + focus 2）

**Modified:** `lib/ui/player/error_card.dart`（折叠/展开双态 + 关闭按钮 + l10nKey 解析，~290 行）、`lib/ui/player/error_card_host.dart`（onClose 接线 + CAP-04 注释）、`lib/ui/theme/tokens.dart`（warning/dangerFatal/errorCardExpandedMaxWidth）

## Decisions Made

见 frontmatter `key-decisions`。核心一条：**l10nKey 解析走键重建**——ErrorReport 只携带 intake 快照的 `playerErrorCode`（不携带 PlayerError 对象），将其还原为 `error.{type}.{code}` 后走与旧横幅逐项一致的 13 key switch；这既满足「完整复制 switch」的 MIG-01 前置，又不让呈现层反向依赖 sealed 错误对象。

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] 展开态卡片在 bounded 高度环境 RenderFlex 溢出**
- **Found during:** Task 1 GREEN
- **Issue:** 展开五段总高超测试视口 48–166px，min-size Column 直接溢出抛 RenderFlex 异常
- **Fix:** 展开段包 `Flexible + SingleChildScrollView`——bounded 环境下尊重剩余高度滚动而非溢出；生产 Positioned(left,top) 挂载同受窗口约束，行为一致
- **Files modified:** lib/ui/player/error_card.dart
- **Verification:** 全部展开用例转绿，无 overflow 异常
- **Commit:** 5204d6cd

**2. [Rule 3 - Blocker] 测试断言 textContaining 多匹配**
- **Found during:** Task 1 GREEN
- **Issue:** `find.textContaining('lib/main.dart:42')` 同时命中定位行与栈文本（栈帧含同路径），findsOneWidget 失败
- **Fix:** 改为定位行逐字符 exact match（与实现渲染格式一致），断言更强
- **Files modified:** test/widget/player/error_card_test.dart
- **Commit:** 5204d6cd（随 GREEN 同文件收敛）

### Plan-execution Deviations（非缺陷，口径澄清）

**3. 两个边界用例直构 ErrorReport 快照而非经 forTesting intake**
- **Found during:** Task 1
- **Issue:** 计划要求数据用 `ErrorReporterImpl.forTesting` 产出；但 warning severity（D-02：当前无捕获源产出 warning）与未知 l10nKey（任何 PlayerError 代码都命中已知表）两条 intake 路径均不可达
- **Fix:** 主路径场景（l10n 解析/媒体路径/展开/null location/fatal）保持 forTesting 真实 intake；两个不可达边界直接构造不可变 ErrorReport（纯数据快照，仍零 MediaKitEngine 构造）
- **Verification:** 对应用例全绿；理由写入测试注释
- **Commit:** dbefc1e

**4. Tokens.errorCardExpandedMaxWidth 新增**
- **Found during:** Task 1
- **Issue:** 展开区需要与折叠不同的宽度上限（420px），项目红线禁止裸数字
- **Fix:** tokens.dart 错误卡片段新增（tokens.dart 本就是计划 files_modified 之一，属计划内扩展）
- **Commit:** 5204d6cd

**Total deviations:** 2 auto-fixed（Rule 1 + Rule 3）+ 2 口径澄清。**Impact:** 无架构影响；溢出修复是真实的展开态正确性 bug；宽度 token 与红线方向一致。

## Issues Encountered

**Headless 基线归因**：全量 `flutter test` 1312 用例**全绿**（exit 0）——memory 记载的 mdk.dll FFI/窗口类预存失败本环境本次未触发，无需 stash 鉴别；本计划零回归。测试全程未构造 MediaKitEngine/media_kit Player（卡片测试用 forTesting reporter + 直构快照 + FakeWindowService）。

**Windows 实机项显式登记（Manual-Only / VER-04）**：实机 hit-test 与全屏期间卡片命中属 widget test 不可复现的宿主窗口行为，Phase 3 收尾统一执行——已写入 error_card doc comment 与本 SUMMARY coverage。

## Known Stubs

| File | Line | Stub | Reason / Resolution |
|------|------|------|---------------------|
| lib/ui/player/error_card.dart | 徽标 GestureDetector onTap: () {} | 空点击回调 | D-01 徽标轮览接线按计划归 03-03（03-01 已登记，非本计划新增缺口） |

## Threat Flags

无新增计划外信任边界。计划 `<threat_model>` 落实情况：T-03-05（可见树不渲染完整媒体路径，两态测试锁死）、T-03-06（Positioned(left,top) 内在尺寸 + 双向 hit-test 测试）、T-03-07（ExcludeFocus 结构断言 + primaryFocus 不变行为断言）均有测试可指认；T-03-SC（零新增包）维持。

## Next Phase Readiness

- 03-03 接线点已标位：徽标 `GestureDetector onTap: () {}`（轮览）、宿主 `_apply` severity 分流（warning→OsdService）、`errorCardCycleTooltip`/复制相关 l10n key 已备。
- 03-04 MIG-01：`_resolveMessage` 13 key 解析已就位（逐项一致 diff 验证）；等效覆盖按 D-09「消息+严重级可见性」断言，不含按钮行为。
- Windows 实机 smoke 清单（VER-04 Manual-Only）保持 pending，Phase 3 收尾统一执行。
- REQUIREMENTS 同步：shared-ID gate（requirements.ready-ids）本轮标记 CARD-01/CARD-02 完成；CARD-03 被 gate 判定 blocked（未暴露原因，其实现与测试证据已在本 SUMMARY coverage 全量登记），留待 03-03/03-04 完成轮或 phase 审计补标记。

## Self-Check: PASSED

- [x] 创建文件存在：test/widget/player/error_card_test.dart（git ls-files 可查）
- [x] Commits 存在：dbefc1e / 5204d6cd / f0b0d80b / 351cf97e（git log 验证）
- [x] `flutter test test/widget/player/error_card_test.dart --plain-name expand` 退出 0
- [x] `flutter test test/widget/player/error_card_test.dart --plain-name hit-test` 退出 0
- [x] `flutter test test/widget/player/error_card_test.dart test/widget/player/error_card_host_test.dart` 19/19 绿
- [x] `flutter analyze` 0 error / 0 warning（59 info 全预存）
- [x] 全量 `flutter test` 1312 用例全绿（零回归，无预存失败需归因）
- [x] 验收标准逐条核验：13 key switch 与 banner 逐项一致（diff）+ 动作按钮未迁移；五段 D-04 段序 + rawStackTrace 逐字符；完整路径 findsNothing + basename 照常；severity 三值 token 来源 + 双语注释；无 Timer/唯一 dismissCurrent 接线；ExcludeFocus + primaryFocus 不变；无 Positioned.fill 包宿主

---

*Executed by GSD sequential executor, 2026-08-31.*
