import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'osd_message.dart';

/// Injectable monotonic clock; elapsed time must never move backwards.
typedef OsdClock = Duration Function();

/// Scheduler returns cancellation; canceled callbacks may still be queued.
typedef OsdScheduler = VoidCallback Function(Duration delay, VoidCallback fire);

/// 全局反馈入口 — owns one current/pending snapshot and at most one timer.
///
/// 准入判定 (admission/prune/expiry) 始终读同步记账真值 [_record]; build 期
/// (SchedulerPhase.persistentCallbacks) 的 show/hide 只把 ValueNotifier 发布
/// 推迟到本帧末 — 通知延后但不丢、不重, 非 build 期时序与旧实现逐位一致。
/// Admission decisions stay synchronous; only the notifier publication may
/// wait for the frame to end during the build phase (mirrors the
/// WorkspaceMenuSession contract).
class OsdService {
  OsdService({OsdClock? now, OsdScheduler? schedule})
    : _now = now ?? _productionClock(),
      _schedule = schedule ?? _productionSchedule;

  static final I = OsdService();
  final OsdClock _now;
  final OsdScheduler _schedule;

  /// 发布通知器 — build 期可能有意滞后 [_record] 至帧末; 准入判定禁读它。
  /// Publication notifier: may intentionally lag [_record] by one frame end
  /// during the build phase; admission/expiry truth must read [_record].
  final _state = ValueNotifier<OsdSnapshot>(const OsdSnapshot(generation: 0));

  /// 同步记账真值 — show/hide 准入、prune 与过期晋升读这里的即时状态。
  /// Synchronous state of record: never lags, so admission decisions can never
  /// observe the publication lag of [_state] (see [_afterBuild]).
  OsdSnapshot _record = const OsdSnapshot(generation: 0);

  /// Single coherent state; callers cannot publish partial visibility updates.
  ValueListenable<OsdSnapshot> get snapshot => _state;

  /// Compatibility read-only projection, not a second mutable state holder.
  ValueListenable<OsdMessage?> get message =>
      _SnapshotView(_state, (s) => s.current?.message);

  /// Compatibility visibility projection of the same generation.
  ValueListenable<bool> get visible =>
      _SnapshotView(_state, (s) => s.isVisible);

  VoidCallback? _cancelTimer;
  int _timerEpoch = 0;
  bool _isDisposed = false;

  /// Admit immediate status by default; explicit priorities are ready for1B.
  ///
  /// 合并契约: 同 coalescingKey 的同 rank 消息顶替合并刷新 (新文本 + 新入场绝对
  /// 到期); 异 key 同 rank 不互吃, 落入 pending 等位接续展示 (双槽占满时按容量
  /// 裁决丢弃第三条); 无 key incoming 走纯 rank 行为, 与旧实现逐字段一致。
  void show(
    String text, {
    IconData? icon,
    double? progress,
    OsdPriority priority = OsdPriority.status,
    Object? coalescingKey,
  }) {
    if (_isDisposed) return;
    final now = _now();
    // 准入读记账真值而非发布面: build 期发布面滞后一帧时, 准入对等仍逐位一致。
    final valid = _prune(_record, now);
    final incoming = OsdEntry(
      message: OsdMessage(
        text: text,
        icon: icon,
        progress: progress,
        priority: priority,
        coalescingKey: coalescingKey,
      ),
      admittedAt: now,
      expiresAt: now + priority.lifetime,
    );
    _admit(valid, incoming, now);
  }

  /// 同步准入判定 — rank 硬门槛之上叠加 coalescingKey 身份门, 经 [_publish] 落账。
  /// Admission decision: rank gate first (structure unchanged), then the key
  /// identity gate constrains only same-rank coalescing of keyed messages.
  void _admit(OsdSnapshot valid, OsdEntry incoming, Duration now) {
    final current = valid.current;
    if (current == null) {
      _publish(incoming, valid.pending, now);
      return;
    }
    final rank = incoming.message.priority.rank;
    final currentRank = current.message.priority.rank;
    final key = incoming.message.coalescingKey;
    // rank 准入是硬门槛: 更高 rank 恒直接顶替 current (身份门不弱化准入结构)。
    if (rank > currentRank) {
      _publish(incoming, valid.pending, now);
      return;
    }
    // 同 rank 身份门: 无 key incoming 走纯 rank (与旧实现逐字段一致); 同 key
    // 顶替合并; 异 key (含 current 无 key) 不得顶替, 落入 pending 各自排队。
    final sameIdentity = key == null || current.message.coalescingKey == key;
    if (rank == currentRank && sameIdentity) {
      _publish(incoming, valid.pending, now);
      return;
    }
    final pending = valid.pending;
    if (rank == currentRank) {
      // 双槽容量裁决 (异 key 同 rank): 不抢 current 也不顶同 rank 异 key 的
      // pending — 仅 pending 空位、更高 rank、或与 pending 同 key 时可入位。
      final canStage =
          pending == null ||
          rank > pending.message.priority.rank ||
          (rank == pending.message.priority.rank &&
              pending.message.coalescingKey == key);
      if (canStage) _publish(current, incoming, now);
      return;
    }
    // rank 更低: 既有 pending 准入规则原样保留 (身份门永不豁免 rank 准入)。
    final replacement = pending == null || rank >= pending.message.priority.rank
        ? incoming
        : pending;
    _publish(current, replacement, now);
  }

  /// Explicit dismissal clears both slots; route-local renderers never call it.
  void hide() {
    if (!_isDisposed) _publish(null, null, _now());
  }

  /// Prune both slots before admission/expiry, promoting only valid remainder.
  OsdSnapshot _prune(OsdSnapshot state, Duration now) {
    final pending = state.pending?.isValidAt(now) == true
        ? state.pending
        : null;
    final current = state.current;
    return current?.isValidAt(now) == true
        ? OsdSnapshot(
            generation: state.generation,
            current: current,
            pending: pending,
          )
        : OsdSnapshot(generation: state.generation, current: pending);
  }

  /// Replace the timer before publication so reentrant listeners see one owner.
  void _publish(OsdEntry? current, OsdEntry? pending, Duration now) {
    _cancelTimer?.call();
    _cancelTimer = null;
    final epoch = ++_timerEpoch;
    // 代次来源是记账真值而非发布面: build 期发布面滞后时, 连续 show 的代次仍
    // 严格递增, 不会把两个不同快照编成同代 (overlay 的代次守卫依赖单调性)。
    final next = OsdSnapshot(
      generation: _record.generation + 1,
      current: current,
      pending: pending,
    );
    _record = next;
    if (current != null) {
      _cancelTimer = _schedule(current.expiresAt - now, () {
        // Cancellation alone cannot retract an already queued callback.
        if (_isDisposed || epoch != _timerEpoch) return;
        final at = _now();
        final valid = _prune(_record, at);
        _publish(valid.current, valid.pending, at);
      });
    }
    // 构建期把发布推迟到帧末; 其余相位同步执行, 可观察时序与旧实现一致。
    _afterBuild(() {
      if (_isDisposed) return;
      // 同引用合并: 一次构建期内多次排队的冲刷塌缩为一次通知, 携带最新一致快照。
      if (!identical(_state.value, _record)) _state.value = _record;
    });
  }

  /// 构建期守卫 — persistentCallbacks 期间把动作推迟到本帧末执行。
  /// Build-phase guard: a post-frame callback registered during
  /// SchedulerPhase.persistentCallbacks always fires at the end of the
  /// in-flight frame, so the deferral is bounded to the current frame and can
  /// never drop a message. Sister pattern: workspace_menu_session.dart.
  static void _afterBuild(VoidCallback action) {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => action());
    } else {
      action();
    }
  }

  /// Release an explicitly owned test/local service, not the shared renderer.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    ++_timerEpoch;
    _cancelTimer?.call();
    _cancelTimer = null;
    _state.dispose();
  }

  static OsdClock _productionClock() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }

  static VoidCallback _productionSchedule(Duration delay, VoidCallback fire) {
    final timer = Timer(delay, fire);
    return timer.cancel;
  }
}

/// Derived reads/listeners forward directly; no duplicated payload/visible flag.
class _SnapshotView<T> implements ValueListenable<T> {
  const _SnapshotView(this.source, this.select);
  final ValueListenable<OsdSnapshot> source;
  final T Function(OsdSnapshot) select;
  @override
  T get value => select(source.value);
  @override
  void addListener(VoidCallback listener) => source.addListener(listener);
  @override
  void removeListener(VoidCallback listener) => source.removeListener(listener);
}
