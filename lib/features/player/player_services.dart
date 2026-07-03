import 'package:flutter/foundation.dart';
import '../../kernel/engine/engine_state.dart';

import '../../kernel/bridge/window_bridge.dart';
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
  PlayerServices({required this.windowService, this.engineOverride});

  /// 异步创建并初始化 PlayerServices 实例
  static Future<PlayerServices> create({
    required WindowBridge windowService,
    EngineState? engineOverride,
  }) async {
    final services = PlayerServices(
      windowService: windowService,
      engineOverride: engineOverride,
    );
    await services.init();
    return services;
  }

  /// 可选的引擎覆盖（用于 MockEngine 调试模式）。
  final EngineState? engineOverride;

  late final EngineState engine;
  late final Playlist playlist;
  late final PlaybackController controller;
  late final VideoProcessingService videoProcessing;
  final WindowBridge windowService;

  final ValueNotifier<int> playlistGeneration = ValueNotifier(0);

  Future<void> init() async {
    engine = engineOverride ?? FvpEngine();
    playlist = Playlist();
    controller = PlaybackController(
      engine: engine,
      playlist: playlist,
      onNeedRebuild: () => playlistGeneration.value++,
    );
    final settings = await SettingsStore.load();
    await controller.init(settings: settings);
    videoProcessing = VideoProcessingService(engine, initialSettings: settings);
  }

  void dispose() {
    playlistGeneration.dispose();
    windowService.dispose();
    videoProcessing.dispose();
    controller.dispose();
    engine.dispose();
  }
}
