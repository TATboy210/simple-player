/// Services 层文件操作模块 — 打开/批量添加文件
///
/// 本文件实现 [FileOperations] 负责文件打开（单个/批量），
/// 集成 PathValidator 路径安全验证和去重逻辑。
///
/// 架构位置：PlaybackController → **FileOperations** → PlaybackNavigator + PathValidator
/// 安全机制：所有文件路径通过 PathValidator.validate() 验证，防止路径遍历攻击
/// 去重策略：使用 Set 做 O(1) 查找，避免重复添加同一文件
library;

import 'package:flutter/foundation.dart';

import '../../../kernel/services/path_validator.dart';
import '../../../kernel/utils/log.dart';
import 'playback_controller.dart';

/// 文件操作服务 — 文件打开和批量添加
///
/// 职责：
/// - [openAndPlay] — 打开单个文件：路径验证 → 查找/添加到播放列表 → 播放
/// - [addFiles] — 批量添加文件：路径验证 → 去重 → 自动播放第一个文件（如果播放列表为空）
/// - [validationError] — 最近一次校验失败的错误消息（UI 层显示用）
class FileOperations {
  FileOperations(this._controller);
  final PlaybackController _controller;

  /// 最近一次校验失败的错误消息（null 表示无错误）
  final ValueNotifier<String?> validationError = ValueNotifier<String?>(null);

  /// 打开并播放文件 — 完整的打开流程
  ///
  /// 流程：路径验证 → 在播放列表中查找或添加 → 播放该索引
  /// 返回 true 表示成功打开并开始播放。
  Future<bool> openAndPlay(String path) async {
    final error = PathValidator.validate(path);
    if (error != null) {
      validationError.value = error;
      return false;
    }
    validationError.value = null;

    // 如果文件已在播放列表中，直接播放；否则添加到末尾
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

  /// 批量添加文件 — 路径验证 + 去重 + 自动播放
  ///
  /// [paths] 文件路径列表（未验证）。
  /// 返回成功添加的数量。如果播放列表之前为空，自动播放第一个文件。
  Future<int> addFiles(List<String> paths) async {
    final validPaths = PathValidator.filterValid(paths);
    if (validPaths.isEmpty) return 0;

    // 使用 Set 做 O(1) 去重检查 — 替代 List.indexWhere 的 O(n) 扫描
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

    // 播放列表之前为空 → 自动播放第一个文件（提升用户体验）
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
