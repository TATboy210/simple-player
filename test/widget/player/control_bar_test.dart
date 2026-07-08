import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
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
    EngineState? eng,
    PlayerActions? actions,
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

    testWidgets('shows all controls at narrow width (no breakpoint gating)', (
      tester,
    ) async {
      // CB-04: compact/ultra-compact breakpoints removed — always show full layout
      // Desktop player typical width 800+, use 600 to avoid Row overflow
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(600, 600)),
            child: Scaffold(
              body: SizedBox(
                width: 600,
                height: 200,
                child: ControlBar(engine: engine),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(VolumeButton), findsOneWidget);
      expect(find.byType(VolumeSlider), findsOneWidget);
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

  group('ControlBar animation', () {
    Widget buildWithIdle({required bool isIdle}) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 200,
            child: ControlBar(engine: engine, isIdle: isIdle),
          ),
        ),
      );
    }

    testWidgets('renders Container with decoration', (tester) async {
      await tester.pumpWidget(buildWithIdle(isIdle: false));
      await tester.pump();

      // ControlBar uses Container + DecorationTween (not AnimatedContainer)
      expect(find.byType(ControlBar), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('idle state renders Container', (tester) async {
      await tester.pumpWidget(buildWithIdle(isIdle: true));
      await tester.pump();

      expect(find.byType(ControlBar), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('decoration animation parameter is accepted', (tester) async {
      // When decoration param is null, ControlBar uses _decorationPlaying directly
      await tester.pumpWidget(buildWithIdle(isIdle: true));
      await tester.pump();

      // Switch to playing — rebuild with new state
      await tester.pumpWidget(buildWithIdle(isIdle: false));
      await tester.pump();

      // ControlBar still renders correctly after state change
      expect(find.byType(ControlBar), findsOneWidget);
    });

    testWidgets('ControlBar with decoration animation parameter', (
      tester,
    ) async {
      // When an external decoration animation is provided, ControlBar uses
      // DecorationTween to interpolate between idle and playing decorations
      final controller = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 150),
        value: 1.0,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 200,
              child: ControlBar(
                engine: engine,
                isIdle: false,
                decoration: controller,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Container should render with the interpolated decoration
      expect(find.byType(ControlBar), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });
  });

  group('ControlBar responsive layout', () {
    Widget buildWithWidth(double width) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 600)),
          child: Scaffold(
            body: SizedBox(
              width: width,
              height: 200,
              child: ControlBar(engine: engine),
            ),
          ),
        ),
      );
    }

    testWidgets('narrow width still shows full layout', (
      tester,
    ) async {
      // CB-04: ultra-compact breakpoint removed — always show full layout
      // Use 600px to avoid Row overflow (desktop player minimum practical width)
      await tester.pumpWidget(buildWithWidth(600));
      await tester.pump();

      expect(find.byIcon(Icons.skip_previous), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.skip_next), findsOneWidget);

      // Full CenterGroup (replay_10 + forward_30 always visible)
      expect(find.byType(CenterGroup), findsOneWidget);

      // Volume always visible (no breakpoint gating)
      expect(find.byType(VolumeButton), findsOneWidget);
      expect(find.byType(VolumeSlider), findsOneWidget);
    });

    testWidgets('medium width shows full layout', (
      tester,
    ) async {
      // CB-04: compact breakpoint removed — always show full layout
      await tester.pumpWidget(buildWithWidth(700));
      await tester.pump();

      expect(find.byType(CenterGroup), findsOneWidget);
      expect(find.byIcon(Icons.replay_10), findsOneWidget);
      expect(find.byIcon(Icons.forward_30), findsOneWidget);

      // Volume always visible (no breakpoint gating)
      expect(find.byType(VolumeButton), findsOneWidget);
      expect(find.byType(VolumeSlider), findsOneWidget);
    });

    testWidgets('full layout (w>500) shows all groups', (tester) async {
      await tester.pumpWidget(buildWithWidth(800));
      await tester.pump();

      // All controls visible
      expect(find.byType(CenterGroup), findsOneWidget);
      expect(find.byType(VolumeButton), findsOneWidget);
      expect(find.byType(VolumeSlider), findsOneWidget);

      // play mode button (left group)
      expect(find.byIcon(Icons.repeat), findsOneWidget);
    });

    testWidgets('_buildBlur skips BackdropFilter when opacity < 0.01', (
      tester,
    ) async {
      // Create an opacity animation that is near-zero
      final opacityController = AnimationController(
        vsync: tester,
        value: 0.005, // < 0.01 threshold
      );
      addTearDown(opacityController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 200,
              child: ControlBar(
                engine: engine,
                opacity: opacityController,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // When opacity < 0.01, BackdropFilter is skipped (GPU optimization)
      // ControlBar still renders but without blur
      expect(find.byType(ControlBar), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });
}
