import 'package:flutter/services.dart';

/// mpv 渲染桥接 — MethodChannel 封装
///
/// C++ 插件负责 ANGLE + D3D11 渲染管线，
/// Dart 侧只传参和管理生命周期。
/// 不包含 NativeCallable（C++ 通过 MarkTextureFrameAvailable 通知 Flutter）。
class MpvRenderBridge {
  static const _channel = MethodChannel('com.simple_player/mpv_render');

  bool _disposed = false;

  /// 创建渲染上下文，返回 textureId
  ///
  /// `mpvHandleAddr` 是 mpv_handle 指针的地址（Pointer.address）
  Future<int> createRender(int mpvHandleAddr, int width, int height) async {
    final result = await _channel.invokeMethod('CreateRenderTexture', {
      'mpv_handle': mpvHandleAddr,
      'width': width,
      'height': height,
    });
    return (result as Map)['textureId'] as int;
  }

  /// 请求 resize（异步，渲染线程下次循环时生效）
  Future<void> resize(int width, int height) async {
    if (_disposed) return;
    await _channel.invokeMethod('Resize', {
      'width': width,
      'height': height,
    });
  }

  /// 获取当前帧信息 {width, height, format}
  Future<Map<String, dynamic>> getFrameInfo() async {
    final result = await _channel.invokeMethod('GetFrameInfo');
    return Map<String, dynamic>.from(result as Map);
  }

  /// 销毁渲染上下文
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _channel.invokeMethod('ReleaseRenderTexture');
  }
}
