import 'dart:async';

import 'package:flutter/foundation.dart';

import '../engine/media_engine.dart';
import '../models/media_state.dart';
import '../models/play_mode.dart';
import '../playlist/playlist.dart';
import '../persistence/playlist_store.dart';
import '../persistence/settings_store.dart';

/// 状态监听 mixin — 自动连播、断点保存、设置恢复、播放列表管理
///
/// 职责: init, dispose, _onStateChanged, removeAt, reorder, clearPlaylist, togglePlayMode
mixin StateMonitor {
  MediaEngine get engine;
  Playlist get playlist;
  ValueNotifier<String> get currentFileName;
  VoidCallback get onNeedRebuild;
  void Function(Object error)? get onError;

  Future<void> playIndex(int index);
  Future<void> playNext();
  void savePlaylist();

  bool _initialized = false;

  /// 初始化: 恢复设置 + 监听引擎状态
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    engine.state.addListener(_onStateChanged);

    final settingsFuture = SettingsStore.load();
    unawaited(_loadPlaylistForMigration());

    try {
      final settings = await settingsFuture;
      engine.setVolume(settings.volume);
      engine.setMute(settings.isMuted);
    } on Exception catch (e) {
      debugPrint('StateMonitor.init load settings failed: $e');
    }
  }

  /// 加载播放列表仅用于历史迁移副作用，结果不恢复
  Future<void> _loadPlaylistForMigration() async {
    try {
      await PlaylistStore.load();
    } on Exception catch (e) {
      debugPrint('PlaylistStore.load migration failed: $e');
    }
  }

  /// 自动连播：引擎状态变为 completed 时根据播放模式决定行为
  void _onStateChanged() {
    final state = engine.state.value;

    // 暂停时保存断点位置
    if (state == MediaState.paused) {
      final idx = playlist.currentIndex;
      if (idx >= 0) {
        playlist.updatePosition(
          idx,
          engine.position.value,
          engine.duration.value,
        );
        savePlaylist();
      }
      return;
    }

    if (state != MediaState.completed) return;

    if (playlist.mode == PlayMode.loopSingle) {
      final idx = playlist.currentIndex;
      if (idx >= 0) {
        playIndex(idx).catchError((e) {
          debugPrint('StateMonitor loopSingle replay failed: $e');
          onError?.call(e);
        });
      }
    } else {
      playNext().catchError((e) {
        debugPrint('StateMonitor auto-advance failed: $e');
        onError?.call(e);
      });
    }
  }

  /// 移除播放列表中指定索引
  Future<void> removeAt(int index) async {
    final wasCurrent = playlist.currentIndex == index;
    playlist.removeAt(index);
    if (wasCurrent) {
      engine.stop();
      final next = playlist.peekNext();
      if (next >= 0) {
        await playIndex(next);
      }
    }
    onNeedRebuild();
    savePlaylist();
  }

  /// 拖拽排序
  void reorder(int oldIndex, int newIndex) {
    playlist.reorder(oldIndex, newIndex);
    onNeedRebuild();
    savePlaylist();
  }

  /// 清空播放列表
  void clearPlaylist() {
    engine.stop();
    playlist.clear();
    currentFileName.value = '';
    onNeedRebuild();
    savePlaylist();
  }

  /// 切换播放模式
  void togglePlayMode() {
    final next = (playlist.mode.index + 1) % PlayMode.values.length;
    playlist.mode = PlayMode.values[next];
    onNeedRebuild();
    SettingsStore.savePlayMode(playlist.mode.index);
  }

  /// 释放资源
  void dispose() {
    engine.state.removeListener(_onStateChanged);
    final idx = playlist.currentIndex;
    if (idx >= 0 && engine.position.value > 0) {
      playlist.updatePosition(
        idx,
        engine.position.value,
        engine.duration.value,
      );
      savePlaylist();
    }
    unawaited(SettingsStore.saveVolume(engine.volume.value));
    unawaited(SettingsStore.saveIsMuted(engine.isMuted.value));
    unawaited(SettingsStore.savePlayMode(playlist.mode.index));
    unawaited(PlaylistStore.dispose());
    currentFileName.dispose();
  }
}
