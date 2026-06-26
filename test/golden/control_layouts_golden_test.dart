import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:player_engine/player_engine.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/control_bar.dart';
import 'package:simple_player_flutter/ui/player/progress_bar.dart';
import 'package:simple_player_flutter/ui/player/volume_controls.dart';

import '../helpers/fake_engine.dart';
import 'golden_comparator.dart';

void main() {
  setUp(() => enableTolerantGoldens());

  late FakeEngine engine;

  setUp(() {
    engine = FakeEngine();
  });

  tearDown(() {
    engine.dispose();
  });

  Widget buildControlSubject({
    required Widget child,
    double width = 800,
    double height = 200,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: Center(
          child: SizedBox(
            width: width,
            height: height,
            child: child,
          ),
        ),
      ),
    );
  }

  group('ControlBar golden', () {
    testWidgets('idle state', (tester) async {
      await tester.pumpWidget(
        buildControlSubject(
          child: ControlBar(
            engine: engine,
            isIdle: true,
            enableBlur: false,
          ),
        ),
      );
      await expectLater(
        find.byType(ControlBar),
        matchesGoldenFile('goldens/control_bar_idle.png'),
      );
    });

    testWidgets('playing state', (tester) async {
      engine.configureMedia(durationMs: 60000);
      engine.position.value = 15000;
      engine.state.value = MediaState.playing;

      await tester.pumpWidget(
        buildControlSubject(
          child: ControlBar(
            engine: engine,
            enableBlur: false,
          ),
        ),
      );
      await expectLater(
        find.byType(ControlBar),
        matchesGoldenFile('goldens/control_bar_playing.png'),
      );
    });

    testWidgets('fullscreen state', (tester) async {
      engine.configureMedia(durationMs: 60000);
      engine.position.value = 30000;
      engine.state.value = MediaState.playing;

      await tester.pumpWidget(
        buildControlSubject(
          child: ControlBar(
            engine: engine,
            enableBlur: false,
          ),
        ),
      );
      await expectLater(
        find.byType(ControlBar),
        matchesGoldenFile('goldens/control_bar_fullscreen.png'),
      );
    });
  });

  group('ProgressBar golden', () {
    testWidgets('empty (no duration)', (tester) async {
      await tester.pumpWidget(
        buildControlSubject(
          height: 60,
          child: ProgressBar(engine: engine),
        ),
      );
      await expectLater(
        find.byType(ProgressBar),
        matchesGoldenFile('goldens/progress_bar_empty.png'),
      );
    });

    testWidgets('half progress', (tester) async {
      engine.configureMedia(durationMs: 60000);
      engine.position.value = 30000;
      engine.buffered.value = 45000;

      await tester.pumpWidget(
        buildControlSubject(
          height: 60,
          child: ProgressBar(engine: engine),
        ),
      );
      await expectLater(
        find.byType(ProgressBar),
        matchesGoldenFile('goldens/progress_bar_half.png'),
      );
    });
  });

  group('VolumeControls golden', () {
    testWidgets('full volume', (tester) async {
      engine.configureMedia();
      engine.volume.value = 1.0;
      engine.isMuted.value = false;

      await tester.pumpWidget(
        buildControlSubject(
          width: 200,
          height: 60,
          child: VolumeButton(engine: engine),
        ),
      );
      await expectLater(
        find.byType(VolumeButton),
        matchesGoldenFile('goldens/volume_controls_full.png'),
      );
    });

    testWidgets('muted', (tester) async {
      engine.configureMedia();
      engine.isMuted.value = true;

      await tester.pumpWidget(
        buildControlSubject(
          width: 200,
          height: 60,
          child: VolumeButton(engine: engine),
        ),
      );
      await expectLater(
        find.byType(VolumeButton),
        matchesGoldenFile('goldens/volume_controls_muted.png'),
      );
    });
  });
}
