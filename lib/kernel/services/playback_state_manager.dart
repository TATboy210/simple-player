/// 播放状态管理 — 设置恢复、断点保存、运行时状态持久化.
///
/// Playback state management — settings restore, breakpoint save, runtime persistence.
///
/// [PlaybackStateManager] persists playback state:
/// 1. Restores volume/mute from SettingsStore on init.
/// 2. Listens for engine pause → saves current position (resume playback).
/// 3. On dispose → async-saves all runtime state (volume, mute, play mode, playlist).
///
/// Architecture: PlaybackController → **PlaybackStateManager** → MediaEngine.state (ValueNotifier).
/// Pattern: Observer — listens to MediaState changes to trigger persistence.
library;

import 'dart:async';

import '../engine/engine_state.dart';
import '../persistence/playlist_store.dart';
import '../persistence/settings_store.dart';
import '../diagnostics/kernel_logger.dart';
import 'playback_controller.dart';

final log = KernelLogger.I;

/// 播放状态管理器 — 设置恢复 + 断点保存 + 销毁持久化.
///
/// Manages persisted playback state — no auto-advance logic.
/// Auto-advance is handled independently by [AutoAdvancePolicy].
class PlaybackStateManager {
  PlaybackStateManager(this._controller);
  final PlaybackController _controller;

  bool _initialized = false;

  /// 初始化：恢复设置 + 注册引擎状态监听.
  ///
  /// Restores settings and registers engine state listener.
  /// [settings] — optional, avoids redundant I/O when caller already loaded.
  /// Idempotent: guarded by [_initialized].
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

  /// 加载播放列表仅用于历史迁移副作用，结果不恢复.
  ///
  /// Loads playlist solely for history migration side-effect; result is discarded.
  /// Uses [PlaylistStore.loadInBackground] to offload file I/O + JSON parsing
  /// to a separate Isolate, avoiding main UI thread blocking.
  Future<void> _loadPlaylistForMigration() async {
    try {
      await PlaylistStore.loadInBackground();
    } on Exception catch (e) {
      log.e('PlaylistStore.load migration failed: $e');
    }
  }

  /// 引擎状态变化回调 — 仅处理 [MediaState.paused] 的断点保存.
  ///
  /// Engine state change callback — breakpoint save on [MediaState.paused] only.
  /// - paused → saves current position to playlist (resume playback)
  /// - other states → ignored (auto-advance handled by AutoAdvancePolicy)
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

  /// 释放资源 — 注销监听器，异步保存所有运行时状态.
  ///
  /// Disposes resources — unregisters listener, async-saves all runtime state.
  /// Saved: current position (only if progress > 0), volume, mute, play mode.
  /// All saves are fire-and-forget (errors logged, don't block disposal).
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
