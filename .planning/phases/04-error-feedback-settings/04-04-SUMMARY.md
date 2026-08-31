---
phase: 04-error-feedback-settings
plan: 04
subsystem: diagnostics
tags: [settings-ui, tab-selection, toggle-row, log-path-validation, file-picker, l10n, widget-tests, tdd]

# Dependency graph
requires:
  - phase: 04-error-feedback-settings
    plan: 01
    provides: "ErrorFeedbackSettings store（setCardEnabled/state/resetForTesting + 默认开语义）+ 三层位置链"
  - phase: 04-error-feedback-settings
    plan: 02
    provides: "DiagnosticLogTarget 协调器（validate/apply/effectiveLogPath + 三不协议）+ logFallbackNotice l10n"
  - phase: 04-error-feedback-settings
    plan: 03
    provides: "ErrorCardHost 呈现门控（开关翻转同帧生效的呈现侧语义）"
provides:
  - "SettingsDialog 选中态架构：StatefulWidget per-dialog 选中 tab + _NavEntry onTap/选中高亮 + 内容切换（General/About 可交互，视频/音频灰显占位零破坏）"
  - "GeneralSettingsContent：错误卡片开关行（代码库首个 Switch）+ 日志目录路径行（手输防抖校验/浏览回填/行内状态/有效路径常显）"
  - "设置域 9 个双语 ARB key + gen-l10n 产物"
  - "widget 测试真实 I/O 协议：pump+runAsync 交替推进 fake-zone 发起的文件链；teardown 禁 await plain async fn"
affects: [SECURITY-t0113-0119-reaudit, VERIFY-phase4-manual-items]

# Actuals (#2632) — chars/4 over the realized diff (9 files, 1112 insertions / 40 deletions)
actuals:
  tokens: 10080
  tasks: 3
  commits: 4

# Tech tracking
tech-stack:
  added: []  # 零新包 —— file_picker 既有依赖换用 v11 静态 API 调用形态（T-04-04-SC accept 依据）
  patterns:
    - "设置行语法：MouseRegion hover + AnimatedContainer 行（循 setting_action_row）+ trailing 控件位"
    - "行内校验状态机：sealed _PathStatus（idle/validating/valid/invalid(reason)）映射 l10n 文案与语义色"
    - "widget 测试真实 I/O 协议：pump（冲刷 fake 微任务）+ runAsync（放行真实文件事件）交替；等待条件一律锚定 effectiveLogPath 落点"

key-files:
  created:
    - lib/ui/dialogs/settings/general_settings_content.dart
    - test/widget/dialogs/general_settings_content_test.dart
  modified:
    - lib/ui/dialogs/settings/settings_dialog.dart
    - lib/l10n/app_en.arb
    - lib/l10n/app_zh.arb
    - lib/l10n/app_localizations.dart
    - lib/l10n/app_localizations_en.dart
    - lib/l10n/app_localizations_zh.dart
    - test/widget/dialogs/settings_dialog_test.dart

key-decisions:
  - "file_picker v11.0.3 实测无 WindowsOptions 类/无 windowsOptions 参数、顶层 lockParentWindow 无废弃标注 —— 浏览按钮用 FilePicker.getDirectoryPath(dialogTitle:…, lockParentWindow: true)（与 file_picker_adapters.dart 的 pickFiles 同参先例），计划字面 v11 options 形态不成立"
  - "提交链收敛到协调器单点：行内校验后直接调用 apply()（其内部含 validate + 三不协议），不按计划字面 validate→apply 双探测 —— 同一可观察行为、减半探测 I/O、单一校验实现（T-04-04-01 对齐）"
  - "Switch 主题用 activeThumbColor（activeColor 自 Flutter 3.31 起废弃，analyze 会报 deprecated 成 error 红线风险）"
  - "TextField 初始值 = effectiveLogPath 逐字（D-03『显示当前有效路径』字面采纳：用户永远看到的是有效落点而非配置输入）"
  - "浏览 picker 异常收窄 on Exception 行内报错（映射 _InvalidStatus(notWritable)，仅有的行内错误文案）；取消（null）与空串返回一律静默忽略"

requirements-completed: [SET-01, SET-02, SET-03]  # 通用 tab UI 收口使三需求全部具备用户可见面；ready-ids 门判定见下

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "设置壳选中态：初始「关于」向后兼容；通用/关于可交互互切且选中高亮为持续态（bgHover+accent，区别 hover）；视频/音频保持 38% Opacity+IgnorePointer 不可点（无伪交互）"
    requirement: SET-01
    verification:
      - kind: widget
        ref: "test/widget/dialogs/settings_dialog_test.dart（壳选中态三用例 + 既有四用例零回归，7/7 绿）"
        status: pass
    human_judgment: false
  - id: D2
    description: "开关行：初始开（store 默认）→ 翻转 store 立即 false → 临时 settings.json 持久化 false（fire-and-forget 可观测）→ 再翻转恢复 true；行本体点击亦可切换"
    requirement: SET-01
    verification:
      - kind: widget
        ref: "test/widget/dialogs/general_settings_content_test.dart#toggle row flips the store and persists"
        status: pass
    human_judgment: false
  - id: D3
    description: "手输防抖校验：到期前零副作用（store 未保存/有效路径未变/无校验中状态）；到期后校验→保存→apply 全协议生效，行内显示『目录可写』"
    requirement: SET-02
    verification:
      - kind: widget
        ref: "test/widget/dialogs/general_settings_content_test.dart#debounced valid directory validates, saves, and retargets"
        status: pass
    human_judgment: false
  - id: D4
    description: "非法输入三不：指向文件的路径 → 行内『无法写入该目录』、store 未保存、effectiveLogPath 不变、输入内容保留；清空 → 保存 '' 并重定向默认链（exe 层 logs/error.log）"
    requirement: SET-02
    verification:
      - kind: widget
        ref: "test/widget/dialogs/general_settings_content_test.dart#invalid path… / #clearing the input…（两用例）"
        status: pass
    human_judgment: false
  - id: D5
    description: "浏览网关：注入 picker 返回 null（取消）→ 零副作用（≠ 清空）；返回可写目录 → 回填输入框并走与手输相同的防抖校验→保存→apply 链路"
    requirement: SET-02
    verification:
      - kind: widget
        ref: "test/widget/dialogs/general_settings_content_test.dart#browse cancel… / #browse backfill…（两用例）"
        status: pass
    human_judgment: false
  - id: D6
    description: "D-04 第一通道：行内状态区常显『当前有效路径：<effective>』；配置目录与有效落点不一致时附加『已回退到默认位置』原因行"
    requirement: SET-02
    verification:
      - kind: widget
        ref: "test/widget/dialogs/general_settings_content_test.dart#effective path and fallback reason are shown inline"
        status: pass
    human_judgment: false
  - id: D7
    description: "Phase 收口质量门：flutter analyze 0 error（61 条既有 info 与 04-01 起基线同值，触碰文件 0 条）；flutter test 1377 例全绿（预存 headless 基线未复现，0 delta）；kernel_logger_gate GATE 1/2 PASS；reporter/单写者/media_kit 零接触（git diff 面审计为空）"
    requirement: SET-03
    verification:
      - kind: other
        ref: "flutter test（exit 0，1377 passed）+ flutter analyze（0 error）+ bash tool/audit/kernel_logger_gate.sh（GATE 1/2 PASS）+ git diff cd0fa2ae -- lib/kernel/（空）"
        status: pass
    human_judgment: false
  - id: D8
    description: "实机 debug run：开关切换卡片立即消失/恢复；日志路径变更后新错误写入新位置、旧行不丢；OSD 一次性；MSIX exe-root 探测失败行内显示 AS 有效路径；非法路径行内 ✗ 呈现"
    verification: []
    human_judgment: true
    rationale: "窗口可见性/OSD 呈现/MSIX ACL 环境/实机交互路径无法在 headless 测试中证明（MEMORY: UAT 证据标准）；四项已按 04-VALIDATION Manual-Only 清单移交 /gsd-verify-work"

# Metrics
duration: 107min
completed: 2026-08-31
status: complete
---

# Phase 4 Plan 04: 设置通用 tab UI 收口（开关行 + 日志路径行）Summary

**设置壳从静态 About 页升级为可导航选中态架构，「通用」tab 承载错误卡片开关行（翻转即生效+持久化）与日志目录路径行（手输防抖校验/浏览回填/行内状态/有效路径常显）——SET-01/02/03 的用户可见面全部落地，Phase 4 质量门全绿（analyze 0 error / 1377 tests / kernel gate 1&2）。**

## Performance

- **Duration:** 107 min（含 fake-zone 真实 I/O 卡死的三轮实证诊断 ~50 min）
- **Started:** 2026-08-31T17:01:08Z
- **Completed:** 2026-08-31T18:48:00Z
- **Tasks:** 3/3（Task 1/2 走 RED→GREEN 双 commit；Task 3 为纯门禁收口，零文件改动无独立 commit）
- **Files:** 9（2 created + 7 modified）

## Accomplishments

- **设置壳选中态架构（Task 1）**：`SettingsDialog` 转 StatefulWidget 持 per-dialog `_SettingsTab` 选中态，初始「关于」向后兼容现状；`_NavEntry` 增 `selected`/`onTap`——选中态用 bgHover 持续底 + accent 图标/文字（与 hover 瞬态区分），灰显占位的 38% Opacity + IgnorePointer 语法逐字保留；内容区 switch 切换 `GeneralSettingsContent`/`AboutContent`，视频/音频防御分支返回空视图。AppDialog 壳、620×440、1px 分隔线零改动。
- **设置域 l10n 一次加齐（Task 1）**：9 个新 key（errorCardToggleLabel/logPathLabel/logPathHint/logPathBrowse/logPathValidatingStatus/logPathValidStatus/logPathInvalidStatus/logFallbackReasonPrefix/logEffectivePathLabel）en+zh 双语 + @key description 入 ARB，`flutter gen-l10n` 产物三文件同步提交。
- **通用内容实装（Task 2）**：开关行为代码库首个 Switch（activeThumbColor=Tokens.accent 主题，doc comment 记录无先例处置），行本体点击亦可翻转（手势最内层胜出无双重翻转）；路径行手输防抖 300ms（参数化），提交统一经 `DiagnosticLogTarget.I.apply` 全协议——校验通过即保存并立即重定向、失败行内 ✗ 且不保存不重定向、清空回默认链；浏览按钮经可注入 `directoryPicker` seam（headless 测试需要，缺省绑生产 FilePicker）；行内状态区 sealed `_PathStatus` 映射 l10n 文案与语义色，有效路径常显 + 回退原因前缀（D-04 第一通道）。
- **widget 测试真实 I/O 协议（本轮沉淀）**：pump（冲刷 fake 微任务推进 coordinator 链续体）+ runAsync（放行真实文件完成事件）交替的 pumpUntil 助手；两条铁律实证入注释——teardown 禁 await plain async fn（FakeAsync 微任务饥饿 → 10 分钟超时），body 内禁 await 真实 I/O（改同步 API）；等待条件一律锚定 effectiveLogPath 落点（store 同步先置早于 swap，避免竞态早退）。
- **Phase 收口（Task 3）**：全项目门全绿——`flutter analyze` 0 error（61 条既有 info 与基线同值）、`flutter test` 1377 例全绿（04-01 起 1342→1363→1377，0 delta，headless 预存基线未复现）、`kernel_logger_gate` GATE 1/2 PASS；改动面自检——`git diff cd0fa2ae -- lib/kernel/` 为空、reporter/snapshot/delegate/sink/formatter 五文件零 diff、设置域无 media_kit 符号（grep 复核）；Per-Task Verification Map 全行对应测试文件均绿；Manual-Only 四项移交 /gsd-verify-work。

## Task Commits

1. **Task 1 RED**：设置壳选中态失败测试 + 骨架文件 —— `b434f27c` (test)
2. **Task 1 GREEN**：选中态架构 + 设置域 l10n key —— `890b368b` (feat)
3. **Task 2 RED**：通用行七行为用例失败测试 —— `5fe059f9` (test)
4. **Task 2 GREEN**：开关行 + 路径行实装 —— `ab0ea378` (feat)

_Task 3（质量门收口）零文件改动，无独立 commit；门禁证据见 coverage D7。_

## Files Created/Modified

- `lib/ui/dialogs/settings/general_settings_content.dart`（NEW）— 开关行 + 路径行 + 行内状态区/有效路径行 + `_SettingsRow`/`_BrowseButton` 行语法组件 + sealed `_PathStatus`
- `lib/ui/dialogs/settings/settings_dialog.dart`（MODIFY）— StatefulWidget 选中态 + `_SettingsTab` 枚举 + `_NavEntry` selected/onTap + 内容 switch
- `lib/l10n/app_en.arb` / `app_zh.arb`（MODIFY）— 设置域 9 个新 key 双语入库
- `lib/l10n/app_localizations.dart` / `_en.dart` / `_zh.dart`（MODIFY）— `flutter gen-l10n` 再生成产物
- `test/widget/dialogs/settings_dialog_test.dart`（EXTEND，+3 用例）— 选中态切换/About 回归/灰显不可交互结构锁
- `test/widget/dialogs/general_settings_content_test.dart`（NEW，7 用例）— 开关持久化/防抖校验/非法三不/清空回链/浏览取消/浏览回填/D-04 第一通道

## Decisions Made

- **file_picker v11 形态修正**：实测 11.0.3 源码（pub-cache）无 `WindowsOptions` 类、`getDirectoryPath` 无 `windowsOptions` 参数、顶层 `lockParentWindow` 无 `@Deprecated`——采用 `FilePicker.getDirectoryPath(dialogTitle:…, lockParentWindow: true)`，模态前置语义与计划意图完全一致（见 Deviations 1）。
- **提交链单点化**：UI 端防抖到期后直接调用 `apply()`（内部 validate + 三不由协调器保证），不按计划字面先 validate 再 apply 的双探测流程——同一可观察行为（校验中状态、三不、通过即保存换位）、减半真实探测 I/O、无「校验通过但 apply 再失败」的中间窗口。
- **Switch 主题**：`activeColor` 已废弃（Flutter 3.31+，deprecated 标注在 SDK 源码确认），用 `activeThumbColor: Tokens.accent` 达成同一视觉意图。
- **有效路径行语义**：常显 `当前有效路径：<effectiveLogPath>`（含配置层胜出与回退两种形态），回退时加显 `已回退到默认位置` 前缀行；effectiveLogPath 为 null（尚未激活）时不渲染误导占位。
- **测试 harness 沉淀**：单例隔离循 04-02/04-03 惯例（resetForTesting + 临时目录 seam + addTearDown 清理）；真实 I/O 链 pump+runAsync 交替推进；teardown 对 delegate.dispose 改 fire-and-forget（同步段即复位 activate 一次性锁，残余 await 链无害）。

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocker] file_picker v11 无 WindowsOptions——计划字面 API 无法编译**
- **Found during:** Task 2 GREEN（实现浏览网关时核对 pub-cache 内 11.0.3 实源）
- **Issue:** 计划 action 写明 `FilePicker.getDirectoryPath(dialogTitle:…, windowsOptions: WindowsOptions(lockParentWindow: true))`，并称顶层 lockParentWindow 已废弃——实测 11.0.3 全源无 `WindowsOptions` 类、无 `windowsOptions` 参数、`lockParentWindow` 为普通顶层 bool 且无 `@Deprecated` 标注（RESEARCH 的 Context7 记载与实际版本不符）。
- **Fix:** `FilePicker.getDirectoryPath(dialogTitle: l10n.logPathBrowse, lockParentWindow: true)`——与 `file_picker_adapters.dart:23` 既有 pickFiles 同参先例一致，模态前置（T-04-04-02 相关语义）原样保留。
- **Files modified:** lib/ui/dialogs/settings/general_settings_content.dart
- **Verification:** flutter analyze 0 error（该文件 0 条目）；浏览用例经注入 seam 全绿
- **Commit:** ab0ea378

**2. [Rule 1 - Bug] Switch.activeColor 已废弃**
- **Found during:** Task 2 GREEN
- **Issue:** 计划要求 `Switch(activeColor: Tokens.accent)`；Flutter 3.31+ 中 activeColor 带 `@Deprecated`（strict 模式下为 analyzer 告警面，且项目 0-error 红线不容劣化）。
- **Fix:** `activeThumbColor: Tokens.accent`（SDK 指定的替代参数，视觉意图相同）。
- **Files modified:** lib/ui/dialogs/settings/general_settings_content.dart
- **Verification:** flutter analyze 0 error
- **Commit:** ab0ea378

**3. [Rule 1 - Bug] 测试作者缺陷三处（FakeAsync 真实 I/O 陷阱族，GREEN 内修正）**
- **Found during:** Task 2 GREEN 首跑（部分用例 10 分钟超时；逐轮探针定位）
- **Issue:** (a) teardown `await delegate.dispose()`——plain async fn 的 await 续体进入 FakeAsync 微任务队列，body 结束后无人冲刷 → 永不完成 → 10 分钟超时（04-03 的 dart:io await 能完成是因 I/O 完成事件经真实事件循环派发，与 plain future 续体路径不同）；(b) body 内 `await fileAsPath.writeAsString('x')` —— FakeAsync zone 不派发真实文件事件，永不完成；(c) pumpUntil 条件以 store 为准——store 在 apply 内同步先置、早于 swap 完成 → 条件提前满足返回，断言撞上未落定状态；另 test 7 `find.textContaining(activeFile.path)` 同时命中有效路径行与输入框初值（2 处）。
- **Fix:** (a) `addTearDown(() => unawaited(delegate.dispose()))`（同步段即复位 activate 锁）；(b) `writeAsStringSync`；(c) 等待条件一律锚定 effectiveLogPath 最终落点；(d) 断言改为标签前缀整行单匹配。
- **Files modified:** test/widget/dialogs/general_settings_content_test.dart
- **Verification:** 14/14 全绿且整轮 2 秒内完成（修复前单用例超时 10 分钟）
- **Commit:** ab0ea378（随 GREEN 一并入库）

**Total deviations:** 3（Rule 3 × 1，Rule 1 × 2——均已修复并锁定）
**Impact:** 无范围/接口影响；一处为计划字面 API 与依赖实际版本的冲突消解，两处为测试作者缺陷；fix 后整轮 dialog 套件 2 秒内全绿。

## Issues Encountered

- 无阻断问题。预存 headless 基线（mdk.dll FFI / 状态机 security）本轮未复现——全量 `flutter test` 1377 例全绿（04-03 基线 1363 + 本计划新增 14，0 delta）。
- `flutter analyze` 61 条 info/warning 全部为未触碰文件的既有条目（与 04-01/04-02/04-03 基线同值），触碰文件 0 条、error 0 条。
- 诊断插曲：GREEN 期间三处测试卡死（每处 10 分钟超时）经三轮最小探针（sync 证据落盘 + 逐段插桩）定位为上述 FakeAsync 陷阱族——未改任何生产代码即修复，相关纪律已写入测试注释供后续计划复用。

## Next Phase Readiness

- **Phase 4 收口**：本计划为 Phase 4 末计划——设置域 UI/协调器/存储/位置链/呈现门控全链落地，三质量门全绿，REQUIREMENTS 的 SET-01/02/03 具备用户可见面并已 mark-complete。
- **/gsd-verify-work 移交（Manual-Only 四项，04-VALIDATION）**：① 实机开关切换卡片立即消失/恢复 + 路径变更后新错误写新位置、旧行不丢；② 回退 OSD「日志已回退到默认位置」出现恰一次不刷屏；③ MSIX 包内冒烟 exe-root 探测失败 → 行内显示 AS 有效路径；④ 设置对话框输入非法路径（指向文件）的行内 ✗ 呈现与不保存。
- **T-01-13/19 重审**：本计划零触碰诊断内核与写路径（diff 面审计为空）；UI 新增面仅为行内文案映射与可注入 picker seam——threat register 的 re-verified 结论维持（04-01/04-02/04-03 同口径），收账落盘在 Phase 收尾 04-SECURITY.md。
- **遗留观测（非阻塞）**：`_pickDirectoryWithPlugin` 在 headless 不可达（生产路径专用），其实机行为（模态前置、取消语义）随 Manual-Only ④ 一并核对。

---

*Plan: 04-04 · Wave 3 of 3 · Phase 4-错误反馈设置（末计划）*
*Executed: 2026-08-31*

## Self-Check: PASSED

- 9 个创建/修改文件全部存在于工作区（2 created + 7 modified）
- 4 个任务 commit（b434f27c / 890b368b / 5fe059f9 / ab0ea378）均在 git 历史中
- 全量门：`flutter test` 1377 例全绿（0 delta）、`flutter analyze` 0 error、`kernel_logger_gate` GATE 1/2 PASS
- 红线证明：`git diff cd0fa2ae -- lib/kernel/` 为空；`.mcp.json`/`pubspec.yaml`/`pubspec.lock`/`.planning/state.json` 等预存脏文件全程未触碰
