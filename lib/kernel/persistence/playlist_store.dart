import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../diagnostics/kernel_logger.dart';
import '../models/play_mode.dart';
import '../models/playlist_item.dart';
import '../models/playlist_sort.dart';

final _log = KernelLogger.I;

/// 播放列表持久化快照 — 队列条目（含断点元数据）、播放模式、排序状态
/// 与上次播放锚点.
///
/// Persisted playlist snapshot — queue entries (with resume metadata),
/// play mode, sort state and last-played anchor. [items] 顺序即队列顺序.
class PersistedPlaylistSnapshot {
  const PersistedPlaylistSnapshot({
    required this.items,
    required this.playMode,
    this.sortKey = PlaylistSortKey.addedOrder,
    this.sortAscending = true,
    this.lastPlayedPath,
  });

  /// 队列条目 — 顺序即队列顺序, 各条目携带断点/时间戳元数据.
  final List<PlaylistItem> items;

  /// 上次的播放模式.
  final PlayMode playMode;

  /// 上次的排序键 (v0.0.6).
  final PlaylistSortKey sortKey;

  /// 上次的排序方向 (v0.0.6).
  final bool sortAscending;

  /// 上次播放的条目路径 (v0.0.6.2) — 恢复后逻辑高亮 + 一键续播锚点.
  ///
  /// 用 path 不用 index: 排序/删除会使 index 漂移 (mpv watch-later 同为
  /// 按文件路径记位); path 不在队列时高亮自然不渲染, 无需清理.
  final String? lastPlayedPath;
}

/// 播放列表持久化 — 纯文本 JSON（Unix 原则: flat text files）.
///
/// Playlist persistence — plain-text JSON at
/// `<ApplicationSupport>/playlist.json`. 结构 (version 3, v0.0.6.2):
/// ```json
/// {
///   "version": 3,
///   "playMode": "loopAll",
///   "sortKey": "addedOrder",
///   "sortAscending": true,
///   "lastPlayedPath": "D:/a.mp4",
///   "items": [{"path": "D:/a.mp4", "positionMs": 1200, "durationMs": 90000,
///              "addedSeq": 0}]
/// }
/// ```
///
/// 迁移契约 (v1 → v2 → v3, 双向向后兼容):
/// - 读 v1 (或条目缺 `addedSeq`): 排序状态回退默认 (addedOrder/升序),
///   addedSeq 由上层按数组下标合成 — 旧文件顺序即添加顺序.
/// - 读 v2 (或顶层缺 `lastPlayedPath`): 该字段回退 null — 启动后无
///   "上次播放"高亮, 断点/排序照常恢复; 下次保存即升级为 v3.
/// - 旧版本 app 读 v3: 不校验 version、fromJson 丢弃未知 key → 完全兼容.
///
/// 容错契约: 文件缺失 / JSON 损坏 / 字段类型异常 → [load] 返回 null
/// （视作"无历史"），绝不抛出到调用方; [save] 失败仅记日志.
/// 损坏文件额外隔离为 `playlist.json.corrupt` 留存（单代, 覆盖旧代）—
/// 现场可回溯, 不再被下次 save 静默覆盖.
///
/// 原子发布契约: save 走 temp(`.part`)→flush→rename — 目标只被完整
/// JSON 一次性替换, 崩溃不产生半截 playlist.json; 发布失败时旧文件
/// 原样保留; 成功发布后清扫历史 `.part` 残留.
class PlaylistStore {
  /// [resolveDirectory] 可注入以隔离测试; 默认 Application Support 目录.
  PlaylistStore({Future<Directory> Function()? resolveDirectory})
    : _resolveDirectory = resolveDirectory ?? _defaultDirectory;

  static const _fileName = 'playlist.json';
  static const _version = 3;

  /// 检疫文件后缀 — `<原路径>.corrupt`, 仅保留一代.
  static const _corruptSuffix = '.corrupt';

  final Future<Directory> Function() _resolveDirectory;

  static Future<Directory> _defaultDirectory() =>
      getApplicationSupportDirectory();

  /// 读取持久化快照; 无文件或损坏时返回 null.
  ///
  /// 损坏处理: 成功读入但解析失败 → 文件原子改名 `.corrupt` 隔离留存
  /// （单代）— 损坏现场可回溯; 读失败/文件缺失仅记日志, 不隔离.
  Future<PersistedPlaylistSnapshot?> load() async {
    try {
      final directory = await _resolveDirectory();
      final file = File('${directory.path}/$_fileName');
      if (!await file.exists()) return null;
      final String content;
      try {
        content = await file.readAsString();
      } on Exception catch (error, stackTrace) {
        // 读失败（锁/IO 瞬时故障）— 视作无历史, 原文件原地保留待下次重试.
        _log.w(
          'PlaylistStore: failed to read playlist.json',
          context: {
            'error': error.toString(),
            'stackTrace': stackTrace.toString(),
          },
        );
        return null;
      }
      final snapshot = _parse(content);
      // 成功读入但解析失败 = 文件损坏 — 隔离取证, 不再无声覆盖销毁证据.
      if (snapshot == null) await _quarantineCorrupt(file);
      return snapshot;
    } on Exception catch (error, stackTrace) {
      // 损坏文件视作无历史 — 播放列表不是关键数据, 不值得打断启动.
      _log.w(
        'PlaylistStore: failed to load playlist.json',
        context: {
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      return null;
    }
  }

  /// 损坏文件检疫 — 原子改名为 `<原路径>.corrupt` 隔离留存（仅一代）.
  ///
  /// Dart `File.rename` 在 Windows 走
  /// `MoveFileExW(MOVEFILE_WRITE_THROUGH | MOVEFILE_REPLACE_EXISTING)`
  /// （runtime/bin/file_win.cc）— 目标已存在时单系统调用原子替换,
  /// 因此**不要预删除旧 .corrupt**（预删除会引入"证据短暂消失"空窗,
  /// rename-over-existing 同时达成覆盖与无空窗）.
  /// rename 失败（杀软/另一实例锁住）→ 原文件原地保留, 仅记日志 —
  /// best-effort: 证据留存失败可接受, 原文件留待下次 save 覆盖.
  Future<void> _quarantineCorrupt(File file) async {
    try {
      // 字节数须在 rename 前采集 — rename 后原路径已不存在.
      final bytes = await file.length();
      await file.rename('${file.path}$_corruptSuffix');
      _log.w(
        'PlaylistStore: corrupt playlist.json quarantined',
        context: {'file': file.path, 'bytes': bytes},
      );
    } on FileSystemException catch (error) {
      _log.w(
        'PlaylistStore: failed to quarantine corrupt playlist.json',
        context: {'file': file.path, 'error': error.toString()},
      );
    }
  }

  /// 保存快照; 失败仅记日志（断点丢失可接受, 不打断播放流程）.
  ///
  /// **写入串行化**: 保存是 fire-and-forget, 切曲/节流/排序可能密集并发
  /// 触发 — 并发 `writeAsString` 的 open/write/close 交错会让旧快照
  /// 后完成、覆盖新快照. 链式队列保证按调用顺序落盘 (last-call-wins).
  Future<void> save(PersistedPlaylistSnapshot snapshot) {
    // 链式续接是写入串行化的核心模式 — async/await 改写会破坏 last-call-wins.
    // ignore: prefer-async-await
    final operation = _writeQueue.then((_) => _write(snapshot));
    // 链续接吞异常防断裂 — _write 内部已捕获 Exception, 此处兜底.
    // 空块刻意: 断链异常已由 _write 记日志, 此处仅维持队列不断裂.
    // ignore: no-empty-block
    _writeQueue = operation.catchError((Object _) {});
    return operation;
  }

  /// 串行写入队列 — 所有 save 依次执行.
  Future<void> _writeQueue = Future<void>.value();

  /// temp 唯一后缀计数器 — microseconds + counter（§30.5, 同
  /// thumbnail_disk_cache 方案; 写入已由 _writeQueue 串行化,
  /// counter 仅为防御性唯一性）.
  int _writeCounter = 0;

  Future<void> _write(PersistedPlaylistSnapshot snapshot) async {
    try {
      final directory = await _resolveDirectory();
      final json = <String, Object?>{
        'version': _version,
        'playMode': snapshot.playMode.name,
        'sortKey': snapshot.sortKey.name,
        'sortAscending': snapshot.sortAscending,
        // null 省略 — 与 PlaylistItem.toJson 同惯例, 缩短人读文件.
        if (snapshot.lastPlayedPath != null)
          'lastPlayedPath': snapshot.lastPlayedPath,
        'items': [for (final item in snapshot.items) item.toJson()],
      };
      await _publishAtomic(directory, jsonEncode(json));
      // rename 成功 = 发布完成 — 此刻清扫历史崩溃 .part 残留（见清扫注释）.
      await _sweepStaleParts(directory);
    } on Exception catch (error) {
      _log.w(
        'PlaylistStore: failed to save playlist.json',
        context: {'error': error.toString()},
      );
    }
  }

  /// 原子发布 — temp 完整写毕（含 flush）后 rename 一次性替换目标.
  ///
  /// Atomic publish: temp → flush → rename. Dart `File.rename` 在 Windows
  /// 走 `MoveFileExW(MOVEFILE_WRITE_THROUGH | MOVEFILE_REPLACE_EXISTING)`
  /// （runtime/bin/file_win.cc）— 目标已存在时单系统调用原子替换, 无
  /// "新旧皆无"空窗; 因此**禁止预删除目标** — thumbnail_disk_cache 的
  /// 先删后改名是 forceRefresh 场景取舍, 此处照抄会引入数据丢失空窗
  /// （崩溃恰落在删除与 rename 之间 → playlist.json 整个消失）.
  Future<void> _publishAtomic(Directory directory, String contents) async {
    final target = File('${directory.path}/$_fileName');
    // temp 唯一后缀 — microseconds + 进程内计数器（§30.5, M1）.
    final suffix = '${DateTime.now().microsecondsSinceEpoch}-${++_writeCounter}';
    final temp = File('${target.path}.$suffix.part');
    try {
      // flush 是崩溃安全的前提 — 数据确实落盘后 rename 替换才有意义.
      await temp.writeAsString(contents, flush: true);
      await temp.rename(target.path);
    } on Exception {
      // 发布失败 — temp 残留 best-effort 清除（锁场景可能仍失败, 吞掉,
      // 由下次成功发布后的清扫兜底）; 旧目标文件未被动过, 历史无损.
      try {
        if (await temp.exists()) await temp.delete();
      } on FileSystemException {
        // best effort — 残留 .part 留待下次清扫
      }
      rethrow;
    }
  }

  /// 清扫 `.part` 崩溃残留 — 历史中断写入不再无限累积（T-261009-fj2-03）.
  ///
  /// 调用时机安全性: 本 save 的 temp 已被 rename 消费, 且写入由
  /// _writeQueue 串行化 — 此刻目录内不存在正在写的 temp, 整体清扫无竞争.
  /// 逐个 best-effort 吞异常（单文件被锁不影响其余）; 目录不可列（锁/权限）
  /// 时整体放弃, 残留留待下次 — 不影响本次 save 已成功的事实.
  Future<void> _sweepStaleParts(Directory directory) async {
    try {
      await for (final entity in directory.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (name.startsWith('$_fileName.') && name.endsWith('.part')) {
          try {
            await entity.delete();
          } on FileSystemException {
            // best effort — 留待下次清扫
          }
        }
      }
    } on FileSystemException {
      // 目录不可列 — 残留留待下次, 本此 save 已成功
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

    // 上次播放锚点 (v3 新增) — 缺失/类型异常回退 null (v2/v1 文件路径).
    final rawLastPlayed = decoded['lastPlayedPath'];
    final lastPlayedPath = rawLastPlayed is String ? rawLastPlayed : null;

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
      lastPlayedPath: lastPlayedPath,
    );
  }
}
