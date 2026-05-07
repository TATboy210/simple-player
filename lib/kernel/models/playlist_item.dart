import '../utils/path_utils.dart';

/// 播放列表项 — 统一数据模型（合并原 PlaylistItem + HistoryEntry）
///
/// 每个字段职责：
/// - path/name：文件标识（name 由 path 派生，不持久化）
/// - timestamp：最后播放时间（null = 从未播放）
/// - positionMs：断点位置（null = 0/未知）
/// - durationMs：视频总时长（null = 未知）
class PlaylistItem {
  final String path;
  final String name;
  final int? timestamp; // millisecondsSinceEpoch，null = 从未播放
  final int? positionMs; // 断点位置，null = 0
  final int? durationMs; // 视频总时长，null = 未知

  PlaylistItem({
    required this.path,
    this.timestamp,
    this.positionMs,
    this.durationMs,
  }) : name = PathUtils.basename(path);

  /// 不可变更新历史元数据
  PlaylistItem copyWith({
    int? timestamp,
    int? positionMs,
    int? durationMs,
  }) {
    return PlaylistItem(
      path: path,
      timestamp: timestamp ?? this.timestamp,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        if (timestamp != null) 'timestamp': timestamp,
        if (positionMs != null) 'positionMs': positionMs,
        if (durationMs != null) 'durationMs': durationMs,
      };

  factory PlaylistItem.fromJson(Map<String, dynamic> json) {
    final path = json['path'];
    if (path is! String) {
      throw FormatException(
        'PlaylistItem.path must be String, got ${path.runtimeType}',
      );
    }
    return PlaylistItem(
      path: path,
      timestamp: (json['timestamp'] as num?)?.toInt(),
      positionMs: (json['positionMs'] as num?)?.toInt(),
      durationMs: (json['durationMs'] as num?)?.toInt(),
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
