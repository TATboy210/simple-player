# Phase A: 架构定稿与核心模型 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-09
**Phase:** A-架构定稿与核心模型
**Areas discussed:** 状态模型设计, 事件系统集成, 错误模型与恢复, Adapter 与 WindowService 边界

---

## 状态模型设计

### Q1: FullscreenSnapshot 容器模式

| Option | Description | Selected |
|--------|-------------|----------|
| 单一 ValueNotifier 包装 | FullscreenSnapshot = 不可变数据类 + copyWith，外层 ValueNotifier 持有 | ✓ |
| 多 ValueNotifier 字段 | 类似 EngineState mixin，每个字段独立 ValueNotifier | |

**User's choice:** 单一 ValueNotifier 包装 (Recommended)
**Notes:** 全屏是强一致状态域，不适合拆成多个独立字段 notifier

### Q2: phase 状态机

| Option | Description | Selected |
|--------|-------------|----------|
| 5 状态线性机 | stable ↔ entering/leaving + forcedChange + error | ✓ |
| 6 状态含 pending | 增加 pending 状态区分排队和执行中 | |

**User's choice:** 5 状态线性机 (Recommended)

### Q3: WindowState 关系

| Option | Description | Selected |
|--------|-------------|----------|
| 独立共存 + 渐进迁移 | WindowState.mode 的 fullscreen deprecated 但保留 | ✓ |
| 直接替代 | 直接移除 WindowState 中 fullscreen 相关字段 | |
| 嵌入 WindowState | FullscreenSnapshot 作为扩展字段嵌入 WindowState | |

**User's choice:** 独立共存 + 渐进迁移 (Recommended)

### Q4: 多窗口容器

| Option | Description | Selected |
|--------|-------------|----------|
| per-window Map 容器 | Map<int, ValueNotifier<FullscreenSnapshot>> | ✓ |
| 单窗口 + 接口预留 | 先做单窗口，多窗口留接口不实现 | |

**User's choice:** per-window Map 容器 (Recommended)

---

## 事件系统集成

### Q5: 事件流实现

| Option | Description | Selected |
|--------|-------------|----------|
| StreamController broadcast | FullscreenAdapter 内部 StreamController broadcast | ✓ |
| ValueNotifier 事件列表 | ValueNotifier<List<FullscreenEvent>> 持有最近事件 | |

**User's choice:** StreamController broadcast (Recommended)

### Q6: WindowListener 集成

| Option | Description | Selected |
|--------|-------------|----------|
| Adapter 内部转换 | 订阅 WindowBridge/driver 回调流，转换为 FullscreenEvent | ✓ |
| WindowService 转发 | WindowService 接收 _WindowListener，回调通知 Adapter | |

**User's choice:** Adapter 内部转换 (Recommended)
**Notes:** 订阅 WindowBridge/driver 暴露的回调流，不直接耦合 _WindowListener 私有类型

---

## 错误模型与恢复

### Q7: 错误类型系统

| Option | Description | Selected |
|--------|-------------|----------|
| sealed class | sealed class + 子类，可携带上下文字段 | ✓ |
| enum + 扩展 | enum + 扩展方法，简洁但无法携带上下文 | |

**User's choice:** sealed class (Recommended)

### Q8: error 恢复路径

| Option | Description | Selected |
|--------|-------------|----------|
| 重试即恢复 | 下一次合法操作自动清理 error 为 stable | ✓ |
| 显式 reset | 需要显式 reset() 调用才能恢复 | |

**User's choice:** 重试即恢复 (Recommended)
**Notes:** error 不是锁死态；不可恢复错误（如 Unsupported）允许重试但立即返回同类错误 + UI 明确提示

---

## Adapter 与 WindowService 边界

### Q9: Adapter 与 WindowService 关系

| Option | Description | Selected |
|--------|-------------|----------|
| 并列 + 内部组合 | 独立模块，内部使用 WindowService 通用方法 | ✓ |
| 包装 WindowService | 代理所有窗口操作 | |
| 完全独立 | 直接调用原生 API 不经过 WindowService | |

**User's choice:** 并列 + 内部组合 (Recommended)

### Q10: 迁移策略

| Option | Description | Selected |
|--------|-------------|----------|
| Phase A 接口 + Phase B 渐进迁移 | Phase A 只建接口和模型 | ✓ |
| Phase A 直接抽出 | 直接把全屏逻辑从 WindowService 抽出 | |

**User's choice:** Phase A 接口 + Phase B 渐进迁移 (Recommended)

---

## Claude's Discretion

- restoreMode 的具体快照时机（调用原生前 vs 后）留给实现阶段
- ForcedChange 事件的检测机制留给实现阶段
- displayId 的获取方式留给 Phase C 平台适配

## Deferred Ideas

None — discussion stayed within phase scope
