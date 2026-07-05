/// Services 层断点保存模块 — 播放位置持久化
///
/// 本文件实现 [BreakpointSaver] 负责在引擎暂停或销毁时保存当前播放位置，
/// 确保应用重启后能从上次播放位置继续播放。
///
/// 架构位置：PlaybackController → **BreakpointSaver** → EngineState.state + PlaylistStore
/// 设计模式：Observer（观察者模式）— 监听 MediaState.paused 触发保存
/// 保存时机：暂停时（实时保存）+ dispose 时（兜底保存）
library;

import '../../../kernel/engine/engine_state.dart';
import '../../../kernel/persistence/playlist_store.dart';
import '../../../kernel/playlist/playlist.dart';

/// 断点保存策略 — 引擎暂停或销毁时保存当前播放位置
///
/// 保存逻辑：
/// - 暂停时（_onStateChanged）：保存当前播放位置到播放列表并持久化
/// - dispose 时：兜底保存，确保不丢失最后的播放进度
///
/// 使用方式：通过 PlaybackController 的构造函数创建并调用 init()。
class BreakpointSaver {
  BreakpointSaver({
    required this.engine,
    required this.playlist,
  });

  /// 视频渲染引擎 — 监听 state 和 position ValueNotifier
  final EngineState engine;

  /// 播放列表 — 更新当前位置信息并触发持久化
  final Playlist playlist;

  /// 注册引擎状态监听器
  void init() {
    engine.state.addListener(_onStateChanged);
  }

  /// 引擎状态变化回调 — 暂停时保存断点位置
  void _onStateChanged() {
    if (engine.state.value != MediaState.paused) return;
    final idx = playlist.currentIndex;
    if (idx < 0) return;
    playlist.updatePosition(
      idx,
      engine.position.value,
      engine.duration.value,
    );
    PlaylistStore.save(playlist);
  }

  /// 释放资源 — 注销监听器，兜底保存当前位置
  ///
  /// 只在有有效播放进度时保存（position > 0）。
  void dispose() {
    engine.state.removeListener(_onStateChanged);
    final idx = playlist.currentIndex;
    // position > 0 表示用户实际播放过，保存 "0 位置" 没有意义
    if (idx >= 0 && engine.position.value > 0) {
      playlist.updatePosition(
        idx,
        engine.position.value,
        engine.duration.value,
      );
      PlaylistStore.save(playlist);
    }
  }
}
