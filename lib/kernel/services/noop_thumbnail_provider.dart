import 'package:flutter/foundation.dart' show Uint8List;

import 'thumbnail_provider.dart';

/// 空实现 — 不支持缩略图的平台返回 null。
///
/// No-op thumbnail provider for platforms that lack thumbnail support.
///
/// Always returns `null` from [generateThumbnail], serving as a safe
/// fallback when native thumbnail generation is unavailable.
class NoopThumbnailProvider implements ThumbnailProvider {
  const NoopThumbnailProvider();

  @override
  Future<Uint8List?> generateThumbnail(String filePath) async => null;
}
