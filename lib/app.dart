import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'kernel/engine/fvp_engine.dart';
import 'kernel/persistence/settings_store.dart';
import 'kernel/playlist/playlist.dart';
import 'kernel/services/playback_controller.dart';
import 'kernel/services/platform_service.dart';
import 'kernel/ui/theme/app_theme.dart';
import 'kernel/ui/window/custom_title_bar.dart';
import 'l10n/app_localizations.dart';

/// 应用壳 — 纯框架：引擎/服务初始化 + 窗口管理 + MaterialApp 骨架
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
  final ValueNotifier<String> _currentFileName = ValueNotifier('');
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    SettingsStore.prewarm(widget.sharedPreferences);
    _engine = FvpEngine();
    _playlist = Playlist();
    _controller = PlaybackController(
      engine: _engine,
      playlist: _playlist,
      onNeedRebuild: () {},
    );
    _init();
  }

  Future<void> _init() async {
    final sw = Stopwatch()..start();
    try {
      await Future.wait([
        PlatformService.I.initService(),
        _controller.init(),
        SettingsStore.loadLocale().then((code) {
          _locale.value = Locale(code);
        }),
      ]);
    } on Exception catch (e) {
      debugPrint('[App] init failed (continuing): $e');
    }
    debugPrint('[App] init completed in ${sw.elapsedMilliseconds}ms');
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _currentFileName.dispose();
    _locale.dispose();
    _controller.dispose();
    _engine.dispose();
    PlatformService.I.dispose();
    super.dispose();
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
        theme: AppTheme.darkTheme,
        home: ValueListenableBuilder<WindowMode>(
          valueListenable: PlatformService.I.mode,
          builder: (context, windowMode, _) => DragToResizeArea(
            enableResizeEdges: windowMode == WindowMode.fullscreen
                ? []
                : null,
            child: Scaffold(
              backgroundColor: Colors.black,
              body: Column(
                children: [
                  CustomTitleBar(fileName: _currentFileName),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Ready',
                        style: TextStyle(color: Colors.white54, fontSize: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
