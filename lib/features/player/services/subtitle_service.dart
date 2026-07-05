/// Services 层字幕检测模块 — 外挂字幕自动匹配与加载
///
/// 本文件实现 [SubtitleService] 负责扫描媒体文件目录，
/// 通过文件名相似性匹配外挂字幕文件（SRT/ASS/SSA/SUB/VTT/IDX/SUP）。
///
/// 架构位置：PlaybackNavigator → **SubtitleService** → EngineState.setExternalSubtitle()
/// 匹配算法：提取媒体文件基名（不含扩展名），查找同目录下同名或 "基名.语言.扩展名" 格式的字幕文件
/// 异步/同步变体：async 用于非热路径，sync 用于 playIndex 热路径
library;

import 'dart:io';

import '../../../kernel/engine/engine_state.dart';
import '../../../kernel/utils/path_utils.dart';
import '../../../kernel/utils/log.dart';

/// 字幕服务 — 外挂字幕自动检测与管理
///
/// 匹配规则：
/// 1. 提取媒体文件基名（不含扩展名），小写归一化
/// 2. 扫描同目录下所有文件，筛选已知字幕扩展名
/// 3. 匹配条件：文件基名 == 媒体基名，或文件基名以 "媒体基名." 开头
///    例如：movie.en.srt 匹配 movie.mkv（支持多语言字幕文件）
///
/// 支持的字幕格式：SRT / ASS / SSA / SUB / VTT / IDX / SUP
class SubtitleService {
  final EngineState _engine;

  SubtitleService(this._engine);

  /// 已知字幕扩展名集合 — 覆盖主流外挂字幕格式
  static const subtitleExtensions = {
    '.srt', // SubRip — 最常见的字幕格式
    '.ass', // Advanced SubStation Alpha — 支持样式和定位
    '.ssa', // SubStation Alpha — ASS 的前身
    '.sub', // MicroDVD — 基于帧的字幕格式
    '.vtt', // WebVTT — Web 标准字幕格式
    '.idx', // VobSub 索引文件 — 配合 .sub 使用
    '.sup', // PGS — 蓝光图形字幕
  };

  /// 异步扫描媒体文件目录，匹配同名字幕文件并加载第一个匹配项。
  ///
  /// 使用 Stream.list() 异步遍历目录，适合非热路径调用。
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
          return; // 只加载第一个匹配的字幕（与 detectAndLoadSync 一致）
        }
      }
    } on Exception catch (e) {
      log.d('SubtitleService.detectAndLoad error: $e');
    }
  }

  /// 同步扫描媒体文件目录，加载第一个匹配的字幕文件。
  ///
  /// 用于 playIndex 热路径（避免 async 改变调用链签名）。
  /// 使用 listSync() 同步遍历目录，文件数量通常很少（< 100），性能可接受。
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

  /// 提取文件名基名（不含扩展名），小写归一化
  ///
  /// 例如：`/path/to/movie.en.srt` → `movie.en`
  /// 用于与同目录下的字幕文件做基名匹配。
  static String _extractBaseName(String mediaPath) {
    final fileName = PathUtils.basename(mediaPath);
    final lastDot = fileName.lastIndexOf('.');
    return (lastDot > 0 ? fileName.substring(0, lastDot) : fileName)
        .toLowerCase();
  }

  /// 检查文件是否是匹配的字幕文件，返回路径或 null
  ///
  /// 匹配条件：
  /// 1. 文件扩展名在 subtitleExtensions 集合中
  /// 2. 文件基名 == 媒体基名（精确匹配），或以 "媒体基名." 开头（语言后缀匹配）
  ///    例如：movie.en.srt 匹配 movie.mkv → entityBase="movie.en", baseName="movie"
  String? _matchSubtitle(String filePath, String baseName) {
    final entityName = PathUtils.basename(filePath);
    final entityDot = entityName.lastIndexOf('.');
    if (entityDot <= 0) return null;
    final ext = entityName.substring(entityDot).toLowerCase();
    if (!subtitleExtensions.contains(ext)) return null;
    final entityBase = entityName.substring(0, entityDot).toLowerCase();
    // 精确匹配或语言后缀匹配（如 movie.en.srt 匹配 movie）
    if (entityBase == baseName || entityBase.startsWith('$baseName.')) {
      return filePath;
    }
    return null;
  }
}
