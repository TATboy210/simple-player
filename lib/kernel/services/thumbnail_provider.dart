import 'package:flutter/painting.dart';

/// 缩略图提供者抽象接口 — 平台无关
///
/// Platform-specific implementations extract system thumbnails from local
/// files. Caching is handled by [ThumbnailService]; providers are stateless.
///
/// Implementations:
/// - [NoopThumbnailProvider] (Windows fallback)
/// - [LinuxThumbnailProvider]
/// - [MacosThumbnailProvider]
abstract interface class ThumbnailProvider {
  /// 获取文件的系统缩略图，失败时返回 null
  ///
  /// - [filePath] must be an absolute local path.
  /// - Returns an [ImageProvider] on success, `null` on failure or
  ///   unsupported format.
  Future<ImageProvider?> getThumbnail(String filePath);
}
