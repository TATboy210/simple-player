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
import '../models/playlist_sort.dart';
import '../persistence/playlist_store.dart';

final _log = KernelLogger.I;

/// 播放列表协调器 — 逻辑队列 + 断点元数据 + 持久化的统一入口.
class PlaylistCoordinator {
  /// [_store] 为 null 时跳过持久化（纯内存模式, 测试便捷）.
  ///
  /// [resumeEnabled] 为断点续播总开关 (v0.0.6, null = 恒启用):
  /// false 时**不记录**断点 (含节流落盘) — 已存断点的隐藏由 UI 门控.
  PlaylistCoordinator({required this._engine, this._store, this.resumeEnabled}) {
    // 只监听 queueRevision 单通知点 — paths/index 分开监听会读到
    // "新列表+旧索引"的中间态 (revision 保证两者都已赋值, 快照一致).
    _engine.queueRevision.addListener(_onQueueRevision);
    _engine.position.addListener(_trackPosition);
    _engine.duration.addListener(_trackDuration);
  }

  final MediaEngine _engine;
  final PlaylistStore? _store;

  /// 断点续播总开关 — 拉取式读取 (每次记录前判值, 无需监听).
  final ValueListenable<bool>? resumeEnabled;

  /// 断点记录是否允许 — 门控取值点.
  bool get _isBreakpointAllowed => resumeEnabled?.value ?? true;

  /// 逻辑队列条目（含断点元数据）— UI 面板的数据源.
  final ValueNotifier<List<PlaylistItem>> _entries = ValueNotifier(
    const <PlaylistItem>[],
  );

  /// path → 元数据缓存. 队列重建时按 path 合并, 条目移除后不主动清理
  /// （断点元数据量级 = 用户看过的文件数, 内存影响可忽略）.
  final Map<String, PlaylistItem> _metaByPath = <String, PlaylistItem>{};

  /// 下一个待分配的添加顺序序号 (addedSeq) — 单调递增, 只增不回收
  /// （删除条目留下空洞无碍排序语义）.
  int _nextAddedSeq = 0;

  /// 当前排序键 (v0.0.6) — 持久化 + 面板菜单勾选态.
  PlaylistSortKey _sortKey = PlaylistSortKey.addedOrder;

  /// 当前排序方向 — true = 升序.
  bool _sortAscending = true;

  /// 取条目元数据; 新 path 分配 addedSeq 并登记入缓存 —
  /// [addedSeq] 是排序键 addedOrder 的数据前提, 必须稳定持久
  /// （on-the-fly 生成会随重建漂移）.
  PlaylistItem _itemFor(String path) {
    final existing = _metaByPath[path];
    if (existing != null) return existing;
    final created = PlaylistItem(path: path, addedSeq: _nextAddedSeq++);
    _metaByPath[path] = created;
    return created;
  }

  /// 切曲前最后一次已知的 position/duration 快照 — 断点更新取材处.
  /// **粘性语义 (v0.0.6)**: 进 0 不回写 — engine.stop 的
  /// `_clearLoadedMediaState` 会同步把 position/duration 清 0, 先于
  /// queueRevision 回流的断点写入; 无粘性时 stop 断点恒为 0
  /// ("停止=丢断点"), 切曲时新文件 position(0) 先到的竞态同理.
  /// position 流高频但只写两个 int 字段, 无 notifier 通知, 开销可忽略.
  int _lastKnownPositionMs = 0;
  int _lastKnownDurationMs = 0;

  bool _disposed = false;

  /// 断点节流落盘间隔 — 播放中每 5s 把当前进度刷进断点元数据并落盘,
  /// 保证强杀进程/异常退出时断点损失不超过该粒度.
  static const Duration _breakpointSaveInterval = Duration(seconds: 5);

  /// 上次断点节流落盘时刻 (毫秒纪元) — 0 = 从未落盘 (首次进度立即保存).
  int _lastBreakpointSaveMs = 0;

  /// 可注入时钟 — 测试控制节流窗口 (默认真实时钟).
  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  // ============================================================
  // UI 视图
  // ============================================================

  /// 队列条目视图（断点元数据已合并）— 面板列表渲染用.
  ValueNotifier<List<PlaylistItem>> get entries => _entries;

  /// 当前播放条目索引 — 身份保持转发引擎镜像（-1 = 未播放）.
  ValueNotifier<int> get currentIndex => _engine.queueIndex;

  /// 当前播放模式 — 身份保持转发引擎镜像（引擎为模式单一数据源）.
  ValueNotifier<PlayMode> get playMode => _engine.playMode;

  /// 当前排序键 (v0.0.6) — 面板菜单勾选态.
  PlaylistSortKey get sortKey => _sortKey;

  /// 当前排序方向 — true = 升序.
  bool get sortAscending => _sortAscending;

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

  /// 按指定键排序队列 (v0.0.6) — 用户显式意图的物理重排.
  ///
  /// 排序与播放顺序严格分离: 这是唯一合法的队列物理重排（随机播放是
  /// 播放顺序覆盖层, 永不改列表排列）. 引擎已装载时经 [QueueControl.sortQueue]
  /// 物理重排 mpv 队列（revision 回流自动重建视图 + 落盘）; 停止态
  /// （引擎队列空）仅重排逻辑队列, 下次装载按新顺序生效.
  ///
  /// [ascending] 省略时: 同键再次排序 = 翻转方向, 换键 = 重置为升序.
  Future<void> sortEntries(PlaylistSortKey key, {bool? ascending}) async {
    final nextAscending = ascending ?? (key == _sortKey ? !_sortAscending : true);
    _sortKey = key;
    _sortAscending = nextAscending;

    final target = [..._entries.value]..sort(
      (a, b) => comparePlaylistEntries(a, b, key: key, ascending: nextAscending),
    );
    final targetPaths = <String>[for (final entry in target) entry.path];

    await _engine.sortQueue(targetPaths);
    if (!_engineQueueMatches(targetPaths)) {
      // 停止态: 引擎队列空 (或与逻辑队列不一致), sortQueue no-op 无回流 —
      // 手工重排逻辑队列并落盘, 下次装载按新顺序生效.
      _entries.value = List<PlaylistItem>.unmodifiable(target);
      unawaited(_save());
    }
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

  /// 从磁盘恢复逻辑队列、播放模式与排序状态 — **不装载 mpv 队列, 不自动播放**
  /// （装载留给用户首次点击条目时的 [playEntryAt] 装载分支）.
  Future<void> restoreFromDisk() async {
    final store = _store;
    if (store == null) return;
    final snapshot = await store.load();
    if (snapshot == null || snapshot.items.isEmpty) return;

    var maxSeq = -1;
    for (final item in snapshot.items) {
      _metaByPath[item.path] = item;
      final seq = item.addedSeq;
      if (seq != null && seq > maxSeq) maxSeq = seq;
    }
    _nextAddedSeq = maxSeq + 1; // 后续新增条目接着编号, 不与恢复值冲突
    _sortKey = snapshot.sortKey;
    _sortAscending = snapshot.sortAscending;
    // 幂等重放排序 — 恢复顺序即上次落盘顺序, 已排序时恒等 (addedOrder
    // 模式下重放按 addedSeq 归位, 修正手工删改造成的漂移).
    final sorted = [...snapshot.items]..sort(
      (a, b) => comparePlaylistEntries(
        a,
        b,
        key: _sortKey,
        ascending: _sortAscending,
      ),
    );
    _entries.value = List<PlaylistItem>.unmodifiable(<PlaylistItem>[...sorted]);
    // 模式恢复不装载队列也可设置（mpv 属性级, 队列空时无副作用）.
    await _engine.setPlayMode(snapshot.playMode);
    _log.i(
      'PlaylistCoordinator: restored queue from disk',
      context: {
        'count': snapshot.items.length,
        'mode': snapshot.playMode.name,
        'sort': '${_sortKey.name}/${_sortAscending ? 'asc' : 'desc'}',
      },
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
      // 新曲目开始 — 重置粘性取材, 防上曲残留污染新曲断点
      // (死文件场景: 新曲 position/duration 从不推进, 若不重置会
      //  继承上曲位置; 正常播放会立即以新值覆盖).
      _lastKnownPositionMs = 0;
      _lastKnownDurationMs = 0;
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

  /// 片尾阈值 — position 落入 [duration−5s, duration] 视为看完.
  static const _nearEofTailMs = 5000;

  /// 片尾百分比阈值 — position ≥ 98% duration 同样视为看完 (长片 5s 太窄).
  static const _nearEofPercent = 98;

  /// 近 EOF 断点规则 — 纯函数 (单测锚点, VLC 惯例).
  ///
  /// 返回应写入的断点位置: 正常中途返回原值; 未播放/看完返回 null.
  /// 短文件 (时长 ≤ 5s) 整体都在片尾阈值区, 永不留断点.
  @visibleForTesting
  static int? effectiveBreakpointMs(int positionMs, int durationMs) {
    if (positionMs <= 0) return null;
    if (durationMs <= 0) return positionMs; // 时长未知 — 位置有效即保留
    if (positionMs >= durationMs - _nearEofTailMs) return null;
    if (positionMs * 100 >= durationMs * _nearEofPercent) return null;
    return positionMs;
  }

  /// 给指定 path 的条目写断点（最后位置 + 时长 + 时间戳）并刷新视图.
  /// 已从逻辑队列移除的条目跳过（删除正在播条目时触发的断点回写是无主记录）.
  /// 近 EOF 的条目写 positionMs=null — 看完不留断点, durationMs 照写
  /// （排序按时长需要它）.
  void _updateBreakpoint(String path) {
    if (!_isBreakpointAllowed) return; // 断点续播总开关关闭 — 不记录
    final existing = _metaByPath[path];
    if (existing == null && !_entries.value.any((e) => e.path == path)) {
      return; // 已移除且无元数据 — 不产生孤儿断点
    }
    // _itemFor 兜底: 条目在视图中但元数据缺失时登记 (含 addedSeq 分配).
    final base = _itemFor(path);
    final updated = base.copyWith(
      positionMs: effectiveBreakpointMs(_lastKnownPositionMs, _lastKnownDurationMs),
      durationMs: _lastKnownDurationMs > 0 ? _lastKnownDurationMs : null,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    _metaByPath[path] = updated;
    // 就地刷新视图中的同 path 条目（保持顺序不变）.
    _entries.value = List<PlaylistItem>.unmodifiable(<PlaylistItem>[
      for (final entry in _entries.value) entry.path == path ? updated : entry,
    ]);
  }

  /// 以引擎 paths 为准重建逻辑队列（元数据按 path 合并, 排序重排后顺序跟随引擎;
  /// 新 path 经 [_itemFor] 登记元数据并分配 addedSeq）.
  void _rebuildEntries(List<String> paths) {
    _entries.value = List<PlaylistItem>.unmodifiable(<PlaylistItem>[
      for (final path in paths) _itemFor(path),
    ]);
  }

  /// 逻辑队列追加（保持引擎镜像顺序语义 — 末尾追加）.
  void _appendToLogicalQueue(List<String> paths) {
    _entries.value = List<PlaylistItem>.unmodifiable(<PlaylistItem>[
      ..._entries.value,
      for (final path in paths) _itemFor(path),
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
    // 粘性取材: 进 0 不回写 (_lastKnown* 字段注释详见粘性语义说明).
    final live = _engine.position.value;
    if (live > 0) _lastKnownPositionMs = live;
    _maybeThrottledSave(live);
    // 断点续播补 seek — "新条目开始播放"锁存信号: position 落入低位区
    // 且时长有效. **必须读引擎活值而非粘性值** — 上曲遗留的高位粘性值
    // 会让低位信号永不满足, 续播静默失效. 一次性消费 (置 null), 后续
    // seek 本身产生的 position 事件不会重复触发.
    final pending = _pendingResumeMs;
    if (pending != null &&
        live < _resumeSeekLatchMs &&
        _engine.duration.value > 0) {
      _pendingResumeMs = null;
      unawaited(_engine.seekTo(pending));
    }
  }

  void _trackDuration() {
    // 粘性取材同 position — duration 清 0 (stop/装载) 不回写.
    final live = _engine.duration.value;
    if (live > 0) _lastKnownDurationMs = live;
    // 断点续播的挂起 seek — duration 首次有效即补齐 (装载场景).
    final pending = _pendingResumeMs;
    if (pending != null && live > 0) {
      _pendingResumeMs = null;
      unawaited(_engine.seekTo(pending));
    }
  }

  /// 断点节流落盘 — 播放中每 [_breakpointSaveInterval] 把当前条目进度
  /// 刷进断点元数据并落盘. 无此机制时 _save 只在切曲/装载等事件触发,
  /// 播放中途强杀进程会丢失自上次事件以来的全部进度.
  void _maybeThrottledSave(int livePositionMs) {
    final current = _observedPlayingPath;
    if (current == null) return; // 未在播放任何条目
    if (livePositionMs <= 0) return; // 起始/清零事件无进度可存
    final nowMs = clock().millisecondsSinceEpoch;
    if (nowMs - _lastBreakpointSaveMs < _breakpointSaveInterval.inMilliseconds) {
      return; // 节流窗口内
    }
    _lastBreakpointSaveMs = nowMs;
    // 先把当前条目断点刷进元数据 (含近 EOF 判定), 再落盘 —
    // 否则 _save 只会写出切曲时的旧快照.
    _updateBreakpoint(current);
    unawaited(_save());
  }

  // ============================================================
  // 持久化
  // ============================================================

  /// 落盘当前逻辑队列 + 模式 + 排序状态（切曲/移除/追加/模式变化时触发;
  /// 失败静默降级）.
  Future<void> _save() async {
    final store = _store;
    if (store == null) return;
    // 元数据以 _metaByPath 为准（断点在 rebuild 后仍保留）, 顺序以视图为准.
    final items = <PlaylistItem>[
      for (final entry in _entries.value) _metaByPath[entry.path] ?? entry,
    ];
    await store.save(
      PersistedPlaylistSnapshot(
        items: items,
        playMode: _engine.playMode.value,
        sortKey: _sortKey,
        sortAscending: _sortAscending,
      ),
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
