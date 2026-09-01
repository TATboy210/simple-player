import 'package:flutter/foundation.dart' show ValueListenable;
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
      builder: (context, navigator) =>
          buildErrorCardMount(context, navigator, mode: windowService.mode),
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

/// 构建错误卡片挂载层（D-10 修订，2026-08-30 用户拍板；G-03-2 位置修订）。
///
/// 卡片挂载于 MaterialApp.builder 的 root Stack、**Navigator 之上**：
/// media_kit 全屏 route 与设置对话框均不再覆盖卡片，卡片在两者期间持续存活。
/// D-05 的「设置打开时卡片被覆盖」语义被 D-10 取代；D-05 其余意图
/// （root Stack 顶层、打开期间存活）保留。
///
/// **双定位语义（G-03-2，UAT「卡片压标题栏」修复）**：[mode] 非 null 时
/// 订阅窗口模式（CARD-06 ValueListenable 惯例）——全屏（D-10）保持窗口
/// 左上角 [Tokens.spMd]；窗口化/最大化时卡片顶缘下移到标题栏下缘
/// （`_errorCardWindowedTop` = 视频区上缘 + 既有呼吸距），不再遮挡自定义
/// 标题栏。[mode] 为 null 时按窗口化偏移定位（确定性分支，供 tear-off
/// 调用方与非窗口宿主使用）。
///
/// hit-test 边界（CARD-02 / T-03-04）：宿主以 Positioned(left, top) 内在尺寸
/// 挂载——RenderStack 对未被子节点覆盖的位置 hitTestSelf 返回 false，点击
/// 自然穿透到下层内容。严禁 Positioned.fill/全尺寸透明容器包裹宿主，严禁
/// IgnorePointer 包卡片——过大的可命中矩形会吞掉全应用的点击。
/// （Positioned 经 ValueListenableBuilder 构建仍作用于 RenderStack：VLB 不
/// 引入 render object，ParentData 直达 Stack——穿透语义不变，仅 top 值随
/// mode 变化。）
///
/// 局部 Overlay（CR-01 修复配套）：卡片挂载于 Navigator 之外（D-10，root
/// Stack 层），子树内没有 Overlay 祖先 —— 展开详情的 SelectableText 在点击
/// 选择文本时 TextSelectionOverlay 会因 "No Overlay widget found" 断言崩溃
/// （HEAD 上即存在的隐性问题，CR-01 约束修复让栈文本变得可点后暴露）。
/// 故挂载壳自带一个最小 Overlay：entry 以 `canSizeOverlay` 让 theatre 按卡片
/// 内在尺寸自适应（Overlay 收到无限约束时的专用路径——有限约束会让
/// theatre tight-fill 撑满并破坏内在尺寸/穿透），卡片本身再由
/// [_ErrorCardOverlayMount] 内的 ConstrainedBox 收口（见其文档）。
Widget buildErrorCardMount(
  BuildContext context,
  Widget? navigator, {
  ValueListenable<WindowMode>? mode,
}) {
  return Stack(
    children: [
      Positioned.fill(child: navigator ?? const SizedBox.shrink()),
      if (mode == null)
        const Positioned(
          left: Tokens.controlBarMarginH,
          top: _errorCardWindowedTop,
          child: RepaintBoundary(child: _ErrorCardOverlayMount()),
        )
      else
        ValueListenableBuilder<WindowMode>(
          valueListenable: mode,
          builder: (context, current, _) => Positioned(
            left: Tokens.controlBarMarginH,
            top: current.isFullscreen ? Tokens.spMd : _errorCardWindowedTop,
            child: const RepaintBoundary(child: _ErrorCardOverlayMount()),
          ),
        ),
    ],
  );
}

/// 窗口化时错误卡片的顶缘偏移 —— 标题栏下缘 + 既有呼吸距（G-03-2）。
///
/// [Tokens.titleBarHeight] 是 CustomTitleBar 实际布局高度的同一编译期常量
/// （custom_title_bar.dart 的 SizedBox 直接消费），单源保证卡片顶缘与视频
/// 区上缘永不错位；相比 GlobalKey/布局回调取视频区实际位置，零新耦合且
/// 精度足够（标题栏高度恒定，不随窗口尺寸/布局变化）。
const double _errorCardWindowedTop = Tokens.titleBarHeight + Tokens.spMd;

/// 错误卡片挂载壳 —— 局部 Overlay + 尺寸收口（CR-01）。
///
/// 定位不归本壳负责：窗口化/全屏双位置语义（G-03-2）由外层
/// [buildErrorCardMount] 的 Positioned top 值决定，本壳只负责从 Positioned
/// 原点向下的 Overlay 提供与尺寸收口。
///
/// 两层职责缺一不可：
/// - **Overlay**（见 [buildErrorCardMount] 文档）：为卡片子树提供 Overlay
///   祖先；entry `canSizeOverlay: true` 使 theatre 在无限约束下按子树内在
///   尺寸定Size，空白区点击穿透语义（CARD-02）不变；
/// - **ConstrainedBox**：RenderStack 对只有 left/top 锚点的 Positioned 子
///   节点给**无界**约束——展开卡片曾被长调用栈撑到 1133px（800px 窗口），
///   Flexible(SingleChildScrollView) 滚动失效。宽度上界
///   [Tokens.errorCardExpandedMaxWidth]（折叠态天然更窄，message 另有
///   [Tokens.errorCardMaxWidth] 截断）；高度上界为窗口高度 ×
///   [Tokens.errorCardMaxHeightRatio]，超出部分进入展开详情区滚动路径。
///   卡片仍以顶左内在尺寸放置，命中区域只覆盖卡片自身矩形。
class _ErrorCardOverlayMount extends StatelessWidget {
  const _ErrorCardOverlayMount();

  @override
  Widget build(BuildContext context) {
    // 窗口尺寸经挂载子树内的 context 读取（builder 的 context 位于
    // WidgetsApp 的 MediaQuery 之上，不能直接在 buildErrorCardMount 里读）。
    final maxHeight =
        MediaQuery.sizeOf(context).height * Tokens.errorCardMaxHeightRatio;
    return Overlay(
      initialEntries: [
        OverlayEntry(
          canSizeOverlay: true,
          builder: (_) => ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Tokens.errorCardExpandedMaxWidth,
              maxHeight: maxHeight,
            ),
            child: const ErrorCardHost(),
          ),
        ),
      ],
    );
  }
}
