import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/volume_controls.dart';
import 'package:simple_player_flutter/ui/shared/osd_overlay.dart';
import '../../helpers/fake_engine.dart';

void main() {
  late FakeEngine engine;

  setUp(() {
    engine = FakeEngine();
  });

  tearDown(() {
    OsdService.I.hide();
    engine.dispose();
  });

  Widget buildSubject({EngineState? eng, required Widget child}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  group('VolumeButton', () {
    testWidgets('shows volume_off icon when muted', (tester) async {
      engine.isMuted.value = true;
      await tester.pumpWidget(
        buildSubject(child: VolumeButton(engine: engine)),
      );
      await tester.pump();

      expect(find.byIcon(Icons.volume_off), findsOneWidget);
    });

    testWidgets('shows volume_off icon when volume is 0', (tester) async {
      engine.volume.value = 0;
      engine.isMuted.value = false;
      await tester.pumpWidget(
        buildSubject(child: VolumeButton(engine: engine)),
      );
      await tester.pump();

      expect(find.byIcon(Icons.volume_off), findsOneWidget);
    });

    testWidgets('shows volume_down icon when volume < 0.5', (tester) async {
      engine.volume.value = 0.3;
      engine.isMuted.value = false;
      await tester.pumpWidget(
        buildSubject(child: VolumeButton(engine: engine)),
      );
      await tester.pump();

      expect(find.byIcon(Icons.volume_down), findsOneWidget);
    });

    testWidgets('shows volume_up icon when volume >= 0.5', (tester) async {
      engine.volume.value = 0.8;
      engine.isMuted.value = false;
      await tester.pumpWidget(
        buildSubject(child: VolumeButton(engine: engine)),
      );
      await tester.pump();

      expect(find.byIcon(Icons.volume_up), findsOneWidget);
    });

    testWidgets('tap toggles mute on', (tester) async {
      engine.volume.value = 0.8;
      engine.isMuted.value = false;
      await tester.pumpWidget(
        buildSubject(child: VolumeButton(engine: engine)),
      );
      await tester.pump();

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();

      expect(engine.isMuted.value, isTrue);
      expect(engine.volume.value, 0.0);
      OsdService.I.hide();
    });

    testWidgets('tap toggles mute off and restores volume', (tester) async {
      engine.volume.value = 0.0;
      engine.isMuted.value = true;
      await tester.pumpWidget(
        buildSubject(child: VolumeButton(engine: engine)),
      );
      await tester.pump();

      // First tap mutes (saves volume)
      // Second tap unmutes (restores volume)
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();

      // Since already muted, unmuting should restore
      expect(engine.isMuted.value, isFalse);
      OsdService.I.hide();
    });
  });

  group('VolumeSlider', () {
    testWidgets('slider reflects engine volume', (tester) async {
      engine.volume.value = 0.5;
      await tester.pumpWidget(
        buildSubject(child: VolumeSlider(engine: engine)),
      );
      await tester.pump();

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 0.5);
    });

    testWidgets('slider updates when engine volume changes', (tester) async {
      await tester.pumpWidget(
        buildSubject(child: VolumeSlider(engine: engine)),
      );
      await tester.pump();

      engine.volume.value = 0.7;
      await tester.pump();

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 0.7);
    });

    testWidgets('dragging slider calls engine.setVolume', (tester) async {
      engine.volume.value = 0.5;
      await tester.pumpWidget(
        buildSubject(child: VolumeSlider(engine: engine)),
      );
      await tester.pump();

      // Drag slider
      final slider = find.byType(Slider);
      final rect = tester.getRect(slider);
      final center = rect.center;

      // Drag from center to 80% of the slider width
      final startX = center.dx;
      final endX = rect.left + rect.width * 0.8;

      final gesture = await tester.startGesture(Offset(startX, center.dy));
      await gesture.moveBy(Offset(endX - startX, 0));
      await gesture.up();
      await tester.pump();

      // Volume should have changed
      expect(engine.volume.value, greaterThan(0.5));

      // Pump past OsdService hold timer to avoid pending timer
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('scroll wheel up increases volume', (tester) async {
      engine.volume.value = 0.5;
      await tester.pumpWidget(
        buildSubject(child: VolumeSlider(engine: engine)),
      );
      await tester.pump();

      final slider = find.byType(VolumeSlider);
      final center = tester.getRect(slider).center;

      // Scroll up → volume increases
      final event = PointerScrollEvent(
        scrollDelta: const Offset(0, -100),
        position: center,
      );
      GestureBinding.instance.handlePointerEvent(event);
      await tester.pump();

      expect(engine.volume.value, greaterThan(0.5));
      OsdService.I.hide();
    });

    testWidgets('scroll wheel down decreases volume', (tester) async {
      engine.volume.value = 0.5;
      await tester.pumpWidget(
        buildSubject(child: VolumeSlider(engine: engine)),
      );
      await tester.pump();

      final slider = find.byType(VolumeSlider);
      final center = tester.getRect(slider).center;

      // Scroll down → volume decreases
      final event = PointerScrollEvent(
        scrollDelta: const Offset(0, 100),
        position: center,
      );
      GestureBinding.instance.handlePointerEvent(event);
      await tester.pump();

      expect(engine.volume.value, lessThan(0.5));
      OsdService.I.hide();
    });

    // ── Scroll boundary clamp ──

    testWidgets('scroll wheel up at max volume (1.0) clamps', (tester) async {
      engine.volume.value = 1.0;
      await tester.pumpWidget(
        buildSubject(child: VolumeSlider(engine: engine)),
      );
      await tester.pump();

      final slider = find.byType(VolumeSlider);
      final center = tester.getRect(slider).center;

      final event = PointerScrollEvent(
        scrollDelta: const Offset(0, -100),
        position: center,
      );
      GestureBinding.instance.handlePointerEvent(event);
      await tester.pump();

      // Clamped at 1.0
      expect(engine.volume.value, 1.0);
      OsdService.I.hide();
    });

    testWidgets('scroll wheel down at min volume (0.0) clamps', (tester) async {
      engine.volume.value = 0.0;
      await tester.pumpWidget(
        buildSubject(child: VolumeSlider(engine: engine)),
      );
      await tester.pump();

      final slider = find.byType(VolumeSlider);
      final center = tester.getRect(slider).center;

      final event = PointerScrollEvent(
        scrollDelta: const Offset(0, 100),
        position: center,
      );
      GestureBinding.instance.handlePointerEvent(event);
      await tester.pump();

      // Clamped at 0.0
      expect(engine.volume.value, 0.0);
      OsdService.I.hide();
    });

    testWidgets('unmute restores previously saved volume', (tester) async {
      // Arrange: set volume to 0.7, then mute
      engine.volume.value = 0.7;
      engine.isMuted.value = false;
      await tester.pumpWidget(
        buildSubject(child: VolumeButton(engine: engine)),
      );
      await tester.pump();

      // Tap to mute — saves 0.7
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();
      expect(engine.isMuted.value, isTrue);
      expect(engine.volume.value, 0.0);

      // Tap again to unmute — restores 0.7
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();
      expect(engine.isMuted.value, isFalse);
      expect(engine.volume.value, closeTo(0.7, 0.01));
      OsdService.I.hide();
    });
  });
}
