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

  /// 内部实例 — 持有缓存状态，消除 static mutable state
  static final ThumbnailService _instance = ThumbnailService._();

  ThumbnailProvider? _impl;

  /// LRU 缓存 — LinkedHashMap 维护插入顺序，访问时 remove+reinsert 移到末尾
  final _cache = <String, ImageProvider>{};

  ThumbnailProvider get _providerImpl {
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
  static Future<ImageProvider?> getThumbnail(String filePath) =>
      _instance._getThumbnailImpl(filePath);

  Future<ImageProvider?> _getThumbnailImpl(String filePath) async {
    // 命中路径优化：remove 返回非 null 即命中，reinsert 实现 LRU touch。
    // 原路径 containsKey + _touchImpl(remove+reinsert) + _cache[read] = 4 次 map；
    // 优化后 remove + reinsert = 2 次，且 remove 的返回值直接复用，省去再读。
    final cached = _cache.remove(filePath);
    if (cached != null) {
      _cache[filePath] = cached; // reinsert → 移到末尾（最近访问）
      return cached;
    }

    final provider = await _providerImpl.getThumbnail(filePath);
    if (provider != null) {
      _cache[filePath] = provider;
      _evictIfNeededImpl();
    }
    return provider;
  }

  /// 移除单个缓存条目。
  static void evict(String filePath) => _instance._cache.remove(filePath);

  /// 清空全部缓存。
  static void clearCache() => _instance._cache.clear();

  /// 重置全部状态（仅供测试使用）。
  @visibleForTesting
  static void reset() {
    _instance._impl = null;
    _instance._cache.clear();
  }

  /// 手动触发 LRU 触摸（仅供测试使用）。
  @visibleForTesting
  static void touch(String filePath) => _instance._touchImpl(filePath);

  /// 缓存条目数量（仅供测试使用）。
  @visibleForTesting
  static int get cacheLength => _instance._cache.length;

  /// 缓存键的迭代顺序（仅供测试使用，oldest-first）。
  @visibleForTesting
  static Iterable<String> get cacheKeys => _instance._cache.keys;

  /// 命中时移到末尾（最近访问）— O(1) remove + reinsert
  void _touchImpl(String filePath) {
    final value = _cache.remove(filePath);
    if (value != null) _cache[filePath] = value;
  }

  /// 超出容量时淘汰最久未访问的条目（迭代器首位）— O(1)
  void _evictIfNeededImpl() {
    while (_cache.length > _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
  }
}
