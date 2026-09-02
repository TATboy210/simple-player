# Phase 6: 能力探测与 C1/C2 钉死 - Context

**Gathered:** 2026-09-02
**Status:** Ready for planning

<domain>
## Phase Boundary

本阶段交付两件使能设施，不含任何用户可见行为变更：

1. **ENAB-01 — DwmCapabilities 启动探测**：runner C++ 侧一次性快照（Windows build number + `DWMWA_BORDER_COLOR` / `DWMWA_WINDOW_CORNER_PREFERENCE` 等属性可用性布尔），经 MethodChannel 透出 Dart，Dart 侧统一消费；Win10 上绝不发出 Win11 22000+ 专属属性调用。
2. **ENAB-02 — C1/C2 钉死**：C1（`WM_NCCALCSIZE` 多分支处理器：fullscreen→8px inset / maximized→overshoot / default→return 0）与 C2（全屏信号唯一读 `_state.mode.value.isFullscreen`）以 gate 脚本 + 结构契约 + 实机 UAT 清单钉死，防后续 chrome 工作回归。

不做：任何 DWM 属性实际生效（Phase 7/8）、拖拽/全屏行为修改（Phase 9/10）、Linux 探测实现（Phase 11，但 Dart 侧探测结构需为其预留对等形态）、media_kit 任何修改（红线解禁仅限 Phase 10）。

</domain>

<decisions>
## Implementation Decisions

### 探测暴露层
- **D-01:** DwmCapabilities 探测走 **Dart FFI**（`ntdll.dll` RtlGetVersion 拿 build 号 + `dwmapi.dll` 探测属性可用性，HRESULT 同步返回），无 MethodChannel、无新增 C++；Dart 侧统一消费，Phase 11 的 Linux compositor 探测做对等 Dart 结构，诊断日志统一走 Dart 链 — **Reversibility:** costly — Phase 7/8 的属性门控将读取 Dart 侧快照，后撤需改动多个消费方。（修订记录：初稿为「C++ 探测 + MethodChannel」，用户表达全面 Dart 化意愿后于规划前修订；C++ 仅保留 WndProc 消息拦截存量段——NCCALCSIZE/NCHITTEST 物理 C++ 不可移）

### C1 测试形态
- **D-02:** C1 回归钉死采用 gate 脚本 + 结构契约（复用 `tool/audit/` bash 脚本先例）：守卫注释存在性检查 + `WM_NCCALCSIZE` 分支结构指纹 + 「禁止裸 `return 0`」grep gate + 实机 UAT 清单（缝隙为 DWM 视觉，headless 不可见，研究明确）。不引入 C++ 测试 harness（项目零 C++ 测试基建，违「小即是美」）

### C2 钉死范围
- **D-03:** C2 与 C1 一起钉——gate 脚本追加一条 grep：全项目禁止读 `VideoState.isFullscreen` 作全屏信号（「便宜，一行规则」，用户原话）

### DWM 调用失败上报
- **D-04:** 属性调用 HRESULT 非 S_OK 时：KernelLogger 每次失败必记；同类失败首次聚合成一条 ErrorReport 上报（复用 v1.0 ErrorReporter 语义去重），错误卡片不刷屏

### C1 规范形态
- **D-05:** C1 现有单分支结构（守卫注释 + `WS_OVERLAPPEDWINDOW` 样式检查 → 条件 `return 0`）为规范形态——2026-09-02 用户裁决「接受单分支为规范形态」；ENAB-02/ROADMAP 准则 3 的「多分支」措辞系研究对理想形态的描述，已同步修正。Plan 06-02 的 FLAGGED ASSUMPTION 与 06-UAT.md 第 3 节的复核项就此解决：无需三分支，GATE 1 钉死单分支现状（由 Plan 06-02 Task 1 实现）

### Claude's Discretion
- MethodChannel 名称与消息结构（遵循项目现有 channel 惯例即可）
- C++ 侧日志出口选择（OutputDebugString / channel 透传 / 两者）
- gate 脚本命名与参数化方式（跟随 `tool/audit/` 现有风格）
- 探测结构体字段命名与组织（对齐 Phase 11 Linux 探测对等形态）

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 里程碑研究（本阶段的实现依据）
- `.planning/research/STACK.md` — RtlGetVersion 探测模式、DWM 属性 build 门槛矩阵（22000+）、「禁止使用」清单
- `.planning/research/ARCHITECTURE.md` — C1/C2 在真实源码中的位置（`flutter_window.cpp:63-71` NCCALCSIZE 多分支、`window_service_state.dart:177` WindowMode 单源）、三层边界划分
- `.planning/research/PITFALLS.md` — Pitfall 1（C1 回归）/ 2（Win10 E_INVALIDARG）/ 3（set-once 失效）的预防策略
- `.planning/research/SUMMARY.md` — Phase 1（对应本 Phase 6）交付清单与依赖关系

### 规划上下文
- `.planning/REQUIREMENTS.md` — ENAB-01 / ENAB-02 需求原文与验收标准
- `.planning/ROADMAP.md` §Phase 6 — 阶段目标与成功标准

### 代码锚点（探测与钉死的落点）
- `windows/runner/flutter_window.cpp` — C1 NCCALCSIZE 多分支处理器现状（MessageHandler）
- `lib/kernel/window_Bridge/window_service_state.dart` — C2 单一数据源（`WindowModeCoordinator.setMode` 串行化 + `_state.mode.value`）
- `tool/audit/` — v4.0 gate 脚本先例（bash + ripgrep 风格，本阶段新脚本跟随）

### 失败上报链（D-04 落点）
- `lib/kernel/diagnostics/kernel_logger.dart` — KernelLogger 门面（kernel 侧强制，CI grep gate 禁 debugPrint）
- `lib/kernel/diagnostics/` ErrorReporter 体系 — v1.0 语义去重（10 秒回滚窗）、`reportPlatformSafely` 公开 intake、错误卡片呈现

### 外部参照（只读模式来源，不链接不修改）
- media_kit pub cache `media_kit_video-2.0.1/windows/utils.cc:85` — `RtlGetVersion` build 检测模式（复制不链接）

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `KernelLogger`（`lib/kernel/diagnostics/kernel_logger.dart`）— C++ 侧失败日志与 Dart 侧消费统一出口
- `ErrorReporterImpl.I.reportPlatformSafely`（v1.0）— D-04 聚合上报直接复用其语义去重（10 秒窗），零新基建
- `tool/audit/*.sh` gate 脚本族（v4.0：动态契约检查 + 水位标记模式）— D-02/D-03 新脚本的风格与结构模板
- `WindowBridge` / `WindowService`（`lib/kernel/window_Bridge/`）— Dart 侧探测快照的天然消费入口

### Established Patterns
- **C2 单一数据源**：全屏信号只读 `_state.mode.value.isFullscreen`（`window_service_state.dart:177`）——gate 规则的正面基线
- **C1 多分支 NCCALCSIZE**：fullscreen→inset / maximized→overshoot / default→return 0（`flutter_window.cpp:63-71`）——结构指纹锁定的对象
- **kernel 禁 debugPrint**：CI grep gate（kernel_logger_gate）——C++ 日志透传 Dart 后须遵守同一惯例
- **ValueNotifier + ValueListenableBuilder**：Dart 侧快照暴露应遵循此惯例（不引入新状态库）

### Integration Points
- `FlutterWindow::OnCreate` / `MessageHandler`（`windows/runner/flutter_window.cpp`）— 探测调用点与守卫注释落点
- `windows/runner/win32_window.cpp` — `WM_NCHITTEST`（C1 的 8px resize `HitTestWindowEdge`，Phase 9 将扩展，本阶段只锁定现状）
- MethodChannel 现有通道惯例（window_manager 通道旁新建应用自有通道）— Dart 侧消费接入口

</code_context>

<specifics>
## Specific Ideas

- 用户原话锚点：「C++ 探测 + MethodChannel 透出，Dart 统一消费」（D-01）、「便宜，一行规则」（D-03）、「卡片不刷屏」（D-04）
- 探测为启动期 one-shot；settle-point 重应用（主题/DPI/模式变化后）属 Phase 7 的 BORD-03，本阶段不实现，但 Dart 快照结构应可支撑后续重读

</specifics>

<deferred>
## Deferred Ideas

- **死代码清扫 + 依赖瘦身**（`lib/ui/playlist/` 4 文件 + `lib/kernel/playlist/playlist.dart` 整链；pubspec 未用依赖 go_router/dio/logger/get/flutter_secure_storage/freezed——删 freezed+pigeon 可顺带解 analyzer 14 生态阻塞）——独立 `/gsd-quick` 任务，不属本里程碑；CLAUDE.md 的 `bridge/win32` FFI 过时描述一并修正
- **Phase 7/8 属性设置的 Dart FFI 化**——本阶段已按 D-01 走 Dart FFI 探测；属性设置（DwmSetWindowAttribute）同样倾向 Dart FFI，属 Phase 7/8 规划时的决策

</deferred>

---

*Phase: 6-能力探测与 C1/C2 钉死*
*Context gathered: 2026-09-02*
