import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
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

  Widget buildSubject({EngineState? eng}) {
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

    testWidgets('portrait ratio calculates correct dimensions', (tester) async {
      engine.textureId.value = 1;
      engine.aspectRatio.value = 0.5; // portrait
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(Texture), findsOneWidget);
      expect(find.byType(FittedBox), findsOneWidget);
    });

    testWidgets('NaN ratio falls back to 16:9', (tester) async {
      engine.textureId.value = 1;
      engine.aspectRatio.value = double.nan;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(Texture), findsOneWidget);
    });

    testWidgets('16:9 ratio renders FittedBox with BoxFit.contain', (tester) async {
      engine.textureId.value = 1;
      engine.aspectRatio.value = 16 / 9;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // 验证渲染链: SizedBox.expand → FittedBox(contain) → Texture
      expect(find.byType(FittedBox), findsOneWidget);
      final fittedBox = tester.widget<FittedBox>(find.byType(FittedBox));
      expect(fittedBox.fit, BoxFit.contain);
      expect(fittedBox.alignment, Alignment.center);
      expect(find.byType(Texture), findsOneWidget);
    });

    testWidgets('4:3 ratio renders with FittedBox and Texture', (tester) async {
      engine.textureId.value = 1;
      engine.aspectRatio.value = 4 / 3;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // 4:3 横屏也应使用 FittedBox(contain) + Texture
      expect(find.byType(FittedBox), findsOneWidget);
      final fittedBox = tester.widget<FittedBox>(find.byType(FittedBox));
      expect(fittedBox.fit, BoxFit.contain);
      expect(find.byType(Texture), findsOneWidget);
    });

    testWidgets('scroll on video does not change volume', (tester) async {
      engine.textureId.value = 1;
      engine.volume.value = 0.8;
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

      // 音量不再由视频区域滚轮调节
      expect(engine.volume.value, closeTo(0.8, 0.01));
    });
  });
}
