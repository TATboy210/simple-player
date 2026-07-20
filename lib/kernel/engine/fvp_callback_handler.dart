import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:fvp/mdk.dart' as mdk;
import '../models/player_error.dart';
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
/// 所有回调统一通过 `scheduleMicrotask` 封送到主 isolate (D12/D13)，
/// 替代旧版 SchedulerBinding.addPostFrameCallback，消除帧阶段复杂性。
///
/// The static [mapMdkState] function is pure and independently testable.
class FvpCallbackHandler {
  final mdk.Player _player;
  final EngineStateMachine _stateMachine;
  final VoidCallback onStopPositionPolling;

  /// 错误通知器 — mdk 回调异常封送到主线程后赋值 (ERR-05)
  final ValueNotifier<PlayerError?> _lastErrorNotifier;

  bool _disposed = false;
  StreamSubscription<void>? _stateSubscription;
  StreamSubscription<void>? _statusSubscription;

  FvpCallbackHandler(
    this._player, {
    required EngineStateMachine stateMachine,
    required this.onStopPositionPolling,
    required ValueNotifier<PlayerError?> lastErrorNotifier,
  }) : _stateMachine = stateMachine,
       _lastErrorNotifier = lastErrorNotifier;

  /// 注册 mdk 回调 — 每个回调包裹 try-catch 封送异常到主线程 (ERR-05)
  void init() {
    _stateSubscription = _player.onStateChanged.listen((event) {
      if (_disposed) return;
      try {
        final mapped = mapMdkState(event.newValue);
        _scheduleOnMain(() {
          if (_disposed) return;
          // 防御：opening 阶段不更新状态 — 这是旧视频的回调
          if (_stateMachine.state.value == MediaState.opening) return;
          _stateMachine.transitionTo(mapped, 'mdk.onStateChanged');
        });
      } on Exception catch (e, st) {
        // ERR-05: mdk 回调异常 → 构造 PlayerError + callbackStackTrace → 封送到主线程
        _marshalCallbackError(e, st, 'mdk.onStateChanged');
      }
    });

    _statusSubscription = _player.onMediaStatus.listen((event) {
      if (_disposed) return;
      try {
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
      } on Exception catch (e, st) {
        // ERR-05: mdk 回调异常 → 构造 PlayerError + callbackStackTrace → 封送到主线程
        _marshalCallbackError(e, st, 'mdk.onMediaStatus');
      }
    });
  }

  /// mdk 回调异常封送 — 在回调线程捕获，构造 PlayerError，通过 _scheduleOnMain 封送到主线程 (ERR-05)
  ///
  /// callbackStackTrace 保存回调线程的栈，便于诊断跨线程错误来源。
  /// 日志由 lastErrorNotifier 的监听者（如 ErrorBanner）在主线程处理。
  void _marshalCallbackError(Object e, StackTrace st, String action) {
    final error = PlaybackError(
      PlaybackErrorCode.playFailed,
      'mdk callback error: $e',
      e,
      ErrorContext(
        action: action,
        module: 'FvpCallbackHandler',
        callbackStackTrace: st,
      ),
    );
    // 封送到主线程 — ValueNotifier 赋值必须在主线程
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
  ///
  /// Marshals [action] to the main isolate via scheduleMicrotask (D12/D13).
  /// 统一使用 scheduleMicrotask 替代 SchedulerBinding.addPostFrameCallback，
  /// 消除帧阶段复杂性，与 Phase 18 D9 错误封送模式一致。
  ///
  /// scheduleMicrotask 开销极低，所有回调统一延迟不影响性能。
  void _scheduleOnMain(VoidCallback action) {
    scheduleMicrotask(action);
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
