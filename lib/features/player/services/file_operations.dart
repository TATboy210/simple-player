import 'package:flutter/foundation.dart';

import '../../../kernel/engine/media_engine.dart';
import '../../../kernel/playlist/playlist.dart';
import '../../../kernel/services/path_validator.dart';

/// 文件操作 mixin — 打开/批量添加文件
///
/// 职责: openAndPlay, addFiles, validationError
mixin FileOperations {
  MediaEngine get engine;
  Playlist get playlist;
  ValueNotifier<String> get currentFileName;
  VoidCallback get onNeedRebuild;

  Future<void> playIndex(int index);
  void savePlaylist();

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

    var idx = playlist.items.indexWhere((e) => e.path == path);
    if (idx < 0) {
      playlist.add(path);
      idx = playlist.length - 1;
    }
    try {
      await playIndex(idx);
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

    final existing = playlist.items.map((e) => e.path).toSet();
    final wasEmpty = playlist.isEmpty;
    var addedCount = 0;
    for (final path in validPaths) {
      if (!existing.contains(path)) {
        playlist.add(path);
        existing.add(path);
        addedCount++;
      }
    }

    if (addedCount == 0) return 0;
    onNeedRebuild();

    if (wasEmpty && playlist.isNotEmpty) {
      try {
        await playIndex(0);
      } on Exception catch (e) {
        debugPrint('addFiles: playIndex(0) failed: $e');
        validationError.value = e.toString();
      }
    } else if (addedCount > 0) {
      savePlaylist();
    }
    return addedCount;
  }
}
