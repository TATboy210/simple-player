import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:fvp/mdk.dart' as mdk;

import '../services/path_validator.dart';

/// 位置轮询器 — 250ms 定时器轮询播放位置
///
/// 职责:
///   - 启动/停止 250ms 定时器
///   - 轮询 position 并更新 ValueNotifier（仅值变化时通知）
///   - URL 路径额外轮询 buffered（本地文件瞬间完全缓存，跳过 FFI）
///   - seek 期间暂停轮询，防止旧位置覆盖 seek 目标
class PositionPoller {
  static const _pollIntervalMs = 250;

  final mdk.Player _player;
  final ValueNotifier<int> position;
  final ValueNotifier<int> buffered;
  final String Function() currentPathGetter;

  Timer? _timer;
  bool _disposed = false;
  bool _seeking = false;

  PositionPoller(
    this._player, {
    required this.position,
    required this.buffered,
    required this.currentPathGetter,
  });

  /// 是否正在 seek（seek 期间暂停轮询）
  set seeking(bool value) => _seeking = value;

  /// 启动轮询
  void start() {
    stop();
    _timer = Timer.periodic(
      const Duration(milliseconds: _pollIntervalMs),
      (_) => _poll(),
    );
  }

  /// 停止轮询
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// 释放资源
  void dispose() {
    _disposed = true;
    stop();
  }

  /// 轮询播放位置
  void _poll() {
    if (_disposed || _seeking) return;
    try {
      final newPos = _player.position;
      if (position.value != newPos) position.value = newPos;

      // 本地文件 buffered 瞬间等于 duration，跳过 FFI 调用
      if (PathValidator.isUrl(currentPathGetter())) {
        final newBuf = _player.buffered();
        if (buffered.value != newBuf) buffered.value = newBuf;
      }
    } on Exception catch (e) {
      debugPrint('PositionPoller._poll error: $e');
    }
  }
}
