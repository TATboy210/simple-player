/// 内存诊断数据类 — 从旧 MemoryMonitor 提炼, 供新实例化 MemoryMonitor 复用。
///
/// Extracted data classes from the legacy singleton MemoryMonitor.
/// [MetricSample] and [MemorySnapshot] are pure data carriers with toJson()
/// serialization, shared by both old and new MemoryMonitor implementations.

/// 单次内存采样 — RSS 字节数 + 时间戳。
///
/// Single RSS sample with timestamp. Pure data, immutable.
class MetricSample {
  /// 构造 — 必填 rssBytes 和 timestamp。
  const MetricSample({
    required this.rssBytes,
    required this.timestamp,
  });

  /// 本次采样 RSS 字节数。
  final int rssBytes;

  /// 采样时间。
  final DateTime timestamp;

  /// 序列化为 JSON 兼容 Map。
  Map<String, Object> toJson() => {
        'rssBytes': rssBytes,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// 内存快照 — 当前值、峰值、增长量、采样历史、时间戳。
///
/// Memory snapshot with current RSS, peak RSS, delta, sampling history,
/// and timestamp. Pure data with toJson() serialization.
class MemorySnapshot {
  /// 构造 — 所有字段必填。
  const MemorySnapshot({
    required this.rssBytes,
    required this.maxRssBytes,
    required this.deltaBytes,
    required this.history,
    required this.timestamp,
  });

  /// 当前 RSS 字节数。
  final int rssBytes;

  /// 历史峰值 RSS 字节数。
  final int maxRssBytes;

  /// 与上次采样的差值 (字节)。
  final int deltaBytes;

  /// 采样历史 (环形缓冲)。
  final List<MetricSample> history;

  /// 快照时间。
  final DateTime timestamp;

  /// 序列化为 JSON 兼容 Map — 含计算字段 rssMB/maxRssMB/historyCount。
  Map<String, Object> toJson() => {
        'rssBytes': rssBytes,
        'maxRssBytes': maxRssBytes,
        'deltaBytes': deltaBytes,
        'rssMB': (rssBytes / (1024 * 1024)).toStringAsFixed(1),
        'maxRssMB': (maxRssBytes / (1024 * 1024)).toStringAsFixed(1),
        'historyCount': history.length,
        'history': history.map((s) => s.toJson()).toList(),
        'timestamp': timestamp.toIso8601String(),
      };
}
