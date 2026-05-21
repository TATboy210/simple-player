import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kernel/bridge/window_bridge.dart';
import 'kernel/engine/fvp_engine.dart';
import 'kernel/persistence/settings_store.dart';
import 'kernel/playlist/playlist.dart';
import 'kernel/services/playback_controller.dart';
import 'kernel/services/video_processing_service.dart';
import 'ui/dialogs/settings_panel.dart';
import 'l10n/app_localizations.dart';
import 'ui/player/player_screen.dart';
import 'ui/shared/empty_state.dart';
import 'ui/shared/play_mode_utils.dart';
import 'ui/widgets/osd_overlay.dart';

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
  final ValueNotifier<int> _themeIndex = ValueNotifier(0);
  late final VideoProcessingService _videoProcessing;
  final ValueNotifier<int> _playlistGeneration = ValueNotifier(0);
  Map<String, String> _customBindings = {};
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
        SettingsStore.loadThemeIndex().then((index) {
          _themeIndex.value = index;
          return index;
        }),
        SettingsStore.load(),
      ]);
      final settings = results[3] as AppSettings;
      _videoProcessing = VideoProcessingService(
        _engine,
        initialSettings: settings,
      );
      _customBindings = await SettingsStore.loadShortcuts();
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
    _themeIndex.dispose();
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
          await _controller.openAndPlay(file.path!);
        }
      }
    }
  }

  void _onFilesDropped(List<String> paths) {
    _controller.addFiles(paths);
  }

  void _showSettingsPanel(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (dialogCtx) => SettingsPanel(
        engine: _engine,
        videoProcessing: _videoProcessing,
        onLocaleChanged: (code) {
          _locale.value = Locale(code);
          SettingsStore.saveLocale(code);
        },
        onThemeChanged: (index) {
          _themeIndex.value = index;
          SettingsStore.saveThemeIndex(index);
        },
        onShortcutsChanged: (bindings) {
          SettingsStore.saveShortcuts(bindings);
        },
      ),
    );
  }

  void _showSettingsQuickMenu(
      BuildContext barCtx, BuildContext appCtx, TapUpDetails tap) {
    final l10n = AppLocalizations.of(appCtx);
    final currentAccent = Theme.of(barCtx).colorScheme.primary;

    const accents = [
      Color(0xFF2C58F4),
      Color(0xFF00B4D8),
      Color(0xFF2D6A4F),
    ];
    final themeNames = [
      l10n.themeMidnight,
      l10n.themeOcean,
      l10n.themeForest,
    ];
    final currentThemeIdx = accents.indexWhere(
      (c) => c == currentAccent,
    );

    final overlay =
        Overlay.of(barCtx).context.findRenderObject()! as RenderBox;
    final pos = overlay.globalToLocal(tap.globalPosition);

    showMenu(
      context: barCtx,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
      color: const Color(0xE61A1A2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0x22FFFFFF)),
      ),
      items: <PopupMenuEntry<dynamic>>[
        PopupMenuItem(
          enabled: false,
          height: 32,
          child: Text(
            l10n.language,
            style: const TextStyle(
              color: Color(0x99FFFFFF),
              fontSize: 11,
            ),
          ),
        ),
        _QuickMenuItem(
          label: '中文',
          selected: _locale.value == const Locale('zh'),
          onTap: () {
            _locale.value = const Locale('zh');
            SettingsStore.saveLocale('zh');
          },
        ),
        _QuickMenuItem(
          label: 'English',
          selected: _locale.value == const Locale('en'),
          onTap: () {
            _locale.value = const Locale('en');
            SettingsStore.saveLocale('en');
          },
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          enabled: false,
          height: 32,
          child: Text(
            l10n.currentTheme,
            style: const TextStyle(
              color: Color(0x99FFFFFF),
              fontSize: 11,
            ),
          ),
        ),
        for (var i = 0; i < accents.length; i++)
          _QuickMenuItem(
            label: themeNames[i],
            selected: i == currentThemeIdx,
            onTap: () {
              _themeIndex.value = i;
              SettingsStore.saveThemeIndex(i);
            },
          ),
      ],
    );
  }

  static ThemeData _buildTheme(int themeIndex) {
    const accents = [
      Color(0xFF2C58F4), // Midnight
      Color(0xFF00B4D8), // Ocean
      Color(0xFF2D6A4F), // Forest
    ];
    final accent = accents[themeIndex.clamp(0, accents.length - 1)];
    return ThemeData.dark().copyWith(
      colorScheme: ColorScheme.dark(
        primary: accent,
        secondary: accent,
      ),
    );
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

    return ValueListenableBuilder<int>(
      valueListenable: _themeIndex,
      builder: (context, themeIdx, _) =>
          ValueListenableBuilder<Locale>(
        valueListenable: _locale,
        builder: (context, locale, _) => MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          onGenerateTitle: (context) =>
              AppLocalizations.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(themeIdx),
        home: Builder(
          builder: (ctx) => Stack(
            children: [
              PlayerScreen(
                engine: _engine,
                controller: _controller,
                playlist: _playlist,
                customBindings: _customBindings,
                playlistGeneration: _playlistGeneration,
                isVideo: _engine.textureId.value != null,
                onOpenFile: _openFile,
                onPrevious: () => _controller.playPrevious(),
                onNext: () => _controller.playNext(),
                onTogglePlayMode: () {
                  _controller.togglePlayMode();
                  final l10n = AppLocalizations.of(ctx);
                  OsdService.I.show(
                    playModeLabel(_playlist.mode, l10n),
                    icon: playModeIcon(_playlist.mode),
                  );
                },
                onSettings: () => _showSettingsPanel(ctx),
                onSettingsSecondary: (barCtx, details) =>
                    _showSettingsQuickMenu(barCtx, ctx, details),
                onFilesDropped: _onFilesDropped,
                onDragHoverChanged: (hovering) {
                  setState(() => _isDragHovering = hovering);
                },
                onFolderScanned: (folderPath, scanned) {
                  _playlist.addAll(scanned.map((i) => i.path).toList());
                  _playlistGeneration.value++;
                },
                onClearHistory: () {
                  final keptPaths = _playlist.items
                      .where((i) => (i.timestamp ?? 0) == 0)
                      .map((i) => i.path)
                      .toList();
                  _playlist.clear();
                  _playlist.addAll(keptPaths);
                  _playlistGeneration.value++;
                },
                emptyState: EmptyState(
                  onOpenFile: _openFile,
                  isDragHovering: _isDragHovering,
                  engineState: _engine.state,
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

// ── 快捷菜单项 — 选中态 + 点击回调 ──

class _QuickMenuItem extends PopupMenuItem<void> {
  _QuickMenuItem({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) : super(
          onTap: onTap,
          height: 36,
          child: Row(
            children: [
              if (selected)
                const Icon(Icons.check, size: 14, color: Color(0xFF2C58F4))
              else
                const SizedBox(width: 14),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF2C58F4)
                      : const Color(0xCCFFFFFF),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
}
