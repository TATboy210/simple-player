import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:fvp/mdk.dart' as mdk;
import 'media_state.dart';

/// Maps mdk player callbacks to Flutter ValueNotifier updates.
///
/// Three callback sources:
///   - `onStateChanged`: play/pause/stop state transitions → MediaState mapping
///   - `onMediaStatus`: buffering start/end, media end events
///   - Both are dispatched to the main thread via [_scheduleOnMain]
///
/// Main-thread scheduling is required because ValueNotifier updates trigger
/// Flutter widget rebuilds — these MUST happen on the main isolate to avoid
/// race conditions with the rendering pipeline.
///
/// The static [mapMdkState] function is pure and independently testable.
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
          // 缓冲结束时恢复到正确的播放状态 — 检查 _player.state 而非
          // 无条件设为 playing，因为用户可能在缓冲期间暂停了播放
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

  /// Schedules [action] on the main thread during the frame callback phase.
  ///
  /// Uses SchedulerBinding.addPostFrameCallback to ensure ValueNotifier
  /// updates happen between frames, preventing mid-frame rebuilds that
  /// could cause visual glitches or assertion failures.
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
