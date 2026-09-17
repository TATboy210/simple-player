import 'package:flutter/painting.dart';

import 'thumbnail_provider.dart';

/// macOS 缩略图提供者 — 降级为文件图标。
///
/// 待实现: QLThumbnailGenerator Objective-C FFI 提取真实缩略图 (macOS 为结构支持平台, 未排期).
class MacosThumbnailProvider implements ThumbnailProvider {
  const MacosThumbnailProvider();

  @override
  Future<ImageProvider?> getThumbnail(String filePath) async => null;
}
