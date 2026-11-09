/// 断点策略与取样 — 播放列表断点续播的纯逻辑部分 (从 PlaylistCoordinator 拆出).
///
/// Breakpoint policy and sampling: the pure, engine-free half of resume
/// breakpoints (near-EOF rule, sticky position/duration, 5s throttle window).
library;

import '../models/playlist_item.dart';
import 'playlist_meta_cache.dart';

/// 片尾阈值 — position 落入 [duration−5s, duration] 视为看完.
const int _nearEofTailMs = 5000;

/// 片尾百分比阈值 — position ≥ 98% duration 同样视为看完 (长片 5s 太窄).
const int _nearEofPercent = 98;

/// 近 EOF 断点规则 — 纯函数 (单测锚点, VLC 惯例).
///
/// Returns the position to persist as a breakpoint: the raw value mid-play,
/// or `null` when nothing was played / the media was (nearly) finished.
/// 短文件 (时长 ≤ 5s) 整体都在片尾阈值区, 永不留断点.
int? breakpointRule(int positionMs, int durationMs) {
  if (positionMs <= 0) return null;
  if (durationMs <= 0) return positionMs; // 时长未知 — 位置有效即保留
  if (positionMs >= durationMs - _nearEofTailMs) return null;
  if (positionMs * 100 >= durationMs * _nearEofPercent) return null;
  return positionMs;
}

/// 把取样的进度应用到条目上, 返回新的不可变条目 (纯函数, 不触碰任何状态).
///
/// Applies the sampled progress to [base]. A `null` effective breakpoint
/// (finished / never played) must really clear `positionMs`; `copyWith`
/// cannot express that ("null = keep old"), so the constructor is used with
/// every field passed through explicitly. [durationMs] is always written when
/// known (sort-by-duration needs it); unknown duration keeps the old value.
PlaylistItem applyBreakpoint(
  PlaylistItem base, {
  required int positionMs,
  required int durationMs,
  required int nowMs,
}) {
  final bp = breakpointRule(positionMs, durationMs);
  if (bp == null) {
    // 看完/未播放 → 清除断点 (toJson 省略该键 → 恢复后从头播).
    return PlaylistItem(
      path: base.path,
      positionMs: null,
      durationMs: durationMs > 0 ? durationMs : base.durationMs,
      addedSeq: base.addedSeq,
      timestamp: nowMs,
    );
  }
  // 正常中途 → copyWith 语义无冲突 (非 null 直接覆盖).
  return base.copyWith(
    positionMs: bp,
    durationMs: durationMs > 0 ? durationMs : null,
    timestamp: nowMs,
  );
}

/// 断点取样器 — 粘性 position/duration + 节流窗口判定.
///
/// Sticky sampler for position/duration plus the throttle gate.
///
/// **粘性语义**: 进 0 不回写 — 引擎 stop 会同步把 position/duration 清 0,
/// 先于 queueRevision 回流的断点写入; 无粘性时 stop 断点恒为 0
/// ("停止=丢断点"), 切曲时新文件 position(0) 先到的竞态同理.
/// 只写两个 int 字段, 无 notifier 通知, 高频调用开销可忽略.
class BreakpointSampler {
  /// 断点节流落盘间隔 — 播放中每 5s 刷一次进度, 保证强杀时损失 ≤ 该粒度.
  static const Duration saveInterval = Duration(seconds: 5);

  int _positionMs = 0;
  int _durationMs = 0;

  /// 上次节流落盘时刻 (毫秒纪元) — 0 = 从未落盘 (首次进度立即保存).
  int _lastSaveMs = 0;

  /// 最后一次已知的有效 position (ms), 从未采到为 0.
  int get positionMs => _positionMs;

  /// 最后一次已知的有效 duration (ms), 从未采到为 0.
  int get durationMs => _durationMs;

  /// 采样 position — 仅 >0 才覆盖 (粘性).
  void samplePosition(int liveMs) {
    if (liveMs > 0) _positionMs = liveMs;
  }

  /// 采样 duration — 仅 >0 才覆盖 (粘性).
  void sampleDuration(int liveMs) {
    if (liveMs > 0) _durationMs = liveMs;
  }

  /// 新曲目开始 — 重置粘性取材, 防上曲残留污染新曲断点
  /// (死文件场景: 新曲 position/duration 从不推进, 会继承上曲位置).
  void reset() {
    _positionMs = 0;
    _durationMs = 0;
  }

  /// 节流判定: 距上次落盘 ≥ [saveInterval] 时返回 true 并推进窗口
  /// (Side effect: 命中即记录 [now] 为新窗口起点).
  bool tryAcquireSaveWindow(DateTime now) {
    final nowMs = now.millisecondsSinceEpoch;
    if (nowMs - _lastSaveMs < saveInterval.inMilliseconds) return false;
    _lastSaveMs = nowMs;
    return true;
  }
}

/// 断点记录器 — 把取样器的进度写入元数据缓存 (不碰视图, 视图刷新由调用方做).
///
/// Writes sampled progress into the metadata cache and returns the new item;
/// the caller decides how to publish it (keeps view mutation single-sourced).
class BreakpointRecorder {
  /// [isAllowed] 为断点总开关取值点 (拉取式, 每次记录前判值).
  BreakpointRecorder({
    required this._meta,
    required this._sampler,
    required this._isAllowed,
  });

  final PlaylistMetaCache _meta;
  final BreakpointSampler _sampler;
  final bool Function() _isAllowed;

  /// 给 [path] 记断点, 返回更新后的条目; 开关关闭/无主记录时返回 null.
  ///
  /// [inView] 表示该 path 当前是否在逻辑队列视图中: 已移除且无元数据的
  /// 条目跳过 (删除正在播条目时触发的断点回写是无主记录, 不产生孤儿断点).
  /// Side effect: 写入 [PlaylistMetaCache] (含 addedSeq 兜底分配).
  PlaylistItem? record(String path, {required bool inView}) {
    if (!_isAllowed()) return null; // 断点续播总开关关闭 — 不记录
    if (_meta[path] == null && !inView) return null;
    // itemFor 兜底: 条目在视图中但元数据缺失时登记 (含 addedSeq 分配).
    final updated = applyBreakpoint(
      _meta.itemFor(path),
      positionMs: _sampler.positionMs,
      durationMs: _sampler.durationMs,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    _meta.put(path, updated);
    return updated;
  }
}
