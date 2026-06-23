import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:player_engine/player_engine.dart';
import 'package:simple_player_flutter/ui/player/video_surface.dart';
import '../../helpers/fake_engine.dart';

void main() {
  late FakeEngine engine;

  setUp(() {
    engine = FakeEngine();
  });

  tearDown(() {
    engine.dispose();
  });

  Widget buildSubject({PlayerEngine? eng}) {
    return MaterialApp(
      home: Scaffold(body: VideoSurface(engine: eng ?? engine)),
    );
  }

  group('VideoSurface', () {
    testWidgets('renders SizedBox.shrink when textureId is null', (
      tester,
    ) async {
      engine.textureId.value = null;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(Texture), findsNothing);
    });

    testWidgets('renders Texture when textureId is set', (tester) async {
      engine.textureId.value = 1;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(Texture), findsOneWidget);
    });

    testWidgets('uses default 16/9 ratio when ratio is invalid (0)', (
      tester,
    ) async {
      engine.textureId.value = 1;
      engine.aspectRatio.value = 0;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(Texture), findsOneWidget);
    });

    testWidgets('uses default 16/9 ratio when ratio is negative', (
      tester,
    ) async {
      engine.textureId.value = 1;
      engine.aspectRatio.value = -1;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(Texture), findsOneWidget);
    });

    testWidgets('uses default 16/9 ratio when ratio is infinity', (
      tester,
    ) async {
      engine.textureId.value = 1;
      engine.aspectRatio.value = double.infinity;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(Texture), findsOneWidget);
    });

    testWidgets('updates when textureId changes', (tester) async {
      engine.textureId.value = null;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(Texture), findsNothing);

      engine.textureId.value = 42;
      await tester.pump();

      expect(find.byType(Texture), findsOneWidget);
    });

    testWidgets('scroll down decreases volume', (tester) async {
      engine.textureId.value = 1;
      engine.volume.value = 0.8;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final target = find.byType(Texture);
      final center = tester.getCenter(target);

      // Dispatch a PointerScrollEvent directly
      final event = PointerScrollEvent(
        position: center,
        scrollDelta: const Offset(0, 50),
      );
      tester.binding.handlePointerEvent(event);
      await tester.pump();

      expect(engine.volume.value, closeTo(0.75, 0.01));
    });

    testWidgets('scroll up increases volume', (tester) async {
      engine.textureId.value = 1;
      engine.volume.value = 0.5;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final target = find.byType(Texture);
      final center = tester.getCenter(target);

      final event = PointerScrollEvent(
        position: center,
        scrollDelta: const Offset(0, -50),
      );
      tester.binding.handlePointerEvent(event);
      await tester.pump();

      expect(engine.volume.value, closeTo(0.55, 0.01));
    });

    testWidgets('volume is clamped to 1.0', (tester) async {
      engine.textureId.value = 1;
      engine.volume.value = 0.98;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final target = find.byType(Texture);
      final center = tester.getCenter(target);

      final event = PointerScrollEvent(
        position: center,
        scrollDelta: const Offset(0, -50),
      );
      tester.binding.handlePointerEvent(event);
      await tester.pump();

      expect(engine.volume.value, 1.0);
    });

    testWidgets('volume is clamped to 0.0', (tester) async {
      engine.textureId.value = 1;
      engine.volume.value = 0.02;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final target = find.byType(Texture);
      final center = tester.getCenter(target);

      final event = PointerScrollEvent(
        position: center,
        scrollDelta: const Offset(0, 50),
      );
      tester.binding.handlePointerEvent(event);
      await tester.pump();

      expect(engine.volume.value, 0.0);
    });
  });
}
