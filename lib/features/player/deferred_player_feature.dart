import 'package:flutter/material.dart';

import '../../kernel/bridge/window_bridge.dart';
import '../../kernel/engine/engine_state.dart';
import '../../kernel/utils/log.dart';
import '../../kernel/startup/startup_coordinator.dart';
import '../../l10n/app_localizations.dart';
import 'player_feature.dart' deferred as player_feature;
import 'services/video_processing_service.dart';

/// 延迟加载的播放器功能组件
///
/// 使用 Dart `deferred as` 导入 PlayerFeature，
/// 在首次 build 时异步加载播放器模块库。
/// 加载期间通过 StartupCoordinator 上报进度（Splash 已在 App 层驱动）。
///
/// 延迟加载播放器模块 — deferred as 避免 eager 导入 FvpEngine 等重型类型。
/// 回调使用抽象类型 EngineState（FvpEngine implements EngineState）。
class DeferredPlayerFeature extends StatefulWidget {
  final StartupCoordinator coordinator;
  final WindowBridge windowService;
  final EngineState? engineOverride;
  final void Function(
    BuildContext context,
    EngineState engine,
    VideoProcessingService? videoProcessing,
  )
  onSettings;
  final void Function(BuildContext barCtx, TapUpDetails details)
  onSettingsSecondary;

  const DeferredPlayerFeature({
    super.key,
    required this.coordinator,
    required this.windowService,
    this.engineOverride,
    required this.onSettings,
    required this.onSettingsSecondary,
  });

  @override
  State<DeferredPlayerFeature> createState() => _DeferredPlayerFeatureState();
}

class _DeferredPlayerFeatureState extends State<DeferredPlayerFeature> {
  bool _loaded = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    widget.coordinator.report(
      StartupPhase.playerModule,
      0.0,
      'Loading player module...',
    );
    try {
      await player_feature.loadLibrary();
      widget.coordinator.report(
        StartupPhase.playerModule,
        1.0,
        'Player module loaded',
      );
      if (mounted) setState(() => _loaded = true);
    } catch (e, stackTrace) {
      log.e(
        '[DeferredPlayerFeature] loadLibrary failed: $e',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Center(
        child: Text(
          AppLocalizations.of(context).playerLoadError,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }
    if (!_loaded) {
      return const SizedBox.shrink();
    }
    return player_feature.PlayerFeature(
      coordinator: widget.coordinator,
      windowService: widget.windowService,
      engineOverride: widget.engineOverride,
      onSettings: widget.onSettings,
      onSettingsSecondary: widget.onSettingsSecondary,
    );
  }
}
