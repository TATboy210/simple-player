# Phase B: 命令队列与恢复策略 - Discussion Log

**Date:** 2026-07-09

## Areas Discussed

### 1. 命令队列实现策略
| Question | Options | Selection |
|----------|---------|-----------|
| 核心机制 | Completer 链 / 简单互斥锁 / 显式队列+调度器 | **Completer 链** |
| 超时处理 | 5s超时+报错 / 超时静默跳过 / 不设超时 | **5s 超时 + 报错** |
| 队列范围 | per-windowId 独立队列 / 全局队列+路由 | **per-windowId 独立队列** |
| 放置位置 | 独立类+Adapter持有 / 内联在Adapter中 | **独立类 + Adapter 内部持有** |
| phase 更新时机 | 入队时更新 / 执行时更新 | **执行时更新**（排队中不改 phase） |
| 待执行命令合并 | 合并待执行 / 只合并相邻 / 不合并 | **合并待执行**（toggle先解析+同windowId+同target+同displayId） |

### 2. 幂等合并与状态回读
| Question | Options | Selection |
|----------|---------|-----------|
| toggle 合并方式 | 先解析再合并 / toggle不合并 | **先解析再合并** |
| 状态回读方式 | 等回调+超时轮询 / 立即查询 / 乐观更新+事件修正 | **等回调 + 超时轮询** (500ms + 100ms×20 = 2.5s) |
| StateDesync 处理 | 报错+不自动重试 / 静默修正 / 自动重试一次 | **报错 + 不自动重试**（snapshot仍更新为真实状态） |
| 轮询参数 | 500ms+100ms×20=2.5s / 300ms+50ms×24=1.5s / 1s+200ms×10=3s | **500ms + 100ms×20 = 2.5s** |
| 轮询 API | windowManager.isFullScreen() / WindowBridge.mode / 平台特定查询 | **windowManager.isFullScreen()** |

### 3. 恢复策略细节
| Question | Options | Selection |
|----------|---------|-----------|
| 快照时机 | 调用原生前快照(含几何) / 只快照mode | **调用原生前快照**（mode+position+size+displayId） |
| maximized 恢复 | 调用 maximize() / 总是恢复几何 | **调用 maximize()**（不用几何模拟） |
| 副屏恢复 | setBounds 恢复 / 回到主屏 | **setBounds 恢复**（副屏不可用时降级主屏 center） |
| minimized 处理 | 先restore再全屏 / 拒绝请求 / 静默忽略 | **先 restore 再全屏** |

### 4. 旧实现迁移路径
| Question | Options | Selection |
|----------|---------|-----------|
| 迁移策略 | Adapter内部双实现 / 新旧入口并存 | **Adapter 内部双实现** |
| feature flag 形式 | 编译时 flag / 运行时 flag / debug/release 切换 | **编译时 --dart-define** |
| 迁移顺序 | 先迁移WindowService / UI层直接用Adapter | **先迁移 WindowService**（Phase B转发，后续UI直连） |
| UI 直调清理 | Phase B 清理 / 留到后续阶段 | **Phase B 清理** |

## Deferred Ideas

None — discussion stayed within phase scope
