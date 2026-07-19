/// Services 层播放导航模块 — 索引跳转与并发守卫
///
/// 本文件实现 [PlaybackNavigator] 负责曲目索引跳转、上一首/下一首导航，
/// 以及关键的 openGeneration 并发守卫机制。
///
/// 架构位置：PlaybackController → **PlaybackNavigator** → MediaEngine.open()
/// 并发模型：openGeneration 计数器丢弃过期的异步 open() 请求
library;

import 'dart:async';

import '../engine/engine_state.dart';
import '../diagnostics/kernel_logger.dart';
import '../utils/path_utils.dart';
import '../services/path_validator.dart';
import 'playback_controller.dart';

final log = KernelLogger.I;

/// 播放导航 — 索引跳转、上一首/下一首、并发 open() 守卫
///
/// 职责：
/// - [playIndex] — 播放指定索引（核心方法，包含完整的打开流程）
/// - [playNext] / [playPrevious] — 委托 playlist 的 peekNext/peekPrevious
/// - openGeneration 守卫 — 快速切换曲目时丢弃过期的异步请求
///
/// openGeneration 模式：用户快速切歌时，多个异步 open() 调用重叠。
/// 每次调用 playIndex 递增 generation，异步完成后检查 generation 是否仍匹配。
/// 若不匹配，说明用户已切歌，直接 return 丢弃旧请求。
class PlaybackNavigator {
  PlaybackNavigator(this._controller);
  final PlaybackController _controller;

  /// 并发 open() 守卫：快速切换歌曲时，丢弃过期的异步请求
  int _openGeneration = 0;

  /// 当前 generation 值，供 UI 层检查异步回调是否过期
  int get currentGeneration => _openGeneration;

  /// 播放指定索引 — 完整的打开流程
  ///
  /// 流程：校验索引 → 递增 generation → 路径安全检查 → 打开引擎 →
  /// 恢复断点位置 → 检测字幕 → 播放 → 更新文件名和历史
  ///
  /// 并发安全：通过 generation 计数器丢弃过期的异步结果，
  /// 确保快速切歌时只有最后一次 open() 生效。
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
      _controller.onError?.call(FileError(FileErrorCode.pathTraversal, validationError));
      return;
    }

    try {
      await _controller.engine.open(current.path);
      // generation 不匹配说明用户已切歌，丢弃本次结果
      if (gen != _openGeneration) return;
      if (_controller.engine.state.value == MediaState.error) {
        throw Exception(_controller.engine.lastError.value?.message ?? '打开失败');
      }

      // FEAT-01: Resume from saved position (> 1s threshold)
      // 只恢复 > 1s 的断点 — < 1s 通常是噪声（如退出时刚好暂停在开头）
      final savedMs = current.positionMs;
      if (savedMs != null && savedMs > 1000) {
        await _controller.engine.seekTo(savedMs);
      }

      // FEAT-03: Auto-detect external subtitles
      // fire-and-forget：字幕检测失败不影响播放
      final subtitlePath = current.path;
      unawaited(
        _controller.subtitleService?.detectAndLoad(subtitlePath).catchError(
          (Object e) {
            log.d('Subtitle detection failed: $e');
          },
        ),
      );

      // FEAT-04: Restore track preferences (audio/subtitle track, subtitle delay)
      _controller.trackPreferenceService?.restoreAfterOpen(_controller.engine.mediaInfo);

      _controller.engine.play();
    } on Exception catch (e) {
      log.e('PlaybackNavigator.playIndex($index) failed: $e');
      // 只在 generation 仍匹配时恢复原索引，避免干扰后续切歌
      if (gen == _openGeneration) {
        _controller.playlist.currentIndex = oldIndex;
      }
      _controller.onError?.call(
        PlaybackError(PlaybackErrorCode.playFailed, 'PlaybackNavigator.playIndex($index) failed: $e', e),
      );
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

  /// 播放下一首 — 委托 playlist.peekNext() 获取下一个索引
  Future<void> playNext() async {
    final next = _controller.playlist.peekNext();
    if (next >= 0) await playIndex(next);
  }

  /// 播放上一首 — 委托 playlist.peekPrevious() 获取上一个索引
  Future<void> playPrevious() async {
    final prev = _controller.playlist.peekPrevious();
    if (prev >= 0) await playIndex(prev);
  }
}
