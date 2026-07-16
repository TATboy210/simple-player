# Phase 15: 契约固化与基线盘点 - Research

**Researched:** 2026-07-17
**Domain:** Dart/Flutter 接口契约文档规约、行为契约测试、可复现静态审计工具、正交状态建模
**Confidence:** MEDIUM-HIGH（核心发现基于对 LIVE 代码的直接验证；文档规约部分基于 Context7 官方 dartdoc 文档；契约测试组织模式与 mpv/ExoPlayer 生命周期精度部分为训练知识，已标注 `[ASSUMED]`）

## Summary

Phase 15 的研究目标不是"要做什么"（23 项决策已全部锁定），而是"怎么做"——为 4 个 BASE 需求提供可执行的具体规约、模板与工具设计。本次研究对 LIVE 代码做了逐项核对（而非依赖 `.planning/codebase/` 陈旧快照），发现了三个对规划有直接影响的**具体性差异**：(1) BASE-02 引用的 "121 处/30 文件" `package:logger` 调用点数字，在当前 LIVE 代码上重新执行同源正则统计，实测为 **84 处/28 文件**——这不是某处出错，而恰恰印证了 D21 锁定的设计原则本身（脚本必须读 LIVE code，任何静态历史数字都会漂移）；(2) `openGeneration` 计数器在 LIVE 代码中存在于**两个独立文件**（`fvp_engine.dart:194` 与 `playback_navigator.dart:33`），而 CONTEXT.md 的 canonical_refs 只显式点出前者——这一发现实际上早已被上游 `.planning/research/PITFALLS.md`（Pitfall 8）记录，但未被 Phase 15 的 canonical_refs 收录，规划时应予以补全；(3) `EngineStateView` 的只读 getter 实际数量为 **13 个 `ValueNotifier` getter**（外加 1 个非 notifier 的 `mediaInfo` getter），而 D3 描述为"12 个"——同时 `media_engine.dart` 自身的类级 `///` 文档注释写的是"将 6 个 ISP 接口聚合"，但其 `implements` 子句实际列出 7 个接口（`EngineStateView` + 6 个能力接口）——这是一处存在于 LIVE 代码自身内部的注释-代码不一致，值得作为 Phase 15 审计的副产物顺手修正。

除这些具体性核对外，本研究为规划提供了三类可直接落地的素材：(a) 基于 Context7 官方 `dart.dev/effective-dart/documentation` 文档验证过的 `///` 契约标签书写惯用法与双语结构范例；(b) 面向"接口而非实现"的契约测试组织范式，包括参数化测试签名、按 ISP 接口分组的目录结构、以及真实坏文件 fixture 的管理方式；(c) 一套具体的 ripgrep 审计脚本设计（含可直接复用的验证命令），以及从"一次性脚本"演进为 Phase 17 CI 闸门的 `--enforce` flag 扩展点设计。

**Primary recommendation:** 契约标签集（`requires:/ensures:/modifies:/states:/throws:`）是项目自创的 Design-by-Contract 惯用法，dartdoc 本身没有原生的 `@requires`/`@ensures` 语法——它们只是遵循 effective_dart 的 `///`+`[bracket-reference]`+单句摘要惯例书写的**自由文本标签行**，靠 grep/正则实现"可查询性"，而不是靠 dartdoc 工具链解析。规划时必须明确：这些标签的"机器可读性"完全依赖 Phase 15 自己写的审计脚本或 Phase 22 的 lint 脚本去 grep 它们，dartdoc 生成的 HTML 文档不会对其做任何特殊渲染或校验。

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| 契约文档固化（`///` 标签） | Kernel（接口层，`lib/kernel/engine/*.dart`） | — | 契约随接口冻结，D1 明确"不设独立 CONTRACT.md"，接口文件是唯一权威落点 |
| 静态调用点审计（logger/MemoryMonitor/openGeneration） | Tooling（`tool/audit/`，独立于 lib/） | Kernel（被审计对象） | 审计脚本是开发时工具，不进入运行时产物；被审计的调用点分布在 Kernel 各层 |
| 契约测试（BASE-04） | Test（`test/`，对 Kernel 接口） | — | 测试对象是 `MediaEngine` 接口契约，不涉及 UI 或适配层；D13 明确"针对接口非实现" |
| 9v6 裁决 + LifecyclePhase 新增 | Kernel（`engine_state_machine.dart` 未来扩展点） | Docs（`PROJECT.md` 派生修正） | 状态语义决策落在 Kernel 状态机文件，但本阶段只冻结契约文字，不改代码 |

**说明：** Phase 15 本身不产出任何 UI/Adapter/Backend 代码——上表刻意标注"Secondary Tier: —"以强调这一点，这是 D1 主题"避免第二真相源"在架构层面的体现：Phase 15 的产出物全部落在 Kernel 接口文档、独立 Tooling 目录、Test 目录三处，不跨越到适配层或 UI 层。

## Contract Documentation Conventions

### D2 扩展标签集的定位：约定，非 dartdoc 特性

通过 Context7 对 `dart.dev` 官方文档的核对 `[CITED: dart.dev/effective-dart/documentation]`：

- dartdoc 官方支持的特殊语法只有：`///` 触发文档提取、`[Identifier]` 方括号引用当前作用域内的类/方法/参数、`{@template}/{@macro}/{@endtemplate}` 复用文档片段、`{@category}` 侧边栏分类标签。
- **dartdoc 没有原生的 `@requires`/`@ensures`/`@throws` 契约注解语法**（这与 Java 的 `@throws` javadoc 标签或 JML 的 `//@ requires` 是完全不同的工具链——Dart 生态里没有对应的一等公民支持）。
- 因此 D2 的 `requires:/ensures:/modifies:/states:/throws:` 标签集是**项目自创的纯文本惯用法**，其"结构化"完全靠人工遵守固定的行首关键字 + 冒号格式，其"可 grep"完全靠 Phase 15/17/22 自己写的脚本用固定正则去匹配这些行。规划时应在契约文档任务的验收标准中明确写出这一点，避免执行者误以为 dartdoc 会做任何校验。

`[CITED: dart.dev/effective-dart/documentation]` effective_dart 对文档摘要句的要求：单句摘要独立成段、使用第三人称动词描述副作用方法（"Deletes the file..."而非"Delete the file..."）、避免与签名冗余的重复。这一惯例应作为 D2 契约块之外、契约块之前的中文意图行的书写基准（尽管 effective_dart 本身面向英文文档，但"单句摘要+空行+详述"结构可直接套用于双语场景）。

### 推荐的标签行格式（基于 D2/D7/D9 决策文字整理）

```dart
/// 播放指定路径的媒体文件
///
/// requires: state ∈ {idle, opening, paused, completed, error}
/// ensures: state == playing on success
/// states: transitions to {opening, playing, error}
/// modifies: [state], [position], [duration], [lastError]
/// throws: FileError (path 不存在), CodecError (解码器初始化失败)
Future<void> open(String path);
```

- 标签顺序建议固定为 `requires → ensures → states → modifies → throws`（无该项则省略整行，不留空标签），保证 grep 时同类标签总在同一相对位置，便于人工审查时视觉对齐。
- `modifies:` 用方括号列出 `EngineStateView` getter 名（`[state]` 而非 `state`），复用 dartdoc 的 `[Identifier]` 引用语法双重收益：既是契约标签，又是可点击跳转的 dartdoc 交叉引用。`[VERIFIED: 直接复用 dartdoc 官方 [bracket] 语法，无额外工具链成本]`
- `states:` 标签与 `EngineStateMachine._canTransitionTo` 的 switch-expression 存在**故意的**信息重复（D7 明确此为交叉校验设计，不是 DRY 违规）。规划时应在契约测试任务里显式包含"契约标签 states: 与 EngineStateMachine 转换表逐条对照"的校验步骤，而不是仅停留在写契约本身。

### 组契约模式（D3）与 Flutter 官方先例

D3 决定 `EngineStateView` 的 13 个（非 D3 原文的"12 个"，见 Pitfalls）只读 getter 按组共享一份轻量契约，每个 getter 只留一行中文意图 + 指回组契约。这与 Flutter 框架自身的惯用法一致：`[ASSUMED，基于训练知识对 Flutter SDK 源码的了解]` `RenderBox` 的诸多几何 getter（`size`、`constraints` 等）在类级文档中统一声明"只读、在 layout 阶段前访问会抛错"的组级不变量，各 getter 自身只写一行说明，不逐个重复"只读"这类跨 getter 共享的约束。

```dart
/// 播放器只读状态视图 — UI 层监听用
///
/// requires: 无（所有 getter 幂等、无参数、永不 throw）
/// ensures: 返回值反映最近一次内部状态更新；disposed 后返回安全默认值（见 D9）
/// modifies: 无（本接口所有成员均为纯读取，不产生副作用）
abstract class EngineStateView {
  /// 纹理 ID — 用于 Texture 渲染，null 表示尚未就绪
  ValueNotifier<int?> get textureId;

  /// 主播放状态 — 正交 6 值枚举
  ValueNotifier<MediaState> get state;

  // ... 其余 11 个 getter 同样只写一行意图，不重复组契约
}
```

## Behavior Contract Testing Patterns

### 参数化测试签名（D13）

契约测试必须能同时对 `FvpEngine`（Phase 15 baseline）和未来的 `NewFvpEngine`（Phase 21 VERIFY-01 闸门）运行，因此测试函数体必须以 `MediaEngine` 接口类型为参数，而不是直接实例化具体类：

```dart
// test/contracts/engine_state_view_contract_test.dart
void runEngineStateViewContractTests(MediaEngine Function() createEngine) {
  group('EngineStateView contract', () {
    late MediaEngine engine;

    setUp(() => engine = createEngine());
    tearDown(() => engine.dispose());

    test('state getter never throws before any open() call', () {
      expect(() => engine.state.value, returnsNormally);
    });

    test('disposed engine returns safe defaults per D9', () async {
      engine.dispose();
      expect(engine.state.value, MediaState.idle);
      expect(engine.position.value, 0);
    });
  });
}
```

```dart
// test/engine/fvp_engine_contract_test.dart — Phase 15 baseline 挂载点
void main() {
  runEngineStateViewContractTests(() => FvpEngine());
  runPlaybackControlContractTests(() => FvpEngine());
  // ... 每个 ISP 接口一组，D14 锁定的分组
}
```

```dart
// test/engine/new_fvp_engine_contract_test.dart — Phase 21 复用挂载点（现在还不存在，仅为示意）
void main() {
  runEngineStateViewContractTests(() => NewFvpEngine());
  // 同一套契约测试函数，只换 factory —— 这正是 D13 "参数化 accepts MediaEngine" 的落地形态
}
```

`[ASSUMED，训练知识]` 这种"共享测试函数 + 按实现挂载"模式是 Dart/Flutter 生态中验证多实现共享同一接口契约的标准做法，与 Flutter 官方 `flutter_driver`/`integration_test` 生态中"platform interface conformance test"的组织思路一致（例如 `shared_preferences_platform_interface` 的测试套件会被 `shared_preferences_android`、`shared_preferences_ios` 等具体实现分别导入复用）——概念上高度相似，但本研究未在本次会话中对该具体 package 的测试代码做实地验证，故整体标注 `[ASSUMED]`。规划时如需更高置信度佐证，可指示执行者在实现阶段直接查看 pub.dev 上 `shared_preferences_platform_interface` 的 `test/` 目录作对照，而非依赖本研究的转述。

### 按 ISP 接口分组的目录结构（D14）

D14 锁定按接口分组，但只列出了 6 个接口名（`EngineStateView/PlaybackControl/TrackControl/SubtitleConfig/VideoEffectControl/RendererControl`），而 LIVE 代码 `media_engine.dart` 的 `implements` 子句实际包含 7 个接口（多出 `VolumeControl`，见 Pitfalls）。建议目录结构：

```
test/contracts/
├── engine_state_view_contract.dart      # D14 组 1
├── playback_control_contract.dart       # D14 组 2
├── track_control_contract.dart          # D14 组 3
├── subtitle_config_contract.dart        # D14 组 4
├── video_effect_control_contract.dart   # D14 组 5
├── renderer_control_contract.dart       # D14 组 6
├── volume_control_contract.dart         # 规划时需决定：新增第 7 组，还是并入现有组
└── contract_test_runner.dart            # 汇总 import，供各具体实现挂载文件复用
```

### 真实坏文件 fixture 管理（D17）

D17 锁定"真实坏文件 fixture"而非 `FakeEngine` 的脚本化错误注入。`test/fixtures/` 目录当前**不存在**（已通过 `ls test/` 确认），需要新建。建议的最小 fixture 集合（清单细节属规划裁量，此处给出结构参考）：

```
test/fixtures/
├── README.md                    # 说明每个坏文件的用途、如何生成/复现
├── corrupted_header.mp4         # 有效扩展名，但文件头被截断/破坏
├── empty_file.mp4                # 0 字节文件
├── not_a_video.txt               # 非视频内容，伪装 .mp4 扩展名（测试基于内容而非扩展名的探测路径，如有）
└── unsupported_codec.avi         # 使用 FvpEngine/MDK 明确不支持的编码
```

```dart
test('open() with corrupted file transitions to error state', () async {
  final engine = FvpEngine();
  await engine.open('test/fixtures/corrupted_header.mp4');
  expect(engine.state.value, MediaState.error);
  expect(engine.lastError.value, isA<CodecError>());
  engine.dispose();
});
```

**注意（D20 边界）：** 契约测试只覆盖静态行为契约（前置/后置/状态/错误），不覆盖时序/竞态。上例是同步 `await` 后断言最终态，不涉及"打开途中再次打开"之类的竞态场景——那部分留给 Phase 20 的 STATE-05/07（依赖 `NewFvpEngine` 才有的 `OpenGenerationTracker`）。

## Reproducible Baseline Audit

### 核心发现：LIVE 数字与历史数字不一致，且这正是 D21 设计要防范的现象

对 BASE-02 三项审计目标在当前 LIVE 代码上重新执行同源 ripgrep 统计，结果如下：

| 审计目标 | CONTEXT.md/ROADMAP.md/REQUIREMENTS.md 引用数字 | 本次 LIVE 复测实测数字 | 差异说明 |
|---------|------------------------------------------------|----------------------|---------|
| `package:logger` 风格调用（`log\|logEngine\|logBridge\|logServices\|logUi`.方法名） | 121 处 / 30 文件 | **84 处 / 28 文件** [VERIFIED: ripgrep on lib/, 2026-07-17] | 差异 37 处/2 文件；根源见下 |
| `MemoryMonitor.start()`/`.snapshot()` 生产调用点 | 2 处 | **2 处**（`lib/main.dart:16`、`lib/kernel/utils/debug_exporter.dart:57`） [VERIFIED] | 完全一致 |
| `openGeneration` 引用 | 仅点出 `fvp_engine.dart:194` | **分布于 2 个文件**：`fvp_engine.dart`（194/250/258/298/307 行）+ `playback_navigator.dart`（33/36/47/64/94 行） [VERIFIED] | canonical_refs 遗漏第二处 |

**根源追溯（追加发现）：** "121 处/30 文件" 这一数字并非 Phase 15 自身产出，而是来自更早的里程碑级研究文档 `.planning/research/PITFALLS.md` 与 `.planning/research/SUMMARY.md`（v3.0 milestone 定义阶段的产物，日期早于 Phase 15 的 discuss-phase）。这两份文档在多处引用"121 call sites across 30 files"作为既定事实，并被后续的 ROADMAP.md/REQUIREMENTS.md/15-CONTEXT.md 原样承袭，从未在这条链路上重新验证过。**这恰好是 D21 决策文字本身预见并设计防范的场景**：15-CONTEXT.md D21 原文写道"数量漂移可在 P17 CI 闸门捕获"——现在这个漂移在 Phase 15 阶段就被捕获了，比预期更早，这是脚本方案优于静态文档方案的直接证据，不是任何人的失误。

同样，`.planning/research/PITFALLS.md`（Pitfall 8）**早已记录**"两个 `openGeneration` 计数器"这一事实（"Two `openGeneration` counters (one in the engine, one in the adapter)"一节，虽然原文语境是关于双引擎共存期间的风险，但明确点出了 `fvp_engine.dart:194` 与后续需要统一的第二个计数器），但这条信息未被收录进 15-CONTEXT.md 的 canonical_refs——这不是决策错误（决策仍然成立），而是一个规划阶段应当补全的引用完整性缺口。

**规划建议：** 不要在 PLAN.md 或任何契约文档里写死"121 处"或"30 文件"这类数字。所有面向 BASE-02 的任务描述应该写"运行 `tool/audit/inventory.dart`（或等价脚本）产出的实际数字"，把数字的确定权完全交给脚本的首次真实运行，文字描述中只保留审计目标（哪些符号、哪些前缀）而不保留具体计数。

### 复现本次审计所用的确切命令（供审计脚本设计参考）

```bash
# package:logger 风格调用点统计（按调用点数）
rg -o "\b(log|logEngine|logBridge|logServices|logUi)\.(t|d|i|w|e|f|v)\(" --type dart lib/ | wc -l

# 按文件数统计
rg -l "\b(log|logEngine|logBridge|logServices|logUi)\.(t|d|i|w|e|f|v)\(" --type dart lib/ | wc -l

# MemoryMonitor 生产调用点（注意会命中 memory_monitor.dart 自身的 doc-comment，需要脚本过滤定义文件自身）
rg -n "MemoryMonitor\.(start|snapshot)\(" --type dart lib/

# openGeneration 全部引用（含声明、递增、比较、doc-comment 提及）
rg -n "openGeneration|_openGeneration" --type dart lib/
```

### ripgrep 脚本 vs. Dart analyzer 脚本：推荐 ripgrep + 手工过滤规则

| 维度 | ripgrep 正则方案 | Dart `analyzer` package 符号解析方案 |
|------|------------------|--------------------------------------|
| 实现成本 | 低——纯 shell/正则，无需引入 `analyzer` 依赖 | 高——需要用 `package:analyzer` 构建 AST，解析 `MethodInvocation` 节点并做符号绑定 |
| 精确度 | 中——正则会误报 doc-comment 内的提及（如 `memory_monitor.dart` 自身文档里出现 `MemoryMonitor.start()` 字样），需要脚本自行加"排除定义文件自身"之类的过滤规则 | 高——AST 级别可精确区分声明/调用/注释，不会误报 |
| 维护成本 | 低——正则模式随符号改名需要手动更新，但改动量小 | 中——AST 遍历逻辑更复杂，但对符号重命名更鲁棒（可用 `Element` 而非字符串匹配） |
| Phase 15 决策依据 | **D21/D23 已锁定"可重跑 grep 脚本"**，且项目当前无引入 `package:analyzer` 作为开发依赖的先例 | 不符合已锁定决策，仅作对比参考 |

**结论：`[VERIFIED: D21/D23 已锁定]`** Phase 15 应使用 ripgrep（或等价 shell 脚本），不使用 `analyzer` 包。规划时应在脚本设计中明确写出"过滤规则"这一步骤（排除定义文件自身的 doc-comment 误报），因为本次 LIVE 复测已经实地遇到了这个问题（`memory_monitor.dart` 自身包含 2 处会被朴素正则误报的文档提及）。

### 快照输出格式建议

D21 要求"提交输出快照供下游 gsd-planner 直读 + 人类审查"。建议双格式输出：

```
tool/audit/
├── inventory.sh                          # 或 inventory.dart —— 可重跑脚本本体
└── README.md                             # 使用说明 + --enforce 演进说明（占位，Phase 17 填充语义）

.planning/phases/15-contract-freeze-baseline-audit/
├── 15-BASELINE-AUDIT.json                # 机器可读——供下游 gsd-planner/CI 直接消费
└── 15-BASELINE-AUDIT.md                  # 人类可读——markdown 表格视图，人工审查用
```

```json
{
  "generated_at": "2026-07-17T00:00:00+08:00",
  "script_version": "1.0.0",
  "targets": {
    "package_logger_usage": {
      "total_call_sites": 84,
      "total_files": 28,
      "breakdown": { "log": 64, "logEngine": 9, "logBridge": 11, "logServices": 0, "logUi": 0 }
    },
    "memory_monitor_calls": {
      "total_call_sites": 2,
      "locations": ["lib/main.dart:16", "lib/kernel/utils/debug_exporter.dart:57"]
    },
    "open_generation_references": {
      "total_files": 2,
      "locations": ["lib/kernel/engine/fvp_engine.dart", "lib/kernel/services/playback_navigator.dart"]
    }
  }
}
```

### `--enforce` 演进路径（供 Phase 17 承接，非本阶段决策）

D23 锁定"同脚本加 `--enforce` flag 即变闸门"。Phase 15 只需确保脚本设计上**不阻断**这一路径，即：脚本的核心统计逻辑与"是否失败退出"逻辑分离成两个函数/两段代码，Phase 17 只需新增一个 flag 分支调用现有统计函数并比较阈值，不需要重写统计逻辑本身。Phase 15 无需实现 `--enforce` 本身，但脚本结构应体现这种可扩展性（例如把统计结果作为函数返回值而非直接 print，方便 Phase 17 复用同一函数做阈值比较）。

## 9v6 + Lifecycle State Precedent

D5-D12 的核心设计——独立正交的 `LifecyclePhase { alive, disposing, disposed }` 枚举与既有 6 值 `MediaState` 分离——在业界主流媒体播放器架构中有明确先例，本研究简要确认这一先例并指出规划应警惕的具体陷阱，**不重新论证决策本身**（决策已锁定）。

### 先例确认

`[ASSUMED，训练知识，与项目既有 memory 笔记方向一致]` mpv 与 AndroidX Media（ExoPlayer）均将"播放状态"与"资源生命周期"建模为两条独立的轴：

- **ExoPlayer**：`Player.getPlaybackState()` 返回 `STATE_IDLE/BUFFERING/READY/ENDED` 这类播放语义状态，与 `Player.release()` 的资源释放完全是另一套 API——调用 `release()` 后不存在"播放状态机进入 RELEASED 状态"这种设计，而是约定"release 后不得再调用任何方法"，本质上与 D11"disposing 对调用者不可见（同步瞬态）"的设计取向一致：**资源释放是终态化的单向操作，不参与常规状态机的转换表**。
- **mpv**：核心播放循环（`run_playloop`）的状态与 `mpv_terminate_destroy()` 的销毁流程完全独立，销毁是同步阻塞调用（等待所有线程退出），没有"正在销毁"这一可观察的中间状态暴露给调用方——与 D11"disposing 同步瞬态、调用者只观察 disposed"的设计一致。

这两个先例都支持 D5-D12 已锁定设计的合理性：**将 dispose 语义从主状态机剥离为正交枚举，且对外表现为同步、不可逆的终态转换，是业界惯用做法而非项目自创的冒险设计**。

### 规划应警惕的具体陷阱（非重新论证，仅补充执行期提醒）

1. **D9"disposed 后 getter 返回安全默认值"的实现代价**：ExoPlayer 的等价设计选择是"release 后调用任何方法行为未定义"（更激进，不保证安全默认值），而 D9 选择了更宽松的"安全默认值，永不 throw"。这意味着 `FvpEngine.dispose()` 之后，所有 13 个 `EngineStateView` getter 的实现都需要显式的 `if (_lifecyclePhase == LifecyclePhase.disposed) return <safe default>;` 分支——如果只在部分 getter 加了这个守卫，会出现"有的 getter 安全、有的 getter 仍访问已释放的底层资源"的不一致 bug，且这类 bug 只有在 dispose 后仍被调用时才会暴露（容易被单元测试忽略，因为多数测试在 dispose 后立即结束用例）。**规划时应确保契约测试覆盖率包含"每一个 getter 在 disposed 后调用一次"，不能只测代表性的 1-2 个**。
2. **D10"error 陷阱态不自动转出"与资源清理的交互**：如果 `FvpEngine` 内部在进入 `error` 态时已经释放了部分底层资源（如纹理），但 `LifecyclePhase` 仍为 `alive`（因为用户没调用 `dispose()`），此时 `recover()` 是否需要重新初始化这部分资源，是 Phase 20 的具体职责，但 Phase 15 的契约测试若要"baseline 捕获 FvpEngine 当前行为"（D16），需要如实记录"当前 FvpEngine 进入 error 态后到底释放了哪些资源"，而不是假设它什么都没释放——这需要实地读代码验证，不能凭空猜测契约文字。
3. **双重 dispose 幂等性的测试盲点**：D8 锁定"double-dispose 幂等 no-op"。测试这一点时容易只测"连续调用两次 `dispose()` 不抛异常"，但更容易漏测的场景是"dispose 后再调用一个 mutating 方法（如 `play()`），该方法是否真的 no-op 而不是抛异常或修改了已经"冻结"的 notifier 值"——D9 要求 mutating 方法在 disposed 后 no-op，这与"disposed 后 getter 返回安全默认值"是两条独立的契约线，测试覆盖需要显式区分。

## Validation Architecture

`.planning/config.json` 中 `workflow.nyquist_validation: true`，本节为强制项。Phase 15 是纯契约/审计阶段，没有运行中的应用可"采样"，因此传统 Nyquist 维度的"采样率"概念需要重新映射为**结构性验证维度**：契约完整性覆盖率、审计脚本可复现性、契约测试通过率（针对旧引擎）。

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test`（内置，项目现有约定，无需新依赖）[VERIFIED: 项目现有 test/ 目录已用此框架] |
| Config file | `pubspec.yaml` dev_dependencies（现有，无需新增） |
| Quick run command | `flutter test test/contracts/` |
| Full suite command | `flutter test --coverage` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BASE-01 | 每个 `MediaEngine`/`EngineStateView` 成员有 requires/ensures/modifies/states/throws 契约标签 | static-check（非运行时测试，是审计脚本的一部分） | `tool/audit/contract_completeness.sh`（需新建） | ❌ Wave 0 |
| BASE-02 | `package:logger`/`MemoryMonitor`/`openGeneration` 调用点盘点可重跑且数字一致 | static-check | `tool/audit/inventory.sh`（需新建，脚本产出与 15-BASELINE-AUDIT.json 比对） | ❌ Wave 0 |
| BASE-03 | 9v6 裁决文字落地 + lifecycle 态清单写入 CONTEXT.md/PROJECT.md | doc-review（人工审查，非自动化测试） | 无自动化命令——由 gsd-plan-check 的 source_grounding 校验 | — |
| BASE-04 | 契约测试对真实 `FvpEngine` 全部通过 | integration（按 D14 分 6-7 组） | `flutter test test/contracts/ --reporter expanded` | ❌ Wave 0（全部为新建文件） |

### Sampling Rate

- **Per task commit:** `flutter test test/contracts/<对应接口组>_contract_test.dart -x`（仅跑当前正在编写的那一组，快速反馈）
- **Per wave merge:** `flutter test test/contracts/`（全部契约测试组）
- **Phase gate:** 全部契约测试对 `FvpEngine` 通过（对应 sc4）+ 审计脚本可重跑两次产出一致结果（对应 sc2 的"可复现"）+ 每个 `MediaEngine`/`EngineStateView` 公开成员均有完整契约标签（对应 sc1，用 `tool/audit/contract_completeness.sh` 校验，而非人工逐个检查）

### Wave 0 Gaps

- [ ] `test/fixtures/` 目录——当前不存在，D17 要求的坏文件 fixture 集合需要从零创建
- [ ] `test/contracts/` 目录——当前不存在，D14 的按接口分组契约测试需要从零创建
- [ ] `tool/audit/` 目录——当前不存在，D23 要求的可重跑审计脚本需要从零创建
- [ ] `tool/audit/contract_completeness.sh`（或等价）——校验 BASE-01 sc1"每个成员有契约"这一验收标准本身需要脚本化，否则只能人工逐个核对 13+N 个成员，容易漏项
- [ ] 框架安装：无需新增（`flutter_test` 已是现有 dev_dependency）

## Pitfalls & Landmines

### Pitfall 1: 历史数字（121/30）已经过时，切勿在 PLAN.md 中固化

**What goes wrong:** 如果规划者把"121 处/30 文件"直接写进 PLAN.md 的任务描述或验收标准里（例如"验证 121 处调用点全部迁移"），一旦审计脚本首次真实运行产出 84/28，会出现"验收标准与脚本实际输出不符"的假性失败，执行者可能误以为脚本写错了，浪费时间去"debug"一个本不存在的 bug。
**Why it happens:** "121/30" 这个数字来自更早的里程碑级研究文档（`PITFALLS.md`/`SUMMARY.md`），经由 ROADMAP.md/REQUIREMENTS.md/15-CONTEXT.md 逐层传抄，从未被重新验证，属于典型的"未经验证的断言被当作既定事实层层传递"。
**How to avoid:** PLAN.md 中所有涉及具体计数的任务描述，只写"审计目标"（哪些符号/前缀），不写具体数字；具体数字完全由脚本首次运行产出，写入 `15-BASELINE-AUDIT.json`，作为该次运行的**记录**而非**预期值**。
**Warning signs:** 任何验收标准写成"验证恰好 N 处"而不是"验证脚本产出与 [文件] 记录一致"的，都是这个陷阱的信号。

### Pitfall 2: `openGeneration` 的 canonical_refs 遗漏第二处，规划任务范围可能画小

**What goes wrong:** 如果 BASE-02 的具体任务只针对 `fvp_engine.dart:194` 做审计（因为这是 CONTEXT.md canonical_refs 唯一显式点出的位置），会漏掉 `playback_navigator.dart` 里独立存在的第二个 `_openGeneration` 计数器，导致 BASE-02 的盘点范围不完整，也为后续 Phase 20/21 埋下隐患（Phase 20 若要统一成单一 `OpenGenerationTracker`，需要先知道当前有几处独立实现）。
**Why it happens:** 这一事实实际上已经被 `.planning/research/PITFALLS.md`（Pitfall 8）记录，但该文档是里程碑级研究产物，未被折叠进 Phase 15 自己的 canonical_refs 列表。
**How to avoid:** 规划 BASE-02 任务时，审计脚本的 `openGeneration` 检索模式应扫描全部 `lib/` 而非仅验证某个已知文件是否存在该模式——本研究提供的 `rg -n "openGeneration|_openGeneration" --type dart lib/` 命令本身就是"扫描全部、不预设位置"的正确用法，规划时应确保脚本采用同样的扫描策略而非硬编码文件路径。
**Warning signs:** 审计脚本如果硬编码了要检查的文件列表（而不是用 glob/递归扫描整个 `lib/`），就会系统性漏掉未预期的第二处、第三处。

### Pitfall 3: `EngineStateView` getter 计数"12 vs 13"的具体性偏差

**What goes wrong:** D3 契约文字写"12 个只读 getter"，若执行者按此数字逐一核对是否所有 getter 都写了契约标签，会在数到第 13 个（`playbackSpeed`）时产生"这个 getter 是不是不在契约范围内"的困惑，或者干脆漏掉。
**Why it happens:** 单纯的计数疏漏，可能是 D3 决策讨论时基于稍早版本的接口代码（`playbackSpeed` getter 可能是后续 v2.1 迭代中追加的）。
**How to avoid:** 契约完整性审计脚本（Wave 0 Gap 中提到的 `contract_completeness.sh`）应该用 AST 或简单的正则从 `engine_state_view.dart` 文件本身**动态提取**所有 getter 签名，逐一核对是否存在对应契约标签，而不是依赖 CONTEXT.md 文字里写死的数字去核对。
**Warning signs:** 任何契约完整性检查如果是"人工数了 12 个然后核对"而非"脚本读文件动态数出实际 getter 数再核对"，都会继承这一偏差。

### Pitfall 4: `media_engine.dart` 自身的类级文档注释与 `implements` 子句不一致（"6 个"vs 实际 7 个接口）

**What goes wrong:** `media_engine.dart` 第 11 行文档注释写"将 6 个 ISP 接口聚合为单一类型"，但第 26-31 行 `implements` 子句实际列出 `EngineStateView` 之外的 6 个能力接口（`PlaybackControl, TrackControl, SubtitleConfig, VideoEffectControl, RendererControl, VolumeControl`）——如果把 `EngineStateView` 也算作"接口"之一（`MediaEngine` 确实 implements 了它），总数是 7；如果只数"能力接口"（不含状态视图），则恰好是 6，与注释吻合。D14 的契约测试分组列表恰好也只列了 6 组（未含 `VolumeControl`），这暗示 D14 讨论时可能也是基于"6 个能力接口"的心智模型，但意外漏掉了 `VolumeControl` 这一个。
**Why it happens:** "接口总数"这一说法本身有歧义（是否把 `EngineStateView` 算进去），导致同一个数字在不同上下文被不同方式解读，进而在 D14 的分组枚举中意外漏掉一个真实存在的接口。
**How to avoid:** 规划 D14 的契约测试目录结构时，应新增 `volume_control_contract.dart` 作为第 7 组（或明确决定并入某个现有组，需给出理由），不能因为 D14 原文只列了 6 个就假设 `VolumeControl` 不需要契约测试。同时建议作为 Phase 15 的顺手修正项，把 `media_engine.dart` 第 11 行的类级文档注释改为准确描述实际的 `implements` 列表（例如"将 EngineStateView 只读状态视图与 6 个控制类 ISP 接口聚合为单一类型"），消除注释与代码的自相矛盾。
**Warning signs:** 任何"接口总数"类的整数断言，都应该用 `implements` 子句里实际列出的类型名逐一核对，而不是依赖任何文字描述里的数字。

### Pitfall 5: 契约标签的"可 grep 性"是脚本约定，不是 dartdoc 保证

**What goes wrong:** 如果执行者假设 `dart doc` 命令生成的 HTML 文档会对 `requires:/ensures:/...` 标签做任何特殊处理（比如单独的"Contract"分区、超链接高亮等），会发现 dartdoc 实际上只是把整段 `///` 文本原样渲染成普通段落，没有任何特殊语义。
**Why it happens:** D2 决策文字提到"可 grep、Phase 22 lint 可校验"，容易被理解为"这是某种正式的、工具链原生支持的标签系统"，但实际上它是纯人工约定的文本格式。
**How to avoid:** 规划 Phase 22（bilingual docs，此为下游阶段但值得在 Phase 15 埋下正确认知）时应明确"lint 校验"指的是 Phase 15/17/22 各自维护的正则/脚本，不是 dartdoc 工具链本身的能力。Phase 15 若要在 PLAN.md 里描述这一点，应避免使用"dartdoc 契约标签"这种可能暗示工具链支持的措辞，改用"约定的 `///` 文本标签，由项目脚本校验"这类更准确的描述。
**Warning signs:** 任何提及"dartdoc 会解析/校验 requires/ensures"之类工具链行为的描述都是这一误解的信号。

## Recommendations for the Planner

1. **BASE-02 任务必须以脚本首次运行的真实输出为准，不得预设具体数字。** 建议 PLAN.md 把"运行 `tool/audit/inventory.sh` 并将输出提交为 `15-BASELINE-AUDIT.json`/`.md`"设计成独立的、任务顺序上靠前的任务，其他任务（如契约文档撰写）如果需要引用调用点数量，应引用这份产出物而非任何历史文档里的数字。
2. **契约文档任务的验收标准应基于"每个 LIVE 代码中实际存在的成员都有对应标签"，而非任何预设计数**。建议先写一个轻量的"提取 `EngineStateView`/`MediaEngine` 及其 6 个能力接口全部公开成员签名"的小脚本（可以是 `contract_completeness.sh` 的核心逻辑），把这个提取结果作为契约撰写任务的输入清单,同时复用于验收检查,避免"写的时候凭记忆数,验收的时候又凭记忆数"两次产生偏差的机会。
3. **D14 的契约测试分组需要在规划阶段明确补上 `VolumeControl` 这一组**（或给出并入某组的明确理由并记录），不要在实现阶段才发现遗漏。
4. **`openGeneration` 的审计与后续文档，需要显式提及 `playback_navigator.dart` 这第二处**，并考虑是否要把这一发现回写进 15-CONTEXT.md 的 canonical_refs（作为审计脚本运行后的知识更新，不是重开决策讨论）。
5. **契约测试的 Wave 0 建设任务（`test/fixtures/`、`test/contracts/`、`tool/audit/` 三个新目录）应作为显式的第一批任务**，因为这三者都是全新基础设施，后续所有契约测试/审计脚本任务都依赖它们先存在。
6. **`media_engine.dart` 类级文档注释的"6 个 ISP 接口"措辞不准确这一项，可以作为 Phase 15 的一个小型顺手修正任务**（与 D18 记录的"PROJECT.md 9态~40边陈旧描述修正"性质类似，都是文档一致性修正，工作量很小，适合与主线任务并行安排）。
7. **Validation Architecture 中的"契约完整性覆盖率"这一验证维度，需要一个脚本化的检查手段（而非人工审查清单）**，建议将其设计为 `tool/audit/` 下与 BASE-02 审计脚本平级的独立脚本，理由是二者都符合"读 LIVE code、可重跑"的同一设计哲学（D21/D23 的同构原则），可以共享部分文件遍历/符号提取的辅助函数。

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BASE-01 | 为每个 `MediaEngine`/`EngineStateView` 成员固化行为契约规约（前置条件、后置条件、允许的 `MediaState` 转换、错误情形、被修改的 `ValueNotifier`） | 本研究提供了经 Context7 核对的 `///` 标签书写惯用法、组契约模式示例、以及 `EngineStateView` 实际 13 getter（非文档所述 12 个）的精确清单，可直接用于任务分解与验收标准设计 |
| BASE-02 | 产出静态调用点盘点：`package:logger` 用法、`MemoryMonitor.start/snapshot`、`openGeneration` 引用 | 本研究提供了 ripgrep 具体命令、快照 JSON/Markdown 双格式设计、`--enforce` 演进路径，并发现历史数字（121/30）已过时（LIVE 实测 84/28）以及 `openGeneration` 存在于两个文件而非一个 |
| BASE-03 | 核对 9 态 vs 6 态差异，决定冻结基线 + v3.0 须补的生命周期态 | 本研究简要确认 mpv/ExoPlayer 的正交状态建模先例支持已锁定的 D5-D12 设计，并补充了 3 项执行期应警惕的具体测试盲点（disposed 后全 getter 覆盖、error 态资源释放的如实记录、mutating 方法 no-op 与 getter 安全默认值的独立测试） |
| BASE-04 | 针对接口（非实现）编写契约测试，作为迁移闸门 | 本研究提供了参数化测试签名范例、按 7 个 ISP 接口（含此前被遗漏的 `VolumeControl`）分组的目录结构、真实坏文件 fixture 集合设计 |
</phase_requirements>

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**契约文档落点（BASE-01，4 项决策）**
- D1 — 契约权威落点：接口 `///` 双语注释（DOC-01 结构）为契约唯一权威落点；不设独立 CONTRACT.md。
- D2 — 契约标签集：扩展 DOC-01 标签集——新增 `requires:`/`ensures:`/`modifies:`；`states:` 承载允许的 MediaState 转换；`throws:` 承载错误情形。
- D3 — getter 契约粒度：`EngineStateView` 12 个只读 getter 按组共享轻量契约——接口顶部组契约，各 getter 一行 `///` 中文意图指回组契约。
- D4 — 实现契约策略：契约权威仅在接口 `///`；`FvpEngine`（旧实现）`///` 薄，仅记录实现特有副作用，不重复契约；冲突以接口为准。

**9v6 裁决 + 生命周期态（BASE-03 + 阻塞约束#2，8 项决策）**
- D5 — 生命周期态建模：独立 `LifecyclePhase { alive, disposing, disposed }` 枚举，与 6 态 `MediaState` 正交。
- D6 — 冻结范围：冻结高层转换语义；完整转换表留 Phase 20。
- D7 — states 标签表示：每方法 `states:` 标签显式列入态/出态；与 `EngineStateMachine` 转换表的重复为故意交叉校验。
- D8 — dispose 契约：`dispose()` 任意态可达 + 终态不可逆；double-dispose 幂等 no-op。
- D9 — disposed 后行为：getter 返回安全默认；mutating 方法 no-op。
- D10 — error 陷阱态：不自动转出，仅显式 `recover()` 或重新 `open()` 可出。
- D11 — disposing 可见性：对调用者不可见（同步瞬态）。
- D12 — recover 可达性：仅可从 error 调用；`transitions to {idle, opening}`（目标态 P20 定）。

**契约测试策略（BASE-04，8 项决策）**
- D13 — 契约测试执行对象：对真实 FvpEngine 跑；参数化 accepts MediaEngine；FakeEngine 不扩展为契约驱动。
- D14 — 契约测试组织：按 ISP 接口分组——`EngineStateView`/`PlaybackControl`/`TrackControl`/`SubtitleConfig`/`VideoEffectControl`/`RendererControl` 各一组。
- D15 — 契约测试覆盖深度：首版优先 `states:`+`throws:`；`ensures`/`modifies` 次轮补。
- D16 — 契约测试覆盖范围：Phase 15 = baseline 捕获 FvpEngine 当前行为；lifecycle 新语义记为 P20 须补清单。
- D17 — 契约测试错误注入：真实坏文件 fixture（`test/fixtures/`）。
- D18 — known gap 清单落点：P20 衍生项记在 CONTEXT.md decisions/deferred。
- D19 — 契约测试断言形式：行为断言 + 从 `states:` 标签/转换表派生参数化测试。
- D20 — 契约测试时序边界：只测静态行为契约；时序/竞态留 P20 STATE-05/07。

**盘点工件 + 陈旧 maps（BASE-02，3 项决策）**
- D21 — 盘点产物形态：可重跑 grep 脚本 + 提交输出快照。
- D22 — 陈旧 codebase maps 处理：加"v2.1 前快照"水印；不扩 Phase 15 范围去刷新。
- D23 — 脚本生命周期与落点：脚本入 `tool/audit/`；输出快照入 `.planning/phases/15-.../`。

### Claude's Discretion

本阶段无用户授权"You decide"项。全部 23 项决策均由用户在 4 区域单问题轮次中显式选定推荐项。下游 gsd-planner 在以下点有实现裁量空间（非本讨论范围）：契约测试 fixture 集具体文件清单、grep 脚本具体语法（ripgrep vs dart script）、`tool/audit/` 目录组织、CONTEXT.md 中 lifecycle-gap 子节是否独立。

### Deferred Ideas (OUT OF SCOPE)

- recover() 目标态 idle vs opening — Phase 20 STATE-04 定。
- lifecycle 完整转换表 — Phase 20 STATE-04 实现时定并回写契约。
- PROJECT.md "9 态~40 边" 陈旧描述修正为"6 态正交 + LifecyclePhase" — Phase 15 派生任务（文档修正，属 Phase 15 产物收尾）。
- `.planning/codebase/` maps 刷新 — 独立 `/gsd-map-codebase` 任务，不在 Phase 15 范围。
- 契约测试 fixture 集完整清单 — gsd-planner 在实现时定。
- Phase 17 LOG-01 CI grep 闸门与 Phase 15 盘点脚本的 `--enforce` 演进 — Phase 17 实现时定。
</user_constraints>

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Dart 生态中"共享测试函数 + 按实现挂载"是验证多实现共享同一接口契约的标准做法，类比 `shared_preferences_platform_interface` 的测试组织方式 | Behavior Contract Testing Patterns | 低——即使该具体先例不完全准确，参数化测试模式本身是 Dart/Flutter 通用做法，不影响 D13/D14 的可执行性 |
| A2 | mpv 的 `mpv_terminate_destroy()` 与 ExoPlayer 的 `release()` 均为同步、不可逆、且不参与主状态机转换表的设计 | 9v6 + Lifecycle State Precedent | 低——此为佐证性先例，不影响已锁定的 D5-D12 决策本身；若细节有误，仅影响"先例是否恰当"这一论证强度，不影响决策执行 |
| A3 | `RenderBox` 等 Flutter 框架源码中存在"组级不变量声明 + 各 getter 一行意图"的先例，佐证 D3 组契约模式 | Contract Documentation Conventions | 低——此为类比佐证，D3 本身已锁定，即使该 Flutter 源码细节记忆有误也不影响 D3 的可执行性 |

## Open Questions

1. **`playback_navigator.dart` 中的第二个 `openGeneration` 计数器是否需要回写进 15-CONTEXT.md 的 canonical_refs？**
   - What we know: 该计数器确实独立存在，且已被更早的里程碑级 `PITFALLS.md` 记录（Pitfall 8），只是未被折叠进 Phase 15 自己的 canonical_refs。
   - What's unclear: 这是否需要触发对 15-CONTEXT.md 的正式修订，还是仅在 PLAN.md/审计脚本设计中口头/文档提及即可。
   - Recommendation: 不需要重开 discuss-phase；建议在 PLAN.md 的 BASE-02 任务描述中直接引用这一发现，并在审计脚本产出的 `15-BASELINE-AUDIT.json`/`.md` 中如实记录两个文件，作为知识更新的落点，不必回改 CONTEXT.md 本身（CONTEXT.md 记录的是决策，不是审计结果）。

2. **D14 遗漏的 `VolumeControl` 契约测试分组，应新增第 7 组还是并入现有组？**
   - What we know: LIVE 代码 `media_engine.dart` 的 `implements` 子句包含 `VolumeControl` 作为独立接口；D14 原文枚举只列了 6 组。
   - What's unclear: 用户在 D14 决策讨论时是否是有意省略（例如认为 `VolumeControl` 太简单不需要独立契约测试组），还是纯粹的枚举疏漏。
   - Recommendation: 由于这是"新增一组测试文件"这种低风险、可逆的实现细节，且属于 CONTEXT.md 明确划给"下游 gsd-planner 裁量"的范围（"契约测试 fixture 集具体文件清单"等同类粒度的实现裁量），建议规划者直接决定新增独立分组（与其余 6 组保持结构一致性，且 `VolumeControl` 确实是独立于 `PlaybackControl` 的能力接口），无需额外用户确认。

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| ripgrep (`rg`) | BASE-02 审计脚本（D21/D23 锁定方案） | ✓ | 14.1.1 [VERIFIED: `rg --version` 输出] | GNU grep（已确认可用，但性能与语法便利性不如 rg） |
| flutter_test | BASE-04 契约测试 | ✓ | 项目现有 dev_dependency，无需新增 | — |
| `test/fixtures/` 目录 | D17 坏文件 fixture | ✗（当前不存在） | — | 无需 fallback——这是 Wave 0 建设任务的一部分，本身就是待创建产物 |
| `tool/audit/` 目录 | D23 脚本落点 | ✗（当前不存在） | — | 无需 fallback——同上，Wave 0 建设任务 |

**Missing dependencies with no fallback:** 无——`test/fixtures/`与`tool/audit/`的"缺失"是预期状态（Phase 15 本身就是要创建它们），不是阻塞性缺口。

## Sources

### Primary (HIGH confidence)
- Context7 `/websites/dart_dev` — 查询 "documentation comments dartdoc best practices effective dart"，确认 dartdoc 官方标签集（`///`, `[bracket-reference]`, `{@template}/{@macro}`, `{@category}`），确认 D2 标签集为项目自创惯用法而非 dartdoc 原生特性
- LIVE code 直接读取与 ripgrep 验证：`lib/kernel/engine/media_engine.dart`、`lib/kernel/engine/fvp_engine.dart`、`lib/kernel/engine/engine_state_view.dart`、`lib/kernel/engine/engine_state_machine.dart`、`lib/kernel/utils/memory_monitor.dart`、`lib/kernel/utils/log.dart`、`lib/kernel/services/playback_navigator.dart`、`test/helpers/fake_engine.dart`

### Secondary (MEDIUM confidence)
- `.planning/research/PITFALLS.md`、`.planning/research/SUMMARY.md`（里程碑级研究产物，早于 Phase 15，记录"121/30"数字来源与"两个 openGeneration 计数器"这一事实）
- `.planning/phases/15-contract-freeze-baseline-audit/15-CONTEXT.md`、`.planning/ROADMAP.md`、`.planning/REQUIREMENTS.md`、`.planning/STATE.md`、`.planning/.continue-here.md`、`.planning/milestones/v3.0-phases/09-interface-decomposition/09-CONTEXT.md`、`.planning/milestones/v3.0-phases/10-state-machine-extraction/10-CONTEXT.md`

### Tertiary (LOW confidence)
- mpv/ExoPlayer 生命周期精度对比（训练知识，非本次会话核实；项目既有 memory 笔记 `reference_media_player_comparison.md` 佐证方向但未覆盖 dispose/release 生命周期细节）
- `shared_preferences_platform_interface` 测试组织方式类比（训练知识，非本次会话核实的具体代码）

## Metadata

**Confidence breakdown:**
- Contract Documentation Conventions: MEDIUM-HIGH — dartdoc 官方语法部分经 Context7 核实为 HIGH；D2 标签集本身是项目自创惯用法，其"最佳实践"部分只能类比 effective_dart 通用原则，故整体 MEDIUM-HIGH
- Reproducible Baseline Audit: HIGH — 全部关键数字（84/28、2、2 文件）均为本次会话直接 ripgrep 验证，非转述
- 9v6 + Lifecycle Precedent: MEDIUM — 先例方向可信（多个独立信息源指向同一结论），但具体 API 名称/行为细节未在本次会话逐一查证源码，标注 `[ASSUMED]`
- Validation Architecture: MEDIUM-HIGH — 结构化映射基于项目现有 `flutter_test` 约定（HIGH）+ Phase 15 特有的"无运行时可采样"这一推理（合理但为本研究首次提出，MEDIUM）

**Research date:** 2026-07-17
**Valid until:** Phase 15 规划与执行期间持续有效；若 `lib/kernel/engine/` 或 `lib/kernel/services/` 目录发生任何提交（尤其涉及 logger 调用点增减），BASE-02 的具体数字需要重新用脚本核实，不依赖本文档的快照数字
