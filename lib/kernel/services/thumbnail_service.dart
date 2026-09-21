import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;

import 'linux_thumbnail_provider.dart';
import 'macos_thumbnail_provider.dart';
import 'noop_thumbnail_provider.dart';
import 'thumbnail_concurrency_gate.dart';
import 'thumbnail_disk_cache.dart';
import 'thumbnail_flight_registry.dart';
import 'thumbnail_provider.dart';
import 'windows_thumbnail_provider.dart';

/// 缩略图规格 — 冻结的解帧参数（P-Thumb v1.3.2 §10.2）
///
/// Frozen extraction parameters. Every field enters the canonical cache-key
/// string, so changing any value (or [schemaVersion]) rotates all keys at
/// once — stale cached thumbnails can never be served after an upgrade.
final class _ThumbnailSpec {
  const _ThumbnailSpec._();

  /// 缓存架构版本 — 整体换 key 的总闸，旧 v2 磁盘文件由后台清理回收
  static const schemaVersion = 'v3';

  /// 解帧最长边 — 列表卡片 128×72 显示足够
  static const maxWidth = 320;
  static const maxHeight = 320;

  /// 截帧时间点 (ms) — 取 1s 处避开常见黑屏首帧
  static const timeMs = 1000;
  static const jpegQuality = 85;
}

/// 文件身份 — immutable snapshot（P-Thumb v1.3.2 §10.1）
///
/// Identity snapshot `(normalized path, size, mtime, spec)` hashed into a
/// cache key. Resolved once per request; async stages must never re-stat
/// or mutate it — they consume the same instance.
final class _FileIdentity {
  const _FileIdentity({
    required this.path,
    required this.cacheKey,
  });

  /// normalize 后的绝对路径 — 传给 provider 的唯一形态
  final String path;

  /// sha256(canonical) — 内存 LRU 与磁盘文件名共用的主键
  final String cacheKey;
}

/// debug-only 观测计数器（P-Thumb v1.3.2 §32 — release 零开销）
///
/// Debug metrics: every increment is kDebugMode-gated at call sites, so
/// release builds neither count nor allocate. Never log per-thumbnail
/// request paths here (§32.3 — 噪音反而制造性能问题).
@visibleForTesting
final class ThumbnailMetrics {
  int requests = 0;
  int memoryHits = 0;
  int diskHits = 0;
  int providerCalls = 0;
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
}

/// 平台感知的缩略图服务门面 — P-Thumb v1.3.2
///
/// Facade that lazily selects a platform-specific [ThumbnailProvider] based
/// on [defaultTargetPlatform] and orchestrates caching.
///
/// Invariants (P-Thumb v1.3.2):
/// - Cache identity = `(normalized path, size, mtime, spec)` 的 SHA-256，
///   绝不用裸 path 当 key（X1/X5）。
/// - Memory LRU 以 cacheKey 为键，容量上限 [_maxCacheSize] (200)。
/// - identity memo：path → identity 解析缓存，memory hit 全程零磁盘 I/O
///   (I10)；`evict(path)` 必须同步删除 memo 条目 (R5)。
/// - All public methods are static — consumers call [ThumbnailService.xxx] directly.
/// - Thread-safety is not guaranteed; called from the UI isolate only.
class ThumbnailService {
  ThumbnailService._();

  /// LRU 容量 — 远大于典型可见区，万级媒体库内存驻留不是本架构目标
  static const _maxCacheSize = 200;

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

  /// 启动清理只调度一次的守卫
  bool _startupCleanupScheduled = false;

  /// LRU — LinkedHashMap 维护插入顺序，访问时 remove+reinsert 移到末尾；
  /// 键为 cacheKey（非 path — 同一 path 可随文件变化产生多个 identity）
  final _cache = <String, ImageProvider>{};

  /// path → 该 path 历史产生过的全部 cacheKey（多版本共存：A.mp4/v1、/v2）
  final Map<String, Set<String>> _cacheKeysByPath = {};

  /// cacheKey → path 反查 — LRU 淘汰时同步维护反向索引
  final Map<String, String> _pathByCacheKey = {};

  /// identity memo — memory hot path 零 stat 的关键（R5/I10）。
  /// 失效契约：evict(path) 删除对应条目；clearCache() 清空全部；
  /// 文件被外部替换但未 evict → 显示旧图（与 v1.2 现状行为一致，
  /// 由 Coordinator 的 evict 调用契约覆盖 — §40.1）。
  final Map<String, _FileIdentity> _identityMemo = {};

  /// negative memo — cacheKey → 失败屏蔽截止时刻（§21.2，TTL 10s）
  final Map<String, DateTime> _failedUntil = {};

  /// path → 失败 key 反向索引 — evict 时 O(keys-of-path) 清理（M6），
  /// 杜绝 v1.3.1 A.9 startsWith prefix collision
  final Map<String, Set<String>> _failureKeysByPath = {};

  /// in-flight 注册表 + epoch 内核（B3）— join/失效/isCurrent 唯一入口
  final ThumbnailFlightRegistry _registry = ThumbnailFlightRegistry();

  /// 并发闸（B4 — §20）— 只包 Provider generation，gate 外零昂贵步骤
  final ThumbnailConcurrencyGate _gate =
      ThumbnailConcurrencyGate(maxConcurrent);

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
    _scheduleStartupCleanupOnce();
    if (kDebugMode) _metrics.requests++;

    // identity 解析（memo 命中 = 零磁盘 I/O — I10）
    final identity = await _resolveIdentityImpl(filePath);
    if (identity == null) return null;

    final key = identity.cacheKey;

    // LRU 命中 — remove 返回非 null 即命中，reinsert 实现 LRU touch（O(1)）
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      if (kDebugMode) _metrics.memoryHits++;
      return cached;
    }

    // negative memo 命中 — TTL 内直接失败，挡住坏文件的重复解帧（§21）
    final failedUntil = _failedUntil[key];
    if (failedUntil != null) {
      if (DateTime.now().isBefore(failedUntil)) {
        return null;
      }
      // TTL 已过 — 回收后走正常流程
      _failedUntil.remove(key);
      _failureKeysByPath[identity.path]?.remove(key);
    }

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
    _FileIdentity identity, {
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
    _FileIdentity identity, {
    required bool forceRefresh,
  }) async {
    try {
      // ── Provider 域：失败 = negative cache 语义（仅 current，M2/21.5）──
      Uint8List? bytes;
      try {
        bytes = await _gate.run(() async {
          // 峰值观测在 gate 内 — 排队中的请求未真正占用解帧资源
          if (kDebugMode) {
            _metrics.providerCalls++;
            _activeProviderCount++;
            if (_activeProviderCount > _metrics.peakConcurrent) {
              _metrics.peakConcurrent = _activeProviderCount;
            }
          }
          try {
            return await _providerImpl.generateThumbnail(identity.path);
          } finally {
            if (kDebugMode) _activeProviderCount--;
          }
        });
      } on Exception {
        // 不捕获 Error — 编程 bug 必须暴露给 zone（I11）
        if (kDebugMode) _metrics.failures++;
        _recordFailureIfCurrent(flight, identity);
        flight.complete(null);
        return;
      }

      if (bytes == null || bytes.isEmpty) {
        if (kDebugMode) _metrics.failures++;
        _recordFailureIfCurrent(flight, identity);
        flight.complete(null);
        return;
      }

      // 检查点 1（await 点 1 之后）— stale 可返回原请求，无 commit 权（§19.7）
      if (!_registry.isCurrent(flight)) {
        flight.complete(MemoryImage(bytes));
        return;
      }

      // ── Disk/commit 域：失败 = 降级 MemoryImage，不进 negative cache ──
      ImageProvider? committed;
      try {
        committed = await _commitToCache(
          flight,
          identity,
          bytes,
          forceRefresh: forceRefresh,
        );
      } on Exception {
        // D7：写失败 ≠ 生成失败 — bytes 已拿到，降级展示（Error 不捕获）
        flight.complete(MemoryImage(bytes));
        return;
      }

      if (forceRefresh) {
        // R2：retry 当前请求即时展示新 bytes — 旧 decoded FileImage 已在
        // _commitToCache 内 evict，下次滚动从新磁盘文件重新 decode（§22.3）
        flight.complete(MemoryImage(bytes));
        return;
      }
      flight.complete(committed ?? MemoryImage(bytes));
    } finally {
      _registry.remove(flight);
    }
  }

  /// negative memo 记录（§21.2）— M2/21.5：stale flight 的失败不记 memo，
  /// 否则文件替换恢复后的新请求会被旧代的失败挡住 10 秒
  void _recordFailureIfCurrent(
    ThumbnailFlight flight,
    _FileIdentity identity,
  ) {
    if (!_registry.isCurrent(flight)) return;
    _failedUntil[identity.cacheKey] =
        DateTime.now().add(_negativeTtl);
    _failureKeysByPath
        .putIfAbsent(identity.path, () => <String>{})
        .add(identity.cacheKey);
  }

  /// commit 阶段 — 内含检查点 2（R7/H1：紧贴 _cachePut，§19.8）
  Future<ImageProvider?> _commitToCache(
    ThumbnailFlight flight,
    _FileIdentity identity,
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

  /// 启动后延迟清理只调度一次（§17.3 入口 1）
  void _scheduleStartupCleanupOnce() {
    if (_startupCleanupScheduled) return;
    _startupCleanupScheduled = true;
    _diskCache.scheduleStartupCleanup();
  }

  /// identity 解析 — normalize → memo → stat → canonical → SHA-256
  ///
  /// stat 失败或文件不存在返回 null（X3：stat 失败 → 不可信 identity，
  /// 绝不降级到 path-only 缓存）。memo 命中时零磁盘访问。
  Future<_FileIdentity?> _resolveIdentityImpl(String rawPath) async {
    final path = p.normalize(rawPath);

    if (!p.isAbsolute(path)) {
      return null;
    }

    // R5：memo 命中 = 零 stat（memory hot path 的前提）
    final memo = _identityMemo[path];
    if (memo != null) {
      if (kDebugMode) _metrics.identityMemoHits++;
      return memo;
    }

    try {
      if (kDebugMode) _metrics.statCalls++;
      final stat = await File(path).stat();

      if (stat.type == FileSystemEntityType.notFound) {
        return null;
      }

      final identity = _buildIdentity(
        path,
        stat.size,
        stat.modified.millisecondsSinceEpoch,
      );

      _identityMemo[path] = identity;
      return identity;
    } on FileSystemException {
      return null;
    }
  }

  /// 组装 identity — size + mtime 进入 canonical，防止源文件替换后命中旧图
  static _FileIdentity _buildIdentity(String path, int size, int modifiedMs) {
    final canonical = buildCanonicalString(
      schemaVersion: _ThumbnailSpec.schemaVersion,
      path: path,
      size: size,
      modifiedMs: modifiedMs,
    );

    return _FileIdentity(
      path: path,
      cacheKey: cacheKeyFromCanonical(canonical),
    );
  }

  /// canonical 身份串 — NUL 分隔防字段拼接歧义（§12.4）。
  ///
  /// 分隔符歧义前提是 path 含 NUL — Windows/POSIX 文件名均由 OS 禁止，
  /// 无需额外防御。实现用 [String.fromCharCode] 构造分隔符，
  /// 避免转义字面量以真实 NUL 字节进入源文件。
  @visibleForTesting
  static String buildCanonicalString({
    required String schemaVersion,
    required String path,
    required int size,
    required int modifiedMs,
    int maxWidth = _ThumbnailSpec.maxWidth,
    int maxHeight = _ThumbnailSpec.maxHeight,
    int timeMs = _ThumbnailSpec.timeMs,
    String format = 'jpeg',
    int quality = _ThumbnailSpec.jpegQuality,
  }) {
    final sep = String.fromCharCode(0x00);
    return '$schemaVersion$sep'
        '$path$sep'
        '$size$sep'
        '$modifiedMs$sep'
        '$maxWidth$sep'
        '$maxHeight$sep'
        '$timeMs$sep'
        '$format$sep'
        '$quality';
  }

  /// canonical → cacheKey — SHA-256 hex（64 字符）。
  ///
  /// hash 只做缓存文件名身份，不是认证边界；输入仅几十到几百字节，
  /// SHA-256 相比 MD5 的额外开销可忽略但抗恶意碰撞更强（§12.3）。
  @visibleForTesting
  static String cacheKeyFromCanonical(String canonical) {
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  /// LRU 写入 + 双向索引维护 + 容量溢出淘汰
  void _cachePutImpl(String path, String key, ImageProvider provider) {
    _cache[key] = provider;
    _cacheKeysByPath.putIfAbsent(path, () => <String>{}).add(key);
    _pathByCacheKey[key] = path;
    _evictLruOverflowImpl();
  }

  /// 超出容量时淘汰最久未访问的条目（迭代器首位）— O(1) 摊销
  void _evictLruOverflowImpl() {
    while (_cache.length > _maxCacheSize) {
      final oldest = _cache.keys.first;
      _cache.remove(oldest);

      final path = _pathByCacheKey.remove(oldest);
      if (path != null) {
        final keys = _cacheKeysByPath[path];
        if (keys != null) {
          keys.remove(oldest);
          if (keys.isEmpty) _cacheKeysByPath.remove(path);
        }
      }
    }
  }

  /// 移除单个 path 的全部缓存条目（v1.3.2 A.9 — B1 子集）
  ///
  /// 同时失效 identity memo（R5 契约）— 下次请求重新 stat，
  /// 文件替换场景由此刷新 identity。
  static void evict(String filePath) => _instance._evictImpl(filePath);

  void _evictImpl(String rawPath) {
    final path = p.normalize(rawPath);

    // R5：memo 同步失效 — 这是文件替换后 identity 能刷新的唯一通道
    _identityMemo.remove(path);

    // B3：pathEpoch++ + 该 path 全部在飞 flight 出 join 表（A.9）
    _registry.evictPath(path);

    final keys = _cacheKeysByPath.remove(path);
    if (keys != null) {
      for (final key in keys) {
        _cache.remove(key);
        _pathByCacheKey.remove(key);
      }
    }

    // B5：negative memo 反向索引清理（A.9 — O(keys-of-path)，无 prefix 碰撞）
    final failedKeys = _failureKeysByPath.remove(path);
    if (failedKeys != null) {
      for (final key in failedKeys) {
        _failedUntil.remove(key);
      }
    }
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
    _cacheKeysByPath.clear();
    _pathByCacheKey.clear();
    _identityMemo.clear();
    _failedUntil.clear();
    _failureKeysByPath.clear();
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
    final identity = await _resolveIdentityImpl(path);
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
    // 先取消启动清理 timer — 防 pending timer 泄漏进 widget 测试
    _defaultDiskCache.cancelStartupCleanup();
    _instance._diskCacheOverride?.cancelStartupCleanup();

    _instance._impl = provider;
    _instance._diskCacheOverride = diskCache;
    _instance._startupCleanupScheduled = false;
    _instance._registry.clear();
    _instance._activeProviderCount = 0;
    _instance._failedUntil.clear();
    _instance._failureKeysByPath.clear();
    _instance._clearCacheImpl();
    _metrics
      ..requests = 0
      ..memoryHits = 0
      ..diskHits = 0
      ..providerCalls = 0
      ..failures = 0
      ..coalescedJoins = 0
      ..diskWriteFallbacks = 0
      ..peakConcurrent = 0
      ..statCalls = 0
      ..identityMemoHits = 0;
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
    final identity = await _instance._resolveIdentityImpl(rawPath);
    return identity?.cacheKey;
  }

  /// 路径标准化视图（仅供测试使用 — ID5/ID6 验收）
  ///
  /// Exposes the exact normalization applied inside identity resolution:
  /// `p.normalize` only — no symlink resolution, no case folding (§11.1).
  @visibleForTesting
  static String normalizePathForTest(String rawPath) => p.normalize(rawPath);

  /// 命中时移到末尾（最近访问）— O(1) remove + reinsert
  void _touchImpl(String cacheKey) {
    final value = _cache.remove(cacheKey);
    if (value != null) _cache[cacheKey] = value;
  }
}
