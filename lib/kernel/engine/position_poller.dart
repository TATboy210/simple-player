import 'dart:async';

import 'package:flutter/foundation.dart';

import 'player_proxy.dart';
import '../services/path_validator.dart';
import '../diagnostics/kernel_logger.dart';

final log = KernelLogger.I;

/// 位置轮询器 — 自适应间隔轮询播放位置.
///
/// Position poller — adaptive-interval playback position polling.
///
/// Responsibilities:
///   - Start/stop timer (default 250ms steady-state polling).
///   - After seek: 100ms fast polling for 1s (smooth progress bar).
///   - Silent mode: 500ms after 3s idle (CPU savings).
///   - Polls position, updates ValueNotifier (only on change).
///   - URL paths: also polls buffered (local files cache instantly, skip FFI).
///   - Pauses polling during seek (prevents stale position overwrite).
class PositionPoller {
  /// 快速轮询间隔（seek 完成后）.
  static const _activePollMs = 100;

  /// 稳态轮询间隔（正常播放）.
  static const _normalPollMs = 250;

  /// 静默模式轮询间隔（无交互时节省 CPU）.
  static const _silentPollMs = 500;

  /// 快速轮询持续时间.
  static const _activeDuration = Duration(seconds: 1);

  /// 静默模式延迟（无交互后多久切换到静默间隔）.
  static const _silentDelay = Duration(seconds: 3);

  final MdkPlayerLike _player;
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

  /// 是否正在 seek（seek 期间暂停轮询，完成后自动切换快速轮询）.
  ///
  /// Whether seeking — pauses polling during seek, resumes with fast polling.
  set seeking(bool value) {
    _seeking = value;
    if (value) {
      _activeTimer?.cancel();
      _activeTimer = null;
      _cancelSilentTimer();
    } else {
      setActive();
      _scheduleSilentTransition();
    }
  }

  /// 切换到快速轮询（100ms），1 秒后自动恢复稳态间隔.
  ///
  /// Switches to fast polling (100ms); auto-returns to steady-state after 1s.
  void setActive() {
    _updateInterval(_activePollMs);
    _activeTimer?.cancel();
    _activeTimer = Timer(_activeDuration, () {
      _updateInterval(_normalPollMs);
    });
  }

  /// 启动轮询（稳态间隔 250ms）.
  ///
  /// Starts polling at steady-state interval (250ms).
  void start() {
    stop();
    _currentIntervalMs = _normalPollMs;
    _timer = Timer.periodic(
      const Duration(milliseconds: _normalPollMs),
      (_) => _poll(),
    );
  }

  /// 启动静默模式轮询: 250ms 起步，3 秒后降频至 500ms.
  ///
  /// Starts silent-mode polling: 250ms initially, drops to 500ms after 3s.
  void startSilent() {
    start();
    _scheduleSilentTransition();
  }

  /// 设置拖拽模式 — 拖拽进度条时降到 16ms（60fps 跟手）.
  ///
  /// Sets drag mode — 16ms polling (60fps) while dragging progress bar.
  static const _dragPollMs = 16;

  void setDragMode(bool isDragging) {
    _updateInterval(isDragging ? _dragPollMs : _normalPollMs);
  }

  /// 根据播放速率调整轮询间隔.
  ///
  /// Adjusts polling interval based on playback rate.
  void setPlaybackRate(double rate) {
    final adjusted = (_normalPollMs / rate).round().clamp(50, _silentPollMs);
    _updateInterval(adjusted);
  }

  /// 停止轮询.
  ///
  /// Stops polling.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _activeTimer?.cancel();
    _activeTimer = null;
    _cancelSilentTimer();
  }

  /// 释放资源.
  ///
  /// Disposes resources.
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

  /// 更新轮询间隔（仅当间隔变化时重建定时器）
  void _updateInterval(int ms) {
    if (_currentIntervalMs == ms) return;
    _currentIntervalMs = ms;
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(milliseconds: ms),
      (_) => _poll(),
    );
    _poll();
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
