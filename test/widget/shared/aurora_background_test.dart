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

    testWidgets('continues rendering after a throttled animation tick', (
      tester,
    ) async {
      await tester.pumpWidget(_buildSubject());

      // Advance beyond the background's repaint throttle. The visible contract
      // is that the animated background remains renderable, independent of the
      // widget/painter implementation used to achieve that repaint.
      await tester.pump(const Duration(milliseconds: 150));

      expect(tester.takeException(), isNull);
      expect(find.byType(AuroraBackground), findsOneWidget);
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

    testWidgets(
      'accepts a zero-size first layout before receiving valid bounds',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 0,
                height: 0,
                child: Stack(children: [AuroraBackground()]),
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.pumpWidget(_buildSubject());
        await tester.pump(const Duration(milliseconds: 150));

        expect(tester.takeException(), isNull);
        expect(find.byType(AuroraBackground), findsOneWidget);
      },
    );

    testWidgets('disposing while blob pre-generation is pending is safe', (
      tester,
    ) async {
      await tester.pumpWidget(_buildSubject());
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())),
      );
      await tester.pump(const Duration(milliseconds: 150));

      expect(tester.takeException(), isNull);
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
