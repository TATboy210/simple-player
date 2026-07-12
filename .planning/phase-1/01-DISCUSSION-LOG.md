# Phase 1: 全屏代码简化 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-12
**Phase:** 1-全屏代码简化
**Areas discussed:** 驱动层合并策略, flutter_fullscreen 取舍, 全屏状态归属, WindowService 职责边界

---

## 驱动层合并策略

### Q1: 4层全屏驱动抽象怎么精简？

| Option | Description | Selected |
|--------|-------------|----------|
| 删除 DesktopFullscreenDriver（推荐） | macOS/Linux 直接用 fullscreen_window 包，保留 WindowsFullscreenDriver + Win32FullscreenFfi 分离。4→3 层。 | ✓ |
| 合并到 2 层 | 同时合并 WindowsFullscreenDriver + Win32FullscreenFfi 为单文件。最激进但合并后可能超 800 行。 | |
| 保持层数，只清代码 | 保持 4 层不变，只清理冗余代码。保守但风险最低。 | |

**User's choice:** 删除 DesktopFullscreenDriver（推荐）
**Notes:** 长期记忆逆向分析确认 Win32 FFI 核心必须保留

### Q2: DesktopFullscreenDriverFactory 怎么处理？

| Option | Description | Selected |
|--------|-------------|----------|
| 删除工厂，内联到 WindowService（推荐） | 平台检测逻辑移入 WindowService.init() 或 main.dart | ✓ |
| 保留工厂但简化 | 保留但直接创建具体驱动 | |
| 工厂不动 | 只删除 DesktopFullscreenDriver 分支 | |

**User's choice:** 删除工厂，内联到 WindowService（推荐）

### Q3: WindowsFullscreenDriver 和 Win32FullscreenFfi 是否合并？

| Option | Description | Selected |
|--------|-------------|----------|
| 保持分离（推荐） | FFI bindings 独立可测试，职责清晰 | ✓ |
| 合并为单文件 | 减少文件切换，但 ~900 行超最佳实践 | |

**User's choice:** 保持分离（推荐）

### Q4: 是否同时清理各层内部冗余代码？

| Option | Description | Selected |
|--------|-------------|----------|
| 清理所有冗余抽象（推荐） | CommandQueue、7 种错误类型、状态机等 | ✓ |
| 只删层，不清理内部 | 只删 DesktopFullscreenDriver + Factory | |

**User's choice:** 清理所有冗余抽象（推荐）

### Q5: macOS/Linux 全屏怎么走？

| Option | Description | Selected |
|--------|-------------|----------|
| 直接用 fullscreen_window 包（推荐） | 不经过额外抽象层 | ✓ |
| 保留薄包装器 | 简化为薄包装器调用 fullscreen_window | |
| 只改 Windows | macOS/Linux 暂不改动 | |

**User's choice:** 直接用 fullscreen_window 包（推荐）

### Q6: 全屏操作失败时的错误处理策略？

| Option | Description | Selected |
|--------|-------------|----------|
| sealed class + 自动恢复（推荐） | FullscreenResult (Success/Failure)，失败时自动恢复窗口状态 | ✓ |
| bool 返回值 | 最简单但丢失错误信息 | |
| 不改错误处理 | 保持现有错误分类 | |

**User's choice:** sealed class + 自动恢复（推荐）

### Q7: 三级确认链怎么处理？

| Option | Description | Selected |
|--------|-------------|----------|
| 简化确认链（推荐） | 保留回调为主路径，超时简化为单次查询，删除 _confirmByWindowId | ✓ |
| 删除确认链 | 完全信任原生回调 | |
| 保持现状 | 保持三级确认链 | |

**User's choice:** 简化确认链（推荐）

---

## flutter_fullscreen 取舍

### Q1: flutter_fullscreen 包评估结论？

| Option | Description | Selected |
|--------|-------------|----------|
| 不引入，保留自研（推荐） | Windows 保留自研 Win32 FFI，macOS/Linux 复用 fullscreen_window 包 | ✓ |
| 引入但 Windows 覆盖 | 引入作为抽象层，Windows 仍用自研 FFI | |
| 全面引入 | 放弃自研 Win32 FFI，风险：7px 缝隙回归 | |

**User's choice:** 不引入，保留自研（推荐）
**Notes:** flutter_fullscreen 内部用 window_manager，无法解决 WS_THICKFRAME 7px 缝隙。用户原话："千万必要下载win32依赖"

### Q2: FULL-02 评估文档形式？

| Option | Description | Selected |
|--------|-------------|----------|
| 写评估文档（推荐） | 输出到 .planning/research/，包含对比表和引入条件 | ✓ |
| 只记结论 | 在 CONTEXT.md 中记录即可 | |

**User's choice:** 写评估文档（推荐）

---

## 全屏状态归属

### Q1: isFullscreen 状态归属？

| Option | Description | Selected |
|--------|-------------|----------|
| WindowService 单一 owner（推荐） | 通过 ValueNotifier 暴露，SettingsStore 删除相关 getter/setter | ✓ |
| 新建 FullscreenStateManager | 独立管理状态 | |
| 双写保持 | WindowService 管状态，持久化仍走 SettingsStore | |

**User's choice:** WindowService 单一 owner（推荐）

### Q2: 全屏状态是否需要持久化？

| Option | Description | Selected |
|--------|-------------|----------|
| 不持久化（推荐） | 全屏是临时状态，删除 SettingsStore 中的持久化代码 | |
| WindowService 持久化 | 由 WindowService 管理持久化 | ✓ |

**User's choice:** WindowService 持久化
**Notes:** 用户认为全屏状态需要持久化，但由 WindowService 而非 SettingsStore 管理

### Q3: 窗口几何快照/恢复逻辑放哪？

| Option | Description | Selected |
|--------|-------------|----------|
| 保留在 WindowService（推荐） | window_persistence.dart 已管理，_restoreSnapshot 保留 | ✓ |
| 移到驱动层 | WindowsFullscreenDriver 内部处理 | |

**User's choice:** 保留在 WindowService（推荐）

---

## WindowService 职责边界

### Q1: WindowService 是否需要拆分？

| Option | Description | Selected |
|--------|-------------|----------|
| 保持现状，不拆分（推荐） | 职责内聚，合并后可能超 500 行但可接受 | ✓ |
| 提取 FullscreenManager | 全屏逻辑独立管理 | |
| 拆为两个子模块 | WindowManager + FullscreenManager | |

**User's choice:** 保持现状，不拆分（推荐）

### Q2: WindowBridge 抽象接口是否保留？

| Option | Description | Selected |
|--------|-------------|----------|
| 保留抽象接口（推荐） | 测试和跨平台需要 | ✓ |
| 删除抽象接口 | 减少一层但丢失测试灵活性 | |

**User's choice:** 保留抽象接口（推荐）

### Q3: WindowService 和 SettingsStore 的依赖关系？

| Option | Description | Selected |
|--------|-------------|----------|
| 构造函数注入（推荐） | 注入持久化接口，便于测试和解耦 | ✓ |
| 保持直接 import | 简单但不可 mock | |

**User's choice:** 构造函数注入（推荐）

### Q4: resize debounce 是否简化？

| Option | Description | Selected |
|--------|-------------|----------|
| 简化为单 Timer（推荐） | 减少 Timer/Completer 交互复杂度 | ✓ |
| 保持双 Timer | 保持现状 | |

**User's choice:** 简化为单 Timer（推荐）

---

## Claude's Discretion

无 — 所有决策均用户明确选择。

## Deferred Ideas

None — discussion stayed within phase scope
