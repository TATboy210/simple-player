/// 缩略图内存缓存 — LRU + path 双向索引 + negative memo (从 ThumbnailService 拆出).
///
/// In-memory state of the thumbnail pipeline: the LRU of decoded providers
/// with its path<->key reverse indexes, and the TTL'd negative memo.
library;

import 'package:flutter/painting.dart';

/// 内存 LRU — 键为 cacheKey（非 path — 同一 path 可随文件变化产生多个 identity）.
///
/// LinkedHashMap 维护插入顺序, 访问时 remove+reinsert 移到末尾 (O(1)).
/// 同时维护 path → keys 与 key → path 双向索引, 使 [evictPath] 为
/// O(keys-of-path) 且 LRU 淘汰时索引不漏清.
class ThumbnailMemoryCache {
  /// [maxSize] 为 LRU 容量上限.
  ThumbnailMemoryCache({required this.maxSize});

  /// LRU 容量上限.
  final int maxSize;

  final Map<String, ImageProvider> _cache = <String, ImageProvider>{};

  /// path → 该 path 历史产生过的全部 cacheKey（多版本共存：A.mp4/v1、/v2）
  final Map<String, Set<String>> _keysByPath = <String, Set<String>>{};

  /// cacheKey → path 反查 — LRU 淘汰时同步维护反向索引
  final Map<String, String> _pathByKey = <String, String>{};

  /// 当前条目数.
  int get length => _cache.length;

  /// 缓存键迭代顺序 (oldest-first).
  Iterable<String> get keys => _cache.keys;

  /// 取并 LRU touch — remove 返回非 null 即命中, reinsert 移到末尾 (O(1)).
  ImageProvider? get(String key) {
    final cached = _cache.remove(key);
    if (cached != null) _cache[key] = cached;
    return cached;
  }

  /// 仅 LRU touch (不存在则 no-op).
  void touch(String key) => get(key);

  /// 写入 + 双向索引维护 + 容量溢出淘汰 (淘汰最久未访问的迭代器首位).
  void put(String path, String key, ImageProvider provider) {
    _cache[key] = provider;
    _keysByPath.putIfAbsent(path, () => <String>{}).add(key);
    _pathByKey[key] = path;
    while (_cache.length > maxSize) {
      final oldest = _cache.keys.first;
      _cache.remove(oldest);
      _unindex(oldest);
    }
  }

  void _unindex(String key) {
    final path = _pathByKey.remove(key);
    if (path == null) return;
    final keys = _keysByPath[path];
    if (keys == null) return;
    keys.remove(key);
    if (keys.isEmpty) _keysByPath.remove(path);
  }

  /// 移除单个 path 的全部缓存条目.
  void evictPath(String path) {
    final keys = _keysByPath.remove(path);
    if (keys == null) return;
    for (final key in keys) {
      _cache.remove(key);
      _pathByKey.remove(key);
    }
  }

  /// 清空全部条目与索引.
  void clear() {
    _cache.clear();
    _keysByPath.clear();
    _pathByKey.clear();
  }
}

/// negative memo — cacheKey → 失败屏蔽截止时刻（§21.2, TTL 10s）.
///
/// 只防 Tile 反复重建导致的重复解帧, 不写磁盘; retry 显式清除 (§21.3).
/// path → key 反向索引使 evict 为 O(keys-of-path) (M6), 杜绝 v1.3.1 A.9
/// startsWith prefix collision.
class ThumbnailFailureMemo {
  /// [ttl] 为屏蔽时长; [now] 可注入时钟 (测试用, 默认真实时钟).
  ThumbnailFailureMemo({required this.ttl, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// 屏蔽时长.
  final Duration ttl;
  final DateTime Function() _now;

  final Map<String, DateTime> _failedUntil = <String, DateTime>{};
  final Map<String, Set<String>> _keysByPath = <String, Set<String>>{};

  /// [key] 当前是否仍在屏蔽期内.
  ///
  /// Side effect: TTL 已过的条目在此回收 (含反向索引), 之后返回 false.
  bool isBlocked(String path, String key) {
    final until = _failedUntil[key];
    if (until == null) return false;
    if (_now().isBefore(until)) return true;
    _failedUntil.remove(key);
    _keysByPath[path]?.remove(key);
    return false;
  }

  /// 记一次失败, 屏蔽 [ttl].
  void record(String path, String key) {
    _failedUntil[key] = _now().add(ttl);
    _keysByPath.putIfAbsent(path, () => <String>{}).add(key);
  }

  /// 清除某 path 的全部失败记录 (evict/retry 用).
  void evictPath(String path) {
    final keys = _keysByPath.remove(path);
    if (keys == null) return;
    for (final key in keys) {
      _failedUntil.remove(key);
    }
  }

  /// 清空全部记录.
  void clear() {
    _failedUntil.clear();
    _keysByPath.clear();
  }
}
