import 'package:flutter/foundation.dart';

import '../../kernel/bridge/window_service.dart';
import '../../kernel/engine/fvp_engine.dart';
import '../../kernel/persistence/settings_store.dart';
import '../../kernel/playlist/playlist.dart';
import 'services/playback_controller.dart';
import 'services/video_processing_service.dart';

/// 播放器服务容器 — 创建 + 生命周期管理
///
/// 单一职责：持有播放器所有服务实例，提供 init/dispose 生命周期。
/// 不涉及 UI 状态，不涉及 BuildContext。
class PlayerServices {
  late final FvpEngine engine;
  late final Playlist playlist;
  late final PlaybackController controller;
  late final VideoProcessingService videoProcessing;
  late final WindowService windowService;

  final ValueNotifier<int> playlistGeneration = ValueNotifier(0);

  Future<void> init() async {
    engine = FvpEngine();
    playlist = Playlist();
    controller = PlaybackController(
      engine: engine,
      playlist: playlist,
      onNeedRebuild: () => playlistGeneration.value++,
    );
    final settings = await SettingsStore.load();
    await controller.init(settings: settings);
    videoProcessing = VideoProcessingService(engine, initialSettings: settings);
    windowService = WindowService();
    windowService.init();
  }

  void dispose() {
    playlistGeneration.dispose();
    windowService.dispose();
    videoProcessing.dispose();
    controller.dispose();
    engine.dispose();
  }
}
