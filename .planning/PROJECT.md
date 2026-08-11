# Simple Player — 播放器 Widget 稳定性与 PC Resize 流畅度

## What This Is

Simple Player 是基于 Flutter desktop、media_kit/libmpv 的桌面媒体播放器。当前里程碑聚焦播放器 UI widget tree：在保持播放功能、视觉状态和交互契约不变的前提下，降低无效 rebuild、布局抖动和窗口频繁变换时的渲染卡顿。

## Current Milestone

**名称：** v1.8 播放器 Widget 重构与 PC Resize 流畅度

**目标：** 先从本地 Git 历史确认最近完整 widget tree，按组件恢复缺失的功能/交互契约；随后以中等颗粒度拆分 rebuild、layout、paint 和 resize 边界，使 PC 窗口频繁最大化、还原、拖拽和尺寸变化时视频纹理、控制栏、标题栏及玻璃层保持稳定。

**恢复决策：** 不整体 checkout 历史 tree，不恢复已删除的 `ControlsOverlay`。`e0083842` 建立的 `Video.controls → PlayerVideoControls` 和 `f590cce2` 完成的直接控制栏架构继续保留；`6e0edbb8` 的标题栏优化继续保留。只在发现具体行为回归时按文件/方法应用历史实现。

## Core Value

播放器的主要功能和使用体验不变，同时让 Windows/PC 窗口频繁变换场景下的 widget rebuild、布局、raster 和纹理生命周期更稳定，减少可感知卡顿。

## Scope

- PlayerScreen、Video surface、PlayerVideoControls、ControlBar 及其局部子组件
- CustomTitleBar、GlassContainer/GlassButton、玻璃装饰和 RepaintBoundary 边界
- ValueNotifier/ValueListenableBuilder 的监听粒度与 source 生命周期
- resize session、视频纹理稳定性和 profile 观测
- 当前未提交改动的定点验证与最小修复

## Out of Scope

- 不修改 media_kit/libmpv 或底层引擎能力
- 不恢复 `ControlsOverlay`
- 不重新引入旧 fullscreen plugin
- 不引入 Provider/Riverpod/Bloc 等新的状态管理框架
- 不改变播放控制、全屏、字幕、拖放、键盘快捷键和窗口按钮的用户契约
- 不在未经确认的情况下删除或提交未追踪截图

## Constraints

- 继续使用 `ValueNotifier + ValueListenableBuilder`
- 所有视觉值使用 `Tokens.*`
- 保持 Windows 为主平台，macOS/Linux 不破坏
- 公开非平凡 API 使用文档注释；side effect 和非显然布局逻辑写清原因
- 当前工作树有未提交增量，禁止整体 reset 或覆盖
- 每个阶段先测试再扩展；提交前要求 analyzer、相关测试、review 和 diff check 通过

## Acceptance Direction

- 主要播放功能、视觉状态和交互行为自动化回归通过
- PlayerVideoControls source replacement、reparent、dispose、subtitle padding、fullscreen route 无泄漏/旧源串扰
- 窗口 resize 测试保持语义树和视频 surface identity
- Windows profile 记录关键帧耗时、resize jank 峰值和内存趋势；不得以“主观感觉流畅”替代证据
- 关键 widget rebuild 边界可解释，减少无关父树重建而不牺牲状态同步

## History

- v4.5 设置面板横向重构与音频功能：Phase 28–32 完成，Phase 33 deferred，Phase 34 skipped。
- v1.8 最近播放器稳定性提交：`e0083842` 统一 controls，`f590cce2` 稳定 resize/control rendering，`6e0edbb8` 优化 CustomTitleBar 窗口模式过渡。

---
*Last updated: 2026-08-11 — v1.8 播放器 Widget 稳定性与 PC Resize 流畅度里程碑启动*
