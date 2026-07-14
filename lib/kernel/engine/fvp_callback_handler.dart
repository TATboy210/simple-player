import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:fvp/mdk.dart' as mdk;
import 'engine_state_machine.dart';
import 'media_state.dart';

/// Maps mdk player callbacks to EngineStateMachine transitions.
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
  final EngineStateMachine _stateMachine;
  final VoidCallback onStopPositionPolling;

  bool _disposed = false;
  StreamSubscription<void>? _stateSubscription;
  StreamSubscription<void>? _statusSubscription;

  FvpCallbackHandler(
    this._player, {
    required EngineStateMachine stateMachine,
    required this.onStopPositionPolling,
  }) : _stateMachine = stateMachine;

  /// 注册 mdk 回调
  void init() {
    _stateSubscription = _player.onStateChanged.listen((event) {
      if (_disposed) return;
      final mapped = mapMdkState(event.newValue);
      _scheduleOnMain(() {
        if (_disposed) return;
        // 防御：opening 阶段不更新状态 — 这是旧视频的回调
        if (_stateMachine.state.value == MediaState.opening) return;
        _stateMachine.transitionTo(mapped, 'mdk.onStateChanged');
      });
    });

    _statusSubscription = _player.onMediaStatus.listen((event) {
      if (_disposed) return;
      final newValue = event.newValue;
      _scheduleOnMain(() {
        if (_disposed) return;

        if (newValue.test(mdk.MediaStatus.buffering)) {
          // 正交模型：buffering 是独立标志，不影响主状态枚举
          if (!_stateMachine.isBuffering.value) {
            _stateMachine.isBuffering.value = true;
          }
        } else {
          if (_stateMachine.isBuffering.value) {
            _stateMachine.isBuffering.value = false;
          }
        }

        if (newValue.test(mdk.MediaStatus.end)) {
          // 防御：只在实际播放中才设 completed — 避免旧视频 end 事件干扰新视频
          final current = _stateMachine.state.value;
          if (current == MediaState.playing || current == MediaState.paused) {
            _stateMachine.transitionTo(MediaState.completed, 'mdk.onMediaStatus.end');
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
      mdk.PlaybackState.stopped => MediaState.idle,
      mdk.PlaybackState.playing => MediaState.playing,
      mdk.PlaybackState.paused => MediaState.paused,
      _ => MediaState.idle,
    };
  }
}
