import 'package:flutter/foundation.dart';

/// 系统文件选择器接缝。
///
/// 将插件静态调用隔离在此接口外，使协调器可以在不启动原生对话框的条件下
/// 验证单开与完成后的资源释放行为。`null` 表示用户取消选择。
abstract interface class FilePickerGateway {
  /// 打开媒体选择器并返回可播放路径，或在取消时返回 `null`。
  Future<List<String>?> pickMediaPaths();
}

/// 已显示原生文件选择器时的 attention 接缝。
///
/// 平台实现会尽力聚焦已有对话框并播放系统提示音；失败只能降级，不能影响
/// 已在进行的 picker 生命周期。
abstract interface class FilePickerAttention {
  /// 请求对已有文件选择器执行 best-effort attention。
  Future<void> requestAttention();
}

/// 协调单个系统文件选择器会话及其结果播放。
///
/// 同一时刻只创建一个 picker；重复触发不会新建对话框，而是请求原生层将
/// 已存在的 picker 带回注意力。选中路径始终按 picker 返回顺序串行播放。
class FilePickerCoordinator {
  FilePickerCoordinator({
    required FilePickerGateway picker,
    required FilePickerAttention attention,
    required Future<void> Function(String path) openAndPlay,
  }) : _picker = picker,
       _attention = attention,
       _openAndPlay = openAndPlay;

  final FilePickerGateway _picker;
  final FilePickerAttention _attention;
  final Future<void> Function(String path) _openAndPlay;

  bool _isPicking = false;
  bool _isDisposed = false;

  /// 当前是否存在尚未完成的文件选择器会话。
  bool get isPicking => _isPicking;

  /// 使尚未完成的原生 picker 结果失效。
  ///
  /// 系统对话框无法被可靠取消；组合根销毁时调用此方法，使迟到的结果不会再
  /// 访问已释放的播放服务。
  void dispose() {
    _isDisposed = true;
  }

  /// 打开 picker，或为已存在的 picker 请求 attention。
  ///
  /// picker 取消、插件异常以及播放完成后都会在 `finally` 释放 guard，避免
  /// 原生选择器失败后永久阻塞后续打开请求。
  Future<void> open() async {
    if (_isDisposed) return;
    if (_isPicking) {
      await _requestAttention();
      return;
    }

    _isPicking = true;
    try {
      final paths = await _picker.pickMediaPaths();
      if (_isDisposed || paths == null || paths.isEmpty) return;

      // 保持原有逐个 await 的语义，避免多媒体打开请求争用同一播放器实例。
      for (final path in paths) {
        if (_isDisposed) return;
        await _openAndPlay(path);
      }
    } on Exception catch (error, stackTrace) {
      debugPrint(
        '[FilePickerCoordinator] picker session failed: $error\n$stackTrace',
      );
    } finally {
      _isPicking = false;
    }
  }

  /// attention 是辅助反馈；平台限制或通道未注册时只记录并安全降级。
  Future<void> _requestAttention() async {
    try {
      await _attention.requestAttention();
    } on Exception catch (error, stackTrace) {
      debugPrint(
        '[FilePickerCoordinator] picker attention unavailable: '
        '$error\n$stackTrace',
      );
    }
  }
}
