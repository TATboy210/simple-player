import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/shared/edge_glow.dart';

void main() {
  Widget buildTestWidget({
    EdgeGlowVariant variant = EdgeGlowVariant.gradient,
    double? glowIntensity,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: EdgeGlow(
          variant: variant,
          glowIntensity: glowIntensity,
          child: const SizedBox(width: 100, height: 50),
        ),
      ),
    );
  }

  group('EdgeGlow glowIntensity', () {
    testWidgets('default null preserves existing behavior', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.byType(EdgeGlow), findsOneWidget);
      final edgeGlow = tester.widget<EdgeGlow>(find.byType(EdgeGlow));
      expect(edgeGlow.glowIntensity, isNull);
    });

    testWidgets('glowIntensity=0.0 renders without error', (tester) async {
      await tester.pumpWidget(buildTestWidget(glowIntensity: 0.0));
      expect(find.byType(EdgeGlow), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('glowIntensity=0.5 renders without error', (tester) async {
      await tester.pumpWidget(buildTestWidget(glowIntensity: 0.5));
      expect(find.byType(EdgeGlow), findsOneWidget);
    });

    testWidgets('glowIntensity=1.0 renders without error', (tester) async {
      await tester.pumpWidget(buildTestWidget(glowIntensity: 1.0));
      expect(find.byType(EdgeGlow), findsOneWidget);
    });

    testWidgets('pulse variant with glowIntensity renders', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        variant: EdgeGlowVariant.pulse,
        glowIntensity: 0.5,
      ));
      expect(find.byType(EdgeGlow), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(EdgeGlow), findsOneWidget);
    });

    testWidgets('omni variant with glowIntensity renders', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        variant: EdgeGlowVariant.omni,
        glowIntensity: 0.3,
      ));
      expect(find.byType(EdgeGlow), findsOneWidget);
    });

    test('glowIntensity is optional parameter', () {
      const glow = EdgeGlow(child: SizedBox());
      expect(glow.glowIntensity, isNull);
    });

    test('glowIntensity accepts valid range', () {
      const glow0 = EdgeGlow(glowIntensity: 0.0, child: SizedBox());
      const glow1 = EdgeGlow(glowIntensity: 1.0, child: SizedBox());
      const glowMid = EdgeGlow(glowIntensity: 0.5, child: SizedBox());
      expect(glow0.glowIntensity, 0.0);
      expect(glow1.glowIntensity, 1.0);
      expect(glowMid.glowIntensity, 0.5);
    });
  });
}
