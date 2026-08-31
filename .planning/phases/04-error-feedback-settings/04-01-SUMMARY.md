---
phase: 04-error-feedback-settings
plan: 01
subsystem: diagnostics
tags: [settings-persistence, portable-json, dart-io, value-notifier, error-diagnostics, location-chain, tdd]

# Dependency graph
requires:
  - phase: 02-trusted-location-file-evidence
    provides: "ErrorLogLocation sealed Result + provider seam、ErrorLogFileSink 单写者、DelegatingDiagnosticLogEffect activate/dispose 语义"
  - phase: 03-playback-error-card-bridge
    provides: "ErrorCaptureSnapshot effects 缝与单例形态（store 单例循此惯例）"
provides:
  - "ErrorFeedbackSettings 便携 settings.json store（UI 层单例 + ValueNotifier + 注入文件 seam + 静默回退）"
  - "ErrorLogLocation.resolve 三层回退链（配置目录 → exe 根 logs/ → Application Support logs/）+ 微秒时间戳临时文件探测 + configuredFailure 回退原因"
  - "组合根接线：_activateDiagnosticLog 内 load 先于 resolve（unawaited 路径内，不阻塞启动）"
  - "原子写持久化（tmp+rename + 四级降级链 + 保存失败吞没）"
  - "test/diagnostics 两份测试文件：tracer 端到端纵切 + 损坏矩阵 + 链序/跳层/降级矩阵"
affects: [04-02-retarget-coordinator, 04-03-card-toggle, 04-04-settings-ui, SECURITY-t0113-0119-reaudit]

# Actuals (#2632) — chars/4 over the realized diff (40,874 bytes across 5 files)
actuals:
  tokens: 10218
  tasks: 2
  commits: 4

# Tech tracking
tech-stack:
  added: []  # 零新包 —— dart:io/dart:convert SDK 能力 + 既有依赖（T-04-01-SC accept 依据）
  patterns:
    - "三层回退链 + 逐层 create/探测 + typed Unavailable 降级（kernel 单点扩展）"
    - "便携 JSON 设置存储：扁平 key + version 字段、is! Map 形状守卫、逐字段类型回退"
    - "原子写：tmp(flush) → rename replace-on-existing + 四级降级（rename→重试→删后 rename→直写）"

key-files:
  created:
    - lib/ui/dialogs/settings/error_feedback_settings.dart
    - test/diagnostics/error_feedback_settings_store_test.dart
  modified:
    - lib/kernel/diagnostics/error_log_location.dart
    - lib/main.dart
    - test/diagnostics/error_log_location_test.dart

key-decisions:
  - "D-02 修订落地（取代 STATE.md Phase-02 D-03）：默认日志位置 = exe 根 logs/error.log，Application Support 降为最后回退层；旧 AS 日志不迁移（零迁移代码，原地作历史存档）"
  - "配置层胜出时 file 直接位于配置目录下（<configured>/error.log），exe/AS 层保持 <base>/logs/error.log 形态"
  - "settings.json schema：{version, errorCardEnabled, logDirectory}，'' = 走默认链；回退原因不持久化，每次启动重算（research Open Question 1/2 采纳）"
  - "store 放 UI 层（lib/ui/dialogs/settings/）—— main.dart:20 导入 UI 层文件的既有先例为合法性依据；kernel 编辑仅限 error_log_location.dart"
  - "ErrorFeedbackSettingsData 提供值相等（==/hashCode），损坏回退后的默认快照与初始态可比"

patterns-established:
  - "Pattern: tracer 端到端纵切 —— 真实临时 settings.json 经 load 驱动注入式三层链解析出落点，ErrorLogFileSink 激活后诊断包在配置目录可读（store→链→sink→磁盘全链贯通证明）"
  - "Pattern: 损坏输入矩阵测试 —— 缺失/空串/尾随垃圾/List 形状/错型字段五形态全部静默回退默认值"
  - "Pattern: pendingPersist 测试等待点 —— fire-and-forget 持久化经 @visibleForTesting getter 可等待，无生产分支差异"

requirements-completed: [SET-02, SET-03]  # 计划声明的贡献需求；#2388 ready-ids 门判 0/2 ready（SET-02 的 UI/重定向协调器在 04-02/04-04），故本轮未 mark-complete

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "三层位置链：配置目录 → exe 根 logs/ → Application Support logs/，逐层 create + 临时文件探测，首个可写层胜出；跳层携带 configuredFailure；全败返回 Unavailable 不抛出"
    requirement: SET-02
    verification:
      - kind: unit
        ref: "test/diagnostics/error_log_location_test.dart（链优先级/空配置跳层/探测失败回退/file-occupied 跳层/双全败降级，7 用例）"
        status: pass
    human_judgment: false
  - id: D2
    description: "便携 settings.json store：形状校验 load（is! Map 守卫 + 逐字段类型检查）+ 五种损坏输入静默回退默认值（D-01）"
    requirement: SET-03
    verification:
      - kind: unit
        ref: "test/diagnostics/error_feedback_settings_store_test.dart（损坏矩阵 5 用例）"
        status: pass
    human_judgment: false
  - id: D3
    description: "tracer 端到端：真实 settings.json 的 logDirectory 经 load → 三层链 → ErrorLogFileSink 激活，诊断包内容落在配置目录（全链贯通）"
    requirement: SET-02
    verification:
      - kind: integration
        ref: "test/diagnostics/error_feedback_settings_store_test.dart#tracer 端到端纵切（真实临时文件 + ErrorReporterImpl.forTesting）"
        status: pass
    human_judgment: false
  - id: D4
    description: "存储层生产加固：原子写（tmp+rename，无 .tmp 残留）+ 四级降级链 + 保存失败静默（state 不回滚）+ round-trip 重启模拟"
    requirement: SET-03
    verification:
      - kind: unit
        ref: "test/diagnostics/error_feedback_settings_store_test.dart（生产加固组 4 用例）"
        status: pass
    human_judgment: false
  - id: D5
    description: "契约翻转：kernel 不直接读进程位置（源码内省：无 Directory.current / resolvedExecutable 字面量），exe 层只经注入 provider 到达"
    requirement: SET-02
    verification:
      - kind: unit
        ref: "test/diagnostics/error_log_location_test.dart#never reads process locations directly - the executable tier is injected"
        status: pass
    human_judgment: false
  - id: D6
    description: "组合根接线：_activateDiagnosticLog 内 load 先于 resolve、注入 exe 目录与 configuredDirectory，均在 unawaited 路径内（不阻塞 MediaKit/window/runApp）"
    verification:
      - kind: other
        ref: "lib/main.dart:125 源码指认 + 全量门（flutter analyze 0 error / 1342 tests 全绿证明编译与集成面完好）"
        status: pass
    human_judgment: false
  - id: D7
    description: "实机 debug run：settings.json 出现在项目目录旁；日志落点为 exe 根 logs/error.log（build 目录，gitignored 属预期）"
    verification: []
    human_judgment: true
    rationale: "窗口可见性与真实 exe 邻近目录落盘无法在 headless 测试中证明（MEMORY: UAT 证据标准 —— 日志只覆盖非 UI 观察点）"

# Metrics
duration: 17min
completed: 2026-08-31
status: complete
---

# Phase 4 Plan 01: 错误反馈设置地基层（tracer 纵切）Summary

**settings.json（便携 JSON）经 load 驱动三层位置链（配置目录 → exe 根 → Application Support）解析出首个可写落点并完成 sink 激活，诊断包当次启动即落在配置目录；存储层加固到生产级（原子写 + 四级降级 + 保存失败静默 + 重启 round-trip）。**

## Performance

- **Duration:** 17 min
- **Started:** 2026-08-31T15:06:06Z
- **Completed:** 2026-08-31T15:23:00Z
- **Tasks:** 2/2
- **Files modified:** 5（2 created + 3 modified）

## Accomplishments

- **tracer 端到端纵切贯通**：真实临时 settings.json → `ErrorFeedbackSettings.I.load()` → `ErrorLogLocation.resolve(三层)` → `ErrorLogFileSink` 激活 → 诊断包落盘在配置目录——一条自动化测试证明 store→链→sink→磁盘全链可达，配置路径当次启动即生效（RESEARCH Pitfall 7 不存在）。
- **三层回退链落地（D-02 修订）**：配置目录 → exe 根 `logs/` → Application Support `logs/`，逐层幂等 `create(recursive)` + 微秒时间戳临时文件探测；配置层失败自动跳层并在 `ErrorLogLocationResolved.configuredFailure` 携带回退原因（D-04 行内呈现的数据源）；全败返回既有 `ErrorLogLocationUnavailable` 降级态，绝不抛出。
- **便携设置存储（D-01）**：UI 层单例 store + `ValueNotifier` + 注入文件 seam；形状校验 load（`is! Map` 守卫承重 + 逐字段类型回退）对缺失/空串/尾随垃圾/List 形状/错型字段五形态全部静默回退默认值。
- **存储层生产加固（SET-03）**：原子写 `settings.json.tmp(flush)` → `rename`（replace-on-existing）+ 四级降级链（rename→重试→删后 rename→直写，每级收窄 `on FileSystemException`）+ 保存失败静默（内存态不回滚）+ 双实例 round-trip 重启模拟。
- **kernel 红线保持**：kernel 改动仅 `error_log_location.dart`（sealed 契约与 `logs/error.log` 常量逐字保留）；reporter/单写者/delegate 语义零 diff；`kernel_logger_gate` GATE 1/2 PASS。

## Task Commits

1. **Task 1 RED**：settings store + 三层链失败测试 —— `9f525333` (test)
2. **Task 1 GREEN**：settings.json 贯通三层位置链 —— `30d5482b` (feat)
3. **Task 2 RED**：原子写 + round-trip 失败测试 —— `eebd9d36` (test)
4. **Task 2 GREEN**：存储层生产加固 —— `7f20ddc8` (feat)

_Note: 两个 TDD 任务均走 RED→GREEN 双 commit；tracer verify 已重跑通过（⚡ Tracer verified end-to-end）。_

## Files Created/Modified

- `lib/ui/dialogs/settings/error_feedback_settings.dart`（NEW）— 便携 JSON 设置 store：`ErrorFeedbackSettingsData` 不可变数据（值相等）+ `ErrorFeedbackSettings` 单例/forTesting + `load()` 形状校验 + setter fire-and-forget 持久化 + `pendingPersist` 测试等待点 + `resetForTesting`
- `lib/kernel/diagnostics/error_log_location.dart`（MODIFY，唯一允许的 kernel 编辑）— `ExecutableDirectoryProvider`/`WritableDirectoryProbe` typedef、resolve 三层链 + `_prepareTier`/`_probeDirectoryWritable` 私有共享帮助函数、`configuredFailure` 可选字段
- `lib/main.dart`（MODIFY）— `_activateDiagnosticLog` 内 load 先于 resolve；组合根注入 exe 目录 provider 与 configuredDirectory
- `test/diagnostics/error_feedback_settings_store_test.dart`（NEW）— tracer 端到端 + 损坏矩阵 + 生产加固组（10 用例）
- `test/diagnostics/error_log_location_test.dart`（EXTEND）— 链序/跳层/回退原因/双降级矩阵（+7 用例）+ 契约翻转用例

## Decisions Made

- **配置层文件形态**：配置层胜出时 `error.log` 直接位于配置目录下（`<configured>/error.log`），exe/AS 层保持 `<base>/logs/error.log`——用户配置的是「日志输出目录」本身，行为规格「file 位于配置目录下」逐字满足。
- **`ErrorFeedbackSettingsData` 值相等**：执行中发现按引用比较会让「错型字段回退」用例误报（回退快照与初始态是不同实例）——不可变数据类补 `==`/`hashCode`（Rule 1 修正，见 Deviations）。
- **requirements 未 mark-complete**：`requirements.ready-ids` 判 0/2 ready（SET-02 的重定向协调器/设置 UI 属 04-02/04-04）——按 #2388 共享 ID 门跳过 mark-complete，留待后续计划推进。
- **probe 失败的证据形态**：探测失败层构造 `FileSystemException('writability probe failed')` 作为该层失败证据，与真实异常对象同等可携带于 `configuredFailure`。

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] ErrorFeedbackSettingsData 缺少值相等导致损坏回退用例误报**
- **Found during:** Task 1 GREEN（首次跑测试，17/18 过）
- **Issue:** `expect(state.value, const ErrorFeedbackSettingsData())` 按引用比较——前四种损坏输入因 load 提前 return 未重赋值而「碰巧」通过，错型字段场景 load 重赋了新实例 → 身份不等 → 误报失败。暴露数据类缺少 `==`/`hashCode` 契约。
- **Fix:** 补 `==`/`hashCode`（`Object.hash`），五个损坏用例全部转为真实的值相等断言。
- **Files modified:** lib/ui/dialogs/settings/error_feedback_settings.dart
- **Verification:** 18/18 全绿（flutter test focused）
- **Commit:** 30d5482b

**Total deviations:** 1（Rule 1，已修复并锁定）
**Impact:** 无范围/接口影响；数据类值相等是计划隐含契约的显式化。

## Issues Encountered

- 无阻断问题。预存 headless 基线（mdk.dll FFI / 状态机 security）本轮未复现失败——全量 `flutter test` 1342 例全绿，0 delta。
- `flutter analyze` 61 条 info/warning 全部位于本计划未触碰的既有文件（player_video_controls.dart 等，out of scope），触碰文件 0 条、error 0 条。

## Next Phase Readiness

- **04-02（重定向协调器）**：`ErrorLogLocation.resolve` 三层签名与 `configuredFailure` 已就位；`DelegatingDiagnosticLogEffect.dispose()→activate()` 公共 API 未动（本计划零接触），research Pattern 2 协议可直接实施。
- **04-03（卡片开关）**：`ErrorFeedbackSettings.I.state` notifier 已就绪；`errorCardEnabled` 默认 true 的损坏回退语义已被测试锁死。
- **04-04（设置 UI）**：`pendingPersist`/`defaultSettingsFile()`/`configuredFailure`（行内回退原因 D-04 数据源）均为 UI 消费面预留的公共 API。
- **T-01-13/19 重审**：sink 落点仍只写诊断包纯文本、settings.json 不承载诊断串——threat model 的 re-verified 结论维持；收账落盘在 Phase 收尾 04-SECURITY.md。
- **实机人工核对（headless 无法证明）**：debug run 确认 settings.json 出现在项目目录旁、日志落 exe 根 `logs/error.log`（build 目录 gitignored 属预期）。

---

*Plan: 04-01 · Wave 1 of 3 · Phase 4-错误反馈设置*
*Executed: 2026-08-31*

## Self-Check: PASSED

- 5 个创建/修改文件全部存在于工作区（2 created + 3 modified）
- 4 个任务 commit（9f525333 / 30d5482b / eebd9d36 / 7f20ddc8）均在 git 历史中
- 全量门：`flutter test` 1342 例全绿（0 delta）、`flutter analyze` 0 error、`kernel_logger_gate` GATE 1/2 PASS
