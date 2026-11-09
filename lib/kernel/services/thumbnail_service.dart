import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;

import 'linux_thumbnail_provider.dart';
import 'macos_thumbnail_provider.dart';
import 'noop_thumbnail_provider.dart';
import 'thumbnail_concurrency_gate.dart';
import 'thumbnail_disk_cache.dart';
import 'thumbnail_flight_registry.dart';
import 'thumbnail_identity.dart';
import 'thumbnail_identity_resolver.dart';
import 'thumbnail_identity.dart' as thumbnail_identity;
import 'thumbnail_memory_cache.dart';
import 'thumbnail_metrics.dart';
import 'thumbnail_provider.dart';
import 'windows_thumbnail_provider.dart';

// 公开 API 不变: ThumbnailMetrics 经 ThumbnailService.metrics 对外, 类型随本库导出.
export 'thumbnail_metrics.dart' show ThumbnailMetrics;

/// 平台感知的缩略图服务门面 — P-Thumb v1.3.2
///
/// Facade that lazily selects a platform-specific [ThumbnailProvider] based
/// on [defaultTargetPlatform] and orchestrates caching.
///
/// Invariants (P-Thumb v1.3.2):
/// - Cache identity = `(normalized path, size, mtime, spec)` 的 SHA-256，
///   绝不用裸 path 当 key（X1/X5）。
/// - Memory LRU 以 cacheKey 为键，容量上限 [_maxCacheSize]。
/// - identity memo：path → identity 解析缓存，memory hit 全程零磁盘 I/O
///   (I10)；`evict(path)` 必须同步删除 memo 条目 (R5)。
/// - All public methods are static — consumers call [ThumbnailService.xxx] directly.
/// - Thread-safety is not guaranteed; called from the UI isolate only.
class ThumbnailService {
  ThumbnailService._();

  /// LRU 容量 — 远大于典型可见区，万级媒体库内存驻留不是本架构目标
  /// (v0.0.9 内存治理: 200→120, 单张 decoded ~144KiB, 120 张 ≈ 17MB)
  static const _maxCacheSize = 120;

  /// provider 并发上限（§20.1）— 两个并发提升吞吐又不无限堆 native decoder
  static const maxConcurrent = 2;

  /// negative memo TTL（§21.1）— 只防 Tile 反复重建导致的重复解帧，
  /// 不写磁盘；retry 显式清除（§21.3）
  static const _negativeTtl = Duration(seconds: 10);

  /// 内部实例 — 持有缓存状态，消除 static mutable state
  static final ThumbnailService _instance = ThumbnailService._();

  /// debug metrics — 单例生命周期内累计，reset() 归零
  static final ThumbnailMetrics _metrics = ThumbnailMetrics();

  /// 默认磁盘缓存 — production 构造（resolveDirectory 默认走 appCache）
  static final ThumbnailDiskCache _defaultDiskCache = ThumbnailDiskCache();

  /// 测试注入的磁盘缓存（M3）— reset() 时替换
  ThumbnailDiskCache? _diskCacheOverride;

  ThumbnailDiskCache get _diskCache => _diskCacheOverride ?? _defaultDiskCache;

  /// 内存 LRU + 双向索引 (见 [ThumbnailMemoryCache]).
  final ThumbnailMemoryCache _cache = ThumbnailMemoryCache(
    maxSize: _maxCacheSize,
  );

  /// identity 解析 + memo (见 [ThumbnailIdentityResolver]).
  final ThumbnailIdentityResolver _identities = ThumbnailIdentityResolver(
    metrics: _metrics,
  );

  /// negative memo (见 [ThumbnailFailureMemo]) — TTL 10s, 不写磁盘.
  final ThumbnailFailureMemo _failures = ThumbnailFailureMemo(
    ttl: _negativeTtl,
  );

  /// in-flight 注册表 + epoch 内核（B3）— join/失效/isCurrent 唯一入口
  final ThumbnailFlightRegistry _registry = ThumbnailFlightRegistry();

  /// 并发闸（B4 — §20）— 只包 Provider generation，gate 外零昂贵步骤
  final ThumbnailConcurrencyGate _gate = ThumbnailConcurrencyGate(
    maxConcurrent,
  );

  /// gate 内当前活跃 provider 数（峰值观测）
  int _activeProviderCount = 0;

  /// debug metrics 访问器（测试观测用）
  @visibleForTesting
  static ThumbnailMetrics get metrics => _metrics;

  ThumbnailProvider? _impl;

  ThumbnailProvider get _providerImpl {
    // 字段不提升, 用 local 捕获消除 `!` (existing 命中 / created 新建各一)
    final existing = _impl;
    if (existing != null) return existing;
    final created = switch (defaultTargetPlatform) {
      // v0.0.5: Windows 从 Noop 升级为原生缩略图解帧.
      // v1.3.2 (B2): Provider 只出 bytes — 磁盘缓存归 [_diskCache]（I7）。
      TargetPlatform.windows => const WindowsThumbnailProvider(),
      TargetPlatform.linux => const LinuxThumbnailProvider(),
      TargetPlatform.macOS => const MacosThumbnailProvider(),
      _ => const NoopThumbnailProvider(),
    };
    _impl = created;
    return created;
  }

  /// 获取文件的系统缩略图，带 identity 缓存与 LRU 内存缓存
  ///
  /// Returns a cached [ImageProvider] or fetches a new one from the
  /// platform [ThumbnailProvider].
  ///
  /// - [filePath] must be an absolute local file path.
  /// - Returns `null` when the platform cannot generate a thumbnail
  ///   or the file cannot be stat-ed (不可信 identity — X3).
  static Future<ImageProvider?> getThumbnail(String filePath) =>
      _instance._getThumbnailImpl(filePath);

  Future<ImageProvider?> _getThumbnailImpl(String filePath) async {
    if (kDebugMode) _metrics.requests++;

    // identity 解析（memo 命中 = 零磁盘 I/O — I10）
    final identity = await _identities.resolve(filePath);
    if (identity == null) return null;

    final key = identity.cacheKey;

    // LRU 命中 — remove 返回非 null 即命中，reinsert 实现 LRU touch（O(1)）
    final cached = _cache.get(key);
    if (cached != null) {
      if (kDebugMode) _metrics.memoryHits++;
      return cached;
    }

    // negative memo 命中 — TTL 内直接失败，挡住坏文件的重复解帧（§21）;
    // TTL 已过则回收后走正常流程
    if (_failures.isBlocked(identity.path, key)) return null;

    // 磁盘命中（第二优先级 — 零 native decode，§28.3）
    final diskProvider = await _diskCache.read(key);
    if (diskProvider != null) {
      if (kDebugMode) _metrics.diskHits++;
      _cachePutImpl(identity.path, key, diskProvider);
      return diskProvider;
    }

    // in-flight join 或新 flight（B3 — §18）
    return _getFlightImpl(identity, forceRefresh: false);
  }

  /// flight 注册与 join（A.5 — H5 force join + M5 收敛）
  ///
  /// - normal 请求：existing 存在即 join（F1/F2 — provider 只执行一次）
  /// - force 请求：只 join 已有的 force flight（H5 — 双击 retry 不重复解帧）；
  ///   forceRefresh 仅由 [retry] 内部传入（M5，B5 接入），
  ///   retry 已先 evict → 旧 normal flight 必然 stale，覆盖注册表键安全。
  Future<ImageProvider?> _getFlightImpl(
    ThumbnailIdentity identity, {
    required bool forceRefresh,
  }) {
    final key = identity.cacheKey;
    final existing = _registry.forKey(key);

    if (existing != null && (!forceRefresh || existing.isForce)) {
      if (kDebugMode) _metrics.coalescedJoins++;
      return existing.future;
    }

    final flight = _registry.create(
      path: identity.path,
      cacheKey: key,
      isForce: forceRefresh,
    );
    _registry.register(flight);

    // fire-and-forget — flight 自己经 completer 交付结果，
    // 异常域全包在 _runFlight 内不会逃逸（R6）
    unawaited(_runFlight(flight, identity, forceRefresh: forceRefresh));
    return flight.future;
  }

  /// flight 执行体（A.6 — R6 三层异常域 + R7 紧贴 commit + M2）
  Future<void> _runFlight(
    ThumbnailFlight flight,
    ThumbnailIdentity identity, {
    required bool forceRefresh,
  }) async {
    try {
      final bytes = await _generateBytes(flight, identity);
      if (bytes == null) {
        flight.complete(null);
        return;
      }
      flight.complete(
        await _commitOrFallback(
          flight,
          identity,
          bytes,
          forceRefresh: forceRefresh,
        ),
      );
    } finally {
      _registry.remove(flight);
    }
  }

  /// Provider 域 — 失败 = negative cache 语义（仅 current，M2/21.5）.
  ///
  /// 返回 null 表示生成失败 (异常 / 空 bytes), 已按 current 判定记入
  /// negative memo; 不捕获 Error — 编程 bug 必须暴露给 zone（I11）.
  Future<Uint8List?> _generateBytes(
    ThumbnailFlight flight,
    ThumbnailIdentity identity,
  ) async {
    Uint8List? bytes;
    try {
      bytes = await _gate.run(() => _callProvider(identity.path));
    } on Exception {
      bytes = null;
    }
    if (bytes != null && bytes.isNotEmpty) return bytes;
    if (kDebugMode) _metrics.failures++;
    _recordFailureIfCurrent(flight, identity);
    return null;
  }

  /// gate 内的 provider 调用 — 峰值观测在 gate 内, 排队中的请求未真正
  /// 占用解帧资源.
  Future<Uint8List?> _callProvider(String path) async {
    if (kDebugMode) {
      _metrics.providerCalls++;
      _activeProviderCount++;
      if (_activeProviderCount > _metrics.peakConcurrent) {
        _metrics.peakConcurrent = _activeProviderCount;
      }
    }
    try {
      return await _providerImpl.generateThumbnail(path);
    } finally {
      if (kDebugMode) _activeProviderCount--;
    }
  }

  /// Disk/commit 域 — 失败 = 降级 MemoryImage，不进 negative cache.
  ///
  /// 返回交付给 flight 的 provider: stale flight 无 commit 权 (检查点 1,
  /// §19.7) 仅返回原请求的 MemoryImage; 写盘异常降级 MemoryImage (D7: 写失败
  /// ≠ 生成失败, Error 不捕获); force 请求即时展示新 bytes (R2) — 旧
  /// decoded FileImage 已在 [_commitToCache] 内 evict, 下次滚动从新磁盘
  /// 文件重新 decode (§22.3).
  Future<ImageProvider> _commitOrFallback(
    ThumbnailFlight flight,
    ThumbnailIdentity identity,
    Uint8List bytes, {
    required bool forceRefresh,
  }) async {
    if (!_registry.isCurrent(flight)) return MemoryImage(bytes);
    ImageProvider? committed;
    try {
      committed = await _commitToCache(
        flight,
        identity,
        bytes,
        forceRefresh: forceRefresh,
      );
    } on Exception {
      return MemoryImage(bytes);
    }
    if (forceRefresh) return MemoryImage(bytes);
    return committed ?? MemoryImage(bytes);
  }

  /// negative memo 记录（§21.2）— M2/21.5：stale flight 的失败不记 memo，
  /// 否则文件替换恢复后的新请求会被旧代的失败挡住 10 秒
  void _recordFailureIfCurrent(
    ThumbnailFlight flight,
    ThumbnailIdentity identity,
  ) {
    if (!_registry.isCurrent(flight)) return;
    _failures.record(identity.path, identity.cacheKey);
  }

  /// commit 阶段 — 内含检查点 2（R7/H1：紧贴 _cachePut，§19.8）
  Future<ImageProvider?> _commitToCache(
    ThumbnailFlight flight,
    ThumbnailIdentity identity,
    Uint8List bytes, {
    required bool forceRefresh,
  }) async {
    if (forceRefresh) {
      // 22.3：覆写同名 cache file 前清 Flutter ImageCache 旧条目（X6）
      final oldFile = await _diskCache.fileFor(identity.cacheKey);
      if (oldFile != null) {
        await FileImage(oldFile).evict();
      }
    }

    final committedFile = await _diskCache.write(
      identity.cacheKey,
      bytes,
      replaceExisting: forceRefresh,
    );

    if (committedFile == null) {
      if (kDebugMode) _metrics.diskWriteFallbacks++;
      return null; // 磁盘失败 → caller 降级 MemoryImage（不记 memo）
    }

    // 检查点 2（R7/H1）：write 是 await 窗口，期间 clearCache()/evict()
    // 可能已穿过检查点 1 — commit 权在最后一刻确认
    if (!_registry.isCurrent(flight)) {
      return null;
    }

    final provider = FileImage(committedFile);
    _cachePutImpl(identity.path, identity.cacheKey, provider);
    return provider;
  }

  /// canonical 身份串 — 委托 [buildCanonicalString] (保留公开入口).
  @visibleForTesting
  static String buildCanonicalString({
    required String schemaVersion,
    required String path,
    required int size,
    required int modifiedMs,
    int maxWidth = ThumbnailSpec.maxWidth,
    int maxHeight = ThumbnailSpec.maxHeight,
    int timeMs = ThumbnailSpec.timeMs,
    String format = 'jpeg',
    int quality = ThumbnailSpec.jpegQuality,
  }) => thumbnail_identity.buildCanonicalString(
    schemaVersion: schemaVersion,
    path: path,
    size: size,
    modifiedMs: modifiedMs,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    timeMs: timeMs,
    format: format,
    quality: quality,
  );

  /// canonical → cacheKey (SHA-256 hex) — 委托 [cacheKeyFromCanonical].
  @visibleForTesting
  static String cacheKeyFromCanonical(String canonical) =>
      thumbnail_identity.cacheKeyFromCanonical(canonical);

  /// LRU 写入 + 双向索引维护 + 容量溢出淘汰 (委托 [ThumbnailMemoryCache.put]).
  void _cachePutImpl(String path, String key, ImageProvider provider) =>
      _cache.put(path, key, provider);

  /// 移除单个 path 的全部缓存条目（v1.3.2 A.9 — B1 子集）
  ///
  /// 同时失效 identity memo（R5 契约）— 下次请求重新 stat，
  /// 文件替换场景由此刷新 identity。
  static void evict(String filePath) => _instance._evictImpl(filePath);

  void _evictImpl(String rawPath) {
    final path = p.normalize(rawPath);

    // R5：memo 同步失效 — 这是文件替换后 identity 能刷新的唯一通道
    _identities.evict(path);

    // B3：pathEpoch++ + 该 path 全部在飞 flight 出 join 表（A.9）
    _registry.evictPath(path);

    _cache.evictPath(path);

    // B5：negative memo 反向索引清理（A.9 — O(keys-of-path)，无 prefix 碰撞）
    _failures.evictPath(path);
  }

  /// 清空全部缓存
  ///
  /// Drops all cached thumbnails. Useful when the playlist is replaced.
  /// 只清 P-Thumb 自己的状态，绝不动 Flutter 全局 imageCache（R3）。
  static void clearCache() => _instance._clearCacheImpl();

  void _clearCacheImpl() {
    // B3：globalEpoch++ O(1) 失效全部 flight（A.10）
    _registry.clear();
    _cache.clear();
    _identities.clear();
    _failures.clear();
  }

  /// 强制重新生成指定文件的缩略图（P-Thumb v1.3.2 §22 — 唯一 force 入口）
  ///
  /// Forces a fresh decode of [rawPath], bypassing memory/disk caches.
  /// 内部流程（A.11）：evict（memo 失效 / pathEpoch++ / negative memo 清理）
  /// → forceRefresh 解帧 → 覆写磁盘 → 返回 [MemoryImage]（R2 即时展示）。
  ///
  /// 双击 retry 场景（H5/F6）：已有在飞 force flight 时直接 join，
  /// 不重复 evict/decode。`forceRefresh` 不作为公开参数暴露（M5）。
  static Future<ImageProvider?> retry(String rawPath) =>
      _instance._retryImpl(rawPath);

  Future<ImageProvider?> _retryImpl(String rawPath) async {
    final path = p.normalize(rawPath);

    // H5/F6：先查在飞 force flight — 直接 join，绝不重复 evict
    final forceFlight = _registry.forceFlightFor(path);
    if (forceFlight != null) {
      if (kDebugMode) _metrics.coalescedJoins++;
      return forceFlight.future;
    }

    evict(path);
    final identity = await _identities.resolve(path);
    if (identity == null) return null;
    return _getFlightImpl(identity, forceRefresh: true);
  }

  /// 重置全部状态（仅供测试使用）
  ///
  /// Clears cache and resets the platform provider so it will be
  /// re-selected on the next access. 可注入测试替身（M3）：
  /// - [provider] — FakeThumbnailProvider（F/E/R 矩阵）
  /// - [diskCache] — 注入临时目录的 ThumbnailDiskCache（D 矩阵）
  @visibleForTesting
  static void reset({
    ThumbnailProvider? provider,
    ThumbnailDiskCache? diskCache,
  }) {
    _instance._impl = provider;
    _instance._diskCacheOverride = diskCache;
    _instance._registry.clear();
    _instance._activeProviderCount = 0;
    _instance._failures.clear();
    // gate 同步重置 (v0.0.9 CI 稳定性) — 上一用例未归还的 slot 若跨
    // reset 存活, 后组可用并发永久减少 (G1 曾在 CI 全量跑时 calls 永卡
    // < 2)。gate.reset 唤醒排队者重新分配, 测试隔离完整。
    _instance._gate.reset();
    _instance._clearCacheImpl();
    _metrics.reset();
  }

  /// 手动触发 LRU 触摸（仅供测试使用）
  ///
  /// Moves [cacheKey] to the most-recently-used position without
  /// fetching a new thumbnail. No-op if not cached.
  @visibleForTesting
  static void touch(String cacheKey) => _instance._touchImpl(cacheKey);

  /// 缓存条目数量（仅供测试使用）
  ///
  /// Returns the current number of cached entries (0 .. [_maxCacheSize]).
  @visibleForTesting
  static int get cacheLength => _instance._cache.length;

  /// 缓存键的迭代顺序（仅供测试使用，oldest-first）— 键为 cacheKey
  @visibleForTesting
  static Iterable<String> get cacheKeys => _instance._cache.keys;

  /// identity 解析的 cacheKey 视图（仅供测试使用 — ID1-ID7 验收）
  ///
  /// Returns the resolved cache key for [rawPath], or `null` when the
  /// file cannot be stat-ed. Memo-aware: repeated calls without evict
  /// reuse the memoized identity.
  @visibleForTesting
  static Future<String?> resolveCacheKey(String rawPath) async {
    final identity = await _instance._identities.resolve(rawPath);
    return identity?.cacheKey;
  }

  /// 路径标准化视图（仅供测试使用 — ID5/ID6 验收）
  ///
  /// Exposes the exact normalization applied inside identity resolution:
  /// `p.normalize` only — no symlink resolution, no case folding (§11.1).
  @visibleForTesting
  static String normalizePathForTest(String rawPath) => p.normalize(rawPath);

  /// 命中时移到末尾（最近访问）— O(1) remove + reinsert
  void _touchImpl(String cacheKey) => _cache.touch(cacheKey);
}
