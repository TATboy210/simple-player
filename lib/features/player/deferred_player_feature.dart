import 'package:flutter/material.dart';

import 'player_feature.dart' deferred as player_feature;

import '../../kernel/startup/startup_coordinator.dart';
import '../../l10n/app_localizations.dart';

/// 延迟加载的播放器功能组件
///
/// 使用 Dart `deferred as` 导入 PlayerFeature，
/// 在首次 build 时异步加载播放器模块库。
/// 加载期间通过 StartupCoordinator 上报进度（Splash 已在 App 层驱动）。
///
/// 回调参数使用 dynamic 以避免 eager 导入 FvpEngine 等重型类型。
/// 实际类型由 PlayerFeature 内部保证，SettingsPanel 内部也有正确的类型约束。
class DeferredPlayerFeature extends StatefulWidget {
  final StartupCoordinator coordinator;
  final void Function(
    BuildContext context,
    dynamic engine,
    dynamic videoProcessing,
  )
  onSettings;
  final void Function(BuildContext barCtx, TapUpDetails details)
  onSettingsSecondary;

  const DeferredPlayerFeature({
    super.key,
    required this.coordinator,
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
    } catch (e) {
      debugPrint('[DeferredPlayerFeature] loadLibrary failed: $e');
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
      onSettings: widget.onSettings,
      onSettingsSecondary: widget.onSettingsSecondary,
    );
  }
}
