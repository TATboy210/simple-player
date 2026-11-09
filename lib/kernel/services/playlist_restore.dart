/// 播放列表启动恢复 — 守卫式读盘 + 幂等重排 (从 PlaylistCoordinator 拆出).
///
/// Startup restore helpers: guarded disk read and idempotent re-sort.
library;

import '../diagnostics/kernel_logger.dart';
import '../models/playlist_item.dart';
import '../models/playlist_sort.dart';
import '../persistence/playlist_store.dart';

final _log = KernelLogger.I;

/// 守卫式读取可恢复快照; 不应恢复时返回 null.
///
/// 守卫 (v0.0.9 P1 启动提速) — restore 已移出启动关键路径 (unawaited),
/// 用户可能在恢复完成前已拖入文件; [isEngineActive] 为真说明会话已开始,
/// 磁盘快照不得覆盖用户会话. 入口 + load 返回后双检封住异步间隙.
/// 快照缺失或为空同样返回 null.
Future<PersistedPlaylistSnapshot?> loadRestorableSnapshot(
  PlaylistStore store, {
  required bool Function() isEngineActive,
}) async {
  if (isEngineActive()) {
    _log.w(
      'PlaylistCoordinator: restore skipped — engine queue already '
      'active, disk snapshot would shadow the live session',
    );
    return null;
  }
  final snapshot = await store.load();
  if (isEngineActive()) {
    _log.w(
      'PlaylistCoordinator: restore skipped after load — engine queue '
      'became active during disk read',
    );
    return null;
  }
  if (snapshot == null || snapshot.items.isEmpty) return null;
  return snapshot;
}

/// 按快照记录的排序状态幂等重放排序.
///
/// 恢复顺序即上次落盘顺序, 已排序时恒等 (addedOrder 模式下重放按
/// addedSeq 归位, 修正手工删改造成的漂移). 返回新的可变列表.
List<PlaylistItem> replaySort(PersistedPlaylistSnapshot snapshot) {
  return [...snapshot.items]..sort(
    (a, b) => comparePlaylistEntries(
      a,
      b,
      key: snapshot.sortKey,
      ascending: snapshot.sortAscending,
    ),
  );
}
