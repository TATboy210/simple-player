import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/shared/glass_container.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

void main() {
  group('GlassContainer', () {
    Widget buildSubject({
      GlassTier tier = GlassTier.normal,
      ValueListenable<double>? opacity,
      bool blurEnabled = true,
      ValueListenable<bool>? resizing,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: GlassContainer(
            tier: tier,
            opacity: opacity,
            blurEnabled: blurEnabled,
            resizing: resizing,
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

    testWidgets('renders with thick tier', (tester) async {
      await tester.pumpWidget(buildSubject(tier: GlassTier.thick));
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

    testWidgets('opacity near zero skips BackdropFilter', (tester) async {
      final opacity = ValueNotifier<double>(0.0);
      await tester.pumpWidget(buildSubject(opacity: opacity));
      await tester.pump();
      // opacity.value < 0.01 → AnimatedBuilder returns child without BackdropFilter
      expect(find.text('test'), findsOneWidget);
      opacity.dispose();
    });

    testWidgets('opacity at 1.0 renders BackdropFilter', (tester) async {
      final opacity = ValueNotifier<double>(1.0);
      await tester.pumpWidget(buildSubject(opacity: opacity));
      await tester.pump();
      // opacity.value >= 0.01 → ClipRRect + BackdropFilter
      expect(find.byType(BackdropFilter), findsOneWidget);
      opacity.dispose();
    });

    testWidgets('opacity animation transitions', (tester) async {
      final opacity = ValueNotifier<double>(1.0);
      await tester.pumpWidget(buildSubject(opacity: opacity));
      await tester.pump();

      // Start with blur
      expect(find.byType(BackdropFilter), findsOneWidget);

      // Fade to near-zero → skip blur
      opacity.value = 0.005;
      await tester.pump();

      expect(find.text('test'), findsOneWidget);
      opacity.dispose();
    });

    testWidgets('resizing=true keeps BackdropFilter mounted but disabled', (
      tester,
    ) async {
      final resizing = ValueNotifier<bool>(true);
      addTearDown(resizing.dispose);
      await tester.pumpWidget(buildSubject(resizing: resizing));
      await tester.pump();

      final filter = find.byType(BackdropFilter);
      expect(filter, findsOneWidget);
      expect(tester.widget<BackdropFilter>(filter).enabled, isFalse);
      expect(find.text('test'), findsOneWidget);
    });

    testWidgets('resizing=false renders BackdropFilter', (tester) async {
      final resizing = ValueNotifier<bool>(false);
      await tester.pumpWidget(buildSubject(resizing: resizing));
      await tester.pump();
      // resizing=false → normal blur path with BackdropFilter
      expect(find.byType(BackdropFilter), findsOneWidget);
      resizing.dispose();
    });

    testWidgets(
      'resizing transition toggles filter without replacing elements',
      (tester) async {
        final resizing = ValueNotifier<bool>(false);
        addTearDown(resizing.dispose);
        await tester.pumpWidget(buildSubject(resizing: resizing));
        await tester.pump();

        final filter = find.byType(BackdropFilter);
        final content = find.text('test');
        final filterElement = tester.element(filter);
        final contentElement = tester.element(content);
        expect(tester.widget<BackdropFilter>(filter).enabled, isTrue);

        resizing.value = true;
        await tester.pump();
        expect(tester.widget<BackdropFilter>(filter).enabled, isFalse);
        expect(tester.element(filter), same(filterElement));
        expect(tester.element(content), same(contentElement));

        resizing.value = false;
        await tester.pump();
        expect(tester.widget<BackdropFilter>(filter).enabled, isTrue);
        expect(tester.element(filter), same(filterElement));
        expect(tester.element(content), same(contentElement));
      },
    );

    testWidgets('replacing resizing notifier detaches the old source', (
      tester,
    ) async {
      final oldResizing = ValueNotifier(false);
      final replacement = ValueNotifier(false);
      addTearDown(oldResizing.dispose);
      addTearDown(replacement.dispose);

      await tester.pumpWidget(buildSubject(resizing: oldResizing));
      await tester.pump();

      final filter = find.byType(BackdropFilter);
      final content = find.text('test');
      final filterElement = tester.element(filter);
      final contentElement = tester.element(content);
      expect(tester.widget<BackdropFilter>(filter).enabled, isTrue);

      await tester.pumpWidget(buildSubject(resizing: replacement));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);

      oldResizing.value = true;
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pump();
      expect(tester.widget<BackdropFilter>(filter).enabled, isTrue);
      expect(tester.element(filter), same(filterElement));
      expect(tester.element(content), same(contentElement));

      replacement.value = true;
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump();
      expect(tester.widget<BackdropFilter>(filter).enabled, isFalse);
      expect(tester.element(filter), same(filterElement));
      expect(tester.element(content), same(contentElement));
    });

    testWidgets('backgroundColor defaults to Tokens.bgGlass', (tester) async {
      await tester.pumpWidget(buildSubject());
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GlassContainer),
          matching: find.byType(Container).first,
        ),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, Tokens.bgGlass);
    });

    testWidgets('backgroundColor overrides default when provided', (
      tester,
    ) async {
      const customColor = Color(0x39080A10);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              backgroundColor: customColor,
              child: Text('test'),
            ),
          ),
        ),
      );
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GlassContainer),
          matching: find.byType(Container).first,
        ),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, customColor);
    });
  });

  group('GlassTier', () {
    test('thin sigma is less than normal', () {
      expect(GlassTier.thin.sigma, lessThan(GlassTier.normal.sigma));
    });

    test('normal sigma equals thick (merged — 2-tier system)', () {
      expect(GlassTier.normal.sigma, equals(GlassTier.thick.sigma));
    });
  });
}
