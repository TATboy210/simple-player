import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/control_bar.dart';
import 'package:simple_player_flutter/ui/player/control_bar_timeline.dart';
import 'package:simple_player_flutter/ui/player/control_bar_view_model.dart';
import 'package:simple_player_flutter/ui/player/media_kit_player_port.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import 'package:simple_player_flutter/ui/player/player_video_controls.dart';
import 'package:simple_player_flutter/ui/player/progress_bar.dart';

import '../test/helpers/fake_engine.dart';

/// Emits a single ordered trace so the diagnostic artifact can compare only
/// adjacent data-chain layers rather than inferring causality from timestamps.
final class _P39Trace {
  var _sequence = 0;

  /// Logs a sanitized diagnostic record; fixture paths are intentionally absent.
  void log(String layer, String status, {int? value, String? detail}) {
    _sequence += 1;
    final valueText = value == null ? '' : ' value=$value';
    final detailText = detail == null ? '' : ' $detail';
    debugPrint('[P39] #$_sequence $layer $status$valueText$detailText');
  }
}

/// Creates the intended direct handoff used to prove the downstream widgets.
Widget _timelineTree({required ControlBarViewModel viewModel}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: SizedBox(
      width: 900,
      height: 64,
      child: ControlBarTimeline(vm: viewModel),
    ),
  ),
);

/// Creates the actual production shell, which is separately inspected for its
/// timeline insertion point without making a second controls tree.
Widget _productionShell({required ControlBarViewModel viewModel}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: SizedBox(
      width: 900,
      height: 200,
      child: ControlBar(vm: viewModel, actions: const PlayerActions()),
    ),
  ),
);

/// Waits while preserving integration-test frame processing for native events.
Future<void> _waitForSignals(WidgetTester tester) async {
  for (var iteration = 0; iteration < 16; iteration += 1) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('P39 real PlayerPort duration and position boundary diagnosis', (
    tester,
  ) async {
    final trace = _P39Trace();
    final fixture = File('${Directory.current.path}/test/fixtures/tiny_valid.mp4');
    final fixtureName = fixture.uri.pathSegments.last;
    final engine = FakeEngine();
    final player = Player();
    final rawSubscriptions = <StreamSubscription<dynamic>>[];
    final diagnosticListeners = <VoidCallback>[];
    PlayerControlsState? controlsState;

    var fixtureOpened = false;
    var rawDurationMs = 0;
    var rawPositionObserved = false;
    var rawPositionLogged = false;
    var portDurationMs = 0;
    var portPositionObserved = false;
    var portPositionLogged = false;
    var statePositionLogged = false;

    // Subscribe upstream before constructing the project port so the raw stream
    // remains an independent harness-validity witness.
    rawSubscriptions.add(
      player.stream.duration.listen((duration) {
        final value = duration.inMilliseconds;
        trace.log(
          'raw.player.stream.duration',
          value > 0 ? 'observed' : 'observed-zero',
          value: value,
        );
        if (value > rawDurationMs) rawDurationMs = value;
      }),
    );
    rawSubscriptions.add(
      player.stream.position.listen((position) {
        rawPositionObserved = true;
        if (rawPositionLogged) return;
        rawPositionLogged = true;
        trace.log(
          'raw.player.stream.position',
          'observed',
          value: position.inMilliseconds,
        );
      }),
    );

    try {
      trace.log('fixture.open', 'started', detail: 'basename=$fixtureName');
      await player.open(Media(fixture.path));
      fixtureOpened = true;
      trace.log('fixture.open', 'observed', detail: 'basename=$fixtureName');

      final port = MediaKitPlayerPort(player);
      trace.log('port.subscribe', 'observed');
      trace.log(
        'port.snapshot.duration',
        port.durationNow.inMilliseconds > 0 ? 'observed' : 'observed-zero',
        value: port.durationNow.inMilliseconds,
      );
      trace.log(
        'port.snapshot.position',
        'observed',
        value: port.positionNow.inMilliseconds,
      );
      rawSubscriptions.add(
        port.duration.listen((duration) {
          final value = duration.inMilliseconds;
          trace.log(
            'port.stream.duration',
            value > 0 ? 'observed' : 'observed-zero',
            value: value,
          );
          if (value > portDurationMs) portDurationMs = value;
        }),
      );
      rawSubscriptions.add(
        port.position.listen((position) {
          portPositionObserved = true;
          if (portPositionLogged) return;
          portPositionLogged = true;
          trace.log(
            'port.stream.position',
            'observed',
            value: position.inMilliseconds,
          );
        }),
      );

      final state = PlayerControlsState(port, engine: engine)..init();
      controlsState = state;
      void durationListener() {
        trace.log(
          'state.durationMs',
          state.durationMs.value > 0 ? 'observed' : 'observed-zero',
          value: state.durationMs.value,
        );
      }

      void positionListener() {
        if (statePositionLogged) return;
        statePositionLogged = true;
        trace.log(
          'state.positionMs',
          'observed',
          value: state.positionMs.value,
        );
      }

      state.durationMs.addListener(durationListener);
      state.positionMs.addListener(positionListener);
      diagnosticListeners.addAll([
        () => state.durationMs.removeListener(durationListener),
        () => state.positionMs.removeListener(positionListener),
      ]);

      final viewModel = ControlBarViewModel(
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
      trace.log(
        'viewModel.notifier.identity',
        identical(viewModel.duration, controlsState.durationMs) &&
                identical(viewModel.position, controlsState.positionMs)
            ? 'observed'
            : 'mismatch',
        detail: 'duration=${identityHashCode(viewModel.duration)} position=${identityHashCode(viewModel.position)}',
      );
      trace.log(
        'timeline.notifier.identity',
        'observed',
        detail: 'duration=${identityHashCode(viewModel.duration)} position=${identityHashCode(viewModel.position)}',
      );

      await tester.pumpWidget(_timelineTree(viewModel: viewModel));
      await _waitForSignals(tester);

      final progressBar = find.byType(ProgressBar);
      final semantics = find.byWidgetPredicate(
        (widget) => widget is Semantics && (widget.properties.slider ?? false),
      );
      final widgetDuration = state.durationMs.value;
      final widgetPosition = state.positionMs.value;
      trace.log(
        'widget.durationMs',
        progressBar.evaluate().isNotEmpty && widgetDuration > 0
            ? 'observed'
            : 'missing-after-deadline',
        value: widgetDuration,
      );
      trace.log(
        'widget.positionMs',
        progressBar.evaluate().isNotEmpty ? 'observed' : 'missing-after-deadline',
        value: widgetPosition,
      );
      trace.log(
        'widget.semantics',
        semantics.evaluate().isNotEmpty ? 'observed' : 'missing-after-deadline',
        detail: semantics.evaluate().isNotEmpty ? 'slider=true' : null,
      );

      // This shell probe is the production-only boundary that Task 1 flagged:
      // it must not be confused with the direct timeline handoff above.
      await tester.pumpWidget(_productionShell(viewModel: viewModel));
      await tester.pump();
      final productionTimelinePresent =
          find.byType(ControlBarTimeline).evaluate().isNotEmpty;
      trace.log(
        'production.timeline.insertion',
        productionTimelinePresent ? 'observed' : 'missing-after-deadline',
      );

      // Fixture and raw duration validate the Windows harness. Downstream loss is
      // diagnostic data, but the adjacent-layer result must be unique.
      expect(fixtureOpened, isTrue, reason: 'fixture did not open');
      expect(
        rawDurationMs,
        greaterThan(0),
        reason: 'invalid harness: raw Player.stream.duration never became non-zero',
      );
      expect(rawPositionObserved, isTrue, reason: 'raw position stream did not emit');

      final boundary = switch ((portDurationMs > 0, state.durationMs.value > 0,
          productionTimelinePresent)) {
        (false, _, _) =>
          'lib/ui/player/media_kit_player_port.dart:MediaKitPlayerPort.duration',
        (true, false, _) =>
          'lib/ui/player/player_video_controls.dart:PlayerControlsState.init',
        (true, true, false) =>
          'lib/ui/player/control_bar_layout.dart:ControlBarLayout._buildLayout',
        (true, true, true) =>
          'lib/ui/player/progress_bar.dart:_ProgressBarState.build',
      };
      trace.log('diagnosis.firstBrokenBoundary=$boundary', 'observed');
      // Position is retained as cross-evidence, never a substitute for duration.
      trace.log(
        'diagnosis.positionCrossEvidence',
        portPositionObserved ? 'observed' : 'missing-after-deadline',
      );

      final strictMode = Platform.environment['P39_POST_REPAIR'] == 'true';
      if (strictMode) {
        expect(
          productionTimelinePresent,
          isTrue,
          reason: 'post-repair mode requires the production ControlBar timeline',
        );
      }
    } finally {
      for (final listener in diagnosticListeners) {
        listener();
      }
      for (final subscription in rawSubscriptions) {
        await subscription.cancel();
      }
      controlsState?.dispose();
      engine.dispose();
      await player.dispose();
    }
  });
}
