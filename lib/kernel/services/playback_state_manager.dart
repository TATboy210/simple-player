/// 播放状态管理 — 设置恢复、断点保存、运行时状态持久化
///
/// 本文件实现 [PlaybackStateManager] 作为播放器状态的持久化管理者：
/// 1. 初始化时从 SettingsStore 恢复音量/静音设置
/// 2. 监听引擎暂停状态，保存当前播放位置（断点续播）
/// 3. 销毁时异步保存所有运行时状态（音量、静音、播放模式、播放列表）
///
/// 架构位置：PlaybackController → **PlaybackStateManager** → MediaEngine.state (ValueNotifier)
/// 设计模式：Observer（观察者模式）— 监听 MediaState 变化触发持久化行为
library;

import 'dart:async';

import '../engine/engine_state.dart';
import '../persistence/playlist_store.dart';
import '../persistence/settings_store.dart';
import '../diagnostics/kernel_logger.dart';
import 'playback_controller.dart';

final log = KernelLogger.I;

/// 播放状态管理器 — 设置恢复 + 断点保存 + 销毁持久化
///
/// 职责：管理播放器的持久化状态，不涉及自动连播逻辑。
/// 自动连播由 [AutoAdvancePolicy] 独立处理。
class PlaybackStateManager {
  PlaybackStateManager(this._controller);
  final PlaybackController _controller;

  bool _initialized = false;

  /// 初始化：恢复设置 + 注册引擎状态监听
  ///
  /// [settings] 可选 — 调用方已加载时传入，避免重复 IO。
  /// 幂等操作：多次调用只执行一次（_initialized 守卫）。
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
      log.e('PlaybackStateManager.init load settings failed: $e');
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

  /// 引擎状态变化回调 — 仅处理 [MediaState.paused] 的断点保存
  ///
  /// 状态机：
  /// - paused → 保存当前播放位置到播放列表（断点续播）
  /// - 其他状态 → 忽略（自动连播由 AutoAdvancePolicy 处理）
  void _onStateChanged() {
    final state = _controller.engine.state.value;
    if (state != MediaState.paused) return;

    final idx = _controller.playlist.currentIndex;
    if (idx >= 0) {
      _controller.playlist.updatePosition(
        idx,
        _controller.engine.position.value,
        _controller.engine.duration.value,
      );
      _controller.savePlaylist();
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
