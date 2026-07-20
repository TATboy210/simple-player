import 'dart:io';
import 'package:path/path.dart' as p;

import '../diagnostics/kernel_logger.dart';

/// Represents a video file discovered in a directory scan.
class VideoFile {
  const VideoFile({
    required this.path,
    required this.name,
    required this.folderPath,
  });

  /// Absolute path to the video file.
  final String path;

  /// File name with extension (e.g. "movie.mp4").
  final String name;

  /// Parent directory path.
  final String folderPath;

  @override
  String toString() => 'VideoFile($name)';
}

/// Scans a directory for video files (non-recursive).
class FolderScanner {
  FolderScanner._();

  // 14 种常见视频格式，覆盖主流容器和编码
  static const _extensions = {
    '.mp4',
    '.mkv',
    '.avi',
    '.mov',
    '.wmv',
    '.flv',
    '.webm',
    '.m4v',
    '.ts',
    '.rmvb',
    '.mpg',
    '.mpeg',
    '.3gp',
    '.vob',
  };

  /// Scan [directory] for video files. Returns empty list on error.
  ///
  /// 异步遍历目录（dir.list() + await for），避免 listSync 阻塞 UI isolate。
  /// 同步语义保留：非递归、扩展名大小写不敏感、按文件名升序排序。
  static Future<List<VideoFile>> scan(String directory) async {
    try {
      final dir = Directory(directory);
      // exists() 异步让出事件循环（vs existsSync 阻塞），大目录扫描不卡 UI
      if (!await dir.exists()) return [];

      final results = <VideoFile>[];
      // await for 逐项流式处理：每个 entity 让出事件循环，UI 可穿插响应
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final ext = p.extension(entity.path).toLowerCase();
        if (!_extensions.contains(ext)) continue;
        results.add(
          VideoFile(
            path: entity.path,
            name: p.basename(entity.path),
            folderPath: directory,
          ),
        );
      }
      // 流结束后统一排序，保持原同步版的稳定升序语义
      results.sort((a, b) => a.name.compareTo(b.name));
      return results;
    } on Exception catch (e) {
      KernelLoggerImpl.I.e('FolderScanner: failed to scan', error: e);
      return [];
    }
  }

  /// Get the parent directory of a file path.
  static String directoryOf(String filePath) {
    return p.dirname(filePath);
  }
}
