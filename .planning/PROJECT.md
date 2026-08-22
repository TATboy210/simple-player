# Simple Player — 播放器 Widget 稳定性与 PC Resize 流畅度

## What This Is

Simple Player 是基于 Flutter desktop、media_kit/libmpv 的桌面媒体播放器。当前里程碑聚焦播放器 UI widget tree：在保持播放功能、视觉状态和交互契约不变的前提下，降低无效 rebuild、布局抖动和窗口频繁变换时的渲染卡顿。

## Current Milestone: v1.9 控制栏进度条修复与精简

**Goal:** 修复加载视频后控制栏进度条不显示、无法交互、鼠标悬停无 Tooltip 的三症状，同时局部重构进度条/Tooltip 相关代码减少占用。

**Target features:**
- 加载视频后进度条正常显示并反映播放进度
- 进度条可正常交互（拖拽/点击 seek）
- 鼠标悬停进度条时 Tooltip（时间预览）正常显示
- 进度条/Tooltip 相关代码局部重构，降低 rebuild/监听占用

**Key context:** v1.8 的 Phase 36 plan 36-03（ProgressBar source replacement、merged listener、timer 生命周期）未完成即切出本里程碑，三症状疑似与其未验证的 listener/生命周期改动相关。验证方式为实机验证。v1.8 未完成的 Phase 37/38 归档至 milestones/。

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
*Last updated: 2026-08-22 — v1.9 控制栏进度条修复与精简里程碑启动*
