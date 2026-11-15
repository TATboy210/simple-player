import 'package:cupertino_ui/cupertino_ui.dart' as cui;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter_localizations/flutter_localizations.dart' as fl;
import 'package:material_ui/material_ui.dart';
import 'package:material_ui/material_ui.dart' as mui;

import 'features/player/player_feature.dart';
import 'kernel/diagnostics/startup_timeline.dart';
import 'kernel/window_bridge/service/window_service.dart';
import 'l10n/app_localizations.dart';
import 'ui/dialogs/settings/error_feedback_settings.dart';
import 'ui/player/error_card_host.dart';
import 'ui/player/modal_hold_observer.dart';
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
    // v0.0.4 字体统一：ThemeData 声明 fontFamily 后，Material 系组件
    // （TextButton/DropdownButton/Tooltip 等）与项目内显式 TextStyle 使用
    // 同一字体族，消除对话框按钮等处的默认 Roboto/Segoe 混排。
    // 注意 copyWith 不支持 fontFamily —— 须在构造时传入。
    final theme =
        ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          fontFamily: Tokens.fontFamily,
        ).copyWith(
          tooltipTheme: const TooltipThemeData(
            waitDuration: Duration(milliseconds: Tokens.tooltipDelayShort),
          ),
        );

    // 语言解析（2026-09-06 中英文切换）：订阅设置 store，切换同帧生效。
    // system → null = MaterialApp 官方的「跟随系统」语义。
    return ValueListenableBuilder<ErrorFeedbackSettingsData>(
      valueListenable: ErrorFeedbackSettings.I.state,
      builder: (context, settings, _) {
        final Locale? locale = switch (settings.language) {
          AppLanguage.system => null,
          AppLanguage.english => const Locale('en'),
          AppLanguage.chinese => const Locale('zh'),
          AppLanguage.korean => const Locale('ko'),
          AppLanguage.japanese => const Locale('ja'),
          AppLanguage.spanish => const Locale('es'),
          AppLanguage.french => const Locale('fr'),
          AppLanguage.malay => const Locale('ms'),
          AppLanguage.vietnamese => const Locale('vi'),
        };
        return MaterialApp(
          locale: locale,
          // delegates 手工组装（生成文件的 localizationsDelegates 常量不含
          // material_ui/cupertino_ui 侧）：SDK 三件覆盖 flutter/material 与
          // widgets 组件链；mui/cui 两件覆盖 material_ui/cupertino_ui 组件链
          // —— 二者的 MaterialLocalizations/CupertinoLocalizations 是不同
          // Type，缺任一侧都会触发 "locale not supported by all delegates"
          // 警告（框架按 delegate.type 去重检查）。flutter_localizations 的
          // Global* 已弃用，待 gen-l10n 模板迁移后此列表可整体换 mui/cui 版。
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            AppLocalizations.delegate,
            // SDK 三件：flutter_localizations 的 Global* 在 3.50 弃用，但其
            // 支持的 MaterialLocalizations/CupertinoLocalizations 类型与
            // mui/cui 的不是同一 Type，模板迁移前两边都要挂。
            // ignore: deprecated_member_use
            fl.GlobalMaterialLocalizations.delegate,
            fl.GlobalWidgetsLocalizations.delegate,
            // ignore: deprecated_member_use
            fl.GlobalCupertinoLocalizations.delegate,
            mui.GlobalMaterialLocalizations.delegate,
            cui.GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          theme: theme,
          darkTheme: theme,
          themeMode: ThemeMode.dark,
          // v0.0.5: 模态路由观察 — 控制栏自动隐藏在设置/菜单开启期间冻结.
          navigatorObservers: [ModalHoldObserver()],
          home: _buildPlayerHome(),
          builder: (context, navigator) =>
              buildErrorCardMount(context, navigator, mode: windowService.mode),
        );
      },
    );
  }

  Widget _buildPlayerHome() {
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
          style: const TextStyle(color: Tokens.fallbackTextColor),
        ),
      ),
    );
  }
}

/// 构建错误卡片挂载层（D-10 修订，2026-08-30 用户拍板；G-03-2 位置修订）。
///
/// 卡片挂载于 MaterialApp.builder 的 root Stack、**Navigator 之上**：
/// 全屏 route 与设置对话框均不再覆盖卡片，卡片在两者期间持续存活。
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
/// hit-test 边界（CARD-02 / T-03-04）：卡片层以 Positioned.fill +
/// CustomSingleChildLayout 铺满 Stack，卡片上限（宽 420、高 0.6×窗口高）在
/// 布局期由 delegate 计算，不再每帧读 MediaQuery 重建。点击穿透靠整条包装链
/// 自身不参与命中：RenderCustomSingleChildLayoutBox 是 RenderShiftedBox，
/// hitTestSelf 默认 false，只有卡片子树命中，空白区域落到下层内容。
/// 严禁在这条链上加带背景的 Container/GestureDetector(opaque)/IgnorePointer
/// 包卡片——任何会 hitTestSelf 的节点都会吞掉全应用的点击。
/// （Positioned 经 ValueListenableBuilder 构建仍作用于 RenderStack：VLB 不
/// 引入 render object，ParentData 直达 Stack，仅 top 值随 mode 变化。）
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
  BuildContext _, // 未使用 — 保留位置以兼容 MaterialApp.builder tear-off 签名.
  Widget? navigator, {
  ValueListenable<WindowMode>? mode,
}) {
  return Stack(
    children: [
      Positioned.fill(child: navigator ?? const SizedBox.shrink()),
      if (mode == null)
        const _ErrorCardLayer(top: _errorCardWindowedTop)
      else
        ValueListenableBuilder<WindowMode>(
          valueListenable: mode,
          builder: (context, current, _) => _ErrorCardLayer(
            top: current.isFullscreen ? Tokens.spMd : _errorCardWindowedTop,
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

/// 错误卡片定位层 —— 在 root Stack 内按 left/[top] 放置卡片并收口尺寸。
///
/// 尺寸上界在**布局期**由 [_ErrorCardLayoutDelegate] 依窗口约束计算
/// （宽 [Tokens.errorCardExpandedMaxWidth]、高 窗口高 ×
/// [Tokens.errorCardMaxHeightRatio]），窗口 resize 只触发该层重新布局，
/// 不再像旧写法（entry 内 `MediaQuery.sizeOf`）每帧重建 ConstrainedBox。
///
/// hit-test：层本身占满 Stack，但 CustomSingleChildLayout / Overlay /
/// Theatre 均不 hitTestSelf，命中仅落在卡片真实矩形，其余区域穿透（CARD-02）。
class _ErrorCardLayer extends StatelessWidget {
  const _ErrorCardLayer({required this.top});

  /// 卡片顶缘到窗口上缘的距离.
  final double top;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: _ErrorCardLayoutDelegate(
          left: Tokens.controlBarMarginH,
          top: top,
        ),
        child: const RepaintBoundary(child: _ErrorCardOverlayMount()),
      ),
    );
  }
}

/// 卡片布局代理 —— 约束（CR-01 尺寸收口）+ 顶左定位（G-03-2）。
///
/// RenderStack 原先对只有 left/top 锚点的 Positioned 子节点给**无界**约束，
/// 展开卡片曾被长调用栈撑到 1133px（800px 窗口），Flexible(
/// SingleChildScrollView) 滚动失效；此处显式给有界约束，卡片仍以顶左内在
/// 尺寸放置，超出高度上界的部分进入展开详情区滚动路径。
class _ErrorCardLayoutDelegate extends SingleChildLayoutDelegate {
  const _ErrorCardLayoutDelegate({required this.left, required this.top});

  final double left;
  final double top;

  @override
  Size getSize(BoxConstraints constraints) => constraints.biggest;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints(
      maxWidth: constraints.maxWidth < Tokens.errorCardExpandedMaxWidth
          ? constraints.maxWidth
          : Tokens.errorCardExpandedMaxWidth,
      maxHeight: constraints.maxHeight * Tokens.errorCardMaxHeightRatio,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(left, top);

  @override
  bool shouldRelayout(_ErrorCardLayoutDelegate oldDelegate) =>
      oldDelegate.left != left || oldDelegate.top != top;
}

/// 错误卡片挂载壳 —— 局部 Overlay（CR-01）。
///
/// 卡片挂载于 Navigator 之外（root Stack 层），子树内没有 Overlay 祖先；
/// 展开详情的 SelectableText 选择文本需要 Overlay，故自带一个最小 Overlay，
/// 尺寸由 [_ErrorCardLayoutDelegate] 的有界约束决定。
class _ErrorCardOverlayMount extends StatelessWidget {
  const _ErrorCardOverlayMount();

  @override
  Widget build(BuildContext context) {
    return Overlay(
      initialEntries: [
        OverlayEntry(
          // Overlay 以 tight 约束铺满 entry；Align 放松为 loose 并顶左对齐，
          // 卡片才能按内在尺寸呈现（Align 自身不参与命中，空白区仍穿透）.
          builder: (_) =>
              const Align(alignment: Alignment.topLeft, child: ErrorCardHost()),
        ),
      ],
    );
  }
}
