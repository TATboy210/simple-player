import 'package:flutter/material.dart';

import 'features/player/player_feature.dart';
import 'kernel/diagnostics/startup_timeline.dart';
import 'kernel/window_bridge/window_manager_service.dart';
import 'l10n/app_localizations.dart';
import 'ui/player/error_card_host.dart';
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
      builder: buildErrorCardMount,
    );
  }

  Widget _buildPlayerHome(BuildContext context) {
    final error = windowInitError;
    if (error != null) {
      return _buildErrorHome(error);
    }
    return PlayerFeature(
      startupTimeline: startupTimeline,
      windowService: windowService,
    );
  }

  /// 窗口初始化失败时的降级文字态。
  ///
  /// 用 [Builder] 的子 context 查本地化：`home` 在 MaterialApp 之外用 App 自身
  /// context 构建，直接调 AppLocalizations.of(context) 会拿到 null（UAT Test 16
  /// 实机复现的崩溃根因）。
  Widget _buildErrorHome(String error) {
    return Builder(
      builder: (context) => Center(
        child: Text(
          '${AppLocalizations.of(context).windowInitializationFailed}: $error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}

/// 构建错误卡片挂载层（D-10 修订，2026-08-30 用户拍板）。
///
/// 卡片挂载于 MaterialApp.builder 的 root Stack、**Navigator 之上**：
/// media_kit 全屏 route 与设置对话框均不再覆盖卡片，卡片在两者期间持续存活。
/// D-05 的「设置打开时卡片被覆盖」语义被 D-10 取代；D-05 其余意图
/// （root Stack 顶层、打开期间存活）保留。
///
/// hit-test 边界（CARD-02 / T-03-04）：宿主以 Positioned(left, top) 内在尺寸
/// 挂载——RenderStack 对未被子节点覆盖的位置 hitTestSelf 返回 false，点击
/// 自然穿透到下层内容。严禁 Positioned.fill/全尺寸透明容器包裹宿主，严禁
/// IgnorePointer 包卡片——过大的可命中矩形会吞掉全应用的点击。
Widget buildErrorCardMount(BuildContext context, Widget? navigator) {
  return Stack(
    children: [
      Positioned.fill(child: navigator ?? const SizedBox.shrink()),
      const Positioned(
        left: Tokens.controlBarMarginH,
        top: Tokens.spMd,
        child: RepaintBoundary(child: ErrorCardHost()),
      ),
    ],
  );
}
