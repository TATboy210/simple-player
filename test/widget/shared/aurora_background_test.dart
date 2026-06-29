import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/player_engine.dart';
import 'package:simple_player_flutter/ui/shared/aurora_background.dart';

/// Helper — AuroraBackground needs a Stack ancestor (uses Positioned internally)
Widget _buildSubject({ValueNotifier<MediaState>? engineState}) {
  return MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [AuroraBackground(engineState: engineState)],
      ),
    ),
  );
}

void main() {
  group('AuroraBackground', () {
    testWidgets('renders with default params', (tester) async {
      await tester.pumpWidget(_buildSubject());
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

    testWidgets('handles engine idle→buffering→idle cycle', (tester) async {
      final engineState = ValueNotifier(MediaState.idle);
      await tester.pumpWidget(_buildSubject(engineState: engineState));

      engineState.value = MediaState.buffering;
      await tester.pump();
      engineState.value = MediaState.idle;
      await tester.pump();
      expect(find.byType(AuroraBackground), findsOneWidget);
      engineState.dispose();
    });

    testWidgets('cleans up resources on dispose', (tester) async {
      final engineState = ValueNotifier(MediaState.idle);
      await tester.pumpWidget(_buildSubject(engineState: engineState));

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: SizedBox()),
      ));
      expect(find.byType(AuroraBackground), findsNothing);
      engineState.dispose();
    });

    testWidgets('handles engineState reference change', (tester) async {
      final engineState1 = ValueNotifier(MediaState.idle);
      await tester.pumpWidget(_buildSubject(engineState: engineState1));

      final engineState2 = ValueNotifier(MediaState.playing);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [AuroraBackground(engineState: engineState2)],
          ),
        ),
      ));
      expect(find.byType(AuroraBackground), findsOneWidget);

      engineState1.dispose();
      engineState2.dispose();
    });
  });
}
