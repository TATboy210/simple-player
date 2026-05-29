import 'package:flutter/foundation.dart';

import '../../../kernel/services/path_validator.dart';
import '../../../kernel/utils/log.dart';
import 'playback_controller.dart';

/// 文件操作 — 打开/批量添加文件
///
/// 职责: openAndPlay, addFiles, validationError
class FileOperations {
  FileOperations(this._rt);
  final PlaybackController _rt;

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

    var idx = _rt.playlist.items.indexWhere((e) => e.path == path);
    if (idx < 0) {
      _rt.playlist.add(path);
      idx = _rt.playlist.length - 1;
    }
    try {
      await _rt.navigator.playIndex(idx);
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

    final existing = _rt.playlist.items.map((e) => e.path).toSet();
    final wasEmpty = _rt.playlist.isEmpty;
    var addedCount = 0;
    for (final path in validPaths) {
      if (!existing.contains(path)) {
        _rt.playlist.add(path);
        existing.add(path);
        addedCount++;
      }
    }

    if (addedCount == 0) return 0;
    _rt.onNeedRebuild();

    if (wasEmpty && _rt.playlist.isNotEmpty) {
      try {
        await _rt.navigator.playIndex(0);
      } on Exception catch (e) {
        log.e('addFiles: playIndex(0) failed: $e');
        validationError.value = e.toString();
      }
    } else if (addedCount > 0) {
      _rt.savePlaylist();
    }
    return addedCount;
  }
}
