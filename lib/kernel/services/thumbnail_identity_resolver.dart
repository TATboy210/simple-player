/// 缩略图 identity 解析器 — normalize → memo → stat → key (从 ThumbnailService 拆出).
///
/// Resolves a raw path to a [ThumbnailIdentity], memoizing so the memory hot
/// path performs zero disk I/O (P-Thumb v1.3.2 R5/I10).
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'thumbnail_identity.dart';
import 'thumbnail_metrics.dart';

/// identity 解析器 (持有 memo).
class ThumbnailIdentityResolver {
  /// [metrics] 仅在 debug 构建累加 (release 零开销).
  ThumbnailIdentityResolver({required this.metrics});

  /// debug 观测计数器 (statCalls / identityMemoHits).
  final ThumbnailMetrics metrics;

  /// identity memo — memory hot path 零 stat 的关键（R5/I10）。
  /// 失效契约：[evict] 删除对应条目；[clear] 清空全部；
  /// 文件被外部替换但未 evict → 显示旧图（与 v1.2 现状行为一致，
  /// 由 Coordinator 的 evict 调用契约覆盖 — §40.1）。
  final Map<String, ThumbnailIdentity> _memo = <String, ThumbnailIdentity>{};

  /// identity 解析 — normalize → memo → stat → canonical → SHA-256
  ///
  /// stat 失败或文件不存在返回 null（X3：stat 失败 → 不可信 identity，
  /// 绝不降级到 path-only 缓存）。memo 命中时零磁盘访问。
  Future<ThumbnailIdentity?> resolve(String rawPath) async {
    final path = p.normalize(rawPath);
    if (!p.isAbsolute(path)) return null;

    // R5：memo 命中 = 零 stat（memory hot path 的前提）
    final memo = _memo[path];
    if (memo != null) {
      if (kDebugMode) metrics.identityMemoHits++;
      return memo;
    }

    try {
      if (kDebugMode) metrics.statCalls++;
      final stat = await File(path).stat();
      if (stat.type == FileSystemEntityType.notFound) return null;

      final identity = buildThumbnailIdentity(
        path,
        stat.size,
        stat.modified.millisecondsSinceEpoch,
      );
      _memo[path] = identity;
      return identity;
    } on FileSystemException {
      return null;
    }
  }

  /// 失效 [normalizedPath] 的 memo — 文件替换后 identity 能刷新的唯一通道 (R5).
  void evict(String normalizedPath) => _memo.remove(normalizedPath);

  /// 清空全部 memo.
  void clear() => _memo.clear();
}
