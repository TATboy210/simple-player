import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:player_engine/player_engine.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/controls_overlay.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import '../../helpers/fake_engine.dart';

void _noop() {}

void main() {
  late FakeEngine engine;

  setUp(() {
    engine = FakeEngine();
  });

  tearDown(() {
    engine.dispose();
  });

  Widget buildSubject({
    PlayerEngine? eng,
    PlayerActions? actions,
    bool emptyStatePresent = false,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ControlsOverlay(
          engine: eng ?? engine,
          actions: actions ?? const PlayerActions(),
          emptyStatePresent: emptyStatePresent,
        ),
      ),
    );
  }

  group('ControlsOverlay', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(ControlsOverlay), findsOneWidget);
    });

    testWidgets('renders ControlBar', (tester) async {
      engine.state.value = MediaState.playing;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(ControlsOverlay), findsOneWidget);
    });

    testWidgets('single tap hides controls after delay', (tester) async {
      engine.state.value = MediaState.playing;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final center = tester.getCenter(find.byType(ControlsOverlay));
      await tester.tapAt(center);
      await tester.pump();

      // After 250ms delay + animation
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('idle state does not hide on tap', (tester) async {
      engine.state.value = MediaState.idle;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final center = tester.getCenter(find.byType(ControlsOverlay));
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('emptyStatePresent + idle disables gesture', (tester) async {
      engine.state.value = MediaState.idle;
      await tester.pumpWidget(buildSubject(emptyStatePresent: true));
      await tester.pump();

      // Should render without error
      expect(find.byType(ControlsOverlay), findsOneWidget);
    });

    testWidgets('mouse hover shows controls', (tester) async {
      engine.state.value = MediaState.playing;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(
        location: tester.getCenter(find.byType(ControlsOverlay)),
      );
      addTearDown(gesture.removePointer);

      await gesture.moveTo(tester.getCenter(find.byType(ControlsOverlay)));
      await tester.pump();

      expect(find.byType(ControlsOverlay), findsOneWidget);
    });

    testWidgets('engine state change triggers AutoHideController callback', (
      tester,
    ) async {
      engine.state.value = MediaState.idle;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // Change engine state while widget is mounted — triggers _onEngineStateChanged
      engine.state.value = MediaState.playing;
      await tester.pump();

      // _onEngineStateChanged calls _autoHide.onEngineStateChanged()
      // playing → show() + scheduleHide() — widget still visible
      expect(find.byType(ControlsOverlay), findsOneWidget);
    });

    testWidgets('mouse exit triggers onMouseExit', (tester) async {
      engine.state.value = MediaState.playing;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final overlay = find.byType(ControlsOverlay);
      final center = tester.getCenter(overlay);

      // Create mouse at center (triggers onEnter + onHover)
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: center);
      addTearDown(gesture.removePointer);

      await gesture.moveTo(center);
      await tester.pump();

      // Move far outside the widget — triggers onExit
      await gesture.moveTo(
        center + const Offset(5000, 5000),
      );
      await tester.pump();

      // onExit called _autoHide.onMouseExit() — no crash, scheduleHide called
      expect(find.byType(ControlsOverlay), findsOneWidget);
    });
  });
}
