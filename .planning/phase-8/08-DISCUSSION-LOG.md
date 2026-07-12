# Phase 8: 删除不必要的抽象层 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-12
**Phase:** 8-删除不必要的抽象层
**Areas discussed:** DesktopFullscreenAdapter 内部状态简化时机

---

## DesktopFullscreenAdapter 内部状态简化时机

| Option | Description | Selected |
|--------|-------------|----------|
| Phase 8 内先简化再删除（推荐） | Phase 8 先把 adapter 内部状态从 FullscreenSnapshot 简化为 ValueNotifier<bool>，然后再删 model 文件。每步都编译通过。Phase 9 再合并进 WindowService。 | ✓ |
| Phase 8 只删文件，Phase 9 修 adapter | Phase 8 只删 model/interface 文件，adapter 代码保留但编译不过。Phase 9 一起修 adapter + 合并进 WindowService。 | |
| Phase 8 连 adapter 一起删 | Phase 8 直接删除 DesktopFullscreenAdapter 整个文件（520行），Phase 9 从零在 WindowService 里写简化逻辑。 | |

**User's choice:** Phase 8 内先简化再删除（推荐）
**Notes:** 研究推荐方案，确保每步编译通过

### 保留能力

| Option | Description | Selected |
|--------|-------------|----------|
| 三级确认链 | Level 1 callback → Level 2 polling → Level 3 timeout | ✓ |
| 恢复策略 | maximized/secondary display 恢复（_RestoreSnapshot） | |
| Windows FFI 快速路径 | is WindowsFullscreenDriver 检测 | |
| 事件广播系统 | FullscreenEvent 事件流（7种事件类型） | |

**User's choice:** 只保留三级确认链
**Notes:** 恢复策略、FFI 快速路径、事件广播在 Phase 8 简化时移除

### 事件替代方案

| Option | Description | Selected |
|--------|-------------|----------|
| ValueNotifier<bool> 替代（推荐） | 删除 FullscreenEvent 事件流，改为 ValueNotifier<bool> isFullscreen | ✓ |
| ValueNotifier<FullscreenState> 替代 | 保留简化状态对象（isFullscreen + error 信息） | |
| 完全删除事件同步 | WindowService 不再监听全屏状态变化 | |

**User's choice:** ValueNotifier<bool> 替代（推荐）
**Notes:** 研究推荐方案，简单直接

### 错误处理方式

| Option | Description | Selected |
|--------|-------------|----------|
| try-catch + debugPrint（推荐） | 删除 FullscreenError，用 try-catch + debugPrint | ✓ |
| 简化错误枚举（3-4种） | 保留简化的错误类型 | |
| 完全删除错误处理 | 静默忽略 | |

**User's choice:** try-catch + debugPrint（推荐）
**Notes:** 符合 ARCHITECTURE.md 错误处理策略

---

## Claude's Discretion

- 删除顺序（叶子节点优先）和提交策略留给实现阶段
- 具体的测试更新策略（删除 vs 适配）留给实现阶段
- DesktopFullscreenAdapter 简化后的具体代码结构留给实现阶段

## Deferred Ideas

None — discussion stayed within phase scope
