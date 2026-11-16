#include "flutter_window.h"

#include <imm.h>
#include <iterator>
#include <optional>
#include <shobjidl.h>
#include <string>
#include <thread>

#include "flutter/generated_plugin_registrant.h"
#include "ime_bridge_messages.h"

namespace {
// 关门专线：Dart 启动后经 SetCloseNotifier 注册一个无参回调
// （FFI NativeCallable.listener，可自 platform 线程安全唤起 UI isolate）。
// WM_CLOSE 有通知器时直接消费并唤起 Dart 的 hide-first persist→exit 时序；
// 未注册（启动极早期/降级）则放行默认销毁 — 旧的 close_bridge_messages
// SC_CLOSE 转换路径已退役（事件流退订后它等价于放行销毁，见 CONTRACT.md）。
// 指针在 Dart 侧永久保活：热重启后新注册覆盖旧值；空窗期极小且仅在 debug。
using CloseNotifier = void (*)();
CloseNotifier g_close_notifier = nullptr;

// 主窗口句柄槽 — OnCreate 写入、OnDestroy 清空。Dart 侧经
// SimplerPlayerGetMainWindowHandle 读取（隐藏态即可用，不依赖焦点/枚举）。
HWND g_main_window = nullptr;
}  // namespace

// C 链接导出（x64 无修饰名），Dart 经 DynamicLibrary.process() 查找。
extern "C" __declspec(dllexport) void SetCloseNotifier(CloseNotifier notifier) {
  g_close_notifier = notifier;
}

// C 链接导出 — 主窗口句柄（三平台同名符号，见 platform/window_handle_locator.dart）。
extern "C" __declspec(dllexport) void* SimplerPlayerGetMainWindowHandle() {
  return g_main_window;
}

// 最小外框尺寸（逻辑像素）— Dart 侧 WindowService 在 init 时设置。
// 走 runner 导出符号 + WM_GETMINMAXINFO 而不是 nativeapi 的 minimumSize
// setter：后者经 WindowMessageDispatcher 注册 handler 时会对宿主窗口做
// GWLP_WNDPROC 全量替换（libnativeapi/nativeapi#30 根因 4），拖拽期间
// 每条 WM_NCHITTEST/WM_SETCURSOR/WM_SIZING（每秒数百条）都要付 dispatcher
// 的互斥锁快照 + handler 遍历 + 排序。WM_GETMINMAXINFO 走 DefWindowProc
// 既有查询点，拖拽热路径零额外开销。macOS/Linux 无此问题，继续走
// nativeapi setter（见 NativeapiWindow.minimumSize 的平台分派）。
SIZE g_min_window_size = {0, 0};  // 逻辑像素；0 表示未设置。

extern "C" __declspec(dllexport) void SimplerPlayerSetMinWindowSize(
    int32_t width, int32_t height) {
  g_min_window_size = SIZE{width, height};
}

// ── 原生文件对话框（性能修复：windows_file_picker 2.0.2 的 compute-isolate
// 架构在辅助线程冷启动 COM，点击到对话框出现实测 6~10s；本机主线程 STA
// 直调同款对话框基线 149ms —— 见 tool 层的 OS 轮询取证记录）。
//
// Dart 侧经 FFI 同步调用：platform 线程进入 Show() 的模态循环直到用户
// 选择/取消。期间 Dart UI isolate 冻结在 FFI 里 —— 与模态语义一致
// （对话框期间本无交互），ModalHoldObserver 的冻结逻辑兼容。
// IMC 状态：Dart 在调用前已经 Win32ImeBridge.enable 恢复（同线程
// SendMessageTimeoutW 投递完成才返回），对话框子窗口创建时 IMC 在位，
// v0.0.8 的 msctf NULL-IMC 崩溃路径不成立；调用方在 finally 里 disable。
//
// 返回码：1 = 选中（out_path 含完整路径）；0 = 用户取消；
// 负值 = COM/参数错误（HRESULT 低 32 位）。
extern "C" __declspec(dllexport) int32_t SimplerPlayerShowOpenDialog(
    const wchar_t* filter_spec,     // 分号分隔扩展名，如 L"mkv;mp4;avi"
    int32_t lock_parent_window,     // 1 = 模态前置于主窗口
    wchar_t* out_path,              // Dart 预分配输出缓冲
    int32_t out_path_capacity) {    // out_path 的 wchar 容量
  if (!filter_spec || !out_path || out_path_capacity <= 0) {
    return -1;
  }
  out_path[0] = L'\0';

  // runner 主线程由 Flutter 引擎完成 COM 初始化（STA）；显式调用一次以
  // 覆盖极端顺序，已初始化时 S_FALSE/RPC_E_CHANGED_MODE 均不视为错误。
  HRESULT co_hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  const bool need_co_uninit = SUCCEEDED(co_hr);

  IFileOpenDialog* dialog = nullptr;
  int32_t result = 0;
  HRESULT hr =
      CoCreateInstance(CLSID_FileOpenDialog, nullptr, CLSCTX_INPROC_SERVER,
                       IID_PPV_ARGS(&dialog));
  if (FAILED(hr) || !dialog) {
    result = static_cast<int32_t>(static_cast<int64_t>(hr));
    if (need_co_uninit) CoUninitialize();
    return result;
  }

  // filter: "mkv;mp4;avi" → COMDLG_FILTERSPEC{ 名称 = "媒体文件",
  // 规格 = "*.mkv;*.mp4;*.avi" } + 全类型兜底（对齐 windows_file_picker
  // 的 FileType.custom 语义：picker 层过滤 + 播放链路 PathValidator 双保险）。
  std::wstring spec = L"*.";
  spec += filter_spec;
  size_t pos = 0;
  while ((pos = spec.find(L";", pos)) != std::wstring::npos) {
    spec.replace(pos, 1, L";*.");
    pos += 3;
  }
  const COMDLG_FILTERSPEC filters[] = {
      {L"媒体文件", spec.c_str()},
      {L"所有文件 (*.*)", L"*.*"},
  };
  dialog->SetFileTypes(static_cast<UINT>(std::size(filters)), filters);
  dialog->SetFileTypeIndex(1);

  DWORD options = 0;
  dialog->GetOptions(&options);
  options |= FOS_PATHMUSTEXIST | FOS_FILEMUSTEXIST | FOS_FORCEFILESYSTEM;
  dialog->SetOptions(options);

  HWND parent =
      lock_parent_window && g_main_window ? g_main_window : nullptr;
  hr = dialog->Show(parent);
  if (SUCCEEDED(hr)) {
    IShellItem* item = nullptr;
    if (SUCCEEDED(dialog->GetResult(&item)) && item) {
      PWSTR path = nullptr;
      if (SUCCEEDED(item->GetDisplayName(SIGDN_FILESYSPATH, &path)) && path) {
        if (wcsnlen_s(path, static_cast<size_t>(out_path_capacity)) <
            static_cast<size_t>(out_path_capacity)) {
          wcscpy_s(out_path, static_cast<size_t>(out_path_capacity), path);
          result = 1;
        } else {
          result = -2;  // 路径超出 Dart 侧缓冲容量
        }
        CoTaskMemFree(path);
      }
      item->Release();
    }
  } else if (hr == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
    result = 0;  // 用户取消
  } else {
    result = static_cast<int32_t>(static_cast<int64_t>(hr));
  }

  dialog->Release();
  if (need_co_uninit) CoUninitialize();
  return result;
}

// ── 异步版（A.2）：对话框跑在独立 STA 线程，platform 线程（= Dart UI
// isolate）不被阻塞 —— 同步版的 Show() 模态循环会把 UI isolate 冻结在
// FFI 里整个对话框存活期（实测：ESC 失效、点击积压"关了又弹"、hot
// reload/日志全部超时）。结果经 callback(request_id, code, path) 回投：
// path 由 new wchar_t[] 分配，Dart 读取后必须调 SimplerPlayerFreeString
// 释放（与 delete[] 配对）。
//
// owner 跨线程：IFileDialog::Show 接受其他线程的 owner hwnd（禁用与
// Z 序由对话框托管），实测行为正确。
//
// 返回码：0 = 已接受（结果稍后经 callback 回投）；-1 = 参数错误。
typedef void (*DialogResultFn)(int32_t request_id, int32_t code,
                               const wchar_t* path);

extern "C" __declspec(dllexport) int32_t SimplerPlayerFreeString(
    wchar_t* path) {
  delete[] path;
  return 0;
}

extern "C" __declspec(dllexport) int32_t SimplerPlayerShowOpenDialogAsync(
    const wchar_t* filter_spec, int32_t lock_parent_window,
    int32_t request_id, DialogResultFn callback) {
  if (!filter_spec || !callback) {
    return -1;
  }
  std::thread([filter = std::wstring(filter_spec), lock_parent_window,
               request_id, callback]() {
    // 独立线程的 STA apartment：对话框的标准宿主形态（COM 跨套间交互
    // 由系统 marshal）。线程结束前 CoUninitialize 配对。
    HRESULT co_hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    const bool need_co_uninit = SUCCEEDED(co_hr);

    IFileOpenDialog* dialog = nullptr;
    int32_t code = 0;
    wchar_t* result_path = nullptr;
    HRESULT hr = CoCreateInstance(CLSID_FileOpenDialog, nullptr,
                                  CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&dialog));
    if (FAILED(hr) || !dialog) {
      code = static_cast<int32_t>(static_cast<int64_t>(hr));
    } else {
      std::wstring spec = L"*.";
      spec += filter;
      size_t pos = 0;
      while ((pos = spec.find(L";", pos)) != std::wstring::npos) {
        spec.replace(pos, 1, L";*.");
        pos += 3;
      }
      const COMDLG_FILTERSPEC filters[] = {
          {L"媒体文件", spec.c_str()},
          {L"所有文件 (*.*)", L"*.*"},
      };
      dialog->SetFileTypes(static_cast<UINT>(std::size(filters)), filters);
      dialog->SetFileTypeIndex(1);
      DWORD options = 0;
      dialog->GetOptions(&options);
      options |= FOS_PATHMUSTEXIST | FOS_FILEMUSTEXIST | FOS_FORCEFILESYSTEM;
      dialog->SetOptions(options);

      HWND parent =
          lock_parent_window && g_main_window ? g_main_window : nullptr;
      hr = dialog->Show(parent);
      if (SUCCEEDED(hr)) {
        IShellItem* item = nullptr;
        if (SUCCEEDED(dialog->GetResult(&item)) && item) {
          PWSTR path = nullptr;
          if (SUCCEEDED(item->GetDisplayName(SIGDN_FILESYSPATH, &path)) &&
              path) {
            code = 1;
            result_path = new wchar_t[wcslen(path) + 1];
            wcscpy_s(result_path, wcslen(path) + 1, path);
            CoTaskMemFree(path);
          }
          item->Release();
        }
      } else if (hr == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
        code = 0;  // 用户取消 — result_path 保持 null
      } else {
        code = static_cast<int32_t>(static_cast<int64_t>(hr));
      }
      dialog->Release();
    }

    // 回投 Dart（NativeCallable.listener 任意线程可调）— path 所有权
    // 移交 Dart（读完后经 SimplerPlayerFreeString 释放）。
    callback(request_id, code, result_path);

    if (need_co_uninit) CoUninitialize();
  }).detach();
  return 0;
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }
  g_main_window = GetHandle();

  // 渲染后端（libnativeapi/nativeapi#30 取证）：Windows 拖拽/resize 场景
  // Impeller（经 ANGLE 走 GLES）实测显著劣于 Skia —— rasterP95 36.6ms vs
  // 21.3ms（同机同帧集）。默认锁 Skia；SIMPLER_PLAYER_IMPELLER=1 恢复
  // Impeller 以便后续 A/B 复测（上游优化落地后可再切回 Default）。
  {
    wchar_t buffer[8] = {};
    DWORD read = GetEnvironmentVariableW(L"SIMPLER_PLAYER_IMPELLER", buffer,
                                         static_cast<DWORD>(std::size(buffer)));
    const bool use_impeller =
        read > 0 && read < std::size(buffer) && wcscmp(buffer, L"1") == 0;
    project_.set_impeller_switch(use_impeller
                                     ? flutter::ImpellerSwitch::Enabled
                                     : flutter::ImpellerSwitch::Disabled);
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // frame/命中/拖动/全屏均由 nativeapi（Dart FFI）在
  // 窗口子类化层处理：隐藏标题栏、最大化贴合工作区、全屏摘除
  // caption/thickframe、标题栏拖动由 Dart 手势经系统拖动循环完成。首帧
  // Show() 保留——Dart 侧若在隐藏态请求最大化，nativeapi 记标记并让这次
  // Show 直接以最大化形态出现。runner 只保留关闭转换与 IME 两处消息。

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  // 播放器无文本输入场景 — 解除窗口与默认输入法上下文 (IMC) 的关联,
  // 根治中文输入法在窗口左上角弹候选窗的问题 (同 flutter/flutter#92050
  // 家族: 无 EditableText 锚点时组合窗定位到 0,0; 相关 #190042)。
  // 恢复入口已迁至本线程的 kAppSetImeEnabled 消息 (见 MessageHandler) —
  // Dart 侧 Win32ImeBridge 经 SendMessageTimeoutW 投递, IMC 切换始终在
  // 创建窗口的 platform 线程执行 (IMM32 线程亲和, UI 线程直调会静默
  // 失效)。未来落地文本输入框时按焦点启停 enable/disable。
  // ⚠ 必须同时解除 **主窗口与 FlutterView 子窗口** — 键盘焦点在子窗口,
  // 组合发生在子窗口的 IMC 上, 只解除主窗口候选窗照弹 (首版实测踩坑)。
  // ⚠ NULL IMC 与原生文件对话框冲突 (IFileOpenDialog 子窗口的 TSF 路径
  // 假定 IMC 存在 → imm32/msctf 空指针崩溃) — 一切原生文件对话框调用
  // 必须经 Dart 侧 Win32ImeBridge.withImeRestored 包裹 (弹窗期间临时
  // 恢复 IME), 新增 picker 时务必遵循。
  ImmAssociateContext(GetHandle(), nullptr);
  ImmAssociateContext(flutter_controller_->view()->GetNativeWindow(), nullptr);

  return true;
}

void FlutterWindow::OnDestroy() {
  g_main_window = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  // 关门专线优先：Dart 通知器在线时 WM_CLOSE 被消费，Dart 完成
  // hide→persist→closing-listeners→exit(0) 后进程自退，窗口无需再销毁。
  // 无通知器（启动极早期/降级）→ 落 DefWindowProc 默认销毁。
  if (message == WM_CLOSE) {
    if (CloseNotifier notifier = g_close_notifier) {
      notifier();
      return 0;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_GETMINMAXINFO:
      // 最小外框约束 — Dart init 时经 SimplerPlayerSetMinWindowSize 设置
      // （逻辑像素，此处按当前窗口 DPI 换算物理值）。未设置时放行默认。
      if (g_min_window_size.cx > 0 && g_min_window_size.cy > 0) {
        UINT dpi = GetDpiForWindow(hwnd);
        auto* info = reinterpret_cast<MINMAXINFO*>(lparam);
        info->ptMinTrackSize.x =
            static_cast<LONG>(g_min_window_size.cx * dpi / USER_DEFAULT_SCREEN_DPI);
        info->ptMinTrackSize.y =
            static_cast<LONG>(g_min_window_size.cy * dpi / USER_DEFAULT_SCREEN_DPI);
        return 0;
      }
      break;
    case ime_bridge_messages::kAppSetImeEnabled:
      // Dart 侧 Win32ImeBridge 投递 — 本线程即创建窗口的 platform 线程,
      // IMM32 调用在此亲和正确。flutter_view 句柄从控制器现取 (可能为
      // null 仅在销毁期, HandleSetImeEnabled 内部已判空跳过)。
      return ime_bridge_messages::HandleSetImeEnabled(
          hwnd, wparam,
          flutter_controller_ ? flutter_controller_->view()->GetNativeWindow()
                              : nullptr);
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
