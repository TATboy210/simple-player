import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/shared/glass_container.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

void main() {
  group('GlassContainer', () {
    Widget buildSubject({
      GlassTier tier = GlassTier.normal,
      bool blurEnabled = true,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: GlassContainer(
            tier: tier,
            blurEnabled: blurEnabled,
            child: const Text('test'),
          ),
        ),
      );
    }

    testWidgets('renders with default params', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('test'), findsOneWidget);
    });

    testWidgets('renders with thin tier', (tester) async {
      await tester.pumpWidget(buildSubject(tier: GlassTier.thin));
      expect(find.text('test'), findsOneWidget);
    });

    testWidgets('blurEnabled=false skips BackdropFilter', (tester) async {
      await tester.pumpWidget(buildSubject(blurEnabled: false));
      // Should render ClipRRect but no BackdropFilter
      expect(find.byType(ClipRRect), findsWidgets);
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('blurEnabled=true renders BackdropFilter', (tester) async {
      await tester.pumpWidget(buildSubject(blurEnabled: true));
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('background is Tokens.bgGlass', (tester) async {
      await tester.pumpWidget(buildSubject());
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GlassContainer),
          matching: find.byType(Container).first,
        ),
      );
      final decoration = container.decoration;
      expect(decoration, isA<BoxDecoration>());
      if (decoration case final BoxDecoration boxDecoration) {
        expect(boxDecoration.color, Tokens.bgGlass);
      }
    });
  });

  group('GlassTier', () {
    test('thin sigma is less than normal', () {
      expect(GlassTier.thin.sigma, lessThan(GlassTier.normal.sigma));
    });

    test('两档体系 — thick 死档已删 (v0.0.8.2)', () {
      expect(GlassTier.values, hasLength(2));
      expect(GlassTier.values, containsAll([GlassTier.thin, GlassTier.normal]));
    });
  });
}
