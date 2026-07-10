import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'fullscreen_window_platform_interface.dart';

/// fullscreen_window 插件 MethodChannel 实现。
///
/// macOS 端通过 MethodCallHandler 接收 NSWindowDelegate 回调 (D-P09):
/// - 注册 `onFullScreenChanged` 方法处理器
/// - 将原生回调转发到 [onFullScreenChanged] 流
class MethodChannelFullscreenWindow extends FullScreenWindowPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('fullscreen_window');

  /// 全屏状态变化流控制器 (D-P09)。
  ///
  /// macOS NSWindowDelegate 回调通过 MethodChannel 到达后，
  /// 解析 isFullScreen 参数并添加到此流。
  final StreamController<bool> _fullScreenController =
      StreamController<bool>.broadcast();

  /// 构造函数 — 注册 MethodCallHandler 接收原生回调。
  MethodChannelFullscreenWindow() {
    methodChannel.setMethodCallHandler(_handleMethodCall);
  }

  /// 处理原生 MethodChannel 调用。
  ///
  /// macOS NSWindowDelegate 回调触发 `onFullScreenChanged` 方法:
  /// - `isFullScreen: true` — windowDidEnterFullScreen 动画完成
  /// - `isFullScreen: false` — windowDidExitFullScreen 动画完成
  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onFullScreenChanged') {
      final args = call.arguments as Map<dynamic, dynamic>;
      final isFullScreen = args['isFullScreen'] as bool;
      _fullScreenController.add(isFullScreen);
    }
  }

  @override
  Stream<bool> get onFullScreenChanged => _fullScreenController.stream;

  @override
  Future<void> setFullScreen(bool isFullScreen) async {
    await methodChannel
        .invokeMethod<void>('setFullScreen', {"isFullScreen": isFullScreen});
  }

  @override
  Future<bool> isFullScreen() async {
    // macOS: 通过 getFullScreenState 查询 NSWindow styleMask
    // 其他平台: MethodChannel 未实现时返回 false
    try {
      final result = await methodChannel.invokeMethod<bool>(
        'getFullScreenState',
      );
      return result ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<Size> getScreenSize(BuildContext? context) async {
    double devicePixelRatio = 1.0;
    if (context != null) {
      var data = context.findAncestorWidgetOfExactType<MediaQuery>()?.data;
      if (data != null) {
        devicePixelRatio = data.devicePixelRatio;
      }
    }

    var map = await methodChannel.invokeMethod<Map>('getScreenSize', {});
    int width = map!["width"];
    int height = map["height"];

    var size = Size(width.toDouble() / devicePixelRatio,
        height.toDouble() / devicePixelRatio);
    return size;
  }
}
