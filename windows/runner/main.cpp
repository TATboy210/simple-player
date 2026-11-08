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
                      _In_ wchar_t *command_line, _In_ int show_command)
{
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent())
  {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  // UI isolate 保持 Flutter 默认的独立线程（2026-10 nativeapi 0.5.10）。
  // nativeapi 0.5.3 起把 Windows 窗口观察（WinEvent 钩子与子类化）安装到
  // 窗口所属线程，默认线程策略的 Flutter 应用仍能收到焦点/生命周期/几何
  // 事件；窗口状态调用从 UI isolate 发出时会自行 marshal 到窗口线程，因此
  // 不再需要把 UI isolate 合并进 platform 线程。IME 桥继续经
  // SendMessageTimeoutW 投递消息，与 Dart 线程模型无关。
  project.set_ui_thread_policy(flutter::UIThreadPolicy::RunOnSeparateThread);

  // 渲染后端（2026-11-07 A/B 裁决，数据见 docs/audit/glass-perf-ab.md）：
  // 默认锁 Skia——Flutter 3.47 Windows 的 Impeller（经 ANGLE 走 GLES）在窗口
  // 拖拽缩放时 raster P95 约 19~27ms，Skia 约 15~17ms，jank60 近乎减半。
  // SIMPLER_PLAYER_FORCE_IMPELLER=1 → 回到 SDK 默认（Impeller），供复测对比。
  // 用环境变量而非命令行 flag——命令行参数会经 set_dart_entrypoint_arguments
  // 混入 Dart 入口参数流；环境变量零污染，同一产物即可双后端对比。
  wchar_t force_impeller[2] = {0};
  const bool use_impeller =
      ::GetEnvironmentVariableW(L"SIMPLER_PLAYER_FORCE_IMPELLER", force_impeller,
                                2) == 1 &&
      force_impeller[0] == L'1';
  if (!use_impeller)
  {
    project.set_impeller_switch(flutter::ImpellerSwitch::Disabled);
  }

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"flutter_windows", origin, size))
  {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0))
  {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
