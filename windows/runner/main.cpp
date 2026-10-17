#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

// 窗口 frame（2026-10 起）：由 nativeapi（Dart FFI，cnativeapi 构建钩子
// 从源码编译原生库）在 Dart 侧设置 TitleBarStyle.hidden 时接管
// NCCALCSIZE/NCHITTEST（保留原生 sizing frame 与 Aero Snap、顶边带交给
// 客户区并命中 HTTOP；Win10 走无 DWM frame 模式防主题色线），runner 无需
// 任何全局配置。
// 窗口创建即隐藏（CreateWindow 无 WS_VISIBLE），可见性由 Dart 侧控制：
// WindowService 以隐藏态完成几何恢复，组合根在首帧栅格化后 reveal 亮窗
// （v0.0.4 空白窗口修复，详见 main.dart）。

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

  // UI isolate 跑在 platform 线程（2026-10 nativeapi 迁移，原为
  // RunOnSeparateThread）。必要条件而非调优：nativeapi 是纯 Dart FFI，
  // 在调用线程上直接调用 Win32 API 并安装 WINEVENT_OUTOFCONTEXT 钩子
  // （窗口最大化/恢复/缩放/焦点事件经安装线程的消息队列投递）。独立 UI
  // 线程没有消息循环 → 窗口事件永不送达；且跨线程 SetWindowPos 会在
  // platform 线程等待新尺寸帧时与 UI 线程互锁。合并线程也是 Flutter
  // 官方声明的未来默认（dart_project.h："later will be changed to running
  // the UI isolate on platform thread"）。IME/SIZEMOVE 桥的
  // SendMessageTimeoutW 在同线程下退化为直接调用 WndProc，语义不变。
  project.set_ui_thread_policy(flutter::UIThreadPolicy::RunOnPlatformThread);

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
