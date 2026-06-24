import Cocoa
import FlutterMacOS

/// macOS 主窗口 — NSWindowDelegate 回调。
class MainFlutterWindow: NSWindow, NSWindowDelegate {
  override func awakeFromNib() {
    super.awakeFromNib()
    self.delegate = self

    self.center()
    self.makeKeyAndOrderFront(nil)
  }
}
