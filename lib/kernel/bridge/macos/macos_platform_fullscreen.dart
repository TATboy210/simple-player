/// macOS 平台全屏实现 — 通过 MethodChannel 调用 NSWindow.toggleFullScreen:。
///
/// macOS 原生全屏自带动画（从标题栏展开），不需要手动保存/恢复窗口样式。
/// 使用 NSWindowDelegate 监听进入/退出全屏完成事件，防止动画重入。
import 'dart:ui';

import 'package:flutter/services.dart';

import '../platform_fullscreen.dart';

/// macOS 平台全屏 — 实现 PlatformFullscreen 接口。
///
/// 通过 MethodChannel 与 Swift 端通信，调用 NSWindow 原生全屏 API。
/// requiresStyleSave = false，macOS 内部管理窗口样式。
class MacosPlatformFullscreen implements PlatformFullscreen {
  static const _channel = MethodChannel('com.simple_player/fullscreen');

  @override
  bool get requiresStyleSave => false;

  @override
  Future<FullscreenSnapshot> enter() async {
    // 保存当前窗口几何（全屏前）
    final rect = await _getWindowRect();
    // 调用原生全屏
    await _channel.invokeMethod<void>('enterFullscreen');
    return FullscreenSnapshot(
      windowStyle: 0, // macOS 不使用窗口样式位
      position: Offset(rect['x']! as double, rect['y']! as double),
      size: Size(rect['width']! as double, rect['height']! as double),
    );
  }

  @override
  void exit(FullscreenSnapshot snapshot) {
    _channel.invokeMethod<void>('exitFullscreen');
  }

  /// 获取当前窗口矩形（位置 + 大小）。
  Future<Map<String, double>> _getWindowRect() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getWindowRect',
    );
    if (result == null) {
      return {'x': 0, 'y': 0, 'width': 1280, 'height': 720};
    }
    return {
      'x': (result['x'] as num?)?.toDouble() ?? 0,
      'y': (result['y'] as num?)?.toDouble() ?? 0,
      'width': (result['width'] as num?)?.toDouble() ?? 1280,
      'height': (result['height'] as num?)?.toDouble() ?? 720,
    };
  }
}
