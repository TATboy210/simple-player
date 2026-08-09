import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'ui/theme/tokens.dart';
import 'kernel/bridge/window_bridge.dart';
import 'kernel/diagnostics/kernel_logger.dart';
import 'kernel/services/locale_service.dart';
import 'kernel/services/theme_service.dart';
import 'kernel/startup/startup_coordinator.dart';
import 'features/player/deferred_player_feature.dart';
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

  /// 可选的设置初始化入口；测试可注入可控 Future，生产环境仍加载真实偏好。
  final Future<void> Function()? initializeSettings;

  /// 可选的 ready 页面构建器；测试可避开 media_kit 原生模块初始化。
  final WidgetBuilder? readyHomeBuilder;

  const App({
    super.key,
    required this.coordinator,
    required this.windowService,
    this.initializeSettings,
    this.readyHomeBuilder,
  });

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final ValueNotifier<bool> _settingsReady = ValueNotifier<bool>(false);

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
      final initializeSettings = widget.initializeSettings;
      if (initializeSettings != null) {
        await initializeSettings();
      } else {
        await Future.wait([LocaleService.I.init(), ThemeService.I.init()]);
      }
    } on Exception catch (e) {
      KernelLogger.I.w('[App] settings load failed (continuing): $e');
    }
    widget.coordinator.report(StartupPhase.settings, 1.0, 'Preferences loaded');
    if (mounted) _settingsReady.value = true;
  }

  @override
  void dispose() {
    _settingsReady.dispose();
    widget.windowService.dispose();
    super.dispose();
  }

  void _showSettingsQuickMenu(BuildContext barCtx, TapUpDetails tap) {
    final l10n = AppLocalizations.of(barCtx);
    final currentAccent = Theme.of(barCtx).colorScheme.primary;

    final themeNames = [l10n.themeMidnight, l10n.themeOcean, l10n.themeForest];
    final currentThemeIdx = ThemeService.accents.indexWhere(
      (c) => c == currentAccent,
    );

    // findRenderObject() 返回 RenderObject?; 用 is 检查替代 `!`+`as`,
    // 类型提升后 overlay 为 RenderBox (无 `!`/`as`, 符合 strict-raw-types)
    final overlay = Overlay.of(barCtx).context.findRenderObject();
    if (overlay is! RenderBox) return;
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
    return ValueListenableBuilder<int>(
      valueListenable: ThemeService.I.themeIndex,
      builder: (context, _, _) {
        final theme = ThemeService.I.currentTheme;
        return AnimatedTheme(
          data: theme,
          duration: const Duration(milliseconds: 250),
          child: ValueListenableBuilder<Locale>(
            valueListenable: LocaleService.I.locale,
            builder: (context, locale, _) => MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              onGenerateTitle: (context) =>
                  AppLocalizations.of(context).appTitle,
              debugShowCheckedModeBanner: true,
              theme: theme,
              home: _StartupHome(
                settingsReady: _settingsReady,
                coordinator: widget.coordinator,
                readyHomeBuilder: widget.readyHomeBuilder ?? _buildPlayerHome,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayerHome(BuildContext context) => DeferredPlayerFeature(
    coordinator: widget.coordinator,
    windowService: widget.windowService,
    onSettingsSecondary: _showSettingsQuickMenu,
  );
}

/// Navigator 的固定初始页面，只在页面内部切换启动画面与播放器。
///
/// 该边界保持根 MaterialApp、Navigator 与 Overlay 的 Element identity，避免
/// settings 初始化完成时整棵 accessibility 根树被卸载并重新创建。
class _StartupHome extends StatelessWidget {
  const _StartupHome({
    required this.settingsReady,
    required this.coordinator,
    required this.readyHomeBuilder,
  });

  final ValueListenable<bool> settingsReady;
  final StartupCoordinator coordinator;
  final WidgetBuilder readyHomeBuilder;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: settingsReady,
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
                 color: selected ? Tokens.menuAccent : Tokens.menuTextNormal,
                 fontSize: 13,
               ),
             ),
           ],
         ),
       );
}
