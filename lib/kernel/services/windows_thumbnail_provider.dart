import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;

import 'thumbnail_provider.dart';

/// Windows 缩略图 Provider — fc_native_video_thumbnail 原生生成 + 磁盘缓存.
///
/// Windows thumbnail provider — native generation via
/// [FcNativeVideoThumbnail] (Windows Shell thumbnail API, 与资源管理器同款)
/// with a on-disk JPEG cache to survive app restarts.
///
/// 缓存布局: `<appSupport>/cache/thumbnails/<md5(path)>.jpg` —
/// md5(path) 为键与 Linux XDG provider 同风格; 生成一次永久复用,
/// 不随源文件变化失效 (视频首帧基本恒定, 断点进度条另由 UI 层表达).
class WindowsThumbnailProvider implements ThumbnailProvider {
  /// [resolveCacheDirectory] 可注入以便测试 (production 用 path_provider).
  const WindowsThumbnailProvider({this.resolveCacheDirectory});

  /// 缩略图最长边 — 列表卡片 16:9 显示足够, 生成开销最小化.
  static const _maxSize = 320;

  /// 磁盘缓存目录解析 — 可注入以便测试 (production 用 path_provider).
  final Future<Directory> Function()? resolveCacheDirectory;

  @override
  Future<ImageProvider?> getThumbnail(String filePath) async {
    final cacheFile = await _cacheFileFor(filePath);
    if (cacheFile != null && await cacheFile.exists()) {
      return FileImage(cacheFile);
    }

    // 原生生成 — Windows 槽位仅支持本地 Path 且不支持 seeking
    // (Shell thumbnail 语义 = 默认代表帧, 与资源管理器一致).
    final Uint8List? bytes;
    try {
      bytes = await FcNativeVideoThumbnail().saveThumbnailToBytes(
        srcFile: filePath,
        width: _maxSize,
        height: _maxSize,
        format: 'jpeg',
        quality: 85,
      );
    } on Exception {
      return null; // 生成失败 (损坏文件/不支持容器) — 占位态由 UI 呈现
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
