import 'package:flutter/foundation.dart';

/// 缩略图提供者抽象接口 — 平台无关（P-Thumb v1.3.2 §23 bytes 契约）
///
/// Platform-specific implementations extract native frame bytes from local
/// files. Providers are stateless: no caching, no retry, no LRU — all cache
/// policy lives in [ThumbnailService] (I7), persistent storage in
/// ThumbnailDiskCache.
///
/// Implementations:
/// - [NoopThumbnailProvider] (fallback)
/// - [LinuxThumbnailProvider]
/// - [MacosThumbnailProvider]
/// - [WindowsThumbnailProvider]
abstract interface class ThumbnailProvider {
  /// 生成原生缩略图帧 — 成功返回 JPEG bytes，失败返回 null
  ///
  /// - [filePath] must be an absolute local path.
  /// - Returns JPEG-encoded bytes, or `null` on failure / unsupported
  ///   format. Implementations must never throw past `on Exception` —
  ///   native decode failures are data problems, not crashes (§24.4).
  Future<Uint8List?> generateThumbnail(String filePath);
}
