import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';
import 'package:simple_player_flutter/ui/window/custom_title_bar.dart';
import 'package:simple_player_flutter/kernel/window_bridge/window_manager_service.dart';

import '../../helpers/fake_window_service.dart';

Widget _wrapWithApp(Widget child, {double width = 800}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(width: width, height: Tokens.titleBarHeight, child: child),
    ),
  );
}

void main() {
  late FakeWindowService windowService;

  setUp(() {
    windowService = FakeWindowService();
  });

  tearDown(() {
    windowService.dispose();
  });

  group('CustomTitleBar drag area interaction', () {
    testWidgets('pan on title area triggers startDragging', (tester) async {
      await tester.pumpWidget(
        _wrapWithApp(CustomTitleBar(windowService: windowService)),
      );
      await tester.pump();

      // 在标题文本左侧空白处开始 pan — 应触发窗口拖动。
      final dragAreaCenter = tester.getCenter(
        find.byKey(const ValueKey('titlebar-minimize')),
      );
      await tester.dragFrom(
        Offset(dragAreaCenter.dx - 200, dragAreaCenter.dy),
        const Offset(30, 5),
      );
      // 等待 tooltip/double-tap 检测定时器结束，避免 pending timer 断言。
      await tester.pumpAndSettle();

      expect(windowService.startDraggingCallCount, greaterThan(0));
    });

    testWidgets('double tap on title area toggles maximize', (tester) async {
      await tester.pumpWidget(
        _wrapWithApp(CustomTitleBar(windowService: windowService)),
      );
      await tester.pump();

      final dragAreaCenter = tester.getCenter(
        find.byKey(const ValueKey('titlebar-minimize')),
      );
      final titlePoint = Offset(dragAreaCenter.dx - 200, dragAreaCenter.dy);

      await tester.tapAt(titlePoint);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(titlePoint);
      await tester.pumpAndSettle();

      expect(windowService.lastModeValue, WindowMode.maximized);
    });

    testWidgets('clicking close button does not trigger drag', (tester) async {
      await tester.pumpWidget(
        _wrapWithApp(CustomTitleBar(windowService: windowService)),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('titlebar-close')));
      await tester.pump();

      expect(windowService.closeCallCount, 1);
      expect(windowService.startDraggingCallCount, 0);
    });

    testWidgets('clicking minimize button does not trigger drag', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithApp(CustomTitleBar(windowService: windowService)),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('titlebar-minimize')));
      await tester.pump();

      expect(windowService.minimizeCallCount, 1);
      expect(windowService.startDraggingCallCount, 0);
    });

    testWidgets('pan on close button does not start window drag', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithApp(CustomTitleBar(windowService: windowService)),
      );
      await tester.pump();

      await tester.dragFrom(
        tester.getCenter(find.byKey(const ValueKey('titlebar-close'))),
        const Offset(40, 5),
      );
      await tester.pump();

      // 按钮区不持有 pan 手势 — 拖动不应触发 startDragging。
      expect(windowService.startDraggingCallCount, 0);
    });

    testWidgets('fullscreen hides title bar interaction', (tester) async {
      windowService.mode.value = WindowMode.fullscreen;
      await tester.pumpWidget(
        _wrapWithApp(CustomTitleBar(windowService: windowService)),
      );
      await tester.pumpAndSettle();

      // IgnorePointer 生效后按钮不可点击。
      await tester.tap(
        find.byKey(const ValueKey('titlebar-close')),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(windowService.closeCallCount, 0);
    });
  });
}
