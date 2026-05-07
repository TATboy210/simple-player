import 'dart:io';

import 'package:flutter/foundation.dart';

import '../engine/media_engine.dart';
import '../models/media_state.dart';
import '../playlist/playlist.dart';
import '../utils/path_utils.dart';
import 'path_validator.dart';

/// 播放导航 mixin — 索引跳转/上一首/下一首
///
/// 职责: playIndex, playNext, playPrevious, openGeneration 守卫
mixin PlaybackNavigator {
  MediaEngine get engine;
  Playlist get playlist;
  ValueNotifier<String> get currentFileName;
  VoidCallback get onNeedRebuild;
  void Function(Object error)? get onError;
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
      _detectExternalSubtitles(current.path);

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

  // ─── External subtitle auto-detection ───

  static const _subtitleExtensions = {'.srt', '.ass', '.ssa', '.sub', '.vtt'};

  /// Scan media file directory for matching external subtitle files.
  /// Loads the first match via engine.setExternalSubtitle.
  ///
  /// Matches subtitle files with the same base name as the media file,
  /// e.g. "movie.mp4" matches "movie.srt", "movie.en.srt", "movie.ass".
  void _detectExternalSubtitles(String mediaPath) {
    try {
      final dirPath = PathUtils.dirname(mediaPath);
      final fileName = PathUtils.basename(mediaPath);
      final lastDot = fileName.lastIndexOf('.');
      final baseName = (lastDot > 0 ? fileName.substring(0, lastDot) : fileName)
          .toLowerCase();

      final dir = Directory(dirPath);
      if (!dir.existsSync()) return;

      for (final entity in dir.listSync()) {
        if (entity is! File) continue;
        final entityName = PathUtils.basename(entity.path);
        final entityDot = entityName.lastIndexOf('.');
        if (entityDot <= 0) continue;
        final ext = entityName.substring(entityDot).toLowerCase();
        if (!_subtitleExtensions.contains(ext)) continue;
        final entityBase = entityName.substring(0, entityDot).toLowerCase();
        // Match exact name or name with language tag (e.g. "movie.en.srt")
        if (entityBase == baseName || entityBase.startsWith('$baseName.')) {
          engine.setExternalSubtitle(entity.path);
          break; // load first match only
        }
      }
    } on Exception catch (e) {
      debugPrint('PlaybackNavigator._detectExternalSubtitles error: $e');
    }
  }
}
