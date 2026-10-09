import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../diagnostics/kernel_logger.dart';

/// 磁盘缓存限额（P-Thumb v1.3.2 §17）
///
/// Disk cache limits. Injected as a value object so tests can shrink them
/// (D9/D10) without generating real 64 MiB fixtures.
final class ThumbnailDiskCacheLimits {
  const ThumbnailDiskCacheLimits({
    this.maxEntries = 512,
    this.maxBytes = 64 * 1024 * 1024,
    this.targetEntries = 409,
    this.targetBytes = 48 * 1024 * 1024,
    this.maxAge = const Duration(days: 30),
  });

  /// 条目上限
  final int maxEntries;

  /// 总字节上限（64 MiB）
  final int maxBytes;

  /// 清理水位条目（80% of 512）— 删到水位而非“写一张删一张”震荡（§17.4）
  final int targetEntries;

  /// 清理水位字节（48 MiB）
  final int targetBytes;

  /// 条目最大年龄（30 天）— 以文件 mtime 近似，不承诺跨重启 LRU（§17.5）
  final Duration maxAge;

  /// 默认生产限额
  static const ThumbnailDiskCacheLimits production = ThumbnailDiskCacheLimits();
}

/// 清理结果摘要 — 跨 isolate 边界回传的可发送 record
///
/// Sendable summary returned from the worker isolate for main-isolate logging.
typedef CleanupSummary = ({int freedBytes, int evictedCount, int survivors});

/// Isolate 运行器抽象 — 匹配 [Isolate.run] 签名, 测试可注入假实现
///
/// Matches [Isolate.run]'s signature exactly; tests inject a fake to simulate
/// [IsolateSpawnException] without spawning a real isolate.
typedef DiskCacheIsolateRunner<T> = Future<T> Function(
  FutureOr<T> Function() task,
);

/// 隔离执行的清理纯函数 — age 淘汰 + 水位淘汰（§17.4/§17.5）
///
/// 在 worker isolate 中运行; 只接收 sendable 参数 (路径 String / 限额值
/// 对象 / hash pattern String / 当前 DateTime)。Directory/RegExp 在函数
/// 内部重建, 绝不捕获跨 isolate 不可发送的对象。
///
/// 语义与原内联清理逐字节一致: D8 .part 1hr 淘汰 / D10 age 淘汰 / 水位
/// oldest-first 淘汰。返回 [CleanupSummary] 供主 isolate 日志记录。
///
/// 目录扫描失败返回零摘要 (与原 early-return 一致); 单文件 stat/delete
/// 失败 best-effort 继续。
Future<CleanupSummary> runDiskCacheCleanupInIsolate({
  required String directoryPath,
  required ThumbnailDiskCacheLimits limits,
  required String hashPattern,
  required DateTime now,
}) async {
  final dir = Directory(directoryPath);
  final safeHash = RegExp(hashPattern);
  final survivors = <(File, FileStat)>[];
  var totalBytes = 0;
  var freedBytes = 0;
  var evictedCount = 0;

  try {
    final entries = await dir.list(followLinks: false).toList();

    for (final entry in entries) {
      if (entry is! File) continue;

      final name = p.basename(entry.path);

      // D8：崩溃残留的 .part — 超过 1 小时即删
      if (name.endsWith('.part')) {
        try {
          final stat = await entry.stat();
          if (now.difference(stat.modified) > const Duration(hours: 1)) {
            await entry.delete();
            freedBytes += stat.size;
            evictedCount++;
          }
        } on FileSystemException {
          // best effort
        }
        continue;
      }

      if (!name.endsWith('.jpg')) continue;
      final stem = name.substring(0, name.length - 4);
      if (!safeHash.hasMatch(stem)) continue;

      try {
        final stat = await entry.stat();

        // D10：age 超限直接淘汰（不占水位）
        if (now.difference(stat.modified) > limits.maxAge) {
          await entry.delete();
          freedBytes += stat.size;
          evictedCount++;
          continue;
        }

        totalBytes += stat.size;
        survivors.add((entry, stat));
      } on FileSystemException {
        // best effort — 文件可能已被并发删除
      }
    }
  } on FileSystemException {
    // 目录扫描失败 — 本轮放弃, 下轮重试; 返回零摘要 (与原 early-return 一致)
    return (freedBytes: 0, evictedCount: 0, survivors: 0);
  }

  // 水位检查 — 未超限直接返回
  if (survivors.length <= limits.maxEntries && totalBytes <= limits.maxBytes) {
    return (
      freedBytes: freedBytes,
      evictedCount: evictedCount,
      survivors: survivors.length,
    );
  }

  // oldest-first 淘汰到水位（§17.4）
  survivors.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
  var currentBytes = totalBytes;
  var currentCount = survivors.length;

  for (final (file, stat) in survivors) {
    if (currentCount <= limits.targetEntries &&
        currentBytes <= limits.targetBytes) {
      break;
    }
    try {
      await file.delete();
      currentBytes -= stat.size;
      currentCount--;
      freedBytes += stat.size;
      evictedCount++;
    } on FileSystemException {
      // best effort
    }
  }

  return (
    freedBytes: freedBytes,
    evictedCount: evictedCount,
    survivors: currentCount,
  );
}

/// 磁盘缓存 — 持久化 JPEG 存储（P-Thumb v1.3.2 §16，v1.3 从 Provider 上移的职责）
///
/// Persistent JPEG store keyed by 64-hex cache key. Responsibilities:
/// temp→publish writes (A.12), 4-byte JPEG validation with read-time
/// self-healing (A.13), bounded background cleanup (§17).
///
/// 注入点（M3，仿 WindowsThumbnailProvider.resolveCacheDirectory 模式）：
/// - [resolveDirectory] — 测试注入临时目录
/// - [now]              — 测试注入可控时钟（D10 age 清理）
/// - [limits]           — 测试缩小限额（D9 水位）
///
/// 目录解析失败永久降级为无磁盘层（MSIX 沙盒等）— I9：缓存可全丢，
/// 播放与播放列表绝不受影响。所有 IO 失败静默降级（best-effort，
/// 由注释与 metrics 表达，不产生 per-thumbnail 日志 — §32.3）。
final class ThumbnailDiskCache {
  ThumbnailDiskCache({
    Future<Directory> Function()? resolveDirectory,
    DateTime Function()? now,
    this.limits = ThumbnailDiskCacheLimits.production,
    DiskCacheIsolateRunner<CleanupSummary>? isolateRunner,
  }) : _resolveDirectory =
           resolveDirectory ?? ThumbnailDiskCache._defaultResolve,
       _now = now ?? DateTime.now,
       _isolateRunner = isolateRunner ?? ((task) => Isolate.run(task));

  final Future<Directory> Function() _resolveDirectory;
  final DateTime Function() _now;

  /// 清理计算执行点 — 默认 [Isolate.run]; 测试注入假实现模拟 spawn 失败
  final DiskCacheIsolateRunner<CleanupSummary> _isolateRunner;

  /// 限额 — 公开只读，测试缩小以驱动水位/age 淘汰（D9/D10）
  final ThumbnailDiskCacheLimits limits;

  /// 安全 hash 白名单 — final 文件名只能来自 64 位小写十六进制（§30.2），
  /// 从构造上杜绝路径拼接注入（§30.1）
  static final RegExp _safeHashPattern = RegExp(r'^[0-9a-f]{64}$');

  /// 默认目录 — `<appCache>/simple_player/thumbnail/v3`（§16.1）
  static Future<Directory> _defaultResolve() async {
    final base = await getApplicationCacheDirectory();
    return Directory(p.join(base.path, 'simple_player', 'thumbnail', 'v3'));
  }

  Directory? _cachedDir;
  bool _dirResolveFailed = false;

  /// temp 唯一后缀计数器 — microseconds + counter（§30.5 统一方案，M1）
  int _writeCounter = 0;

  /// 成功写盘计数 — 每 64 次安排一次后台清理（§17.3 入口 2）
  int _writesSinceCleanup = 0;

  /// 单飞清理 — 同一时间只有一个 cleanup Future（§17.3）
  Future<void>? _cleanupFuture;

  /// 本进程是否已跑过启动清理（惰性守卫）
  DateTime? _lastStartupCleanupAt;

  /// 解析缓存目录 — 一次性；失败永久降级为无磁盘层
  Future<Directory?> _ensureDirectory() async {
    final cached = _cachedDir;
    if (cached != null) return cached;
    if (_dirResolveFailed) return null;
    try {
      final dir = await _resolveDirectory();
      await dir.create(recursive: true);
      _cachedDir = dir;
      // §17.3 入口 1：目录就绪后安排一次启动清理 — 惰性无 timer；
      // 解析失败路径（沙盒/测试）天然不触发
      scheduleStartupCleanup();
      return dir;
    } on Exception {
      // 目录不可创建（MSIX 沙盒/权限）— 环境性问题，不再反复触碰；
      // 缓存整体退化为内存层（I9）
      _dirResolveFailed = true;
      return null;
    }
  }

  /// 返回 final 缓存文件路径（不校验内容）— retry 的 FileImage.evict 用
  Future<File?> fileFor(String cacheKey) async {
    final dir = await _ensureDirectory();
    if (dir == null || !_isSafeHash(cacheKey)) return null;
    return File(p.join(dir.path, '$cacheKey.jpg'));
  }

  /// temp → publish 写入（A.12）
  ///
  /// - [replaceExisting] = true 仅用于 forceRefresh（retry）— 完整 temp
  ///   写成功后才删除旧 final，生成失败时旧缓存仍然存在（§22.2）。
  /// - 非 force 场景命中已有 final 时直接复用，不重复写。
  /// - 返回 null = 写失败（调用方降级 MemoryImage，不进 negative cache）。
  Future<File?> write(
    String cacheKey,
    Uint8List bytes, {
    required bool replaceExisting,
  }) async {
    final dir = await _ensureDirectory();
    if (dir == null || !_isSafeHash(cacheKey)) {
      return null;
    }

    // H4 write 侧对称校验（§30.6）— 非法 JPEG 不落盘（D11）
    if (bytes.length < 4 ||
        bytes[0] != 0xFF ||
        bytes[1] != 0xD8 ||
        bytes[bytes.length - 2] != 0xFF ||
        bytes[bytes.length - 1] != 0xD9) {
      return null;
    }

    final target = File(p.join(dir.path, '$cacheKey.jpg'));

    // temp 唯一后缀 — microseconds + 进程内计数器（§30.5，M1）
    final suffix = '${_now().microsecondsSinceEpoch}-${++_writeCounter}';
    final temp = File('${target.path}.$suffix.part');

    try {
      await temp.writeAsBytes(bytes, flush: true);

      if (await target.exists()) {
        if (!replaceExisting) {
          await temp.delete();
          return target;
        }
        // 非严格原子替换：目标文件只会在完整 temp 写完后才被删除
        await target.delete();
      }

      await temp.rename(target.path);
      _onWriteSuccess();
      return target;
    } on FileSystemException {
      try {
        if (await temp.exists()) {
          await temp.delete();
        }
      } on FileSystemException {
        // best effort — 残留 .part 由 scheduled cleanup 兜底（D8）
      }
      return null;
    }
  }

  /// 校验 + 读时自愈（A.13）
  ///
  /// 完整 4 字节校验 SOI(FF D8) + EOI(FF D9) — 仅查首字节 0xFF 不足以
  /// 拒绝垃圾文件（H4/D12）。损坏文件读时删除自愈，下次请求重新生成。
  /// 注意：删除必须发生在 RAF 关闭之后 — Windows 文件句柄不共享
  /// DELETE 权限，句柄未关时 delete 会失败。
  Future<ImageProvider?> read(String cacheKey) async {
    final dir = await _ensureDirectory();
    if (dir == null || !_isSafeHash(cacheKey)) {
      return null;
    }

    final file = File(p.join(dir.path, '$cacheKey.jpg'));

    try {
      final length = await file.length();

      if (length < 4) {
        await file.delete();
        return null;
      }

      var isJpeg = false;
      final raf = await file.open(mode: FileMode.read);
      try {
        final head = await raf.read(2);
        await raf.setPosition(length - 2);
        final tail = await raf.read(2);

        isJpeg =
            head.length == 2 &&
            tail.length == 2 &&
            head[0] == 0xFF &&
            head[1] == 0xD8 &&
            tail[0] == 0xFF &&
            tail[1] == 0xD9;
      } finally {
        await raf.close();
      }

      // 自愈删除 — RAF 已关闭，Windows 句柄不再阻塞
      if (!isJpeg) {
        await file.delete();
        return null;
      }

      return FileImage(file);
    } on FileSystemException {
      return null;
    }
  }

  /// 后台清理（§17.3）— 单飞；绝不进入请求热路径（§17.2）
  Future<void> scheduleCleanup() {
    final existing = _cleanupFuture;
    if (existing != null) return existing;
    final task = _runCleanup().whenComplete(() => _cleanupFuture = null);
    _cleanupFuture = task;
    return task;
  }

  /// 启动后首次使用时安排一次后台清理（§17.3 入口 1）
  ///
  /// 惰性触发（无 Timer）：首次缩略图请求本就是启动后的第一个自然点，
  /// 避免为“延迟 30s”挂全局 timer — 那会向测试/预览环境泄漏 pending
  /// timers（widget 测试的 invariant 检查会失败）。
  void scheduleStartupCleanup() {
    if (_lastStartupCleanupAt != null) return;
    _lastStartupCleanupAt = _now();
    unawaited(scheduleCleanup());
  }

  /// 成功写盘计数 — 累计 64 次安排一次清理（§17.3 入口 2）
  void _onWriteSuccess() {
    _writesSinceCleanup++;
    if (_writesSinceCleanup >= 64) {
      _writesSinceCleanup = 0;
      unawaited(scheduleCleanup());
    }
  }

  bool _isSafeHash(String cacheKey) => _safeHashPattern.hasMatch(cacheKey);

  /// 防御性 info 日志 — 包裹 KernelLogger, 测试中未初始化 logger 时静默降级
  /// (匹配 isolated_error_log_sink.dart:402-411 降级模式)
  void _logInfo(String message, {Map<String, Object?>? context}) {
    try {
      KernelLogger.I.info(message, context: context);
    } on Object {
      // 测试中 KernelLogger 可能未初始化 — 静默降级, 不影响清理流程
    }
  }

  /// 防御性 warn 日志 — 包裹 KernelLogger, 测试中未初始化 logger 时静默降级
  void _logWarn(String message, {Map<String, Object?>? context}) {
    try {
      KernelLogger.I.warn(message, context: context);
    } on Object {
      // 测试中 KernelLogger 可能未初始化 — 静默降级
    }
  }

  /// 清理主体 — age 淘汰 + 水位淘汰（§17.4/§17.5）
  ///
  /// 计算与删除在 worker isolate 中执行 (via [Isolate.run]), 释放主 isolate
  /// 事件循环; [IsolateSpawnException] 降级为内联 async 路径 (匹配项目降级
  /// 哲学 — isolated_error_log_sink.dart spawn 失败回退 ErrorLogFileSink)。
  /// 闭包只捕获可发送数据 (路径 String / 限额值对象 / pattern String /
  /// DateTime), Directory/RegExp 在 isolate 内部重建。
  ///
  /// 261009-roy S3/F16: catch 面补 Error 族分支 — 非 Exception 的 Error
  /// （如绑定解析 ArgumentError, 261009-fio H1 同族环境性失败）与 spawn
  /// 失败同样回落内联清理; 内联再失败则记 warn 跳过本轮。清理经
  /// `unawaited(scheduleCleanup())` 触发的路径绝不让错误外溢成未处理
  /// 异步异常。
  ///
  /// 排序依据 file.stat().modified 作为 approximate recency；
  /// 不承诺跨重启绝对 LRU（X9：不为此制造每次 hit 的磁盘写）。
  Future<void> _runCleanup() async {
    final dir = await _ensureDirectory();
    if (dir == null) return;

    final now = _now();
    final dirPath = dir.path;
    final hashPatternStr = _safeHashPattern.pattern;
    // 提取限额到局部变量 — 闭包只捕获 sendable 数据, 避免 `this` 跨 isolate
    final cachedLimits = limits;

    // isolate 优先; spawn 失败与 Error 族均降级内联回落 (summary 为 null
    // 即回落信号), 内联回落再失败跳过本轮。
    CleanupSummary? summary;
    try {
      summary = await _isolateRunner(
        () => runDiskCacheCleanupInIsolate(
          directoryPath: dirPath,
          limits: cachedLimits,
          hashPattern: hashPatternStr,
          now: now,
        ),
      );
      _logInfo(
        'thumbnail disk cache cleanup finished',
        context: {
          'freedBytes': summary.freedBytes,
          'evictedCount': summary.evictedCount,
          'survivors': summary.survivors,
        },
      );
      return;
    } on IsolateSpawnException catch (e) {
      _logWarn(
        'isolate cleanup unavailable — falling back to inline',
        context: {'error': e.toString()},
      );
    } on Error catch (error, stackTrace) {
      // S3/F16: Error 族 (非 Exception) 降级内联 — 不再沿清理链上抛
      _logWarn(
        'thumbnail isolate cleanup failed (Error) — falling back to inline',
        context: {'error': '$error', 'stackTrace': '$stackTrace'},
      );
    }
    try {
      final inline = await runDiskCacheCleanupInIsolate(
        directoryPath: dirPath,
        limits: cachedLimits,
        hashPattern: hashPatternStr,
        now: now,
      );
      _logInfo(
        'thumbnail disk cache cleanup finished (inline fallback)',
        context: {
          'freedBytes': inline.freedBytes,
          'evictedCount': inline.evictedCount,
          'survivors': inline.survivors,
        },
      );
    } on Object catch (error, stackTrace) {
      // 内联回落也失败 — 跳过本轮, 下轮清理重试; 绝不让错误沿
      // unawaited(scheduleCleanup()) 变成未处理异步异常
      _logWarn(
        'thumbnail disk cache cleanup inline fallback failed — '
        'skipping this round',
        context: {'error': '$error', 'stackTrace': '$stackTrace'},
      );
    }
  }
}
