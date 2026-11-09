/// 磁盘缓存清理 — 限额值对象 + 隔离执行的清理纯函数 (从 thumbnail_disk_cache 拆出).
///
/// Disk-cache cleanup: limits value object, sendable summary and the pure
/// worker-isolate cleanup function (P-Thumb v1.3.2 §17).
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

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
  final scan = _CleanupScan();
  try {
    final entries = await Directory(directoryPath)
        .list(followLinks: false)
        .toList();
    final safeHash = RegExp(hashPattern);
    for (final entry in entries) {
      if (entry is File) await _scanEntry(entry, scan, safeHash, limits, now);
    }
  } on FileSystemException {
    // 目录扫描失败 — 本轮放弃, 下轮重试; 返回零摘要 (与原 early-return 一致)
    return (freedBytes: 0, evictedCount: 0, survivors: 0);
  }

  // 水位检查 — 未超限直接返回; 否则 oldest-first 淘汰到水位 (§17.4)
  if (scan.survivors.length > limits.maxEntries ||
      scan.totalBytes > limits.maxBytes) {
    await _evictToWatermark(scan, limits);
  }
  return scan.summary;
}

/// 清理扫描累加器 — 存活文件 + 释放/淘汰计数 (isolate 内局部状态).
class _CleanupScan {
  /// 存活 (未被 age 淘汰) 的 jpg 及其 stat, 用于水位淘汰排序.
  final List<(File, FileStat)> survivors = <(File, FileStat)>[];

  /// 存活文件总字节.
  int totalBytes = 0;

  /// 已释放字节.
  int freedBytes = 0;

  /// 已淘汰文件数.
  int evictedCount = 0;

  /// 当前摘要 — survivors 取现存数.
  CleanupSummary get summary => (
    freedBytes: freedBytes,
    evictedCount: evictedCount,
    survivors: survivors.length,
  );

  /// 记一次删除.
  void recordEviction(int sizeBytes) {
    freedBytes += sizeBytes;
    evictedCount++;
  }
}

/// 扫描单个文件: D8 .part 淘汰 / D10 age 淘汰 / 其余合法 jpg 记入存活集.
///
/// 单文件 stat/delete 失败 best-effort 继续 (文件可能已被并发删除).
Future<void> _scanEntry(
  File entry,
  _CleanupScan scan,
  RegExp safeHash,
  ThumbnailDiskCacheLimits limits,
  DateTime now,
) async {
  final name = p.basename(entry.path);
  final isPart = name.endsWith('.part');
  if (!isPart) {
    if (!name.endsWith('.jpg')) return;
    final stem = name.substring(0, name.length - 4);
    if (!safeHash.hasMatch(stem)) return;
  }

  try {
    final stat = await entry.stat();
    // D8：崩溃残留的 .part 超过 1 小时即删; D10：age 超限直接淘汰（不占水位）
    final maxAge = isPart ? const Duration(hours: 1) : limits.maxAge;
    if (now.difference(stat.modified) > maxAge) {
      await entry.delete();
      scan.recordEviction(stat.size);
      return;
    }
    if (isPart) return; // 未过期的 .part 留给在途写入, 不计入存活
    scan.totalBytes += stat.size;
    scan.survivors.add((entry, stat));
  } on FileSystemException {
    // best effort
  }
}

/// oldest-first 淘汰到水位（§17.4）— 删到 target 而非"写一张删一张"震荡.
///
/// 结束后 [_CleanupScan.survivors] 只含仍存在的文件 (删除失败者算存活),
/// 摘要的 survivors 与旧实现的 currentCount 一致.
Future<void> _evictToWatermark(
  _CleanupScan scan,
  ThumbnailDiskCacheLimits limits,
) async {
  final sorted = [...scan.survivors]
    ..sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
  var currentBytes = scan.totalBytes;
  var currentCount = sorted.length;
  final kept = <(File, FileStat)>[];

  var index = 0;
  for (; index < sorted.length; index++) {
    if (currentCount <= limits.targetEntries &&
        currentBytes <= limits.targetBytes) {
      break;
    }
    final (file, stat) = sorted[index];
    try {
      await file.delete();
      currentBytes -= stat.size;
      currentCount--;
      scan.recordEviction(stat.size);
    } on FileSystemException {
      kept.add(sorted[index]); // best effort — 删除失败者仍算存活
    }
  }
  kept.addAll(sorted.sublist(index)); // 未触及 (已达水位) 的较新文件
  scan.survivors
    ..clear()
    ..addAll(kept);
}
