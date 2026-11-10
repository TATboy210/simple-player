import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// Cmd+Q / 应用菜单退出 / 注销 — 完全不走窗口 close 路径，须单独拦截。
  /// 专线在线时唤起 Dart hide-first 序列并取消本次终止（序列末尾 exit(0)
  /// 完成真正的退出）；未注册时放行系统终止。
  /// 注：系统注销/强制终止（NSApplication.reply(to:) 超时类）不可无限拦截，
  /// 落盘由 resize 会话防抖兜底（CONTRACT.md 强制路径条目）。
  override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    if let notifier = currentCloseNotifier() {
      notifier()
      return .terminateCancel
    }
    return .terminateNow
  }
}
