// ignore_for_file: unnecessary_getters_setters
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/playlist_item.dart';
import '../models/play_mode.dart';

/// 播放列表管理 — 状态机
///
/// 核心职责:
///   - 维护有序播放项列表
///   - 跟踪当前播放索引（add/remove/reorder 时自动调整）
///   - 4 种播放模式的导航逻辑
///   - JSON 序列化/反序列化（防御式，索引 clamp）
///
/// 设计原则:
///   - CQS 分离: next()/previous() 只返回新索引，不修改内部状态
///   - 调用方通过 currentIndex setter 更新状态
///   - items 返回 List.unmodifiable 防止外部篡改
class Playlist {
  final List<PlaylistItem> _items = [];
  int _currentIndex = -1;
  PlayMode _mode = PlayMode.normal;
  final _random = Random();

  Playlist();

  // ─── 查询 ───

  List<PlaylistItem> get items => List.unmodifiable(_items);
  int get length => _items.length;
  int get currentIndex => _currentIndex;
  PlayMode get mode => _mode;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  /// 当前播放项，索引无效时返回 null
  PlaylistItem? get current =>
      (_currentIndex >= 0 && _currentIndex < _items.length)
          ? _items[_currentIndex]
          : null;

  bool get hasNext {
    if (_items.isEmpty) return false;
    switch (_mode) {
      case PlayMode.normal:
        return _currentIndex < _items.length - 1;
      case PlayMode.loopAll:
      case PlayMode.loopSingle:
      case PlayMode.shuffle:
        return true;
    }
  }

  bool get hasPrevious {
    if (_items.isEmpty) return false;
    switch (_mode) {
      case PlayMode.normal:
        return _currentIndex > 0;
      case PlayMode.loopAll:
      case PlayMode.loopSingle:
      case PlayMode.shuffle:
        return true;
    }
  }

  // ─── 修改 ───

  /// 设置当前索引（范围校验）
  set currentIndex(int value) {
    if (value >= -1 && value < _items.length) {
      _currentIndex = value;
    }
  }

  /// 设置播放模式
  set mode(PlayMode value) {
    _mode = value;
  }

  /// 添加文件到列表末尾，返回新索引
  int add(String path) {
    _items.add(PlaylistItem(path: path));
    if (_currentIndex < 0) _currentIndex = 0;
    return _items.length - 1;
  }

  /// 添加完整的 item（保留历史元数据），用于从持久化恢复
  int addItem(PlaylistItem item) {
    _items.add(item);
    if (_currentIndex < 0) _currentIndex = 0;
    return _items.length - 1;
  }

  /// 批量添加
  void addAll(List<String> paths) {
    for (final p in paths) {
      add(p);
    }
  }

  /// 移除指定索引的项，返回是否成功
  ///
  /// 索引调整规则:
  ///   - 删除项在当前项之前 → currentIndex--
  ///   - 删除当前项 → 保持索引指向下一首（越界则指向最后一首）
  ///   - 列表清空 → currentIndex = -1
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

  /// 拖拽排序: 将 [oldIndex] 移动到 [newIndex]
  ///
  /// ReorderableListView 约定: oldIndex < newIndex 时，newIndex 已减 1。
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

  /// 清空列表
  void clear() {
    _items.clear();
    _currentIndex = -1;
  }

  /// 更新当前项的历史元数据（播放成功时调用）
  ///
  /// 设置 timestamp=now + positionMs/durationMs，不改变列表排序。
  void updateHistory(int index, {int? positionMs, int? durationMs}) {
    if (index < 0 || index >= _items.length) return;
    final old = _items[index];
    _items[index] = old.copyWith(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      positionMs: positionMs ?? old.positionMs,
      durationMs: durationMs ?? old.durationMs,
    );
  }

  /// 更新断点位置（暂停/退出时调用，不改变 timestamp）
  void updatePosition(int index, int positionMs, int? durationMs) {
    if (index < 0 || index >= _items.length) return;
    final old = _items[index];
    _items[index] = old.copyWith(
      positionMs: positionMs,
      durationMs: durationMs ?? old.durationMs,
    );
  }

  /// 从旧 history 数据合并元数据（一次性迁移用）
  ///
  /// - 已有项：按 path 匹配合并 timestamp/positionMs/durationMs
  /// - history 中有但 playlist 没有的项：添加到末尾
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
        _items.add(PlaylistItem(
          path: entry.key,
          timestamp: (map['timestamp'] as num?)?.toInt(),
          positionMs: (map['positionMs'] as num?)?.toInt(),
          durationMs: (map['durationMs'] as num?)?.toInt(),
        ));
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

  /// 计算下一首的索引；没有下一首返回 -1
  ///
  /// 注意: 此方法不修改 _currentIndex，调用方需通过 currentIndex setter 更新。
  int peekNext() {
    if (_items.isEmpty) return -1;

    switch (_mode) {
      case PlayMode.normal:
        if (_currentIndex < _items.length - 1) {
          return _currentIndex + 1;
        }
        return -1;
      case PlayMode.loopAll:
        return (_currentIndex + 1) % _items.length;
      case PlayMode.loopSingle:
        return _currentIndex;
      case PlayMode.shuffle:
        // 单首歌直接返回自身（do-while 会死循环）
        if (_items.length == 1) return _currentIndex;
        // 随机选一首，排除当前首避免连续重复
        // do-while 安全：_items.length > 1 时保证能退出
        int next;
        do {
          next = _random.nextInt(_items.length);
        } while (next == _currentIndex);
        return next;
    }
  }

  /// 计算上一首的索引；没有上一首返回 -1
  ///
  /// 注意: 此方法不修改 _currentIndex，调用方需通过 currentIndex setter 更新。
  int peekPrevious() {
    if (_items.isEmpty) return -1;

    switch (_mode) {
      case PlayMode.normal:
        if (_currentIndex > 0) {
          return _currentIndex - 1;
        }
        return -1;
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

    // 播放模式（防御: 越界回退 normal）
    final modeIndex = (json['mode'] as num?)?.toInt() ?? 0;
    playlist._mode = (modeIndex >= 0 && modeIndex < PlayMode.values.length)
        ? PlayMode.values[modeIndex]
        : PlayMode.normal;

    // 播放项（逐项 try-catch，损坏项跳过）
    final items = json['items'] as List<dynamic>? ?? [];
    for (final item in items) {
      try {
        playlist._items.add(PlaylistItem.fromJson(item as Map<String, dynamic>));
      } on Exception catch (e) {
        debugPrint('Playlist.fromJson: skipping corrupted item: $e');
      }
    }

    // 当前索引（防御: clamp 到有效范围）
    playlist._currentIndex = (json['currentIndex'] as num?)?.toInt() ?? -1;
    if (playlist._items.isEmpty) {
      playlist._currentIndex = -1;
    } else {
      playlist._currentIndex =
          playlist._currentIndex.clamp(0, playlist._items.length - 1);
    }

    return playlist;
  }

  @override
  String toString() =>
      'Playlist(${_items.length} items, index=$_currentIndex, mode=$_mode)';
}
