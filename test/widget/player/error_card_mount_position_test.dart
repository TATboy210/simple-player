import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/app.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporter.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/window_bridge/window_manager_service.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/error_card_host.dart';
import 'package:simple_player_flutter/ui/player/error_capture_snapshot.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

/// G-03-2 挂载位置回归 —— 错误卡片窗口化时下移到视频区上缘（标题栏之下），
/// 全屏时保持 D-10（窗口左上角）。
///
/// 定位方案：Tokens.titleBarHeight 是 CustomTitleBar 实际布局高度的同一
/// 编译期常量（custom_title_bar.dart SizedBox 直接消费），单源保证永不错位；
/// 相比 GlobalKey/布局回调取视频区实际位置，零新耦合且精度足够（标题栏
/// 高度恒定，不随窗口尺寸/布局变化）。
void main() {
  setUpAll(() {
    // 诊断单例测试惯例：KernelLogger 先复位再 init（App 组合根需要它）。
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  setUp(() async {
    // ErrorCardHost 经 ErrorReporterImpl.I 单例订阅呈现状态；每个测试重建
    // 单例（循 error_card_host_test.dart 惯例）。effects 与生产 main.dart
    // 的 D-11 接线一致（reporter 既有 effects 缝 → ErrorCaptureSnapshot）。
    await ErrorReporterImpl.resetForTesting();
    ErrorCaptureSnapshot.I.resetForTesting();
    ErrorReporterImpl.init(effects: [ErrorCaptureSnapshot.I.record]);
  });

  /// 注入一份真实报告使卡片可见（挂载层对空队列渲染 SizedBox.shrink，
  /// 位置断言需要可见的宿主）。
  void reportVisibleError() {
    ErrorReporterImpl.I.reportBootstrapSafely(
      StateError('挂载位置验证'),
      StackTrace.current,
    );
  }

  /// 挂载层 harness：builder 注入 mode notifier 的 buildErrorCardMount。
  Widget buildHarness(ValueListenable<WindowMode>? mode) => MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const SizedBox.shrink(),
    builder: (context, navigator) =>
        buildErrorCardMount(context, navigator, mode: mode),
  );

  group('error card mount position (G-03-2)', () {
    testWidgets('windowed mode places the card below the title bar', (
      tester,
    ) async {
      // Arrange：挂载层收到窗口化 mode，卡片可见。
      final modeNotifier = ValueNotifier(WindowMode.windowed);
      addTearDown(modeNotifier.dispose);
      await tester.pumpWidget(buildHarness(modeNotifier));
      await tester.pump();
      reportVisibleError();
      await tester.pump();
      await tester.pump();

      // Assert：顶左 = 视频区上缘 + 既有呼吸距 —— 标题栏（32.0）不再被遮挡。
      final topLeft = tester.getTopLeft(find.byType(ErrorCardHost));
      expect(topLeft.dx, Tokens.controlBarMarginH);
      expect(
        topLeft.dy,
        Tokens.titleBarHeight + Tokens.spMd,
        reason: '窗口化时卡片顶缘必须位于标题栏下缘（视频区上缘，44.0）',
      );
    });

    testWidgets('fullscreen mode keeps D-10 window top-left', (tester) async {
      // Arrange：先窗口化挂载并使卡片可见。
      final modeNotifier = ValueNotifier(WindowMode.windowed);
      addTearDown(modeNotifier.dispose);
      await tester.pumpWidget(buildHarness(modeNotifier));
      await tester.pump();
      reportVisibleError();
      await tester.pump();

      // Act：切到全屏 mode（media_kit 全屏期间卡片仍显示，D-10）。
      modeNotifier.value = WindowMode.fullscreen;
      await tester.pump();
      await tester.pump();

      // Assert：全屏 = 窗口左上角（12.0），dx 不变。
      final topLeft = tester.getTopLeft(find.byType(ErrorCardHost));
      expect(topLeft.dx, Tokens.controlBarMarginH);
      expect(
        topLeft.dy,
        Tokens.spMd,
        reason: '全屏时 D-10 语义保持：卡片仍显示于窗口左上角',
      );
    });

    testWidgets('tear-off default (mode omitted) positions at windowed offset', (
      tester,
    ) async {
      // Arrange：builder 直接 tear-off 引用 buildErrorCardMount（mode 缺省，
      // error_card_host_test.dart:53 既有用法）——确定性回归锚。
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SizedBox.shrink(),
          builder: buildErrorCardMount,
        ),
      );
      await tester.pump();
      reportVisibleError();
      await tester.pump();
      await tester.pump();

      // Assert：缺省路径按窗口化偏移定位（既有挂载测试的确定性锚）。
      final topLeft = tester.getTopLeft(find.byType(ErrorCardHost));
      expect(topLeft.dx, Tokens.controlBarMarginH);
      expect(
        topLeft.dy,
        Tokens.titleBarHeight + Tokens.spMd,
        reason: 'mode 缺省时按窗口化偏移定位（确定性分支）',
      );
    });
  });
}
