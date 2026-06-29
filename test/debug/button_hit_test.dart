/// R1 调试测试 — 验证按钮在 ControlsOverlay 内是否可点击
///
/// 运行: flutter test test/debug/button_hit_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/controls_overlay.dart';
import 'package:simple_player_flutter/ui/player/control_bar.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import '../helpers/fake_engine.dart';

void main() {
  late FakeEngine engine;

  setUp(() {
    engine = FakeEngine();
    engine.state.value = MediaState.playing;
    engine.duration.value = 60000;
    engine.position.value = 10000;
  });

  tearDown(() {
    engine.dispose();
  });

  Widget buildFullOverlay({PlayerActions? actions}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: ControlsOverlay(
            engine: engine,
            actions:
                actions ??
                const PlayerActions(onPrevious: _noop, onNext: _noop),
          ),
        ),
      ),
    );
  }

  Widget buildControlBarOnly({PlayerActions? actions}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 200,
          child: ControlBar(
            engine: engine,
            actions:
                actions ??
                const PlayerActions(onPrevious: _noop, onNext: _noop),
          ),
        ),
      ),
    );
  }

  group('R1 Debug: Button hit test', () {
    testWidgets('ControlBar only — play/pause button tappable', (tester) async {
      await tester.pumpWidget(buildControlBarOnly());
      await tester.pump();

      final playButton = find.byIcon(Icons.pause);
      expect(playButton, findsOneWidget, reason: 'Should find pause icon');

      await tester.tap(playButton);
      await tester.pump();

      expect(
        engine.state.value,
        MediaState.paused,
        reason: 'togglePlayPause should change state to paused',
      );
    });

    testWidgets('ControlsOverlay — play/pause button tappable', (tester) async {
      await tester.pumpWidget(buildFullOverlay());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final playButton = find.byIcon(Icons.pause);
      expect(
        playButton,
        findsOneWidget,
        reason: 'Should find pause icon inside ControlsOverlay',
      );

      await tester.tap(playButton);
      await tester.pump();

      expect(
        engine.state.value,
        MediaState.paused,
        reason: 'togglePlayPause should work through ControlsOverlay',
      );
    });

    testWidgets('ControlsOverlay — previous button tappable', (tester) async {
      var prevCalled = false;
      await tester.pumpWidget(
        buildFullOverlay(
          actions: PlayerActions(
            onPrevious: () => prevCalled = true,
            onNext: _noop,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final prevButton = find.byIcon(Icons.skip_previous);
      expect(prevButton, findsOneWidget);

      await tester.tap(prevButton);
      await tester.pump();

      expect(prevCalled, isTrue, reason: 'onPrevious should be called');
    });

    testWidgets('ControlsOverlay — next button tappable', (tester) async {
      var nextCalled = false;
      await tester.pumpWidget(
        buildFullOverlay(
          actions: PlayerActions(
            onPrevious: _noop,
            onNext: () => nextCalled = true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final nextButton = find.byIcon(Icons.skip_next);
      expect(nextButton, findsOneWidget);

      await tester.tap(nextButton);
      await tester.pump();

      expect(nextCalled, isTrue, reason: 'onNext should be called');
    });

    testWidgets('ControlsOverlay — fullscreen button tappable', (tester) async {
      var fsCalled = false;
      await tester.pumpWidget(
        buildFullOverlay(
          actions: PlayerActions(
            onPrevious: _noop,
            onNext: _noop,
            onToggleFullscreen: () => fsCalled = true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final fsButton = find.byIcon(Icons.fullscreen);
      expect(fsButton, findsOneWidget);

      await tester.tap(fsButton);
      await tester.pump();

      expect(fsCalled, isTrue, reason: 'onToggleFullscreen should be called');
    });
  });
}

void _noop() {}
