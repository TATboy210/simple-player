import 'package:flutter/material.dart';

import 'features/player/player_feature.dart';
import 'kernel/diagnostics/startup_timeline.dart';
import 'kernel/window_bridge/window_manager_service.dart';
import 'l10n/app_localizations.dart';
import 'ui/theme/tokens.dart';

/// 应用壳 — MaterialApp、固定主题与本地化。
///
/// 启动链已压缩为两层直挂：main 完成基础设施后 runApp → 本壳直接组合
/// [PlayerFeature]（其内部自带 ready/error 状态管理）。历史的多阶段进度
/// Splash（生产不可达）与 deferred 包装（Windows 桌面无延迟收益）已移除，
/// 判据与取舍见长期记忆 project_controlbar_resize_constant 同期归档。
class App extends StatelessWidget {
  /// 启动计时器 — 由 [PlayerFeature] 在服务初始化完成后输出 Timeline 日志。
  final StartupTimeline startupTimeline;

  final WindowBridge windowService;

  /// 窗口初始化失败信息 — 非 null 时以文字态呈现，不阻断 App 构建。
  final String? windowInitError;

  const App({
    super.key,
    required this.startupTimeline,
    required this.windowService,
    this.windowInitError,
  });

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
      home: _buildPlayerHome(context),
    );
  }

  Widget _buildPlayerHome(BuildContext context) {
    final error = windowInitError;
    if (error != null) {
      return Center(
        child: Text(
          '${AppLocalizations.of(context).windowInitializationFailed}: $error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }
    return PlayerFeature(
      startupTimeline: startupTimeline,
      windowService: windowService,
    );
  }
}
