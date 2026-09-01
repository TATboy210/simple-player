---
phase: 04-error-feedback-settings
plan: 03
subsystem: diagnostics
tags: [render-gate, value-notifier, error-card, settings-toggle, zero-kernel, tdd]

# Dependency graph
requires:
  - phase: 04-error-feedback-settings
    plan: 01
    provides: "ErrorFeedbackSettings store（I.state notifier + setCardEnabled + resetForTesting seam + 默认开语义）"
  - phase: 03-playback-error-card-bridge
    provides: "ErrorCardHost 呈现宿主 + ErrorCaptureSnapshot effect 缝（快照保留机制）"
provides:
  - "ErrorCardHost.build 外层渲染门控：!errorCardEnabled → SizedBox.shrink()（D-05 同帧消失）"
  - "SET-01 呈现语义自动化锁定：off 同帧消失 / off 期间快照继续收 / on 恢复最新（含 off 期间错误）/ 默认开"
  - "host 测试 setUp 的 store 单例隔离惯例（resetForTesting + 临时目录 seam + addTearDown 清理）"
affects: [04-04-settings-ui]

# Actuals (#2632) — chars/4 over the realized diff (12,368 bytes across 2 files)
actuals:
  tokens: 3092
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []  # 零新包 —— Flutter SDK ValueListenableBuilder + 既有依赖（T-04-03-SC accept 依据）
  patterns:
    - "build 级呈现门控：外层 ValueListenableBuilder 订阅 store 单例，off 同帧 SizedBox.shrink；门控绝不进入 _apply/_routeWarning（warning 分流免伤）"
    - "widget 测试中的真实 I/O 等待点：tester.runAsync 包裹（testWidgets FakeAsync zone 不派发真实文件事件）"

key-files:
  created: []
  modified:
    - lib/ui/player/error_card_host.dart
    - test/widget/player/error_card_host_test.dart

key-decisions:
  - "门控订阅整个 ErrorFeedbackSettingsData（ValueListenableBuilder<ErrorFeedbackSettingsData>）而非拆 bool notifier —— 04-04 设置 UI 复用同一 store 单例，logDirectory 变更引发的额外重建无副作用"
  - "默认开用例定位为回归锁（store 默认值 + 门控缺省接线的双重守护）：RED 期通过是构造性事实（无门控代码时卡片本就显示），其防回归价值在于锁定门控接线的默认态"
  - "settings seam 在 setUp 统一重绑到系统临时目录下不存在路径 —— 既有 14 用例零改动继承默认开隔离，新用例共享同一 seam"
  - "正确相对导入 ../dialogs/settings/（计划字面 ../../dialogs/ 会解析到 lib/dialogs 不存在路径）"

requirements-completed: [SET-01]  # 计划声明的贡献需求；ready-ids 门判定见下（通用 tab UI 行属 04-04）

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "off 同帧消失：开关关闭后一次 pump 内 ErrorCard findsNothing，且 presentation.current 仍非空（队列未被消费 —— 关卡片不动队列）"
    requirement: SET-01
    verification:
      - kind: widget
        ref: "test/widget/player/error_card_host_test.dart#toggle off hides the card the same frame and keeps the queue"
        status: pass
    human_judgment: false
  - id: D2
    description: "off 期间捕获零影响：快照长度增长（record 从不查询开关）+ presenter 链推进（pendingCount 增长）+ 卡片仍隐藏（只落盘不弹卡的呈现侧证明）"
    requirement: SET-01
    verification:
      - kind: widget
        ref: "test/widget/player/error_card_host_test.dart#reports keep flowing into snapshot and presenter while gated off"
        status: pass
    human_judgment: false
  - id: D3
    description: "on 恢复最新：重新开启后立即渲染快照最新报告（含 off 期间到达的那条，D-05「含队列中错误」）"
    requirement: SET-01
    verification:
      - kind: widget
        ref: "test/widget/player/error_card_host_test.dart#toggle on restores the newest report including off-period errors"
        status: pass
    human_judgment: false
  - id: D4
    description: "默认开：settings.json 缺失（seam 指向不存在文件 + load 静默回退）时挂载注入错误卡片正常显示 —— 与 Phase 3 行为完全一致"
    requirement: SET-01
    verification:
      - kind: widget
        ref: "test/widget/player/error_card_host_test.dart#missing settings file keeps the card enabled by default"
        status: pass
    human_judgment: false
  - id: D5
    description: "warning 分流不受门控影响（结构级证明）：门控只存在于 build 最外层，_apply/_routeWarning/_onSnapshotChanged/_onClose 代码零改动（diff 仅为缩进位移 + 门控注释）；Phase 3 host 用例 14/14 零回归"
    requirement: SET-01
    verification:
      - kind: unit
        ref: "git diff 面审计（presenter 符号仅出现在重排缩进的注释行）+ test/widget/player/ 332 例全绿"
        status: pass
    human_judgment: false
  - id: D6
    description: "零 kernel 改动红线：lib/kernel/ diff 为 0 行；error_reporter/error_capture_snapshot/error_reporting_dependencies/error_log_file_sink 四文件 diff 均为 0；kernel_logger_gate GATE 1/2 PASS"
    requirement: SET-01
    verification:
      - kind: other
        ref: "git diff f9b27ddb~1 HEAD -- lib/kernel/（空）+ bash tool/audit/kernel_logger_gate.sh（GATE 1/2 PASS）"
        status: pass
    human_judgment: false
  - id: D7
    description: "实机 debug run：开关切换后卡片立即消失/恢复；关闭期间触发错误后 error.log 仍有新记录（呈现与落盘双通道实机观察）"
    verification: []
    human_judgment: true
    rationale: "窗口可见性与落盘文件实机行为无法在 headless 测试中证明（MEMORY: UAT 证据标准 —— 日志只覆盖非 UI 观察点）"

# Metrics
duration: 24min
completed: 2026-08-31
status: complete
---

# Phase 4 Plan 03: 错误卡片开关呈现门控 Summary

**ErrorCardHost.build 外层一行门控锁死 SET-01 全部呈现语义：关→同帧消失只落盘不弹卡、开→恢复含队列中错误的最新报告、缺省→默认开，捕获/快照/落盘链零接触（D-05 零 kernel 由 diff 面与 kernel gate 双重证明）。**

## Performance

- **Duration:** 24 min（含首跑 RED 用例 10 分钟超时的修复往返）
- **Started:** 2026-08-31T16:11:24Z
- **Completed:** 2026-08-31T16:35:16Z
- **Tasks:** 2/2
- **Files:** 2（0 created + 2 modified）

## Accomplishments

- **呈现门控落地（D-05 立即生效）**：`ErrorCardHost.build` 最外层包 `ValueListenableBuilder<ErrorFeedbackSettingsData>`（订阅 `ErrorFeedbackSettings.I.state` 单例，UI→UI 单例与 OsdService.I 同一惯例），`!errorCardEnabled → const SizedBox.shrink()` —— 同帧移除卡片，无退场动画；内部 `ValueListenableBuilder<ErrorPresentationState>` 子树（隐藏门/快照渲染/徽标/close 接线）逐字保留，仅整体缩进一级。
- **off 语义四用例自动化锁定**：off 同帧消失且队列未被消费（presentation.current 仍非空）；off 期间快照继续接纳 + presenter 链推进（pendingCount 增长）而卡片仍隐藏；on 恢复显示快照最新（含关闭期间到达的错误）；settings 缺失经 load 静默回退默认开。
- **零 kernel 红线双重证明**：`git diff -- lib/kernel/` 为 0 行，reporter/snapshot/delegate/sink 四文件 diff 均为 0；`kernel_logger_gate` GATE 1/2 PASS。`_apply`/`_routeWarning`/`_onSnapshotChanged`/`_onClose` 零逻辑改动（warning OSD 分流与轮览重置免伤）。
- **Phase 3 零回归**：既有 14 个 host 用例因 setUp 统一复位 store 默认开而零改动通过；`test/widget/player/` 卡片族 332 例全绿。
- **改动面收窄自检**：计划 diff 仅 2 个声明文件；host 中无新增 reporter/kernel 符号调用（presenter 符号仅出现在重排缩进的既有注释行）。

## Task Commits

1. **Task 1 RED**：卡片开关呈现门控失败测试 —— `f9b27ddb` (test)
2. **Task 1 GREEN**：门控实现 + doc comment 增补 —— `6f2a5289` (feat)

## Files Created/Modified

- `lib/ui/player/error_card_host.dart`（MODIFY）— build 外层 SET-01 门控（+import ../dialogs/settings/error_feedback_settings.dart、类 doc comment 第 7 项骨架义务、门控注释）；内部渲染子树逐字保留
- `test/widget/player/error_card_host_test.dart`（EXTEND，+165 行）— `SET-01 卡片开关呈现门控（D-05）` group 四用例 + setUp 追加 store 单例隔离（resetForTesting + 系统临时目录 seam + addTearDown 清理）+ dart:io/settings store 导入

## Decisions Made

- **订阅整个 settings 数据而非拆 bool**：门控 builder 收 `ErrorFeedbackSettingsData`，读 `settings.errorCardEnabled` —— 04-04 的 Switch 行翻转 `setCardEnabled` 与 logDirectory 变更走同一 notifier，额外重建无副作用（builder 纯渲染）。
- **默认开用例 = 回归锁**：该用例在 RED 期（无门控代码）通过是构造性事实 —— 其守护对象是「门控接线的默认态」（防止未来实现把门控初值写成关）；store 默认值本身已由 04-01 的损坏矩阵锁死，两层证据独立成立。
- **setUp 统一 store 隔离**：`resetForTesting(settingsFile: () => <临时目录>/settings.json)`（不存在的文件路径）+ addTearDown 递归清理 —— 既有用例零改动继承默认开，新用例共享同一 seam；开关翻转的 fire-and-forget 持久化静默失败（D-01），不污染工作区。

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] 默认开用例在 testWidgets 内直接 await 真实 I/O 导致 10 分钟超时**
- **Found during:** Task 1 RED 首跑（15 pass / 3 预期失败 / 1 超时）
- **Issue:** `await ErrorFeedbackSettings.I.load()` 在 testWidgets 的 FakeAsync zone 中永不完成 —— zone 不派发真实文件事件，widget 测试等待点默认超时 10 分钟，拖垮整轮反馈。
- **Fix:** 经 `tester.runAsync(() => ErrorFeedbackSettings.I.load())` 包裹（widget 测试执行真实 I/O 的标准缝），运行时长回落到 2s。
- **Files modified:** test/widget/player/error_card_host_test.dart
- **Verification:** RED 重跑 15 pass / 3 fail（2s）；GREEN 后 18/18 全绿
- **Commit:** f9b27ddb（随 RED 一并入库）

**2. [Rule 3 - Blocker] 计划字面导入路径 `../../dialogs/settings/...` 不存在**
- **Found during:** Task 1 GREEN（写 import 时按目录结构核对）
- **Issue:** 计划 action 写明 import `../../dialogs/settings/error_feedback_settings.dart`，但从 `lib/ui/player/` 出发 `../../` 解析到 `lib/dialogs/`（不存在）——照抄无法编译；目标文件实际位于 `lib/ui/dialogs/settings/`。
- **Fix:** 使用正确相对路径 `../dialogs/settings/error_feedback_settings.dart`。
- **Files modified:** lib/ui/player/error_card_host.dart
- **Verification:** flutter analyze 0 error（该文件 0 条目）
- **Commit:** 6f2a5289（随 GREEN 一并入库）

**Total deviations:** 2（Rule 1 × 1，Rule 3 × 1——均已修复并锁定）
**Impact:** 无范围/接口影响；一处测试作者缺陷（RED 内自行修正），一处计划字面路径笔误。

## Issues Encountered

- 无阻断问题。预存 headless 基线（mdk.dll FFI / 状态机 security）本轮未触及——本计划改动面（host 门控 + host 测试）为纯 Dart/Flutter，headless 全绿。
- `flutter analyze` 61 条 info/warning 全部为未触碰文件的既有条目（与 04-01/04-02 基线同值），触碰文件 0 条、error 0 条。

## Next Phase Readiness

- **04-04（设置 UI）**：消费面全部就绪——`ErrorFeedbackSettings.I.setCardEnabled(bool)`（通用 tab Switch 行直接调用）、`state.value.errorCardEnabled`（行初值）、`DiagnosticLogTarget.I.validate/apply/effectiveLogPath`（04-02 已备）；本计划的门控让 Switch 翻转即时生效，UI 行无需任何回调接线进 host。
- **实机人工核对（headless 无法证明，04-VALIDATION Manual-Only 表）**：debug run 开关切换后卡片立即消失/恢复；关闭期间触发错误后 error.log 仍有新记录（快照/落盘侧自动化已锁，实机验证呈现与落盘双通道闭环）。
- **T-01-13/19 重审**：本计划零触碰诊断内核与写路径，未给 retained 诊断串新增任何 sink——threat register 的 re-verified 结论维持（04-01/04-02 同口径），收账落盘在 Phase 收尾 04-SECURITY.md。

---

*Plan: 04-03 · Wave 2 of 3 · Phase 4-错误反馈设置*
*Executed: 2026-08-31*

## Self-Check: PASSED

- 2 个修改文件均存在于工作区（0 created + 2 modified）
- 2 个任务 commit（f9b27ddb / 6f2a5289）均在 git 历史中
- 质量门：`flutter test test/widget/player/` 332 例全绿（host 文件 18/18）、`flutter analyze` 0 error（61 条既有 info 与基线同值）、`kernel_logger_gate` GATE 1/2 PASS
- 零 kernel 证明：`git diff f9b27ddb~1 HEAD -- lib/kernel/` 为空
