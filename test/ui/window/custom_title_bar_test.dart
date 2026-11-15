import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';
import 'package:simple_player_flutter/ui/window/custom_title_bar.dart';
import 'package:simple_player_flutter/kernel/window_bridge/window_bridge.dart';

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

  /// 标题文本左侧空白处 — 位于拖动区内、避开右侧按钮组。
  Offset titlePoint(WidgetTester tester) {
    final minimize = tester.getCenter(
      find.byKey(const ValueKey('titlebar-minimize')),
    );
    return Offset(minimize.dx - 200, minimize.dy);
  }

  group('CustomTitleBar drag area interaction', () {
    testWidgets('pan on title area triggers startDragging', (tester) async {
      await tester.pumpWidget(
        _wrapWithApp(CustomTitleBar(windowService: windowService)),
      );
      await tester.pump();

      await tester.dragFrom(titlePoint(tester), const Offset(30, 5));
      // 等待 tooltip/double-tap 检测定时器结束，避免 pending timer 断言。
      await tester.pumpAndSettle();

      expect(windowService.startDraggingCallCount, 1);
    });

    testWidgets('double tap delegates to the system title bar action', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithApp(CustomTitleBar(windowService: windowService)),
      );
      await tester.pump();

      final point = titlePoint(tester);
      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(point);
      await tester.pumpAndSettle();

      // 最大化/还原的切换由系统执行 — 标题栏不再自行调用 setMode，
      // 模式经原生 maximize/restore 事件回流到 mode。
      expect(windowService.titleBarDoubleClickCallCount, 1);
      expect(windowService.lastModeValue, isNull);
      // 裸点击（无位移）不过 pan slop，不触发拖动。
      expect(windowService.startDraggingCallCount, 0);
    });

    testWidgets('two slow taps on title area are not a double click', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithApp(CustomTitleBar(windowService: windowService)),
      );
      await tester.pump();

      final point = titlePoint(tester);
      // 直接构造带显式时间戳的事件（tapAt 的 timeStamp 不随 pump 推进，
      // 无法表达 500ms 间隔）。
      Future<void> tapAtWithStamp(Duration stamp) async {
        tester.binding.handlePointerEvent(
          PointerDownEvent(position: point, timeStamp: stamp),
        );
        tester.binding.handlePointerEvent(
          PointerUpEvent(position: point, timeStamp: stamp),
        );
        await tester.pump();
      }

      await tapAtWithStamp(Duration.zero);
      await tapAtWithStamp(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(windowService.titleBarDoubleClickCallCount, 0);
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

    testWidgets('maximize button toggles between maximized and windowed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithApp(CustomTitleBar(windowService: windowService)),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('titlebar-maximize-toggle')));
      await tester.pump();
      expect(windowService.lastModeValue, WindowMode.maximized);

      await tester.tap(find.byKey(const ValueKey('titlebar-maximize-toggle')));
      await tester.pump();
      expect(windowService.lastModeValue, WindowMode.windowed);
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

      // 全屏 Offstage 收起整条标题栏: 按钮不在命中树中 (仍挂载, 保持
      // identity), 在原按钮位置点击也触达不到它。
      expect(find.byKey(const ValueKey('titlebar-close')), findsNothing);
      expect(
        find.byKey(const ValueKey('titlebar-close'), skipOffstage: false),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(790, 16));
      await tester.pump();

      expect(windowService.closeCallCount, 0);
    });

    testWidgets('drag area spans the full title bar height', (tester) async {
      await tester.pumpWidget(
        _wrapWithApp(CustomTitleBar(windowService: windowService)),
      );
      await tester.pump();

      // 回归: 命中区曾只有标题文字高 (约 17px), 上下空白拖不动/双击无效。
      final area = tester.getRect(
        find.byKey(const ValueKey('titlebar-drag-area')),
      );
      expect(area.top, 0);
      expect(area.height, Tokens.titleBarHeight);
      // 按钮组不在拖动区内 — 按钮仍由 Flutter 命中。
      final minimize = tester.getRect(
        find.byKey(const ValueKey('titlebar-minimize')),
      );
      expect(area.right, lessThanOrEqualTo(minimize.left));

      // 贴近顶边 (y=2) 的空白处双击同样生效。
      final point = Offset(area.left + 40, 2);
      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(point);
      await tester.pumpAndSettle();
      expect(windowService.titleBarDoubleClickCallCount, 1);
    });

    testWidgets('fullscreen collapses the title bar slot', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Column(
              children: [
                CustomTitleBar(windowService: windowService),
                const Expanded(child: SizedBox(key: ValueKey('content'))),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('content'))).dy,
        Tokens.titleBarHeight,
      );

      windowService.mode.value = WindowMode.fullscreen;
      await tester.pumpAndSettle();

      // 回归: 全屏只透明化会留一条 32px 空带 (用户所见「全屏仍有标题栏」)。
      expect(tester.getTopLeft(find.byKey(const ValueKey('content'))).dy, 0);

      windowService.mode.value = WindowMode.windowed;
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('content'))).dy,
        Tokens.titleBarHeight,
      );
    });
  });
}
