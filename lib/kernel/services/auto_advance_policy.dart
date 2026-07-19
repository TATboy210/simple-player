/// 自动连播策略 — 监听引擎完成状态并决定下一首播放逻辑
///
/// 本文件实现 [AutoAdvancePolicy] 作为播放完成后的连播决策器：
/// - 单曲循环 (loopSingle) → 重播当前索引
/// - 其他模式 (loopAll / shuffle) → 自动播放下一首
///
/// 架构位置：PlaybackController → **AutoAdvancePolicy** → MediaEngine.state (ValueNotifier)
/// 设计模式：Strategy（策略模式）— 封装连播决策，可独立替换或扩展
library;

import 'dart:async';

import '../engine/engine_state.dart';
import '../models/play_mode.dart';
import '../diagnostics/kernel_logger.dart';
import 'playback_controller.dart';

final log = KernelLogger.I;

/// 自动连播策略 — 监听 [MediaState.completed] 并驱动播放器前进
///
/// 职责单一：只关心「播放完成后做什么」，不涉及设置恢复或断点保存。
/// 通过 [PlaybackController] 的回调访问播放列表和导航器，保持松耦合。
class AutoAdvancePolicy {
  AutoAdvancePolicy(this._controller);
  final PlaybackController _controller;

  bool _initialized = false;

  /// 初始化：注册引擎状态监听
  ///
  /// 幂等操作：多次调用只注册一次（_initialized 守卫）。
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _controller.engine.state.addListener(_onStateChanged);
  }

  /// 引擎状态变化回调 — 仅处理 [MediaState.completed]
  ///
  /// 状态机：
  /// - completed + loopSingle → 重播当前索引
  /// - completed + 其他模式 → 自动播放下一首
  /// - 其他状态 → 忽略
  void _onStateChanged() {
    if (_controller.engine.state.value != MediaState.completed) return;

    if (_controller.playlist.mode == PlayMode.loopSingle) {
      final idx = _controller.playlist.currentIndex;
      if (idx >= 0) unawaited(_replayIndex(idx));
    } else {
      unawaited(_autoAdvance());
    }
  }

  /// 单曲循环：重新播放指定索引
  Future<void> _replayIndex(int index) async {
    try {
      await _controller.navigator.playIndex(index);
    } on Exception catch (e, st) {
      log.e('AutoAdvancePolicy loopSingle replay failed: $e', stackTrace: st);
      _controller.onError?.call(e);
    }
  }

  /// 自动连播：播放下一首
  Future<void> _autoAdvance() async {
    try {
      await _controller.navigator.playNext();
    } on Exception catch (e, st) {
      log.e('AutoAdvancePolicy auto-advance failed: $e', stackTrace: st);
      _controller.onError?.call(e);
    }
  }

  /// 释放资源 — 注销引擎状态监听
  void dispose() {
    _controller.engine.state.removeListener(_onStateChanged);
  }
}
