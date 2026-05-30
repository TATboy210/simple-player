import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:fvp/mdk.dart' as mdk;

import '../services/path_validator.dart';
import '../utils/log.dart';

/// 位置轮询器 — 自适应间隔轮询播放位置
///
/// 职责:
///   - 启动/停止定时器（默认 250ms 稳态轮询）
///   - seek 完成后切换到 100ms 快速轮询 1 秒，保证进度条平滑
///   - 轮询 position 并更新 ValueNotifier（仅值变化时通知）
///   - URL 路径额外轮询 buffered（本地文件瞬间完全缓存，跳过 FFI）
///   - seek 期间暂停轮询，防止旧位置覆盖 seek 目标
class PositionPoller {
  /// 快速轮询间隔（seek 完成后）
  static const _activePollMs = 100;

  /// 稳态轮询间隔（正常播放）
  static const _normalPollMs = 250;

  /// 快速轮询持续时间
  static const _activeDuration = Duration(seconds: 1);

  final mdk.Player _player;
  final ValueNotifier<int> position;
  final ValueNotifier<int> buffered;
  final String Function() currentPathGetter;

  Timer? _timer;
  Timer? _activeTimer;
  int _currentIntervalMs = _normalPollMs;
  bool _disposed = false;
  bool _seeking = false;

  PositionPoller(
    this._player, {
    required this.position,
    required this.buffered,
    required this.currentPathGetter,
  });

  /// 是否正在 seek（seek 期间暂停轮询，完成后自动切换快速轮询）
  set seeking(bool value) {
    _seeking = value;
    if (value) {
      // seek 开始：取消活跃定时器（seek 期间不需要快速轮询）
      _activeTimer?.cancel();
      _activeTimer = null;
    } else {
      // seek 完成：切换到快速轮询
      setActive();
    }
  }

  /// 切换到快速轮询（100ms），1 秒后自动恢复稳态间隔
  void setActive() {
    _updateInterval(_activePollMs);
    _activeTimer?.cancel();
    _activeTimer = Timer(_activeDuration, () {
      _updateInterval(_normalPollMs);
    });
  }

  /// 启动轮询（稳态间隔 250ms）
  void start() {
    stop();
    _currentIntervalMs = _normalPollMs;
    _timer = Timer.periodic(
      const Duration(milliseconds: _normalPollMs),
      (_) => _poll(),
    );
  }

  /// 停止轮询
  void stop() {
    _timer?.cancel();
    _timer = null;
    _activeTimer?.cancel();
    _activeTimer = null;
  }

  /// 释放资源
  void dispose() {
    _disposed = true;
    stop();
  }

  /// 更新轮询间隔（仅当间隔变化时重建定时器，避免不必要开销）
  void _updateInterval(int ms) {
    if (_currentIntervalMs == ms) return;
    _currentIntervalMs = ms;
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(milliseconds: ms),
      (_) => _poll(),
    );
    _poll(); // 立即轮询一次，避免间隔切换时的空白
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
      log.e('PositionPoller._poll error: $e');
    }
  }
}
