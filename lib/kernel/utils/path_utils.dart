/// 路径工具函数
///
/// 统一的文件名提取，替代 4 处不一致的 split 逻辑。
class PathUtils {
  PathUtils._();

  /// 从完整路径中提取文件名
  ///
  /// 兼容 Unix (/)、Windows (\) 和混合分隔符路径。
  /// 用 lastIndexOf 单次定位分隔符，避免旧版双重 split + 中间列表分配。
  /// 'C:/Videos/movie.mkv' → 'movie.mkv'
  /// '/home/user/video.mp4' → 'video.mp4'
  /// 'song.mp3' → 'song.mp3'
  static String basename(String path) {
    // 从末尾找最后一个 / 或 \
    var lastSep = -1;
    for (var i = path.length - 1; i >= 0; i--) {
      final c = path.codeUnitAt(i);
      if (c == 0x2F || c == 0x5C) { // '/' or '\'
        lastSep = i;
        break;
      }
    }
    return lastSep >= 0 ? path.substring(lastSep + 1) : path;
  }

  /// 从完整路径中提取目录路径
  ///
  /// 'C:/Videos/movie.mkv' → 'C:/Videos'
  /// 'song.mp3' → '.'
  static String dirname(String path) {
    var lastSep = -1;
    for (var i = path.length - 1; i >= 0; i--) {
      final c = path.codeUnitAt(i);
      if (c == 0x2F || c == 0x5C) {
        lastSep = i;
        break;
      }
    }
    return lastSep >= 0 ? path.substring(0, lastSep) : '.';
  }
}
