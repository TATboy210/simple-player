---
phase: 04-error-feedback-settings
plan: 05
subsystem: diagnostics
tags: [gap-closure, g-04-1, path-config-removal, two-tier-chain, d-07, l10n-cleanup, tdd]

# Dependency graph
requires:
  - phase: 04-error-feedback-settings
    plan: 01
    provides: "ErrorFeedbackSettings store（开关持久化/WR-06 双层回退）+ error_log_location 位置链"
  - phase: 04-error-feedback-settings
    plan: 02
    provides: "DiagnosticLogTarget 协调器 + DelegatingDiagnosticLogEffect 激活缝"
  - phase: 04-error-feedback-settings
    plan: 04
    provides: "通用 tab 开关行 + 路径行 UI 与 widget 测试真实 I/O 协议（本计划收窄其路径行面）"
provides:
  - "双层日志落点链（exe 根 logs/error.log 优先 → Application Support logs/ 静默回退）——无任何用户可配置入口"
  - "两键 settings.json 形态（version + errorCardEnabled）+ 旧文件第三键静默忽略的向后兼容语义"
  - "仅启动激活的最小协调器（attach + 单参数 activateResolved 唯一激活实现）"
  - "设置域 l10n 收窄为唯一开关行键 errorCardToggleLabel"
affects: [VERIFY-phase4-manual-items]

# Actuals (#2632) — chars/4 over the realized diff (≈2087 changed lines across 16 file-touches)
actuals:
  tokens: 23500
  tasks: 3
  commits: 3

# Tech tracking
tech-stack:
  added: []  # 零新增依赖 —— 目录选择插件依赖保留给既有功能，pubspec 零 diff
  patterns:
    - "纯移除收窄：保留 API 的封闭原因集整体保留（validateConfiguredDirectory 的返回词汇表，store 探测复用不可删，per D-07 第 3 条）"
    - "FakeAsync zone 跨用例链头陷阱：单例内 Future 链跨 widget 测试存活时，后继用例 zone 注册的监听器排入已销毁 zone 队列永不执行——resetForTesting 须重建测试期链"

key-files:
  created: []
  modified:
    - lib/kernel/diagnostics/error_log_location.dart
    - lib/ui/dialogs/settings/error_feedback_settings.dart
    - lib/ui/dialogs/settings/diagnostic_log_target.dart
    - lib/ui/dialogs/settings/general_settings_content.dart
    - lib/main.dart
    - lib/app.dart
    - lib/l10n/app_en.arb
    - lib/l10n/app_zh.arb
    - lib/l10n/app_localizations.dart
    - lib/l10n/app_localizations_en.dart
    - lib/l10n/app_localizations_zh.dart
    - test/diagnostics/error_log_location_test.dart
    - test/diagnostics/error_feedback_settings_store_test.dart
    - test/diagnostics/diagnostic_log_target_test.dart
    - test/widget/dialogs/general_settings_content_test.dart
  deletions:
    - "lib/ui/dialogs/settings/diagnostic_log_target.dart 内 DiagnosticFallbackNotice 通知桥 widget 族（整类 + State，随文件收窄删除）"
    - "协调器运行时重定向协议全体（apply/_applyNow/_applyDefaultChain/_swapTo/validate/_logFileIn/串行队列）与两个 UI 读数 notifier"

key-decisions:
  - "activateResolved 保留命名形参 {required File file}（计划「单参数」的最低破坏形态）——Task 1 用例与既有测试调用形态不变，RED/GREEN 编译两侧兼容"
  - "attach 签名不变但只存 effect：provider 形参保留组合根调用形态，落点解析收敛到 main 的 resolve 链（触碰文件 0 analyze 条目要求排除未用私有字段）"
  - "resetForTesting 增补串行持久化链重建（测试专用路径，生产行为零变化）：单例 _persistFuture 创建于上一用例 FakeAsync zone，跨用例 .then 续体排入死 zone 队列永不执行——实测下一用例写入永不落盘，探针实证后修复"
  - "损坏矩阵第三键错型用例按计划意图落地为『新增』而非『改写』：现有五用例无一引用第三键，删除任一用例都会丢失既有证明（开关错型回退默认值）——五用例逐字保留 + 追加残留第三键向后兼容用例"

requirements-completed: [SET-02]  # 修订语义（路径配置移除）的代码与测试事实落地；SET-02 已在 REQUIREMENTS.md 关账

# Coverage metadata (#1602)
coverage:
  - id: G1
    description: "通用 tab 仅渲染开关行：文本输入框/浏览按钮（ValueKey settings-log-path-browse）/校验状态文案/有效路径行全部 findsNothing；开关翻转置 store 并持久化"
    requirement: SET-02
    verification:
      - kind: widget
        ref: "test/widget/dialogs/general_settings_content_test.dart#general tab renders the toggle row only（G-04-1 absence 用例，UAT Test 3/5 作废项的自动化对应面）"
        status: pass
    human_judgment: false
  - id: G2
    description: "settings.json 两键形态：store 自写盘解码后 JSON 恰为 {version, errorCardEnabled}；旧三键文件残留第三键被 load 静默忽略且开关正常装载"
    requirement: SET-02
    verification:
      - kind: unit
        ref: "test/diagnostics/error_feedback_settings_store_test.dart#两键 settings.json…（tracer）+ #残留第三键…被静默忽略"
        status: pass
    human_judgment: false
  - id: G3
    description: "双层链：注入 exe/AS provider 时 exe 根 logs/error.log 胜出、exe 层不可写回退 AS、全败降级 Unavailable 不抛出；断言不引用已删除的回退原因字段"
    requirement: SET-02
    verification:
      - kind: unit
        ref: "test/diagnostics/error_log_location_test.dart#双层回退链组三用例 + tracer 双层落点断言"
        status: pass
    human_judgment: false
  - id: G4
    description: "启动激活唯一实现：attach → 单参数 activateResolved 后 delegate.logPath == 注入文件；运行时重定向协议与通知桥零残留（grep 门 = 0）"
    requirement: SET-02
    verification:
      - kind: unit
        ref: "test/diagnostics/diagnostic_log_target_test.dart#attach → single-parameter activateResolved… + Task 2 grep 门（lib/ 被移除符号计数 0）"
        status: pass
    human_judgment: false
  - id: G5
    description: "保留面回归：WR-05 串行链/唯一 tmp/原子写四级降级、WR-06 两层回退两用例、校验矩阵 11 用例、host 门控与 settings_dialog 既有套件全绿；reporter/单写者/delegate/pubspec 零 diff"
    requirement: SET-02
    verification:
      - kind: other
        ref: "flutter test 全量 1363 例 0 失败 + git diff 6d7a6972 红线五文件为空 + kernel diff 仅 error_log_location.dart"
        status: pass
    human_judgment: false

# Metrics
duration: 42min
completed: 2026-09-01
status: complete
---

# Phase 4 Plan 05: G-04-1 日志路径配置移除（D-07 双层链收口）Summary

**日志路径配置功能按 D-07 整体移除：通用 tab 只剩错误卡片开关行，日志固定落 exe 根 logs/error.log（Application Support 静默回退的双层链），settings.json 收窄为两键且旧文件第三键向后兼容，D-04 通知桥与运行时重定向协议不复存在——UAT Test 3/5 作废项获得自动化对应面，G-04-1 关账。**

## Performance

- **Duration:** 42 min（含跨用例 FakeAsync 死链的三轮探针定位 ~15 min）
- **Started:** 2026-09-01T01:01:38Z
- **Completed:** 2026-09-01T01:44:36Z
- **Tasks:** 3/3（Task 1 RED commit + Task 2 GREEN commit + Task 3 l10n commit）
- **Files:** 15（0 created + 15 modified，含 2 处文件内整块删除）

## Accomplishments

- **Task 1（测试面收窄，RED）**：四个测试文件收窄到目标形态——通用内容套件删九个路径行用例、新增 G-04-1 absence 用例；位置套件删配置层两组（三层链组四个配置用例 + 启动配置层校验契约整组）、双层用例改写后断言不再引用 configuredFailure、校验矩阵 11 用例逐字保留并改组描述；store 套件 tracer 改写为两键 round-trip + 双层落点 + sink 纵切；协调器套件删重定向协议七用例与通知桥组、保留单条启动激活用例。RED 形态精确成立：**恰好 2 条新断言失败**（absence 用例发现旧代码渲染 TextField；store 旧实现写出第三键 `logDirectory`），其余全过，零编译错误，零生产改动。
- **Task 2（生产面移除，GREEN）**：六文件编译原子一次完成——kernel resolve 链收窄双层（删除配置层分支与 configuredFailure 字段，validateConfiguredDirectory/封闭原因集/探测 seam 逐字保留）；store 单偏好化（两键 _encode、未知键静默忽略注释化）；协调器收窄为 attach + 单参数 activateResolved + resetForTesting 三方法；通用内容仅剩开关行（_SettingsRow 与 Switch activeThumbColor 细节逐字不动）；main.dart 保持 load → resolve → activateResolved 启动链与 hooks-first 顺序逐字；app.dart 摘除通知桥 Positioned 子树恢复卡片挂载原貌。GREEN 后四套件 + player 宿主套件全绿。
- **Task 3（l10n + 全门禁）**：en/zh 双语 10 键移除（通知桥文案 1 + 路径行文案 9，@key 随删），`flutter gen-l10n` 三产物再生成入库（生成文件零手编）；全量门禁四绿——analyze 0 error（60 条 info 与执行起点基线同值）、全量 test 1363 例 0 失败、kernel_logger_gate GATE 1/2 PASS、红线 diff 审计为空。

## Task Commits

1. **Task 1 RED**：测试面收窄到目标形态 —— `4bca3128` (test)，4 files，+113/−916
2. **Task 2 GREEN**：生产面移除（六文件编译原子 + widget 测试 GREEN 侧修正）—— `133438d0` (feat)，7 files，+118/−758
3. **Task 3 l10n**：设置域 10 键移除 + 三产物再生成 —— `0d908c89` (feat)，5 files，+2/−180

## Files Created/Modified

- `lib/kernel/diagnostics/error_log_location.dart`（MODIFY）— 双层 resolve；删 configuredDirectory 入参 / configuredFailure 字段 / 透传管道；保留 validateConfiguredDirectory（形参改名 directory 以满足零残留 grep 门，API 不变）、封闭原因集、sealed 结果类、_prepareTier、默认探测、provider typedef、常量
- `lib/ui/dialogs/settings/error_feedback_settings.dart`（MODIFY）— 单偏好数据类（==/hashCode 按剩余字段重算）、两键 _encode、删 setLogDirectory 与 load 的目录分支；resetForTesting 增补持久化链重建（见 Deviations 3）
- `lib/ui/dialogs/settings/diagnostic_log_target.dart`（MODIFY）— 收窄为 attach / activateResolved({required File file}) / resetForTesting 三方法；删重定向协议全体、两个 UI 读数 notifier、DiagnosticFallbackNotice 通知桥族；import 面随符号面收窄
- `lib/ui/dialogs/settings/general_settings_content.dart`（MODIFY）— 仅开关行；删路径行区块、防抖/提交链、浏览网关、行内状态族、有效路径行、_fellBack、_BrowseButton 与两个注入构造参数
- `lib/main.dart`（MODIFY）— resolve 移除配置目录实参、switch 解构移除 configuredFailure、activateResolved 单参调用；hooks-first 顺序与 unawaited 纪律逐字不动
- `lib/app.dart`（MODIFY）— 删通知桥 Positioned 子树与 import；Stack 恢复卡片挂载原貌（Positioned.fill + 双 mode 分支逐字）
- `lib/l10n/app_en.arb` / `app_zh.arb`（MODIFY）— 设置域仅剩 errorCardToggleLabel
- `lib/l10n/app_localizations.dart` / `_en.dart` / `_zh.dart`（MODIFY）— gen-l10n 再生成（死 getter 清零）
- `test/diagnostics/error_log_location_test.dart`（MODIFY）— 27→19 用例：删配置层两组，双层三用例 + 校验矩阵 11 用例 + 契约翻转用例（逐字保留、组名改双层表述）
- `test/diagnostics/error_feedback_settings_store_test.dart`（MODIFY）— tracer 两键 round-trip + 双层纵切改写；损坏矩阵 5 保留 + 残留第三键用例新增；加固四用例开关字段驱动；WR-06 逐字保留
- `test/diagnostics/diagnostic_log_target_test.dart`（MODIFY）— 12→1 用例：单条启动激活用例（attach → 单参数 activateResolved → delegate 落点一致）
- `test/widget/dialogs/general_settings_content_test.dart`（MODIFY）— 10→2 用例：开关行持久化（逐字继承 + 收尾排空链）+ G-04-1 absence 用例

## Decisions Made

- **activateResolved 形参形态**：保留命名形参 `{required File file}` 实现「签名收窄为仅 file 形参」——比改位置参数少破坏所有既有调用点（RED 用例须在旧代码下编译，GREEN 后不得再改测试）。
- **attach 保签名、删存储**：provider 形参保留（main.dart 调用形态与 hooks-first 顺序逐字不动的要求），body 只存 effect——未用私有字段会触发 analyzer unused_field 条目，触碰文件 0 条目门要求字段一并移除。
- **参数名 configuredDirectory → directory**：validateConfiguredDirectory 的形参名与被移除符号同名（子串级 grep 冲突），改名单不 API（位置参数、闭集、语义均不变），使 Task 2 done 的零残留计数门与保留符号正门同时成立。
- **测试 harness 裁剪口径**：通用内容套件的协调器重绑从 `resetForTesting(effect, as, exe)` 收窄为 `resetForTesting(effect)`（旧代码可选形参可省，两侧编译兼容）；store seam 与 activateResolved(file:) 逐字保留。

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] G-04-1 absence 用例首版在 runAsync 内直接 await pendingPersist —— FakeAsync 微任务饥饿死锁**
- **Found during:** Task 2 GREEN 首跑（用例 10 分钟超时）
- **Issue:** 计划 Task 1 措辞「沿用 pendingPersist 等待点惯例」在 widget 测试语境不可行：persist 链续体驻留 fake-zone 微任务队列，`runAsync(() => pendingPersist)` 内永不被冲刷——正是 04-04 沉淀的「body 禁 await 真实 I/O」陷阱族（本计划的 context 文件明载该协议）。
- **Fix:** 等待条件改锚定 settings.json 落盘（pumpUntil 存在性 + runAsync 读内容），与同文件开关行用例同一协议；计划意图（可等待持久化）完整保留。
- **Files modified:** test/widget/dialogs/general_settings_content_test.dart
- **Verification:** 用例 2 秒内全绿（修复前 10 分钟超时）
- **Commit:** 133438d0

**2. [Rule 1 - Bug] 开关行用例收尾未排空持久化链 + 单例链跨用例存活 —— 下一用例写入永不落盘**
- **Found during:** Task 2 GREEN（absence 用例单独跑绿、跟在开关行用例后必挂；三轮 print 探针实证）
- **Issue:** 开关行用例结束于第二次翻转，`_persistFuture` 链头 Future 创建于该用例的 FakeAsync zone；下一用例 tap 时 `.then` 续体被排入**已销毁 zone** 的队列永不执行——探针显示 `_schedulePersist` 被调用、`_persist` 从未启动、根目录连 tmp 都不出现。04-04 未踩中是因为其后继用例只断言 store 内存态与 effectiveLogPath，从不等 settings.json 文件。
- **Fix:** 双层修复：(a) 开关行用例收尾以 `pendingPersist.whenComplete` 旗标 + pump/runAsync 交替排空本用例全部写入（防残留写落在下一用例重绑 seam 上污染内容）；(b) `resetForTesting` 增补 `_persistFuture = Future<void>.value()`——测试专用路径，链重建于当前 zone（生产行为零变化，生产无 zone 切换）。计划将 resetForTesting 列为「逐字保留」，本改动是对其**测试隔离完备性**的缺陷修复而非行为变更，探针实证修复前后生产路径不受影响。
- **Files modified:** test/widget/dialogs/general_settings_content_test.dart + lib/ui/dialogs/settings/error_feedback_settings.dart
- **Verification:** 两用例顺序跑全绿；探针显示 persist 在第二用例正常启动并落盘
- **Commit:** 133438d0

**3. [Rule 2 - Missing coverage] 损坏矩阵「第三键错型改写」落地为「新增」用例**
- **Found during:** Task 1 RED（计划与实际文件形态不符）
- **Issue:** 计划称损坏矩阵五用例中「第三键错型用例」改写为未知键静默忽略——实际矩阵五用例（缺文件/空串/尾随垃圾/List 形状/开关错型）无一引用第三键；若按字面改写任一用例都会丢失既有证明（如开关错型回退默认值的逐字段校验证明）。
- **Fix:** 五用例逐字保留 + 新增「残留第三键（旧 logDirectory）被静默忽略且开关字段正常装载」用例（fixture 用真实旧键名 `logDirectory` + 错型值 123，旧代码与新代码均绿——恰好向后兼容语义的 RED-safe 表达）。矩阵 5→6 用例。
- **Files modified:** test/diagnostics/error_feedback_settings_store_test.dart
- **Verification:** 用例在 Task 1 RED 轮即绿（非新增失败）；GREEN 后保持绿
- **Commit:** 4bca3128

**4. [Rule 1 - Bug] validateConfiguredDirectory 形参名与被移除符号同名（grep 门冲突）**
- **Found during:** Task 2 done 门复核
- **Issue:** 计划零残留门 `grep "…configuredDirectory…" lib/ | wc -l == 0` 与保留门 `validateConfiguredDirectory ≥ 1` 互相冲突——保留函数的形参名字面含被移除符号。
- **Fix:** 形参改名 directory（内部局部 candidate 配套），API 签名/语义/测试调用点零变化。
- **Files modified:** lib/kernel/diagnostics/error_log_location.dart
- **Verification:** 两门同过（0 残留 + 保留计数 3/3/9/1）
- **Commit:** 133438d0

### 契约翻转用例处置说明（计划执行上下文点名项）

04-01 的契约翻转用例（kernel 不直接读进程位置、exe 层只经注入到达）为**逐字保留**，仅组/用例措辞中的「三层」表述同步改「双层」——非计划正文的「改写」语义；同文件既有组描述「SET-02 采用面」改「内部可写探测契约（store 双层回退复用）」按计划执行。

**Total deviations:** 4（Rule 1 × 3，Rule 2 × 1——全部修复并锁定，均有探针/门禁证据）
**Impact:** 无范围/接口影响；两处为测试基础设施缺陷修复（FakeAsync zone 家族，沉淀为可复用纪律），一处为计划-实况错配的保真落地，一处为 grep 门自洽性修正；修复后全量门禁四绿。

## Issues Encountered

- 无阻断问题。预存 headless 基线（mdk.dll FFI / 状态机 security）未复现——全量 1363 例 0 失败。
- **测试计数基线漂移（非本计划引入）**：计划以 1377 为基线，执行起点实测 1389（04-04 收口后其他提交的自然增长）；本计划净删除 26 例（widget −8 / location −8 / coordinator −11 / store +1）→ 终态 1363，「0 delta 门」按「无新增失败」口径满足。
- **analyze info 基线漂移（非本计划引入）**：计划记 61 条 info 基线，执行起点实测 60 条；本计划全程维持 60 条与起点同值，触碰文件 0 条目。

## Next Phase Readiness

- **G-04-1 关账证据齐备**：UAT gap 卡四条 missing 项全部落地——① 路径行 UI/logDirectory 字段/关联测试移除（absence 用例 + 零残留 grep 门）；② resolve 链双层收窄 + 启动激活接线保持（双层三用例 + main.dart activateResolved 正门）；③ D-04 通知桥移除（DiagnosticFallbackNotice 零残留）；④ 受影响测试收窄（契约翻转用例逐字保留 + 双层断言）。
- **/gsd-verify-work 移交**：UAT Tests 1/2/4/6（实机开关切换、重启持久化、MSIX ACL 冒烟、快速开关）保持 pending，实机复核时 Test 3/5 按已作废口径跳过；开关行实机呈现与两键 settings.json 落盘位置（exe 旁 / AS 回退层）可在同轮冒烟覆盖。
- **T-01-13/19 口径维持**：纯移除、零新增 retained 串 sink，写路径仍只产出诊断包纯文本；红线五文件零 diff 证明 reporter/单写者语义零接触，收账落盘随 Phase 收尾 04-SECURITY.md。

---

*Plan: 04-05 · Wave 2 · Phase 4-错误反馈设置（gap closure G-04-1）*
*Executed: 2026-09-01*

## Self-Check: PASSED

- 15 个修改文件全部存在于工作区（0 created + 15 modified）；DiagnosticFallbackNotice 通知桥与重定向协议符号在 lib/ 零残留（grep 计数 0）
- 3 个任务 commit（4bca3128 / 133438d0 / 0d908c89）均在 git 历史中，且 4bca3128（RED）先于 133438d0（GREEN）满足 TDD gate 顺序
- 全量门：`flutter test` 1363 例 0 失败（exit 0）、`flutter analyze` 0 error（60 info 与执行起点同值）、`kernel_logger_gate` GATE 1/2 PASS
- 保留门：validateConfiguredDirectory 在 kernel/store 各 ≥1、errorCardEnabled ≥3、activateResolved 在 main.dart ≥1；settings.json 两键 round-trip 由 tracer 用例锁定
- 红线证明：`git diff 6d7a6972` 对 reporter/error_capture_snapshot/error_reporting_dependencies/error_log_file_sink/diagnostic_pack_formatter 五文件为空、lib/kernel/ 内仅 error_log_location.dart、pubspec.yaml/pubspec.lock 零改动（预存脏文件全程未触碰、未入库）
