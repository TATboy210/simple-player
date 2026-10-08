import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'osd_message.dart';

/// Injectable monotonic clock; elapsed time must never move backwards.
typedef OsdClock = Duration Function();

/// Scheduler returns cancellation; canceled callbacks may still be queued.
typedef OsdScheduler = VoidCallback Function(Duration delay, VoidCallback fire);

/// 全局反馈入口 — owns one current/pending snapshot and at most one timer.
class OsdService {
  OsdService({OsdClock? now, OsdScheduler? schedule})
    : _now = now ?? _productionClock(),
      _schedule = schedule ?? _productionSchedule;

  static final I = OsdService();
  final OsdClock _now;
  final OsdScheduler _schedule;
  final _state = ValueNotifier<OsdSnapshot>(const OsdSnapshot(generation: 0));

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
  void show(
    String text, {
    IconData? icon,
    double? progress,
    OsdPriority priority = OsdPriority.status,
    Object? coalescingKey,
  }) {
    if (_isDisposed) return;
    final now = _now();
    final valid = _prune(_state.value, now);
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
    final current = valid.current;
    // Same rank replaces (and thus coalesces) immediately; higher never requeues.
    if (current == null || priority.rank >= current.message.priority.rank) {
      _publish(incoming, valid.pending, now);
      return;
    }
    final pending = valid.pending;
    final replacement =
        pending == null || priority.rank >= pending.message.priority.rank
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
    final next = OsdSnapshot(
      generation: _state.value.generation + 1,
      current: current,
      pending: pending,
    );
    if (current != null) {
      _cancelTimer = _schedule(current.expiresAt - now, () {
        // Cancellation alone cannot retract an already queued callback.
        if (_isDisposed || epoch != _timerEpoch) return;
        final at = _now();
        final valid = _prune(_state.value, at);
        _publish(valid.current, valid.pending, at);
      });
    }
    _state.value = next;
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
