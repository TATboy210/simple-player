#import "FullscreenWindowPlugin.h"

@implementation FullscreenWindowPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    FlutterMethodChannel *channel =
        [FlutterMethodChannel methodChannelWithName:@"fullscreen_window"
                                    binaryMessenger:[registrar messenger]];
    FullscreenWindowPlugin *instance = [[FullscreenWindowPlugin alloc] init];
    instance.channel = channel;
    [registrar addMethodCallDelegate:instance channel:channel];

    // 设置 NSWindow delegate 接收全屏动画完成回调 (D-P09)
    // mainWindow 可能在此时为 nil (应用尚未完成启动)，
    // 延迟到首次 setFullScreen 调用时再次尝试设置
    NSWindow *window = [NSApp mainWindow];
    if (window != nil) {
        window.delegate = instance;
    }
}

- (void)handleMethodCall:(FlutterMethodCall *)call
                  result:(FlutterResult)result {
    if ([@"setFullScreen" isEqualToString:call.method]) {
        NSNumber *isFullScreen = call.arguments[@"isFullScreen"];
        NSWindow *window = [NSApp mainWindow];
        if (window == nil) {
            result([FlutterError errorWithCode:@"NO_WINDOW"
                                       message:@"No main window found"
                                       details:nil]);
            return;
        }
        // 确保 delegate 已设置 (registerWithRegistrar 时 mainWindow 可能为 nil)
        if (window.delegate != self) {
            window.delegate = self;
        }
        BOOL currentlyFullScreen =
            (window.styleMask & NSWindowStyleMaskFullScreen) != 0;
        if ([isFullScreen boolValue] != currentlyFullScreen) {
            [window toggleFullScreen:nil];
        }
        result(nil);
    } else if ([@"getFullScreenState" isEqualToString:call.method]) {
        // 查询当前全屏状态 — 通过 styleMask 检查 (D-P09)
        NSWindow *window = [NSApp mainWindow];
        if (window == nil) {
            result(@(NO));
            return;
        }
        BOOL isFullScreen =
            (window.styleMask & NSWindowStyleMaskFullScreen) != 0;
        result(@(isFullScreen));
    } else if ([@"getScreenSize" isEqualToString:call.method]) {
        NSScreen *screen = [NSScreen mainScreen];
        NSRect frame = [screen frame];
        CGFloat scale = [screen backingScaleFactor];
        result(@{
            @"width" : @(frame.size.width * scale),
            @"height" : @(frame.size.height * scale)
        });
    } else {
        result(FlutterMethodNotImplemented);
    }
}

// ─── NSWindowDelegate 回调 (D-P09) ───

/// 全屏进入动画完成 — 通知 Dart 层状态已确认。
- (void)windowDidEnterFullScreen:(NSNotification *)notification {
    [self.channel invokeMethod:@"onFullScreenChanged"
                     arguments:@{@"isFullScreen" : @YES}];
}

/// 全屏退出动画完成 — 通知 Dart 层状态已确认。
- (void)windowDidExitFullScreen:(NSNotification *)notification {
    [self.channel invokeMethod:@"onFullScreenChanged"
                     arguments:@{@"isFullScreen" : @NO}];
}

@end
