import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../diagnostics/kernel_logger.dart';
import '../models/play_mode.dart';
import '../models/playlist_item.dart';
import '../models/playlist_sort.dart';

final _log = KernelLogger.I;

/// 播放列表持久化快照 — 队列条目（含断点元数据）、播放模式与排序状态.
///
/// Persisted playlist snapshot — queue entries (with resume metadata),
/// play mode and sort state. [items] 顺序即队列顺序.
class PersistedPlaylistSnapshot {
  const PersistedPlaylistSnapshot({
    required this.items,
    required this.playMode,
    this.sortKey = PlaylistSortKey.addedOrder,
    this.sortAscending = true,
  });

  /// 队列条目 — 顺序即队列顺序, 各条目携带断点/时间戳元数据.
  final List<PlaylistItem> items;

  /// 上次的播放模式.
  final PlayMode playMode;

  /// 上次的排序键 (v0.0.6).
  final PlaylistSortKey sortKey;

  /// 上次的排序方向 (v0.0.6).
  final bool sortAscending;
}

/// 播放列表持久化 — 纯文本 JSON（Unix 原则: flat text files）.
///
/// Playlist persistence — plain-text JSON at
/// `<ApplicationSupport>/playlist.json`. 结构 (version 2, v0.0.6):
/// ```json
/// {
///   "version": 2,
///   "playMode": "loopAll",
///   "sortKey": "addedOrder",
///   "sortAscending": true,
///   "items": [{"path": "D:/a.mp4", "positionMs": 1200, "durationMs": 90000,
///              "addedSeq": 0}]
/// }
/// ```
///
/// 迁移契约 (v1 → v2, 双向向后兼容):
/// - 读 v1 (或条目缺 `addedSeq`): 排序状态回退默认 (addedOrder/升序),
///   addedSeq 由上层按数组下标合成 — 旧文件顺序即添加顺序.
/// - 旧版本 app 读 v2: 不校验 version、fromJson 丢弃未知 key → 完全兼容.
///
/// 容错契约: 文件缺失 / JSON 损坏 / 字段类型异常 → [load] 返回 null
/// （视作"无历史"），绝不抛出到调用方; [save] 失败仅记日志.
class PlaylistStore {
  /// [resolveDirectory] 可注入以隔离测试; 默认 Application Support 目录.
  PlaylistStore({Future<Directory> Function()? resolveDirectory})
    : _resolveDirectory = resolveDirectory ?? _defaultDirectory;

  static const _fileName = 'playlist.json';
  static const _version = 2;

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
  ///
  /// **写入串行化**: 保存是 fire-and-forget, 切曲/节流/排序可能密集并发
  /// 触发 — 并发 `writeAsString` 的 open/write/close 交错会让旧快照
  /// 后完成、覆盖新快照. 链式队列保证按调用顺序落盘 (last-call-wins).
  Future<void> save(PersistedPlaylistSnapshot snapshot) {
    final operation = _writeQueue.then((_) => _write(snapshot));
    // 链续接吞异常防断裂 — _write 内部已捕获 Exception, 此处兜底.
    _writeQueue = operation.catchError((Object _) {});
    return operation;
  }

  /// 串行写入队列 — 所有 save 依次执行.
  Future<void> _writeQueue = Future<void>.value();

  Future<void> _write(PersistedPlaylistSnapshot snapshot) async {
    try {
      final directory = await _resolveDirectory();
      final file = File('${directory.path}/$_fileName');
      final json = {
        'version': _version,
        'playMode': snapshot.playMode.name,
        'sortKey': snapshot.sortKey.name,
        'sortAscending': snapshot.sortAscending,
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

    // 排序状态 (v2 新增) — 缺失/越界回退默认 (v1 文件路径).
    final rawSortKey = decoded['sortKey'];
    final sortKey = PlaylistSortKey.values.firstWhere(
      (k) => k.name == rawSortKey,
      orElse: () => PlaylistSortKey.addedOrder,
    );
    final rawAscending = decoded['sortAscending'];
    final sortAscending = rawAscending is bool ? rawAscending : true;

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
    // v1 迁移: 条目缺 addedSeq 按数组下标合成 — 旧文件顺序即添加顺序.
    for (var i = 0; i < items.length; i++) {
      if (items[i].addedSeq == null) {
        items[i] = items[i].copyWith(addedSeq: i);
      }
    }
    return PersistedPlaylistSnapshot(
      items: items,
      playMode: playMode,
      sortKey: sortKey,
      sortAscending: sortAscending,
    );
  }
}
