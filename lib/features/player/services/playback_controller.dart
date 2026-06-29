import 'package:flutter/foundation.dart';

import '../../../kernel/engine/player_engine.dart';
import '../../../kernel/models/play_mode.dart';
import '../../../kernel/persistence/playlist_store.dart';
import '../../../kernel/persistence/settings_store.dart';
import '../../../kernel/playlist/playlist.dart';
import '../../../kernel/utils/debug_probe.dart';
import 'file_operations.dart';
import 'playback_navigator.dart';
import 'state_monitor.dart';
import 'subtitle_service.dart';

/// 播放控制器 — 播放器全部运行时能力的统一入口
///
/// 组合 PlaybackNavigator / FileOperations / StateMonitor 三个子模块，
/// UI 层只与本类交互。
class PlaybackController {
  PlaybackController({
    required this.engine,
    required this.playlist,
    required VoidCallback onNeedRebuild,
    void Function(Object error)? onError,
    SubtitleService? subtitleService,
  }) : _onNeedRebuild = onNeedRebuild,
       _onError = onError,
       _subtitleService = subtitleService {
    navigator = PlaybackNavigator(this);
    fileOps = FileOperations(this);
    monitor = StateMonitor(this);
  }

  final PlayerEngine engine;
  final Playlist playlist;
  final VoidCallback _onNeedRebuild;
  final void Function(Object error)? _onError;
  final SubtitleService? _subtitleService;

  late final PlaybackNavigator navigator;
  late final FileOperations fileOps;
  late final StateMonitor monitor;

  /// 调试探针 — 记录播放控制操作的耗时和事件。
  final DebugProbe probe = DebugProbeRegistry.register('playback');

  final ValueNotifier<String> currentFileName = ValueNotifier('');

  /// 通知 UI 层播放列表已变更
  void onNeedRebuild() => _onNeedRebuild();

  /// 错误回调（子模块通过 `_rt.onError?.call(e)` 调用）
  void Function(Object error)? get onError => _onError;

  /// 获取字幕服务（可能为 null）
  SubtitleService? get subtitleService => _subtitleService;

  /// 保存播放列表 — 异步写入，跨模块共享
  void savePlaylist() {
    PlaylistStore.save(playlist);
  }

  // ── 转发 — UI 层的统一入口 ──

  Future<void> playIndex(int i) => navigator.playIndex(i);
  Future<void> playNext() => navigator.playNext();
  Future<void> playPrevious() => navigator.playPrevious();
  Future<bool> openAndPlay(String p) => fileOps.openAndPlay(p);
  Future<int> addFiles(List<String> p) => fileOps.addFiles(p);
  ValueNotifier<String?> get validationError => fileOps.validationError;

  // ── 播放列表 CRUD（从 StateMonitor 提取）──

  /// 移除播放列表中指定索引
  Future<void> removeAt(int index) async {
    final wasCurrent = playlist.currentIndex == index;
    playlist.removeAt(index);
    if (wasCurrent) {
      engine.stop();
      final next = playlist.peekNext();
      if (next >= 0) {
        await navigator.playIndex(next);
      }
    }
    _onNeedRebuild();
    savePlaylist();
  }

  /// 拖拽排序
  void reorder(int oldIndex, int newIndex) {
    playlist.reorder(oldIndex, newIndex);
    _onNeedRebuild();
    savePlaylist();
  }

  /// 清空播放列表
  void clearPlaylist() {
    engine.stop();
    playlist.clear();
    currentFileName.value = '';
    _onNeedRebuild();
    savePlaylist();
  }

  /// 切换播放模式
  void togglePlayMode() {
    final next = (playlist.mode.index + 1) % PlayMode.values.length;
    playlist.mode = PlayMode.values[next];
    _onNeedRebuild();
    SettingsStore.savePlayMode(playlist.mode.index);
  }

  // ── 生命周期 ──

  Future<void> init({AppSettings? settings}) =>
      probe.measureAsync('init', () => monitor.init(settings: settings));

  void dispose() {
    monitor.dispose();
    currentFileName.dispose();
    fileOps.validationError.dispose();
  }
}
