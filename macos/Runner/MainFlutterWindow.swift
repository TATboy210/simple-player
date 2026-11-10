import Cocoa
import FlutterMacOS

// ─── runner C ABI 导出（与 Windows flutter_window.cpp 同模式，见 CONTRACT.md）───

/// 关门专线回调 — Dart 经 FFI NativeCallable.listener 注册，主线程调用安全
/// （投递回 UI isolate，不阻塞 AppKit）。
typealias CloseNotifier = @convention(c) () -> Void
private var gCloseNotifier: CloseNotifier?

/// AppDelegate 读取专线（Cmd+Q 走 applicationShouldTerminate，不经窗口）。
func currentCloseNotifier() -> CloseNotifier? { gCloseNotifier }

/// 主窗口槽 — awakeFromNib 赋值（weak：窗口释放自动清空）。
private weak var gMainWindow: MainFlutterWindow?

@_cdecl("SetCloseNotifier")
public func setCloseNotifier(_ notifier: @escaping @convention(c) () -> Void) {
  gCloseNotifier = notifier
}

@_cdecl("SimplerPlayerGetMainWindowHandle")
public func simplerPlayerGetMainWindowHandle() -> UnsafeMutableRawPointer? {
  guard let window = gMainWindow else { return nil }
  return Unmanaged.passUnretained(window).toOpaque()
}

/// macOS 主窗口 — 隐藏态建窗（xib visibleAtLaunch=NO，此处不 orderFront），
/// 亮窗时机由 Dart reveal() 决定（契约 5）；关闭经专线交 Dart hide-first
/// 序列（契约 7）。file_picker_attention 通道保留（file_picker_adapters 在用）。
class MainFlutterWindow: NSWindow, NSWindowDelegate {
  private var filePickerAttentionChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    super.awakeFromNib()
    self.delegate = self
    gMainWindow = self

    guard let controller = self.contentViewController as? FlutterViewController else {
      return
    }
    let messenger = controller.engine.binaryMessenger

    filePickerAttentionChannel = FlutterMethodChannel(
      name: "com.simple_player/file_picker_attention",
      binaryMessenger: messenger
    )
    filePickerAttentionChannel?.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else {
        result(FlutterError(
          code: "DISPOSED",
          message: "Window was disposed",
          details: nil
        ))
        return
      }
      guard call.method == "focusExistingPicker" else {
        result(FlutterMethodNotImplemented)
        return
      }

      // file_picker attaches NSOpenPanel as a sheet, so no extra panel is created.
      let found = self.attachedSheet is NSOpenPanel
      if let panel = self.attachedSheet as? NSOpenPanel {
        panel.makeKeyAndOrderFront(nil)
      }
      // NSBeep() C 全局函数与 NSApp.beep() 在 Xcode 26+ SDK 的 Swift
      // 可见性中均不可用 — NSSound.beep() 是同一系统提示音的稳定形态。
      NSSound.beep()
      result(["found": found])
    }

    // 刻意不 center()/makeKeyAndOrderFront — 隐藏态建窗，几何由 Dart init
    // 恢复、首帧栅格化后 Dart reveal() 亮窗（与 Windows runner 时序对齐）。
  }

  // MARK: - 关闭拦截（契约 7 的 macOS 通道）

  /// 全量拦截点 — performClose:（Cmd+W/程序化）、macOS 26 红绿灯按钮的
  /// 私有 __close→close 直达路径、以及任何直接 close 调用都汇到这里。
  /// 专线在线时交给 Dart hide-first 序列（其末尾 exit(0)，不会再回来调
  /// 原生 close）；未注册（启动极早期/降级）放行原生销毁。
  override func close() {
    if let notifier = gCloseNotifier {
      notifier()
      return
    }
    super.close()
  }

  /// performClose: 的 delegate 询问点 — 早于 close() 拦截，语义更显式；
  /// 与 close() 覆盖有重叠，Dart 侧关窗序列单飞幂等，双保险无害。
  func windowShouldClose(_ sender: NSWindow) -> Bool {
    if let notifier = gCloseNotifier {
      notifier()
      return false
    }
    return true
  }
}
