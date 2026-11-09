/// 逻辑队列视图模型 — UI 数据源 notifier + 元数据缓存 + 写时复制变更 (从 PlaylistCoordinator 拆出).
///
/// Logical queue model: the single ValueNotifier the panel listens to, the
/// per-path metadata cache, and copy-on-write mutations. Every publish goes
/// through the one [notifier], so listeners keep a single notification point.
library;

import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/playlist_item.dart';
import 'playlist_meta_cache.dart';

/// 逻辑队列条目列表 (含断点元数据).
///
/// 发布的 List 恒为不可变快照: 任何变更都产生新快照 (写时复制), 旧快照对
/// 持有者保持不变. 单条替换只复制引用数组、不重建条目实例.
class PlaylistEntries {
  /// UI 面板的数据源 — 身份保持, UI 监听同一实例.
  final ValueNotifier<List<PlaylistItem>> notifier =
      ValueNotifier<List<PlaylistItem>>(const <PlaylistItem>[]);

  /// path → 元数据缓存 + addedSeq 分配.
  final PlaylistMetaCache meta = PlaylistMetaCache();

  /// 当前快照.
  List<PlaylistItem> get items => notifier.value;

  /// [path] 在当前快照中的索引, 不在则 -1.
  int indexOfPath(String path) => items.indexWhere((e) => e.path == path);

  /// 以引擎 paths 为准重建 (元数据按 path 合并, 顺序跟随引擎; 新 path 经
  /// [PlaylistMetaCache.itemFor] 登记并分配 addedSeq).
  void rebuildFrom(List<String> paths) {
    notifier.value = List.unmodifiableOf(<PlaylistItem>[
      for (final path in paths) meta.itemFor(path),
    ]);
  }

  /// 末尾追加 (保持引擎镜像顺序语义).
  void append(List<String> paths) {
    notifier.value = List.unmodifiableOf(<PlaylistItem>[
      ...items,
      for (final path in paths) meta.itemFor(path),
    ]);
  }

  /// 排除指定索引集合 (单/批量移除共用).
  void drop(Set<int> indices) {
    notifier.value = List.unmodifiableOf([
      for (var i = 0; i < items.length; i++)
        if (!indices.contains(i)) items[i],
    ]);
  }

  /// 整体替换 (手工重排/磁盘恢复).
  void replaceAll(List<PlaylistItem> next) {
    notifier.value = List.unmodifiableOf(next);
  }

  /// 单条替换: 复制引用数组后改一个槽位, 其余条目实例原样沿用
  /// (identical), 以不可变视图发布一次通知.
  void replaceAt(int index, PlaylistItem item) {
    final next = List<PlaylistItem>.of(items);
    next[index] = item;
    notifier.value = UnmodifiableListView<PlaylistItem>(next);
  }

  /// 释放 notifier.
  void dispose() => notifier.dispose();
}
