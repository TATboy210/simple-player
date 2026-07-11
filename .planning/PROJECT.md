# Player Fullscreen — v3 架构简化

## What This Is

将 `simple_player_flutter` 的全屏功能从 5 层过度抽象（3,248 行）简化为 2 层直接架构（~800 行）。v1 建立了 FullscreenAdapter、CommandQueue、状态机、7 种错误类型、7 种事件类型——对于单窗口媒体播放器来说过度工程化。

**核心洞察：** fullscreen_window 包用 30 行 C++ 实现全屏 toggle。我们的 Win32 FFI 实现（600 行）解决了它没解决的问题（多显示器、WS_THICKFRAME、防闪烁）。但上面的 Adapter/CommandQueue/Model 层（~2,400 行）是不必要的抽象。

## Core Value

**全屏 = 视频占满屏幕 + 控制栏正常工作。** 不需要 5 层抽象、7 种错误类型、命令队列、状态机来管理一个 bool。

## Architecture: Before vs After

```
BEFORE (5 layers, 3,248 lines):
UI → WindowService → FullscreenAdapter → CommandQueue → FullscreenDriver → Platform

AFTER (2 layers, ~800 lines):
UI → WindowService → FullscreenDriver → Platform
```

## Requirements

### Validated

- ✓ WindowMode 枚举 — 已有
- ✓ window_manager 初始化、尺寸恢复 — 已有
- ✓ Win32 FFI 重写（WS_THICKFRAME、多显示器钳位、防闪烁）— v1 已完成
- ✓ macOS NSWindowDelegate 回调 — v1 已完成
- ✓ Linux GTK 信号回调 — v1 已完成
- ✓ 5 个全屏 bug 已修复 — 已有

### Active (v3 Simplification)

- [ ] SIMPLIFY-01: 删除 FullscreenAdapter 抽象层（68 行）— 只有 1 个实现，不需要多态
- [ ] SIMPLIFY-02: 删除 FullscreenCommandQueue（258 行）— 单窗口不需要命令队列
- [ ] SIMPLIFY-03: 删除 4 个 Model 类（431 行）— FullscreenSnapshot/Error/Event/Request 用 try/catch + ValueNotifier 替代
- [ ] SIMPLIFY-04: 合并 DesktopFullscreenAdapter 逻辑进 WindowService — 消除双状态系统
- [ ] SIMPLIFY-05: 精简 FullscreenDriver 接口（15 方法 → 5 方法）
- [ ] SIMPLIFY-06: 借鉴 plugin_platform_interface 模式建立联合插件地基
- [ ] SIMPLIFY-07: Windows x86 + ARM 自适应 FFI（user32.dll 跨架构一致）
- [ ] SIMPLIFY-08: macOS/Linux 复用 fullscreen_window 原生代码

### Out of Scope

- 独立 pub 包发布 — 先在项目内完成
- D3D11 独占全屏 — 探索性，不在简化范围内
- 全屏动画统一 — 简化后再考虑
- Web/Mobile — 桌面优先

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 删除 Adapter+CommandQueue | 单窗口 app 不需要 per-window 队列和多态接口 | — Pending |
| 保留 Win32 FFI 核心 | 解决真实问题（多显示器、WS_THICKFRAME、防闪烁） | ✓ 已确认 |
| 借鉴 plugin_platform_interface | 编译时类型安全 + 平台注入模式 | — Pending |
| x86/ARM 不需要分支代码 | Win32 API 跨架构一致，Flutter 构建时自动选择 | ✓ 已确认 |
| macOS/Linux 复用 fullscreen_window | 原生代码写得好，不需要重写 | ✓ 已确认 |

## Context

- **逆向分析完成**: fullscreen_window v1.2.1 完整分析（702 行核心代码）
- **现有实现分析**: 18 源文件 4,368 行，8 测试文件 3,555 行
- **研究文件**: `.planning/research/` 下 6 份报告
- **记忆参考**: [[reference_fullscreen_window_reverse]] [[anti_pattern_fullscreen_architecture]]

## Evolution

This document evolves at phase transitions and milestone boundaries.

---

*Last updated: 2026-07-11 — v3 simplification direction after reverse engineering analysis*
