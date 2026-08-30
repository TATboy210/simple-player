# Simple Player — 错误捕获定位反馈系统

## What This Is

Simple Player 是基于 Flutter desktop、media_kit/libmpv 的桌面媒体播放器。本里程碑为播放器建立统一的错误捕获→定位→反馈系统：四类错误接入全局钩子，出错时左上角滑入非模态错误卡片，显示定位信息与源码行，自动落盘纯文本日志。服务于开发者本人日常使用，出错时可即时定位问题方位。

## Current Milestone: v2.1 错误捕获定位反馈系统

**Goal:** 全局错误钩子零接入 → 四类错误全捕获，出错可定位、可复制、可回溯。

**Target features:**
- 四类错误全捕获：UI/框架异常、异步未捕获异常、播放引擎错误、启动期异常
- 左上角非模态错误卡片：常驻手动关，不遮挡控制栏/标题栏交互区
- 卡片详情：文件:行号 + 源码行（release 优雅降级）+ 完整调用栈 + 一键复制 + 日志路径 + 媒体路径
- 错误自动落盘：ErrorReporter 副作用链新增 FileSink（dart:io append+flush 单写者；logger FileOutput 不按条 flush 已证实弃用），仅错误事件上盘，单文件追加纯文本
- 设置"通用"tab：错误卡片开关（默认开）+ 日志输出路径可配置
- 替换旧 ErrorBanner，所有错误统一走新卡片

**Key context:** v1.9（进度条三症状）停在 Phase 39 Wave 2 未完成，已归档至 `.planning/milestones/v1.9-progress-bar/`（进度记录完整保留可恢复）。

## Core Value

**出错可定位**：任何错误发生时，无需接调试器即可知道错误在哪个文件哪一行、调用链是什么，一键复制或从日志文件回溯——出错不再是无名黑盒。

## Scope

- lib/kernel/diagnostics/（error_reporter 新建 + kernel_logger 扩展 FileSink）
- main.dart / app.dart（全局错误钩子：FlutterError.onError、PlatformDispatcher.onError、runZonedGuarded）
- 播放引擎错误通道（PlayerError → error_reporter 统一汇入）
- 左上角错误卡片 widget（非模态、不遮挡交互区）
- settings_dialog 通用 tab（开关 + 输出路径）
- 旧 ErrorBanner 撤除整合

## Out of Scope

- 播放功能演进（自动下一首/播放列表）— 与错误反馈无关
- 远程上报/遥测（Sentry/Crashlytics）— 个人桌面应用无此需求
- 日志轮转/压缩/加密 — 单文件追加已满足
- 其他 UI 功能 — 本里程碑只做错误反馈

## Context

- **零全局错误钩子现状**：`FlutterError.onError`/`PlatformDispatcher.onError`/`runZonedGuarded` 全项目零匹配，未捕获异常直接崩溃/红屏
- **诊断设施已备**：lib/kernel/diagnostics/ 已有 8 文件（kernel_logger 三 sink、MemoryMonitor、startup_timeline 等），在其上扩展而非重写
- **logger ^2.7.0 弃用修订（2026-08-30）**：FileOutput 不按条 flush（仅 destroy 时刷）且 kernel gate 禁止 lib/kernel/ 导入 package:logger，FileSink 改 dart:io 直写；后续可从 pubspec 移除 logger
- **旧 ErrorBanner**：已展示播放引擎错误（监听 engine.lastError），将被统一替换
- **媒体路径来源**：PlaybackController.currentPath
- **v1.9 归档**：见 Key context

## Constraints

- **Unix 九原则**（用户钦定，取舍最高依据）：小即是美/只做好一件事/快建原型/可移植优先/纯文本存储/软件杠杆/shell 脚本/避免强制式 UI/程序皆过滤器
- **media_kit 不可改动**（memory 红线）：只处理项目封装/UI/测试层
- **质量红线**：flutter analyze 0 error；flutter test 全绿
- **状态管理惯例**：ValueNotifier + ValueListenableBuilder，不引入新状态库

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 四类错误全捕获 | 全覆盖无盲区 | ✓ Phase 01（UAT 16/16） |
| 左上角非模态卡片常驻手动关 | 不遮挡交互 + 不丢错误 | — Pending |
| 源码行 release 优雅降级 | 读不到源码退化为定位文本 | — Pending |
| 仅错误上盘 | 文件干净易读 | — Pending |
| kernel_logger 门面 + logger 包输出 | 存量零改动 + 杠杆效应 | ✓ Phase 01（沿用） |
| 新建 error_reporter 独立服务 | 各司其职（原则 2） | ✓ Phase 01（含语义去重/路径净化） |
| 统一替换旧 ErrorBanner | 一套展示逻辑 | — Pending |
| 设置开关 + 输出路径可配 | 关卡片不关落盘 | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition:** requirements 增删、决策补录、"What This Is" 漂移修正
**After each milestone:** 全节审查、Core Value 复核、Out of Scope 审计

---
*Last updated: 2026-08-30 after Phase 02*
