# Phase 6: 能力探测与 C1/C2 钉死 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-02
**Phase:** 6-能力探测与 C1/C2 钉死
**Areas discussed:** 探测暴露层, C1 回归测试形态, C2 钉死范围, DWM 调用失败上报

---

## 探测暴露层（DwmCapabilities 结果给谁用）

| Option | Description | Selected |
|--------|-------------|----------|
| 1. C++ 内部快照 | runner 内静态结构体 + 日志，Dart 不感知（最小面，但 Phase 11 Linux 探测在 Dart 侧，结构不对齐） | |
| 2. C++ 探测 + MethodChannel 透出 Dart | Dart 侧 WindowBridge 可读快照，Phase 11 Linux 探测对等结构，诊断走 Dart 链 | ✓ |
| 3. Dart 侧自行探测 | 与「native window appearance belongs in runner C++」研究结论相悖 | |

**User's choice:** 选项 2 —「C++ 探测 + MethodChannel 透出，Dart 统一消费」
**Notes:** 用户补充强调 Dart 统一消费，为 Phase 11 Linux 对等结构预留形态。

## C1 回归测试形态（headless 测不出 DWM 视觉，钉什么）

| Option | Description | Selected |
|--------|-------------|----------|
| 1. C++ 纯函数抽取 + C++ harness | 最强保障，但项目零 C++ 测试基建，需新搭 | |
| 2. Gate 脚本 + 结构契约 | 守卫注释存在性 + NCCALCSIZE 分支结构指纹 + 禁裸 `return 0` grep gate + 实机 UAT 清单（复用 `tool/audit/` 先例） | ✓ |
| 3. 双层都要 | C++ harness + gate 脚本 | |

**User's choice:** 选项 2 — gate 脚本 + 结构契约
**Notes:** 无补充；实机 UAT 清单承接「缝隙 headless 不可见」研究结论。

## C2 钉死范围

| Option | Description | Selected |
|--------|-------------|----------|
| 1. 一起钉 | gate 加一条 grep：全项目禁止读 `VideoState.isFullscreen` 作全屏信号 | ✓ |
| 2. 只钉 C1 | C2 留文档 | |

**User's choice:** 选项 1 —「便宜，一行规则」
**Notes:** 阶段标题含 C1/C2，用户选择补齐 ENAB-02 之外的 C2 钉死。

## DWM 调用失败上报路径（HRESULT 非 S_OK）

| Option | Description | Selected |
|--------|-------------|----------|
| 1. 仅 KernelLogger | 最小，符合现状惯例 | |
| 2. 接入 ErrorReporter 弹卡 | 可定位性强，但 DWM 失败非致命，弹卡可能太吵 | |
| 3. KernelLogger + 首次聚合上报 | 每次失败必记日志；同类失败首次聚合一条 ErrorReport（复用 v1.0 语义去重） | ✓ |

**User's choice:** 选项 3 —「卡片不刷屏」
**Notes:** 无补充。

## Claude's Discretion

- MethodChannel 名称与消息结构
- C++ 侧日志出口（OutputDebugString / channel 透传）
- gate 脚本命名与参数化
- 探测结构体字段命名（对齐 Phase 11 对等形态）

## Deferred Ideas

None — discussion stayed within phase scope
