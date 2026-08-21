import 'package:flutter/material.dart';

import 'kernel/startup/startup_coordinator.dart';
import 'kernel/window_bridge/window_manager_service.dart';
import 'features/player/deferred_player_feature.dart';
import 'ui/shared/progress_splash_screen.dart';
import 'ui/theme/tokens.dart';
import 'l10n/app_localizations.dart';

/// 应用壳 — MaterialApp、固定主题与本地化。
class App extends StatefulWidget {
  final StartupCoordinator coordinator;
  final WindowBridge windowService;
  final String? windowInitError;
  final WidgetBuilder? readyHomeBuilder;

  const App({
    super.key,
    required this.coordinator,
    required this.windowService,
    this.windowInitError,
    this.readyHomeBuilder,
  });

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final ValueNotifier<bool> _appReady = ValueNotifier<bool>(true);
  late final WindowBridge _windowService;

  @override
  void initState() {
    super.initState();
    _windowService = widget.windowService;
  }

  @override
  void dispose() {
    _appReady.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData.dark().copyWith(
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: Tokens.tooltipDelayShort),
      ),
    );

    return MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      home: _StartupHome(
        appReady: _appReady,
        coordinator: widget.coordinator,
        readyHomeBuilder: widget.readyHomeBuilder ?? _buildPlayerHome,
      ),
    );
  }

  Widget _buildPlayerHome(BuildContext context) {
    final error = widget.windowInitError;
    if (error != null) {
      return Center(
        child: Text(
          '${AppLocalizations.of(context).windowInitializationFailed}: $error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }
    return DeferredPlayerFeature(
      coordinator: widget.coordinator,
      windowService: _windowService,
    );
  }
}

/// 启动页：未就绪显示闪屏，就绪后进入播放器。
class _StartupHome extends StatelessWidget {
  const _StartupHome({
    required this.appReady,
    required this.coordinator,
    required this.readyHomeBuilder,
  });

  final ValueNotifier<bool> appReady;
  final StartupCoordinator coordinator;
  final WidgetBuilder readyHomeBuilder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: appReady,
      builder: (context, isReady, _) {
        if (isReady) return readyHomeBuilder(context);

        return ValueListenableBuilder<StartupState>(
          valueListenable: coordinator.state,
          builder: (context, startupState, _) =>
              ProgressSplashScreen(state: startupState),
        );
      },
    );
  }
}
