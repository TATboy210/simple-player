# Requirements: Simple Player — 内核重写（兼容式替换与诊断内核）v3.0

**Defined:** 2026-07-16
**Supersedes:** v2.1 REQUIREMENTS.md（v2.1 已验证能力见 `PROJECT.md` Validated 节；v2.1 Widget 层需求 WGT-*/NOTIF-* 移入 Out of Scope，因 v3.0 "UI 不动"）
**Core Value:** 播放内核的健壮性与可扩展性 — 引擎抽象清晰、状态一致、错误恢复可靠、诊断能力（MemoryMonitor、统一日志）为内核一等公民；Widget↔Kernel 边界清晰、API 统一、可测试。

> **需求表述约定：** 本里程碑为内部内核重写（无 UI 改动），需求按**可测内核能力/行为**表述，每条原子、可测、独立。REQ-ID 类别对齐 `research/SUMMARY.md` 的 8 阶段代码接地构建顺序。Traceability 由 roadmapper 回填。

## v1 Requirements

### BASE — 契约固化与基线盘点（Phase 1）

- [x] **BASE-01**: 为每个 `MediaEngine`/`EngineStateView` 成员固化行为契约规约（前置条件、后置条件、允许的 `MediaState` 转换、错误情形、被修改的 `ValueNotifier`）
- [x] **BASE-02**: 产出静态调用点盘点：`package:logger` 用法（121 处/30 文件）、`MemoryMonitor.start/snapshot`（2 处）、`openGeneration` 引用
- [x] **BASE-03**: 核对 9 态（PROJECT.md）vs 6 态（`engine_state_machine.dart`）差异，决定冻结基线 + v3.0 须补的生命周期态（如 `disposed`/`disposing`/`error`-恢复）
- [x] **BASE-04**: 针对接口（非实现）编写契约测试，作为迁移闸门

### ADAPT — 兼容适配层骨架（Phase 2）

- [x] **ADAPT-01**: `KernelAdapter implements MediaEngine`，100% 路由到旧引擎，零行为变更，全测试套件绿
- [x] **ADAPT-02**: `DiagnosticsBundle` 载体（`KernelLogger` + `MemoryMonitor` + `EngineMetrics` + `EngineEventLog`），含 `noop` 默认，构造注入
- [x] **ADAPT-03**: 适配层转发活动引擎的 `ValueNotifier` **实例**（不重新包装），`ValueListenableBuilder` 监听器不脱钩
- [x] **ADAPT-04**: 单一 `KernelMode { legacy, migrated }` 仲裁者 + 由适配层持有的统一 `openGeneration` 计数器，无双数据源
- [x] **ADAPT-05**: 尺寸预算受控 — 适配层+门面+sealed 错误+tracker 合计 < 旧 `FvpEngine`；适配层除 `KernelMode`+generation 计数器外无状态

### LOG — 零依赖 KernelLogger 门面（Phase 3）

- [x] **LOG-01**: `lib/kernel/diagnostics/` 内零依赖 `KernelLogger` 门面（`dart:developer` + 受控 `debugPrint`）；内核永不导入 `package:logger`（CI grep 闸门）
- [x] **LOG-02**: 日志级别（trace/debug/info/warn/error/fatal）、结构化 `Map` 上下文、稳定调用点 API、文件路径脱敏
- [x] **LOG-03**: 发布门控 `kDebugMode`；warn/error 走 `dart:developer.log`；release 构建产出零 `debugPrint`/debug/info 行
- [x] **LOG-04**: 121 处调用点的替换迁移保留 `log*.w(...)` 调用形状（30 文件仅改 import/声明即迁移）
- [x] **LOG-05**: 可插拔 `LogSink`（`DevToolsSink`/`DebugPrintSink`/`NullSink`）；app 级 `log.dart` 作为 sink 注册（接线在内核之外）

### ERR — Sealed 错误模型稳化（Phase 4）

- [x] **ERR-01**: 扩展现有 sealed `PlayerError`（`ErrorContext`：action/generation/path/timestamp/module + `ErrorCode` 注册表）；保留 `ValueNotifier<PlayerError?>` 契约
- [x] **ERR-02**: 可恢复 vs 致命分裂根植于层级顶端；无静默吞错（类型化 `on` 子句，永不捕获 `Error` 子类）
- [x] **ERR-03**: 引擎 catch 点构造带上下文的 `PlayerError`、赋值 `lastError`、经 `bundle.logger.e` 发射；`PlaybackController._onError` 取 `PlayerError`
- [x] **ERR-04**: UI 边界 `ErrorView` 翻译（字符串码 + 本地化消息 + 严重级）；sealed `KernelError` 永不以原始 sealed 对象暴露给 UI
- [x] **ERR-05**: 错误跨 mdk 回调线程封送（主线程重建，回调栈作为字段携带）

### MEM — MemoryMonitor 一等化（Phase 5）

- [x] **MEM-01**: 实例化（非静态单例），构造注入 `RssProvider`（默认 `ProcessInfo`）+ `Clock`；阈值/间隔/历史上限可配置
- [x] **MEM-02**: `start`/`stop`/`dispose` 生命周期；可关闭（`NoopMemoryMonitor`/`disabled` 工厂）；对播放业务状态零干扰（永不调用 `PlaybackController`、永不改 `MediaState`）
- [x] **MEM-03**: 保留 `ValueNotifier<MemorySnapshot?>` + `snapshot()`/`exportJson()`；移至 `diagnostics/`，数据类拆至 `memory_snapshot.dart`
- [x] **MEM-04**: 单例→实例迁移在**一个原子提交**内完成（瞬态静态桥 shim + 重写 2 处调用 + 删除 shim），永不跨提交拆分
- [x] **MEM-05**: `MemoryMonitor` 实例纳入 `DiagnosticsBundle`；与 `KernelLogger` 集成（替换直接 `debugPrint`）

### STATE — 状态与生命周期重写（Phase 6）

- [x] **STATE-01**: `fvp_engine.dart`（就地修改 per D1）实现 `MediaEngine`，依赖 `DiagnosticsBundle`，发射 `PlayerError`+上下文
- [x] **STATE-02**: `openGeneration` 经 `OpenGenerationTracker` 与状态机统一（守卫移入机器，`transitionTo` 原子拒绝过时 generation 的转换）
- [x] **STATE-03**: `EngineStateMachine` 静默 assert-only 忽略替换为 `Result.err` + `KernelLogger` 警告；穷举 `switch`（无 `default`）
- [x] **STATE-04**: 生命周期加固 — `disposed`/`disposing`/`error`-恢复态、显式 `recover()`、双重 dispose 安全
- [x] **STATE-05**: mdk 回调封送至主 isolate；监听器触发的 open 延迟至 `scheduleMicrotask`
- [x] **STATE-06**: `DelegationPolicy` 按能力逐个翻转到新引擎；每次翻转后 Phase 1 契约测试通过（基础设施就位，实际翻转 deferred → Phase 21）
- [x] **STATE-07**: 竞态测试（open→seek→open 快速连发）断言最终状态仅匹配最后一次 open

### VERIFY — 测试与迁移验证 + 适配层收拢（Phase 7）

- [ ] **VERIFY-01**: 契约测试对 `NewFvpEngine` 通过
- [ ] **VERIFY-02**: 双轨回归套件 — 同一 widget 测试对 `KernelAdapter` all-old vs all-new；输出一致（时序用 `fakeAsync`）
- [ ] **VERIFY-03**: 迁移顺序由依赖图（`codegraph`）推导：叶子 → 编排器 → 状态管理器 → UI 绑定
- [ ] **VERIFY-04**: 适配层删除闸门清单（100% 调用方迁移、对等通过、守卫已移入、回退路径已审计）；收拢在独立提交
- [ ] **VERIFY-05**: `flutter analyze` 严格干净；`kernel/` 覆盖率 ≥ 80%
- [ ] **VERIFY-06**: 发布构建 CI 闸门 — `--release` 冒烟测试产出零 `debugPrint`/debug/info 行

### DOC — 双语 API 文档注释标准（Phase 8，与 3–6 并行）

- [x] **DOC-01**: Phase 1 即约定注释结构 — `///` 意图行（中文）、空行、`///` 契约块（英文：params/returns/throws/states/invariants）；英文行为权威，中文"为何"权威
- [x] **DOC-02**: `lib/kernel/**` 中 v3.0 修改的每个公开符号同时含中文意图 + 英文契约
- [x] **DOC-03**: 每个 `KernelError` 子类附错误码 + 英文契约

## Future Requirements

> 研究标注的 differentiators，推迟至 v3.x/v4+（触发条件见 `research/SUMMARY.md`）。

- **LOG-F01**: 按 `openGeneration` 的日志关联、惰性消息构造、内存环形缓冲 + 崩溃导出（与 `EngineEventLog` 统一）、每 sink 级别过滤
- **ERR-F01**: 上下文中的 `openGeneration` 关联、`RetryPolicy` 枚举、按码错误指标（复用 `EngineMetrics`）、非异常控制流 `Result<T>`、用户面 l10n 码→键映射
- **MEM-F01**: 可插拔 `MetricProbe` 源（GPU/帧时序）、带驱逐策略的环形缓冲、每引擎作用域、窗口统计
- **ADAPT-F01**: shadow 模式（调用新、丢弃结果、比对+日志差异）、按子系统渐进发布、新旧差异遥测
- **STATE-F01**: 转换表为 `const Map`、事件日志与 `EngineEventLog` 统一、转换指标、每态能力协商（`canSeek(state)`）、热重载安全的状态保留
- **SINK-F01**: 内核外的文件/远程日志 sink（触发：工单工作流需持久日志）
- **v2.1 deferred**: D1 引擎能力查询、D2 播放列表序列化解耦、D5 NetworkConfigurator 自适应、T4 PositionPoller 策略模式、T6 结构化 EngineMetrics（部分由 v3.0 `DiagnosticsBundle` 吸收）

## Out of Scope

| Feature | Reason |
|---------|--------|
| 底层引擎更换 | 继续使用 fvp (MDK/FFmpeg)，不更换底层 |
| UI 层改动（含 v2.1 WGT-* Widget API 统一、NOTIF-* rebuild 优化） | v3.0 专注内核，不改播放器界面；UI→Kernel 契约冻结不变 |
| 状态管理模式更换 | 继续使用 ValueNotifier + ValueListenableBuilder |
| 新增播放功能 | 本次只重写现有功能的内核实现 |
| 内核新增第三方运行时依赖（如 `logger`/`logging` 包进内核） | 零依赖 `KernelLogger` 门面；`package:logger` 仅保留在 app 级 sink 接线，内核永不导入 |
| 一次性全量替换内核 | 兼容式逐步迁移，禁止 big-bang swap |
| 内核拥有异步文件/远程日志 sink | sink 接线在内核之外；文件轮转移至 app 层 |
| 位置轮询器 200ms 热路径上记日志 | 反模式（噪声+性能） |
| 内存阈值自动执行策略 | 违反"零干扰"；需独立可测的策略层，推迟至有具体事件 |
| collapse 适配层前新内核未经证明 | 适配层删除须由闸门清单守护，禁止早收拢 |
| 适配层永久保留 / 化为常驻 god-adapter 层 | 适配层是 seam 不是 layer；迁移完成后收拢删除 |
| 多实例播放 / ABR 自适应码率 | 架构准备但不实现，属长期计划 |

## Traceability

> 由 roadmapper 在路线图创建时回填。每条需求映射到恰好一个阶段。

| Requirement | Phase | Status |
|-------------|-------|--------|
| BASE-01 | Phase 15 | Complete |
| BASE-02 | Phase 15 | Complete |
| BASE-03 | Phase 15 | Complete |
| BASE-04 | Phase 15 | Complete |
| ADAPT-01 | Phase 16 | Complete |
| ADAPT-02 | Phase 16 | Complete |
| ADAPT-03 | Phase 16 | Complete |
| ADAPT-04 | Phase 16 | Complete |
| ADAPT-05 | Phase 16 | Complete |
| LOG-01 | Phase 17 | Complete |
| LOG-02 | Phase 17 | Complete |
| LOG-03 | Phase 17 | Complete |
| LOG-04 | Phase 17 | Complete |
| LOG-05 | Phase 17 | Complete |
| ERR-01 | Phase 18 | Complete |
| ERR-02 | Phase 18 | Complete |
| ERR-03 | Phase 18 | Complete |
| ERR-04 | Phase 18 | Complete |
| ERR-05 | Phase 18 | Complete |
| MEM-01 | Phase 19 | Complete |
| MEM-02 | Phase 19 | Complete |
| MEM-03 | Phase 19 | Complete |
| MEM-04 | Phase 19 | Complete |
| MEM-05 | Phase 19 | Complete |
| STATE-01 | Phase 20 | Complete |
| STATE-02 | Phase 20 | Complete |
| STATE-03 | Phase 20 | Complete |
| STATE-04 | Phase 20 | Complete |
| STATE-05 | Phase 20 | Complete |
| STATE-06 | Phase 20 | Complete (infra built, flips deferred → Phase 21) |
| STATE-07 | Phase 20 | Complete |
| VERIFY-01 | Phase 21 | Pending |
| VERIFY-02 | Phase 21 | Pending |
| VERIFY-03 | Phase 21 | Pending |
| VERIFY-04 | Phase 21 | Pending |
| VERIFY-05 | Phase 21 | Pending |
| VERIFY-06 | Phase 21 | Pending |
| DOC-01 | Phase 22 | Complete |
| DOC-02 | Phase 22 | Complete |
| DOC-03 | Phase 22 | Complete |

**Coverage:**

- v1 requirements: 40 total
- Mapped to phases: 40 ✓
- Unmapped: 0 ✓

**Phase 映射概览**（按代码接地 8 阶段构建顺序）：

- Phase 15 契约固化与基线盘点 ← BASE (4)
- Phase 16 兼容适配层骨架 + DiagnosticsBundle ← ADAPT (5)
- Phase 17 零依赖 KernelLogger 门面 ← LOG (5)
- Phase 18 Sealed 错误模型稳化 ← ERR (5)
- Phase 19 MemoryMonitor 一等化 ← MEM (5)
- Phase 20 状态与生命周期重写 ← STATE (7)
- Phase 21 测试与迁移验证 + 适配层收拢 ← VERIFY (6)
- Phase 22 双语 API 文档注释标准 ← DOC (3)

---

## v4.0 Requirements — 设置面板框架重构

**Defined:** 2026-07-21
**Core Value:** 以 Kodi + Steam 混合导航范式重建设置面板框架，支持 D-pad/手柄/键鼠三模态交互，保持毛玻璃设计语言一致性，先框架后功能。

> **范围约定：** 本里程碑聚焦框架骨架（窗口绘制 + 导航系统 + 交互模式），**不实现**具体设置项的功能逻辑。所有 tab 页仅渲染占位内容（SettingRow 骨架），实际功能在后续里程碑填充。

### PANEL — Overlay Shell & State Model（Phase 23）

- [x] **PANEL-01**: `SettingsPanelState` 状态模型 — `ValueNotifier<bool> isOpen`、`ValueNotifier<int> selectedTab`、`ValueNotifier<Offset> dragOffset`；视频暂停/恢复由 `PlaybackController` 协调
- [x] **PANEL-02**: `SettingsPanelController` — `open()`/`close()`/`toggle()` 方法，打开时暂停视频并记录先前播放状态（`wasPlaying`），关闭时恢复到先前状态
- [x] **PANEL-03**: 毛玻璃覆盖层壳 — `BackdropFilter(sigmaX/Y)` + `bgGlass` + `borderHighlight`，居中定位（`Alignment.center`），拖拽约束在播放器窗口内
- [x] **PANEL-04**: 标题栏 — 左侧 "设置" 文字 + 右侧 × 关闭按钮（`GlassIconButton`），拖拽区域仅标题栏
- [x] **PANEL-05**: 遮罩层 — 半透明遮罩覆盖整个播放器，点击遮罩关闭面板，`AnimatedOpacity` + `AnimatedScale` 开关动效
- [x] **PANEL-06**: 键盘关闭 — `ESC` 和 `B` 键关闭面板（`FocusTraversalGroup` 内 `LogicalKeySet` 处理）
- [x] **PANEL-07**: 面板尺寸 — 500×400 基础尺寸，全屏时按窗口比例缩放（`MediaQuery.size` 计算），最大不超过窗口 80%

### SIDEBAR — Sidebar Navigation（Phase 24）

- [ ] **SIDEBAR-01**: 固定 200px 侧边栏 — 左侧垂直导航，每个 tab 项含图标 + 文字标签，选中态高亮（`accent` 色背景 + 白色文字）
- [ ] **SIDEBAR-02**: Tab 列表 — 7 个完整 tab（General/EQ/Audio/Video/Shortcuts/About/Performance），每项 48px 高度，垂直排列
- [ ] **SIDEBAR-03**: Tab 切换 — 点击切换 + `FadeTransition` 200ms 过渡动画，内容区淡入淡出
- [ ] **SIDEBAR-04**: LB/RB 快捷键 — 手柄 LB/RB 键循环切换 tab（左减右增，循环），与点击切换共享同一 `selectedTab` notifier

### TABS — Tab Content Framework（Phase 25）

- [x] **TABS-01**: 7 个 tab 页壳 — 每个 tab 为独立 `StatelessWidget`，接收当前 tab 索引，渲染 `SettingRow` 骨架列表（占位内容）
- [x] **TABS-02**: `SettingRow` 组件 — 标签 + 控件布局，支持 `Switch`/`Slider`/`SpinControl`/`Dropdown` 控件类型，内联描述文本（标签下方灰色小字）
- [x] **TABS-03**: OK/Cancel/Apply 按钮栏 — 底部固定，OK 应用所有待定更改并关闭，Cancel 丢弃并关闭，Apply 应用但不关闭
- [x] **TABS-04**: 延迟应用模式 — locale/theme/shortcuts 更改存入 `_pending*` 状态，仅 OK/Apply 时提交，Cancel 恢复原始值

### NAV — Gamepad & Keyboard Navigation（Phase 26）

- [ ] **NAV-01**: `FocusTraversalGroup` 包裹整个面板 — 侧边栏和内容区各为独立 `FocusTraversalGroup`，D-pad ↑↓ 在当前组内移动焦点
- [ ] **NAV-02**: `FocusableActionDetector` 在每个 `SettingRow` — 焦点态显示高亮边框（`borderHighlight`），hover 态显示 `bgHover` 背景
- [ ] **NAV-03**: `SpinControl` 组件 — 左右方向键循环切换选项值（替代 Dropdown，手柄友好），显示当前值 + 左右箭头指示器
- [ ] **NAV-04**: D-pad ←→ 调整值 — 在 SpinControl/Switch/Slider 上，左右方向键调整当前值（Slider 步进 5%）
- [ ] **NAV-05**: A 键确认 — 在可交互控件上，A 键触发确认（Switch 切换、SpinControl 选择、Button 点击）
- [ ] **NAV-06**: B 键关闭 — 任何时候 B 键关闭设置面板（与 ESC 等效），若焦点在控件上则先退回侧边栏

### SCALE — Responsive Scaling（Phase 27）

- [ ] **SCALE-01**: 窗口尺寸检测 — `MediaQuery.size` 检测播放器窗口尺寸，面板尺寸按比例缩放
- [ ] **SCALE-02**: 全屏适配 — 全屏模式下面板放大到 600×480（保持 5:4 比例），侧边栏保持 200px
- [ ] **SCALE-03**: 小窗口适配 — 窗口 < 800px 宽时，面板缩小到 400×320，侧边栏缩到 160px

### v4.0 Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| PANEL-01 | Phase 23 | Pending |
| PANEL-02 | Phase 23 | Pending |
| PANEL-03 | Phase 23 | Pending |
| PANEL-04 | Phase 23 | Pending |
| PANEL-05 | Phase 23 | Pending |
| PANEL-06 | Phase 23 | Pending |
| PANEL-07 | Phase 23 | Pending |
| SIDEBAR-01 | Phase 24 | Pending |
| SIDEBAR-02 | Phase 24 | Pending |
| SIDEBAR-03 | Phase 24 | Pending |
| SIDEBAR-04 | Phase 24 | Pending |
| TABS-01 | Phase 25 | Pending |
| TABS-02 | Phase 25 | Pending |
| TABS-03 | Phase 25 | Pending |
| TABS-04 | Phase 25 | Pending |
| NAV-01 | Phase 26 | Pending |
| NAV-02 | Phase 26 | Pending |
| NAV-03 | Phase 26 | Pending |
| NAV-04 | Phase 26 | Pending |
| NAV-05 | Phase 26 | Pending |
| NAV-06 | Phase 26 | Pending |
| SCALE-01 | Phase 27 | Pending |
| SCALE-02 | Phase 27 | Pending |
| SCALE-03 | Phase 27 | Pending |

**v4.0 Coverage:** 24 requirements, all mapped to phases 23–27.

---
*Requirements defined: 2026-07-16 (v3.0) — 2026-07-21 (v4.0 appended)*
*Last updated: 2026-07-22 — v4.0 settings panel framework requirements appended*
