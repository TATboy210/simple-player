import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'kernel/bridge/window_bridge.dart';
import 'kernel/startup/startup_coordinator.dart';
import 'features/player/deferred_player_feature.dart';
import 'ui/shared/progress_splash_screen.dart';
import 'ui/theme/tokens.dart';
import 'l10n/app_localizations.dart';

/// 应用壳 — MaterialApp、固定主题与本地化。
///
/// 播放器服务创建和 UI 组合已下沉到 PlayerFeature。
class App extends StatefulWidget {
  final StartupCoordinator coordinator;
  final WindowBridge windowService;

  /// 可选的 ready 页面构建器；测试可避开 media_kit 原生模块初始化。
  final WidgetBuilder? readyHomeBuilder;

  /// 启动前读取的主题模式；为空时保持 Midnight 深色默认值。
  final AdaptiveThemeMode? savedThemeMode;

  const App({
    super.key,
    required this.coordinator,
    required this.windowService,
    this.readyHomeBuilder,
    this.savedThemeMode,
  });

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final ValueNotifier<bool> _appReady = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() {
    if (mounted) {
      _appReady.value = true;
    }
    return Future.value();
  }

  @override
  void dispose() {
    _appReady.dispose();
    widget.windowService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdaptiveTheme(
    // 当前设计系统固定为 Midnight；浅色入口暂时复用深色主题，避免
    // Material 控件与 Tokens 深色视觉混合。后续可独立设计亮色令牌后替换。
    light: ThemeData.dark(),
    dark: ThemeData.dark(),
    initial: widget.savedThemeMode ?? AdaptiveThemeMode.dark,
    builder: (theme, darkTheme) => MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: theme.copyWith(
        tooltipTheme: const TooltipThemeData(
          waitDuration: Duration(milliseconds: Tokens.tooltipDelayShort),
        ),
      ),
      darkTheme: darkTheme.copyWith(
        tooltipTheme: const TooltipThemeData(
          waitDuration: Duration(milliseconds: Tokens.tooltipDelayShort),
        ),
      ),
      home: _StartupHome(
        appReady: _appReady,
        coordinator: widget.coordinator,
        readyHomeBuilder: widget.readyHomeBuilder ?? _buildPlayerHome,
      ),
    ),
  );

  Widget _buildPlayerHome(BuildContext context) => DeferredPlayerFeature(
    coordinator: widget.coordinator,
    windowService: widget.windowService,
  );
}

/// Navigator 的固定初始页面，只在页面内部切换启动画面与播放器。
///
/// 该边界保持根 MaterialApp、Navigator 与 Overlay 的 Element identity，避免
/// 启动阶段完成时整棵 accessibility 根树被卸载并重新创建。
class _StartupHome extends StatelessWidget {
  const _StartupHome({
    required this.appReady,
    required this.coordinator,
    required this.readyHomeBuilder,
  });

  final ValueListenable<bool> appReady;
  final StartupCoordinator coordinator;
  final WidgetBuilder readyHomeBuilder;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
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
