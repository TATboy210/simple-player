# Phase C: 平台适配与深化 - Context

**Gathered:** 2026-07-10
**Status:** Ready for planning

<domain>
## Phase Boundary

将 Phase A/B 建立的 FullscreenAdapter 抽象层在 Windows/macOS/Linux 三端落地为生产级稳定实现。Windows 自写 FFI 驱动（扩展现有 win32_fullscreen.dart），macOS/Linux 用 fullscreen_window 插件 + Adapter 叠加层。平台差异文档化，FullscreenCapability 返回每平台真实能力。

本阶段不实现质量收尾和 E2E 测试（Phase D），不实现 Web/Mobile 适配。

</domain>

<decisions>
## Implementation Decisions

### 平台驱动策略
- **D-P01:** **混合策略**：Windows 自写 FFI 驱动（主路径），macOS/Linux 用 fullscreen_window 插件 + Adapter 叠加层。各端取最优方案。
- **D-P02:** **每平台一个 Driver 文件** + `desktop_fullscreen_driver_factory.dart` 统一创建入口。文件：`windows_fullscreen_driver.dart`、`macos_fullscreen_driver.dart`、`linux_fullscreen_driver.dart`。工厂方法根据 `Platform.isXXX` 选择。与现有 `Win32DisplayAdapter` 模式一致。
- **D-P03:** **编译时二选一**：`USE_NEW_FULLSCREEN=true` + `USE_WINDOWS_NATIVE_FULLSCREEN=true`。运行时不混合、不降级、不自动回退。
- **D-P04:** **Driver 3 方法接口**：`enterFullscreen()` / `leaveFullscreen()` / `queryState()`。恢复逻辑留给 Adapter 层（Phase B D-22~D-25 已锁定）。Driver 只负责原生操作。

### Windows 深化
- **D-P05:** **扩展现有 win32_fullscreen.dart** 为 `WindowsFullscreenDriver`，复用已验证的 WS_THICKFRAME 处理逻辑。不重写。
- **D-P06:** **WS_THICKFRAME 处理**：进入全屏时剥离 WS_THICKFRAME 样式，退出时恢复。现有方案已解决 7px 缝隙问题。
- **D-P07:** **主动焦点恢复**：退出全屏后 `SetForegroundWindow` + `SetFocus` 恢复焦点。安全护栏：只在"本次由本应用触发的退出全屏"后执行；先判定窗口可见且未最小化；失败只报日志 + 错误事件，不循环抢焦点。
- **D-P08:** **TopMost 残留清理**：退出全屏时 `SetWindowPos(HWND_NOTOPMOST)` 清理置顶状态。

### macOS 原生生命周期
- **D-P09:** **插件 + 回调确认**：fullscreen_window 插件做基础进出，Driver 在插件调用后监听 NSWindow delegate 回调（`windowDidEnterFullScreen` / `windowDidExitFullScreen`），等回调确认后才设 stable。超时 2.5s 报 PlatformFailure。
- **D-P10:** **原生全屏动画**：使用 macOS 原生全屏动画（绿色按钮效果），不用无边框绕过。用户体验与 macOS 习惯一致。
- **D-P11:** **统一确认链**：回调未到 → 500ms 等待 → 100ms 轮询到 2.5s → 超时按 PlatformFailure + 一次 queryState() 校正。与 Phase B D-19 三级确认策略一致。

### Linux WM 兜底
- **D-P12:** **插件 + 三级确认**：fullscreen_window 插件做基础进出，Driver 严格执行 Phase B D-19 的三级确认（回调→轮询→超时）。不同 WM 回调可靠性不同，轮询兜底。
- **D-P13:** **WM 检测 + 文档化**：运行时检测 WM 类型（通过 `XDG_SESSION_TYPE` + 环境变量），记录到 `FullscreenCapability.platformNotes` + 日志。不做逐 WM 特殊处理，仅文档化。若某 WM 确认失败率高，后续再升级到逐 WM 适配。

### Claude's Discretion
- Driver 内部的 FFI 调用细节（如具体 Win32 API 参数）留给实现阶段
- macOS delegate 回调的具体桥接方式（MethodChannel vs FFI）留给实现阶段
- Linux WM 检测的具体环境变量列表留给实现阶段
- 能力矩阵的具体数值（如超时时间微调）留给实现阶段

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目规划
- `.planning/PROJECT.md` — 项目全貌、核心价值、约束、已锁定决策
- `.planning/REQUIREMENTS.md` — 22 个 v1 需求，Phase C 涉及 PLAT-01~04
- `.planning/ROADMAP.md` — 4 阶段路线图，Phase C 目标和成功标准
- `.planning/STATE.md` — 当前项目状态
- `.planning/phases/01-architecture-core-models/01-CONTEXT.md` — Phase A 决策（D-01~11），Phase C 必须遵循
- `.planning/phases/02-command-queue-recovery/02-CONTEXT.md` — Phase B 决策（D-12~31），命令队列/恢复策略/迁移路径

### 现有实现
- `lib/kernel/bridge/fullscreen_adapter.dart` — FullscreenAdapter 抽象接口（Phase A 产出）
- `lib/kernel/bridge/window_service.dart` — 当前全屏实现，Phase C Driver 将替代其内部 fullscreen_window 调用
- `lib/kernel/bridge/win32/win32_fullscreen.dart` — 已有 Win32 FFI 全屏实现，WindowsFullscreenDriver 扩展基础
- `lib/kernel/bridge/win32/win32_display_enumerator.dart` — Win32 FFI 显示器枚举，副屏恢复依赖
- `packages/fullscreen_window/` — 本地全屏插件，macOS/Linux 继续使用
- `lib/kernel/models/fullscreen_capability.dart` — 能力查询模型，Phase C 每端返回真实值
- `lib/kernel/models/fullscreen_snapshot.dart` — 状态快照模型
- `lib/kernel/models/fullscreen_event.dart` — 事件模型
- `lib/kernel/models/fullscreen_error.dart` — 错误模型（含 PlatformFailure/StateDesync）

### 代码库模式
- `.planning/codebase/ARCHITECTURE.md` — 分层架构、数据流、关键抽象
- `.planning/codebase/STACK.md` — 技术栈、依赖、平台要求
- `.planning/codebase/INTEGRATIONS.md` — 外部集成、平台 API

### 参考记忆
- `memory/project_fullscreen_bugs.md` — 5 个全屏 bug 修复经验
- `memory/project_fullscreen_win32_fix.md` — Win32 FFI 重写方案（WS_THICKFRAME 解决方案）
- `memory/anti_pattern_fullscreen_ffi.md` — 禁止 win32 包的反面教训

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **win32_fullscreen.dart**: 已验证的 WS_THICKFRAME 处理逻辑，WindowsFullscreenDriver 直接扩展
- **Win32DisplayAdapter**: 已有的 Win32 FFI 显示器枚举，副屏恢复依赖 `EnumDisplayMonitors` + `GetMonitorInfoW`
- **fullscreen_window 插件**: macOS/Linux 继续使用，插件已有三端实现
- **FullscreenCapability 模型**: Phase A 已定义，Phase C 每端填充真实值

### Established Patterns
- **ValueNotifier + ValueListenableBuilder**: 唯一状态管理模式
- **Composition over inheritance**: FvpEngine 由 6 个 helper 组合，Driver 采用类似模式
- **编译时 flag**: 已有 `USE_MOCK_ENGINE=true` 模式，新增 `USE_WINDOWS_NATIVE_FULLSCREEN=true`
- **三级确认**: Phase B D-19 已锁定（回调→轮询→超时），macOS/Linux Driver 遵循

### Integration Points
- **FullscreenAdapter**: Phase C Driver 被 Adapter 内部持有，Adapter 调用 Driver 的 3 个方法
- **WindowService**: Phase C 不改 WindowService 接口，只替换内部实现路径
- **FullscreenCapability**: 每端 `capabilities()` 返回真实能力矩阵

</code_context>

<specifics>
## Specific Ideas

- Windows FFI 驱动复用现有 win32_fullscreen.dart，不重写
- macOS 使用原生全屏动画（绿色按钮效果），等 delegate 回调确认
- Linux 运行时检测 WM 类型记录到 platformNotes + 日志
- 焦点恢复有安全护栏：只在本应用触发的退出后执行、先判定窗口可见、失败只报日志
- 能力矩阵：Windows A（查询/恢复/显示器/状态一致性）、macOS A/B（生命周期确认后可升 A）、Linux B（WM 差异 + 兜底）
- 编译时 flag 粒度：USE_NEW_FULLSCREEN + USE_WINDOWS_NATIVE_FULLSCREEN 两个独立开关

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: C-平台适配与深化*
*Context gathered: 2026-07-10*
