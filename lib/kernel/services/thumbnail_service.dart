import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'linux_thumbnail_provider.dart';
import 'macos_thumbnail_provider.dart';
import 'noop_thumbnail_provider.dart';
import 'thumbnail_provider.dart';

/// 平台感知的缩略图服务门面。
///
/// 根据 [defaultTargetPlatform] 惰性选择平台实现，
/// 统一管理 LRU 内存缓存。消费者无需感知底层平台差异。
class ThumbnailService {
  ThumbnailService._();

  static const _maxCacheSize = 200;

  static ThumbnailProvider? _impl;

  /// LRU 缓存 — Map 维护数据，List 维护访问顺序（最近访问在末尾）
  static final _cache = <String, ImageProvider>{};
  static final _order = <String>[]; // 末尾 = 最近访问

  static ThumbnailProvider get _provider {
    if (_impl != null) return _impl!;
    _impl = switch (defaultTargetPlatform) {
      TargetPlatform.windows => const NoopThumbnailProvider(),
      TargetPlatform.linux => const LinuxThumbnailProvider(),
      TargetPlatform.macOS => const MacosThumbnailProvider(),
      _ => const NoopThumbnailProvider(),
    };
    return _impl!;
  }

  /// 获取文件的系统缩略图，带 LRU 内存缓存。
  static Future<ImageProvider?> getThumbnail(String filePath) async {
    if (_cache.containsKey(filePath)) {
      _touch(filePath);
      return _cache[filePath];
    }

    final provider = await _provider.getThumbnail(filePath);
    if (provider != null) {
      _cache[filePath] = provider;
      _order.add(filePath);
      _evictIfNeeded();
    }
    return provider;
  }

  /// 移除单个缓存条目。
  static void evict(String filePath) {
    _cache.remove(filePath);
    _order.remove(filePath);
  }

  /// 清空全部缓存。
  static void clearCache() {
    _cache.clear();
    _order.clear();
  }

  /// 命中时移到末尾（最近访问）
  static void _touch(String filePath) {
    _order.remove(filePath);
    _order.add(filePath);
  }

  /// 超出容量时淘汰最久未访问的条目（列表头部）
  static void _evictIfNeeded() {
    while (_cache.length > _maxCacheSize) {
      final oldest = _order.removeAt(0);
      _cache.remove(oldest);
    }
  }
}
