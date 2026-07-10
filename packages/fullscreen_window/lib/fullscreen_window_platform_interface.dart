import 'package:flutter/widgets.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'fullscreen_window_method_channel.dart';

/// fullscreen_window 插件平台接口 — macOS/Linux/Windows 三端实现。
///
/// macOS 端额外支持 NSWindowDelegate 回调 (D-P09):
/// - [onFullScreenChanged] 全屏状态变化流 (delegate 回调驱动)
/// - [isFullScreen] 查询当前真实全屏状态 (styleMask 检查)
abstract class FullScreenWindowPlatform extends PlatformInterface {
  /// Constructs a FullscreenWindowPlatform.
  FullScreenWindowPlatform() : super(token: _token);

  static final Object _token = Object();

  static FullScreenWindowPlatform _instance = MethodChannelFullscreenWindow();

  /// The default instance of [FullScreenWindowPlatform] to use.
  ///
  /// Defaults to [MethodChannelFullscreenWindow].
  static FullScreenWindowPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FullScreenWindowPlatform] when
  /// they register themselves.
  static set instance(FullScreenWindowPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> setFullScreen(bool isFullScreen) {
    throw UnimplementedError();
  }

  Future<Size> getScreenSize(BuildContext? context) {
    throw UnimplementedError();
  }

  /// 全屏状态变化流 — macOS NSWindowDelegate 回调驱动 (D-P09)。
  ///
  /// 其他平台返回空流。
  Stream<bool> get onFullScreenChanged => const Stream.empty();

  /// 查询当前全屏状态 — macOS 通过 styleMask 检查 (D-P09)。
  ///
  /// 其他平台默认返回 false。
  Future<bool> isFullScreen() async => false;
}
