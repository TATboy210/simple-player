import 'package:flutter/foundation.dart';

import '../../../kernel/engine/media_engine.dart';
import '../../../kernel/models/media_state.dart';
import '../../../kernel/playlist/playlist.dart';
import '../../../kernel/utils/path_utils.dart';
import '../../../kernel/services/path_validator.dart';
import 'subtitle_service.dart';

/// 播放导航 mixin — 索引跳转/上一首/下一首
///
/// 职责: playIndex, playNext, playPrevious, openGeneration 守卫
mixin PlaybackNavigator {
  MediaEngine get engine;
  Playlist get playlist;
  ValueNotifier<String> get currentFileName;
  VoidCallback get onNeedRebuild;
  void Function(Object error)? get onError;
  SubtitleService? get subtitleService;
  void savePlaylist();

  /// 并发 open() 守卫：快速切换歌曲时，丢弃过期的异步请求
  int openGeneration = 0;

  /// 当前 generation 值，供 UI 层检查异步回调是否过期
  int get currentGeneration => openGeneration;

  /// 播放指定索引
  Future<void> playIndex(int index) async {
    if (index < 0 || index >= playlist.length) return;
    final gen = ++openGeneration;
    final oldIndex = playlist.currentIndex;
    playlist.currentIndex = index;
    final current = playlist.current;
    if (current == null) return;

    // 安全：验证路径防止播放列表注入的路径遍历
    final validationError = PathValidator.validate(current.path);
    if (validationError != null) {
      debugPrint('playIndex: rejected unsafe path: $validationError');
      onError?.call(Exception(validationError));
      return;
    }

    try {
      await engine.open(current.path);
      if (gen != openGeneration) return;
      if (engine.state.value == MediaState.error) {
        throw Exception(engine.errorMessage.value ?? '打开失败');
      }

      // FEAT-01: Resume from saved position (> 1s threshold)
      final savedMs = current.positionMs;
      if (savedMs != null && savedMs > 1000) {
        await engine.seekTo(savedMs);
      }

      // FEAT-03: Auto-detect external subtitles
      subtitleService?.detectAndLoadSync(current.path);

      engine.play();
    } on Exception catch (e) {
      debugPrint('PlaybackNavigator.playIndex($index) failed: $e');
      if (gen == openGeneration) {
        playlist.currentIndex = oldIndex;
      }
      onError?.call(e);
      return;
    }
    onNeedRebuild();
    currentFileName.value = PathUtils.basename(current.path);
    playlist.updateHistory(
      index,
      positionMs: engine.position.value,
      durationMs: engine.duration.value,
    );
    savePlaylist();
  }

  /// 播放下一首
  Future<void> playNext() async {
    final next = playlist.peekNext();
    if (next >= 0) await playIndex(next);
  }

  /// 播放上一首
  Future<void> playPrevious() async {
    final prev = playlist.peekPrevious();
    if (prev >= 0) await playIndex(prev);
  }
}
