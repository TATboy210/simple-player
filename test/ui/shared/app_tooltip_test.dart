import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/shared/app_tooltip.dart';
import 'package:simple_player_flutter/ui/shared/glass_container.dart';

void main() {
  for (final glass in [false, true]) {
    testWidgets(
      'native ${glass ? 'glass' : 'plain'} hover waits 400ms and exits',
      (tester) async {
        final focus = FocusNode();
        addTearDown(focus.dispose);
        final control = glass
            ? GlassButton.iconOnly(
                icon: Icons.play_arrow,
                tooltip: 'tip',
                focusNode: focus,
                onPressed: () {},
              )
            : AppTooltip(
                message: 'tip',
                child: TextButton(
                  focusNode: focus,
                  onPressed: () {},
                  child: const Text('plain'),
                ),
              );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: Center(child: control)),
          ),
        );
        expect(find.byTooltip('tip'), findsOneWidget);
        focus.requestFocus();
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.text('tip'),
          findsNothing,
          reason: 'focus alone is not sticky hover',
        );
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(find.byWidget(control)));
        await tester.pump(const Duration(milliseconds: 399));
        expect(find.text('tip'), findsNothing);
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('tip'), findsOneWidget);
        final rich = tester.widget<RichText>(
          find.descendant(
            of: find.text('tip'),
            matching: find.byType(RichText),
          ),
        );
        expect(rich.text.style?.decoration, isNot(TextDecoration.underline));
        await tester.tap(find.byWidget(control));
        await mouse.moveTo(Offset.zero);
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.text('tip'), findsNothing);
        expect(focus.hasFocus, isTrue);
        await mouse.removePointer();
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('empty message passes child through without tooltip', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppTooltip(message: ' ', child: Text('child')),
      ),
    );
    expect(find.text('child'), findsOneWidget);
    expect(find.byType(Tooltip), findsNothing);
  });

  for (final elapsed in [200, 600]) {
    testWidgets('native unmount at ${elapsed}ms releases hover', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppTooltip(message: 'old tip', child: Text('old')),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('old')));
      await tester.pump(Duration(milliseconds: elapsed));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('replacement'))),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('old tip'), findsNothing);
      expect(find.text('replacement'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await mouse.removePointer();
    });
  }

  testWidgets(
    'GlassButton preserves one Tab stop, activation and glass identity',
    (tester) async {
      final first = FocusNode();
      final next = FocusNode();
      addTearDown(first.dispose);
      addTearDown(next.dispose);
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                GlassButton(
                  icon: Icons.play_arrow,
                  label: 'Play',
                  tooltip: 'tip',
                  focusNode: first,
                  onPressed: () => calls++,
                ),
                TextButton(
                  focusNode: next,
                  onPressed: () {},
                  child: const Text('next'),
                ),
              ],
            ),
          ),
        ),
      );
      final glass = tester.element(find.byType(GlassContainer));
      first.requestFocus();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('tip'), findsNothing);
      expect(tester.element(find.byType(GlassContainer)), same(glass));
      expect(find.byType(BackdropFilter), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(calls, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      expect(next.hasPrimaryFocus, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
