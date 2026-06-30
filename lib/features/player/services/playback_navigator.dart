import 'dart:async';

import '../../../kernel/engine/engine_state.dart';
import '../../../kernel/utils/log.dart';
import '../../../kernel/utils/path_utils.dart';
import '../../../kernel/services/path_validator.dart';
import 'playback_controller.dart';

/// 播放导航 — 索引跳转/上一首/下一首
///
/// 职责: playIndex, playNext, playPrevious, openGeneration 守卫
class PlaybackNavigator {
  PlaybackNavigator(this._controller);
  final PlaybackController _controller;

  /// 并发 open() 守卫：快速切换歌曲时，丢弃过期的异步请求
  int _openGeneration = 0;

  /// 当前 generation 值，供 UI 层检查异步回调是否过期
  int get currentGeneration => _openGeneration;

  /// 播放指定索引
  Future<void> playIndex(int index) async {
    if (index < 0 || index >= _controller.playlist.length) return;
    final gen = ++_openGeneration;
    final oldIndex = _controller.playlist.currentIndex;
    _controller.playlist.currentIndex = index;
    final current = _controller.playlist.current;
    if (current == null) return;

    // 安全：验证路径防止播放列表注入的路径遍历
    final validationError = PathValidator.validate(current.path);
    if (validationError != null) {
      log.w('playIndex: rejected unsafe path: $validationError');
      _controller.onError?.call(Exception(validationError));
      return;
    }

    try {
      await _controller.engine.open(current.path);
      if (gen != _openGeneration) return;
      if (_controller.engine.state.value == MediaState.error) {
        throw Exception(_controller.engine.errorMessage.value ?? '打开失败');
      }

      // FEAT-01: Resume from saved position (> 1s threshold)
      final savedMs = current.positionMs;
      if (savedMs != null && savedMs > 1000) {
        await _controller.engine.seekTo(savedMs);
      }

      // FEAT-03: Auto-detect external subtitles
      final subtitlePath = current.path;
      unawaited(
        _controller.subtitleService?.detectAndLoad(subtitlePath).catchError(
          (Object e) {
            log.d('Subtitle detection failed: $e');
          },
        ),
      );

      _controller.engine.play();
    } on Exception catch (e) {
      log.e('PlaybackNavigator.playIndex($index) failed: $e');
      if (gen == _openGeneration) {
        _controller.playlist.currentIndex = oldIndex;
      }
      _controller.onError?.call(e);
      return;
    }
    _controller.onNeedRebuild();
    _controller.currentFileName.value = PathUtils.basename(current.path);
    _controller.playlist.updateHistory(
      index,
      positionMs: _controller.engine.position.value,
      durationMs: _controller.engine.duration.value,
    );
    _controller.savePlaylist();
  }

  /// 播放下一首
  Future<void> playNext() async {
    final next = _controller.playlist.peekNext();
    if (next >= 0) await playIndex(next);
  }

  /// 播放上一首
  Future<void> playPrevious() async {
    final prev = _controller.playlist.peekPrevious();
    if (prev >= 0) await playIndex(prev);
  }
}
