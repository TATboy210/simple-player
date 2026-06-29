# Phase 3: 接口优化 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-29
**Phase:** 3-接口优化
**Areas discussed:** Dart mixin 机制, Mixin 方法边界, MockEngine 适配, 向后兼容策略

---

## Dart Mixin 机制

### 形式选择
| Option | Description | Selected |
|--------|-------------|----------|
| mixin on PlayerEngine | `mixin TrackControl on PlayerEngine` — 限定在 PlayerEngine 体系内使用 | ✓ |
| abstract mixin class | 独立的 mixin class，不限定 on 约束 | |
| 不确定，交给 Planner | 让 Planner 和 Researcher 决定 | |

**User's choice:** mixin on PlayerEngine（推荐）
**Notes:** 编译器保证 mixin 只在 PlayerEngine 体系内使用，类型安全

### 实现方式
| Option | Description | Selected |
|--------|-------------|----------|
| 纯接口（abstract 方法） | mixin 只定义方法签名，由 FvpEngine 实现 | ✓ |
| 带默认实现（委托 helper） | mixin 提供默认实现，内部委托给 helper 类 | |
| 混合模式 | 简单的用默认实现，复杂的留 abstract | |

**User's choice:** 纯接口（abstract 方法）
**Notes:** mixin 做方法分组，FvpEngine 保持现有委托逻辑不变

---

## Mixin 方法边界

### 方法分组
| Option | Description | Selected |
|--------|-------------|----------|
| 按功能域分 | TrackControl(9) + VideoEffects(4) + RendererConfig(2)，核心留在基类 | ✓ |
| 按使用场景分 | TrackControl(6) + VideoEffects(4) + RendererConfig(5) | |
| 只拆高频使用 | 只提取 VideoEffects(4) 和 RendererConfig(2) | |

**User's choice:** 按功能域分（推荐）
**Notes:** TrackControl 9方法（音轨3+字幕5+均衡器1），VideoEffects 4方法，RendererConfig 2方法

### ValueNotifier 归属
| Option | Description | Selected |
|--------|-------------|----------|
| 全留在基类 | 所有 12 个 ValueNotifier 保持在 PlayerEngine 基类 | ✓ |
| 跟着方法走 | subtitleText 移入 TrackControl 等 | |

**User's choice:** 全留在基类（推荐）
**Notes:** mixin 纯做方法分组，不碰状态

---

## MockEngine 适配

| Option | Description | Selected |
|--------|-------------|----------|
| 实现全部 mixin | MockEngine with TrackControl, VideoEffects, RendererConfig | ✓ |
| 不实现 mixin | MockEngine 不 with mixin，`engine is TrackControl` 返回 false | |
| 两个 MockEngine | MockFvpEngine（with mixin）和 MockPlayerEngine（不 with） | |

**User's choice:** MockEngine 实现全部 mixin（推荐）
**Notes:** 测试中 `engine is TrackControl` 返回 true，与 FvpEngine 行为一致

---

## 向后兼容策略

### FvpEngine 签名变更
| Option | Description | Selected |
|--------|-------------|----------|
| 仅改 FvpEngine 签名 | FvpEngine with 3 个 mixin，PlayerEngine 不变 | ✓ |
| PlayerEngine 也改为 mixin | PlayerEngine 改为 mixin 组合体 | |
| 分两步 | Phase 3 只定义 mixin，Phase 4 再应用 | |

**User's choice:** 仅改 FvpEngine 签名（推荐）
**Notes:** 57 个 UI 文件零修改

### UI 能力检查
| Option | Description | Selected |
|--------|-------------|----------|
| if + as cast | `if (engine is TrackControl) { engine as TrackControl }` | |
| Dart 3 pattern matching | `if (engine case TrackControl tc) { ... }` | ✓ |
| 不使用能力检查 | mixin 只用于架构分层 | |

**User's choice:** Dart 3 pattern matching
**Notes:** 类型安全且不需要显式 cast

---

## Claude's Discretion

- mixin 文件组织方式留给 Planner 决定
- 具体哪些 UI 文件需要加能力检查留给 Planner 分析

## Deferred Ideas

None — discussion stayed within phase scope
