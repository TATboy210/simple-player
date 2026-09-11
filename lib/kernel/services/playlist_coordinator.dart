/// 播放列表协调器 — 队列视图、断点续播与持久化的服务层编排 (v0.0.5).
///
/// Playlist coordinator — queue view, resume breakpoints and persistence.
///
/// 架构位置: PlaylistPanel (UI) → **PlaylistCoordinator** → MediaEngine (QueueControl)
///
/// 职责切分（每层只做一件事）:
/// - mpv 原生 playlist = 引擎侧队列权威（装载/导航/循环/乱序）
/// - 本类 = **逻辑队列权威**（持久化语义）: 引擎 `stop` 清空装载队列时
///   逻辑队列保留（"停止"不清空面板列表）; 断点/时间戳元数据在此维护
/// - [PlaylistStore] = 纯文本 JSON 落盘
///
/// 同步模型（完全被动监听, 无主动轮询）:
/// - 引擎 queuePaths 变化（装载/追加/移除/乱序重排）→ 逻辑队列重建
///   （按 path 合并既有元数据, 空装载视作 stop — 保留逻辑队列）
/// - 引擎 queueIndex 变化（切曲/自动续播）→ 旧条目按 **path** 键更新断点
///   （索引键在整队列替换时会错位, path 键恒稳）→ 节流落盘
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../diagnostics/kernel_logger.dart';
import '../engine/engine_state.dart';
import '../models/play_mode.dart';
import '../models/playlist_item.dart';
import '../persistence/playlist_store.dart';

final _log = KernelLogger.I;

/// 播放列表协调器 — 逻辑队列 + 断点元数据 + 持久化的统一入口.
class PlaylistCoordinator {
  /// [_store] 为 null 时跳过持久化（纯内存模式, 测试便捷）.
  PlaylistCoordinator({required this._engine, this._store}) {
    // 只监听 queueRevision 单通知点 — paths/index 分开监听会读到
    // "新列表+旧索引"的中间态 (revision 保证两者都已赋值, 快照一致).
    _engine.queueRevision.addListener(_onQueueRevision);
    _engine.position.addListener(_trackPosition);
    _engine.duration.addListener(_trackDuration);
  }

  final MediaEngine _engine;
  final PlaylistStore? _store;

  /// 逻辑队列条目（含断点元数据）— UI 面板的数据源.
  final ValueNotifier<List<PlaylistItem>> _entries = ValueNotifier(
    const <PlaylistItem>[],
  );

  /// path → 元数据缓存. 队列重建时按 path 合并, 条目移除后不主动清理
  /// （断点元数据量级 = 用户看过的文件数, 内存影响可忽略）.
  final Map<String, PlaylistItem> _metaByPath = <String, PlaylistItem>{};

  /// 切曲前最后一次已知的 position/duration 快照 — 断点更新取材处.
  /// position 流高频但只写两个 int 字段, 无 notifier 通知, 开销可忽略.
  int _lastKnownPositionMs = 0;
  int _lastKnownDurationMs = 0;

  bool _disposed = false;

  // ============================================================
  // UI 视图
  // ============================================================

  /// 队列条目视图（断点元数据已合并）— 面板列表渲染用.
  ValueNotifier<List<PlaylistItem>> get entries => _entries;

  /// 当前播放条目索引 — 身份保持转发引擎镜像（-1 = 未播放）.
  ValueNotifier<int> get currentIndex => _engine.queueIndex;

  /// 当前播放模式 — 身份保持转发引擎镜像（引擎为模式单一数据源）.
  ValueNotifier<PlayMode> get playMode => _engine.playMode;

  // ============================================================
  // 动作转发
  // ============================================================

  /// 播放指定索引条目.
  ///
  /// 引擎装载队列与逻辑队列一致 → 直接 jumpTo（引擎已装载, 毫秒级切换）;
  /// 否则（停止态 / 磁盘恢复后首次点击）→ 装载完整逻辑队列并从该条目起播.
  Future<bool> playEntryAt(int index) async {
    final paths = <String>[for (final entry in _entries.value) entry.path];
    if (index < 0 || index >= paths.length) return false;

    if (_engineQueueMatches(paths)) {
      return _engine.jumpTo(index);
    }
    final result = await _engine.openPlaylist(paths, startIndex: index);
    switch (result) {
      case OpenSuccess():
        _engine.play();
        return true;
      case OpenError(:final error):
        _log.e(
          'PlaylistCoordinator: failed to play entry',
          context: {'error': error.message},
        );
        return false;
      case OpenSuperseded():
        return false;
    }
  }

  /// 移除指定索引条目 — 逻辑队列先行（UI 即时反馈）, 引擎装载时同步移除
  /// （空装载 no-op）; 删除正在播放条目的 mpv 自动跳转经 queueIndex 回流同步.
  Future<void> removeEntryAt(int index) async {
    final paths = <String>[for (final entry in _entries.value) entry.path];
    if (index < 0 || index >= paths.length) return;

    final removed = _entries.value[index];
    _metaByPath.remove(removed.path);
    _entries.value = List<PlaylistItem>.unmodifiable([
      for (var i = 0; i < _entries.value.length; i++)
        if (i != index) _entries.value[i],
    ]);

    await _engine.removeFromQueue(index);
    unawaited(_save());
  }

  /// 追加条目到队列末尾 — 引擎装载时走 mpv 原生 append（不打断当前播放）,
  /// 停止态仅扩充逻辑队列（下次装载生效）.
  Future<void> appendEntries(List<String> paths) async {
    if (paths.isEmpty) return;
    _appendToLogicalQueue(paths);
    await _engine.appendToQueue(paths);
    unawaited(_save());
  }

  /// 跳到下一个条目 — 边界回绕语义由引擎 [QueueControl] 统一裁定.
  bool next() => _engine.nextInQueue();

  /// 跳到上一个条目.
  bool previous() => _engine.previousInQueue();

  /// 断点续播指定索引条目 (v0.0.5) — 播放 + seek 到该条目的断点位置.
  ///
  /// **时序竞态修复** (media_kit 文档查证): `seek` 只等播放器初始化, 不等
  /// 新文件加载完成 — 装载/跳转后立即 seek 会被发到尚未切换的 mpv 状态
  /// 而丢失. 因此无论装载还是已装载分支, 一律记入 [_pendingResumeMs] 挂起,
  /// 由 [_trackPosition] 在"新条目开始播放"信号 (position 回到低位锁存区
  /// 且时长有效) 时补 seek — loadfile 完成后首个 position 事件必然落位.
  Future<bool> resumeEntryAt(int index) async {
    final items = _entries.value;
    if (index < 0 || index >= items.length) return false;
    final resumeMs = items[index].positionMs ?? 0;

    final ok = await playEntryAt(index);
    if (!ok) return false;
    if (resumeMs > 0) {
      _pendingResumeMs = resumeMs;
      _pendingResumeTimeout?.cancel();
      _pendingResumeTimeout = Timer(_resumeTimeout, () {
        if (_disposed) return;
        _pendingResumeMs = null; // 超时放弃 — 播放继续, 不悬挂
      });
    }
    return true;
  }

  /// 待补的断点 seek 位置 — null = 无挂起请求.
  int? _pendingResumeMs;
  Timer? _pendingResumeTimeout;

  /// 补 seek 的 position 低位锁存区 — 新条目开始播放时首个 position 事件
  /// 必然低于此值; 超出即视为非起始态 (旧条目残留事件), 继续等待.
  static const _resumeSeekLatchMs = 2000;

  /// 挂起 seek 超时兜底 — 媒体加载极慢 (网络流/损坏文件) 时低位信号
  /// 可能迟迟不到; 超时放弃挂起, 防悬挂 (断点丢失可接受, 播放不受阻).
  static const _resumeTimeout = Duration(seconds: 5);

  /// 设置播放模式 — 引擎为模式单一数据源, 本类仅落盘.
  Future<void> setPlayMode(PlayMode mode) async {
    await _engine.setPlayMode(mode);
    unawaited(_save());
  }

  /// 循环切换播放模式 — loopAll → loopSingle → shuffle → loopAll.
  ///
  /// UI (控制栏按钮/面板按钮) 共用此入口, 图标随引擎 playMode notifier 刷新.
  Future<void> cyclePlayMode() async {
    const cycle = {
      PlayMode.loopAll: PlayMode.loopSingle,
      PlayMode.loopSingle: PlayMode.shuffle,
      PlayMode.shuffle: PlayMode.loopAll,
    };
    await setPlayMode(cycle[_engine.playMode.value] ?? PlayMode.loopAll);
  }

  // ============================================================
  // 启动恢复
  // ============================================================

  /// 从磁盘恢复逻辑队列与播放模式 — **不装载 mpv 队列, 不自动播放**
  /// （装载留给用户首次点击条目时的 [playEntryAt] 装载分支）.
  Future<void> restoreFromDisk() async {
    final store = _store;
    if (store == null) return;
    final snapshot = await store.load();
    if (snapshot == null || snapshot.items.isEmpty) return;

    for (final item in snapshot.items) {
      _metaByPath[item.path] = item;
    }
    _entries.value = List<PlaylistItem>.unmodifiable(<PlaylistItem>[
      for (final item in snapshot.items) item,
    ]);
    // 模式恢复不装载队列也可设置（mpv 属性级, 队列空时无副作用）.
    await _engine.setPlayMode(snapshot.playMode);
    _log.i(
      'PlaylistCoordinator: restored queue from disk',
      context: {'count': snapshot.items.length, 'mode': snapshot.playMode.name},
    );
  }

  // ============================================================
  // 引擎镜像监听
  // ============================================================

  /// 上一次处理的引擎队列快照 (切曲检测基准).
  List<String>? _observedPaths;
  String? _observedPlayingPath;

  /// 引擎队列状态变化 (装载/追加/移除/乱序/切曲/自动续播) —
  /// revision 触发时 queuePaths 与 queueIndex 均已是最新值, 读到一致快照.
  void _onQueueRevision() {
    final paths = _engine.queuePaths.value;
    final index = _engine.queueIndex.value;
    final current = (index >= 0 && index < paths.length) ? paths[index] : null;

    final queueChanged =
        _observedPaths == null || !_listEquals(paths, _observedPaths!);
    if (queueChanged && paths.isNotEmpty) {
      // 装载/替换/移除/乱序 → 逻辑队列以引擎为准重建（元数据按 path 合并）.
      // 空装载（stop 的 playlist-clear）视作"停止" — 逻辑队列保留不清空.
      _rebuildEntries(paths);
    }

    // 切曲/换队列/删正在播跳转: 给"上一次正在播"的条目记断点.
    final previous = _observedPlayingPath;
    if (previous != null && previous != current) {
      _updateBreakpoint(previous);
    }
    _observedPaths = List<String>.unmodifiable(paths);
    _observedPlayingPath = current;

    if (queueChanged || previous != current) unawaited(_save());
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// 给指定 path 的条目写断点（最后位置 + 时长 + 时间戳）并刷新视图.
  /// 已从逻辑队列移除的条目跳过（删除正在播条目时触发的断点回写是无主记录）.
  void _updateBreakpoint(String path) {
    final existing = _metaByPath[path];
    if (existing == null && !_entries.value.any((e) => e.path == path)) {
      return; // 已移除且无元数据 — 不产生孤儿断点
    }
    final base = existing ?? PlaylistItem(path: path);
    final updated = base.copyWith(
      positionMs: _lastKnownPositionMs,
      durationMs: _lastKnownDurationMs > 0 ? _lastKnownDurationMs : null,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    _metaByPath[path] = updated;
    // 就地刷新视图中的同 path 条目（保持顺序不变）.
    _entries.value = List<PlaylistItem>.unmodifiable(<PlaylistItem>[
      for (final entry in _entries.value) entry.path == path ? updated : entry,
    ]);
  }

  /// 以引擎 paths 为准重建逻辑队列（元数据按 path 合并, 乱序重排后顺序跟随引擎）.
  void _rebuildEntries(List<String> paths) {
    _entries.value = List<PlaylistItem>.unmodifiable(<PlaylistItem>[
      for (final path in paths) _metaByPath[path] ?? PlaylistItem(path: path),
    ]);
  }

  /// 逻辑队列追加（保持引擎镜像顺序语义 — 末尾追加）.
  void _appendToLogicalQueue(List<String> paths) {
    _entries.value = List<PlaylistItem>.unmodifiable(<PlaylistItem>[
      ..._entries.value,
      for (final path in paths) _metaByPath[path] ?? PlaylistItem(path: path),
    ]);
  }

  /// 判断引擎装载队列与给定 paths 是否一致（playEntryAt 的跳转/装载分支判据）.
  bool _engineQueueMatches(List<String> paths) {
    final enginePaths = _engine.queuePaths.value;
    if (enginePaths.length != paths.length) return false;
    for (var i = 0; i < paths.length; i++) {
      if (enginePaths[i] != paths[i]) return false;
    }
    return true;
  }

  void _trackPosition() {
    _lastKnownPositionMs = _engine.position.value;
    // 断点续播补 seek — "新条目开始播放"锁存信号: position 落入低位区
    // 且时长有效. 一次性消费 (置 null), 后续 seek 本身产生的 position
    // 事件不会重复触发.
    final pending = _pendingResumeMs;
    if (pending != null &&
        _lastKnownPositionMs < _resumeSeekLatchMs &&
        _engine.duration.value > 0) {
      _pendingResumeMs = null;
      unawaited(_engine.seekTo(pending));
    }
  }

  void _trackDuration() {
    _lastKnownDurationMs = _engine.duration.value;
    // 断点续播的挂起 seek — duration 首次有效即补齐 (装载场景).
    final pending = _pendingResumeMs;
    if (pending != null && _lastKnownDurationMs > 0) {
      _pendingResumeMs = null;
      unawaited(_engine.seekTo(pending));
    }
  }

  // ============================================================
  // 持久化
  // ============================================================

  /// 落盘当前逻辑队列 + 模式（切曲/移除/追加/模式变化时触发; 失败静默降级）.
  Future<void> _save() async {
    final store = _store;
    if (store == null) return;
    // 元数据以 _metaByPath 为准（断点在 rebuild 后仍保留）, 顺序以视图为准.
    final items = <PlaylistItem>[
      for (final entry in _entries.value) _metaByPath[entry.path] ?? entry,
    ];
    await store.save(
      PersistedPlaylistSnapshot(items: items, playMode: _engine.playMode.value),
    );
  }

  // ============================================================
  // 生命周期
  // ============================================================

  /// 释放监听与自有 notifier. 引擎镜像 notifier 由引擎 dispose 管理（借用规则）.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _pendingResumeTimeout?.cancel();
    _engine.queueRevision.removeListener(_onQueueRevision);
    _engine.position.removeListener(_trackPosition);
    _engine.duration.removeListener(_trackDuration);
    _entries.dispose();
  }
}
