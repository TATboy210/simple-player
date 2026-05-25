import 'package:flutter/material.dart';
import 'kernel/persistence/settings_store.dart';
import 'kernel/startup/startup_coordinator.dart';
import 'features/player/deferred_player_feature.dart';
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

  const App({super.key, required this.coordinator});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  static const _accents = [
    Color(0xFF2C58F4), // Midnight
    Color(0xFF00B4D8), // Ocean
    Color(0xFF2D6A4F), // Forest
  ];

  final ValueNotifier<Locale> _locale = ValueNotifier(const Locale('zh'));
  final ValueNotifier<int> _themeIndex = ValueNotifier(0);
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
      await Future.wait([
        SettingsStore.loadLocale().then((code) {
          _locale.value = Locale(code);
          return code;
        }),
        SettingsStore.loadThemeIndex().then((index) {
          _themeIndex.value = index;
          return index;
        }),
      ]);
    } on Exception catch (e) {
      debugPrint('[App] settings load failed (continuing): $e');
    }
    widget.coordinator.report(StartupPhase.settings, 1.0, 'Preferences loaded');
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _locale.dispose();
    _themeIndex.dispose();
    super.dispose();
  }

  static ThemeData _buildTheme(int themeIndex) {
    final accent = _accents[themeIndex.clamp(0, _accents.length - 1)];
    return ThemeData.dark().copyWith(
      colorScheme: ColorScheme.dark(primary: accent, secondary: accent),
    );
  }

  void _showSettingsPanel(
    BuildContext context,
    dynamic engine,
    dynamic videoProcessing,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (dialogCtx) => SettingsPanel(
        engine: engine,
        videoProcessing: videoProcessing,
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

  void _showSettingsQuickMenu(BuildContext barCtx, TapUpDetails tap) {
    final l10n = AppLocalizations.of(barCtx);
    final currentAccent = Theme.of(barCtx).colorScheme.primary;

    final themeNames = [l10n.themeMidnight, l10n.themeOcean, l10n.themeForest];
    final currentThemeIdx = _accents.indexWhere((c) => c == currentAccent);

    final overlay = Overlay.of(barCtx).context.findRenderObject()! as RenderBox;
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
            style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
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
            style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
          ),
        ),
        for (var i = 0; i < _accents.length; i++)
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

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return MaterialApp(
        home: ValueListenableBuilder<StartupState>(
          valueListenable: widget.coordinator.state,
          builder: (context, startupState, _) =>
              ProgressSplashScreen(state: startupState),
        ),
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: _themeIndex,
      builder: (context, themeIdx, _) => ValueListenableBuilder<Locale>(
        valueListenable: _locale,
        builder: (context, locale, _) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: MaterialApp(
            key: const ValueKey('material-app'),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(themeIdx),
            home: DeferredPlayerFeature(
              coordinator: widget.coordinator,
              onSettings: (ctx, engine, videoProcessing) =>
                  _showSettingsPanel(ctx, engine, videoProcessing),
              onSettingsSecondary: _showSettingsQuickMenu,
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
