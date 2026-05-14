import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kernel/bridge/window_bridge.dart';
import 'kernel/engine/fvp_engine.dart';
import 'kernel/models/play_mode.dart';
import 'kernel/persistence/settings_store.dart';
import 'kernel/playlist/playlist.dart';
import 'kernel/services/playback_controller.dart';
import 'kernel/services/video_processing_service.dart';
import 'ui/dialogs/settings_dialog.dart';
import 'l10n/app_localizations.dart';
import 'ui/player/player_screen.dart';
import 'ui/playlist/playlist_panel.dart';
import 'ui/widgets/osd_overlay.dart';
import 'ui/shared/empty_state.dart';

/// 应用壳 — 引擎/服务初始化 + 窗口管理 + 完整播放器 UI
class App extends StatefulWidget {
  const App({super.key, required this.sharedPreferences});

  final SharedPreferences sharedPreferences;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final FvpEngine _engine;
  late final Playlist _playlist;
  late final PlaybackController _controller;
  final ValueNotifier<Locale> _locale = ValueNotifier(const Locale('zh'));
  late final VideoProcessingService _videoProcessing;
  final ValueNotifier<int> _playlistGeneration = ValueNotifier(0);
  bool _ready = false;
  bool _isDragHovering = false;

  @override
  void initState() {
    super.initState();
    SettingsStore.prewarm(widget.sharedPreferences);
    _engine = FvpEngine();
    _playlist = Playlist();
    _controller = PlaybackController(
      engine: _engine,
      playlist: _playlist,
      onNeedRebuild: () => _playlistGeneration.value++,
    );
    _init();
  }

  Future<void> _init() async {
    final sw = Stopwatch()..start();
    try {
      final results = await Future.wait([
        _controller.init(),
        SettingsStore.loadLocale().then((code) {
          _locale.value = Locale(code);
          return code;
        }),
        SettingsStore.load(),
      ]);
      final settings = results[2] as AppSettings;
      _videoProcessing = VideoProcessingService(_engine, initialSettings: settings);
    } on Exception catch (e) {
      debugPrint('[App] init failed (continuing): $e');
      _videoProcessing = VideoProcessingService(_engine);
    }
    debugPrint('[App] init completed in ${sw.elapsedMilliseconds}ms');
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _playlistGeneration.dispose();
    _locale.dispose();
    _videoProcessing.dispose();
    _controller.dispose();
    _engine.dispose();
    WindowBridge.I.dispose();
    super.dispose();
  }

  Future<void> _openFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm',
        'mp3', 'flac', 'wav', 'aac', 'ogg', 'wma', 'm4a',
      ],
    );
    if (result != null && result.files.isNotEmpty) {
      for (final file in result.files) {
        if (file.path != null) {
          await _controller.openAndPlay(file.path!);
        }
      }
    }
  }

  void _onFilesDropped(List<String> paths) {
    _controller.addFiles(paths);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return ValueListenableBuilder<Locale>(
      valueListenable: _locale,
      builder: (context, locale, _) => MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: Stack(
          children: [
            PlayerScreen(
          engine: _engine,
          controller: _controller,
          playlist: _playlist,
          playlistGeneration: _playlistGeneration,
          isVideo: _engine.textureId.value != null,
          onOpenFile: _openFile,
          onPrevious: () => _controller.playPrevious(),
          onNext: () => _controller.playNext(),
          onTogglePlayMode: () {
            final modes = PlayMode.values;
            final nextIndex = (_playlist.mode.index + 1) % modes.length;
            _playlist.mode = modes[nextIndex];
            _playlistGeneration.value++;
          },
          onSettings: () => showDialog(
            context: context,
            builder: (_) => SettingsDialog(
              engine: _engine,
              videoProcessing: _videoProcessing,
            ),
          ),
          onFilesDropped: _onFilesDropped,
          onDragHoverChanged: (hovering) {
            setState(() => _isDragHovering = hovering);
          },
          playlistPanel: PlaylistPanel(
            playlist: _playlist,
            onSelectIndex: (i) => _controller.playIndex(i),
            onRemoveIndex: (i) {
              _playlist.removeAt(i);
              _playlistGeneration.value++;
            },
            onReorder: (oldIndex, newIndex) {
              _playlist.reorder(oldIndex, newIndex);
              _playlistGeneration.value++;
            },
            onClear: () {
              _playlist.clear();
              _playlistGeneration.value++;
            },
          ),
          emptyState: EmptyState(
            onOpenFile: _openFile,
            isDragHovering: _isDragHovering,
            engineState: _engine.state,
          ),
            ),
            const OsdOverlay(),
          ],
        ),
      ),
    );
  }
}
