import 'dart:io';

import '../../../kernel/engine/player_engine.dart';
import '../../../kernel/utils/path_utils.dart';
import '../../../kernel/utils/log.dart';

/// 字幕服务 — 外挂字幕自动检测与管理
class SubtitleService {
  final PlayerEngine _engine;

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
      final dir = Directory(PathUtils.dirname(mediaPath));
      if (!await dir.exists()) return;

      final baseName = _extractBaseName(mediaPath);
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final match = _matchSubtitle(entity.path, baseName);
        if (match != null) {
          _engine.setExternalSubtitle(match);
        }
      }
    } on Exception catch (e) {
      log.d('SubtitleService.detectAndLoad error: $e');
    }
  }

  /// 同步扫描媒体文件目录，加载第一个匹配的字幕文件。
  ///
  /// 用于 playIndex 热路径（避免 async 改变调用链签名）。
  void detectAndLoadSync(String mediaPath) {
    try {
      final dir = Directory(PathUtils.dirname(mediaPath));
      if (!dir.existsSync()) return;

      final baseName = _extractBaseName(mediaPath);
      for (final entity in dir.listSync()) {
        if (entity is! File) continue;
        final match = _matchSubtitle(entity.path, baseName);
        if (match != null) {
          _engine.setExternalSubtitle(match);
          break;
        }
      }
    } on Exception catch (e) {
      log.d('SubtitleService.detectAndLoadSync error: $e');
    }
  }

  /// 提取文件名（不含扩展名），小写。
  static String _extractBaseName(String mediaPath) {
    final fileName = PathUtils.basename(mediaPath);
    final lastDot = fileName.lastIndexOf('.');
    return (lastDot > 0 ? fileName.substring(0, lastDot) : fileName)
        .toLowerCase();
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
}
