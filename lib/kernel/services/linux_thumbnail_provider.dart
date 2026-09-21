import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show Uint8List;

import 'thumbnail_provider.dart';

/// Linux 缩略图提供者 — XDG Thumbnail Factory（P-Thumb v1.3.2 bytes 契约）
///
/// 检查 `~/.cache/thumbnails/{size}/{md5(uri)}.png` 缓存目录。
/// 大多数 Linux 文件管理器（Nautilus、Thunar、Dolphin）会自动生成缩略图。
/// 缓存未命中时返回 null（facade 层显示文件图标）。
///
/// v1.3.2（B2）：返回 PNG bytes 而非 FileImage — 磁盘缓存策略归 Service 层。
/// 注意 XDG 侧是 PNG 编码，Service 层磁盘缓存的 JPEG 校验只针对自身落盘
/// 文件（XDG bytes 不经 Service 磁盘缓存直写路径时由调用方处理）。
class LinuxThumbnailProvider implements ThumbnailProvider {
  const LinuxThumbnailProvider();

  /// XDG 缩略图尺寸，按优先级排序
  static const _thumbnailSizes = ['x-large', 'large', 'normal'];

  @override
  Future<Uint8List?> generateThumbnail(String filePath) async {
    try {
      final home = Platform.environment['HOME'];
      if (home == null) return null;

      final uri = Uri.file(filePath).toString();
      final hash = md5.convert(uri.codeUnits).toString();

      for (final size in _thumbnailSizes) {
        final file = File('$home/.cache/thumbnails/$size/$hash.png');
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      }
    } on Exception {
      // 缓存读取失败，降级为 null
    }
    return null;
  }
}
