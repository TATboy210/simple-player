import 'package:flutter/material.dart';
import 'ui/theme/tokens.dart';
import 'kernel/bridge/window_bridge.dart';
import 'kernel/engine/engine_state.dart';
import 'kernel/utils/log.dart';
import 'kernel/services/locale_service.dart';
import 'kernel/services/theme_service.dart';
import 'kernel/startup/startup_coordinator.dart';
import 'features/player/deferred_player_feature.dart';
import 'features/player/services/video_processing_service.dart';
import 'ui/dialogs/settings_panel.dart';
import 'ui/shared/progress_splash_screen.dart';
import 'l10n/app_localizations.dart';

/// 应用壳 — MaterialApp + 主题/语言 + 设置 UI
///
/// 播放器服务创建和 UI 组合已下沉到 PlayerFeature。
/// 本类仅负责：
///   - MaterialApp 壳（主题、国际化）
///   - 设置面板（需要 MaterialApp 级 BuildContext）
///   - 右键快捷菜单（语言/主题切换）
class App extends StatefulWidget {
  final StartupCoordinator coordinator;
  final WindowBridge windowService;
  final EngineState? engineOverride;

  const App({
    super.key,
    required this.coordinator,
    required this.windowService,
    this.engineOverride,
  });

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    widget.coordinator.report(
      StartupPhase.settings,
      0.0,
      'Loading preferences...',
    );
    try {
      await Future.wait([LocaleService.I.init(), ThemeService.I.init()]);
    } on Exception catch (e) {
      log.w('[App] settings load failed (continuing): $e');
    }
    widget.coordinator.report(StartupPhase.settings, 1.0, 'Preferences loaded');
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    widget.windowService.dispose();
    super.dispose();
  }

  void _showSettingsPanel(
    BuildContext context,
    EngineState engine,
    VideoProcessingService? videoProcessing,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (dialogCtx) => SettingsPanel(
        engine: engine,
        videoProcessing: videoProcessing,
      ),
    );
  }

  void _showSettingsQuickMenu(BuildContext barCtx, TapUpDetails tap) {
    final l10n = AppLocalizations.of(barCtx);
    final currentAccent = Theme.of(barCtx).colorScheme.primary;

    final themeNames = [l10n.themeMidnight, l10n.themeOcean, l10n.themeForest];
    final currentThemeIdx = ThemeService.accents.indexWhere(
      (c) => c == currentAccent,
    );

    final overlay = Overlay.of(barCtx).context.findRenderObject()! as RenderBox;
    final pos = overlay.globalToLocal(tap.globalPosition);

    showMenu(
      context: barCtx,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
      color: Tokens.menuBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Tokens.menuBorder),
      ),
      items: <PopupMenuEntry<dynamic>>[
        PopupMenuItem(
          enabled: false,
          height: 32,
          child: Text(
            l10n.language,
            style: const TextStyle(color: Tokens.menuTextMuted, fontSize: 11),
          ),
        ),
        _QuickMenuItem(
          label: '中文',
          selected: LocaleService.I.locale.value == const Locale('zh'),
          onTap: () => LocaleService.I.setLocale('zh'),
        ),
        _QuickMenuItem(
          label: 'English',
          selected: LocaleService.I.locale.value == const Locale('en'),
          onTap: () => LocaleService.I.setLocale('en'),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          enabled: false,
          height: 32,
          child: Text(
            l10n.currentTheme,
            style: const TextStyle(color: Tokens.menuTextMuted, fontSize: 11),
          ),
        ),
        for (var i = 0; i < ThemeService.accents.length; i++)
          _QuickMenuItem(
            label: themeNames[i],
            selected: i == currentThemeIdx,
            onTap: () => ThemeService.I.setTheme(i),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return MaterialApp(
        theme: ThemeService.I.currentTheme,
        home: ValueListenableBuilder<StartupState>(
          valueListenable: widget.coordinator.state,
          builder: (context, startupState, _) =>
              ProgressSplashScreen(state: startupState),
        ),
      );
    }

    return AnimatedTheme(
      data: ThemeService.I.currentTheme,
      duration: const Duration(milliseconds: 250),
      child: ValueListenableBuilder<Locale>(
        valueListenable: LocaleService.I.locale,
        builder: (context, locale, _) => MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          theme: ThemeService.I.currentTheme,
          home: DeferredPlayerFeature(
            coordinator: widget.coordinator,
            windowService: widget.windowService,
            engineOverride: widget.engineOverride,
            onSettings: (ctx, engine, videoProcessing) =>
                _showSettingsPanel(ctx, engine, videoProcessing),
            onSettingsSecondary: _showSettingsQuickMenu,
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
               const Icon(Icons.check, size: 14, color: Tokens.menuAccent)
             else
               const SizedBox(width: 14),
             const SizedBox(width: 8),
             Text(
               label,
               style: TextStyle(
                 color: selected
                     ? Tokens.menuAccent
                     : Tokens.menuTextNormal,
                 fontSize: 13,
               ),
             ),
           ],
         ),
       );
}
