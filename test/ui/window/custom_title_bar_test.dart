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

    testWidgets('double tap on title area toggles maximize via setMode', (
      tester,
    ) async {
      // 2026-09-06 双击检测：两次按下间隔 <=300ms 且位移 <=24px →
      // 判定双击，经 setMode 切换最大化/还原（原生 HTCAPTION 模拟不产生
      // 系统级 WM_NCLBUTTONDBLCLK，Dart 层检测是唯一路径）。
      await tester.pumpWidget(
        _wrapWithApp(CustomTitleBar(windowService: windowService)),
      );
      await tester.pump();

      final dragAreaCenter = tester.getCenter(
        find.byKey(const ValueKey('titlebar-minimize')),
      );
      final titlePoint = Offset(dragAreaCenter.dx - 200, dragAreaCenter.dy);

      // Act — 快速双击（100ms 间隔 < 300ms 阈值）。
      await tester.tapAt(titlePoint);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(titlePoint);
      await tester.pumpAndSettle();

      // Assert — 双击切换到最大化（setMode 被 Dart 层调用）。
      expect(windowService.lastModeValue, WindowMode.maximized);
      // 裸点击（无位移）不触发 onPanStart — GestureDetector 方案下
      // startDragging 仅在真实拖动（超过 slop）时发生。
      expect(windowService.startDraggingCallCount, 0);
    });

    testWidgets('double tap on maximized title area restores to windowed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithApp(CustomTitleBar(windowService: windowService)),
      );
      await tester.pump();

      final dragAreaCenter = tester.getCenter(
        find.byKey(const ValueKey('titlebar-minimize')),
      );
      final titlePoint = Offset(dragAreaCenter.dx - 200, dragAreaCenter.dy);

      // Arrange — 最大化态。
      windowService.mode.value = WindowMode.maximized;

      // Act — 快速双击。
      await tester.tapAt(titlePoint);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(titlePoint);
      await tester.pumpAndSettle();

      // Assert — 还原为窗口态。
      expect(windowService.lastModeValue, WindowMode.windowed);
    });

    testWidgets('two slow taps on title area do not toggle maximize', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithApp(CustomTitleBar(windowService: windowService)),
      );
      await tester.pump();

      final dragAreaCenter = tester.getCenter(
        find.byKey(const ValueKey('titlebar-minimize')),
      );
      final titlePoint = Offset(dragAreaCenter.dx - 200, dragAreaCenter.dy);

      // Act — 慢速两次点击：直接构造带显式时间戳的事件（tapAt 的事件
      // timeStamp 不随 pump 推进，无法表达 500ms 间隔）。
      Future<void> tapAtWithStamp(Duration stamp) async {
        tester.binding.handlePointerEvent(
          PointerDownEvent(position: titlePoint, timeStamp: stamp),
        );
        tester.binding.handlePointerEvent(
          PointerUpEvent(position: titlePoint, timeStamp: stamp),
        );
        await tester.pump();
      }

      await tapAtWithStamp(Duration.zero);
      await tapAtWithStamp(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Assert — 不判定双击：无 setMode；裸点击不触发拖动（无位移
      // 不过 pan slop，与 pointer-down 直拖方案的差异由实现注释锁定）。
      expect(windowService.lastModeValue, isNull);
      expect(windowService.startDraggingCallCount, 0);
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
