import 'package:flutter/painting.dart';

import 'thumbnail_provider.dart';

/// macOS 缩略图提供者 — 降级为文件图标。
///
/// TODO: 实现 QLThumbnailGenerator Objective-C FFI 提取真实缩略图。
class MacosThumbnailProvider implements ThumbnailProvider {
  const MacosThumbnailProvider();

  @override
  Future<ImageProvider?> getThumbnail(String filePath) async => null;
}
