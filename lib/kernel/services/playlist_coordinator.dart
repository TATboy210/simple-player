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
import 'playlist_breakpoint.dart';
import 'playlist_entries.dart';
import 'playlist_queue_observer.dart';
import 'playlist_restore.dart';
import 'playlist_resume_seeker.dart';
import 'thumbnail_service.dart';

final _log = KernelLogger.I;

/// 播放列表协调器 — 逻辑队列 + 断点元数据 + 持久化的统一入口.
class PlaylistCoordinator {
  /// [_store] 为 null 时跳过持久化（纯内存模式, 测试便捷）.
  ///
  /// [resumeEnabled] 为断点续播总开关 (v0.0.6, null = 恒启用):
  /// false 时**不记录**断点 (含节流落盘) — 已存断点的隐藏由 UI 门控.
  ///
  /// [thumbnailEvict] 为缩略图缓存失效钩子 (可选, 便于注入/测试);
  /// 默认回落到 [ThumbnailService.evict] 静态实现, 现有调用方无需改动.
  PlaylistCoordinator({
    required this._engine,
    this._store,
    this.resumeEnabled,
    void Function(String path)? thumbnailEvict,
  }) : _thumbnailEvict = thumbnailEvict ?? ThumbnailService.evict {
    // 只监听 queueRevision 单通知点 — paths/index 分开监听会读到
    // "新列表+旧索引"的中间态 (revision 保证两者都已赋值, 快照一致).
    _engine.queueRevision.addListener(_onQueueRevision);
    _engine.position.addListener(_trackPosition);
    _engine.duration.addListener(_trackDuration);
  }

  final MediaEngine _engine;
  final PlaylistStore? _store;
  final void Function(String path) _thumbnailEvict;

  /// 断点续播补 seek 调度 (见 [PlaylistResumeSeeker]).
  final PlaylistResumeSeeker _resumeSeeker = PlaylistResumeSeeker();

  /// 断点续播总开关 — 拉取式读取 (每次记录前判值, 无需监听).
  final ValueListenable<bool>? resumeEnabled;

  /// 断点记录是否允许 — 门控取值点.
  bool get _isBreakpointAllowed => resumeEnabled?.value ?? true;

  /// 逻辑队列视图模型 — notifier + 元数据缓存 + 写时复制变更.
  final PlaylistEntries _view = PlaylistEntries();

  /// 当前排序键 (v0.0.6) — 持久化 + 面板菜单勾选态.
  PlaylistSortKey _sortKey = PlaylistSortKey.addedOrder;

  /// 当前排序方向 — true = 升序.
  bool _sortAscending = true;

  /// 断点取样器 — 粘性 position/duration + 节流窗口 (见 [BreakpointSampler]).
  final BreakpointSampler _sampler = BreakpointSampler();

  /// 断点记录器 — 取样进度写入元数据缓存 (见 [BreakpointRecorder]).
  late final BreakpointRecorder _recorder = BreakpointRecorder(
    meta: _view.meta,
    sampler: _sampler,
    isAllowed: () => _isBreakpointAllowed,
  );

  bool _disposed = false;

  /// 上次播放的条目路径 (v0.0.6.2) — 跨会话逻辑高亮锚点.
  ///
  /// 与引擎 queueIndex 解耦: 停止态/引擎队列空时仍有值（"停止也有锚"
  /// 正是本特性目的）; 引擎对此无概念, 属持久化语义域. 更新时机:
  /// revision 回流的 current 非空时置锚（单通知点覆盖装载/切曲/shuffle）,
  /// stop 回流不动, 移除锚点条目清空, 磁盘恢复时还原.
  final ValueNotifier<String?> _lastPlayedPath = ValueNotifier<String?>(null);

  /// 可注入时钟 — 测试控制节流窗口 (默认真实时钟).
  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  // ---- UI 视图 ----

  /// 队列条目视图（断点元数据已合并）— 面板列表渲染用.
  ValueNotifier<List<PlaylistItem>> get entries => _view.notifier;

  /// 当前播放条目索引 — 身份保持转发引擎镜像（-1 = 未播放）.
  ValueNotifier<int> get currentIndex => _engine.queueIndex;

  /// 当前播放模式 — 身份保持转发引擎镜像（引擎为模式单一数据源）.
  ValueNotifier<PlayMode> get playMode => _engine.playMode;

  /// 当前排序键 (v0.0.6) — 面板菜单勾选态.
  PlaylistSortKey get sortKey => _sortKey;

  /// 当前排序方向 — true = 升序.
  bool get sortAscending => _sortAscending;

  /// 上次播放的条目路径 (v0.0.6.2) — 身份保持转发, 面板停止态高亮锚点
  /// （path 不在队列时 UI 无匹配, 高亮自然不渲染）.
  ValueNotifier<String?> get lastPlayedPath => _lastPlayedPath;

  // ---- 动作转发 ----

  /// 播放指定索引条目.
  ///
  /// 引擎装载队列与逻辑队列一致 → 直接 jumpTo（引擎已装载, 毫秒级切换）;
  /// 否则（停止态 / 磁盘恢复后首次点击）→ 装载完整逻辑队列并从该条目起播.
  Future<bool> playEntryAt(int index) async {
    final paths = <String>[for (final entry in _view.items) entry.path];
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
    if (index < 0 || index >= _view.items.length) return;

    final removed = _view.items[index];
    _view.meta.remove(removed.path);
    // 移除锚点条目 → 清空锚 (用户显式丢弃该条目, 高亮失效);
    // 移除其他条目不动 (path 键防误伤同名不同条).
    if (_lastPlayedPath.value == removed.path) _lastPlayedPath.value = null;
    _view.drop({index});

    await _engine.removeFromQueue(index);
    unawaited(_save());
  }

  /// 批量移除指定索引集合的条目 (右键菜单批量删除, v0.0.7) —
  /// 逻辑队列一次性重算 (UI 即时反馈), 引擎侧**降序**逐个移除
  /// (降序保证前置索引不受删除位移影响), 最后统一落盘一次.
  ///
  /// 缩略图缓存按 P-Thumb §40.1/§40.2 契约接线: 移除**成功后**逐 path
  /// evict (O(移除数), 绝不 clearCache) — 遵循"业务成功才清缓存"顺序.
  Future<void> removeEntriesAt(Set<int> indices) async {
    if (indices.isEmpty) return;
    final valid = indices
        .where((i) => i >= 0 && i < _view.items.length)
        .toSet();
    if (valid.isEmpty) return;

    final removedPaths = <String>[for (final i in valid) _view.items[i].path];

    // 逻辑队列一次性重算 — 排除全部选中索引 (unmodifiable 新列表).
    for (final path in removedPaths) {
      _view.meta.remove(path);
    }
    _view.drop(valid);

    // 引擎装载态: 单次批量调用 (v0.0.9 事件放大治理) — 引擎侧降序移除
    // + revision 单发收敛 (N → 1), 删除正在播放条目的跳转同单条语义.
    final enginePaths = _engine.queuePaths.value;
    if (enginePaths.isNotEmpty) {
      await _engine.removeFromQueueBatch(valid);
    }

    // 锚点清理 — 被移除条目曾是"上次播放"锚则置空 (与单条语义一致).
    if (removedPaths.contains(_lastPlayedPath.value)) {
      _lastPlayedPath.value = null;
    }

    // P-Thumb §40.1/§40.2: 业务成功后批量失效缩略图缓存.
    for (final path in removedPaths) {
      _thumbnailEvict(path);
    }

    unawaited(_save());
  }

  /// 追加条目到队列末尾 — 引擎装载时走 mpv 原生 append（不打断当前播放）,
  /// 停止态仅扩充逻辑队列（下次装载生效）.
  Future<void> appendEntries(List<String> paths) async {
    if (paths.isEmpty) return;
    _view.append(paths);
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
    final nextAscending =
        ascending ?? (key == _sortKey ? !_sortAscending : true);
    _sortKey = key;
    _sortAscending = nextAscending;

    final target = [..._view.items]
      ..sort(
        (a, b) =>
            comparePlaylistEntries(a, b, key: key, ascending: nextAscending),
      );
    final targetPaths = <String>[for (final entry in target) entry.path];

    await _engine.sortQueue(targetPaths);
    if (!_engineQueueMatches(targetPaths)) {
      // 停止态: 引擎队列空 (或与逻辑队列不一致), sortQueue no-op 无回流 —
      // 手工重排逻辑队列并落盘, 下次装载按新顺序生效.
      _view.replaceAll(target);
      unawaited(_save());
    }
  }

  /// 跳到下一个条目 — 边界回绕语义由引擎 [QueueControl] 统一裁定.
  bool next() => _engine.nextInQueue();

  /// 跳到上一个条目.
  bool previous() => _engine.previousInQueue();

  /// 断点续播指定索引条目 (v0.0.5) — 播放 + seek 到该条目的断点位置.
  ///
  /// **时序竞态修复** (mpv loadfile 异步语义): `seek` 只等播放器初始化, 不等
  /// 新文件加载完成 — 装载/跳转后立即 seek 会被发到尚未切换的 mpv 状态
  /// 而丢失. 因此无论装载还是已装载分支, 一律经 [_resumeSeeker] 挂起,
  /// 由 [_trackPosition] 在"新条目开始播放"信号 (position 回到低位锁存区
  /// 且时长有效) 时补 seek — loadfile 完成后首个 position 事件必然落位.
  Future<bool> resumeEntryAt(int index) async {
    final items = _view.items;
    if (index < 0 || index >= items.length) return false;
    final resumeMs = items[index].positionMs ?? 0;

    final ok = await playEntryAt(index);
    if (!ok) return false;
    if (resumeMs > 0) _resumeSeeker.arm(resumeMs);
    return true;
  }

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

  // ---- 启动恢复 ----

  /// 从磁盘恢复逻辑队列、播放模式与排序状态 — **不装载 mpv 队列, 不自动播放**
  /// （装载留给用户首次点击条目时的 [playEntryAt] 装载分支）.
  ///
  /// 守卫: 引擎队列已非空时不覆盖用户会话 (见 [loadRestorableSnapshot]).
  Future<void> restoreFromDisk() async {
    final store = _store;
    if (store == null) return;
    final snapshot = await loadRestorableSnapshot(
      store,
      isEngineActive: () => _engine.queuePaths.value.isNotEmpty,
    );
    if (snapshot == null) return;

    _view.meta.restore(snapshot.items); // 同时推进 addedSeq 序号, 不与恢复值冲突
    _sortKey = snapshot.sortKey;
    _sortAscending = snapshot.sortAscending;
    // 幂等重放排序 — 见 [replaySort].
    _view.replaceAll(replaySort(snapshot));
    // 上次播放锚点恢复 (v0.0.6.2) — 仅逻辑高亮, 引擎仍不装载不自动播;
    // path 不在队列时 UI 无匹配, 高亮自然不渲染.
    _lastPlayedPath.value = snapshot.lastPlayedPath;
    // 模式恢复不装载队列也可设置（mpv 属性级, 队列空时无副作用）.
    await _engine.setPlayMode(snapshot.playMode);
    _log.i(
      'PlaylistCoordinator: restored queue from disk',
      context: {
        'count': snapshot.items.length,
        'mode': snapshot.playMode.name,
        'sort': '${_sortKey.name}/${_sortAscending ? 'asc' : 'desc'}',
        'lastPlayed': snapshot.lastPlayedPath,
      },
    );
  }

  // ---- 引擎镜像监听 ----

  /// 引擎队列快照观察器 (切曲检测基准 + identity 快路径).
  final QueueObserver _observer = QueueObserver();

  /// 引擎队列状态变化 (装载/追加/移除/乱序/切曲/自动续播) —
  /// revision 触发时 queuePaths 与 queueIndex 均已是最新值, 读到一致快照.
  void _onQueueRevision() {
    final transition = _observer.observe(
      _engine.queuePaths.value,
      _engine.queueIndex.value,
    );
    if (transition == null) return; // 快路径短路 — 零重建零落盘

    final paths = _engine.queuePaths.value;
    if (transition.queueChanged && paths.isNotEmpty) {
      // 装载/替换/移除/乱序 → 逻辑队列以引擎为准重建（元数据按 path 合并）.
      // 空装载（stop 的 playlist-clear）视作"停止" — 逻辑队列保留不清空.
      _view.rebuildFrom(paths);
    }

    // 切曲/换队列/删正在播跳转: 给"上一次正在播"的条目记断点.
    final previous = transition.previousPlayingPath;
    if (previous != null && transition.playingChanged) {
      _updateBreakpoint(previous);
      // 新曲目开始 — 重置粘性取材, 防上曲残留污染新曲断点
      // (死文件场景: 新曲 position/duration 从不推进, 若不重置会
      //  继承上曲位置; 正常播放会立即以新值覆盖).
      _sampler.reset();
    }

    // 上次播放锚点 (v0.0.6.2) — current 非空即置锚 (装载/切曲/shuffle 全
    // 走此单通知点); current 为 null 是 stop 的空装载回流, 锚保留
    // ("停止也有锚"). notifier 值相等时自动去重, 重复置锚无通知开销.
    final current = transition.currentPlayingPath;
    if (current != null) _lastPlayedPath.value = current;

    if (transition.queueChanged || transition.playingChanged) {
      unawaited(_save());
    }
  }

  /// 近 EOF 断点规则 — 委托 [effectiveBreakpointMs] (保留旧入口, 单测锚点).
  @visibleForTesting
  static int? effectiveBreakpointMs(int positionMs, int durationMs) =>
      breakpointRule(positionMs, durationMs);

  /// 给指定 path 的条目写断点（最后位置 + 时长 + 时间戳）并刷新视图.
  /// 已从逻辑队列移除的条目跳过（删除正在播条目时触发的断点回写是无主记录）.
  /// 近 EOF 的条目写 positionMs=null — 看完不留断点, durationMs 照写
  /// （排序按时长需要它）; 规则见 [applyBreakpoint].
  ///
  /// **单条替换** (v0.0.13): 只替换视图中变化的那一条, 其余条目实例原样
  /// 沿用 (identical), 经同一个 notifier 单点通知; 不再逐条重建整个
  /// 列表 (旧实现每 5s 对 n 条全量 collection-for 重建).
  void _updateBreakpoint(String path) {
    final index = _view.indexOfPath(path);
    final updated = _recorder.record(path, inView: index >= 0);
    if (updated == null || index < 0) return; // 无记录 / 仅元数据 — 不通知
    _view.replaceAt(index, updated);
  }

  /// 判断引擎装载队列与给定 paths 是否一致（playEntryAt 的跳转/装载分支判据）.
  bool _engineQueueMatches(List<String> paths) =>
      listEquals(_engine.queuePaths.value, paths);

  void _trackPosition() {
    final live = _engine.position.value;
    _sampler.samplePosition(live); // 粘性取材: 进 0 不回写
    _maybeThrottledSave(live);
    // 断点续播补 seek — 见 [PlaylistResumeSeeker.onPosition].
    final seekTo = _resumeSeeker.onPosition(
      liveMs: live,
      engineDurationMs: _engine.duration.value,
    );
    if (seekTo != null) unawaited(_engine.seekTo(seekTo));
  }

  void _trackDuration() {
    final live = _engine.duration.value;
    _sampler.sampleDuration(live); // 粘性取材同 position
    final seekTo = _resumeSeeker.onDuration(live);
    if (seekTo != null) unawaited(_engine.seekTo(seekTo));
  }

  /// 断点节流落盘 — 播放中每 [BreakpointSampler.saveInterval] 把当前条目
  /// 进度刷进断点元数据并落盘. 无此机制时 _save 只在切曲/装载等事件触发,
  /// 播放中途强杀进程会丢失自上次事件以来的全部进度.
  void _maybeThrottledSave(int livePositionMs) {
    final current = _observer.playingPath;
    if (current == null) return; // 未在播放任何条目
    if (livePositionMs <= 0) return; // 起始/清零事件无进度可存
    if (!_sampler.tryAcquireSaveWindow(clock())) return; // 节流窗口内
    // 先把当前条目断点刷进元数据 (含近 EOF 判定), 再落盘 —
    // 否则 _save 只会写出切曲时的旧快照.
    _updateBreakpoint(current);
    unawaited(_save());
  }

  // ---- 持久化 ----

  /// 退出前最终落盘 (v0.0.6.2) — 绕过 5s 节流把当前条目断点刷进元数据后
  /// 同步落盘一次, 由关窗链经 WindowBridge.addClosingListener 调用.
  ///
  /// 正常切曲/节流已覆盖大部分场景, 本方法消除"最后一次切曲后的节流窗口
  /// 内强杀进程"的断点缝隙. 已 dispose 或未在播放时仅落盘当前快照, 不抛.
  Future<void> flushForExit() async {
    if (_disposed) return;
    final current = _observer.playingPath;
    if (current != null) {
      _updateBreakpoint(current); // 内部自守 _isBreakpointAllowed
    }
    await _save();
  }

  /// 落盘当前逻辑队列 + 模式 + 排序状态（切曲/移除/追加/模式变化时触发;
  /// 失败静默降级）.
  Future<void> _save() async {
    final store = _store;
    if (store == null) return;
    // 元数据以元数据缓存为准（断点在 rebuild 后仍保留）, 顺序以视图为准.
    final items = <PlaylistItem>[
      for (final entry in _view.items) _view.meta[entry.path] ?? entry,
    ];
    await store.save(
      PersistedPlaylistSnapshot(
        items: items,
        playMode: _engine.playMode.value,
        sortKey: _sortKey,
        sortAscending: _sortAscending,
        lastPlayedPath: _lastPlayedPath.value,
      ),
    );
  }

  // ---- 生命周期 ----

  /// 释放监听与自有 notifier. 引擎镜像 notifier 由引擎 dispose 管理（借用规则）.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _resumeSeeker.dispose();
    _engine.queueRevision.removeListener(_onQueueRevision);
    _engine.position.removeListener(_trackPosition);
    _engine.duration.removeListener(_trackDuration);
    _view.dispose();
    _lastPlayedPath.dispose();
  }
}
