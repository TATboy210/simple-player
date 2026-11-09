/// 引擎队列观察器 — 把 (paths, index) 快照流归约为"变化事件" (从 PlaylistCoordinator 拆出).
///
/// Queue observer: reduces the engine's (paths, index) snapshot stream into
/// transitions. Holds only the previous snapshot; knows nothing of the engine.
library;

import 'package:flutter/foundation.dart';

/// 一次队列快照相对上一次的变化.
class QueueTransition {
  /// 创建变化记录.
  const QueueTransition({
    required this.queueChanged,
    required this.previousPlayingPath,
    required this.currentPlayingPath,
  });

  /// 队列内容 (paths) 相对上次是否变化 (首次观察视为变化).
  final bool queueChanged;

  /// 上一次正在播放的条目 path (null = 当时未播放).
  final String? previousPlayingPath;

  /// 本次正在播放的条目 path (null = 未播放 / stop 的空装载回流).
  final String? currentPlayingPath;

  /// 切曲/换队列/删正在播跳转: 上一次正在播的条目已不是当前条目.
  bool get playingChanged => previousPlayingPath != currentPlayingPath;
}

/// 队列快照观察器.
class QueueObserver {
  /// 上一次处理的引擎队列快照 (切曲检测基准).
  List<String>? _paths;
  String? _playingPath;

  /// 上一次处理的引擎队列索引 (identity 快路径比对基准, v0.0.9 P1).
  int _index = -1;

  /// 上一次观察到的正在播放条目 path.
  String? get playingPath => _playingPath;

  /// 观察一次快照; 与上次逐字节等价时返回 null (快路径短路).
  ///
  /// identity 快路径 (v0.0.9 P1 事件放大治理) — 引擎每次队列变化都新建
  /// unmodifiable List, 引用相同 + index 相同 ⇒ 快照等价, 重复通知零成本
  /// 短路 (跳过 O(n) 比较与潜在落盘).
  ///
  /// Side effect: 更新内部基准快照 (调用方应在处理完变化后不再回读旧值).
  QueueTransition? observe(List<String> paths, int index) {
    if (identical(paths, _paths) && index == _index) return null;

    final current = (index >= 0 && index < paths.length) ? paths[index] : null;
    final transition = QueueTransition(
      queueChanged: !listEquals(paths, _paths),
      previousPlayingPath: _playingPath,
      currentPlayingPath: current,
    );
    _paths = List.unmodifiableOf(paths);
    _playingPath = current;
    _index = index;
    return transition;
  }
}
