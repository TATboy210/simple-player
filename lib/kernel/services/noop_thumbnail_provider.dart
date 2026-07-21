import 'package:flutter/painting.dart';

import 'thumbnail_provider.dart';

/// 空实现 — 不支持缩略图的平台返回 null。
///
/// No-op thumbnail provider for platforms that lack thumbnail support.
///
/// Always returns `null` from [getThumbnail], serving as a safe fallback
/// when native thumbnail generation is unavailable.
class NoopThumbnailProvider implements ThumbnailProvider {
  const NoopThumbnailProvider();

  @override
  Future<ImageProvider?> getThumbnail(String filePath) async => null;
}
