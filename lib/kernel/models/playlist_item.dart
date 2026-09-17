import '../utils/path_utils.dart';

/// 播放列表项 — 统一数据模型（合并原 PlaylistItem + HistoryEntry）
///
/// 每个字段职责：
/// - path/name：文件标识（name 由 path 派生，不持久化）
/// - timestamp：最后播放时间（null = 从未播放）
/// - positionMs：断点位置（null = 0/未知）
/// - durationMs：视频总时长（null = 未知）
/// - addedSeq：添加顺序序号（v0.0.6，null = 未编号旧数据）— 排序键
///   `addedOrder` 的数据前提；物理排序后队列顺序已变，仅此字段
///   能还原"添加顺序"
///
/// Immutable data class representing a single playlist entry. Equality is
/// based solely on [path]; two items with the same path are considered equal
/// regardless of playback metadata.
///
/// Serialization: [toJson] / [fromJson] round-trip via `Map<String, dynamic>`.
/// Null metadata fields are omitted from the JSON output to save space.
class PlaylistItem {
  /// 文件绝对路径（唯一标识）
  ///
  /// Absolute file path. Serves as the identity key for equality.
  final String path;

  /// 文件名（由 path 派生，不持久化）
  ///
  /// Display name derived from [path] via [PathUtils.basename]. Not persisted.
  final String name;

  /// 最后播放时间戳（millisecondsSinceEpoch）。null = 从未播放
  ///
  /// Last playback timestamp as Unix epoch milliseconds, or `null` if never played.
  final int? timestamp;

  /// 断点位置（毫秒）。null = 0/未知
  ///
  /// Resume position in milliseconds, or `null` / `0` for the start.
  final int? positionMs;

  /// 视频总时长（毫秒）。null = 未知
  ///
  /// Total media duration in milliseconds, or `null` if unknown.
  final int? durationMs;

  /// 添加顺序序号 (v0.0.6)。null = 未编号（旧版本数据 / 未入队）
  ///
  /// Monotonic sequence for "added order" sort key; `null` for legacy data.
  final int? addedSeq;

  /// 创建播放列表项。[path] 必填，其余可选。
  ///
  /// Creates a [PlaylistItem].
  ///
  /// - [path] (required): absolute file path.
  /// - [timestamp]: last-played epoch ms; `null` if never played.
  /// - [positionMs]: resume position in ms; `null` / `0` for start.
  /// - [durationMs]: total duration in ms; `null` if unknown.
  /// - [addedSeq]: add-order sequence; `null` for legacy/unsequenced items.
  PlaylistItem({
    required this.path,
    this.timestamp,
    this.positionMs,
    this.durationMs,
    this.addedSeq,
  }) : name = PathUtils.basename(path);

  /// 不可变更新历史元数据
  ///
  /// Returns a copy with the given playback metadata replaced.
  /// [path] is always preserved. Omitted parameters retain their current value.
  // 故意不含 [path] — 路径是条目身份键 (断点/排序/锚点均按 path 键),
  // copyWith 不允许改路径, DCM 的 incomplete-copy-with 与该设计冲突.
  // ignore: avoid-incomplete-copy-with
  PlaylistItem copyWith({
    int? timestamp,
    int? positionMs,
    int? durationMs,
    int? addedSeq,
  }) {
    return PlaylistItem(
      path: path,
      timestamp: timestamp ?? this.timestamp,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      addedSeq: addedSeq ?? this.addedSeq,
    );
  }

  /// 序列化为 JSON map，null 字段省略以节省空间
  ///
  /// Serializes to a JSON-compatible map. Null metadata fields are omitted.
  Map<String, dynamic> toJson() => {
    'path': path,
    if (timestamp != null) 'timestamp': timestamp,
    if (positionMs != null) 'positionMs': positionMs,
    if (durationMs != null) 'durationMs': durationMs,
    if (addedSeq != null) 'addedSeq': addedSeq,
  };

  /// 从 JSON map 反序列化
  ///
  /// Deserializes from a JSON map produced by [toJson].
  ///
  /// Throws [FormatException] if `json['path']` is missing or not a [String].
  /// Numeric fields are coerced via `num.toInt()` to handle both `int` and
  /// `double` JSON representations.
  factory PlaylistItem.fromJson(Map<String, dynamic> json) {
    final path = json['path'];
    if (path is! String) {
      throw FormatException(
        'PlaylistItem.path must be String, got ${path.runtimeType}',
      );
    }
    // 类型安全转换：使用 is num 检查避免 TypeError
    final rawTimestamp = json['timestamp'];
    final rawPosition = json['positionMs'];
    final rawDuration = json['durationMs'];
    final rawAddedSeq = json['addedSeq'];
    return PlaylistItem(
      path: path,
      timestamp: (rawTimestamp is num) ? rawTimestamp.toInt() : null,
      positionMs: (rawPosition is num) ? rawPosition.toInt() : null,
      durationMs: (rawDuration is num) ? rawDuration.toInt() : null,
      addedSeq: (rawAddedSeq is num) ? rawAddedSeq.toInt() : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaylistItem &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'PlaylistItem($name)';
}
