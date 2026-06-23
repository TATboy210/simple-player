/// 播放列表项 — 不可变数据类
class PlaylistItem {
  final String path;
  final String title;
  final int? durationMs;
  final int? lastPositionMs;

  const PlaylistItem({
    required this.path,
    required this.title,
    this.durationMs,
    this.lastPositionMs,
  });

  PlaylistItem copyWith({
    String? path,
    String? title,
    int? durationMs,
    int? lastPositionMs,
  }) {
    return PlaylistItem(
      path: path ?? this.path,
      title: title ?? this.title,
      durationMs: durationMs ?? this.durationMs,
      lastPositionMs: lastPositionMs ?? this.lastPositionMs,
    );
  }
}
