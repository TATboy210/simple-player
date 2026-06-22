import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/shared/glass_container.dart';

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

    testWidgets('resizing=true skips BackdropFilter', (tester) async {
      final resizing = ValueNotifier<bool>(true);
      await tester.pumpWidget(buildSubject(resizing: resizing));
      await tester.pump();
      // resizing=true → ClipRRect + RepaintBoundary, no BackdropFilter
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('test'), findsOneWidget);
      resizing.dispose();
    });

    testWidgets('resizing=false renders BackdropFilter', (tester) async {
      final resizing = ValueNotifier<bool>(false);
      await tester.pumpWidget(buildSubject(resizing: resizing));
      await tester.pump();
      // resizing=false → normal blur path with BackdropFilter
      expect(find.byType(BackdropFilter), findsOneWidget);
      resizing.dispose();
    });

    testWidgets('resizing transition rebuilds correctly', (tester) async {
      final resizing = ValueNotifier<bool>(false);
      await tester.pumpWidget(buildSubject(resizing: resizing));
      await tester.pump();

      // Start without resize → BackdropFilter present
      expect(find.byType(BackdropFilter), findsOneWidget);

      // Simulate resize start → skip BackdropFilter
      resizing.value = true;
      await tester.pump();
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('test'), findsOneWidget);

      // Resize end → restore BackdropFilter
      resizing.value = false;
      await tester.pump();
      expect(find.byType(BackdropFilter), findsOneWidget);
      resizing.dispose();
    });
  });

  group('GlassTier', () {
    test('thin sigma is less than normal', () {
      expect(GlassTier.thin.sigma, lessThan(GlassTier.normal.sigma));
    });

    test('normal sigma is less than thick', () {
      expect(GlassTier.normal.sigma, lessThan(GlassTier.thick.sigma));
    });
  });
}
