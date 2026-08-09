import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/ui/shared/aurora_background.dart';

/// Helper — AuroraBackground needs a Stack ancestor (uses Positioned internally)
Widget _buildSubject({ValueNotifier<MediaState>? engineState}) {
  return MaterialApp(
    home: Scaffold(
      body: Stack(children: [AuroraBackground(engineState: engineState)]),
    ),
  );
}

void main() {
  group('AuroraBackground', () {
    testWidgets('renders with default params', (tester) async {
      await tester.pumpWidget(_buildSubject());
      expect(find.byType(AuroraBackground), findsOneWidget);
    });

    testWidgets('repaint ticks do not rebuild the CustomPaint widget', (
      tester,
    ) async {
      await tester.pumpWidget(_buildSubject());
      final customPaintFinder = find.descendant(
        of: find.byType(AuroraBackground),
        matching: find.byType(CustomPaint),
      );
      final initialCustomPaint = tester.widget<CustomPaint>(customPaintFinder);

      // Aurora 以 ~10 FPS 重绘（_onTick 内 100ms 节流）；推进 150ms 超过阈值，
      // 触发一次 repaint，但不应重建 CustomPaint widget（painter 复用 + repaint
      // Listenable 驱动 RenderObject paint，不走 widget rebuild 路径）。
      await tester.pump(const Duration(milliseconds: 150));

      final auroraAnimatedBuilder = find.descendant(
        of: find.byType(AuroraBackground),
        matching: find.byType(AnimatedBuilder),
      );
      expect(auroraAnimatedBuilder, findsNothing);
      expect(
        tester.widget<CustomPaint>(customPaintFinder),
        same(initialCustomPaint),
      );
    });

    testWidgets('renders with engineState=idle', (tester) async {
      final engineState = ValueNotifier(MediaState.idle);
      await tester.pumpWidget(_buildSubject(engineState: engineState));
      expect(find.byType(AuroraBackground), findsOneWidget);
      engineState.dispose();
    });

    testWidgets('handles engine idle→playing transition', (tester) async {
      final engineState = ValueNotifier(MediaState.idle);
      await tester.pumpWidget(_buildSubject(engineState: engineState));

      engineState.value = MediaState.playing;
      await tester.pump();
      expect(find.byType(AuroraBackground), findsOneWidget);
      engineState.dispose();
    });

    testWidgets('handles engine idle→playing→idle cycle', (tester) async {
      final engineState = ValueNotifier(MediaState.idle);
      await tester.pumpWidget(_buildSubject(engineState: engineState));

      engineState.value = MediaState.playing;
      await tester.pump();
      engineState.value = MediaState.idle;
      await tester.pump();
      expect(find.byType(AuroraBackground), findsOneWidget);
      engineState.dispose();
    });

    testWidgets('handles engine idle→opening→idle cycle', (tester) async {
      final engineState = ValueNotifier(MediaState.idle);
      await tester.pumpWidget(_buildSubject(engineState: engineState));

      engineState.value = MediaState.opening;
      await tester.pump();
      engineState.value = MediaState.idle;
      await tester.pump();
      expect(find.byType(AuroraBackground), findsOneWidget);
      engineState.dispose();
    });

    testWidgets('cleans up resources on dispose', (tester) async {
      final engineState = ValueNotifier(MediaState.idle);
      await tester.pumpWidget(_buildSubject(engineState: engineState));

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())),
      );
      expect(find.byType(AuroraBackground), findsNothing);
      engineState.dispose();
    });

    testWidgets('handles engineState reference change', (tester) async {
      final engineState1 = ValueNotifier(MediaState.idle);
      await tester.pumpWidget(_buildSubject(engineState: engineState1));

      final engineState2 = ValueNotifier(MediaState.playing);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [AuroraBackground(engineState: engineState2)],
            ),
          ),
        ),
      );
      expect(find.byType(AuroraBackground), findsOneWidget);

      engineState1.dispose();
      engineState2.dispose();
    });
  });
}
