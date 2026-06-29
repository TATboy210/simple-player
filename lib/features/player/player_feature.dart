import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../kernel/bridge/window_bridge.dart';
import '../../kernel/persistence/settings_store.dart';
import '../../kernel/utils/log.dart';
import '../../kernel/startup/startup_coordinator.dart';
import '../../ui/player/player_screen.dart';
import '../../ui/shared/empty_state.dart';
import '../../ui/shared/play_mode_utils.dart';
import '../../ui/shared/osd_overlay.dart';
import '../../l10n/app_localizations.dart';
import '../../kernel/engine/player_engine.dart';
import 'services/video_processing_service.dart';
import 'player_services.dart';

/// 播放器功能组件 — UI 状态 + PlayerScreen 组合
///
/// 单一职责：
///   - 持有 PlayerServices 实例
///   - 管理 ready/drag-hover/custom-bindings 等 UI 状态
///   - 提供文件选择、拖放、播放模式切换等回调
///   - 组合 PlayerScreen
///
/// 需要 MaterialApp 级 BuildContext 的回调（设置面板、快捷菜单）
/// 由 App 通过构造函数传入。
class PlayerFeature extends StatefulWidget {
  final StartupCoordinator coordinator;
  final WindowBridge windowService;
  final PlayerEngine? engineOverride;
  final void Function(
    BuildContext context,
    PlayerEngine engine,
    VideoProcessingService videoProcessing,
  )
  onSettings;
  final void Function(BuildContext barCtx, TapUpDetails details)
  onSettingsSecondary;

  const PlayerFeature({
    super.key,
    required this.coordinator,
    required this.windowService,
    this.engineOverride,
    required this.onSettings,
    required this.onSettingsSecondary,
  });

  @override
  State<PlayerFeature> createState() => _PlayerFeatureState();
}

class _PlayerFeatureState extends State<PlayerFeature> {
  late final PlayerServices _services;
  bool _ready = false;
  bool _error = false;
  String _errorMessage = '';
  bool _isDragHovering = false;
  Map<String, String> _customBindings = {};

  @override
  void initState() {
    super.initState();
    _services = PlayerServices(
      windowService: widget.windowService,
      engineOverride: widget.engineOverride,
    );
    _init();
  }

  Future<void> _init() async {
    final sw = Stopwatch()..start();
    widget.coordinator.report(
      StartupPhase.playerInit,
      0.0,
      'Initializing engine...',
    );
    try {
      await _services.init();
      widget.coordinator.report(
        StartupPhase.playerInit,
        0.7,
        'Loading settings...',
      );
      _customBindings = await SettingsStore.loadShortcuts();
    } catch (e, stackTrace) {
      log.e('[PlayerFeature] init failed: $e', error: e, stackTrace: stackTrace);
      if (mounted) setState(() {
        _error = true;
        _errorMessage = '$e';
      });
      return;
    }
    log.d('[PlayerFeature] init completed in ${sw.elapsedMilliseconds}ms');
    widget.coordinator.markReady();
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _openFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'mp4',
        'mkv',
        'avi',
        'mov',
        'wmv',
        'flv',
        'webm',
        'mp3',
        'flac',
        'wav',
        'aac',
        'ogg',
        'wma',
        'm4a',
      ],
    );
    if (result != null && result.files.isNotEmpty) {
      for (final file in result.files) {
        if (file.path != null) {
          await _services.controller.openAndPlay(file.path!);
        }
      }
    }
  }

  void _onFilesDropped(List<String> paths) {
    _services.controller.addFiles(paths);
  }

  void _onTogglePlayMode() {
    _services.controller.togglePlayMode();
    final l10n = AppLocalizations.of(context);
    OsdService.I.show(
      playModeLabel(_services.playlist.mode, l10n),
      icon: playModeIcon(_services.playlist.mode),
    );
  }

  @override
  void dispose() {
    _services.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              'Player initialization failed',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    if (!_ready) {
      return const SizedBox.shrink();
    }

    final engine = _services.engine;
    final controller = _services.controller;
    final playlist = _services.playlist;

    // DEBUG: 首帧渲染后 dump widget 树
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugDumpApp();
    });

    return PlayerScreen(
      engine: engine,
      controller: controller,
      playlist: playlist,
      customBindings: _customBindings,
      playlistGeneration: _services.playlistGeneration,
      windowService: _services.windowService,
      onOpenFile: _openFile,
      onTogglePlayMode: _onTogglePlayMode,
      onSettings: () => widget.onSettings(
        context,
        _services.engine,
        _services.videoProcessing,
      ),
      onSettingsSecondary: (barCtx, details) =>
          widget.onSettingsSecondary(barCtx, details),
      onFilesDropped: _onFilesDropped,
      onDragHoverChanged: (hovering) {
        setState(() => _isDragHovering = hovering);
      },
      onFolderScanned: (folderPath, scanned) {
        playlist.addAll(scanned.map((i) => i.path).toList());
        _services.playlistGeneration.value++;
      },
      onClearHistory: () {
        final keptPaths = playlist.items
            .where((i) => (i.timestamp ?? 0) == 0)
            .map((i) => i.path)
            .toList();
        playlist.clear();
        playlist.addAll(keptPaths);
        _services.playlistGeneration.value++;
      },
      emptyState: EmptyState(
        onOpenFile: _openFile,
        isDragHovering: _isDragHovering,
        engineState: engine.state,
      ),
    );
  }
}
