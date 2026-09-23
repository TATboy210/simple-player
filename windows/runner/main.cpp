#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <bitsdojo_window_windows/bitsdojo_window_plugin.h>

#include "flutter_window.h"
#include "utils.h"

// BB 同款全局配置（2026-09-06 用户裁决，window_manager + bitsdojo 双包）：
// bitsdojo 接管 NCCALCSIZE/NCHITTEST（BDW_CUSTOM_FRAME），自绘客户区扩展
// 到整窗，四边等宽原生 resize 判定 + 无系统主题色边框，系统标题栏由自绘
// 标题栏（custom_title_bar.dart）替代。
// 不用 BDW_HIDE_ON_STARTUP——窗口创建即隐藏（CreateWindow 无 WS_VISIBLE），
// 可见性由 Dart 侧控制：WindowService 以隐藏态完成几何恢复，组合根在首帧
// 栅格化后 reveal 亮窗（v0.0.4 空白窗口修复，详见 main.dart）。
auto bdw = bitsdojo_window_configure(BDW_CUSTOM_FRAME);

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  // BB 同款（2026-09-06 窗口帧数配置）：显式锁定 UI isolate 独立线程。
  // Flutter Windows 的 Default 当前即为独立线程（dart_project.h 官方注释
  // "Currently will run the UI isolate on separate thread, later will be
  // changed to running the UI isolate on platform thread"），BB 以注释行
  // 形式保留同一配置。显式设置的意义：
  // 1) 锁定行为 — 阻止未来 Flutter SDK 把默认切到 platform 线程后，UI 帧
  //    调度与 platform 线程上的原生模态 resize loop（WM_SIZE 风暴）、
  //    控制台 I/O 重新合并争线，导致拖拽 resize 掉帧回归；
  // 2) 独立线程下 Dart 帧流水线（build/layout/raster 调度）与原生窗口
  //    消息处理解耦，快速拖拽边框时帧率更稳。
  // MethodChannel 插件（window_manager/bitsdojo/media_kit）均走 messenger
  // 线程无关路径，不受此策略影响；纹理仍由 raster 线程消费。
  project.set_ui_thread_policy(flutter::UIThreadPolicy::RunOnSeparateThread);

  // 毛玻璃取证开关（v0.0.8.2 A/B，协议见 docs/audit/glass-perf-ab.md）：
  // SIMPLER_PLAYER_FORCE_SKIA=1 → 禁用 Impeller 走 Skia。
  // 用环境变量而非命令行 flag——命令行参数会经 set_dart_entrypoint_arguments
  // 混入 Dart 入口参数流；环境变量零污染，同一产物即可双后端对比。
  // 不设或值非 "1" 时行为与 SDK 默认（ImpellerSwitch::Default）完全一致。
  // A/B 裁决后按结论保留（锁 Skia）或删除本段（E1 阶段落锤）。
  wchar_t force_skia[2] = {0};
  if (::GetEnvironmentVariableW(L"SIMPLER_PLAYER_FORCE_SKIA", force_skia, 2) ==
          1 &&
      force_skia[0] == L'1') {
    project.set_impeller_switch(flutter::ImpellerSwitch::Disabled);
  }

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"flutter_windows", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
