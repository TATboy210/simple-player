/// 自动连播策略 — 监听引擎完成状态并决定下一首播放逻辑.
///
/// Auto-advance policy — listens for engine completion and decides next track.
///
/// [AutoAdvancePolicy] decides what happens after playback completes:
/// - loopSingle → replay current index
/// - loopAll / shuffle → auto-play next track
///
/// Architecture: PlaybackController → **AutoAdvancePolicy** → MediaEngine.state (ValueNotifier).
/// Pattern: Strategy — encapsulates advance decision, independently replaceable.
library;

import 'dart:async';

import '../engine/engine_state.dart';
import '../models/play_mode.dart';
import '../diagnostics/kernel_logger.dart';
import 'playback_controller.dart';

final _log = KernelLogger.I;

/// 自动连播策略 — 监听 [MediaState.completed] 并驱动播放器前进.
///
/// Listens for [MediaState.completed] and drives playback forward.
/// Single responsibility: only handles "what to do after playback ends";
/// no settings restore or breakpoint save. Accesses playlist and navigator
/// via [PlaybackController] callbacks for loose coupling.
class AutoAdvancePolicy {
  AutoAdvancePolicy(this._controller);
  final PlaybackController _controller;

  bool _initialized = false;

  /// 初始化：注册引擎状态监听.
  ///
  /// Registers engine state listener. Idempotent (guarded by [_initialized]).
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _controller.engine.state.addListener(_onStateChanged);
  }

  /// 引擎状态变化回调 — 仅处理 [MediaState.completed].
  ///
  /// Engine state callback — handles [MediaState.completed] only.
  /// - completed + loopSingle → replay current index
  /// - completed + other modes → auto-play next
  /// - other states → ignored
  void _onStateChanged() {
    if (_controller.engine.state.value != MediaState.completed) return;

    if (_controller.playlist.mode == PlayMode.loopSingle) {
      final idx = _controller.playlist.currentIndex;
      if (idx >= 0) unawaited(_replayIndex(idx));
    } else {
      unawaited(_autoAdvance());
    }
  }

  /// 单曲循环：重新播放指定索引.
  ///
  /// Loop-single: replays the specified index.
  Future<void> _replayIndex(int index) async {
    try {
      await _controller.navigator.playIndex(index);
    } on Exception catch (e, st) {
      _log.e('AutoAdvancePolicy loopSingle replay failed: $e', stackTrace: st);
      _controller.onError?.call(
        PlaybackError(
          PlaybackErrorCode.playFailed,
          'AutoAdvancePolicy loopSingle replay failed: $e',
          e,
        ),
      );
    }
  }

  /// 自动连播：播放下一首.
  ///
  /// Auto-advance: plays the next track.
  Future<void> _autoAdvance() async {
    try {
      await _controller.navigator.playNext();
    } on Exception catch (e, st) {
      _log.e('AutoAdvancePolicy auto-advance failed: $e', stackTrace: st);
      _controller.onError?.call(
        PlaybackError(
          PlaybackErrorCode.playFailed,
          'AutoAdvancePolicy auto-advance failed: $e',
          e,
        ),
      );
    }
  }

  /// 释放资源 — 注销引擎状态监听.
  ///
  /// Disposes resources — unregisters engine state listener.
  void dispose() {
    _controller.engine.state.removeListener(_onStateChanged);
  }
}
