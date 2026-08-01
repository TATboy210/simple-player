// ignore_for_file: unnecessary_getters_setters
import 'dart:math';

import '../models/playlist_item.dart';
import '../models/play_mode.dart';
import '../diagnostics/kernel_logger.dart';

final _log = KernelLogger.I;

/// 播放列表管理 — 状态机.
///
/// Playlist model — state machine for ordered media items.
///
/// Core responsibilities:
///   - Maintains ordered playlist items.
///   - Tracks current index (auto-adjusts on add/remove/reorder).
///   - Navigation logic for 4 play modes (loopAll, loopSingle, shuffle).
///   - JSON serialization/deserialization (defensive, index clamping).
///
/// Design principles:
///   - CQS separation: [peekNext]/[peekPrevious] return index without mutating state.
///   - Caller updates state via [currentIndex] setter.
///   - [items] returns `List.unmodifiable` to prevent external mutation.
class Playlist {
  final List<PlaylistItem> _items = [];
  int _currentIndex = -1;
  PlayMode _mode = PlayMode.loopAll;
  final _random = Random();

  Playlist();

  // ─── 查询 ───

  List<PlaylistItem> get items => List.unmodifiable(_items);
  int get length => _items.length;
  int get currentIndex => _currentIndex;
  PlayMode get mode => _mode;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  /// 当前播放项，索引无效时返回 null.
  ///
  /// Current playlist item; null if index is invalid.
  PlaylistItem? get current =>
      (_currentIndex >= 0 && _currentIndex < _items.length)
      ? _items[_currentIndex]
      : null;

  bool get hasNext => _items.isNotEmpty;

  bool get hasPrevious => _items.isNotEmpty;

  // ─── 修改 ───

  /// 设置当前索引（范围校验）.
  ///
  /// Sets current index (range-validated).
  set currentIndex(int value) {
    if (value >= -1 && value < _items.length) {
      _currentIndex = value;
    }
  }

  /// 设置播放模式.
  ///
  /// Sets play mode.
  set mode(PlayMode value) {
    _mode = value;
  }

  /// 添加文件到列表末尾，返回新索引.
  ///
  /// Appends a file to the list; returns the new index.
  int add(String path) {
    _items.add(PlaylistItem(path: path));
    if (_currentIndex < 0) _currentIndex = 0;
    return _items.length - 1;
  }

  /// 添加完整的 item（保留历史元数据），用于从持久化恢复.
  ///
  /// Adds a full [PlaylistItem] (preserving history metadata) — used for restore.
  int addItem(PlaylistItem item) {
    _items.add(item);
    if (_currentIndex < 0) _currentIndex = 0;
    return _items.length - 1;
  }

  /// 批量添加.
  ///
  /// Batch-adds file paths.
  void addAll(List<String> paths) {
    for (final p in paths) {
      add(p);
    }
  }

  /// 移除指定索引的项，返回是否成功.
  ///
  /// Removes item at [index]; returns success.
  /// Index adjustment rules:
  ///   - Removed before current → currentIndex--
  ///   - Removed current → index points to next (clamped to last)
  ///   - List empty → currentIndex = -1
  bool removeAt(int index) {
    if (index < 0 || index >= _items.length) return false;
    _items.removeAt(index);

    if (_items.isEmpty) {
      _currentIndex = -1;
    } else if (index < _currentIndex) {
      _currentIndex--;
    } else if (index == _currentIndex) {
      _currentIndex = _currentIndex.clamp(0, _items.length - 1);
    }
    return true;
  }

  /// 拖拽排序: 将 [oldIndex] 移动到 [newIndex].
  ///
  /// Drag-reorder: moves item from [oldIndex] to [newIndex].
  /// ReorderableListView convention: when oldIndex < newIndex, newIndex is pre-decremented.
  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _items.length) return;
    if (newIndex < 0 || newIndex >= _items.length) return;
    if (oldIndex == newIndex) return;

    final item = _items.removeAt(oldIndex);
    _items.insert(newIndex, item);

    // 跟踪当前播放项
    if (_currentIndex == oldIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }
  }

  /// 清空列表.
  ///
  /// Clears the playlist.
  void clear() {
    _items.clear();
    _currentIndex = -1;
  }

  /// 更新当前项的历史元数据（播放成功时调用）.
  ///
  /// Updates history metadata (timestamp=now + positionMs/durationMs).
  /// Does not change list order.
  void updateHistory(int index, {int? positionMs, int? durationMs}) {
    if (index < 0 || index >= _items.length) return;
    final old = _items[index];
    _items[index] = old.copyWith(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      positionMs: positionMs ?? old.positionMs,
      durationMs: durationMs ?? old.durationMs,
    );
  }

  /// 更新断点位置（暂停/退出时调用，不改变 timestamp）.
  ///
  /// Updates breakpoint position (called on pause/exit); preserves timestamp.
  void updatePosition(int index, int positionMs, int? durationMs) {
    if (index < 0 || index >= _items.length) return;
    final old = _items[index];
    _items[index] = old.copyWith(
      positionMs: positionMs,
      durationMs: durationMs ?? old.durationMs,
    );
  }

  /// 从旧 history 数据合并元数据（一次性迁移用）.
  ///
  /// Merges legacy history metadata (one-time migration).
  /// - Existing items: merges timestamp/positionMs/durationMs by path match.
  /// - Items in history but not in playlist: appended to end.
  void mergeHistory(Map<String, Map<String, dynamic>> historyMap) {
    // 更新已有项
    for (var i = 0; i < _items.length; i++) {
      final hist = historyMap[_items[i].path];
      if (hist != null) {
        final old = _items[i];
        _items[i] = old.copyWith(
          timestamp: (hist['timestamp'] as num?)?.toInt() ?? old.timestamp,
          positionMs: (hist['positionMs'] as num?)?.toInt() ?? old.positionMs,
          durationMs: (hist['durationMs'] as num?)?.toInt() ?? old.durationMs,
        );
      }
    }
    // 添加 history 中有但 playlist 没有的项
    for (final entry in historyMap.entries) {
      if (!_items.any((item) => item.path == entry.key)) {
        final map = entry.value;
        _items.add(
          PlaylistItem(
            path: entry.key,
            timestamp: (map['timestamp'] as num?)?.toInt(),
            positionMs: (map['positionMs'] as num?)?.toInt(),
            durationMs: (map['durationMs'] as num?)?.toInt(),
          ),
        );
      }
    }
    if (_currentIndex < 0 && _items.isNotEmpty) {
      _currentIndex = 0;
    }
  }

  // ─── 导航（CQS: 只返回索引，不修改状态） ───
  //
  // 设计决策: peekNext/peekPrevious 是纯查询，不修改 _currentIndex。
  // 调用方（PlaybackController）拿到索引后显式设置 currentIndex。
  // 对比旧代码的 next()/previous() 既返回值又修改状态，违反 CQS 原则，
  // 导致 bug 难以追踪（"我只查了一下，为什么状态变了？"）。

  /// 计算下一首的索引；没有下一首返回 -1.
  ///
  /// Calculates next index; -1 if no next. Does NOT mutate [_currentIndex];
  /// caller must set [currentIndex] explicitly (CQS).
  int peekNext() {
    if (_items.isEmpty) return -1;

    switch (_mode) {
      case PlayMode.loopAll:
        return (_currentIndex + 1) % _items.length;
      case PlayMode.loopSingle:
        return _currentIndex;
      case PlayMode.shuffle:
        if (_items.length == 1) return _currentIndex;
        int next;
        do {
          next = _random.nextInt(_items.length);
        } while (next == _currentIndex);
        return next;
    }
  }

  /// 计算上一首的索引；没有上一首返回 -1.
  ///
  /// Calculates previous index; -1 if no previous. Does NOT mutate [_currentIndex];
  /// caller must set [currentIndex] explicitly (CQS).
  int peekPrevious() {
    if (_items.isEmpty) return -1;

    switch (_mode) {
      case PlayMode.loopAll:
        return (_currentIndex - 1 + _items.length) % _items.length;
      case PlayMode.loopSingle:
        return _currentIndex;
      case PlayMode.shuffle:
        if (_items.length == 1) return _currentIndex;
        int prev;
        do {
          prev = _random.nextInt(_items.length);
        } while (prev == _currentIndex);
        return prev;
    }
  }

  // ─── 序列化 ───

  Map<String, dynamic> toJson() => {
    'mode': _mode.index,
    'currentIndex': _currentIndex,
    'items': _items.map((e) => e.toJson()).toList(),
  };

  factory Playlist.fromJson(Map<String, dynamic> json) {
    final playlist = Playlist();

    // 播放模式（防御: 越界回退 loopAll，类型安全转换）
    final rawMode = json['mode'];
    final modeIndex = (rawMode is num) ? rawMode.toInt() : 0;
    playlist._mode = (modeIndex >= 0 && modeIndex < PlayMode.values.length)
        ? PlayMode.values[modeIndex]
        : PlayMode.loopAll;

    // 播放项（逐项 try-catch，损坏项跳过）
    final items = json['items'] as List<dynamic>? ?? [];
    for (final item in items) {
      try {
        playlist._items.add(
          PlaylistItem.fromJson(item as Map<String, dynamic>),
        );
      } on Exception catch (e) {
        _log.w('Playlist.fromJson: skipping corrupted item: $e');
      }
    }

    // 当前索引（防御: clamp 到有效范围，类型安全转换）
    final rawIndex = json['currentIndex'];
    playlist._currentIndex = (rawIndex is num) ? rawIndex.toInt() : -1;
    if (playlist._items.isEmpty) {
      playlist._currentIndex = -1;
    } else {
      playlist._currentIndex = playlist._currentIndex.clamp(
        0,
        playlist._items.length - 1,
      );
    }

    return playlist;
  }

  @override
  String toString() =>
      'Playlist(${_items.length} items, index=$_currentIndex, mode=$_mode)';
}
