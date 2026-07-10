#import <FlutterMacOS/FlutterMacOS.h>

/// macOS fullscreen plugin — 负责 NSWindow toggleFullScreen: 和 delegate 回调。
///
/// 实现 NSWindowDelegate 接收全屏动画完成回调 (D-P09):
/// - windowDidEnterFullScreen: 全屏进入完成
/// - windowDidExitFullScreen: 全屏退出完成
@interface FullscreenWindowPlugin : NSObject <FlutterPlugin, NSWindowDelegate>

/// MethodChannel 引用 — delegate 回调通过此 channel 通知 Dart 层。
@property (nonatomic, strong) FlutterMethodChannel *channel;

@end
