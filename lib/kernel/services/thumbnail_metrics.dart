/// 缩略图 debug 观测计数器 (从 ThumbnailService 拆出).
///
/// Debug-only counters for the thumbnail pipeline (P-Thumb v1.3.2 §32).
library;

/// debug-only 观测计数器（P-Thumb v1.3.2 §32 — release 零开销）
///
/// Debug metrics: every increment is kDebugMode-gated at call sites, so
/// release builds neither count nor allocate. Never log per-thumbnail
/// request paths here (§32.3 — 噪音反而制造性能问题).
final class ThumbnailMetrics {
  /// getThumbnail 请求总数.
  int requests = 0;

  /// 内存 LRU 命中数.
  int memoryHits = 0;

  /// 磁盘缓存命中数.
  int diskHits = 0;

  /// provider 实际调用次数.
  int providerCalls = 0;

  /// 解帧失败数.
  int failures = 0;

  /// in-flight join 合并的请求数（F1/F2 生效度）
  int coalescedJoins = 0;

  /// 磁盘写失败降级 MemoryImage 的次数（R6 disk 域观察）
  int diskWriteFallbacks = 0;

  /// provider 并发峰值（G1 — gate 生效度观测）
  int peakConcurrent = 0;

  /// identity 解析触发的 File.stat 次数 — ID7 用：memo 生效则第二次请求不再增长
  int statCalls = 0;

  /// identity memo 命中次数
  int identityMemoHits = 0;

  /// 全部归零 (ThumbnailService.reset 用).
  void reset() {
    requests = 0;
    memoryHits = 0;
    diskHits = 0;
    providerCalls = 0;
    failures = 0;
    coalescedJoins = 0;
    diskWriteFallbacks = 0;
    peakConcurrent = 0;
    statCalls = 0;
    identityMemoHits = 0;
  }
}
