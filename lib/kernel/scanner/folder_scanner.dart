import 'dart:io';
import 'package:path/path.dart' as p;

/// Represents a video file discovered in a directory scan.
class VideoFile {
  const VideoFile({
    required this.path,
    required this.name,
    required this.folderPath,
  });

  final String path;
  final String name;
  final String folderPath;

  @override
  String toString() => 'VideoFile($name)';
}

/// Scans a directory for video files (non-recursive).
class FolderScanner {
  FolderScanner._();

  static const _extensions = {
    '.mp4', '.mkv', '.avi', '.mov', '.wmv',
    '.flv', '.webm', '.m4v', '.ts', '.rmvb',
    '.mpg', '.mpeg', '.3gp', '.vob',
  };

  /// Scan [directory] for video files. Returns empty list on error.
  static List<VideoFile> scan(String directory) {
    try {
      final dir = Directory(directory);
      if (!dir.existsSync()) return [];

      return dir
          .listSync()
          .whereType<File>()
          .where((f) {
            final ext = p.extension(f.path).toLowerCase();
            return _extensions.contains(ext);
          })
          .map((f) => VideoFile(
                path: f.path,
                name: p.basename(f.path),
                folderPath: directory,
              ))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    } on Exception {
      return [];
    }
  }

  /// Get the parent directory of a file path.
  static String directoryOf(String filePath) {
    return p.dirname(filePath);
  }
}
