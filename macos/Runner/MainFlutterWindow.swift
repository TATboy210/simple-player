import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Register aspect ratio MethodChannel
    let channel = FlutterMethodChannel(
      name: "com.simple_player/aspect_ratio",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      if call.method == "setAspectRatio" {
        guard let ratio = call.arguments as? Double else {
          result(FlutterError(code: "INVALID_ARGS", message: "Expected double", details: nil))
          return
        }
        if ratio > 0 {
          self.contentAspectRatio = NSSize(width: ratio, height: 1.0)
        } else {
          // Reset to no aspect ratio constraint
          self.contentAspectRatio = NSSize.zero
        }
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
