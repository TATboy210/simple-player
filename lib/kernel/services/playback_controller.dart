import 'package:flutter/foundation.dart';

import '../engine/media_engine.dart';
import '../persistence/playlist_store.dart';
import '../playlist/playlist.dart';
import 'file_operations.dart';
import 'playback_navigator.dart';
import 'state_monitor.dart';

/// 播放控制器 — 业务编排层（Orchestrator）
///
/// 由 3 个 mixin 组合而成:
///   - FileOperations: 文件打开（校验 → 添加到列表 → 播放）
///   - PlaybackNavigator: 播放列表导航（上一首/下一首/指定索引）
///   - StateMonitor: 自动连播、断点保存、设置恢复、播放列表管理
///
/// 本类持有共享状态和构造函数，savePlaylist 作为跨 mixin 共享方法。
class PlaybackController
    with FileOperations, PlaybackNavigator, StateMonitor {
  @override
  final MediaEngine engine;
  @override
  final Playlist playlist;
  @override
  final ValueNotifier<String> currentFileName = ValueNotifier<String>('');
  @override
  final VoidCallback onNeedRebuild;
  @override
  final void Function(Object error)? onError;

  PlaybackController({
    required this.engine,
    required this.playlist,
    required this.onNeedRebuild,
    this.onError,
  });

  /// 保存播放列表 — 异步写入，跨 mixin 共享
  @override
  void savePlaylist() {
    PlaylistStore.save(playlist);
  }
}
