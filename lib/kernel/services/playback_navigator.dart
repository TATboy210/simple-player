/// Services 层播放导航模块 — 索引跳转与并发守卫
///
/// 本文件实现 [PlaybackNavigator] 负责曲目索引跳转、上一首/下一首导航，
/// 以及关键的 openGeneration 并发守卫机制。
///
/// 架构位置：PlaybackController → **PlaybackNavigator** → MediaEngine.open()
/// 并发模型：openGeneration 计数器丢弃过期的异步 open() 请求
library;

import 'dart:async';

import '../diagnostics/kernel_logger.dart' show KernelLoggerImpl;
import '../engine/open_result.dart';
import '../models/player_error.dart';
import '../utils/path_utils.dart';
import '../services/path_validator.dart';
import 'playback_controller.dart';

final _log = KernelLoggerImpl.I;

/// 播放导航 — 索引跳转、上一首/下一首与打开结果提交。
///
/// 职责：
/// - [playIndex] — 播放指定索引，并只在 [OpenSuccess] 后提交副作用。
/// - [playNext] / [playPrevious] — 委托 playlist 的 peekNext/peekPrevious。
///
/// 并发安全由引擎的 [OpenResult] 契约表达：较新的打开请求会使旧请求返回
/// [OpenSuperseded]，导航器因此无需读取或预测引擎内部 generation。
class PlaybackNavigator {
  PlaybackNavigator(this._controller);
  final PlaybackController _controller;

  /// 播放指定索引。
  ///
  /// 正常打开失败以 [OpenError] 返回并恢复原索引；[OpenSuperseded] 是并发
  /// 正常结局，不报告错误且不提交任何属于旧请求的播放、历史或持久化副作用。
  Future<void> playIndex(int index) async {
    if (index < 0 || index >= _controller.playlist.length) return;

    final oldIndex = _controller.playlist.currentIndex;
    _controller.playlist.currentIndex = index;
    final current = _controller.playlist.current;
    if (current == null) return;

    // 安全：验证路径防止播放列表注入的路径遍历。
    final validationError = PathValidator.validate(current.path);
    if (validationError != null) {
      _log.w('playIndex: rejected unsafe path: $validationError');
      _controller.onError?.call(
        FileError(FileErrorCode.pathTraversal, validationError),
      );
      return;
    }

    final result = await _controller.engine.open(current.path);
    switch (result) {
      case OpenSuccess():
        await _commitOpenSuccess(
          index,
          oldIndex,
          current.path,
          current.positionMs,
        );
      case OpenError(:final error):
        _controller.playlist.currentIndex = oldIndex;
        _controller.onError?.call(error);
      case OpenSuperseded():
        // 旧请求不能覆盖新请求已选择的播放列表项或 UI 状态。
        return;
    }
  }

  /// 提交成功打开后的播放相关副作用。
  ///
  /// 断点恢复包含异步边界；恢复结束后重新确认目标仍被选中，避免旧请求
  /// 对已切换的媒体调用 play()、写入历史或覆盖标题。
  Future<void> _commitOpenSuccess(
    int index,
    int oldIndex,
    String path,
    int? savedPositionMs,
  ) async {
    try {
      if (savedPositionMs != null && savedPositionMs > 1000) {
        // 小于一秒的退出位置通常只是开头噪声，不应触发恢复跳转。
        await _controller.engine.seekTo(savedPositionMs);
      }
    } on Exception catch (error) {
      if (!_isSelectedTarget(index, path)) return;
      _log.e('PlaybackNavigator.playIndex($index) seek failed: $error');
      _controller.playlist.currentIndex = oldIndex;
      _controller.onError?.call(
        PlaybackError(
          PlaybackErrorCode.playFailed,
          'PlaybackNavigator.playIndex($index) seek failed: $error',
          error,
        ),
      );
      return;
    }

    if (!_isSelectedTarget(index, path)) return;

    // 字幕检测不影响主播放链路，失败仅记录诊断信息。
    unawaited(
      _controller.subtitleService?.detectAndLoad(path).catchError((
        Object error,
      ) {
        _log.d('Subtitle detection failed: $error');
      }),
    );
    _controller.trackPreferenceService?.restoreAfterOpen(
      _controller.engine.mediaInfo,
    );
    _controller.engine.play();
    _controller.onNeedRebuild();
    _controller.currentFileName.value = PathUtils.basename(path);
    _controller.playlist.updateHistory(
      index,
      positionMs: _controller.engine.position.value,
      durationMs: _controller.engine.duration.value,
    );
    _controller.savePlaylist();
  }

  /// 检查异步恢复期间是否已选择了另一首曲目。
  bool _isSelectedTarget(int index, String path) =>
      _controller.playlist.currentIndex == index &&
      _controller.playlist.current?.path == path;

  /// 播放下一首；无可播放后继项时安全卸载已完成的媒体。
  ///
  /// loopAll、loopSingle 与 shuffle 的回绕/重播仍由 [Playlist.peekNext] 决定；
  /// 只有它明确返回 `-1` 时才进入空置收尾。
  Future<void> playNext() async {
    final next = _controller.playlist.peekNext();
    if (next >= 0) {
      await playIndex(next);
      return;
    }

    await _controller.stopCurrentMedia();
  }

  /// 播放上一首 — 委托 playlist.peekPrevious() 获取上一个索引
  Future<void> playPrevious() async {
    final prev = _controller.playlist.peekPrevious();
    if (prev >= 0) await playIndex(prev);
  }
}
