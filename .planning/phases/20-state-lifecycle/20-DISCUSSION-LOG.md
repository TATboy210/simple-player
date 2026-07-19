# Phase 20: 状态与生命周期重写 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-20
**Phase:** 20-状态与生命周期重写
**Areas discussed:** NewFvpEngine 架构, 生命周期状态机, DelegationPolicy 翻转策略, mdk 回调封送与竞态防护

---

## NewFvpEngine 架构

### Q1: 构建方式
| Option | Description | Selected |
|--------|-------------|----------|
| 组合委托 | NewFvpEngine 内部持有 FvpEngine 实例 | |
| 独立实现 + 复用 helper | 独立实现 MediaEngine，复用 helper | |
| 继承 FvpEngine | 继承，override 需要替换的方法 | |

**User's choice:** 独立实现 + 复用 helper → 后改为直接修改 fvp_engine.dart

### Q2: DiagnosticsBundle 集成
| Option | Description | Selected |
|--------|-------------|----------|
| 构造注入 bundle | 构造函数接收 DiagnosticsBundle | ✓ |
| 按需注入单个组件 | 只接收需要的组件 | |
| 静态 logger + 实例注入其他 | 混合模式 | |

**User's choice:** 构造注入 bundle

### Q3: Helper 复用策略
| Option | Description | Selected |
|--------|-------------|----------|
| 原样复用 | 不修改 helper 接口 | |
| 复用 + 适配 helper 接口 | 注入 logger、修改回调签名 | ✓ |
| 先原样复用，后续改造 | 分两步走 | |

**User's choice:** 复用 + 适配 helper 接口

### Q4: 文件位置
| Option | Description | Selected |
|--------|-------------|----------|
| new_fvp_engine.dart | 与旧引擎并存 | |
| 直接修改 fvp_engine.dart | 在同一文件内渐进替换 | ✓ |
| engine/v2/ 子目录 | 与旧引擎完全隔离 | |

**User's choice:** 直接修改 fvp_engine.dart

### Q5: Result 类型
| Option | Description | Selected |
|--------|-------------|----------|
| Result<T> sealed class | Ok/Err | |
| bool + lastError 通知 | 复用现有错误通道 | |
| TransitionResult 枚举 | ok/illegal/staleGeneration | ✓ |

**User's choice:** TransitionResult 枚举

### Q6: OpenGenerationTracker 集成
| Option | Description | Selected |
|--------|-------------|----------|
| 嵌入状态机内部 | 状态机完全自包含 | ✓ |
| 独立组件，引擎层检查 | 解耦 | |
| 装饰器包装状态机 | 包装模式 | |

**User's choice:** 嵌入状态机内部

### Q7: openGeneration 与 PlaybackNavigator 关系
| Option | Description | Selected |
|--------|-------------|----------|
| 双层守护 | Navigator + 状态机 | |
| 迁移到 tracker（单一源） | Navigator 通过 tracker 查询 | ✓ |
| 分层计数器 | 不同层面不同计数器 | |

**User's choice:** 迁移到 tracker（单一源）

---

## 生命周期状态机

### Q8: 如何融入状态机
| Option | Description | Selected |
|--------|-------------|----------|
| 扩展 MediaState 枚举 | 新增 disposed/disposing | |
| 正交 LifecyclePhase | Phase 15 约定 | ✓ |
| 引擎层 bool 守卫 | 不改状态机 | |

**User's choice:** 正交 LifecyclePhase

### Q9: recover() 语义
| Option | Description | Selected |
|--------|-------------|----------|
| error → idle 直接重置 | 简单明确 | ✓ |
| error → opening 自动重试 | 可能循环 | |
| 显式 recover() 方法 | 由 UI 调用 | |

**User's choice:** error → idle 直接重置

### Q10: 双重 dispose 安全
| Option | Description | Selected |
|--------|-------------|----------|
| bool 守卫 + 静默返回 | 已有模式 | ✓ |
| LifecyclePhase 检查 + 日志警告 | 可观测 | |
| assert 暴露 | 严格 | |

**User's choice:** bool 守卫 + 静默返回

---

## DelegationPolicy 翻转策略

### Q11: 翻转粒度
| Option | Description | Selected |
|--------|-------------|----------|
| 按 ISP 接口 | 每次翻转一个完整接口 | |
| 按单个方法 | 最细粒度 | ✓ |
| 按子系统分组 | 业务逻辑分组 | |

**User's choice:** 按单个方法翻转

### Q12: 验证策略
| Option | Description | Selected |
|--------|-------------|----------|
| 契约测试作为闸门 | 只跑该方法 | |
| 契约 + 手动冒烟 | 双保险 | |
| 完整测试套件 | 契约 + 集成 + widget | ✓ |

**User's choice:** 完整测试套件

### Q13: 翻转顺序
| Option | Description | Selected |
|--------|-------------|----------|
| 叶子优先 | volume → open | |
| 核心优先 | open → volume | ✓ |
| 低风险优先 | volume → open | |

**User's choice:** 核心优先（open → volume）

---

## mdk 回调封送与竞态防护

### Q14: 回调封送方式
| Option | Description | Selected |
|--------|-------------|----------|
| scheduleMicrotask | Phase 18 同模式 | ✓ |
| addPostFrameCallback | 与 UI 同步 | |
| Isolate 通信 | 最复杂 | |

**User's choice:** scheduleMicrotask 封送

### Q15: 竞态测试场景
| Option | Description | Selected |
|--------|-------------|----------|
| open→open | generation 守卫 | |
| open→seek→open | 操作交错 | |
| open→dispose | 生命周期边界 | |
| 全部场景 | 以上全部 + open→play→pause→open | ✓ |

**User's choice:** 全部场景

### Q16: 延迟范围
| Option | Description | Selected |
|--------|-------------|----------|
| 所有回调统一延迟 | 统一策略 | ✓ |
| 仅触发 open 的回调 | 精确 | |
| generation 检查决定 | 与 tracker 联动 | |

**User's choice:** 所有回调统一延迟

---

## Claude's Discretion

用户在全部 13 问都选了具体选项，无 "You decide" 选择。

## Deferred Ideas

- P21 适配层收拢
- P21 双轨回归验证
- P22 双语注释
- Helper 逐步改造（D3 延后）
- ERR-F01 Future
