---
status: awaiting_human_verify
trigger: "播放器全屏状态下窗口边缘还能按住拖拽改变窗口大小，正确的应该是全屏状态下鼠标放在窗口边缘不会拖拽不会改变窗口大小"
created: 2026-09-05
updated: 2026-09-05
---

## Symptoms

- 预期：全屏时四边四角不允许拖拽缩放；退出全屏恢复正常缩放。
- 实际：全屏窗口仍可通过边缘拖拽改变尺寸。
- 复现：进入播放器全屏，把鼠标放到边缘并拖拽。
- 错误信息与首次发生时间：未提供，不阻塞源码定位。
- 范围：仅原播放器的最小修复，不改 media_kit 或 window_frame_kit。

## Current Focus

hypothesis: 已确认 bitsdojo handle_nchittest 只检查 IsZoomed，不检查全屏样式；父子窗口均会触发边缘命中。
next_action: 用户重启新构建，实测全屏四边四角不可缩放、退出恢复，并确认全屏进出与关闭正常。

## Evidence

- 当前双包架构：bitsdojo 负责原生 frame/边缘命中；window_manager 负责事件与状态；全屏由 media_kit 实施。
- WindowModeCoordinator.syncFullscreenState 当前只更新模式，不操作原生 resize 能力。
- 开始时已有用户改动：lib/l10n/app_localizations{,_en,_zh}.dart、macos/Flutter/GeneratedPluginRegistrant.swift；不得覆盖。

## Resolution

root_cause: bitsdojo_window_windows 0.1.6 的 handle_nchittest（170-212）仅以 IsZoomed 屏蔽最大化缩放；media_kit 全屏摘除 WS_OVERLAPPEDWINDOW 后仍会被其识别为普通可缩放边缘。单改 Dart 或 setResizable 无法守住该路径。
fix: 用户明确批准临时 runner 原生例外。插件注册后对父子 HWND 安装 SetWindowSubclass；原生样式无 WS_OVERLAPPEDWINDOW 时 WM_NCHITTEST 返回 HTCLIENT、SC_SIZE 返回 0，其余透传；WM_NCDESTROY 自解除。不改媒体包、窗口样式或几何。后续 window_frame_kit 迁移时删除此临时 guard。
verification: 原生测试先因缺少 guard 头文件 RED，补实现后 MSVC Release /W4 /WX 构建与 CTest 1/1 通过；覆盖父子命中、8方向 SC_SIZE、退出恢复及销毁。flutter build windows --debug 成功。flutter analyze 为 0 error/0 warning/64 info，因 info 退出码1；提示均在本次未改的 Dart 文件。git diff --check 通过。未运行全量 flutter test，未声称真实播放器 UAT 通过。聚焦审查无逻辑阻塞；审查提出的 C4100 疑点不成立：EdgeProc 的 window/lparam 用于 DefSubclassProc，且 /W4 /WX 已实际编译通过，未为此屏蔽警告。
files_changed: windows/runner/fullscreen_resize_guard.h（新增）、windows/runner/flutter_window.cpp（安装）、windows/runner/CMakeLists.txt（comctl32 链接）、windows/runner/tests/CMakeLists.txt 与 fullscreen_resize_guard_test.cpp（独立原生回归）。未提交 git。
