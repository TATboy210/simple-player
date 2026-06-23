# v1.3 Widget Performance & Architecture Optimization

## What This Is

Widget 层性能与架构优化专项。当前 Widget 层有 25 文件 ~6000 行，存在 callback drilling、重复文件、目录混乱、性能隐患等问题。本 milestone 通过全面性能审计、架构重构和代码清理，使 Widget 层达到工业级质量。

## Core Value

在不改变外部行为的前提下，让 Widget 层代码更干净、更快、更易维护。

## Milestone Scope

### In Scope

- **性能优化**: 全面审计 + 优化（rebuild 减少、BackdropFilter 降级、RepaintBoundary、Paint cache、Ticker 生命周期）
- **架构重构**: PlayerActions record（修复 callback drilling）+ 目录重组
- **代码清理**: 4 个重复文件合并、目录结构对齐

### Out of Scope

- app.dart god object 拆分 — 改动面太大，单独 milestone
- ControlBar 子组件拆分 — 当前结构可接受
- DI 迁移（6 单例→构造函数注入）— 风险高，deferred
- 新增缺失组件（VolumeSlider/SpeedButton 等）— 功能性变更，不在优化范畴
- 状态管理迁移（ValueNotifier→其他）— 已决定保留

## Context

- **Widget 层**: 25 文件 ~6000 行，lib/ui/ 下 6 个子目录
- **已有记忆**: Widget Layer Design、Widget Layer Redesign（gap analysis）
- **State 管理**: ValueNotifier + ValueListenableBuilder
- **架构模式**: 3 层（Kernel/Features/UI）
- **已知问题**:
  - PlayerScreen 接收 15+ VoidCallback
  - ControlsOverlay 接收 10+ VoidCallback
  - 4 个重复文件（keyboard_handler, drop_handler, custom_title_bar, path_validator）
  - 目录结构与 player_flutter 参考不一致
  - BackdropFilter 在 resize 时无降级（已有 respectResizeState 但不完整）
  - 部分 widget 缺少 RepaintBoundary

## Constraints

- **行为不变**: 所有优化必须通过现有测试，无功能回归
- **测试覆盖**: 优化后覆盖率 ≥80%
- **ValueNotifier 保留**: 不迁移状态管理模式
- **fvp 引擎**: 不改动引擎层代码

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| PlayerActions record 替代 callback drilling | 类型安全、减少参数传递、IDE 补全 | — Pending |
| 目录按功能域重组 | 对齐 player_flutter 参考，提高可发现性 | — Pending |
| DI 迁移推迟 | 改动面大、风险高，单独处理 | Deferred |
| app.dart 拆分推迟 | 需要更大 scope 规划 | Deferred |

## Evolution

本 milestone 完成后更新 PROJECT.md 和 ROADMAP.md。

---
*Created: 2026-06-22 for v1.3 milestone planning*
