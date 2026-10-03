import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

/// 并发闸 — 有界化最昂贵的 native 解帧步骤（P-Thumb v1.3.2 §20）
///
/// Bounds the most expensive step (native frame extraction) to
/// [maxConcurrent] concurrent tasks. FIFO fairness — LIFO 更快但会饿死
/// 旧请求（§20.5），真正的可见性优先级调度留给 v1.4。
///
/// 只包 Provider generation（§20.2）— stat/memory/disk 查询一律不进
/// gate（X4），磁盘命中不该排在两个 native decode 后面（§20.3）。
final class ThumbnailConcurrencyGate {
  ThumbnailConcurrencyGate(this.maxConcurrent)
    : assert(maxConcurrent > 0, 'gate capacity must be positive');

  final int maxConcurrent;

  int _active = 0;

  /// FIFO 等待队列 — release 时 slot 直接移交给队首 waiter
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();

  /// 执行 [task] — acquire → try/finally release 全程异常安全（§20.4）：
  /// task 抛异常照样归还 slot，绝不出现“active 永远不减”的全局卡死。
  Future<T> run<T>(Future<T> Function() task) async {
    await _acquire();
    try {
      return await task();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() async {
    if (_active < maxConcurrent) {
      _active++;
      return;
    }

    final waiter = Completer<void>();
    _waiters.addLast(waiter);
    await waiter.future;
  }

  void _release() {
    // slot 直接移交队首 waiter — 计数不回退，FIFO 不饿死（§20.5）
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
      return;
    }
    _active--;
  }

  /// 当前占用数（测试观测）
  @visibleForTesting
  int get active => _active;

  /// 排队数（测试观测）
  @visibleForTesting
  int get queued => _waiters.length;

  /// 重置占用与等待队列 — 仅测试基建使用 (经 [ThumbnailService.reset])。
  ///
  /// [ThumbnailService.reset] 换 provider/diskCache 时若不清 gate,
  /// 上一用例未归还的 slot 会跨用例存活 (CI 全量跑时前组竞态残留
  /// 可致后组 calls 永卡 < 上限, 条件泵 500 轮耗尽 → 90s 超时)。
  /// 生产路径不得调用: 真实占用必须自然归还, 清零会超发并发。
  // 非 @visibleForTesting: 唯一调用方 ThumbnailService.reset 同为
  // 测试基建链路, 注解会在生产文件内调用点触发 invalid_use lint。
  void reset() {
    _active = 0;
    for (final waiter in _waiters) {
      // 唤醒全部排队者 — 被重置的等待方重新走 acquire 分配。
      waiter.complete();
    }
    _waiters.clear();
  }
}
