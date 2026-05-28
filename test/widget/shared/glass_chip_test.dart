import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/shared/glass_chip.dart';

void main() {
  group('GlassChip', () {
    Widget buildSubject({
      String label = '1.0x',
      bool selected = false,
      VoidCallback? onTap,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: GlassChip(
            label: label,
            selected: selected,
            onTap: onTap ?? () {},
          ),
        ),
      );
    }

    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.byType(GlassChip), findsOneWidget);
    });

    testWidgets('displays label text', (tester) async {
      await tester.pumpWidget(buildSubject(label: '1.5x'));
      expect(find.text('1.5x'), findsOneWidget);
    });

    testWidgets('taps trigger onTap callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildSubject(onTap: () => tapped = true));
      await tester.tap(find.byType(GlassChip));
      expect(tapped, isTrue);
    });

    testWidgets('selected state shows decoration', (tester) async {
      await tester.pumpWidget(buildSubject(selected: true));
      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect(container.decoration, isNotNull);
    });

    testWidgets('unselected state has no decoration', (tester) async {
      await tester.pumpWidget(buildSubject(selected: false));
      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect(container.decoration, isNull);
    });

    testWidgets('has button semantics', (tester) async {
      await tester.pumpWidget(buildSubject(label: '2.0x'));
      final semantics = find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.button ?? false),
      );
      expect(semantics, findsOneWidget);
    });

    testWidgets('respects custom width and height', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassChip(
              label: '1.0x',
              selected: false,
              onTap: () {},
              width: 64,
              height: 40,
            ),
          ),
        ),
      );
      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect(container.constraints?.maxWidth, 64);
      expect(container.constraints?.maxHeight, 40);
    });
  });
}
