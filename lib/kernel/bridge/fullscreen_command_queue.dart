import 'dart:async';

import '../models/fullscreen_request.dart';
import '../models/fullscreen_snapshot.dart';

/// per-window 命令串行化队列 — Completer 链实现。
///
/// 设计约束 (per D-12~D-18):
/// - 同一 windowId 只允许一个 in-flight 命令
/// - 待执行命令可合并: 同 windowId + 同目标状态 → 复用 Completer
/// - toggle 先由 FullscreenAdapter 解析为 Enter/Leave 再入队
/// - 5 秒超时后自动取消并返回 false (D-13)
/// - dispose 后拒绝新命令，pending complete(false)，in-flight 不 drain (P1-5)
/// - maxQueueSize=50 per windowId (P1-6)
///
/// 用法:
/// ```dart
/// final queue = FullscreenCommandQueue();
/// final result = await queue.enqueue(
///   FullscreenRequest.enter(),
///   (request) async => await nativeSetFullscreen(true),
/// );
/// ```
class FullscreenCommandQueue {
  /// per-windowId 独立队列 (D-14)。
  final _queues = <int, _WindowQueue>{};

  /// 队列级 dispose 标志 — dispose 后不允许创建新队列。
  bool _disposed = false;

  /// 队列容量上限 per windowId (P1-6)。
  ///
  /// 正常场景合并逻辑会保持队列极短，50 是极端情况保护。
  static const maxQueueSize = 50;

  /// 入队命令，返回 executor 的执行结果。
  ///
  /// - 无 in-flight → 立即执行 executor
  /// - 有 in-flight 且 pending 可合并 → 复用 pending 的 Completer (D-17)
  /// - 有 in-flight 且 pending 不可合并 → 替换 pending（最新 wins）
  ///
  /// [timeout] 可选超时，默认 5 秒 (D-13)。
  /// [currentFullscreen] 当前全屏状态，用于 toggle 解析 (D-18)。
  Future<bool> enqueue(
    FullscreenRequest request,
    Future<bool> Function(FullscreenRequest) executor, {
    Duration timeout = const Duration(seconds: 5),
    bool currentFullscreen = false,
  }) {
    if (_disposed) {
      throw StateError('FullscreenCommandQueue disposed');
    }

    final windowId = request.windowId;
    final queue = _queues.putIfAbsent(windowId, () => _WindowQueue());

    // toggle 先解析为明确目标 (D-18)
    final resolved = _resolveToggle(request, currentFullscreen);

    return queue.enqueue(resolved, executor, timeout: timeout);
  }

  /// 取消指定 windowId 的当前 in-flight 命令。
  void cancel(int windowId) {
    _queues[windowId]?.cancelInFlight();
  }

  /// 释放所有资源 (P1-5)。
  ///
  /// - pending 的 Completer 立即 complete(false)
  /// - in-flight 的命令: 不取消，让 executor 自然完成，但完成后不 drain
  /// - 超时 Timer 全部 cancel
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final queue in _queues.values) {
      queue.dispose();
    }
    _queues.clear();
  }

  /// toggle 解析: 基于当前全屏状态转换为 Enter/Leave (D-18)。
  ///
  /// 已经是 Enter/Leave 的请求直接透传。
  static FullscreenRequest _resolveToggle(
    FullscreenRequest request,
    bool currentFullscreen,
  ) {
    return switch (request) {
      EnterFullscreen() || LeaveFullscreen() => request,
      ToggleFullscreen(:final preferredMode, :final windowId) =>
        currentFullscreen
            ? FullscreenRequest.leave(windowId: windowId)
            : FullscreenRequest.enter(
                mode: preferredMode ?? FullscreenMode.borderless,
                windowId: windowId,
              ),
    };
  }
}

/// 单窗口命令队列 — Completer 链核心实现。
class _WindowQueue {
  /// 当前正在执行的命令。
  _QueuedCommand? _inFlight;

  /// 等待执行的下一个命令。
  _QueuedCommand? _pending;

  /// 是否已 dispose。
  bool disposed = false;

  /// 入队命令。
  Future<bool> enqueue(
    FullscreenRequest request,
    Future<bool> Function(FullscreenRequest) executor, {
    Duration timeout = const Duration(seconds: 5),
  }) {
    // 合并检查 (D-17): in-flight 或 pending 存在且目标相同 → 复用 Completer
    if (_inFlight != null && _canMerge(_inFlight!.request, request)) {
      return _inFlight!.completer.future;
    }
    if (_pending != null && _canMerge(_pending!.request, request)) {
      return _pending!.completer.future;
    }

    final completer = Completer<bool>();
    final command = _QueuedCommand(request, completer, executor);

    if (_inFlight != null) {
      // 有 in-flight: 替换 pending (D-12)
      // 完成旧 pending 避免泄漏
      final old = _pending;
      _pending = command;
      if (old != null && !old.completer.isCompleted) {
        old.timer?.cancel();
        old.completer.complete(false);
      }
      return completer.future;
    }

    // 无 in-flight: 立即执行
    _execute(command, timeout: timeout);
    return completer.future;
  }

  /// 执行命令 — Completer 链核心。
  Future<void> _execute(
    _QueuedCommand command, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    _inFlight = command;

    // 启动超时 Timer (D-13)
    command.timer = Timer(timeout, () {
      if (!command.completer.isCompleted) {
        command.completer.complete(false);
      }
    });

    try {
      final result = await command.executor(command.request);
      if (!command.completer.isCompleted) {
        command.completer.complete(result);
      }
    } on Exception catch (e) {
      // executor 异常 → 返回 false，不抛出
      assert(() {
        // ignore: avoid_print
        print('[FullscreenCommandQueue] executor error: $e');
        return true;
      }());
      if (!command.completer.isCompleted) {
        command.completer.complete(false);
      }
    } finally {
      command.timer?.cancel();
      _inFlight = null;

      // 消费 pending — 但 disposed 后不 drain (P1-5)
      final next = _pending;
      _pending = null;
      if (next != null && !disposed && !next.completer.isCompleted) {
        unawaited(_execute(next, timeout: timeout));
      }
    }
  }

  /// 取消当前 in-flight 命令。
  void cancelInFlight() {
    final cmd = _inFlight;
    if (cmd != null && !cmd.completer.isCompleted) {
      cmd.timer?.cancel();
      cmd.completer.complete(false);
    }
  }

  /// 释放队列 (P1-5)。
  void dispose() {
    if (disposed) return;
    disposed = true;

    // pending complete(false)
    if (_pending != null && !_pending!.completer.isCompleted) {
      _pending!.timer?.cancel();
      _pending!.completer.complete(false);
    }
    _pending = null;

    // in-flight: 不取消，但 Timer cancel
    _inFlight?.timer?.cancel();
  }

  /// 判断两个命令是否可合并 (D-17)。
  ///
  /// 合并规则:
  /// 1. 同一 windowId
  /// 2. 目标全屏状态相同 (enter/leave + mode)
  static bool _canMerge(FullscreenRequest a, FullscreenRequest b) {
    if (a.windowId != b.windowId) return false;
    return _resolveTarget(a) == _resolveTarget(b);
  }

  /// 解析命令为目标全屏状态元组。
  ///
  /// 用于合并判断 — 比较两个命令是否指向同一目标。
  static (bool fullscreen, FullscreenMode mode) _resolveTarget(
    FullscreenRequest request,
  ) {
    return switch (request) {
      EnterFullscreen(:final mode) => (true, mode),
      LeaveFullscreen() => (false, FullscreenMode.windowed),
      // toggle 已在 FullscreenCommandQueue.enqueue 中解析，不应到达这里
      ToggleFullscreen() => throw StateError(
          'ToggleFullscreen must be resolved before entering _WindowQueue',
        ),
    };
  }
}

/// 待执行命令 — 携带请求、Completer、executor 和超时 Timer。
class _QueuedCommand {
  _QueuedCommand(this.request, this.completer, this.executor);

  final FullscreenRequest request;
  final Completer<bool> completer;
  final Future<bool> Function(FullscreenRequest) executor;
  Timer? timer;
}
