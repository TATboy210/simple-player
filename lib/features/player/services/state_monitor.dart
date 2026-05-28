import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../kernel/models/media_state.dart';
import '../../../kernel/models/play_mode.dart';
import '../../../kernel/persistence/playlist_store.dart';
import '../../../kernel/persistence/settings_store.dart';
import 'playback_controller.dart';

/// 状态监听 — 自动连播、断点保存、设置恢复
///
/// 职责: init, dispose, _onStateChanged
class StateMonitor {
  StateMonitor(this._rt);
  final PlaybackController _rt;

  bool _initialized = false;

  /// 初始化: 恢复设置 + 监听引擎状态
  ///
  /// [settings] 可选 — 调用方已加载时传入，避免重复 IO。
  Future<void> init({AppSettings? settings}) async {
    if (_initialized) return;
    _initialized = true;
    _rt.engine.state.addListener(_onStateChanged);

    unawaited(_loadPlaylistForMigration());

    try {
      final s = settings ?? await SettingsStore.load();
      _rt.engine.setVolume(s.volume);
      _rt.engine.setMute(s.isMuted);
    } on Exception catch (e) {
      debugPrint('StateMonitor.init load settings failed: $e');
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
      debugPrint('PlaylistStore.load migration failed: $e');
    }
  }

  /// 自动连播：引擎状态变为 completed 时根据播放模式决定行为
  void _onStateChanged() {
    final state = _rt.engine.state.value;

    // 暂停时保存断点位置
    if (state == MediaState.paused) {
      final idx = _rt.playlist.currentIndex;
      if (idx >= 0) {
        _rt.playlist.updatePosition(
          idx,
          _rt.engine.position.value,
          _rt.engine.duration.value,
        );
        _rt.savePlaylist();
      }
      return;
    }

    if (state != MediaState.completed) return;

    if (_rt.playlist.mode == PlayMode.loopSingle) {
      final idx = _rt.playlist.currentIndex;
      if (idx >= 0) {
        _rt.navigator.playIndex(idx).catchError((e) {
          debugPrint('StateMonitor loopSingle replay failed: $e');
          _rt.onError?.call(e);
        });
      }
    } else {
      _rt.navigator.playNext().catchError((e) {
        debugPrint('StateMonitor auto-advance failed: $e');
        _rt.onError?.call(e);
      });
    }
  }

  /// 释放资源
  void dispose() {
    _rt.engine.state.removeListener(_onStateChanged);
    final idx = _rt.playlist.currentIndex;
    if (idx >= 0 && _rt.engine.position.value > 0) {
      _rt.playlist.updatePosition(
        idx,
        _rt.engine.position.value,
        _rt.engine.duration.value,
      );
      _rt.savePlaylist();
    }
    unawaited(SettingsStore.saveVolume(_rt.engine.volume.value)
        .catchError((e) => debugPrint('SettingsStore.saveVolume failed: $e')));
    unawaited(SettingsStore.saveIsMuted(_rt.engine.isMuted.value)
        .catchError((e) => debugPrint('SettingsStore.saveIsMuted failed: $e')));
    unawaited(SettingsStore.savePlayMode(_rt.playlist.mode.index)
        .catchError((e) => debugPrint('SettingsStore.savePlayMode failed: $e')));
    unawaited(PlaylistStore.dispose().catchError((e) {
      debugPrint('PlaylistStore.dispose failed: $e');
    }));
  }
}
