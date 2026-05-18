class PlaylistItem {
  final String path;
  final String name;

  PlaylistItem({required this.path})
    : name = path.split('/').last.split('\\').last;

  Map<String, dynamic> toJson() => {'path': path};

  factory PlaylistItem.fromJson(Map<String, dynamic> json) {
    return PlaylistItem(path: json['path'] as String);
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
