import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/app.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporter.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/diagnostics/startup_timeline.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/error_card.dart';
import 'package:simple_player_flutter/ui/player/error_card_host.dart';

import '../../helpers/fake_window_service.dart';

void main() {
  setUpAll(() {
    // 诊断单例测试惯例：KernelLogger 先复位再 init（App 组合根需要它）。
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  setUp(() async {
    // ErrorCardHost 经 ErrorReporterImpl.I 单例订阅呈现状态；
    // 每个测试重建单例，保证 FIFO/isReady 不跨测试泄漏。
    await ErrorReporterImpl.resetForTesting();
    ErrorReporterImpl.init();
  });

  // 真实 App 组合根，走 windowInitError 降级文字态 home —— 避免构造
  // MediaKitEngine/media_kit Player（headless mdk.dll 预存失败基线）。
  // builder 挂载层（D-10）对两种 home 一视同仁，降级路径同时充当
  // Task 2 的 windowInitError 存活用例。
  Widget buildApp() => App(
        startupTimeline: StartupTimeline(),
        windowService: FakeWindowService(),
        windowInitError: 'window init failed',
      );

  // 挂载层语义副本：直接复用 app.dart 的 buildErrorCardMount，
  // home 可注入自定义控件（穿透/故障注入用例需要）。
  Widget buildMountHarness({required Widget home}) => MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
        builder: buildErrorCardMount,
      );

  group('ErrorCardHost 端到端呈现（tracer）', () {
    testWidgets('accepts a report and shows the card at the top-left', (
      tester,
    ) async {
      // Arrange：挂载宿主并等首帧 post-frame flushPresentation（D-12 门）。
      await tester.pumpWidget(buildApp());
      await tester.pump();

      // Act：空闲相位接纳一份真实报告。
      ErrorReporterImpl.I.reportBootstrapSafely(
        StateError('引擎打开失败'),
        StackTrace.current,
      );
      await tester.pump();

      // Assert：卡片可见、显示报告 message 与「1 错误」计数徽标（D-01）。
      expect(find.byType(ErrorCard), findsOneWidget);
      expect(find.textContaining('引擎打开失败'), findsOneWidget);
      expect(find.text('1 错误'), findsOneWidget);

      // D-10/CARD-06：卡片挂载在 app root 左上角。
      final topLeft = tester.getTopLeft(find.byType(ErrorCard));
      expect(topLeft.dx, lessThan(100));
      expect(topLeft.dy, lessThan(100));
    });

    testWidgets('presents a pre-mount report after the first flush (D-12)', (
      tester,
    ) async {
      // Arrange：模拟 bootstrap 窗口 —— 挂载前报告已入队且呈现未就绪。
      ErrorReporterImpl.I.reportBootstrapSafely(
        StateError('bootstrap 窗口错误'),
        StackTrace.current,
      );
      expect(ErrorReporterImpl.I.presentation.value.isReady, isFalse);

      // Act：宿主 mount 后首帧 flushPresentation 补呈现；
      // post-frame 相位内到达的发布再推迟一帧落地。
      await tester.pumpWidget(buildApp());
      await tester.pump();
      await tester.pump();

      // Assert：预入队错误最终可见。
      expect(find.byType(ErrorCard), findsOneWidget);
      expect(find.textContaining('bootstrap 窗口错误'), findsOneWidget);
    });

    testWidgets('taps outside the card bounds reach widgets below', (
      tester,
    ) async {
      // Arrange：卡片可见 + 卡片矩形之外放一个可点击探针（基础穿透，
      // 完整 hit-test 套件在 03-02）。
      var tapped = false;
      await tester.pumpWidget(
        buildMountHarness(
          home: Scaffold(
            body: Center(
              child: GestureDetector(
                key: const ValueKey('probe'),
                onTap: () => tapped = true,
                child: Container(width: 200, height: 100, color: Colors.blue),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      ErrorReporterImpl.I.reportBootstrapSafely(
        StateError('穿透检查'),
        StackTrace.current,
      );
      await tester.pump();
      expect(find.byType(ErrorCard), findsOneWidget);

      // Act：点击屏幕中央探针（卡片位于左上角，二者不相交）。
      await tester.tap(find.byKey(const ValueKey('probe')));
      await tester.pump();

      // Assert：控件回调触发 —— 内在尺寸挂载未吞掉点击。
      expect(tapped, isTrue);
    });

    testWidgets('stays visible above an opaque fullscreen-style route', (
      tester,
    ) async {
      // Arrange：报告已呈现。
      await tester.pumpWidget(buildApp());
      await tester.pump();
      ErrorReporterImpl.I.reportBootstrapSafely(
        StateError('route 之下错误'),
        StackTrace.current,
      );
      await tester.pump();
      expect(find.byType(ErrorCard), findsOneWidget);

      // Act：push 一个不透明全屏样式 route（模拟 media_kit 全屏 route 层级）。
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Center(child: Text('opaque'))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert：D-10 —— 卡片在 route 之上仍可见。
      expect(find.text('opaque'), findsOneWidget);
      expect(find.byType(ErrorCard), findsOneWidget);
    });
  });
}
