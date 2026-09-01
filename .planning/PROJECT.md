# Simple Player — 窗口外观与全屏体验

## What This Is

Simple Player 是基于 Flutter desktop、media_kit/libmpv 的桌面媒体播放器。本里程碑解决窗口外壳层的四个体验问题：系统主题色渗透（Win10 红边）、跨平台圆角一致性、全屏进出过渡闪烁、自绘标题栏拖拽偶发不跟手。窗口视觉与交互完全由应用自绘控制，不受系统主题与平台差异污染。服务于开发者本人日常使用。

## Current Milestone: v1.1 窗口外观与全屏体验

**Goal:** 窗口视觉跨平台一致（圆角、无系统主题色污染），全屏过渡无闪烁，标题栏拖拽稳定跟手。

**Target features:**
- 去主题色边框：Win10 上窗口边缘被系统主题强调色（用户案例红色）描边，彻底消除
- 圆角统一：Win11 原生 DWM 圆角；Win10/Linux 方案（伪圆角 or 直角）等研究结论再定；Linux（SteamOS/通用桌面）按通用方案实现正确
- 全屏过渡无闪烁：进入时标题栏/边框闪现 + 尺寸跳变、退出时闪烁，三个症状全消
- 标题栏拖拽可靠性：自绘标题栏拖动偶发不跟手，达到必现跟手

**Key context:**
- 全屏后边缘有缝的问题已解决（v1.0 前修复），本里程碑不动
- 「标题栏闪现」2026-08-27 曾暂缓（当时全局 DWMNCRP 方案已撤回、勿重提），本次重新攻坚需找新路径
- 窗口为 frameless（runner WM_NCCALCSIZE return 0 + window_manager setAsFrameless），系统 resize 由 SmartDragToResizeArea 兜底——拖拽问题与此链路同源，一并排查
- Linux 无实机——实现正确性以通用桌面方案为准，交付物标记「待实机验证」
- 研究工具：Context7 文档 + GitHub 同类播放器（mpv 前端、IINA 等）方案调研

## Core Value

**窗口外壳完全自绘自治**：系统主题、平台差异不得渗透到窗口视觉与交互——红边、圆角缺失、全屏闪烁、拖拽失灵都是这一原则的违反；用户在任何系统上看到的窗口都是应用自己的样子。

## Scope

- windows/runner（C++ 层：WM_NCCALCSIZE / DWM 属性 / 拖拽消息链路）
- lib/kernel/window_Bridge/（窗口模式协调、全屏切换链路）
- lib/ui/window/custom_title_bar.dart（自绘标题栏拖拽入口）
- media_kit 全屏功能链路（本里程碑授权解禁，仅限全屏部分）
- Linux 桌面（GTK/ Wayland/X11）窗口外壳适配的结构性实现

## Out of Scope

- 全屏后边缘有缝问题 — 已解决，不重开
- 播放功能演进 — 与窗口外壳无关
- media_kit 非全屏部分（播放/轨道/字幕链路）— 红线仅对全屏功能解禁
- macOS 窗口外壳 — 结构性支持存在但非发布目标，本里程碑不验证
- 全局 DWMNCRP 方案 — 2026-08-27 已撤回，勿重提

## Context

- **frameless 现状**：白边修复时采用 setAsFrameless（WM_NCCALCSIZE return 0），代价是失去系统 resize，靠 SmartDragToResizeArea 兜底；红边与拖拽问题都发生在这条链路上
- **全屏链路现状**：当前走 media_kit 链路（用户授权本里程碑解禁该部分红线）；此前方案 A（FFI 桥）/方案 B（DWM 禁用）实机效果不理想已 revert，「全屏样式权威收编」记录了技术事实（route+utils.cc 双层链路/Vulkan 不可行/wm.setFullScreen frameless 缺陷），重启攻坚前先采集撤回时具体症状
- **Win10 圆角**：原生不支持窗口圆角（Win11 才有 DWM 圆角），伪圆角 = 窗口透明 + Flutter 层裁剪，有性能与锯齿代价——取舍等研究结论
- **拖拽偶发不跟手**：用户观察到极小概率拖动无效，疑似 window_manager startDragging 或 hit-test 时序问题
- **v1.0 归档**：错误捕获定位反馈系统已发布（ErrorCard 全链路），本里程碑与其正交

## Constraints

- **Unix 九原则**（用户钦定，取舍最高依据）：小即是美/只做好一件事/快建原型/可移植优先/纯文本存储/软件杠杆/shell 脚本/避免强制式 UI/程序皆过滤器
- **media_kit 红线（部分解禁）**：本里程碑仅允许为全屏功能修改 media_kit 相关代码；其余部分（播放/轨道/字幕）仍不可改动
- **质量红线**：flutter analyze 0 error；flutter test 全绿
- **状态管理惯例**：ValueNotifier + ValueListenableBuilder，不引入新状态库
- **平台边界**：Windows 实机验证为主；Linux 结构性正确即可并标记待实机验证

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| media_kit 红线仅为全屏功能解禁 | 全屏链路问题源自该链路；其余能力不动 | — Pending |
| 圆角方案等研究结论再定 | Win10 伪圆角有代价，先看同类播放器怎么做 | — Pending |
| 全局 DWMNCRP 不重提 | 2026-08-27 实机效果不理想已撤回 | ✓ 已定 |
| Linux 标记待实机验证 | 无实机，只保证实现正确 | ✓ 已定 |
| 全屏缝隙不重开 | 已解决 | ✓ 已定 |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition:** requirements 增删、决策补录、"What This Is" 漂移修正
**After each milestone:** 全节审查、Core Value 复核、Out of Scope 审计

---
*Last updated: 2026-09-01 after milestone v1.1 start*
