/// Services 层状态监控模块 — 自动连播、断点保存、设置恢复
///
/// 本文件实现 [StateMonitor] 作为引擎状态变化的观察者，负责：
/// 1. 初始化时恢复持久化设置（音量、静音状态）
/// 2. 监听引擎状态变化，驱动断点保存和自动连播
/// 3. 销毁时异步保存所有运行时状态
///
/// 架构位置：PlaybackController → **StateMonitor** → MediaEngine.state (ValueNotifier)
/// 设计模式：Observer（观察者模式）— 监听 MediaState 变化触发行为
/// 与 AutoAdvancePolicy 的关系：StateMonitor 是早期实现，包含断点保存+设置恢复+自动连播。
/// AutoAdvancePolicy 是重构后的独立策略类，专注于自动连播逻辑。
library;

import '../engine/engine_state.dart';
import 'dart:async';

import '../utils/log.dart';
import '../models/play_mode.dart';
import '../persistence/playlist_store.dart';
import '../persistence/settings_store.dart';
import 'playback_controller.dart';

/// 状态监控服务 — 监听引擎状态变化并执行副作用
///
/// 三大职责：
/// - **设置恢复**：init() 时从 SettingsStore 加载音量/静音状态并应用到引擎
/// - **状态监听**：_onStateChanged() 处理 paused（断点保存）和 completed（自动连播）
/// - **销毁保存**：dispose() 异步保存当前音量/静音/播放模式和播放列表位置
///
/// 使用方式：通过 PlaybackController.monitor 访问，由 PlaybackController.init() 触发初始化。
class StateMonitor {
  StateMonitor(this._controller);
  final PlaybackController _controller;

  bool _initialized = false;

  /// 初始化：恢复设置 + 注册引擎状态监听
  ///
  /// [settings] 可选 — 调用方已加载时传入，避免重复 IO。
  ///幂等操作：多次调用只执行一次（_initialized 守卫）。
  Future<void> init({AppSettings? settings}) async {
    if (_initialized) return;
    _initialized = true;
    _controller.engine.state.addListener(_onStateChanged);

    // fire-and-forget：后台加载播放列表用于历史迁移，不阻塞主 UI
    unawaited(_loadPlaylistForMigration());

    try {
      final s = settings ?? await SettingsStore.load();
      _controller.engine.setVolume(s.volume);
      _controller.engine.setMute(s.isMuted);
    } on Exception catch (e) {
      log.e('StateMonitor.init load settings failed: $e');
    }
  }

  /// 加载播放列表仅用于历史迁移副作用，结果不恢复
  ///
  /// 使用 loadInBackground() 将文件 I/O + JSON 解析移至独立 Isolate，
  /// 不阻塞主 UI 线程。迁移逻辑仍在主 Isolate 回调中执行。
  Future<void> _loadPlaylistForMigration() async {
    try {
      await PlaylistStore.loadInBackground();
    } on Exception catch (e) {
      log.e('PlaylistStore.load migration failed: $e');
    }
  }

  /// 引擎状态变化回调 — 根据新状态执行相应副作用
  ///
  /// 状态机：
  /// - paused → 保存当前播放位置到播放列表（断点保存）
  /// - completed → 根据播放模式决定行为（单曲循环 or 自动下一首）
  /// - 其他状态 → 忽略
  void _onStateChanged() {
    final state = _controller.engine.state.value;

    // 暂停时保存断点位置
    if (state == MediaState.paused) {
      final idx = _controller.playlist.currentIndex;
      if (idx >= 0) {
        _controller.playlist.updatePosition(
          idx,
          _controller.engine.position.value,
          _controller.engine.duration.value,
        );
        _controller.savePlaylist();
      }
      return;
    }

    if (state != MediaState.completed) return;

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
      log.e('StateMonitor loopSingle replay failed: $e', stackTrace: st);
      _controller.onError?.call(e);
    }
  }

  /// 自动连播：播放下一首
  Future<void> _autoAdvance() async {
    try {
      await _controller.navigator.playNext();
    } on Exception catch (e, st) {
      log.e('StateMonitor auto-advance failed: $e', stackTrace: st);
      _controller.onError?.call(e);
    }
  }

  /// 释放资源 — 注销监听器，异步保存所有运行时状态
  ///
  /// 保存内容：
  /// - 当前播放位置（仅在有有效播放进度时保存）
  /// - 音量、静音状态、播放模式（fire-and-forget，不阻塞销毁流程）
  /// - 播放列表到持久化存储
  void dispose() {
    _controller.engine.state.removeListener(_onStateChanged);
    final idx = _controller.playlist.currentIndex;
    // position > 0 表示用户实际播放过，否则保存 "0 位置" 没有意义
    if (idx >= 0 && _controller.engine.position.value > 0) {
      _controller.playlist.updatePosition(
        idx,
        _controller.engine.position.value,
        _controller.engine.duration.value,
      );
      _controller.savePlaylist();
    }
    // fire-and-forget 保存：错误仅日志记录，不阻塞销毁流程
    unawaited(
      SettingsStore.saveVolume(
        _controller.engine.volume.value,
      ).catchError((Object e) => log.e('SettingsStore.saveVolume failed: $e')),
    );
    unawaited(
      SettingsStore.saveIsMuted(
        _controller.engine.isMuted.value,
      ).catchError((Object e) => log.e('SettingsStore.saveIsMuted failed: $e')),
    );
    unawaited(
      SettingsStore.savePlayMode(
        _controller.playlist.mode.index,
      ).catchError((Object e) => log.e('SettingsStore.savePlayMode failed: $e')),
    );
    unawaited(
      PlaylistStore.dispose().catchError((Object e) {
        log.e('PlaylistStore.dispose failed: $e');
      }),
    );
  }
}
