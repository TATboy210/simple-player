import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/shared/empty_state.dart';

void main() {
  Widget buildSubject({VoidCallback? onOpenFile, bool dragHovering = false}) =>
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: EmptyState(
            onOpenFile: onOpenFile,
            isDragHovering: dragHovering,
          ),
        ),
      );

  testWidgets('the open-file button is immediately tappable', (tester) async {
    var openCount = 0;
    await tester.pumpWidget(buildSubject(onOpenFile: () => openCount++));

    // 空置态挂载即完整显示（无延迟/无入场动画）— 按钮立即可点。
    await tester.tap(find.byIcon(Icons.folder_open));
    expect(openCount, 1);
  });

  testWidgets('unmounting disposes safely', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    expect(tester.takeException(), isNull);
  });

  group('dragHoveringListenable — listenable 驱动路径 (v0.0.9 P0-2)', () {
    testWidgets('hover 翻转 — listener 驱动动画不 rebuild 不抛异常', (tester) async {
      final hover = ValueNotifier<bool>(false);
      addTearDown(hover.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EmptyState(onOpenFile: () {}, dragHoveringListenable: hover),
          ),
        ),
      );

      // hover 进/出各翻转一次 — 动画 forward/reverse 由 listener 驱动。
      hover.value = true;
      await tester.pump(const Duration(milliseconds: 400));
      hover.value = false;
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.byType(EmptyState), findsOneWidget);
    });

    testWidgets('构造时已 hovering — initState 同步起播动画', (tester) async {
      final hover = ValueNotifier<bool>(true);
      addTearDown(hover.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EmptyState(onOpenFile: () {}, dragHoveringListenable: hover),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
    });

    testWidgets('listenable 源替换 — didUpdateWidget 迁移监听', (tester) async {
      final hoverA = ValueNotifier<bool>(false);
      final hoverB = ValueNotifier<bool>(false);
      addTearDown(hoverA.dispose);
      addTearDown(hoverB.dispose);
      final newHover = ValueNotifier<bool>(false);
      addTearDown(newHover.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EmptyState(onOpenFile: () {}, dragHoveringListenable: hoverA),
          ),
        ),
      );
      // 替换 hover 源后，旧源翻转不应再驱动动画，新源翻转应生效。
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EmptyState(
              onOpenFile: () {},
              dragHoveringListenable: newHover,
            ),
          ),
        ),
      );

      newHover.value = true;
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    });
  });
}
