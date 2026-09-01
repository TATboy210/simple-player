---
phase: 05-e2e-resilience-verification
plan: 01
subsystem: error-diagnostics
tags: [verification, evidence-archive, developer-docs, resilience, zero-product-diff]
requires: [phase-01-capture, phase-02-diagnostics-file, phase-03-error-card, phase-04-feedback-settings]
provides:
  - VER-01~05 归档证据映射表(可 grep 定位)
  - 四源端到端整合注入用例(tracer)
  - 爆发压测/关闭失败隔离补差用例
  - VER-05 开发者边界文档(docs/error-diagnostics-limitations.md)
  - headless-baseline.txt(全量测试机械化基线,空基线)
affects: [milestone-close]
tech-stack:
  added: []
  patterns:
    - 04-04 真实 I/O 协议变体:runAsync+pump 轮询锚定文件落点(禁裸 await FakeAsync zone 链)
    - teardown 捕获 setUp 时刻目录值(禁共享 late 引用,防跨测试误删)
    - 诊断包计数改逐标记出现次数+位置递增断言(包内含空行,不可按空行切包)
key-files:
  created:
    - test/diagnostics/end_to_end_injection_test.dart
    - test/diagnostics/burst_resilience_test.dart
    - .planning/phases/05-e2e-resilience-verification/headless-baseline.txt
    - .planning/phases/05-e2e-resilience-verification/05-EVIDENCE-MAP.md
    - docs/error-diagnostics-limitations.md
  modified: []
decisions:
  - headless 基线取空文件分支:当前环境零基线失败(Phase 4 期已观察到 mdk.dll 不再触发),机制对空/非空两态均成立
  - VER-03 条件补差命中:既有 :743 只覆盖 intake 路径,dismiss/close-advance 路径无显式用例 → 新增 close-advance 隔离用例
  - PlayerError 卡片断言按 D-02 l10n 契约:卡片渲染 l10nKey 解析文案,原始消息用于报告与文件证据
  - 零 diff 断言以提交区间 82960d8c..HEAD 为准(工作树含用户预存 pubspec.yaml 等修改,与本 phase 无关)
metrics:
  duration: 58min
  completed: 2026-09-01
  tasks: 3
  commits: 4
actuals:
  tokens: 8200
  tasks: 3
  commits: 4
requirements-completed:
  - "**VER-01**: 四源端到端故障注入——每源各产单报告+文件证据+卡片（开关开启时）"
  - "**VER-02**: 合成错误爆发（100-1000 事件）下有界内存、合并 UI、受控写盘、播放控制仍响应"
  - "**VER-03**: zone 一致性冒烟（binding/runApp 同 zone）、reentrancy 测试、复制/关闭失败隔离测试"
  - "**VER-04**: Windows 实机冒烟：标题拖动/窗口控制/seek/播放列表/全屏/ESC/媒体键在卡片显示期间全部正常"
  - "**VER-05**: 文档化 release 源码/符号策略与原生崩溃边界（Dart 钩子不覆盖 libmpv/FFI 进程崩溃）"
coverage: "VER-01:4 端到端 testWidgets + 佐证;VER-02:既有 burst 主证据 + 3 补差用例;VER-03:zone/reentrancy/复制既有归档 + close-advance 补差;VER-04:03-UAT Test 1-4 + 04-UAT Test 1/2/4/6 正式归档;VER-05:四章节文档"
---

# Phase 5 Plan 01: 端到端韧性验证 Summary

**One-liner:** 四源端到端整合注入 + 爆发/关闭隔离补差用例全绿,VER-01~05 证据映射表与开发者边界文档归档,产品实现零 diff,质量四门禁(analyze/machine 基线 diff/kernel_logger_gate/零 diff)全绿——里程碑验证闭环收官。

**One-liner (EN):** Four-source end-to-end injection suite plus burst/close-isolation gap tests all green; VER-01~05 evidence map and developer limitations doc archived with zero product diff — milestone verification closed.

## 完成内容 (What Was Done)

### Task 1 (tracer, VER-01/D-01): 四源端到端整合注入 — commit `e2c040fe`
- `test/diagnostics/end_to_end_injection_test.dart`:4 个 testWidgets,每源经**真实注入入口**走完整链路(FlutterError.onError 钩子回调 / PlatformDispatcher.onError 钩子回调 / 生产 `BootstrapErrorFallback.report` zone 兜底 / `PlayerErrorReportBridge`+FakeEngine),断言三件套 = reporter 恰一份新报告(occurrenceCount=1)+ temp FileSink 文件新增该源记录 + ErrorCard 呈现且徽标「1 错误」。
- step 0 机械化基线:全量 `flutter test --machine` → 提取失败用例 → `headless-baseline.txt` 为**空**(当前环境零基线失败;与 plan 预案一致:Phase 4 期已观察到 mdk.dll 不再触发,机制对空/非空两态均成立)。
- tracer 反馈门:targeted verify 复跑端到端(含组合跑 5 连稳定)→ 通过后才扩展。

### Task 2 (VER-02/VER-03, D-03/D-04): 爆发压测与关闭失败隔离补差 — commit `d7b3f2ff`
- `test/diagnostics/burst_resilience_test.dart` 4 用例:
  - **A 混合爆发**:1000 条(互异 900+同消息 100)→ FIFO ≤5 设计值、逐出报告不在队列、合并 `occurrenceCount=100` 可见、zone+FlutterError.onError 双口径零 unhandled;
  - **B 写盘受控**:temp 真实 FileSink 驱动 100 条互异爆发 → 单写者链保序(逐标记恰一次+文件内位置严格递增)、零写失败、可用性为真;
  - **C pump 不卡**:fakeAsync 爆发后,爆发前预排定 timer 准时完成、microtask 刷新、队列仍有界(实机面由 03-UAT Test 1 归档佐证);
  - **D 关闭失败隔离补差**:close-advance 触发抛错 presentation 监听/失败 effect → 不抛、不产生第二错误报告、队列恰好推进一格(循 :743 隔离缝)。
- 既有主证据归档引用(文件头):reporter :291 duplicate burst / :156 FIFO / :743 reentrancy / error_card :746 复制失败隔离。

### Task 3 (VER-01~05 归档 + VER-05 文档 + 收口门禁, D-02/D-05) — commit `c6ca4c2b`
- `05-EVIDENCE-MAP.md`:VER-01~05 逐项证据表(全部可 grep 定位);VER-04 以 03-UAT Test 1–4 + 04-UAT Test 1/2/4/6 **正式归档不重跑**(Test 3/5 路径配置已移除不适用);移除后未覆盖点盘点 = 无缺口(预 count 成立);表尾收口记录含 START hash 与全门禁结果。
- `docs/error-diagnostics-limitations.md`(中文双语四章):①release 源码/符号降级(LOC-02,无源码 I/O、定位文本不报错);②Dart 钩子边界(不覆盖 libmpv/FFI 原生进程崩溃,归属 WER 工具域,与 Out of Scope 口径一致);③isolate 写盘语义与卡死时间窗读数(心跳 30s,心跳空档 T1–T2 = 冻结窗口;「日志不可用」= 写盘降级而非捕获失效);④WER LocalDumps 注册表建议(per-app 子键/DumpFolder/DumpType=2/DumpCount=10,与 error.log 互不替代)。
- **收口门禁全绿**:`flutter analyze` 0 error;全量 `flutter test --machine` 经 node diff 脚本对照基线 → PASS(零新增失败);`bash tool/audit/kernel_logger_gate.sh` GATE 1+2 PASS;两归档文件存在;`git diff --name-only 82960d8c..HEAD -- lib/ windows/ pubspec.yaml` 为空(产品零 diff 被断言证明)。

## Verification (验收对照)

| 成功标准 | 结果 |
|----------|------|
| 1. 四源端到端整合用例全绿(每源报告+文件+卡片) | ✅ 4/4,组合稳定 5 连跑 |
| 2. 100–1000 爆发设计值口径(有界/合并可见/写盘受控/pump 不卡) | ✅ 用例 A/B/C |
| 3. zone/reentrancy/复制与关闭失败隔离全有归档指向,缺口已补差 | ✅ 映射表 VER-03 行 |
| 4. VER-04 以 03/04 UAT 正式归档不重跑,移除后盘点完成 | ✅ 映射表 VER-04 行 |
| 5. VER-05 文档四章节(release 降级/原生崩溃边界/isolate 写盘/WER) | ✅ docs/ 落盘 |
| 6. 产品零 diff(lib/ windows/ pubspec.yaml)+ 质量门禁全绿 | ✅ 提交区间断言 + 四门禁 |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] 端到端用例首轮运行挂死 → 04-04 轮询协议修复**
- **Found during:** Task 1
- **Issue:** `expectFileRecord` 在 `tester.runAsync` 内裸 await `sink.drain()` —— FileSink 写链续体在 FakeAsync zone 创建,runAsync 不派发 fake 微任务 → 永久饿死(每用例 10min 超时)。
- **Fix:** 改为交替 `runAsync(真实事件循环派发 OS 写完成)`+`pump(刷新 fake 微任务)` 轮询锚定文件落点;读改 `readAsStringSync` 静默处理未落盘态。
- **Files modified:** test/diagnostics/end_to_end_injection_test.dart
- **Commit:** e2c040fe

**2. [Rule 1 - Bug] 跨测试 PathNotFound 竞态(联合跑下偶发失败)**
- **Found during:** Task 1 稳定性复跑(复现 3 次,单测必过)
- **Issue:** teardown 闭包引用共享 `late tempRoot` 变量,异步 delete 跨测试迟执行时误删下一用例新目录,`readAsString` 在测试中途抛 PathNotFoundException。
- **Fix:** teardown 注册时捕获 setUp 时刻的目录值(禁共享 late 引用);读侧静默未就绪。
- **Files modified:** test/diagnostics/end_to_end_injection_test.dart
- **Commit:** e2c040fe

**3. [Rule 1 - Bug] PlayerError 卡片文案按 l10nKey 解析**
- **Found during:** Task 1
- **Issue:** FileError(pathEmpty) 的卡片摘要渲染 `l10n.errorFilePathEmpty`(error_card.dart `_resolveMessage`),断言原始消息找不到。
- **Fix:** PlayerError 源断言改用 AppLocalizations 解析文案(D-02 卡片契约),原始消息仍用于报告与文件证据断言。
- **Files modified:** test/diagnostics/end_to_end_injection_test.dart
- **Commit:** e2c040fe

**4. [Rule 1 - Bug] 爆发写盘用例按空行切包计数错误**
- **Found during:** Task 2
- **Issue:** 诊断包内部以空行分节(formatter `writeln()`),按 `\n\n` split 切包把单包撕碎 → hasLength(100) 失败。
- **Fix:** 改逐标记断言「恰好出现一次 + 文件内位置严格递增」,同等证明完整有序无交错;另修 `LastResortOutput` 双参签名与 `_publishSafely` isReady 语义(补 `flushPresentation`)。
- **Files modified:** test/diagnostics/burst_resilience_test.dart
- **Commit:** d7b3f2ff

### 记录性说明
- 首轮挂死运行按每用例 10min 默认超时自终;进程级 taskkill 被权限分类器拒绝(dart.exe 下有用户 IDE/运行中 app 等无关负载),等待自终后以修复版重跑——未影响任何提交产物。
- 工作树中 `pubspec.yaml`/`pubspec.lock`/`.mcp.json`/`.planning/state.json` 等为 START 前已存在的用户预存修改,按任务纪律**从未暂存**;零 diff 断言按 plan 口径取提交区间 `82960d8c..HEAD`(为空)。

## Known Stubs

None — 本 phase 零产品代码,新测试全部走真实链路(真实 reporter 单例、真实 FileSink 落盘、真实卡片渲染),无 stub/placeholder。

## Auth Gates

None.

## Self-Check: PASSED

- 5 产物文件全部存在;3 个任务 commit(e2c040fe / d7b3f2ff / c6ca4c2b)全部存在于 git log。
- 收口门禁 2026-09-01 实测:analyze 0 error / machine 基线 diff PASS(0 baseline entries)/ kernel_logger_gate GATE 1+2 PASS / 产品零 diff 提交区间为空。
