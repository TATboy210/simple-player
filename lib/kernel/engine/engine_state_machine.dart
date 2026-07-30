import 'package:flutter/foundation.dart';

import '../diagnostics/kernel_logger.dart' show KernelLoggerImpl;
import 'lifecycle_phase.dart';
import 'media_state.dart';
import 'transition_result.dart';

/// 独立状态机 — 管理播放器主状态 + 生命周期 + generation 守卫
///
/// Standalone state machine — manages playback state + lifecycle + generation guard.
///
/// 拥有 4 个 ValueNotifier + 1 个 generation 计数器：
/// Owns 4 ValueNotifiers + 1 generation counter:
/// - [state] 主播放状态（6 值正交枚举）
/// - [lifecyclePhase] 引擎生命周期（正交于 state）
/// - [isSeeking] 是否正在 seek
/// - [isBuffering] 是否正在缓冲
/// - `_openGeneration` open 请求计数器（嵌入状态机，单一真相源）
///
/// [transitionTo] 用 switch expression 穷举合法转换路径，
/// 编译期保证新增状态时所有路径都被更新。
/// 返回 [TransitionResult] 替代旧版 bool，非法转换通过 KernelLogger.warn 记录。
///
/// [togglePlayPause] 通过 [onPlay]/[onPause] 回调注入解耦，
/// 不持有引擎引用，避免循环依赖。
///
/// [recover] 从 error 状态恢复到 idle，清理 lastError。
class EngineStateMachine {
  /// 创建状态机 — 回调可选, 支持构造后注入以解耦循环依赖
  ///
  /// Creates state machine. Callbacks are optional and can be set after
  /// construction to break circular dependency with MediaKitEngine.
  ///
  /// [onPlay] invoked when toggle is requested from idle/paused/completed.
  /// [onPause] invoked when toggle is requested from playing.
  EngineStateMachine({this.onPlay, this.onPause});

  /// 播放回调 — idle/paused/completed 态 toggle 时调用
  ///
  /// Play callback — invoked when toggle is requested from idle/paused/completed.
  /// Set after construction to break circular dependency (state machine created
  /// before engine.play/pause is available).
  VoidCallback? onPlay;

  /// 暂停回调 — playing 态 toggle 时调用
  ///
  /// Pause callback — invoked when toggle is requested from playing state.
  /// Set after construction to break circular dependency.
  VoidCallback? onPause;

  /// 主播放状态 — 正交 6 值枚举 (idle/opening/playing/paused/completed/error)
  ///
  /// Primary playback state — orthogonal 6-value enum.
  /// Transitions validated by [transitionTo] via switch expression.
  final ValueNotifier<MediaState> state = ValueNotifier(MediaState.idle);

  /// 引擎生命周期阶段 — 正交于 state 的独立维度
  ///
  /// Engine lifecycle phase — orthogonal dimension independent of state.
  /// 与 MediaState 正交共存：state 表示播放行为，lifecyclePhase 表示引擎存活阶段。
  final ValueNotifier<LifecyclePhase> lifecyclePhase =
      ValueNotifier(LifecyclePhase.alive);

  /// 是否正在 seek — 独立于主状态, 可与任何 MediaState 共存
  ///
  /// Whether a seek operation is in progress — independent of primary state.
  /// Can coexist with any [MediaState] value.
  final ValueNotifier<bool> isSeeking = ValueNotifier(false);

  /// 是否正在缓冲 — 独立于主状态, 可与任何 MediaState 共存
  ///
  /// Whether buffering is in progress — independent of primary state.
  /// Can coexist with any [MediaState] value.
  final ValueNotifier<bool> isBuffering = ValueNotifier(false);

  // ---- OpenGenerationTracker（嵌入状态机，单一真相源）----

  /// open 请求计数器 — 每次 open 递增
  ///
  /// Open request counter — incremented on each open() call.
  /// 用于检测 stale 回调：回调携带的 generation 与当前值不匹配时拒绝状态转换。
  int _openGeneration = 0;

  /// 递增 generation 并返回新值 — 由 open() 调用
  ///
  /// Increments generation counter and returns new value.
  /// Called by open() to register a new open request.
  int nextGeneration() => ++_openGeneration;

  /// 当前 generation 值 — 只读查询
  ///
  /// Current generation value — read-only query.
  int get currentGeneration => _openGeneration;

  // ---- transitionTo（返回 TransitionResult，KernelLogger.warn 记录非法转换）----

  /// 尝试转换到目标状态
  ///
  /// Returns [TransitionResult] indicating outcome:
  /// - [TransitionResult.ok] 转换成功，状态已更新
  /// - [TransitionResult.illegal] 非法转换（违反状态矩阵），已通过 KernelLogger.warn 记录
  /// - [TransitionResult.staleGeneration] generation 过期（open 请求已被新请求取代）
  TransitionResult transitionTo(
    MediaState next,
    String caller, {
    int? generation,
  }) {
    final current = state.value;

    // 检查 generation（如果提供）
    // Check generation if provided
    if (generation != null && generation != _openGeneration) {
      KernelLoggerImpl.I.warn(
        'EngineStateMachine.$caller: stale generation '
        '(provided=$generation, current=$_openGeneration)',
      );
      return TransitionResult.staleGeneration;
    }

    if (!_canTransitionTo(current, next)) {
      // 所有构建模式下通过 KernelLogger.warn 记录（非 assert-only debugPrint）
      // Logged via KernelLogger.warn in all build modes (not assert-only debugPrint)
      KernelLoggerImpl.I.warn(
        'EngineStateMachine.$caller: illegal transition $current → $next',
      );
      return TransitionResult.illegal;
    }
    state.value = next;
    return TransitionResult.ok;
  }

  /// switch expression 穷举 — 编译期保证所有 case 覆盖
  static bool _canTransitionTo(MediaState current, MediaState next) {
    return switch (current) {
      MediaState.idle =>
        next == MediaState.opening ||
            next == MediaState.playing ||
            next == MediaState.error,
      MediaState.opening =>
        next == MediaState.idle ||
            next == MediaState.playing ||
            next == MediaState.error,
      MediaState.playing =>
        next == MediaState.paused ||
            next == MediaState.completed ||
            next == MediaState.error ||
            next == MediaState.idle,
      MediaState.paused =>
        next == MediaState.playing ||
            next == MediaState.error ||
            next == MediaState.idle,
      // completed→playing:补齐矩阵边,允许 completed 态按 play 重新播放。
      // 原 matrix 未收录此边,导致 togglePlayPause 在 completed 态调 onPlay→play()
      // 时 transitionTo(playing) 静默失败(known 契约-实现落差),违反"按钮永可点"。
      MediaState.completed =>
        next == MediaState.opening ||
            next == MediaState.playing ||
            next == MediaState.error ||
            next == MediaState.idle,
      MediaState.error =>
        next == MediaState.opening || next == MediaState.idle,
    };
  }

  /// 切换播放/暂停 — 通过回调注入, 不持有引擎引用, 避免循环依赖
  ///
  /// Toggle play/pause via injected callbacks. Does not hold engine reference.
  /// State-to-callback mapping:
  /// - playing → calls [onPause]
  /// - idle/paused/completed → calls [onPlay]
  /// - opening/error → no-op (not toggleable)
  void togglePlayPause() {
    final current = state.value;
    if (current == MediaState.playing) {
      onPause?.call();
    } else if (current == MediaState.idle ||
        current == MediaState.paused ||
        current == MediaState.completed) {
      onPlay?.call();
    }
    // opening/error — no-op
  }

  /// 从 error 状态恢复到 idle — 显式方法调用
  ///
  /// Recover from error state to idle — explicit method call.
  /// 仅在 state == MediaState.error 时生效，其他状态为 no-op。
  /// Only effective when state == MediaState.error, no-op otherwise.
  ///
  /// [lastError] 可选的错误通知器，恢复时同步清理。
  /// Optional error notifier — cleared on recovery.
  void recover({ValueNotifier<Object?>? lastError}) {
    if (state.value == MediaState.error) {
      state.value = MediaState.idle;
      lastError?.value = null;
    }
  }

  /// 释放所有 ValueNotifier 资源 — 双重调用安全
  ///
  /// Release all ValueNotifier resources — safe to call twice.
  /// 第二次调用直接 return（_disposed 守卫）。
  /// Second call returns immediately (_disposed guard).
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    lifecyclePhase.value = LifecyclePhase.disposed;
    state.dispose();
    lifecyclePhase.dispose();
    isSeeking.dispose();
    isBuffering.dispose();
  }

  /// dispose 守卫 — 防止重复释放
  bool _disposed = false;
}
