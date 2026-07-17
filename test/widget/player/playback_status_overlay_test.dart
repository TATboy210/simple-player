import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/playback_status_overlay.dart';

import '../../helpers/fake_engine.dart';

void main() {
  late FakeEngine engine;

  setUp(() {
    engine = FakeEngine();
  });

  tearDown(() {
    engine.dispose();
  });

  Widget buildSubject() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: PlaybackStatusOverlay(engine: engine)),
  );

  group('PlaybackStatusOverlay', () {
    testWidgets('shows opening indicator while the engine opens media', (
      tester,
    ) async {
      // Arrange
      engine.state.value = MediaState.opening;

      // Act
      await tester.pumpWidget(buildSubject());

      // Assert
      expect(find.byKey(PlaybackStatusOverlay.openingKey), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows buffering indicator while playback buffers', (
      tester,
    ) async {
      // Arrange
      engine.state.value = MediaState.playing;
      engine.isBuffering.value = true;

      // Act
      await tester.pumpWidget(buildSubject());

      // Assert
      expect(find.byKey(PlaybackStatusOverlay.bufferingKey), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('hides when playback is active and not buffering', (
      tester,
    ) async {
      // Arrange
      engine.state.value = MediaState.playing;
      engine.isBuffering.value = false;

      // Act
      await tester.pumpWidget(buildSubject());

      // Assert
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('updates after the mounted engine enters and leaves opening', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(buildSubject());

      // Act
      engine.state.value = MediaState.opening;
      await tester.pump();

      // Assert
      expect(find.byKey(PlaybackStatusOverlay.openingKey), findsOneWidget);

      engine.state.value = MediaState.playing;
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('prioritizes opening and suppresses idle or error buffering', (
      tester,
    ) async {
      // Arrange
      engine.isBuffering.value = true;
      engine.state.value = MediaState.opening;
      await tester.pumpWidget(buildSubject());

      // Assert
      expect(find.byKey(PlaybackStatusOverlay.openingKey), findsOneWidget);
      expect(find.byKey(PlaybackStatusOverlay.bufferingKey), findsNothing);

      // Act
      engine.state.value = MediaState.idle;
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);

      engine.state.value = MediaState.error;
      await tester.pump();
      // ErrorBanner owns the error presentation path.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
