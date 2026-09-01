---
phase: 03-playback-error-card-bridge
plan: 03
subsystem: ui/player/diagnostics-presentation
tags: [error-card, copy-diagnostic-pack, clipboard-mock, severity-routing, osd-routing, badge-cycling, local-snapshot, tdd]
requires:
  - "ErrorCardHost + ErrorCard（03-01/02，本计划补交互切片）"
  - "formatDiagnosticPack(ErrorReport, {logPath})（LOG-05 单一来源，Phase 2）"
  - "ErrorReporterImpl.diagnosticLogPath（ValueListenable<String?>，Phase 2）"
  - "OsdService.I.show(text, icon:)（D-06/D-02 反馈通道）"
  - "ErrorReporterImpl effects 扩展缝（Phase 2 设计的副作用挂点）"
provides:
  - "ErrorCard 一键复制诊断包（CARD-04/D-06：LOG-05 同源同格式 + 两态 OSD 反馈 + 失败隔离）"
  - "D-02 severity 路由完成版：warning→OSD 恰好一次 + 单次 dismissCurrent（eventId 防重）"
  - "D-01/D-11 徽标轮览：ErrorCaptureSnapshot 本地有界快照（≤20）+ 宿主轮览索引（纯视图偏移）"
  - "error_capture_snapshot.dart —— 呈现层快照 store（既有 effects 缝维护，kernel 零改动）"
affects:
  - "03-04：MIG-01 ErrorBanner 删除（卡片消息/严重级/复制呈现能力已全量就位）"
  - "Phase 4/5：新增 warning 产生源时 D-02 分流即刻生效（该分支已测试锁死）"
tech-stack:
  added: []
  patterns:
    - "呈现层快照经既有 effects 缝维护：presentation 只发布 FIFO 队首，D-01 显示最新 + 已捕获计数在其上不可实现 —— effect(每份接纳报告) 是唯一零 kernel 改动的观察点"
    - "Clipboard mock 缝 = SystemChannels.platform handler（成功捕获与失败注入同一缝）；未 mock 的 send 在测试 binding 中永不完成（非 MissingPluginException）"
    - "徽标轮览 = 纯视图偏移：渲染取快照索引，适配 notifier 保持 reporter 队首语义，dismissCurrent 零调用（presentation 通知计数断言）"
key-files:
  created:
    - lib/ui/player/error_capture_snapshot.dart
  modified:
    - lib/ui/player/error_card.dart
    - lib/ui/player/error_card_host.dart
    - lib/main.dart
    - test/widget/player/error_card_test.dart
    - test/widget/player/error_card_host_test.dart
key-decisions:
  - "D-11 快照数据源改走既有 effects 缝（ErrorCaptureSnapshot，UI 层新文件 + main.dart 一行 effect 挂入）：计划假设 presentation 通知能逐份送达新报告 —— 实际 _publishSafely 只发布 _queue.first，后入队报告在成为队首前对呈现层不可见，D-01「显示最新/徽标计数」被测试证伪；fallback 未新增 kernel API（research Open Question 3 红线保持）"
  - "D-01 替换语义落实为「卡片显示最新」：03-02 两个多报告用例（关闭推进/同帧合并）从队首断言翻转为最新断言 —— 计划 Task 2 RED 明确要求「连续接纳 3 份报告卡片显示最新」，且轮览方向「向旧轮览（循环）」只有最新为默认位才自洽"
  - "手动关闭消费真实队首（presentation.current）而非轮览显示条目，快照同步移除该条：dismissCurrent 语义（CAP-04）不动，徽标计数与用户已处置的条目保持一致"
  - "MissingPluginException typed catch 保留为防御分支：SystemChannels.platform 是 OptionalMethodChannel，invokeMethod 内部已吞掉 MissingPluginException，该路径经 channel 不可触达；测试改为断言「未 mock channel 不崩溃、卡片无恙」"
  - "warning 合成数据直接向公开 presentation ValueNotifier 发布快照（同 03-02 口径）：四个捕获源硬编码 error/fatal，forTesting intake 产不出 warning；error/fatal 用例仍走真实 intake"
requirements-completed:
  - CARD-04
  - CARD-03
coverage:
  - kind: test
    ref: "test/widget/player/error_card_test.dart 'copy sends a formatter-identical pack and shows copied OSD'"
    status: pass
    human_judgment: false
    note: "LOG-05 单一来源：复制文本与 formatDiagnosticPack 输出逐字符相等；OSD「已复制」+ check 图标；折叠态不变"
  - kind: test
    ref: "test/widget/player/error_card_test.dart 'pack logPath section reflects diagnosticLogPath at copy time'"
    status: pass
    human_judgment: false
    note: "logPath 复制时刻取值（注入 _FakeLogStatus），与 formatter(logPath: 同值) 输出相等"
  - kind: test
    ref: "test/widget/player/error_card_test.dart 'PlatformException injection shows failed OSD and keeps card intact'"
    status: pass
    human_judgment: false
    note: "失败注入 →「复制失败」pill，卡片可见且内容不变，takeException 为 null（T-03-11 隔离）"
  - kind: test
    ref: "test/widget/player/error_card_test.dart 'unmocked clipboard channel leaves card intact with no crash'"
    status: pass
    human_judgment: false
    note: "channel 真实语义验证：无崩溃、卡片无恙（OptionalMethodChannel 吞 MissingPluginException，见 key-decisions）"
  - kind: test
    ref: "test/widget/player/error_card_host_test.dart 'warning head routes to OSD and advances exactly once'"
    status: pass
    human_judgment: false
    note: "D-02：OSD 一次（非空计数缝）+ presentation 通知恰好 +2（发布+单次推进）；同 eventId 重复发布守卫后计数不再增加；后续 error 正常上卡（T-03-09）"
  - kind: test
    ref: "test/widget/player/error_card_host_test.dart 'newest error replaces the card and badge counts the snapshot'"
    status: pass
    human_judgment: false
    note: "D-01 替换语义：3 份报告显示最新、不堆叠，徽标「3 错误」；第 4 份到达内容替换计数跟进"
  - kind: test
    ref: "test/widget/player/error_card_host_test.dart 'badge tap cycles older through the snapshot and wraps'"
    status: pass
    human_judgment: false
    note: "D-11 循环轮览：最新→旧→最旧→回最新；轮览期 presentation 通知数 0（dismissCurrent 零调用，T-03-10）"
  - kind: test
    ref: "test/widget/player/error_card_host_test.dart 'snapshot caps at the bound and evicts the oldest'"
    status: pass
    human_judgment: false
    note: "21 份报告徽标封顶「20 错误」；轮览到最旧显示第 2 份（第 1 份被挤出）"
  - kind: test
    ref: "test/widget/player/error_card_host_test.dart 'manual close during cycling advances the real head and resets'"
    status: pass
    human_judgment: false
    note: "轮览中关闭：真实队首被消费、徽标减一、轮览重置到最新、可继续翻页"
  - kind: verify-command
    ref: "flutter test test/widget/player/error_card_test.dart --plain-name copy"
    status: pass
    human_judgment: false
    note: "Task 1 focused 命令退出 0（4 用例）"
  - kind: verify-command
    ref: "flutter test test/widget/player/error_card_host_test.dart --plain-name warning"
    status: pass
    human_judgment: false
    note: "Task 2 focused 命令退出 0（1 用例）"
  - kind: verify-command
    ref: "flutter test test/widget/player/error_card_test.dart test/widget/player/error_card_host_test.dart"
    status: pass
    human_judgment: false
    note: "计划 verification：28 用例全绿（17 卡片 + 11 宿主）"
  - kind: verify-command
    ref: "flutter analyze"
    status: pass
    human_judgment: false
    note: "0 error / 0 warning；59 个 info 全部预存（与 03-01/02 基线同数）"
  - kind: verify-command
    ref: "flutter test（全量 1321 用例）"
    status: pass
    human_judgment: false
    note: "全绿 exit 0 —— headless mdk.dll 预存基线本次未触发，本计划零回归"
  - kind: manual-smoke
    ref: "VER-04 Manual-Only：Windows 实机剪贴板真复制 + warning OSD 持续时长观感"
    status: pending
    human_judgment: true
    note: "widget test 用 mock channel 驱动，真实系统剪贴板写入与 OSD 观感须实机确认；归 Phase 3 收尾统一执行"
duration: 34
completed: 2026-08-31
status: complete
actuals:
  tokens: 8800
  tasks: 2
  commits: 4
---

# Phase 3 Plan 03: 一键复制诊断包与严重级路由/徽标轮览（CARD-04/CARD-03 + D-01/D-02/D-06/D-11）Summary

**One-liner:** 卡片补齐「复制即证据」闭环（复制文本与日志文件逐字符同源，成功/失败两态 OSD 反馈且异常不外溢）与多错误回看能力（warning 分流 OSD 恰好一次推进、徽标在 20 条本地有界快照内向旧循环轮览），至此除 MIG-01 迁移外的全部卡片行为到位。

## Performance

- **Estimate:** 50000 tokens / 2 tasks（confidence: low）
- **Actual:** ~8800 tokens（chars/4，4 个 commit 合计 727 insertions / 55 deletions）/ 2 tasks / 4 commits / 34 min
- 估算偏差主因：03-02 的卡片/宿主骨架直接扩展；D-11 快照缝被证伪后的 fallback（新增 store 文件）多花约 15 分钟但避免了 kernel 改动。

## Accomplishments

- **CARD-04/D-06 复制通路**：`_copyDiagnosticPack` 一律调 `formatDiagnosticPack(report, logPath: diagnosticLogPath.value)`（复制时刻取值，LOG-05 单一来源 —— 卡内零自拼格式字符串）；成功「已复制」/失败「复制失败」两态 OsdService pill；typed catch `PlatformException`（KernelLogger.I.w 结构化记录）+ `MissingPluginException`（防御分支），异常绝不外溢、卡片可见性与内容不受影响（T-03-11）。复制按钮 GestureDetector 内层命中 + Semantics，零焦点抢占（CARD-01），折叠/展开状态不变。
- **D-02 severity 路由完成版**：warning 队首 → `OsdService.I.show(message, icon: warning_amber)` + 恰好一次 `dismissCurrent()`；`_lastWarningEventId` 防同帧/同 eventId 重复触发（去重合并重发布与相位守卫双回调场景，T-03-09）；warning 不上卡片、不进快照。当前四个捕获源不产生 warning，该分支为 Phase 4/5 前瞻且已被测试锁死。
- **D-01/D-11 徽标轮览**：`ErrorCaptureSnapshot`（UI 层 store，经 reporter 既有 effects 缝维护，上界 20 命名常量、eventId 原地合并、超出挤最旧）+ 宿主单字段轮览索引（渲染取 `快照[len-1-index]`，取模循环）；新报告重置到最新；轮览期 `dismissCurrent` 零调用（presentation 通知计数断言，T-03-10）；手动关闭消费真实队首并同步移除快照条目（已处置不再计入徽标）。卡片只替换不堆叠（D-01）。
- **呈现层快照缝的执行期证伪与 fallback**（详见 Deviations 1）：presentation 只发布 FIFO 队首，计划假设的「自 presentation 通知逐份维护快照」不可实现；改用既有 effect 缝后 kernel 保持零改动（research Open Question 3 红线达成）。
- **03-02 基线修正**：两个多报告用例（关闭推进/同帧合并）的显示断言从「队首」翻转为「最新」—— D-01 替换语义与轮览方向（向旧循环）的必然推论，计划 Task 2 RED 明确要求。

## Task Commits

| Task | Commit | Type | Content |
|------|--------|------|---------|
| 1 (RED) | 2505bc52 | test(03-03) | copy 组 4 用例（同源等值/logPath 取值/PlatformException 注入/channel 缺失路径） |
| 1 (GREEN) | 218db016 | feat(03-03) | 复制按钮 + _copyDiagnosticPack（typed catch + 两态 OSD 反馈 + 失败隔离） |
| 2 (RED) | 9015c240 | test(03-03) | warning 路由 + 徽标轮览 5 用例；两个 03-02 多报告用例翻转为最新语义 |
| 2 (GREEN) | 21b632c6 | feat(03-03) | ErrorCaptureSnapshot store + severity 路由完成版 + 轮览索引 + main.dart effect 挂入 |

## Files Created/Modified

**Created:** `lib/ui/player/error_capture_snapshot.dart`（86 行 —— D-11 有界快照 store）

**Modified:** `lib/ui/player/error_card.dart`（复制按钮 + 可点击徽标 + onBadgeTap）、`lib/ui/player/error_card_host.dart`（severity 路由 + 轮览索引 + 快照监听相位守卫）、`lib/main.dart`（快照 effect 挂入，一行）、`test/widget/player/error_card_test.dart`（+copy 组 4 用例，关闭用例语义修正）、`test/widget/player/error_card_host_test.dart`（+warning/badge 两组 5 用例，同帧用例语义修正）

## Decisions Made

见 frontmatter `key-decisions`。核心一条：**D-11 快照数据源改走既有 effects 缝** —— 计划假设 presentation 通知能逐份送达新报告，实际 `_publishSafely` 只发布 `_queue.first`（后入队报告成为队首前对呈现层不可见），D-01「显示最新/徽标已捕获计数」在该缝上被测试证伪；fallback 采用 Phase 2 设计的 effect 观察点（`ErrorReporterImpl.init(effects: [..., ErrorCaptureSnapshot.I.record])`），未新增任何 kernel API，D-11「不给 kernel 新增只读历史 API」文字与精神均保持。

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical] D-11 快照的 presentation 通知源被测试证伪，改用既有 effects 缝**
- **Found during:** Task 2 GREEN
- **Issue:** `_apply(state)` 只能观察到 `state.current` = FIFO 队首（`error_reporter._publishSafely`）；连续接纳 3 份报告时快照只见过队首一份，「卡片显示最新 + 徽标 3 错误」（计划 RED 原文）在 presentation 缝上不可实现 —— 触发计划预授权的 fallback 条款（research Open Question 3）
- **Fix:** 新增 UI 层 `ErrorCaptureSnapshot`（有界 20、eventId 原地合并、warning 跳过），组合根经**既有** effects 缝挂入；kernel 零改动、零新 API；宿主只持轮览索引单一视图状态
- **Files modified:** lib/ui/player/error_capture_snapshot.dart（新）、lib/main.dart、lib/ui/player/error_card_host.dart
- **Verification:** badge 组 4 用例全绿；全量 1321 用例零回归
- **Commit:** 21b632c6

**2. [Rule 1 - Lint] PlatformException catch 的未用 stackTrace 参数**
- **Found during:** Task 1 GREEN
- **Issue:** `unused_catch_stack` warning（KernelLogger.I.w 无 stackTrace 参数）—— analyze 基线从 59 涨到 60
- **Fix:** 移除未用 catch 参数
- **Verification:** `flutter analyze lib/ui/player/error_card.dart` 零问题；总体回到 59 预存 info
- **Commit:** 218db016

### Plan-execution Deviations（非缺陷，口径澄清）

**3. MissingPluginException「天然路径」不可达**
- **Found during:** Task 1
- **Issue:** 计划假设「handler 未注册时 Clipboard.setData 天然抛 MissingPluginException」；实测（Flutter 3.47）未 mock 的 send 永不完成（消息被测试 binding 丢弃），且 `SystemChannels.platform` 是 OptionalMethodChannel —— 其 invokeMethod 内部**吞掉** MissingPluginException 返回 null
- **Fix:** 测试改为断言真实可观察行为（无崩溃、卡片无恙）；生产 `on MissingPluginException` catch 保留为防御分支并注明不可经 channel 触达
- **Commit:** 218db016

**4. 两个 03-02 多报告用例断言翻转（队首 → 最新）**
- **Found during:** Task 2
- **Issue:** 03-02 锁定的「FIFO 队首显示」与 D-01「新错误替换卡片内容」+ 轮览方向「向旧循环」矛盾（最新为默认位才自洽）；计划 Task 2 RED 明确要求显示最新
- **Fix:** error_card_test 关闭用例与 host_test 同帧用例的显示断言翻转为最新，注释记录 D-01 语义；两用例核心断言（CAP-04 推进 / buildScheduledCount==2）不变
- **Commit:** 9015c240

**5. warning 合成数据直构发布**
- **Found during:** Task 2
- **Issue:** 四个捕获源硬编码 error/fatal，`forTesting` intake 产不出 warning（D-02 分层本就是 Phase 4/5 前瞻）
- **Fix:** 直接向公开的 `presentation` ValueNotifier 发布合成快照（宿主唯一监听缝，零 kernel 改动）；error/fatal 用例仍走真实 intake。同 03-02 SUMMARY deviation #3 口径
- **Commit:** 9015c240

**Total deviations:** 2 auto-fixed（Rule 2 + Rule 1）+ 3 口径澄清。**Impact:** 无架构破坏 —— kernel 零改动、零新包、零新 API；fallback 复用 Phase 2 设计的 effect 缝，属计划预授权 fallback 条款的落地（未新增 reporter 只读 API，故未触发「需先回 planner」条款的字面条件）；语义修正均以计划 RED 原文为权威。

## Issues Encountered

- **未 mock platform channel 的 send 永不完成**：scratch 验证确认 Flutter 3.47 测试 binding 对未注册 channel 丢弃消息（Future 悬挂）而非抛 MissingPluginException —— 修正测试策略（见 Deviation 3），生产代码不变。
- **Headless 基线归因**：全量 `flutter test` 1321 用例**全绿**（exit 0）—— memory 记载的 mdk.dll FFI/窗口类预存失败本环境本次未触发，无需 stash 鉴别；本计划零回归。测试全程未构造 MediaKitEngine/media_kit Player。
- **Windows 实机项显式登记（Manual-Only / VER-04）**：真实系统剪贴板写入与 warning OSD 观感归 Phase 3 收尾统一执行。

## Known Stubs

无新增。03-01/03-02 登记的徽标空回调占位（`onTap: () {}`）已由本计划 Task 2 回收为 `onBadgeTap: _cycleBadge` 实接线。

## Threat Flags

无新增计划外信任边界。计划 `<threat_model>` 落实情况：T-03-08（剪贴板暴露 accept —— D-07 批准开发机完整路径入包，包内容经既有脱敏）、T-03-09（warning 恰好一次推进 + eventId 防重，测试锁死）、T-03-10（轮览纯视图偏移，presentation 通知计数为零的断言可指认）、T-03-11（typed catch 双路径测试）、T-03-SC（零新增包）维持。

## Next Phase Readiness

- 03-04 MIG-01：卡片侧消息解析（13 key）、严重级色、复制、关闭、轮览全部就位 —— ErrorBanner 删除后无能力缺口；等效覆盖按 D-09「消息+严重级可见性」口径（不含动作按钮）。
- 呈现层快照（ErrorCaptureSnapshot）现为准公共缝：03-04 若需「删除 ErrorBanner 后等效覆盖」的多报告场景，harness 接线方式见两测试文件 setUp。
- Windows 实机 smoke 清单（VER-04 Manual-Only）保持 pending，Phase 3 收尾统一执行。
- REQUIREMENTS 同步：CARD-04 本轮直接标记；CARD-03（03-02 起 ready-ids gate blocked）本轮随最后一个声明计划 SUMMARY 落盘重试标记。

## Self-Check: PASSED

- [x] 创建文件存在：lib/ui/player/error_capture_snapshot.dart（git ls-files 可查）
- [x] Commits 存在：2505bc52 / 218db016 / 9015c240 / 21b632c6（git log 验证）
- [x] `flutter test test/widget/player/error_card_test.dart --plain-name copy` 退出 0（4/4）
- [x] `flutter test test/widget/player/error_card_host_test.dart --plain-name warning` 退出 0（1/1）
- [x] `flutter test test/widget/player/error_card_test.dart test/widget/player/error_card_host_test.dart` 28/28 绿
- [x] `flutter analyze` 0 error / 0 warning（59 info 全预存）
- [x] 全量 `flutter test` 1321 用例全绿（零回归，无预存失败需归因）
- [x] 验收标准逐条核验：复制文本逐字符等于 formatter 输出（无卡内自拼）；两态 OSD 反馈 + 卡片不受影响；logPath 复制时刻取值；无新增动作按钮（D-09）；warning 恰好一次 OSD+推进无循环；快照 eventId 身份/上界 20 命名常量/最旧挤出；轮览 dismissCurrent 零调用 + 手动关闭重置；新错误替换不堆叠；kernel 文件 diff 为零

---

*Executed by GSD sequential executor, 2026-08-31.*
