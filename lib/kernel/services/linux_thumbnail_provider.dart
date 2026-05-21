import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/painting.dart';

import 'thumbnail_provider.dart';

/// Linux 缩略图提供者 — XDG Thumbnail Factory
///
/// 检查 `~/.cache/thumbnails/{size}/{md5(uri)}.png` 缓存目录。
/// 大多数 Linux 文件管理器（Nautilus、Thunar、Dolphin）会自动生成缩略图。
/// 缓存未命中时返回 null（facade 层显示文件图标）。
class LinuxThumbnailProvider implements ThumbnailProvider {
  const LinuxThumbnailProvider();

  /// XDG 缩略图尺寸，按优先级排序
  static const _thumbnailSizes = ['x-large', 'large', 'normal'];

  @override
  Future<ImageProvider?> getThumbnail(String filePath) async {
    try {
      final home = Platform.environment['HOME'];
      if (home == null) return null;

      final uri = Uri.file(filePath).toString();
      final hash = md5.convert(uri.codeUnits).toString();

      for (final size in _thumbnailSizes) {
        final thumbPath = '$home/.cache/thumbnails/$size/$hash.png';
        final file = File(thumbPath);
        if (await file.exists()) {
          return FileImage(file);
        }
      }
    } on Exception {
      // 缓存读取失败，降级为 null
    }
    return null;
  }
}
