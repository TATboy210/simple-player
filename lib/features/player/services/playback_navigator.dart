import 'package:flutter/foundation.dart';

import '../../../kernel/models/media_state.dart';
import '../../../kernel/utils/path_utils.dart';
import '../../../kernel/services/path_validator.dart';
import 'playback_controller.dart';

/// 播放导航 — 索引跳转/上一首/下一首
///
/// 职责: playIndex, playNext, playPrevious, openGeneration 守卫
class PlaybackNavigator {
  PlaybackNavigator(this._rt);
  final PlaybackController _rt;

  /// 并发 open() 守卫：快速切换歌曲时，丢弃过期的异步请求
  int _openGeneration = 0;

  /// 当前 generation 值，供 UI 层检查异步回调是否过期
  int get currentGeneration => _openGeneration;

  /// 播放指定索引
  Future<void> playIndex(int index) async {
    if (index < 0 || index >= _rt.playlist.length) return;
    final gen = ++_openGeneration;
    final oldIndex = _rt.playlist.currentIndex;
    _rt.playlist.currentIndex = index;
    final current = _rt.playlist.current;
    if (current == null) return;

    // 安全：验证路径防止播放列表注入的路径遍历
    final validationError = PathValidator.validate(current.path);
    if (validationError != null) {
      debugPrint('playIndex: rejected unsafe path: $validationError');
      _rt.onError?.call(Exception(validationError));
      return;
    }

    try {
      await _rt.engine.open(current.path);
      if (gen != _openGeneration) return;
      if (_rt.engine.state.value == MediaState.error) {
        throw Exception(_rt.engine.errorMessage.value ?? '打开失败');
      }

      // FEAT-01: Resume from saved position (> 1s threshold)
      final savedMs = current.positionMs;
      if (savedMs != null && savedMs > 1000) {
        await _rt.engine.seekTo(savedMs);
      }

      // FEAT-03: Auto-detect external subtitles
      _rt.subtitleService?.detectAndLoadSync(current.path);

      _rt.engine.play();
    } on Exception catch (e) {
      debugPrint('PlaybackNavigator.playIndex($index) failed: $e');
      if (gen == _openGeneration) {
        _rt.playlist.currentIndex = oldIndex;
      }
      _rt.onError?.call(e);
      return;
    }
    _rt.onNeedRebuild();
    _rt.currentFileName.value = PathUtils.basename(current.path);
    _rt.playlist.updateHistory(
      index,
      positionMs: _rt.engine.position.value,
      durationMs: _rt.engine.duration.value,
    );
    _rt.savePlaylist();
  }

  /// 播放下一首
  Future<void> playNext() async {
    final next = _rt.playlist.peekNext();
    if (next >= 0) await playIndex(next);
  }

  /// 播放上一首
  Future<void> playPrevious() async {
    final prev = _rt.playlist.peekPrevious();
    if (prev >= 0) await playIndex(prev);
  }
}
