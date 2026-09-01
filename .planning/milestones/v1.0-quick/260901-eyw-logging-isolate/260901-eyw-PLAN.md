---
phase: quick-260901-eyw
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/kernel/diagnostics/isolated_error_log_sink.dart
  - lib/ui/dialogs/settings/diagnostic_log_target.dart
  - test/diagnostics/isolated_error_log_sink_test.dart
autonomous: true
requirements: [] # quick task (260901-eyw) — sourced from /gsd-quick brief, no ROADMAP requirement IDs
user_setup: []

estimate:
  tokens: 70000
  raw_tokens: 35000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - 主 isolate 事件循环卡死（await 饿死/同步阻塞）时，卡死前已递送的每条错误记录仍由常驻 logging isolate 以 RandomAccessFile 同步写+flush 落盘——已递送记录零丢失
    - 心跳行 [heartbeat] main alive @ <ISO8601 UTC> 由主 isolate 每 30s 递送；日志文件中最后一个心跳行与下一条记录之间的空档即主 isolate 卡死时间窗（运营读数，headless 不可单测，文档注明）
    - isolate spawn 失败或 worker 意外退出时幂等降级：后续记录经既有 ErrorLogFileSink 直写，捕获链永不阻断（D-01/D-02 静默失败哲学）；降级为排他模式，绝不双写
    - 对调用方的可观察语义与现状逐项一致：顺序（record 序=落盘序）、append+UTF-8+flush、severity 门（仅 error/fatal）、drain 可重入、dispose 幂等、logsAvailable 成功恢复/失败置假、失败上报首条+每 50 条限流
    - ErrorLogFileSink、DelegatingDiagnosticLogEffect、ErrorReporter effects 链、main.dart 四者零 diff；error_log_file_sink_test.dart 全部 6 用例原样通过
  artifacts:
    - lib/kernel/diagnostics/isolated_error_log_sink.dart（消息协议 + worker 入口 + IsolatedErrorLogSink，单文件 <400 行）
    - test/diagnostics/isolated_error_log_sink_test.dart（真实临时文件纵切 + 心跳 + 降级三路径）
    - lib/ui/dialogs/settings/diagnostic_log_target.dart 仅第 62 行 sink 构造换名 + 文档注释同步
  key_links:
    - DiagnosticLogTarget.activateResolved → IsolatedErrorLogSink（取代 ErrorLogFileSink 构造，唯一生产构造点）
    - IsolatedErrorLogSink.record → severity 门 → formatDiagnosticPack(logPath) → SendPort _WriteRequest → _logWorkerEntry → File.openSync(append)+writeStringSync(utf8)+flushSync → _WriteOk/_WriteFailed ack
    - ack 回流 → 失败限流门（计数+logsAvailable+degradedOutput）→ 与 ErrorLogFileSink 可观察行为一致
    - worker onExit/onError → 幂等 _degrade → 惰性 ErrorLogFileSink(file:, degradedOutput:) 接管后续 record
---

<objective>
日志文件写入挪进常驻 logging isolate + 心跳日志——补上错误反馈管线唯一的技术短板：主 isolate 卡死时文件写入不再跟着卡，卡死期间已递送的记录零丢失，卡死时间窗由心跳空档可读。

Purpose: 出错可定位的最后一环——主线程冻结不再把错误证据困在内存里，进程被杀也不丢已递送记录。
Output: lib/kernel/diagnostics/isolated_error_log_sink.dart（约 350 行，零新增依赖，dart:isolate 为 SDK）；DiagnosticLogTarget 一行换线；新测试文件三组用例全绿；四个冻结文件零 diff。
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.claude/CLAUDE.md
@lib/kernel/diagnostics/error_log_file_sink.dart
@lib/kernel/diagnostics/error_reporting_dependencies.dart
@lib/ui/dialogs/settings/diagnostic_log_target.dart
@test/diagnostics/error_log_file_sink_test.dart

关键事实（已核查，执行时不必重读全文件）：

- 唯一生产构造点：diagnostic_log_target.dart:62 `effect.activate(sink: ErrorLogFileSink(file: file), resolvedPath: file.path)`。main.dart:152 经协调器调用，不直接构造 sink。换线只动这一行。
- 冻结契约（error_log_file_sink_test.dart 6 用例直接构造 ErrorLogFileSink）：severity 门只看 severity 不看 acceptance；pack 由 formatDiagnosticPack(report, logPath) 生成、以 `\n\n` 结尾；drain 可重入；dispose 连调两次安全；logsAvailable 初始 true、失败置假、成功恢复；degradedOutput 首条+每 50 条（_failureReportInterval=50）；_defaultDegradedOutput 只向 KernelLogger 传 errorType 不传 message。
- 该类被 test/diagnostics/global_error_hooks_test.dart:156 与 error_feedback_settings_store_test.dart:87 直接构造——所以 ErrorLogFileSink 本体必须零 diff（它同时是本方案的降级回退实现）。
- Phase 2 语义锚点（不得破坏）：append+UTF-8+flush 逐条写、非投毒 Future 链、失败隔离、错误上报限流。isolate 化是写入执行位置的替换，不是语义修改。
- activateResolved 的既有消费者测试（diagnostic_log_target_test.dart 断言 logPath；general_settings_content_test.dart:92-98 fire-and-forget dispose，注释明言「sink 不持 OS 句柄，残余链无害」）——worker 采用**每消息现开现关句柄**设计（不持常驻句柄）正是为了兼容这两处：空闲 worker 零 OS 句柄，teardown 删临时目录不受阻，fire-and-forget dispose 无害。
- 本机 headless 全量 flutter test 有预存失败（mdk.dll FFI 等历史项，见 MEMORY）——验证锚定：新测试文件 + 三个相邻测试文件全绿 + 全量无新增失败。
- 若 Task 1 首用例（真实 isolate+真实文件纵切）在 headless 下 RED 且根因是 isolate 环境限制而非实现缺失：停下上报，不硬写其余用例（规划钦定的「先验证再写全」）。

## 隔离边界（钦定，执行时不得越界）

| 归属 | 类/函数 | 改动 |
|------|---------|------|
| 主 isolate | DelegatingDiagnosticLogEffect（error_reporting_dependencies.dart） | 零 diff（接口冻结） |
| 主 isolate | ErrorReporter / effects 链 / GlobalErrorHooks | 零 diff |
| 主 isolate | ErrorLogFileSink（error_log_file_sink.dart） | 零 diff（降级回退实现 + 自身 6 用例契约） |
| 主 isolate | formatDiagnosticPack + severity 门 | 保持 main 侧纯函数，由新 sink 调用（格式化不需要进子 isolate，String 天然可跨 SendPort） |
| 主 isolate | main.dart | 零 diff |
| 主 isolate | DiagnosticLogTarget | 仅 activateResolved 内 sink 构造换名一行 + 文档注释同步 |
| 子 isolate | _logWorkerEntry（新文件顶层函数，Isolate.spawn 要求） | 新增 |
| 主 isolate | IsolatedErrorLogSink（新文件，implements DiagnosticLogSink） | 新增：severity 门/格式化/消息协议/ack 失败门/心跳 Timer/降级编排 |

## 消息协议（新文件内私有 sealed 类，同 isolate 组内可直接 SendPort 递送）

主 → 子：_WriteRequest(id:int, pack:String)；_DrainRequest(id:int)；_CloseRequest(id:int)
子 → 主：_WorkerHandshake(requestPort:SendPort)；_WriteOk(id:int)；_DrainOk(id:int)；_ClosedOk(id:int)；_WriteFailed(id:int, errorType:String)

握手时序：主侧建 ReceivePort（就绪口）→ _WorkerConfig(replyTo: 就绪口 sendPort, path: file.path) 经 spawnWorker 递给子 isolate → _logWorkerEntry 建 ReceivePort（请求口）并回 _WorkerHandshake → 主侧存请求口、flush 缓冲、启动心跳。握手前到达的 record 缓冲为 (report, acceptance) 对（降级重放需原始 report）；心跳 tick 在握手前直接丢弃（错过一条 30s 心跳无害）。

子侧每消息写盘语义（镜像 writeAsString append 的逐次开合）：File(path).openSync(mode: FileMode.append)（不存在则创建）→ writeStringSync(pack, encoding: utf8) → flushSync() → finally closeSync()。任一步失败 → best-effort closeSync + 回 _WriteFailed(id, error.runtimeType.toString())；成功回 _WriteOk(id)。_CloseRequest 处理完此前全部请求后 Isolate.exit(请求口, _ClosedOk(id))。

心跳行格式（钦定）：'[heartbeat] main alive @ ' + DateTime.now().toUtc().toIso8601String() + '\n'——单行、可 grep（'main alive'）、以单 \n 结尾与报告块的双 \n 视觉区分。
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: 核心竖切——worker isolate + IsolatedErrorLogSink 的 record/drain/dispose + ack 失败门（RED→GREEN）</name>
  <files>lib/kernel/diagnostics/isolated_error_log_sink.dart, test/diagnostics/isolated_error_log_sink_test.dart</files>
  <behavior>
    - Test 1（真实文件纵切 + 环境证明，最先写）：临时目录 fixture（复用 error_log_file_sink_test 的 _LogFixture 模式）；构造 IsolatedErrorLogSink(file:)；直接 record 两条含中文消息的 error 报告 + 一条 warning 报告（_report helper 本地复刻）；drain；读文件：两条 error pack 均在且按 record 序、不含 warning 消息、以 raw stack 加双换行结尾、不含 heartbeat 字样（默认 30s 间隔在快测内不触发，此断言顺带锁定心跳不经 severity 门乱入）。
    - Test 2（drain 可重入 + dispose 幂等）：连发 3 条后 drain 两次都正常完成；dispose 两次第二次不抛不挂。
    - Test 3（dispose 后 record 走回退，对应「effect remains reusable」契约）：record → dispose → 再 record → drain → 文件含两条记录（第二条经回退 ErrorLogFileSink 直写）。
    - Test 4（真实写失败隔离 + 恢复 + 可用性语义）：record→drain 落盘；删除整个临时目录；record→drain → logsAvailable 为 false 且 degradedOutput 恰好 1 次；重建目录后 record→drain → logsAvailable 恢复 true 且 degradedOutput 仍 1 次（证明每消息现开句柄可恢复，镜像既有「restores availability」用例）。
    - Test 5（50 连续失败限流）：目录删除后连发 50 条 → drain/dispose → degradedOutput 恰好 2 次（首条+第 50 条）、logsAvailable false。
  </behavior>
  <action>
先建 test/diagnostics/isolated_error_log_sink_test.dart，落 Test 1-5（fixture 与 _report helper 本地复刻，不 import 测试文件私有符号），运行 flutter test 确认 RED（类不存在）。然后新建 lib/kernel/diagnostics/isolated_error_log_sink.dart（library; 头 + 双语 /// 文档，import dart:async/dart:io/dart:isolate + flutter/foundation + 本目录 error_report/error_reporting_dependencies/error_log_file_sink/diagnostic_pack_formatter/kernel_logger）：

一、协议类：按 context 的消息协议表定义私有 final 类（const 构造、全 final 字段），sealed 两条方向各一组，模式匹配用 switch。
二、_logWorkerEntry 顶层函数：收 _WorkerConfig，建请求口，先回 _WorkerHandshake(请求口 sendPort)，然后 for-each 监听请求：_WriteRequest 走现开现关同步写（FileMode.append + writeStringSync 默认 utf8 + flushSync + finally closeSync，try/on Object 包裹，失败 best-effort closeSync 后回 _WriteFailed 带 error.runtimeType.toString()——只传 runtimeType 字符串不传 message，与 _defaultDegradedOutput 纪律一致）；_DrainRequest 回 _DrainOk；_CloseRequest 回 _ClosedOk 并 Isolate.exit。
三、IsolatedErrorLogSink implements DiagnosticLogSink：构造参数 file + degradedOutput（默认复刻 ErrorLogFileSink._defaultDegradedOutput 的 KernelLogger warn + errorType-only context，包 try 容纳 logger 未初始化）。字段：logsAvailable ValueNotifier 初始 true、_consecutiveFailures、_failureReportInterval=50、_nextId、请求口可空、_pending List 缓冲、_modeReady Completer、_closed 标记、_fallback 可空。私有 _startWorker：建就绪口、组装 _WorkerConfig、经 spawnWorker 参数（本任务不引参数，直接调用私有 _defaultSpawnWorker 顶层函数）spawn，onExit/onError 端口接 _handleWorkerGone（本任务留空实现，Task 2 填充降级）。握手监听：存请求口 → flush _pending（逐条 severity 门+formatDiagnosticPack(logPath)+发 _WriteRequest）→ 完成 _modeReady。record：永不上抛（effect 契约）；_closed → _ensureFallback().record；未握手 → _pending.addLast(report, acceptance)；已握手 → severity 门（仅 error/fatal，不看 acceptance，与 ErrorLogFileSink 相同）→ format（包 try，失败走失败门）→ 发 _WriteRequest(++_nextId)。ack 处理：_WriteOk → 计数归零+available true；_WriteFailed → 计数+available false+shouldReport（首条或 %50==0）时调 degradedOutput(StateError 包 errorType, StackTrace.empty)，degradedOutput 调用包 try。drain：await _modeReady → 发 _DrainRequest(++_nextId) + Completer 对 _DrainOk。dispose：记忆化 Future；发 _CloseRequest → await _ClosedOk → 置 _closed；重复调用返回同一 Future；_closed 后 record 走 _ensureFallback（惰性构造 ErrorLogFileSink(file:, degradedOutput:)，构造包 try，失败则丢弃并 degradedOutput——降级永不上抛）。

TDD 提交节奏：RED 提交 test(quick-260901-eyw): add failing tests for isolated log sink core；GREEN 提交 feat(quick-260901-eyw): implement logging isolate core。GREEN 后 dart format 两文件。注释随写随补（/// 双语 + 非显而易见处行内 why：握手缓冲、每消息现开句柄的理由、errorType-only 纪律）。
  </action>
  <verify>
    <automated>flutter test test/diagnostics/isolated_error_log_sink_test.dart && flutter analyze</automated>
  </verify>
  <done>Test 1-5 全绿（真实 isolate + 真实临时文件）；flutter analyze 0 error；worker 子 isolate 不持常驻句柄（每消息现开现关）；record/drain/dispose/logsAvailable 对调用方表现与 ErrorLogFileSink 契约一致；Test 1 同时完成 headless isolate 可用性验证。</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: 心跳 Timer + spawn 失败/worker 死亡降级 + 协调器一行换线（RED→GREEN）</name>
  <files>lib/kernel/diagnostics/isolated_error_log_sink.dart, lib/ui/dialogs/settings/diagnostic_log_target.dart, test/diagnostics/isolated_error_log_sink_test.dart</files>
  <behavior>
    - Test 6（心跳写入）：heartbeatInterval 注入 1ms 构造 sink；真实等待约 60ms；dispose；读文件 contains 'main alive @' 至少一次（真实 Timer 走主 isolate 事件循环，flutter test 非 FakeAsync 的 test() 块内可用真实延迟）。
    - Test 7（spawn 失败回退 + 缓冲重放）：spawnWorker 注入同步抛 StateError 的假缝；record 两条 → drain → 文件经回退 ErrorLogFileSink 含两条记录、logsAvailable true、degradedOutput 零调用（降级是模式切换非写失败，静默哲学）；drain 在未握手期调用也正常完成（经 _modeReady → 降级路径解决）。
    - Test 8（worker 意外死亡降级）：spawnWorker 注入 passthrough 假缝捕获真 Isolate；record→drain 落盘；isolate.kill(priority: Isolate.immediate)；真实轮询（Future.delayed 循环，上限 2s）直到 isDegradedForTesting 为 true；record → drain → 文件含新记录（经回退直写）。
  </behavior>
  <action>
先在测试文件追加 Test 6-8 确认 RED（heartbeatInterval 参数与 spawnWorker 缝尚不存在）。然后改 isolated_error_log_sink.dart：

一、WorkerSpawner typedef：Future<Isolate> Function(void Function(_WorkerConfig) entry, _WorkerConfig config, {SendPort? onExit, SendPort? onError})；顶层 _defaultSpawnWorker 以 Isolate.spawn(entry, config, onExit:, onError:, errorsAreFatal: false) 实现（显式 errorsAreFatal: false，写 worker 自容错注释）；IsolatedErrorLogSink 构造新增可选 spawnWorker（/// 注明仅测试缝）与 heartbeatInterval（默认 const Duration(seconds: 30)）。
二、_startWorker 改经注入缝：同步 try 包裹调用，失败走降级；onError/onExit 都汇入幂等 _handleWorkerGone → _degradeAndReplay（once-guard）：cancel 心跳 Timer → 惰性 _ensureFallback → _pending 重放（原始 report 经 fallback.record 重格式化，formatDiagnosticPack 纯函数输出逐字符一致）→ 完成 _modeReady（使未决 drain 正常解决）。_handleWorkerGone 需区分干净关闭（已收 _ClosedOk 后的退出不降级）与意外退出；同步 spawn 失败与握手前异步失败共用 _degradeAndReplay 的幂等性。降级全程不上抛。
三、心跳：握手后 Timer.periodic(heartbeatInterval)，tick 若已握手且未降级未关闭则发 _WriteRequest(++_nextId, 心跳行)——不经 severity 门但共享 ack 失败门（磁盘健康信号语义一致）；缓冲期/降级期 tick 丢弃；dispose 与降级路径 cancel Timer。
四、@visibleForTesting bool get isDegradedForTesting（供 Test 8 轮询降级完成，消除 kill→onExit 竞态）。
五、diagnostic_log_target.dart 第 62 行：ErrorLogFileSink(file: file) 换为 IsolatedErrorLogSink(file: file)，import 同步，activateResolved 的 /// Side effect 注释同步一句话（说明写入已移交常驻 logging isolate、失败降级经既有 sink）。这是 sink 换线的唯一接线点；协调器其余逻辑（attach 一次性、激活一次性锁）零改动。

回归验证三个相邻文件全绿：error_log_file_sink_test（契约冻结证明）、diagnostic_log_target_test（activateResolved 换线后 logPath 断言不变）、general_settings_content_test（fire-and-forget dispose 对无常驻句柄的空闲 worker 无害——若此处因隔离化超时，回头检查 worker 是否误持常驻句柄，而不是改测试）。TDD 提交：test(quick-260901-eyw): add heartbeat and degradation tests；feat(quick-260901-eyw): wire heartbeat and fallback into log isolate。GREEN 后 dart format。
  </action>
  <verify>
    <automated>flutter test test/diagnostics/isolated_error_log_sink_test.dart test/diagnostics/error_log_file_sink_test.dart test/diagnostics/diagnostic_log_target_test.dart test/widget/dialogs/general_settings_content_test.dart && flutter analyze</automated>
  </verify>
  <done>Test 6-8 全绿且 Task 1 五用例零回归；三个相邻既有测试文件全绿；心跳 30s 默认 + 注入缝；spawn 失败与 worker 死亡均幂等降级到 ErrorLogFileSink 且降级永不上抛；DiagnosticLogTarget 仅一行换线；analyze 0 error。</done>
</task>

<task type="auto">
  <name>Task 3: 冻结契约零 diff 证明 + grep 门 + 全量无新增失败 + 收尾提交</name>
  <files>test/diagnostics/isolated_error_log_sink_test.dart</files>
  <action>
一、零 diff 证明（本 quick 最硬的验收）：git diff --quiet -- lib/kernel/diagnostics/error_log_file_sink.dart lib/kernel/diagnostics/error_reporting_dependencies.dart lib/main.dart 三文件逐一 exit 0；git diff --stat 确认 lib/ui/dialogs/settings/diagnostic_log_target.dart 仅数行（换名 + import + 注释）。
二、kernel grep 门：对 lib/kernel/diagnostics/isolated_error_log_sink.dart 过滤 /// 文档行后不得出现 debugPrint 或裸 print（新 kernel 文件守 KernelLogger 纪律；默认 degradedOutput 走 KernelLogger.I.warn）。
三、全量 flutter test：无新增失败——判定标准为失败集合与 MEMORY 记录的预存清单（mdk.dll FFI 加载等历史项）一致；任何 test/diagnostics/ 或 test/widget/dialogs/ 下的失败即回归，必须修复后才算 done。若预存失败基线不确定，先 git stash 本改动跑一次基线再 pop 对照（stash 鉴别法，MEMORY 有先例）。
四、dart format 覆盖全部触碰文件；确认 pubspec.yaml/pubspec.lock 零 diff（dart:isolate 是 SDK，零新增依赖）。
五、收尾提交：docs(quick-260901-eyw): finalize logging isolate with frozen-contract proofs（若前两任务已按节奏提交，此处只提交零散收尾）。
  </action>
  <verify>
    <automated>git diff --quiet -- lib/kernel/diagnostics/error_log_file_sink.dart lib/kernel/diagnostics/error_reporting_dependencies.dart lib/main.dart && grep -v '^\s*///' lib/kernel/diagnostics/isolated_error_log_sink.dart | grep -c 'debugPrint' | grep -qx '0' && flutter test test/diagnostics/ && flutter analyze</automated>
  </verify>
  <done>三个冻结文件零 diff；新 kernel 文件无 debugPrint/裸 print；test/diagnostics/ 目录全绿；全量 flutter test 无新增失败（预存清单外零新增）；零新增依赖成立；analyze 0 error。</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| 主 isolate ↔ logging isolate | SendPort 进程内消息（pack 字符串、id、errorType） |
| logging isolate → 文件系统 | 子 isolate 对 ErrorLogLocation.resolve 受控路径做 append 同步写 |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-EYW-01 | Denial of Service | spawn 失败 / worker 意外退出（onExit/onError） | medium | mitigate | 幂等 _degradeAndReplay：缓冲重放 + 后续 record 经既有 ErrorLogFileSink 直写，捕获链永不阻断（D-01/D-02 静默失败哲学）；once-guard 防重复降级 |
| T-EYW-02 | Denial of Service | 主侧未决消息缓冲（SendPort 队列） | low | accept | 写入频率=错误频率且受 reporter 有界 FIFO 上游约束；心跳 30s 一条；VM 自管队列，无放大路径 |
| T-EYW-03 | Information Disclosure | 跨 SendPort 内容 | low | accept | 同进程同特权 isolate 组，不出进程边界；失败只传 runtimeType 字符串不传 message（errorType-only 纪律与 _defaultDegradedOutput 一致），pack 内容与现状直写完全相同 |
| T-EYW-04 | Tampering | 日志文件写入 | low | accept | 路径源为 ErrorLogLocation.resolve 既有受控链（校验语义零接触）；append-only + UTF-8 + flush 与 Phase 2 决策逐字一致；worker 绝不接收用户可控路径 |
| T-EYW-05 | Denial of Service | 心跳 Timer / dispose 生命周期泄漏 | low | mitigate | Timer 在 dispose 与降级两路径均 cancel；dispose 经 _ClosedOk 确认后置 _closed，记忆化 Future 保证幂等 |
</threat_model>

<verification>
- flutter analyze 0 error（全项目）
- test/diagnostics/isolated_error_log_sink_test.dart 全绿（真实 isolate + 真实临时文件 + 心跳 + 三条降级路径）
- error_log_file_sink_test.dart、diagnostic_log_target_test.dart、general_settings_content_test.dart 全绿（既有契约与消费者零回归）
- 零 diff 门：ErrorLogFileSink / DelegatingDiagnosticLogEffect / main.dart 三文件 git diff --quiet 通过
- 全量 flutter test 失败集合与 MEMORY 预存清单一致（无新增失败）
- grep 门：新 kernel 文件过滤文档行后零 debugPrint/裸 print；pubspec 零 diff（零新增依赖）
</verification>

<success_criteria>
主 isolate 卡死时已递送错误记录由常驻 logging isolate 同步落盘零丢失；日志心跳空档可读出卡死时间窗；spawn 失败/worker 死亡幂等降级到既有直写且捕获链永不阻断；顺序/UTF-8/severity/drain/失败隔离/logsAvailable 语义对调用方逐项与现状一致；ErrorLogFileSink 等四个冻结文件零 diff；零新增依赖；analyze 0 error。
</success_criteria>

<output>
Create `.planning/quick/260901-eyw-logging-isolate/260901-eyw-SUMMARY.md` when done
</output>
