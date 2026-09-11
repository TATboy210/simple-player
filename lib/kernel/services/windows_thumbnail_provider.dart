import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/painting.dart';
import 'package:flutter_video_thumbnail_plus/flutter_video_thumbnail_plus.dart';
import 'package:path/path.dart' as p;

import 'thumbnail_provider.dart';

/// Windows 缩略图 Provider — Media Foundation 解帧 + WIC 编码 + 磁盘缓存.
///
/// Windows thumbnail provider — frame extraction via Media Foundation
/// ([FlutterVideoThumbnailPlus]) with a on-disk JPEG cache to survive
/// app restarts.
///
/// 依赖选型 (v0.0.5, fc_native_video_thumbnail 已弃): 前者走 Windows Shell
/// 缩略图缓存, 对缓存 miss/特殊容器会 WTS_E_FAILEDEXTRACTION; 本包走
/// Media Foundation 系统解码器直接解帧, 与播放器解码能力同源.
///
/// 缓存布局: `<appSupport>/cache/thumbnails/<md5(path)>.jpg` —
/// md5(path) 为键与 Linux XDG provider 同风格; 生成一次永久复用,
/// 不随源文件变化失效 (断点进度条另由 UI 层表达).
class WindowsThumbnailProvider implements ThumbnailProvider {
  /// [resolveCacheDirectory] 可注入以便测试 (production 用 path_provider).
  const WindowsThumbnailProvider({this.resolveCacheDirectory});

  /// 缩略图最长边 — 列表卡片 16:9 显示足够, 解帧开销最小化.
  static const _maxSize = 320;

  /// 截帧时间点 (ms) — 取 1s 处避开常见黑屏首帧; 超出时长的短视频由
  /// Media Foundation 收敛到末帧.
  static const _timeMs = 1000;

  /// 磁盘缓存目录解析 — 可注入以便测试 (production 用 path_provider).
  final Future<Directory> Function()? resolveCacheDirectory;

  @override
  Future<ImageProvider?> getThumbnail(String filePath) async {
    final cacheFile = await _cacheFileFor(filePath);
    if (cacheFile != null && await cacheFile.exists()) {
      return FileImage(cacheFile);
    }

    // 解帧 — 失败 (损坏文件/不支持的容器) 静默返回 null, 占位态由 UI 呈现.
    final Uint8List? bytes;
    try {
      bytes = await FlutterVideoThumbnailPlus.thumbnailData(
        video: filePath,
        imageFormat: ImageFormat.jpeg,
        maxWidth: _maxSize,
        maxHeight: _maxSize,
        timeMs: _timeMs,
        quality: 85,
      );
    } on Exception {
      return null;
    }
    if (bytes == null) return null;

    // 写磁盘缓存 — best-effort: 写失败仅退化为内存使用, 不阻断.
    if (cacheFile != null) {
      try {
        await cacheFile.create(recursive: true);
        await cacheFile.writeAsBytes(bytes);
      } on Exception {
        // 目录不可写 (MSIX 沙盒等) — 忽略.
      }
    }
    return MemoryImage(bytes);
  }

  /// 解析缓存文件路径 — 目录解析失败返回 null (跳过磁盘层).
  Future<File?> _cacheFileFor(String filePath) async {
    final resolve = resolveCacheDirectory;
    if (resolve == null) return null;
    try {
      final dir = await resolve();
      final key = md5.convert(utf8.encode(filePath)).toString();
      return File(p.join(dir.path, 'cache', 'thumbnails', '$key.jpg'));
    } on Exception {
      return null;
    }
  }
}
