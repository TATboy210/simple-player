import 'dart:io';

import '../engine/media_engine.dart';
import '../utils/path_utils.dart';
import '../utils/log.dart';

/// 字幕服务 — 外挂字幕自动检测与管理
///
/// 从 PlaybackNavigator 提取的字幕逻辑，提供扩展点:
///   - [detectAndLoad]: 自动扫描同名字幕文件
///   - 未来: searchOnline(), adjustStyle(), syncDelay()
class SubtitleService {
  final MediaEngine _engine;

  SubtitleService(this._engine);

  static const _subtitleExtensions = {
    '.srt',
    '.ass',
    '.ssa',
    '.sub',
    '.vtt',
    '.idx',
    '.sup',
  };

  /// 异步扫描媒体文件目录，匹配同名字幕文件并加载第一个匹配项。
  Future<void> detectAndLoad(String mediaPath) async {
    try {
      final dirPath = PathUtils.dirname(mediaPath);
      final fileName = PathUtils.basename(mediaPath);
      final lastDot = fileName.lastIndexOf('.');
      final baseName = (lastDot > 0 ? fileName.substring(0, lastDot) : fileName)
          .toLowerCase();

      final dir = Directory(dirPath);
      if (!await dir.exists()) return;

      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final entityName = PathUtils.basename(entity.path);
        final entityDot = entityName.lastIndexOf('.');
        if (entityDot <= 0) continue;
        final ext = entityName.substring(entityDot).toLowerCase();
        if (!_subtitleExtensions.contains(ext)) continue;
        final entityBase = entityName.substring(0, entityDot).toLowerCase();
        if (entityBase == baseName || entityBase.startsWith('$baseName.')) {
          _engine.setExternalSubtitle(entity.path);
        }
      }
    } on Object catch (e) {
      log.d('SubtitleService.detectAndLoad error: $e');
    }
  }

  /// Extension point: 在线字幕搜索
  ///
  /// 未来可接入 OpenSubtitles / SubHD 等 API。
  Future<void> searchOnline(String mediaPath) async {
    // TODO: implement online subtitle search
  }

  /// Extension point: 字幕样式调整
  void adjustStyle({double? fontSize, String? fontColor}) {
    // TODO: implement subtitle style adjustment
  }
}
