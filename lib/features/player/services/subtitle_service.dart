import 'dart:io';

import '../../../kernel/engine/media_engine.dart';
import '../../../kernel/utils/path_utils.dart';
import '../../../kernel/utils/log.dart';

/// 字幕服务 — 外挂字幕自动检测与管理
///
/// 从 PlaybackNavigator 提取的字幕逻辑，提供扩展点:
///   - [detectAndLoad]: 异步扫描同名字幕文件
///   - [detectAndLoadSync]: 同步扫描（用于 playIndex 热路径）
///   - 未来: searchOnline(), adjustStyle(), syncDelay()
class SubtitleService {
  final MediaEngine _engine;

  SubtitleService(this._engine);

  static const subtitleExtensions = {
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
        final match = _matchSubtitle(entity.path, baseName);
        if (match != null) {
          _engine.setExternalSubtitle(match);
        }
      }
    } on Object catch (e) {
      log.d('SubtitleService.detectAndLoad error: $e');
    }
  }

  /// 同步扫描媒体文件目录，加载第一个匹配的字幕文件。
  ///
  /// 用于 playIndex 热路径（避免 async 改变调用链签名）。
  /// Directory.listSync() 在小目录（<20 文件）上开销可忽略。
  void detectAndLoadSync(String mediaPath) {
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
        final match = _matchSubtitle(entity.path, baseName);
        if (match != null) {
          _engine.setExternalSubtitle(match);
          break; // load first match only (sync path)
        }
      }
    } on Object catch (e) {
      log.d('SubtitleService.detectAndLoadSync error: $e');
    }
  }

  /// 检查文件是否是匹配的字幕文件，返回路径或 null。
  String? _matchSubtitle(String filePath, String baseName) {
    final entityName = PathUtils.basename(filePath);
    final entityDot = entityName.lastIndexOf('.');
    if (entityDot <= 0) return null;
    final ext = entityName.substring(entityDot).toLowerCase();
    if (!subtitleExtensions.contains(ext)) return null;
    final entityBase = entityName.substring(0, entityDot).toLowerCase();
    if (entityBase == baseName || entityBase.startsWith('$baseName.')) {
      return filePath;
    }
    return null;
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
