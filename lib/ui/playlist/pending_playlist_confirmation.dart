import 'dart:async';

import '../../kernel/models/playlist_item.dart';

/// 删除确认快照 — 在用户异步抉择前冻结目标身份 (原始索引 + 条目引用)。
///
/// Freezes path identity before any asynchronous user choice.
///
/// 冻结身份 = (原始索引, addedSeq, path) 三元组。addedSeq 是 path 级稳定
/// 身份 (PlaylistCoordinator._metaByPath 按 path 缓存且必须稳定持久),
/// 生产环境的重复条目 = 同一 PlaylistItem 实例占据多个队列位置, 孪生之间
/// path 与 addedSeq 完全相同、不可区分 — 精确性由冻结原始索引承担:
/// 确认后回放时, 冻结位上的 (path, addedSeq) 仍相符则直取该位; 否则按
/// (path, addedSeq) 在当前列表恰好唯一命中才回退; 0 命中 (目标消失) 或
/// 多命中 (冻结位失效的孪生歧义) 一律跳过 — 宁可不删, 绝不误删。
class PendingPlaylistConfirmation {
  /// 冻结快照工厂 — [indices] 中所有界内位置一律保留 (含同 path 重复条目;
  /// H3: 旧实现把重复 path 的索引全部丢弃, 导致单条删除完全失效), 越界
  /// 索引丢弃。[message] 以冻结后的目标计数求值, 确认文案计数由此结构性
  /// 等于冻结目标数 (确认后队列再变动也不改变已展示的文案)。
  factory PendingPlaylistConfirmation({
    required String Function(int targetCount) message,
    required List<PlaylistItem> entries,
    required Set<int> indices,
  }) {
    final frozen = <({int index, PlaylistItem item})>[
      for (final index in indices)
        if (index >= 0 && index < entries.length)
          (index: index, item: entries[index]),
    ];
    return PendingPlaylistConfirmation._(
      message(frozen.length),
      List.unmodifiable(frozen),
    );
  }

  /// 私有构造 — [targets] 已冻结, [message] 已按冻结计数求值。
  PendingPlaylistConfirmation._(this.message, this._targets);

  /// 确认文案 — factory 内按冻结计数求值, 之后不再变化。
  final String message;

  /// 冻结目标记录 — (原始索引, 条目) 同构锁步; 条目自带 path/addedSeq。
  final List<({int index, PlaylistItem item})> _targets;

  /// 冻结目标计数 — 确认文案与实际删除数的对账基准。
  int get targetCount => _targets.length;

  /// 是否无有效冻结目标 (全部索引越界) — 调用方据此放弃弹卡。
  bool get isEmpty => _targets.isEmpty;

  final Completer<bool> _result = Completer<bool>();
  Future<bool> get result => _result.future;

  /// Complete once; owner hide/replacement and user choice may race.
  void complete(bool confirmed) {
    if (!_result.isCompleted) _result.complete(confirmed);
  }

  /// 在提交时刻同步回放冻结意图于 [entries] — 每目标至多解析出 1 个索引:
  /// (a) 冻结原始索引仍在界内且该位置 (path, addedSeq) 相符 → 直取;
  /// (b) 否则收集 (path, addedSeq) 双匹配位置, 恰好唯一才回退;
  /// (c) 0 个 (消失) 或多个 (孪生歧义) → 跳过, 绝不把一条确认展开成多条删除。
  Set<int> resolve(List<PlaylistItem> entries) {
    final hits = <int>{};
    for (final target in _targets) {
      final resolved = _resolveTarget(entries, target.index, target.item);
      if (resolved != null) hits.add(resolved);
    }
    return Set.unmodifiable(hits);
  }

  /// 单目标三段式解析 — 无精确命中时返回 null (跳过该目标)。
  static int? _resolveTarget(
    List<PlaylistItem> entries,
    int index,
    PlaylistItem item,
  ) {
    // (a) 冻结位优先 — 位置仍在界内且身份未变, 精确命中用户所点那一格。
    if (index < entries.length &&
        entries[index].path == item.path &&
        entries[index].addedSeq == item.addedSeq) {
      return index;
    }
    // (b) 唯一回退 — 列表移位后按 (path, addedSeq) 收集全部双匹配位置。
    final matches = <int>[
      for (var i = 0; i < entries.length; i++)
        if (entries[i].path == item.path &&
            entries[i].addedSeq == item.addedSeq)
          i,
    ];
    // (c) 0 命中 = 目标消失; 多命中 = 冻结位失效的孪生歧义 — 一律跳过。
    return matches.length == 1 ? matches.single : null;
  }
}
