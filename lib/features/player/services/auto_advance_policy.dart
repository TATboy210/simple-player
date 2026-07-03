import 'dart:async';

import '../../../kernel/engine/engine_state.dart';
import '../../../kernel/models/play_mode.dart';
import '../../../kernel/playlist/playlist.dart';
import '../../../kernel/utils/log.dart';
import 'playback_navigator.dart';

/// 自动连播策略 — 引擎状态变为 completed 时根据播放模式决定行为
class AutoAdvancePolicy {
  AutoAdvancePolicy({
    required this.engine,
    required this.playlist,
    required this.navigator,
    required this.onError,
  });

  final EngineState engine;
  final Playlist playlist;
  final PlaybackNavigator navigator;
  final void Function(Object error)? onError;

  void init() {
    engine.state.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    if (engine.state.value != MediaState.completed) return;

    if (playlist.mode == PlayMode.loopSingle) {
      final idx = playlist.currentIndex;
      if (idx >= 0) unawaited(_replayIndex(idx));
    } else {
      unawaited(_autoAdvance());
    }
  }

  Future<void> _replayIndex(int index) async {
    try {
      await navigator.playIndex(index);
    } on Exception catch (e, st) {
      log.e('AutoAdvancePolicy loopSingle replay failed: $e', stackTrace: st);
      onError?.call(e);
    }
  }

  Future<void> _autoAdvance() async {
    try {
      await navigator.playNext();
    } on Exception catch (e, st) {
      log.e('AutoAdvancePolicy auto-advance failed: $e', stackTrace: st);
      onError?.call(e);
    }
  }

  void dispose() {
    engine.state.removeListener(_onStateChanged);
  }
}
