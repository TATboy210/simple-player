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
import 'thumbnail_disk_cache.dart';
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

  /// 磁盘写失败降级 MemoryImage 的次数（R6 disk 域观察）
  int diskWriteFallbacks = 0;

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

    // 磁盘命中（第二优先级 — 零 native decode，§28.3）
    final diskProvider = await _diskCache.read(key);
    if (diskProvider != null) {
      if (kDebugMode) _metrics.diskHits++;
      _cachePutImpl(identity.path, key, diskProvider);
      return diskProvider;
    }

    // Provider 解帧（bytes 契约 — B2 起）
    final bytes = await _generateBytes(identity.path);
    if (bytes == null) return null;

    return _commitBytes(identity, bytes);
  }

  /// Provider 域异常兜底（R6 §31.1）— 解帧失败返回 null，Error 不捕获
  Future<Uint8List?> _generateBytes(String path) async {
    try {
      if (kDebugMode) _metrics.providerCalls++;
      return await _providerImpl.generateThumbnail(path);
    } on Exception {
      if (kDebugMode) _metrics.failures++;
      return null;
    }
  }

  /// Disk/commit 域（R6 §31.1）— 写盘失败降级 MemoryImage，不进 negative cache
  ///
  /// 成功 commit 时返回 FileImage 并放入 LRU；写失败返回 MemoryImage
  /// （D7：bytes 已拿到，存储失败 ≠ 生成失败）。
  Future<ImageProvider?> _commitBytes(
    _FileIdentity identity,
    Uint8List bytes,
  ) async {
    try {
      final committed = await _diskCache.write(
        identity.cacheKey,
        bytes,
        replaceExisting: false,
      );
      if (committed != null) {
        final provider = FileImage(committed);
        _cachePutImpl(identity.path, identity.cacheKey, provider);
        return provider;
      }
    } on Exception {
      // 磁盘写失败 — 降级 MemoryImage（D7/R6），Error 不捕获（I11）
    }
    if (kDebugMode) _metrics.diskWriteFallbacks++;
    return MemoryImage(bytes);
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

    final keys = _cacheKeysByPath.remove(path);
    if (keys != null) {
      for (final key in keys) {
        _cache.remove(key);
        _pathByCacheKey.remove(key);
      }
    }
  }

  /// 清空全部缓存
  ///
  /// Drops all cached thumbnails. Useful when the playlist is replaced.
  /// 只清 P-Thumb 自己的状态，绝不动 Flutter 全局 imageCache（R3）。
  static void clearCache() => _instance._clearCacheImpl();

  void _clearCacheImpl() {
    _cache.clear();
    _cacheKeysByPath.clear();
    _pathByCacheKey.clear();
    _identityMemo.clear();
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
    _instance._clearCacheImpl();
    _metrics
      ..requests = 0
      ..memoryHits = 0
      ..diskHits = 0
      ..providerCalls = 0
      ..failures = 0
      ..diskWriteFallbacks = 0
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
