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
///   - 静默模式: 正常播放 3 秒后降频至 500ms，节省 CPU
///   - 轮询 position 并更新 ValueNotifier（仅值变化时通知）
///   - URL 路径额外轮询 buffered（本地文件瞬间完全缓存，跳过 FFI）
///   - seek 期间暂停轮询，防止旧位置覆盖 seek 目标
class PositionPoller {
  /// 快速轮询间隔（seek 完成后）
  static const _activePollMs = 100;

  /// 稳态轮询间隔（正常播放）
  static const _normalPollMs = 250;

  /// 静默模式轮询间隔（无交互时节省 CPU）
  static const _silentPollMs = 500;

  /// 快速轮询持续时间
  static const _activeDuration = Duration(seconds: 1);

  /// 静默模式延迟（无交互后多久切换到静默间隔）
  static const _silentDelay = Duration(seconds: 3);

  final mdk.Player _player;
  final ValueNotifier<int> position;
  final ValueNotifier<int> buffered;
  final String Function() currentPathGetter;

  Timer? _timer;
  Timer? _activeTimer;
  Timer? _silentTimer;
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
      // seek 开始：取消活跃定时器和静默定时器
      _activeTimer?.cancel();
      _activeTimer = null;
      _cancelSilentTimer();
    } else {
      // seek 完成：切换到快速轮询，重置静默延迟
      setActive();
      _scheduleSilentTransition();
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

  /// 启动静默模式轮询: 250ms 起步，3 秒后降频至 500ms
  void startSilent() {
    start();
    _scheduleSilentTransition();
  }

  /// 停止轮询
  void stop() {
    _timer?.cancel();
    _timer = null;
    _activeTimer?.cancel();
    _activeTimer = null;
    _cancelSilentTimer();
  }

  /// 释放资源
  void dispose() {
    _disposed = true;
    stop();
  }

  /// 安排静默模式切换（3 秒后降频至 500ms）
  void _scheduleSilentTransition() {
    _cancelSilentTimer();
    _silentTimer = Timer(_silentDelay, () {
      _updateInterval(_silentPollMs);
    });
  }

  /// 取消静默模式定时器
  void _cancelSilentTimer() {
    _silentTimer?.cancel();
    _silentTimer = null;
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
