// ignore_for_file: prefer-async-await, avoid-passing-async-when-sync-expected
import 'dart:async' show unawaited;
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

  /// 用系统默认浏览器打开外部 URL（平台感知）。
  ///
  /// - `url`: http(s) 外链；调用方负责给 URL 做白名单/常量来源约束
  ///   （本项目内只有「关于」页的社交链接常量表调用）。
  /// - Side effect: 启动平台浏览器（cmd start / xdg-open / open）。
  /// - Fire-and-forget：启动失败只记 warn 日志，绝不外抛（点链接失败
  ///   不应打断设置面板交互）。
  /// - No-op with a warning log on unsupported platforms.
  static void openUrl(String url) {
    void onLaunchError(Object error) {
      _log.w(
        'openUrl: failed to launch browser',
        context: {'error': error.toString()},
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        // start 是 cmd 内建命令（不是可执行文件），必须经 cmd /c 调用；
        // 空串参数占位防止 URL 里的 # 等字符被 start 当窗口标题解析。
        unawaited(
          Process.run('cmd', [
            '/c',
            'start',
            '',
            url,
          ]).then(
            // ignore: no-empty-block
            (_) {},
            onError: onLaunchError,
          ),
        );
      case TargetPlatform.linux:
        unawaited(
          Process.run('xdg-open', [url]).then(
            // ignore: no-empty-block
            (_) {},
            onError: onLaunchError,
          ),
        );
      case TargetPlatform.macOS:
        unawaited(
          Process.run('open', [url]).then(
            // ignore: no-empty-block
            (_) {},
            onError: onLaunchError,
          ),
        );
      default:
        _log.w('openUrl: unsupported platform');
    }
  }
}
