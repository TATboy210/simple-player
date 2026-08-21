---
status: investigating
trigger: "请审查当前仓库 Windows runner、CMakeLists 和 media_kit 初始化，重点判断清理 build 后 exe 无法启动的原因。检查是否有最近改动引入崩溃或 CMake policy 作用域问题，给出具体修复建议；不要提交。"
created: 2026-08-18T00:00:00+08:00
updated: 2026-08-18T00:00:00+08:00
---

## Current Focus
hypothesis: 至少存在两条需区分的候选链路：CMake CMP0175 设置可能未传播到 media_kit 子目录，导致 clean configure/build 失败；同时最近 runner 重构可能引入运行时启动崩溃。先用实际插件 CMake 作用域与静态启动链路验证。
test: 完整读取 Windows runner、media_kit 插件 CMake、Dart 初始化和最近提交差异，并对 clean configure 结果做隔离实验。
expecting: 若 policy 作用域问题成立，插件自己的 cmake_minimum_required(3.14) 会使顶层 CMP0175 OLD 无效；若 runner 崩溃成立，应找到确定的空句柄/错误消息处理。
next_action: 运行隔离的 CMake configure，观察 CMP0175 是否在插件子目录触发错误或警告。

## Symptoms
expected: 清理 build 后重新构建的 Windows exe 能正常启动。
actual: 清理 build 后 exe 无法启动；具体错误日志未提供。
errors: 未提供运行时错误、退出码或事件查看器信息。
reproduction: 清理 build 目录后构建 Windows exe，启动 exe。
started: 未提供；需结合最近改动静态判断。

## Eliminated

## Evidence

- timestamp: 2026-08-18T00:00:00+08:00
  checked: windows/runner/main.cpp, flutter_window.cpp, win32_window.cpp and their diff against HEAD
  found: Current runner reaches FlutterWindow::Create, constructs FlutterViewController, checks engine/view, registers plugins, and the existing debug executable produced normal MediaKit/ANGLE/PlayerFeature startup logs. No deterministic null dereference was found in the reviewed startup path.
  implication: The reported inability to start is not reproduced by the current existing executable; the recent runner rewrite has robustness regressions but no proven clean-build-only crash from static inspection.

- timestamp: 2026-08-18T00:00:00+08:00
  checked: windows/flutter/ephemeral/.plugin_symlinks/media_kit_libs_windows_video/windows/CMakeLists.txt
  found: The plugin calls cmake_minimum_required(VERSION 3.14) and defines two add_custom_command(TARGET ...) calls without PRE_BUILD/PRE_LINK/POST_BUILD keywords (lines 90-97 and 126-130). It is a separate add_subdirectory scope.
  implication: A plain cmake_policy(SET CMP0175 OLD) in the top-level directory is not a reliable way to configure the plugin scope; CMAKE_POLICY_DEFAULT_CMP0175 OLD is the relevant compatibility mechanism. The current uncommitted variable is directionally correct, but should be validated with the actual CMake version and configure log.

- timestamp: 2026-08-18T00:00:00+08:00
  checked: lib/main.dart, PlayerServices, MediaKitEngine and generated plugin list
  found: MediaKit.ensureInitialized() runs before PlayerServices creates Player; windowManager.ensureInitialized() runs before WindowService.init(); media_kit_libs_windows_video is generated and registered, and a launched debug artifact logged native libmpv allocation and ANGLE initialization successfully.
  implication: Dart media_kit initialization order is correct and is unlikely to explain a process that cannot start after clean build. Missing runtime bundle assets/DLLs remain a packaging hypothesis, not an initialization-order finding.

- timestamp: 2026-08-18T00:00:00+08:00
  checked: CMake configure/build tooling
  found: bash cannot resolve cmake, while the existing build cache records CMake 4.3.1; therefore a fresh configure/build was not executed in this shell.
  implication: Clean-build failure mode remains unverified and must be tested with the Visual Studio CMake executable or flutter build windows --verbose.

## Resolution
root_cause: 尚未能把“clean build 后 exe 无法启动”归因到单一已复现根因。已确认 CMake CMP0175 存在子目录 policy 作用域风险；Dart media_kit 初始化顺序正确；当前 runner 静态检查未发现确定性启动崩溃。最优先验证的是 clean 构建产物是否缺少 libmpv-2.dll/ANGLE DLL 或 CMake configure/build 是否失败。
fix: 不修改代码；给出针对性修复建议和验证步骤。
verification: 已直接启动现有 Debug exe 并观察到 MediaKit NativeReferenceHolder、ANGLE、VideoOutput、PlayerFeature init 日志；未完成 clean configure/build，也未获得用户的发布目录错误信息。
files_changed: []
