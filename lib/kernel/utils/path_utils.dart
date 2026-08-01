import 'dart:io' show Process;

import 'package:flutter/foundation.dart';

import '../diagnostics/kernel_logger.dart';

final _log = KernelLogger.I;

/// 路径工具函数
///
/// 统一的文件名提取，替代 4 处不一致的 split 逻辑。
///
/// Contract:
/// - Pure static utility class — no I/O for `basename`/`dirname`.
/// - `openFileLocation` has platform side effects (launches file manager).
/// - Handles both Unix (`/`) and Windows (`\`) path separators.
class PathUtils {
  PathUtils._();

  /// 从完整路径中提取文件名
  ///
  /// 兼容 Unix (/)、Windows (\) 和混合分隔符路径。
  /// 用 lastIndexOf 单次定位分隔符，避免旧版双重 split + 中间列表分配。
  ///
  /// - `path`: full file path with any separator style.
  /// - Returns: the filename portion after the last separator.
  /// - Returns [path] unchanged if no separator is found.
  ///
  /// Examples:
  /// `'C:/Videos/movie.mkv'` → `'movie.mkv'`
  /// `'/home/user/video.mp4'` → `'video.mp4'`
  /// `'song.mp3'` → `'song.mp3'`
  static String basename(String path) {
    // 从末尾找最后一个 / 或 \
    var lastSep = -1;
    for (var i = path.length - 1; i >= 0; i--) {
      final c = path.codeUnitAt(i);
      if (c == 0x2F || c == 0x5C) {
        // '/' or '\'
        lastSep = i;
        break;
      }
    }
    return lastSep >= 0 ? path.substring(lastSep + 1) : path;
  }

  /// 从完整路径中提取目录路径
  ///
  /// - `path`: full file path with any separator style.
  /// - Returns: the directory portion before the last separator.
  /// - Returns `'.'` when [path] contains no directory separator.
  ///
  /// Examples:
  /// `'C:/Videos/movie.mkv'` → `'C:/Videos'`
  /// `'song.mp3'` → `'.'`
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

  /// 打开文件所在目录（平台感知）
  ///
  /// - `path`: full file path; its parent directory will be opened.
  /// - `runner`: optional injectable process runner for testing; defaults to [Process.run].
  /// - Side effect: launches the platform file manager (explorer/xdg-open/open).
  /// - No-op with a warning log on unsupported platforms.
  static void openFileLocation(
    String path, {
    Future<void> Function(String, List<String>)? runner,
  }) {
    final run = runner ?? Process.run;
    final dir = dirname(path);
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        run('explorer', [dir]);
      case TargetPlatform.linux:
        run('xdg-open', [dir]);
      case TargetPlatform.macOS:
        run('open', [dir]);
      default:
        _log.w('openFileLocation: unsupported platform');
    }
  }
}
