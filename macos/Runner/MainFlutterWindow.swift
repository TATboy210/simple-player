import Cocoa
import FlutterMacOS

/// macOS 主窗口 — 处理全屏 MethodChannel + NSWindowDelegate 回调。
///
/// MethodChannel: com.simple_player/fullscreen
///   - enterFullscreen: 进入全屏（阻塞等待动画完成）
///   - exitFullscreen: 退出全屏（阻塞等待动画完成）
///   - getWindowRect: 返回当前窗口 {x, y, width, height}
///
/// NSCondition 防止重入，2 秒超时防止永久挂起。
class MainFlutterWindow: NSWindow, NSWindowDelegate {
  private var fullscreenChannel: FlutterMethodChannel?
  private let fullscreenCondition = NSCondition()
  private var isTogglingFullScreen = false

  override func awakeFromNib() {
    super.awakeFromNib()
    self.delegate = self

    guard let controller = self.contentViewController as? FlutterViewController else {
      return
    }
    let messenger = controller.engine.binaryMessenger

    fullscreenChannel = FlutterMethodChannel(
      name: "com.simple_player/fullscreen",
      binaryMessenger: messenger
    )

    fullscreenChannel?.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else {
        result(FlutterError(
          code: "DISPOSED",
          message: "Window was disposed",
          details: nil
        ))
        return
      }

      switch call.method {
      case "enterFullscreen":
        self.handleEnterFullscreen(result: result)
      case "exitFullscreen":
        self.handleExitFullscreen(result: result)
      case "getWindowRect":
        self.handleGetWindowRect(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    self.center()
    self.makeKeyAndOrderFront(nil)
  }

  // MARK: - Fullscreen Methods

  private func handleEnterFullscreen(result: @escaping FlutterResult) {
    // 已经全屏则跳过
    guard !self.styleMask.contains(.fullScreen) else {
      result(nil)
      return
    }

    fullscreenCondition.lock()
    isTogglingFullScreen = true
    self.toggleFullScreen(nil)

    // 等待动画完成（最多 2 秒）
    let deadline = Date().addingTimeInterval(2.0)
    while isTogglingFullScreen && Date() < deadline {
      fullscreenCondition.wait(until: deadline)
    }
    fullscreenCondition.unlock()
    result(nil)
  }

  private func handleExitFullscreen(result: @escaping FlutterResult) {
    // 非全屏则跳过
    guard self.styleMask.contains(.fullScreen) else {
      result(nil)
      return
    }

    fullscreenCondition.lock()
    isTogglingFullScreen = true
    self.toggleFullScreen(nil)

    let deadline = Date().addingTimeInterval(2.0)
    while isTogglingFullScreen && Date() < deadline {
      fullscreenCondition.wait(until: deadline)
    }
    fullscreenCondition.unlock()
    result(nil)
  }

  private func handleGetWindowRect(result: @escaping FlutterResult) {
    let frame = self.frame
    result([
      "x": frame.origin.x,
      "y": frame.origin.y,
      "width": frame.size.width,
      "height": frame.size.height
    ] as [String: Any])
  }

  // MARK: - NSWindowDelegate

  func windowDidEnterFullScreen(_ notification: Notification) {
    _signalCondition()
  }

  func windowDidExitFullScreen(_ notification: Notification) {
    _signalCondition()
  }

  func windowDidFailToEnterFullScreen(_ window: NSWindow) {
    _signalCondition()
  }

  func windowDidFailToExitFullScreen(_ window: NSWindow) {
    _signalCondition()
  }

  /// 通知等待线程全屏动画已完成。
  private func _signalCondition() {
    fullscreenCondition.lock()
    isTogglingFullScreen = false
    fullscreenCondition.signal()
    fullscreenCondition.unlock()
  }
}
