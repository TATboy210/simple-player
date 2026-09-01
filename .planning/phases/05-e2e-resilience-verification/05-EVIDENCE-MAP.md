# Phase 5 证据映射表(VER-01~05 归档)

**Plan:** 05-01(端到端韧性验证收官)
**采信边界:** D-01/D-02 —— Phase 1–4 已积累测试按主证据直接归档;本 phase 仅补四源端到端整合用例与爆发/关闭隔离补差;VER-04 实机记录正式归档,不重跑。
**引用格式:** `测试文件#用例名`(可 grep 定位)或 `UAT 文档#Test N`。

---

## VER-01 四源端到端故障注入

> 需求口径:四源端到端故障注入——每源各产单报告+文件证据+卡片(开关开启时)

| 证据 | 类型 | 引用 | 状态 |
|------|------|------|------|
| 四源端到端整合注入(tracer,本 phase 新增) | 自动化 | `test/diagnostics/end_to_end_injection_test.dart#framework error via the installed FlutterError.onError hook yields report, file record, and card` | ✅ 归档 |
| 同上(异步未捕获源) | 自动化 | `test/diagnostics/end_to_end_injection_test.dart#uncaught async error via the PlatformDispatcher.onError hook yields report, file record, and card` | ✅ 归档 |
| 同上(bootstrap zone 兜底源) | 自动化 | `test/diagnostics/end_to_end_injection_test.dart#guarded-zone error via the production BootstrapErrorFallback.report yields report, file record, and card` | ✅ 归档 |
| 同上(PlayerError 桥接源) | 自动化 | `test/diagnostics/end_to_end_injection_test.dart#PlayerError forwarded by the bridge yields report, file record, and card` | ✅ 归档 |
| reporter 层四源归一化先例 | 自动化(佐证) | `test/diagnostics/error_reporter_test.dart#normalizes framework, bootstrap, platform, and player inputs` | ✅ 归档 |
| 卡片呈现/门控语义先例 | 自动化(佐证) | `test/widget/player/error_card_host_test.dart#accepts a report and shows the card at the top-left`;SET-01 门控组(`error_card_host_test.dart#toggle off hides the card the same frame and keeps the queue`) | ✅ 归档 |

## VER-02 合成错误爆发(100–1000 事件)

> 需求口径:有界内存、合并 UI、受控写盘、播放控制仍响应(D-03/D-04 设计值口径)

| 证据 | 类型 | 引用 | 状态 |
|------|------|------|------|
| 100/1000 duplicate burst 主证据 | 自动化 | `test/diagnostics/error_reporter_test.dart#keeps 100 and 1000 duplicate bursts bounded with accumulated counts` | ✅ 归档(引用,不重写) |
| 混合爆发补差(本 phase 新增) | 自动化 | `test/diagnostics/burst_resilience_test.dart#keeps a 1000 mixed burst bounded with visible merge counts and zero unhandled errors` | ✅ 归档 |
| 爆发下写盘受控补差(本 phase 新增) | 自动化 | `test/diagnostics/burst_resilience_test.dart#keeps the single-writer chain intact with ordered packs under burst` | ✅ 归档 |
| pump 响应不卡补差(本 phase 新增) | 自动化 | `test/diagnostics/burst_resilience_test.dart#completes pre-scheduled timers and microtasks on time after burst` | ✅ 归档 |
| 快照 ≤20 上界 | 自动化(佐证) | `test/widget/player/error_card_host_test.dart#snapshot caps at the bound and evicts the oldest` | ✅ 归档 |
| 「播放控制仍响应」实机面 | UAT 实机(佐证) | `.planning/phases/03-playback-error-card-bridge/03-UAT.md#Test 1` | ✅ 归档 |
| profile/内存曲线阈值 | 明确排除 | D-04:不设阈值,属后端优化轮(Deferred Ideas) | ➖ 不适用 |

## VER-03 zone 一致性 / reentrancy / 复制与关闭失败隔离

> 需求口径:zone 一致性冒烟(binding/runApp 同 zone)、reentrancy 测试、复制/关闭失败隔离测试

| 证据 | 类型 | 引用 | 状态 |
|------|------|------|------|
| zone 一致性(钩子回调含容器) | 自动化 | `test/diagnostics/global_error_hooks_test.dart#contains reporter failures from both installed callbacks`;`#forwards exact dispatcher error and stack then returns true`;`#delegates an initialized bootstrap error once` | ✅ 归档 |
| reentrancy(任意 effect 失败不外溢) | 自动化 | `test/diagnostics/error_reporter_test.dart#isolates listener and effect failures while suppressing reentrant intake` | ✅ 归档 |
| reentrancy(协作器故障含容器) | 自动化 | `test/diagnostics/error_reporter_test.dart#contains malformed collaborator failures without throwing` | ✅ 归档 |
| 复制失败隔离(CARD-04) | 自动化 | `test/widget/player/error_card_test.dart#unmocked clipboard channel leaves card intact with no crash` | ✅ 归档 |
| 关闭推进 | 自动化 | `test/widget/player/error_card_test.dart#close button dismisses current and advances the FIFO` | ✅ 归档 |
| 关闭推进过程中 effect 失败不产生第二错误(条件补差,本 phase 新增) | 自动化 | `test/diagnostics/burst_resilience_test.dart#keeps close-advance contained when the effect fails` | ✅ 归档(盘点结论:既有 :743 只覆盖 intake 路径,dismiss 路径补差命中) |
| 打开日志失败隔离(E97) | 自动化(佐证) | `test/widget/player/error_card_host_test.dart#ProcessException from the seam shows failed OSD without escaping` | ✅ 归档 |

## VER-04 Windows 实机冒烟(D-02:正式归档,不重跑)

> 需求口径:标题拖动/窗口控制/seek/播放列表/全屏/ESC/媒体键在卡片显示期间全部正常

| 证据 | 类型 | 引用 | 状态 |
|------|------|------|------|
| 卡片显示期间宿主窗口交互 6 项(标题拖动/控制/键盘/全屏/复制/打开日志) | UAT 实机 | `.planning/phases/03-playback-error-card-bridge/03-UAT.md#Test 1` | ✅ 归档 |
| 卡片位置(视频区域左上角) | UAT 实机 | `.planning/phases/03-playback-error-card-bridge/03-UAT.md#Test 2` | ✅ 归档 |
| F1 快捷键帮助 | UAT 实机 | `.planning/phases/03-playback-error-card-bridge/03-UAT.md#Test 3` | ✅ 归档 |
| 调试注入入口移除(用后即撤) | UAT 实机 | `.planning/phases/03-playback-error-card-bridge/03-UAT.md#Test 4` | ✅ 归档 |
| 实机开关切换(SET-01) | UAT 实机 | `.planning/phases/04-error-feedback-settings/04-UAT.md#Test 1` | ✅ 归档 |
| 开关重启持久化(SET-03) | UAT 实机 | `.planning/phases/04-error-feedback-settings/04-UAT.md#Test 2` | ✅ 归档 |
| MSIX ACL 冒烟(设置双层回退) | UAT 实机 | `.planning/phases/04-error-feedback-settings/04-UAT.md#Test 4` | ✅ 归档 |
| 快速开关并发确认 | UAT 实机 | `.planning/phases/04-error-feedback-settings/04-UAT.md#Test 6` | ✅ 归档 |
| 路径配置(原 Test 3/5) | 已移除 | 用户决策功能整体移除,随移除不再适用 | ➖ 不适用 |

**移除后未覆盖点盘点(D-02):** 注入入口 G-03-4 已用后即撤(03-UAT Test 4)、路径配置 SET-02 已修订移除(04-UAT Test 3/5)——两者均为「移除即验收」项,无残留行为需要覆盖。**预 count 成立:无已知缺口,无需实机核对清单。**

## VER-05 开发者文档

| 证据 | 类型 | 引用 | 状态 |
|------|------|------|------|
| release 源码/符号降级策略 | 文档 | `docs/error-diagnostics-limitations.md` §1 | ✅ 归档 |
| Dart 钩子边界(不覆盖 libmpv/FFI 原生崩溃) | 文档 | `docs/error-diagnostics-limitations.md` §2 | ✅ 归档 |
| isolate 写盘语义与卡死时间窗读数方法 | 文档 | `docs/error-diagnostics-limitations.md` §3 | ✅ 归档 |
| WER LocalDumps 注册表配置建议 | 文档 | `docs/error-diagnostics-limitations.md` §4 | ✅ 归档 |

---

## Phase 收口记录

| 门禁 | 结果 |
|------|------|
| START commit | `82960d8c` |
| Task 1 整合用例 + Task 2 补差用例 | ✅ 全绿(8/8,组合稳定 5 连跑) |
| 全量 `flutter test --machine` 基线 diff(headless-baseline.txt) | ✅ PASS:no new failures beyond headless baseline(0 baseline entries) |
| `flutter analyze` | ✅ 0 error(64 条 info/warning 均为预存,非本 phase 触碰面) |
| `bash tool/audit/kernel_logger_gate.sh` | ✅ GATE 1 PASS(LOG-01)+ GATE 2 PASS(LOG-04) |
| 产品零 diff:`git diff --name-only 82960d8c..HEAD -- lib/ windows/ pubspec.yaml` | ✅ 输出为空 |
| headless 基线 | 空基线(当前环境零基线失败;Phase 4 期已观察到 mdk.dll 不再触发) |

**工作区说明:** 工作树中 `pubspec.yaml`/`pubspec.lock`/`.mcp.json` 等存在 START 之前已发生的用户预存修改——零 diff 断言按 plan 口径以**提交区间** `82960d8c..HEAD` 为准(本 phase 提交未触碰 lib/、windows/、pubspec.yaml)。
