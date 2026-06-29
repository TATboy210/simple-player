import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/player_engine.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/control_bar.dart';
import 'package:simple_player_flutter/ui/player/center_controls.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import 'package:simple_player_flutter/ui/player/volume_controls.dart';
import 'package:simple_player_flutter/ui/player/time_range_display.dart';
import 'package:simple_player_flutter/ui/player/progress_bar.dart';
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
    bool isIdle = false,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 200,
          child: ControlBar(
            engine: eng ?? engine,
            actions: actions ?? const PlayerActions(),
            isIdle: isIdle,
          ),
        ),
      ),
    );
  }

  group('ControlBar', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(ControlBar), findsOneWidget);
    });

    testWidgets('renders TimeRangeDisplay', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(TimeRangeDisplay), findsOneWidget);
    });

    testWidgets('renders ProgressBar', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(ProgressBar), findsOneWidget);
    });

    testWidgets('renders play mode button', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byIcon(Icons.repeat), findsOneWidget);
    });

    testWidgets('renders CenterGroup', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(CenterGroup), findsOneWidget);
    });

    testWidgets('shows secondary controls at width >= 500', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(VolumeButton), findsOneWidget);
      expect(find.byType(VolumeSlider), findsOneWidget);
    });

    testWidgets('hides secondary controls at width < 500', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: ControlBar(engine: engine),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(VolumeButton), findsNothing);
      expect(find.byType(VolumeSlider), findsNothing);
    });

    testWidgets('shows folder_open button when onOpenFile is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(actions: const PlayerActions(onOpenFile: _noop)),
      );
      await tester.pump();

      expect(find.byIcon(Icons.folder_open), findsOneWidget);
    });

    testWidgets('hides folder_open button when onOpenFile is null', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byIcon(Icons.folder_open), findsNothing);
    });

    testWidgets('shows fullscreen button when onToggleFullscreen is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(actions: const PlayerActions(onToggleFullscreen: _noop)),
      );
      await tester.pump();

      expect(find.byIcon(Icons.fullscreen), findsOneWidget);
    });

    testWidgets('shows subtitles button when onOpenSubtitle is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(actions: const PlayerActions(onOpenSubtitle: _noop)),
      );
      await tester.pump();

      expect(find.byIcon(Icons.subtitles), findsOneWidget);
    });

    testWidgets('shows queue_music when onTogglePlaylist is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(actions: const PlayerActions(onTogglePlaylist: _noop)),
      );
      await tester.pump();

      expect(find.byIcon(Icons.queue_music), findsOneWidget);
    });

    testWidgets('shows settings when onSettings is provided', (tester) async {
      await tester.pumpWidget(
        buildSubject(actions: const PlayerActions(onSettings: _noop)),
      );
      await tester.pump();

      expect(find.byIcon(Icons.settings), findsOneWidget);
    });
  });
}
