/// 条目元数据缓存 — path → PlaylistItem + addedSeq 分配 (从 PlaylistCoordinator 拆出).
///
/// Per-path metadata cache that owns the monotonic `addedSeq` counter.
library;

import '../models/playlist_item.dart';

/// path 键元数据缓存.
///
/// 队列重建时按 path 合并; 条目移除后不主动清理 (量级 = 用户看过的文件数,
/// 内存影响可忽略), 仅显式 [remove] 时丢弃 (用户主动删除).
class PlaylistMetaCache {
  final Map<String, PlaylistItem> _byPath = <String, PlaylistItem>{};

  /// 下一个待分配的添加顺序序号 — 单调递增, 只增不回收
  /// (删除留下空洞无碍排序语义).
  int _nextAddedSeq = 0;

  /// 取已登记条目, 无则 null.
  PlaylistItem? operator [](String path) => _byPath[path];

  /// 取条目元数据; 新 path 分配 addedSeq 并登记.
  ///
  /// addedSeq 是排序键 addedOrder 的数据前提, 必须稳定持久
  /// (on-the-fly 生成会随重建漂移).
  PlaylistItem itemFor(String path) {
    final existing = _byPath[path];
    if (existing != null) return existing;
    final created = PlaylistItem(path: path, addedSeq: _nextAddedSeq++);
    _byPath[path] = created;
    return created;
  }

  /// 覆盖登记 [path] 的元数据 (断点更新写入点).
  void put(String path, PlaylistItem item) => _byPath[path] = item;

  /// 丢弃 [path] 的元数据.
  void remove(String path) => _byPath.remove(path);

  /// 从磁盘快照恢复: 登记全部条目并把序号推进到 max(addedSeq)+1,
  /// 后续新增条目接着编号, 不与恢复值冲突.
  void restore(Iterable<PlaylistItem> items) {
    var maxSeq = -1;
    for (final item in items) {
      _byPath[item.path] = item;
      final seq = item.addedSeq;
      if (seq != null && seq > maxSeq) maxSeq = seq;
    }
    _nextAddedSeq = maxSeq + 1;
  }
}
