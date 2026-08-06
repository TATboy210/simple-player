import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'linux_thumbnail_provider.dart';
import 'macos_thumbnail_provider.dart';
import 'noop_thumbnail_provider.dart';
import 'thumbnail_provider.dart';

/// 平台感知的缩略图服务门面
///
/// Facade that lazily selects a platform-specific [ThumbnailProvider] based
/// on [defaultTargetPlatform] and manages an LRU in-memory cache.
///
/// Invariants:
/// - Cache capacity is bounded at [_maxCacheSize] (200 entries).
/// - All public methods are static — consumers call [ThumbnailService.xxx] directly.
/// - Thread-safety is not guaranteed; called from the UI isolate only.
class ThumbnailService {
  ThumbnailService._();

  static const _maxCacheSize = 200;

  /// 内部实例 — 持有缓存状态，消除 static mutable state
  static final ThumbnailService _instance = ThumbnailService._();

  ThumbnailProvider? _impl;

  /// LRU 缓存 — LinkedHashMap 维护插入顺序，访问时 remove+reinsert 移到末尾
  final _cache = <String, ImageProvider>{};

  ThumbnailProvider get _providerImpl {
    // 字段不提升, 用 local 捕获消除 `!` (existing 命中 / created 新建各一)
    final existing = _impl;
    if (existing != null) return existing;
    final created = switch (defaultTargetPlatform) {
      TargetPlatform.windows => const NoopThumbnailProvider(),
      TargetPlatform.linux => const LinuxThumbnailProvider(),
      TargetPlatform.macOS => const MacosThumbnailProvider(),
      _ => const NoopThumbnailProvider(),
    };
    _impl = created;
    return created;
  }

  /// 获取文件的系统缩略图，带 LRU 内存缓存
  ///
  /// Returns a cached [ImageProvider] or fetches a new one from the
  /// platform [ThumbnailProvider].
  ///
  /// - [filePath] must be an absolute local file path.
  /// - Returns `null` when the platform cannot generate a thumbnail.
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

  /// 移除单个缓存条目
  ///
  /// Removes [filePath] from the LRU cache. No-op if not present.
  static void evict(String filePath) => _instance._cache.remove(filePath);

  /// 清空全部缓存
  ///
  /// Drops all cached thumbnails. Useful when the playlist is replaced.
  static void clearCache() => _instance._cache.clear();

  /// 重置全部状态（仅供测试使用）
  ///
  /// Clears cache and resets the platform provider so it will be
  /// re-selected on the next access.
  @visibleForTesting
  static void reset() {
    _instance._impl = null;
    _instance._cache.clear();
  }

  /// 手动触发 LRU 触摸（仅供测试使用）
  ///
  /// Moves [filePath] to the most-recently-used position without
  /// fetching a new thumbnail. No-op if not cached.
  @visibleForTesting
  static void touch(String filePath) => _instance._touchImpl(filePath);

  /// 缓存条目数量（仅供测试使用）
  ///
  /// Returns the current number of cached entries (0 .. [_maxCacheSize]).
  @visibleForTesting
  static int get cacheLength => _instance._cache.length;

  /// 缓存键的迭代顺序（仅供测试使用，oldest-first）
  ///
  /// Returns cache keys in insertion order (oldest first). Useful for
  /// verifying LRU eviction behavior in tests.
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
