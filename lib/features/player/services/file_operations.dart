import 'package:flutter/foundation.dart';

import '../../../kernel/services/path_validator.dart';
import '../../../kernel/utils/log.dart';
import 'playback_controller.dart';

/// 文件操作 — 打开/批量添加文件
///
/// 职责: openAndPlay, addFiles, validationError
class FileOperations {
  FileOperations(this._controller);
  final PlaybackController _controller;

  /// 最近一次校验失败的错误消息（null 表示无错误）
  final ValueNotifier<String?> validationError = ValueNotifier<String?>(null);

  /// 添加文件到播放列表并播放（已校验的路径）
  Future<bool> openAndPlay(String path) async {
    final error = PathValidator.validate(path);
    if (error != null) {
      validationError.value = error;
      return false;
    }
    validationError.value = null;

    var idx = _controller.playlist.items.indexWhere((e) => e.path == path);
    if (idx < 0) {
      _controller.playlist.add(path);
      idx = _controller.playlist.length - 1;
    }
    try {
      await _controller.navigator.playIndex(idx);
      return true;
    } on Exception catch (e) {
      validationError.value = e.toString();
      return false;
    }
  }

  /// 批量添加文件（已校验的路径列表），返回成功添加的数量
  Future<int> addFiles(List<String> paths) async {
    final validPaths = PathValidator.filterValid(paths);
    if (validPaths.isEmpty) return 0;

    final existing = _controller.playlist.items.map((e) => e.path).toSet();
    final wasEmpty = _controller.playlist.isEmpty;
    var addedCount = 0;
    for (final path in validPaths) {
      if (!existing.contains(path)) {
        _controller.playlist.add(path);
        existing.add(path);
        addedCount++;
      }
    }

    if (addedCount == 0) return 0;
    _controller.onNeedRebuild();

    if (wasEmpty && _controller.playlist.isNotEmpty) {
      try {
        await _controller.navigator.playIndex(0);
      } on Exception catch (e) {
        log.e('addFiles: playIndex(0) failed: $e');
        validationError.value = e.toString();
      }
    } else if (addedCount > 0) {
      _controller.savePlaylist();
    }
    return addedCount;
  }
}
