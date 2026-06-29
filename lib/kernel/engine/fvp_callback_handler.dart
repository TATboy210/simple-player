import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:fvp/mdk.dart' as mdk;
import 'media_state.dart';

/// mdk 回调处理器 — 将底层状态变化映射到 Flutter ValueNotifier
///
/// 职责:
///   - onStateChanged: mdk 播放状态 → MediaState 映射
///   - onMediaStatus: 缓冲/结束事件处理
///   - 调度到主线程（SchedulerBinding.addPostFrameCallback）
///
/// 纯函数 mapMdkState 可独立测试。
class FvpCallbackHandler {
  final mdk.Player _player;
  final ValueNotifier<MediaState> state;
  final ValueNotifier<bool> isBuffering;
  final VoidCallback onStopPositionPolling;

  bool _disposed = false;
  StreamSubscription<void>? _stateSubscription;
  StreamSubscription<void>? _statusSubscription;

  FvpCallbackHandler(
    this._player, {
    required this.state,
    required this.isBuffering,
    required this.onStopPositionPolling,
  });

  /// 注册 mdk 回调
  void init() {
    _stateSubscription = _player.onStateChanged.listen((event) {
      if (_disposed) return;
      final mapped = mapMdkState(event.newValue);
      _scheduleOnMain(() {
        if (_disposed) return;
        if (state.value != mapped) state.value = mapped;
      });
    });

    _statusSubscription = _player.onMediaStatus.listen((event) {
      if (_disposed) return;
      final newValue = event.newValue;
      _scheduleOnMain(() {
        if (_disposed) return;

        if (newValue.test(mdk.MediaStatus.buffering)) {
          if (!isBuffering.value) isBuffering.value = true;
          if (state.value != MediaState.buffering) {
            state.value = MediaState.buffering;
          }
        } else {
          if (isBuffering.value) isBuffering.value = false;
          if (state.value == MediaState.buffering) {
            state.value = _player.state == mdk.PlaybackState.playing
                ? MediaState.playing
                : MediaState.paused;
          }
        }

        if (newValue.test(mdk.MediaStatus.end)) {
          if (state.value != MediaState.completed) {
            state.value = MediaState.completed;
          }
          onStopPositionPolling();
        }
      });
    });
  }

  /// 标记已释放，阻止后续回调处理
  void dispose() {
    _disposed = true;
    _stateSubscription?.cancel();
    _statusSubscription?.cancel();
  }

  /// 将回调调度到主线程帧回调
  void _scheduleOnMain(VoidCallback action) {
    SchedulerBinding.instance.addPostFrameCallback((_) => action());
  }

  /// 纯函数映射：mdk.PlaybackState → MediaState
  ///
  /// static 保证无副作用、可独立测试。
  /// mdk 只有 3 种状态（stopped/playing/paused），
  /// loading/buffering/completed 等由 onMediaStatus 单独处理。
  static MediaState mapMdkState(mdk.PlaybackState mdkState) {
    return switch (mdkState) {
      mdk.PlaybackState.stopped => MediaState.stopped,
      mdk.PlaybackState.playing => MediaState.playing,
      mdk.PlaybackState.paused => MediaState.paused,
      _ => MediaState.idle,
    };
  }
}
