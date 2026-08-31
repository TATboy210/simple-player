---
phase: 04-error-feedback-settings
plan: 02
subsystem: diagnostics
tags: [settings-validation, retarget-protocol, single-writer, value-notifier, osd-notice, l10n, tdd]

# Dependency graph
requires:
  - phase: 04-error-feedback-settings
    plan: 01
    provides: "ErrorLogLocation.resolve 三层链 + configuredFailure、ErrorFeedbackSettings store、DelegatingDiagnosticLogEffect.dispose/activate 语义"
  - phase: 02-trusted-location-file-evidence
    provides: "ErrorLogFileSink 单写者 + drain、pending FIFO 容量 32 保序、hooks-first 启动契约"
provides:
  - "validateConfiguredDirectory 单层校验 API（ConfiguredDirectoryFailure 封闭枚举 + ConfiguredDirectoryValidation sealed 结果，唯一允许的 kernel 编辑第二段）"
  - "DiagnosticLogTarget 协调器单例：attach/activateResolved/validate/apply + effectiveLogPath / pendingFallbackNotice 两 notifier"
  - "安全重定向协议：全协调器唯一 _swapTo 通道，恒为 dispose→activate（activate→activate 静默失效路径被源码结构与保序测试共同封死）"
  - "DiagnosticFallbackNotice 通知桥 widget（D-04 第二通道，一次性 OSD）+ logFallbackNotice 双语 l10n key"
  - "组合根收敛：启动激活与路径重定向共用 activateResolved 唯一激活实现"
affects: [04-03-card-toggle, 04-04-settings-ui, SECURITY-t0113-0119-reaudit]

# Actuals (#2632) — chars/4 over the realized diff (1,091 insertions / 6 deletions across 11 files)
actuals:
  tokens: 10900
  tasks: 3
  commits: 7

# Tech tracking
tech-stack:
  added: []  # 零新包 —— dart:io / Flutter SDK / 既有依赖（T-04-02-SC accept 依据）
  patterns:
    - "校验即证明 sink 可用：形态拒绝矩阵先行 + 复用链层 create/probe 帮助函数收尾（无第二份探测实现）"
    - "resolve-before-dispose 换位协议：先确认新位置再 dispose，失败窗口归零；间隙记录由 delegate pending FIFO 保序补发"
    - "一次性通知语义：仅 null→值 转换、消费即清空、挂起不被覆盖"

key-files:
  created:
    - lib/ui/dialogs/settings/diagnostic_log_target.dart
    - test/diagnostics/diagnostic_log_target_test.dart
  modified:
    - lib/kernel/diagnostics/error_log_location.dart
    - lib/main.dart
    - lib/app.dart
    - lib/l10n/app_en.arb
    - lib/l10n/app_zh.arb
    - lib/l10n/app_localizations.dart
    - lib/l10n/app_localizations_en.dart
    - lib/l10n/app_localizations_zh.dart
    - test/diagnostics/error_log_location_test.dart

key-decisions:
  - "kernel 校验顺序：形态拒绝（notAbsolute/invalidCharacters/UNC/超长）先行，复用 04-01 的 _prepareTier 做 create+探测收尾——校验矩阵六类输入全覆盖且无第二份探测实现"
  - "UNC 拒绝（A3）与 1024 长度上界均文档化于 doc comment；上界为命名静态常量 maxConfiguredPathLength"
  - "apply 同目录幂等分支先于保存：无换位副作用、不触发持久化（计划 (a)/(b) 分支的显式化）"
  - "resolve 失败不 dispose（_applyDefaultChain 返回 Invalid 且旧 sink 继续服务）——resolve-before-dispose 消除失败窗口（RESEARCH Pattern 2 caveat 落实）"
  - "effectiveLogPath 为 UI 的权威有效路径来源，免疫 dispose 期间 delegate.logPath 的 null 闪烁；pendingFallbackNotice 仅 null→值 一次性置值"
  - "attach 移至 GlobalErrorHooks.install 之后、unawaited 激活之前——预存 hooks-first 契约测试锁定首个平台目录引用的源码顺序，计划字面时序（init 之前）与之冲突，契约优先"
  - "通知桥以 Positioned 包裹挂载 Stack 末尾——非 positioned 子节点会使 Stack（连同 Positioned.fill 的 Navigator）塌缩成 0x0 空屏"

requirements-completed: []  # 计划声明 SET-02；ready-ids 门判定见下（设置 UI 面属 04-04，未 mark-complete）

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "kernel 单层校验 validateConfiguredDirectory：合法/可创建深路径 → Valid；空/空白/相对 → notAbsolute；控制字符+null byte → invalidCharacters；UNC → uncPathUnsupported（A3）；超长 → pathTooLong（1024 常量）；file-occupied（errno 183 形态）与注入 probe 恒 false → notWritable 携带原始异常；注入 seam 生效"
    requirement: SET-02
    verification:
      - kind: unit
        ref: "test/diagnostics/error_log_location_test.dart#validateConfiguredDirectory 单层校验（11 用例）"
        status: pass
    human_judgment: false
  - id: D2
    description: "重定向协议：有效路径换位后旧文件恰含 pre-swap 全部记录、新文件收 post-swap 记录、双路径同步、D-03 校验通过即保存；dispose 间隙注入记录经 pending FIFO 补发到新文件且整体保序"
    requirement: SET-02
    verification:
      - kind: unit
        ref: "test/diagnostics/diagnostic_log_target_test.dart#valid retarget / gap flush（真实临时文件 + gate 化 writer）"
        status: pass
    human_judgment: false
  - id: D3
    description: "三不与存活：无效路径不保存/不换位/不通知且旧 sink 继续落盘；空串保存 '' 后经注入 provider 解析默认链并重定向；resolve 失败（exe 层被占据 + AS 抛出）不 dispose、旧文件可追加；同路径幂等无 dispose/activate 痕迹"
    requirement: SET-02
    verification:
      - kind: unit
        ref: "test/diagnostics/diagnostic_log_target_test.dart#invalid three-nos / empty-chain / unresolved no-dispose / idempotent（4 用例，logPath 变化监听取证）"
        status: pass
    human_judgment: false
  - id: D4
    description: "一次性回退通知 + 通知桥：activateResolved 携带 configuredFailure 置值一次、消费即清空、挂起不被覆盖；DiagnosticFallbackNotice 桥将通知经 l10n 送 OsdService 恰一次，无通知不触发 OSD"
    requirement: SET-02
    verification:
      - kind: widget
        ref: "test/diagnostics/diagnostic_log_target_test.dart#startup activation / notice bridge（3 用例，MaterialApp + zh locale）"
        status: pass
    human_judgment: false
  - id: D5
    description: "组合根收敛：main 不再直接构造 ErrorLogFileSink/activate；attach 同步先于任何激活；启动激活与 _swapTo 共用 activateResolved；hooks-first 启动契约（源码顺序门）保持绿"
    requirement: SET-02
    verification:
      - kind: unit
        ref: "test/diagnostics/global_error_hooks_test.dart#declares hooks-first diagnostic file startup ordering（预存契约测试，修正后通过）+ 全量门 1363 全绿"
        status: pass
    human_judgment: false
  - id: D6
    description: "实机 debug run：配置无效路径启动 → OSD「日志已回退到默认位置」出现恰一次不刷屏；设置页行内将显示 effectiveLogPath + 原因（数据源已就绪，行组件属 04-04）"
    verification: []
    human_judgment: true
    rationale: "OSD 可见性与一次性呈现无法在 headless 测试中证明（MEMORY: UAT 证据标准 —— 日志只覆盖非 UI 观察点）"

# Metrics
duration: 30min
completed: 2026-08-31
status: complete
---

# Phase 4 Plan 02: 日志路径校验与安全重定向协调器 Summary

**用户配置的日志目录先经 kernel 单层校验证明可写才被采用，变更经「先确认新位置 → dispose → activate」完成零丢失零乱序的安全换位，启动回退以一次性 OSD 告知——SET-02 的写入前校验、无效回退、sink 安全重建三件事全部落地。**

## Performance

- **Duration:** 30 min
- **Started:** 2026-08-31T15:34:08Z
- **Completed:** 2026-08-31T16:03:45Z
- **Tasks:** 3/3
- **Files:** 11（2 created + 9 modified）

## Accomplishments

- **kernel 单层校验 API（唯一允许的 kernel 编辑第二段，同一文件）**：`validateConfiguredDirectory` 六类输入矩阵全覆盖——合法/可创建深路径 → `ConfiguredDirectoryValid`；空/空白/相对 → `notAbsolute`；控制字符+null byte → `invalidCharacters`；UNC → `uncPathUnsupported`（A3 文档化）；超长 → `pathTooLong`（`maxConfiguredPathLength = 1024` 命名常量）；file-occupied（实测 errno 183 形态）与注入 probe 恒 false → `notWritable` 且原始异常 contained 随行。全程收窄捕获、绝不抛出。
- **DiagnosticLogTarget 协调器（UI 层单例，循 ErrorCaptureSnapshot.I 形态）**：`attach` / `activateResolved` / `validate` / `apply` 四段公共 API；全协调器仅 `_swapTo` 一处调用 dispose 且恒为 dispose→activate——**activate→activate 静默失效路径被源码结构封死**（RESEARCH Pitfall 2）。无效路径三不（不保存/不换位/不通知）、空串=回默认链、resolve 失败不 dispose（旧 sink 存活）、同路径幂等，全部由真实临时文件测试锁定。
- **间隙保序证明**：gate 化 writer 卡住旧 sink 的 drain，在 dispose 间隙经 `delegate.record` 注入记录——该记录出现在**新文件**（pending FIFO 容量 32 在 activate 时冲刷），旧文件完整保留换位前全部记录且顺序不变（SET-02「切换不损坏写入中记录」的自动化证明）。
- **D-04 双通道就绪**：`effectiveLogPath`（UI 权威有效路径，免疫 dispose null 闪烁）+ 类型化回退原因供 04-04 行内消费；`pendingFallbackNotice` 一次性置值（仅 null→值，挂起不被覆盖、消费即清空）经 `DiagnosticFallbackNotice` 桥送 `OsdService.show(l10n.logFallbackNotice)` 恰一次。通知桥以 `SizedBox.shrink` 零布局零 hit-test 挂载。
- **组合根收敛**：`main` 不再直接构造 `ErrorLogFileSink`/调用 `activate`——启动激活与用户改路径重定向共用 `activateResolved` 唯一激活实现（research 单一激活实现 caveat 落实）；hooks-first 启动契约测试保持绿。
- **kernel 红线保持**：kernel 改动仅 `error_log_location.dart`（`resolve` 三层链与 sealed 契约逐字保留）；reporter/单写者/delegate 语义零 diff；`kernel_logger_gate` GATE 1/2 PASS。

## Task Commits

1. **Task 1 RED**：configured directory 单层校验失败测试 —— `2a85a38a` (test)
2. **Task 1 GREEN**：kernel 校验 API + logFallbackNotice l10n —— `bfe3fc1e` (feat)
3. **Task 2 RED**：重定向协议失败测试 —— `35a92b7a` (test)
4. **Task 2 GREEN**：DiagnosticLogTarget 协调器 —— `d35c2e23` (feat)
5. **Task 3 RED**：启动激活 + 通知桥失败测试 —— `70d537f2` (test)
6. **Task 3 GREEN**：组合根接线 + 通知桥挂载 —— `aea1dccf` (feat)
7. **fix**：attach 移至 hooks 安装之后保住 hooks-first 契约 —— `f2287ad0` (fix)

## Files Created/Modified

- `lib/ui/dialogs/settings/diagnostic_log_target.dart`（NEW）— 协调器单例（attach/activateResolved/validate/apply + 两 notifier + 唯一 `_swapTo` 换位通道）+ `DiagnosticFallbackNotice` 通知桥 widget（监听 → post-frame → OsdService.show(l10n) → consume）
- `lib/kernel/diagnostics/error_log_location.dart`（MODIFY，唯一允许的 kernel 编辑）— `ConfiguredDirectoryFailure` 封闭枚举、`ConfiguredDirectoryValidation` sealed 结果、`validateConfiguredDirectory`、`maxConfiguredPathLength` 常量
- `lib/main.dart`（MODIFY）— `attach`（hooks 安装后、激活前同步）+ `_activateDiagnosticLog` 的 switch 收敛到 `activateResolved`；删除本地 sink 构造
- `lib/app.dart`（MODIFY）— `buildErrorCardMount` Stack 末尾以 Positioned 挂载通知桥（零布局占用）
- `lib/l10n/app_en.arb` / `app_zh.arb` + 三个生成文件（MODIFY）— `logFallbackNotice` 双语 key + `flutter gen-l10n` 产物入库
- `test/diagnostics/diagnostic_log_target_test.dart`（NEW）— 11 用例：重定向保序/间隙缓冲/三不/空串链/resolve 失败存活/幂等/一次性通知/启动激活/通知桥 widget
- `test/diagnostics/error_log_location_test.dart`（EXTEND）— 单层校验矩阵 11 用例

## Decisions Made

- **校验复用链层帮助函数**：`validateConfiguredDirectory` 直接复用 `_prepareTier`（create(recursive) + 探测），无第二份探测实现——「校验即证明 sink 可用」与链层语义完全一致（T-04-02-01 mitigate 落实）。
- **幂等分支先于保存**：apply 与当前有效落点同目录时直接返回 Valid——不保存、不换位、无副作用（计划 (a)/(b) 分支的显式化；store 不产生冗余持久化）。
- **通知仅 null→值**：挂起未消费时后到的失败不覆盖——避免通知刷屏，与 D-04「恰好一次」语义互锁。
- **`_applyDefaultChain` 未 attach 时折叠 typed Invalid**（不抛 `StateError`）——组合根编程错误也不伪造成功；生产路径 attach 先于 runApp，不可达。
- **契约测试优先于计划字面时序**：attach 携带 `getApplicationSupportDirectory` tear-off，按计划置于 `ErrorReporterImpl.init` 之前会违反预存 hooks-first 源码顺序契约——真实不变量（同步先于 runApp、先于任何激活）在 hooks 安装后位置全部保留，见 Deviations 2。

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] 通知桥直接作为 Stack 非 positioned 子节点会塌缩应用壳**
- **Found during:** Task 3 GREEN（实现时核对 Flutter Stack 布局语义）
- **Issue:** 计划字面指令「Stack 末尾追加 `const DiagnosticFallbackNotice()`（build 返回 SizedBox.shrink）」——Stack 一旦存在任何非 positioned 子节点，尺寸收缩为该子节点尺寸（0x0），令上方 `Positioned.fill` 的 Navigator 一并塌缩成空屏（app.dart doc comment 明文记录的 hit-test/布局边界契约）。
- **Fix:** 以 `const Positioned(left: 0, top: 0, child: DiagnosticFallbackNotice())` 挂载——positioned 子节点不参与 Stack 尺寸计算；零尺寸 SizedBox 无 hit-test 面，穿透语义不变，「零布局占用」验收标准原样满足。
- **Files modified:** lib/app.dart
- **Verification:** error_card_mount_position_test + error_card_host_test 17 用例全绿；全量门全绿
- **Commit:** aea1dccf

**2. [Rule 3 - Blocker] attach 时序与预存 hooks-first 契约测试冲突**
- **Found during:** Task 3 后全量门（`flutter test` 1362/1363，`global_error_hooks_test.dart` 源码顺序断言红）
- **Issue:** 该预存测试锁定「首个 `getApplicationSupportDirectory` 引用必须晚于 `GlobalErrorHooks.install`」（Phase 2 hooks-first 锁定决策：捕获安装先于任何平台路径接触）。计划的 attach 位置（`ErrorReporterImpl.init` 之前）让 provider tear-off 文本先于 hooks 安装，契约被违反。
- **Fix:** attach 移至 `GlobalErrorHooks.install` 之后、`unawaited(_activateDiagnosticLog)` 之前——计划的真实意图（协调器在任意激活与 UI 交互前就绪）全部保留，仅放弃与契约冲突的字面时序；位置约束写入源码注释。
- **Files modified:** lib/main.dart
- **Verification:** global_error_hooks_test 14/14 绿；全量门 `flutter test` 1363 全绿
- **Commit:** f2287ad0

**3. [Rule 1 - Bug] Task 2 RED 用例作者缺陷（GREEN 内修正）**
- **Found during:** Task 2 GREEN 首跑（12/14，2 红）
- **Issue:** (a) 间隙用例的 gate 化 writer 只挂起不落盘——旧文件永远等不到 pre-swap 内容；(b) 挂起通知用例经 `resetForTesting` 重绑，而该 seam 会清空 notifier——「不被覆盖」场景从未构造。
- **Fix:** writer 释放后真实 append 落盘；通知用例改经 `delegate.dispose()` 复位锁后二次 `activateResolved`（真实换位形态），不经 reset。
- **Files modified:** test/diagnostics/diagnostic_log_target_test.dart
- **Verification:** 14/14 绿
- **Commit:** d35c2e23（随 GREEN 一并入库）

**Total deviations:** 3（Rule 1 × 2，Rule 3 × 1——均已修复并锁定）
**Impact:** 无范围/接口影响；两处为计划字面指令与既有布局/契约事实的冲突消解，一处为测试作者缺陷。

## Issues Encountered

- 无阻断问题。预存 headless 基线（mdk.dll FFI / 状态机 security）本轮未复现——全量 `flutter test` 1363 例全绿（04-01 基线 1342 + 本计划新增 21，0 delta）。
- `flutter analyze` 61 条 info/warning 全部为未触碰文件的既有条目（与 04-01 基线同值），触碰文件 0 条、error 0 条。

## Next Phase Readiness

- **04-03（卡片开关）**：`ErrorFeedbackSettings.I.state` notifier 就绪（04-01）；本计划零接触 ErrorCardHost/snapshot——D-05 呈现层接缝未被触碰。
- **04-04（设置 UI）**：消费面全部就绪——`DiagnosticLogTarget.I.validate(directory)`（行内即时校验）、`apply(directory)`（防抖后提交）、`effectiveLogPath`（「当前有效路径」权威读数）、`pendingFallbackNotice`（一次性通知数据源）+ `logFallbackNotice` 双语文案。行组件按 04-PATTERNS 的 row grammar 实装即可。
- **T-01-13/19 重审**：本计划的写路径仍只产出诊断包纯文本；校验面新增的只是「拒绝更早」（UNC/控制字符/超长在探测前拦截）——threat register 的 mitigate/accept 维持，收账落盘在 Phase 收尾 04-SECURITY.md。
- **实机人工核对（headless 无法证明，04-VALIDATION Manual-Only 表）**：配置无效路径启动 → OSD「日志已回退到默认位置」出现恰一次不刷屏；设置页行内显示有效路径（04-04 落地后一并核对）。

---

*Plan: 04-02 · Wave 2 of 3 · Phase 4-错误反馈设置*
*Executed: 2026-08-31*

## Self-Check: PASSED

- 11 个创建/修改文件全部存在于工作区（2 created + 9 modified）
- 7 个 commit（2a85a38a / bfe3fc1e / 35a92b7a / d35c2e23 / 70d537f2 / aea1dccf / f2287ad0）均在 git 历史中
- 全量门：`flutter test` 1363 例全绿（0 delta）、`flutter analyze` 0 error（61 条既有 info 与 04-01 基线同值）、`kernel_logger_gate` GATE 1/2 PASS
