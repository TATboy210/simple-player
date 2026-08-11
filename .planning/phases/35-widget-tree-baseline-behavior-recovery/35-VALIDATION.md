---
phase: 35
slug: widget-tree-baseline-behavior-recovery
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-11
---

# Phase 35 — 验证策略

本阶段以现有 fake-port/widget 测试锁定当前 controls tree 与生命周期契约；不启动真实 libmpv/MDK，不以 Windows GUI/profile 取代 headless 自动化。真实 fullscreen、OS 拖放和 profile 证据由 Phase 38 收集。

## 测试基础设施与隔离

| 项目 | 约定 |
|---|---|
| 框架 | `flutter_test`；widget tests 是本阶段的集成式行为门。 |
| Quick gate | `flutter test test/widget/shared/glass_button_test.dart test/widget/player/player_video_controls_test.dart test/widget/player/player_screen_window_bridge_replacement_test.dart test/widget/player/player_screen_accessibility_resize_test.dart test/widget/player/player_screen_stop_empty_state_test.dart test/widget/player/player_keyboard_actions_test.dart test/widget/player/drop_handler_test.dart test/integration/controls_flow_test.dart test/integration/error_propagation_test.dart` |
| 静态门 | `flutter analyze` 与 `git diff --check`。 |
| Native 隔离 | 所有新增 PlayerScreen/controls 测试必须注入 `videoSurfaceBuilder`、`FakeVideoControlsPort`、`FakeWindowService`，不得构造真实 media_kit surface、WindowService 或 MDK。 |
| 已有 FFI 失败 | `flutter test` 全套中的 `mdk.dll` 失败不是本阶段的豁免。若 quick gate 出现 FFI 失败，保留失败列表，在临时 detached `HEAD` worktree 复跑**完全相同命令**，然后删除 worktree；同样失败且与 Phase 35 触达模块无交集才记录为既有环境失败，否则阻塞。禁止 stash/reset/checkout/restore 当前工作树。 |

## 每任务自动化映射

| 任务 | Plan | Wave | 要求 | 自动化命令 | 状态 |
|---|---|---:|---|---|---|
| 历史与当前树基线 | 01-1 | 1 | BASE-01, BASE-02 | `git diff --check` 加四段只读 `git diff --name-status` | pending |
| 行为 quick gate | 01-2 | 1 | BASE-03 | 上述 Quick gate；随后独立 `flutter analyze`、`git diff --check` | pending |
| WindowBridge replacement | 02-1 | 2 | BASE-02, BASE-03 | `flutter test test/widget/player/player_screen_window_bridge_replacement_test.dart test/widget/player/player_screen_accessibility_resize_test.dart` | pending |
| GlassButton 最新 callback | 02-2 | 2 | BASE-04 | `flutter test test/widget/shared/glass_button_test.dart` | pending |
| source/reparent 隔离 | 03-1 | 2 | BASE-05 | `flutter test test/widget/player/player_video_controls_test.dart --plain-name "reparent 同时替换全部 source 后只响应新依赖"` | pending |
| padding/dispose 隔离 | 03-2 | 2 | BASE-05, BASE-03 | `flutter test test/widget/player/player_video_controls_test.dart`；随后 Quick gate、`flutter analyze`、`git diff --check` | pending |

## 采样与判定

- 每个任务先运行其最小命令；Wave 1 完成后运行 Quick gate；Wave 2 两个计划完成并合并后再运行 Quick gate、`flutter analyze` 与 `git diff --check`。
- 不使用 watch mode；最小测试文件为秒级反馈，Quick gate 可接受为 wave 级反馈。
- 任何失败均保留原始输出与失败测试名；不得 skip、删断言或放宽 matcher。生产修复必须由新增/强化测试先红后绿授权。

## Wave 0

无缺失测试基础设施：现有 fake 已覆盖 PlayerVideoControls，Plan 02 任务 1 在 Wave 2 创建 WindowBridge replacement 测试，且该任务本身先写测试再实施。所有任务均有可运行 `<automated>` 命令。

## 手工边界

| 行为 | 原因 | 归属 |
|---|---|---|
| 原生 Windows fullscreen route、真实 OS 文件拖放、纹理/profile | 依赖 GUI/native runtime，不能在 headless fake-port gate 中证明 | Phase 38 |
