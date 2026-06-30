import '../../../kernel/engine/engine_state.dart';
import 'dart:async';

import '../../../kernel/utils/log.dart';
import '../../../kernel/models/play_mode.dart';
import '../../../kernel/persistence/playlist_store.dart';
import '../../../kernel/persistence/settings_store.dart';
import 'playback_controller.dart';

/// 状态监听 — 自动连播、断点保存、设置恢复
///
/// 职责: init, dispose, _onStateChanged
class StateMonitor {
  StateMonitor(this._controller);
  final PlaybackController _controller;

  bool _initialized = false;

  /// 初始化: 恢复设置 + 监听引擎状态
  ///
  /// [settings] 可选 — 调用方已加载时传入，避免重复 IO。
  Future<void> init({AppSettings? settings}) async {
    if (_initialized) return;
    _initialized = true;
    _controller.engine.state.addListener(_onStateChanged);

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

  /// 自动连播：引擎状态变为 completed 时根据播放模式决定行为
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

  /// 释放资源
  void dispose() {
    _controller.engine.state.removeListener(_onStateChanged);
    final idx = _controller.playlist.currentIndex;
    if (idx >= 0 && _controller.engine.position.value > 0) {
      _controller.playlist.updatePosition(
        idx,
        _controller.engine.position.value,
        _controller.engine.duration.value,
      );
      _controller.savePlaylist();
    }
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
