import 'package:flutter/foundation.dart';

import '../diagnostics/kernel_logger.dart' show KernelLoggerImpl;
import 'media_state.dart';

/// 独立状态机 — 管理播放器主状态 + generation 守卫
///
/// Standalone state machine — manages playback state + generation guard.
///
/// 拥有 3 个 ValueNotifier + 1 个 generation 计数器：
/// Owns 3 ValueNotifiers + 1 generation counter:
/// - [state] 主播放状态（6 值正交枚举）
/// - [isSeeking] 是否正在 seek
/// - [isBuffering] 是否正在缓冲
/// - `_openGeneration` open 请求计数器（嵌入状态机，单一真相源）
///
/// [transitionTo] 是带 generation 检查的 setter — 不做合法性矩阵校验。
/// 转换合法性由调用方（引擎本地 guard）负责，这些 guard 同时控制是否调
/// 底层 player，顺带挡住非法转换，无需状态机再校验一遍。generation 过期时
/// 拒绝写入并经 KernelLogger.warn 记录，防止 stale 回调污染状态。
///
/// [togglePlayPause] 通过 [onPlay]/[onPause] 回调注入解耦，
/// 不持有引擎引用，避免循环依赖。
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
  /// Written by [transitionTo]; legality enforced by callers' local guards.
  final ValueNotifier<MediaState> state = ValueNotifier(MediaState.idle);

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

  /// 判断给定 generation 是否为当前代 — generation 逻辑内聚于状态机
  ///
  /// Whether [gen] matches the current open generation.
  /// Migrated from MediaKitEngine so generation logic lives entirely in the
  /// state machine; callers consume, not implement.
  bool isCurrent(int gen) => gen == _openGeneration;

  // ---- transitionTo（带 generation 检查的 setter）----

  /// 写入目标状态 — 带 generation 守卫的 setter
  ///
  /// Writes [next] as the new playback state. Does NOT validate legality —
  /// callers' local guards own that responsibility (and also decide whether
  /// to invoke the underlying player). The state machine only guards against
  /// stale callbacks via [generation].
  ///
  /// [generation] 提供时，若与当前代不匹配视为 stale 回调，拒绝写入并经
  /// KernelLogger.warn 记录（[caller] 标注来源，便于定位 stale 调用点）。
  /// [generation] 为 null 时直接写入（调用方已用本地 guard 把关）。
  void transitionTo(MediaState next, String caller, {int? generation}) {
    if (generation != null && generation != _openGeneration) {
      KernelLoggerImpl.I.warn(
        'EngineStateMachine.$caller: stale generation '
        '(provided=$generation, current=$_openGeneration)',
      );
      return;
    }
    state.value = next;
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

  /// 释放所有 ValueNotifier 资源 — 双重调用安全
  ///
  /// Release all ValueNotifier resources — safe to call twice.
  /// 第二次调用直接 return（_disposed 守卫）。
  /// Second call returns immediately (_disposed guard).
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    state.dispose();
    isSeeking.dispose();
    isBuffering.dispose();
  }

  /// dispose 守卫 — 防止重复释放
  bool _disposed = false;
}
