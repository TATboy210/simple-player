/// Services 层自动连播策略模块 — 策略模式实现
///
/// 本文件实现 [AutoAdvancePolicy] 策略类，负责引擎状态变为 completed 时
/// 根据播放模式（PlayMode）决定下一步行为。
///
/// 架构位置：PlaybackController → **AutoAdvancePolicy** → PlaybackNavigator → EngineState
/// 设计模式：Strategy（策略模式）— 通过构造函数注入依赖，状态变化时的行为可替换
/// 与 StateMonitor 的关系：StateMonitor 是早期实现（断点保存+设置恢复+自动连播混合），
/// AutoAdvancePolicy 是重构后的独立策略类，专注自动连播逻辑。
library;

import 'dart:async';

import '../../../kernel/engine/engine_state.dart';
import '../../../kernel/models/play_mode.dart';
import '../../../kernel/playlist/playlist.dart';
import '../../../kernel/utils/log.dart';
import 'playback_navigator.dart';

/// 自动连播策略 — 引擎状态变为 completed 时根据播放模式决定行为
///
/// 行为规则：
/// - loopSingle → 重新播放当前索引（单曲循环）
/// - loopAll / shuffle → 播放下一首（委托 PlaybackNavigator.playNext）
///
/// 构造时注入所有依赖，无需持有 PlaybackController 引用，
/// 便于独立构造和单元测试。
class AutoAdvancePolicy {
  AutoAdvancePolicy({
    required this.engine,
    required this.playlist,
    required this.navigator,
    required this.onError,
  });

  /// 视频渲染引擎 — 监听 state ValueNotifier
  final EngineState engine;

  /// 播放列表 — 获取当前索引和播放模式
  final Playlist playlist;

  /// 播放导航器 — 委托 playIndex / playNext
  final PlaybackNavigator navigator;

  /// 错误回调 — 捕获异常时调用（null 表示忽略错误）
  final void Function(Object error)? onError;

  /// 注册引擎状态监听器
  void init() {
    engine.state.addListener(_onStateChanged);
  }

  /// 引擎状态变化回调 — 检查 completed 状态后决定行为
  void _onStateChanged() {
    if (engine.state.value != MediaState.completed) return;

    if (playlist.mode == PlayMode.loopSingle) {
      final idx = playlist.currentIndex;
      if (idx >= 0) unawaited(_replayIndex(idx));
    } else {
      unawaited(_autoAdvance());
    }
  }

  /// 单曲循环：重新播放指定索引
  Future<void> _replayIndex(int index) async {
    try {
      await navigator.playIndex(index);
    } on Exception catch (e, st) {
      log.e('AutoAdvancePolicy loopSingle replay failed: $e', stackTrace: st);
      onError?.call(e);
    }
  }

  /// 自动连播：播放下一首
  Future<void> _autoAdvance() async {
    try {
      await navigator.playNext();
    } on Exception catch (e, st) {
      log.e('AutoAdvancePolicy auto-advance failed: $e', stackTrace: st);
      onError?.call(e);
    }
  }

  /// 注销引擎状态监听器
  void dispose() {
    engine.state.removeListener(_onStateChanged);
  }
}
