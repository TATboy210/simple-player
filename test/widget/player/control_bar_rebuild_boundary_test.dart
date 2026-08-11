import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/center_controls.dart';
import 'package:simple_player_flutter/ui/player/control_bar.dart';
import 'package:simple_player_flutter/ui/player/control_bar_actions.dart';
import 'package:simple_player_flutter/ui/player/control_bar_layout.dart';
import 'package:simple_player_flutter/ui/player/control_bar_timeline.dart';
import 'package:simple_player_flutter/ui/player/control_bar_title.dart';
import 'package:simple_player_flutter/ui/player/control_bar_view_model.dart';
import 'package:simple_player_flutter/ui/player/left_button_group.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import 'package:simple_player_flutter/ui/player/progress_bar.dart';
import 'package:simple_player_flutter/ui/player/right_button_group.dart';
import 'package:simple_player_flutter/ui/player/time_range_display.dart';
import 'package:simple_player_flutter/ui/player/volume_controls.dart';

/// Counts the outer ControlBar build so notifier updates cannot be mistaken for
/// a parent rebuild caused by the test harness itself.
class _ControlBarBuildProbe extends StatelessWidget {
  const _ControlBarBuildProbe({required this.builds, required this.child});

  final ValueNotifier<int> builds;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    builds.value += 1;
    return child;
  }
}

void main() {
  late _ControlBarHarness harness;

  setUp(() {
    harness = _ControlBarHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  testWidgets('title change rebuilds only title slice', (tester) async {
    await tester.pumpWidget(harness.build(titleListenable: harness.title));
    await tester.pump();

    final shellBuilds = harness.builds.value;
    final layout = tester.element(find.byType(ControlBarLayout));
    final timeline = tester.element(find.byType(ControlBarTimeline));
    final actions = tester.element(find.byType(ControlBarActions));
    final progress = tester.element(find.byType(ProgressBar));
    final title = tester.element(find.byType(ControlBarTitle));

    harness.title.value = 'second-file.mkv';
    await tester.pump();

    expect(find.text('second-file.mkv'), findsOneWidget);
    expect(harness.builds.value, shellBuilds);
    expect(tester.element(find.byType(ControlBarLayout)), same(layout));
    expect(tester.element(find.byType(ControlBarTimeline)), same(timeline));
    expect(tester.element(find.byType(ControlBarActions)), same(actions));
    expect(tester.element(find.byType(ProgressBar)), same(progress));
    expect(tester.element(find.byType(ControlBarTitle)), same(title));
  });

  testWidgets('static title remains available without a listenable', (
    tester,
  ) async {
    await tester.pumpWidget(harness.build(title: 'static-file.mp4'));
    await tester.pump();

    expect(find.text('static-file.mp4'), findsOneWidget);
  });

  testWidgets('idle change updates only the center action slice', (
    tester,
  ) async {
    await tester.pumpWidget(harness.build(isIdleListenable: harness.isIdle));
    await tester.pump();

    final shellBuilds = harness.builds.value;
    final title = tester.element(find.byType(ControlBarTitle));
    final timeline = tester.element(find.byType(ControlBarTimeline));
    final left = tester.element(find.byType(LeftButtonGroup));
    final right = tester.element(find.byType(RightButtonGroup));
    final center = tester.element(find.byType(CenterGroup));

    harness.isIdle.value = true;
    await tester.pump();

    expect(harness.builds.value, shellBuilds);
    expect(tester.element(find.byType(ControlBarTitle)), same(title));
    expect(tester.element(find.byType(ControlBarTimeline)), same(timeline));
    expect(tester.element(find.byType(LeftButtonGroup)), same(left));
    expect(tester.element(find.byType(RightButtonGroup)), same(right));
    expect(tester.element(find.byType(CenterGroup)), same(center));
  });

  testWidgets(
    'playing change updates play button without rebuilding other slices',
    (tester) async {
      await tester.pumpWidget(harness.build());
      await tester.pump();

      final shellBuilds = harness.builds.value;
      final title = tester.element(find.byType(ControlBarTitle));
      final timeline = tester.element(find.byType(ControlBarTimeline));
      final actions = tester.element(find.byType(ControlBarActions));
      final volume = tester.element(find.byType(VolumeButton));

      harness.isPlaying.value = true;
      await tester.pump();

      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(harness.builds.value, shellBuilds);
      expect(tester.element(find.byType(ControlBarTitle)), same(title));
      expect(tester.element(find.byType(ControlBarTimeline)), same(timeline));
      expect(tester.element(find.byType(ControlBarActions)), same(actions));
      expect(tester.element(find.byType(VolumeButton)), same(volume));
    },
  );

  testWidgets('volume and mute changes remain inside the volume area', (
    tester,
  ) async {
    await tester.pumpWidget(harness.build());
    await tester.pump();

    final shellBuilds = harness.builds.value;
    final title = tester.element(find.byType(ControlBarTitle));
    final timeline = tester.element(find.byType(ControlBarTimeline));
    final center = tester.element(find.byType(CenterGroup));
    final actions = tester.element(find.byType(ControlBarActions));

    harness.volume.value = 0.25;
    await tester.pump();
    expect(find.byIcon(Icons.volume_down), findsOneWidget);

    harness.isMuted.value = true;
    await tester.pump();
    expect(find.byIcon(Icons.volume_off), findsOneWidget);
    expect(harness.builds.value, shellBuilds);
    expect(tester.element(find.byType(ControlBarTitle)), same(title));
    expect(tester.element(find.byType(ControlBarTimeline)), same(timeline));
    expect(tester.element(find.byType(CenterGroup)), same(center));
    expect(tester.element(find.byType(ControlBarActions)), same(actions));
  });

  testWidgets('progress changes do not rebuild title or actions', (
    tester,
  ) async {
    await tester.pumpWidget(harness.build());
    await tester.pump();

    final shellBuilds = harness.builds.value;
    final title = tester.element(find.byType(ControlBarTitle));
    final actions = tester.element(find.byType(ControlBarActions));
    final volume = tester.element(find.byType(VolumeButton));
    final timeline = tester.element(find.byType(ControlBarTimeline));

    harness.position.value = 1000;
    harness.duration.value = 5000;
    await tester.pump();

    expect(find.byType(TimeRangeDisplay), findsOneWidget);
    expect(harness.builds.value, shellBuilds);
    expect(tester.element(find.byType(ControlBarTitle)), same(title));
    expect(tester.element(find.byType(ControlBarActions)), same(actions));
    expect(tester.element(find.byType(VolumeButton)), same(volume));
    expect(tester.element(find.byType(ControlBarTimeline)), same(timeline));
  });
}

/// Owns the independent notifier sources used to prove ControlBar boundaries.
class _ControlBarHarness {
  final builds = ValueNotifier<int>(0);
  final title = ValueNotifier<String>('first-file.mp4');
  final isIdle = ValueNotifier<bool>(false);
  final isPlaying = ValueNotifier<bool>(false);
  final position = ValueNotifier<int>(0);
  final duration = ValueNotifier<int>(0);
  final volume = ValueNotifier<double>(1);
  final isMuted = ValueNotifier<bool>(false);
  final rate = ValueNotifier<double>(1);
  final isFullscreen = ValueNotifier<bool>(false);

  /// Builds a real ControlBar with only fake listenables; no media_kit surface
  /// is needed to exercise the widget-level rebuild boundaries.
  Widget build({
    String? title,
    ValueListenable<String>? titleListenable,
    ValueListenable<bool>? isIdleListenable,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 200,
          child: _ControlBarBuildProbe(
            builds: builds,
            child: ControlBar(
              vm: ControlBarViewModel(
                isPlaying: isPlaying,
                position: position,
                duration: duration,
                volume: volume,
                isMuted: isMuted,
                rate: rate,
                isFullscreen: isFullscreen,
                onSeek: (_) {},
                onPlayPause: () {},
                onSeekBack: (_) {},
                onSeekForward: (_) {},
                onToggleMute: () {},
                onSetVolume: (_) {},
                onSetRate: (_) {},
              ),
              actions: const PlayerActions(),
              isIdleListenable: isIdleListenable,
              title: title,
              titleListenable: titleListenable,
            ),
          ),
        ),
      ),
    );
  }

  /// Releases every test-owned notifier after the widget tree is unmounted.
  void dispose() {
    builds.dispose();
    title.dispose();
    isIdle.dispose();
    isPlaying.dispose();
    position.dispose();
    duration.dispose();
    volume.dispose();
    isMuted.dispose();
    rate.dispose();
    isFullscreen.dispose();
  }
}
