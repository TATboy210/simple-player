import 'package:flutter/foundation.dart';

import 'media_state.dart';

/// 独立状态机 — 管理播放器主状态 + 两个辅助标志
///
/// 从 FvpEngine 中提取，拥有 3 个 ValueNotifier：
/// - [state] 主播放状态（6 值正交枚举）
/// - [isSeeking] 是否正在 seek
/// - [isBuffering] 是否正在缓冲
///
/// [transitionTo] 用 switch expression 穷举合法转换路径，
/// 编译期保证新增状态时所有路径都被更新。
///
/// [togglePlayPause] 通过 [onPlay]/[onPause] 回调注入解耦，
/// 不持有引擎引用，避免循环依赖。
class EngineStateMachine {
  /// 创建状态机
  ///
  /// [onPlay] 播放回调 — idle/paused/completed 状态 toggle 时调用
  /// [onPause] 暂停回调 — playing 状态 toggle 时调用
  EngineStateMachine({this.onPlay, this.onPause});

  /// 播放回调（idle/paused/completed → toggle）
  ///
  /// 可在构造后设置，用于解决 FvpEngine 的循环依赖
  ///（状态机先创建，engine.play/pause 后注入）
  VoidCallback? onPlay;

  /// 暂停回调（playing → toggle）
  ///
  /// 可在构造后设置，用于解决 FvpEngine 的循环依赖
  VoidCallback? onPause;

  /// 主播放状态 — 正交 6 值枚举
  final ValueNotifier<MediaState> state = ValueNotifier(MediaState.idle);

  /// 是否正在 seek — 独立于主状态
  final ValueNotifier<bool> isSeeking = ValueNotifier(false);

  /// 是否正在缓冲 — 独立于主状态
  final ValueNotifier<bool> isBuffering = ValueNotifier(false);

  /// 尝试转换到目标状态
  ///
  /// 返回 `true` 表示转换成功，`false` 表示非法转换被忽略。
  /// debug 模式下非法转换触发 assert 警告（不崩溃）；
  /// release 模式下非法转换被静默忽略。
  bool transitionTo(MediaState next, String caller) {
    final current = state.value;
    if (!_canTransitionTo(current, next)) {
      // debug 模式: assert 内打印警告（release 模式 assert 被编译器移除）
      assert(() {
        debugPrint(
          '⚠️ EngineStateMachine.$caller: illegal transition $current → $next',
        );
        return true;
      }());
      return false;
    }
    state.value = next;
    return true;
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
      MediaState.completed =>
        next == MediaState.opening ||
            next == MediaState.error ||
            next == MediaState.idle,
      MediaState.error =>
        next == MediaState.opening || next == MediaState.idle,
    };
  }

  /// 切换播放/暂停 — 通过回调注入，不持有引擎引用
  ///
  /// 状态 → 回调映射:
  /// - playing → [onPause]
  /// - idle/paused/completed → [onPlay]
  /// - opening/error → 无操作（不可 toggle）
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

  /// 释放所有 ValueNotifier 资源
  void dispose() {
    state.dispose();
    isSeeking.dispose();
    isBuffering.dispose();
  }
}
