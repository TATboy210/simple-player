import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/player_error.dart';
import 'engine_state_machine.dart';
import 'media_state.dart';
import 'player_proxy.dart';

/// Maps player callbacks to EngineStateMachine transitions.
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
/// 所有回调统一通过 `scheduleMicrotask` 封送到主 isolate (D12/D13)，
/// 替代旧版 SchedulerBinding.addPostFrameCallback，消除帧阶段复杂性。
///
/// The static [mapPlayerState] function is pure and independently testable.
class FvpCallbackHandler {
  final MdkPlayerLike _player;
  final EngineStateMachine _stateMachine;
  final VoidCallback onStopPositionPolling;

  /// 错误通知器 — 回调异常封送到主线程后赋值 (ERR-05)
  final ValueNotifier<PlayerError?> _lastErrorNotifier;

  bool _disposed = false;
  StreamSubscription<dynamic>? _stateSubscription;
  StreamSubscription<dynamic>? _statusSubscription;

  FvpCallbackHandler(
    this._player, {
    required EngineStateMachine stateMachine,
    required this.onStopPositionPolling,
    required ValueNotifier<PlayerError?> lastErrorNotifier,
  }) : _stateMachine = stateMachine,
       _lastErrorNotifier = lastErrorNotifier;

  /// 注册回调 — 每个回调包裹 try-catch 封送异常到主线程 (ERR-05)
  void init() {
    _stateSubscription = _player.onStateChanged.listen((event) {
      if (_disposed) return;
      try {
        // event 是 MdkStateChangedEvent，包含 newValue (MdkPlaybackState)
        final stateEvent = event as MdkStateChangedEvent;
        final mapped = mapPlayerState(stateEvent.newValue);
        _scheduleOnMain(() {
          if (_disposed) return;
          // 防御：opening 阶段不更新状态 — 这是旧视频的回调
          if (_stateMachine.state.value == MediaState.opening) return;
          _stateMachine.transitionTo(mapped, 'player.onStateChanged');
        });
      } on Exception catch (e, st) {
        _marshalCallbackError(e, st, 'player.onStateChanged');
      }
    });

    _statusSubscription = _player.onMediaStatus.listen((event) {
      if (_disposed) return;
      try {
        // event 是 MdkMediaStatusEvent，包含 newValue (MdkMediaStatus)
        final statusEvent = event as MdkMediaStatusEvent;
        final newValue = statusEvent.newValue;
        _scheduleOnMain(() {
          if (_disposed) return;

          if (newValue.test(MdkMediaStatus.buffering)) {
            if (!_stateMachine.isBuffering.value) {
              _stateMachine.isBuffering.value = true;
            }
          } else {
            if (_stateMachine.isBuffering.value) {
              _stateMachine.isBuffering.value = false;
            }
          }

          if (newValue.test(MdkMediaStatus.end)) {
            // 防御：只在实际播放中才设 completed — 避免旧视频 end 事件干扰新视频
            final current = _stateMachine.state.value;
            if (current == MediaState.playing || current == MediaState.paused) {
              _stateMachine.transitionTo(MediaState.completed, 'player.onMediaStatus.end');
            }
            onStopPositionPolling();
          }
        });
      } on Exception catch (e, st) {
        _marshalCallbackError(e, st, 'player.onMediaStatus');
      }
    });
  }

  /// 回调异常封送 — 在回调线程捕获，构造 PlayerError，通过 _scheduleOnMain 封送到主线程 (ERR-05)
  void _marshalCallbackError(Object e, StackTrace st, String action) {
    final error = PlaybackError(
      PlaybackErrorCode.playFailed,
      'callback error: $e',
      e,
      ErrorContext(
        action: action,
        module: 'FvpCallbackHandler',
        callbackStackTrace: st,
      ),
    );
    _scheduleOnMain(() {
      if (_disposed) return;
      _lastErrorNotifier.value = error;
    });
  }

  /// 标记已释放，阻止后续回调处理
  void dispose() {
    _disposed = true;
    _stateSubscription?.cancel();
    _statusSubscription?.cancel();
  }

  /// 封送 [action] 到主 isolate — 通过 scheduleMicrotask 统一延迟 (D12/D13)
  void _scheduleOnMain(VoidCallback action) {
    scheduleMicrotask(action);
  }

  /// 纯函数映射：MdkPlaybackState → MediaState
  ///
  /// static 保证无副作用、可独立测试。
  /// 播放器只有 3 种状态（stopped/playing/paused），
  /// loading/buffering/completed 等由 onMediaStatus 单独处理。
  static MediaState mapPlayerState(MdkPlaybackState playerState) {
    return switch (playerState) {
      MdkPlaybackState.stopped => MediaState.idle,
      MdkPlaybackState.playing => MediaState.playing,
      MdkPlaybackState.paused => MediaState.paused,
    };
  }

  /// 向后兼容的映射方法 — 旧代码可能直接使用 mdk.PlaybackState
  ///
  /// 已弃用：使用 [mapPlayerState] 替代。
  @Deprecated('Use mapPlayerState with MdkPlaybackState instead')
  static MediaState mapMdkState(dynamic mdkState) {
    if (mdkState is MdkPlaybackState) return mapPlayerState(mdkState);
    // mdk.PlaybackState fallback — 字符串匹配
    final str = mdkState.toString();
    if (str.contains('playing')) return MediaState.playing;
    if (str.contains('paused')) return MediaState.paused;
    return MediaState.idle;
  }
}
