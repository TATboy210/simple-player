import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../diagnostics/kernel_logger.dart';
import '../models/play_mode.dart';
import '../models/playlist_item.dart';

final _log = KernelLogger.I;

/// 播放列表持久化快照 — 队列条目（含断点元数据）与播放模式.
///
/// Persisted playlist snapshot — queue entries (with resume metadata) and
/// play mode. [items] 顺序即队列顺序.
class PersistedPlaylistSnapshot {
  const PersistedPlaylistSnapshot({
    required this.items,
    required this.playMode,
  });

  /// 队列条目 — 顺序即队列顺序, 各条目携带断点/时间戳元数据.
  final List<PlaylistItem> items;

  /// 上次的播放模式.
  final PlayMode playMode;
}

/// 播放列表持久化 — 纯文本 JSON（Unix 原则: flat text files）.
///
/// Playlist persistence — plain-text JSON at
/// `<ApplicationSupport>/playlist.json`. 结构:
/// ```json
/// {
///   "version": 1,
///   "playMode": "loopAll",
///   "items": [{"path": "D:/a.mp4", "positionMs": 1200, "durationMs": 90000}]
/// }
/// ```
///
/// 容错契约: 文件缺失 / JSON 损坏 / 字段类型异常 → [load] 返回 null
/// （视作"无历史"），绝不抛出到调用方; [save] 失败仅记日志.
class PlaylistStore {
  /// [resolveDirectory] 可注入以隔离测试; 默认 Application Support 目录.
  PlaylistStore({Future<Directory> Function()? resolveDirectory})
    : _resolveDirectory = resolveDirectory ?? _defaultDirectory;

  static const _fileName = 'playlist.json';
  static const _version = 1;

  final Future<Directory> Function() _resolveDirectory;

  static Future<Directory> _defaultDirectory() =>
      getApplicationSupportDirectory();

  /// 读取持久化快照; 无文件或损坏时返回 null.
  Future<PersistedPlaylistSnapshot?> load() async {
    try {
      final directory = await _resolveDirectory();
      final file = File('${directory.path}/$_fileName');
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      return _parse(content);
    } on Exception catch (error, stackTrace) {
      // 损坏文件视作无历史 — 播放列表不是关键数据, 不值得打断启动.
      _log.w(
        'PlaylistStore: failed to load playlist.json',
        context: {'error': error.toString(), 'stackTrace': stackTrace.toString()},
      );
      return null;
    }
  }

  /// 保存快照; 失败仅记日志（断点丢失可接受, 不打断播放流程）.
  Future<void> save(PersistedPlaylistSnapshot snapshot) async {
    try {
      final directory = await _resolveDirectory();
      final file = File('${directory.path}/$_fileName');
      final json = {
        'version': _version,
        'playMode': snapshot.playMode.name,
        'items': [for (final item in snapshot.items) item.toJson()],
      };
      await file.writeAsString(jsonEncode(json));
    } on Exception catch (error) {
      _log.w(
        'PlaylistStore: failed to save playlist.json',
        context: {'error': error.toString()},
      );
    }
  }

  /// 解析 JSON 文本 — 逐字段容错: 顶层结构/条目/模式任一异常只丢弃该部分.
  PersistedPlaylistSnapshot? _parse(String content) {
    final Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;

    final rawMode = decoded['playMode'];
    final playMode = PlayMode.values.firstWhere(
      (m) => m.name == rawMode,
      orElse: () => PlayMode.loopAll, // 越界/缺失回退默认 — 旧 fromJson 同风格
    );

    final rawItems = decoded['items'];
    if (rawItems is! List) return null;
    final items = <PlaylistItem>[];
    for (final raw in rawItems) {
      if (raw is! Map<String, dynamic>) continue; // 损坏条目跳过, 不弃整个队列
      try {
        items.add(PlaylistItem.fromJson(raw));
      } on FormatException {
        continue;
      }
    }
    return PersistedPlaylistSnapshot(items: items, playMode: playMode);
  }
}
