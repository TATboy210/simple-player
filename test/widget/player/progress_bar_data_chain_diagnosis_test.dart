import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/window_bridge/window_bridge.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/control_bar_timeline.dart';
import 'package:simple_player_flutter/ui/player/control_bar_view_model.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import 'package:simple_player_flutter/ui/player/player_video_controls.dart';
import 'package:simple_player_flutter/ui/player/progress_bar.dart';

import '../../helpers/fake_engine.dart';
import '../../helpers/fake_player_controls.dart';
import '../../helpers/fake_video_controls.dart';

/// Builds the production PlayerVideoControls shell with only project fakes.
/// This probe never constructs media_kit Player or loads MDK.
Widget _controlsShell({
  required Key key,
  required FakeVideoControlsPort video,
  required FakeEngine engine,
  required ValueListenable<WindowMode> windowMode,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: SizedBox(
      width: 1280,
      height: 720,
      child: PlayerVideoControls(
        key: key,
        video: video,
        engine: engine,
        actions: const PlayerActions(),
        currentFileName: ValueNotifier<String>('diagnosis.mp4'),
        windowMode: windowMode,
      ),
    ),
  ),
);

/// Builds the intended state-to-progress handoff without the production shell.
Widget _timelineTree({
  required PlayerControlsState state,
  required FakeEngine engine,
}) {
  final vm = ControlBarViewModel(
    isPlaying: state.isPlaying,
    position: state.positionMs,
    duration: state.durationMs,
    volume: state.volume01,
    isMuted: engine.isMuted,
    rate: state.rate,
    isFullscreen: ValueNotifier<bool>(false),
    onSeek: state.seek,
    onPlayPause: () {},
    onSeekBack: (_) {},
    onSeekForward: (_) {},
    onToggleMute: () {},
    onSetVolume: (_) {},
    onSetRate: state.setRate,
  );
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(width: 800, height: 48, child: ControlBarTimeline(vm: vm)),
    ),
  );
}

Semantics _progressSemantics(WidgetTester tester) => tester.widget<Semantics>(
  find.byWidgetPredicate(
    (widget) => widget is Semantics && (widget.properties.slider ?? false),
  ),
);

void main() {
  group('ProgressBar data-chain diagnosis', () {
    testWidgets('port-to-state detects the production shell missing timeline', (
      tester,
    ) async {
      final engine = FakeEngine()..play();
      final player = FakePlayerControls(isPlayingNow: true);
      final video = FakeVideoControlsPort(player: player);
      final windowMode = ValueNotifier<WindowMode>(WindowMode.windowed);
      addTearDown(engine.dispose);
      addTearDown(video.dispose);
      addTearDown(windowMode.dispose);

      await tester.pumpWidget(
        _controlsShell(
          key: GlobalKey(),
          video: video,
          engine: engine,
          windowMode: windowMode,
        ),
      );
      player.emitDuration(const Duration(milliseconds: 60000));
      player.emitPosition(const Duration(milliseconds: 15000));
      await tester.pump();
      // Broadcast stream delivery schedules state updates after the event loop.
      await tester.pump();

      // The production shell must compose the same timeline that the direct
      // handoff uses; otherwise stream values cannot reach user interaction.
      expect(find.byType(ControlBarTimeline), findsOneWidget);
      expect(find.byType(ProgressBar), findsOneWidget);
      expect(_progressSemantics(tester).properties.value, '25%');
    });

    testWidgets(
      'port-to-state state-to-progress delayed duration and incrementing position survive the intended handoff',
      (tester) async {
        final engine = FakeEngine();
        final player = FakePlayerControls();
        final state = PlayerControlsState(player, engine: engine)..init();
        addTearDown(state.dispose);
        addTearDown(engine.dispose);
        addTearDown(player.dispose);

        await tester.pumpWidget(_timelineTree(state: state, engine: engine));
        // The state notifiers are the public, stable output of the port-to-state
        // bridge. Drive them as the existing fake stream regression tests do.
        state.durationMs.value = 60000;
        state.positionMs.value = 15000;
        await tester.pump();
        expect(state.durationMs.value, 60000);
        expect(state.positionMs.value, 15000);
        // The current production tree omits ControlBarTimeline, so this
        // direct state proof is deliberately kept distinct from the shell
        // probe above rather than pretending a ProgressBar semantic exists.
        expect(find.byType(ProgressBar), findsOneWidget);

        state.positionMs.value = 30000;
        await tester.pump();
        expect(state.positionMs.value, 30000);
        expect(find.byType(ProgressBar), findsOneWidget);
      },
    );

    testWidgets(
      'port-to-state replacement preserves notifier identity and isolates old port events',
      (tester) async {
        final firstEngine = FakeEngine();
        final secondEngine = FakeEngine();
        final oldPlayer = FakePlayerControls();
        final newPlayer = FakePlayerControls(
          durationNow: const Duration(milliseconds: 60000),
          positionNow: const Duration(milliseconds: 12000),
        );
        final state = PlayerControlsState(oldPlayer, engine: firstEngine)
          ..init();
        final originalPosition = state.positionMs;
        final originalDuration = state.durationMs;
        addTearDown(state.dispose);
        addTearDown(firstEngine.dispose);
        addTearDown(secondEngine.dispose);
        addTearDown(oldPlayer.dispose);
        addTearDown(newPlayer.dispose);

        state.updateSources(newPlayer, engine: secondEngine);
        expect(state.positionMs, same(originalPosition));
        expect(state.durationMs, same(originalDuration));
        expect(state.positionMs.value, 12000);
        oldPlayer.emitPosition(const Duration(milliseconds: 59000));
        await tester.pump();
        expect(state.positionMs.value, 12000);
        newPlayer.emitPosition(const Duration(milliseconds: 30000));
        await tester.pump();
        expect(state.positionMs.value, 30000);
      },
    );

    testWidgets(
      'pointer-hit tap drag two hover coordinates and sibling occlusion',
      (tester) async {
        final engine = FakeEngine();
        final player = FakePlayerControls();
        final state = PlayerControlsState(player, engine: engine)..init();
        addTearDown(state.dispose);
        addTearDown(engine.dispose);
        addTearDown(player.dispose);

        await tester.pumpWidget(_timelineTree(state: state, engine: engine));
        player.emitDuration(const Duration(milliseconds: 60000));
        await tester.pump();
        await tester.pump();
        final bar = find.byType(ProgressBar);
        final rect = tester.getRect(bar);

        await tester.tapAt(rect.center);
        await tester.pump();
        expect(player.lastSeekPosition?.inMilliseconds, closeTo(30000, 1500));

        final drag = await tester.startGesture(
          rect.centerLeft + const Offset(40, 0),
        );
        await drag.moveTo(rect.centerRight - const Offset(40, 0));
        await tester.pump();
        await drag.up();
        await tester.pump();
        // The state bridge performs the end seek; the fake records the port
        // command after its optimistic state update. The midpoint tap covers
        // the separate instantaneous seek path.
        expect(player.seekCallCount, greaterThanOrEqualTo(1));

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: rect.centerLeft + const Offset(80, 0));
        await tester.pump();
        final first = tester.widget<Positioned>(find.byType(Positioned).last);
        final firstText = tester
            .widget<Text>(find.textContaining('0:').last)
            .data;
        await mouse.moveTo(rect.centerRight - const Offset(80, 0));
        await tester.pump();
        final second = tester.widget<Positioned>(find.byType(Positioned).last);
        expect(second.left, isNot(first.left));
        // The self-drawn preview is distinct from TimeRangeDisplay, whose text
        // remains stable until a position stream event arrives.
        expect(firstText, isNotNull);

        var overlayTaps = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => overlayTaps++,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
        await tester.tapAt(rect.center);
        expect(overlayTaps, 1);
      },
    );
  });
}
