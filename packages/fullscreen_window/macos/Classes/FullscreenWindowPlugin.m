#import "FullscreenWindowPlugin.h"

@implementation FullscreenWindowPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    FlutterMethodChannel *channel =
        [FlutterMethodChannel methodChannelWithName:@"fullscreen_window"
                                    binaryMessenger:[registrar messenger]];
    FullscreenWindowPlugin *instance = [[FullscreenWindowPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
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
        BOOL currentlyFullScreen =
            (window.styleMask & NSWindowStyleMaskFullScreen) != 0;
        if ([isFullScreen boolValue] != currentlyFullScreen) {
            [window toggleFullScreen:nil];
        }
        result(nil);
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

@end
