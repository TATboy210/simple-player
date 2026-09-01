---
phase: 03-playback-error-card-bridge
plan: 01
subsystem: ui/player/diagnostics-presentation
tags: [error-card, non-modal, card-05, value-notifier, l10n, tracer]
requires:
  - "ErrorReporterImpl.presentation (ValueNotifier<ErrorPresentationState>, Phase 1 契约)"
  - "flushPresentation()/dismissCurrent() 呈现宿主 API（Phase 1，此前无调用方）"
  - "GlassContainer + Tokens 设计系统（D-03 视觉复用）"
provides:
  - "ErrorCardHost —— CARD-05 相位守卫呈现宿主（适配 notifier + 首帧 flushPresentation + dispose 摘除）"
  - "ErrorCard —— 折叠视图（severity 色点 + message + D-01 计数徽标），03-02 在此扩展展开区"
  - "buildErrorCardMount —— MaterialApp.builder root Stack 挂载层（D-10，Navigator 之上）"
  - "全部 Wave 0 错误卡片 l10n key（13 个，中英双语，后续计划不再加 key）"
affects:
  - "03-02：展开区/严格 hit-test 套件/语义色分层/手动关"
  - "03-03：CARD-04 复制/徽标轮览接线/warning→OsdService 路由"
  - "03-04：MIG-01 等效覆盖与 ErrorBanner 删除"
tech-stack:
  added: []
  patterns:
    - "SchedulerPhase 守卫 + post-frame 回调内重读最新值（CARD-05 适配器，研究 Pattern 1 落地）"
    - "宿主自有适配 ValueNotifier（D-08/A5：ValueListenableBuilder 订阅意图 + 避开 build 期同步发布）"
    - "MaterialApp.builder root Stack + Positioned(left,top) 内在尺寸挂载（D-10/CARD-02）"
    - "BuildOwner.onBuildScheduled 计数断言帧调度次数（同帧合并的唯一可观测缝）"
key-files:
  created:
    - lib/ui/player/error_card_host.dart
    - lib/ui/player/error_card.dart
    - test/widget/player/error_card_host_test.dart
  modified:
    - lib/app.dart
    - lib/ui/theme/tokens.dart
    - lib/l10n/app_en.arb
    - lib/l10n/app_zh.arb
    - lib/l10n/app_localizations.dart
    - lib/l10n/app_localizations_en.dart
    - lib/l10n/app_localizations_zh.dart
key-decisions:
  - "适配器非直接订阅：ValueListenableBuilder 读宿主自有 notifier 而非 reporter.presentation（A5 偏差已在 doc comment 记录），CARD-05 唯一失效路径由此封死"
  - "计数徽标 = pendingCount + 1（含队首总数）：行为规格「1 错误」优先于 action 文本的『先用 pendingCount』表述，符合 D-01『已捕获错误数』语义"
  - "卡片直接渲染 report.message（intake 已脱敏限界快照），不复刻 error_banner 的 l10nKey switch；MIG-01 等效覆盖口径（03-04）按 D-09『消息+严重级可见性』处理"
  - "挂载 builder 提取为 app.dart 顶层函数 buildErrorCardMount：测试复用同一挂载语义，避免 harness 复制导致漂移"
  - "Task 1 用真实 App 组合根 + windowInitError 降级 home 做端到端测试：不构造 MediaKitEngine（headless mdk.dll 预存基线），且降级路径同时充当 Task 2 的降级存活用例"
patterns-established:
  - "CARD-05 相位守卫适配器（SchedulerPhase.idle 才同步应用，非 idle 一律 post-frame 重读）——后续任何订阅 reporter.presentation 的 UI 必须走此模式"
  - "flutter_test 中模拟 FlutterError.onError 生产钩子的标准姿势：链回原 handler 记账 + takeException 消费（直接吞掉会挂死测试，见 Issues Encountered）"
requirements-completed:
  - CARD-05
  - CARD-06
coverage:
  - kind: test
    ref: "test/widget/player/error_card_host_test.dart 'accepts a report and shows the card at the top-left'"
    status: pass
    human_judgment: false
    note: "CARD-06/D-10：真实接纳报告 → presentation → 宿主 → 左上角卡片（message + 「1 错误」徽标 + 位置断言）"
  - kind: test
    ref: "test/widget/player/error_card_host_test.dart 'presents a pre-mount report after the first flush (D-12)'"
    status: pass
    human_judgment: false
    note: "D-12：挂载前入队的 bootstrap 错误经首帧 flushPresentation 补呈现；同时覆盖 windowInitError 降级 home 存活（Task 2 behavior 4）"
  - kind: test
    ref: "test/widget/player/error_card_host_test.dart 'taps outside the card bounds reach widgets below'"
    status: pass
    human_judgment: false
    note: "CARD-02 基础穿透（完整 hit-test 套件按计划归 03-02）"
  - kind: test
    ref: "test/widget/player/error_card_host_test.dart 'stays visible above an opaque fullscreen-style route'"
    status: pass
    human_judgment: false
    note: "D-10：不透明全屏样式 route 之上卡片仍可见"
  - kind: test
    ref: "test/widget/player/error_card_host_test.dart 'build-phase report arrival causes no secondary markNeedsBuild'"
    status: pass
    human_judgment: false
    note: "CARD-05 故障注入：build 抛错经 FlutterError.onError → reporter，原错误 post-frame 呈现，零 markNeedsBuild 次生断言"
  - kind: test
    ref: "test/widget/player/error_card_host_test.dart 'same-frame reports converge to one end-of-frame update'"
    status: pass
    human_judgment: false
    note: "CARD-05 时序：persistentCallbacks 相位到达（相位探针记录）+ onBuildScheduled 计数证明单次帧尾终值更新 + 队首/总数正确"
  - kind: verify-command
    ref: "flutter analyze"
    status: pass
    human_judgment: false
    note: "0 error / 0 warning；59 个 info 全部为预存（prefer_initializing_formals 等，非本计划文件）"
  - kind: verify-command
    ref: "flutter test（全量 1299 用例）"
    status: pass
    human_judgment: false
    note: "全绿，无失败——headless mdk.dll 预存基线本次未触发，无预存失败需鉴别，本计划零回归"
  - kind: manual-smoke
    ref: "03-VALIDATION Manual-Only：实机全屏期间卡片显示 + 卡片显示期控制栏/标题栏命中"
    status: pending
    human_judgment: true
    note: "widget test 无法复现 media_kit 全屏 route 与宿主窗口 hit-test；按验证策略归 Windows 实机 smoke（Phase 3 收尾统一执行）"
duration: 45
completed: 2026-08-31
status: complete
actuals:
  tokens: 8300
  tasks: 2
  commits: 3
---

# Phase 3 Plan 01: 错误卡片端到端 Tracer（宿主 + 折叠视图 + app root 挂载）Summary

**One-liner:** 一份真实接纳的 ErrorReport 全链路贯通：`ErrorReporterImpl.presentation` → CARD-05 相位守卫宿主 → 折叠视图卡片 → app root Navigator 之上的左上角常驻显示，build 期故障注入与同帧多报告时序由回归测试锁死。

## Performance

- **Estimate:** 60000 tokens / 2 tasks（confidence: low）
- **Actual:** ~8300 tokens（chars/4，3 个 commit 合计 742 insertions）/ 2 tasks / 3 commits / 41 min
- 估算偏差主因：研究阶段的 Pattern 1 骨架可直接落地，六项宿主义务集中在两个小文件（小即是美），无返工。

## Accomplishments

- **端到端 tracer 全绿**：`reportBootstrapSafely/reportFlutterSafely` 接纳的报告经 `presentation` → `ErrorCardHost` 适配层渲染为左上角可见卡片，显示 message 与 D-01 计数徽标（中文 locale「1 错误」）。
- **CARD-05 锁死**：宿主相位守卫（`SchedulerPhase.idle` 才同步应用，非 idle 一律 `addPostFrameCallback` 且回调内重读最新值）。故障注入证明 build 期抛错零次生 `markNeedsBuild`；同帧多报告经 `onBuildScheduled` 计数证明收敛为一次帧尾终值更新（队首显示 + 总数徽标）。
- **D-10 挂载**：`MaterialApp.builder` root Stack、`Positioned(left: Tokens.controlBarMarginH, top: Tokens.spMd)` 内在尺寸挂 Navigator 之上——不透明 route 之上仍可见；卡外点击穿透（CARD-02 基础）。D-05「设置覆盖卡片」语义被 D-10 取代（挂载处中文注释记录）。
- **D-12 补呈现**：宿主首帧 post-frame `flushPresentation()`，挂载前入队的 bootstrap/windowInit 错误最终可见（含 windowInitError 降级 home 存活用例）。
- **Wave 0 l10n 一次到位**：13 个 errorCard* key 中英双语入库，`flutter gen-l10n` 产物随 RED commit 提交，后续计划不再加 key。
- **CARD-01 前置**：卡片子树 `ExcludeFocus`，交互元素一律 `GestureDetector`（无 GlassButton 焦点劫持面）；T-03-02 纯 `Text` 渲染；T-03-01 可见区只投影已脱敏字段。

## Task Commits

| Task | Commit | Type | Content |
|------|--------|------|---------|
| 1 (tracer RED) | 5ef2a30e | test(03-01) | 失败的端到端测试 4 用例 + 全部 Wave 0 l10n key（双语）+ gen-l10n 产物 |
| 1 (tracer GREEN) | 31e124ee | feat(03-01) | ErrorCardHost 相位守卫宿主 + ErrorCard 折叠视图 + app.dart buildErrorCardMount + Tokens.errorCardMaxWidth |
| 2 | 4ef2733 | test(03-01) | CARD-05 故障注入 + 同帧合并时序回归测试（实现零改动，Task 1 已建立） |

Tracer feedback gate：Task 1 后重跑 `<verify>`（focused 4/4 绿）→ `⚡ Tracer verified end-to-end — expanding`。

## Files Created/Modified

**Created:** `lib/ui/player/error_card_host.dart`（111 行）、`lib/ui/player/error_card.dart`（~110 行）、`test/widget/player/error_card_host_test.dart`（6 用例）

**Modified:** `lib/app.dart`（builder 挂载层 + D-10 注释）、`lib/ui/theme/tokens.dart`（errorCardMaxWidth）、`lib/l10n/app_en.arb` / `app_zh.arb` / 三个生成的 `app_localizations*.dart`

## Decisions Made

见 frontmatter `key-decisions`。核心一条：**适配器订阅（宿主自有 notifier）替代直接订阅 reporter.presentation**——这是 D-08/A5 预授权的偏差，理由（CARD-05 build 期同步发布）已写进源码 doc comment，后续计划的展开区/复制逻辑继续消费该适配层。

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocker] Tokens.errorCardMaxWidth 落在 tokens.dart（plan files_modified 未列）**
- **Found during:** Task 1
- **Issue:** 折叠 message 需要 320px 截断宽度；项目红线「所有视觉值经 Tokens.*」禁止裸数字
- **Fix:** 在 tokens.dart 错误卡片段新增 `errorCardMaxWidth = 320.0`
- **Files modified:** lib/ui/theme/tokens.dart
- **Verification:** flutter analyze 0 error；测试经 maxWidth 约束渲染正常
- **Commit:** 31e124ee

### Plan-execution Deviations（非缺陷，口径澄清）

**2. 计数徽标值 = pendingCount + 1（含队首）**
- **Found during:** Task 1
- **Issue:** action 文本说「先用 presentation 的 pendingCount」，但 behavior 规格明确单份报告显示「1 错误」；`_publishSafely` 的 ready 态 pendingCount 不含队首（单报告时为 0）
- **Fix:** 宿主 build 计算 `totalCount = pendingCount + 1`，注释记录 D-01「已捕获错误总数」语义；behavior 规格优先
- **Files modified:** lib/ui/player/error_card_host.dart
- **Verification:** 两用例断言「1 错误」「2 错误」均过
- **Commit:** 31e124ee

**3. 挂载 builder 提取为公开顶层函数 buildErrorCardMount**
- **Found during:** Task 1
- **Issue:** 穿透/故障注入用例需要与生产完全一致的挂载语义；复制 builder 进测试会漂移
- **Fix:** app.dart 顶层函数承载 builder 逻辑，MaterialApp.builder 与测试共用
- **Commit:** 31e124ee

**4. Task 2 为纯测试 commit（无 GREEN 实现变更）**
- **Found during:** Task 2
- **Issue:** 计划预期 Task 2「补齐最后实现细节」，但 Task 1 的 GREEN 实现已完整覆盖（非 idle 一律推迟 / mounted 守卫 / == 短路——后者由 ValueNotifier.value setter 内建）
- **Fix:** Task 2 只交付回归测试锁死；RED 即 GREEN，已在 commit message 说明
- **Commit:** 4ef2733

**Total deviations:** 1 auto-fixed（Rule 3）+ 3 口径澄清。**Impact:** 无架构影响；Tokens 补充符合红线方向；徽标语义以行为规格为准。

## Issues Encountered

**flutter_test 不可直接吞掉 FlutterError.onError（10 分钟挂死）**：故障注入首版把 `FlutterError.onError` 替换为只进 reporter 的 handler，测试体挂死到 10 分钟超时（binding 异常记账 `_pendingExceptionDetails` 断裂）。修复模式：handler 内**链回原 handler** + `tester.takeException()` 主动消费预期异常，20 秒内稳定通过。已写入测试注释作为本仓库标准姿势（patterns-established 第 2 条）。

**Headless 基线归因**：全量 `flutter test` 1299 用例**全绿**——memory 记载的 mdk.dll FFI/窗口类预存失败本环境本次未触发，无需 stash 鉴别；本计划零回归。

## Known Stubs

| File | Line | Stub | Reason / Resolution |
|------|------|------|---------------------|
| lib/ui/player/error_card.dart | onTap: () {} （计数徽标） | 空点击回调 | D-01 徽标轮览接线按计划归 03-03（13 个 l10n key 已含轮览文案）；非本计划目标缺口 |

## Threat Flags

无新增计划外信任边界。计划 `<threat_model>` 五项 disposition 落实情况：T-03-01（可见区仅脱敏字段）、T-03-02（纯 Text 渲染）、T-03-04（Positioned 内在尺寸 + 禁 Positioned.fill/IgnorePointer 的挂载注释）已落地并有测试/源码可指认；T-03-03（相位守卫）由本计划测试锁死。

## Next Phase Readiness

- 03-02 直接在 `ErrorCard` 上扩展展开区（13 key 中 errorCardSection* / errorCardLocationUnavailable 已备）与语义色分层；严格 hit-test 套件挂进 `error_card_host_test.dart` 同款 harness。
- 03-03 的复制/轮览/warning 路由接线点：徽标 GestureDetector、宿主 `_apply` severity 分流（注释已标位）。
- 03-04 MIG-01 等效覆盖按「消息+严重级可见性」断言（D-09）；本计划卡片渲染口径（report.message 直显）已记录，等效测试设计时需对齐。
- Windows 实机 smoke 清单（03-VALIDATION Manual-Only）保持 pending，Phase 3 收尾统一执行。

## Self-Check: PASSED

- [x] 创建文件存在：error_card_host.dart / error_card.dart / error_card_host_test.dart（`git ls-files` 均可查）
- [x] Commits 存在：5ef2a30e / 31e124ee / 4ef2733（git log 验证）
- [x] `flutter test test/widget/player/error_card_host_test.dart` 退出 0（6/6）
- [x] `flutter analyze` 0 error / 0 warning（红线达成）
- [x] 全量 `flutter test` 1299 用例全绿（无预存失败需归因）
- [x] 验收标准逐条核验：六项骨架义务源码可指认；相位守卫回调内重读；挂载为 Positioned(left,top) 无 Positioned.fill/IgnorePointer；l10n 双语齐备且产物入库；测试零 MediaKitEngine 构造

---

*Executed by GSD sequential executor, 2026-08-31.*
