import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/controls_overlay.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import 'package:simple_player_flutter/ui/shared/transmitted_light.dart';
import '../../helpers/fake_engine.dart';

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
    bool isFullscreen = false,
    bool emptyStatePresent = false,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ControlsOverlay(
          engine: eng ?? engine,
          actions: actions ?? const PlayerActions(),
          isFullscreen: isFullscreen,
          emptyStatePresent: emptyStatePresent,
        ),
      ),
    );
  }

  group('Transmitted Light', () {
    testWidgets('renders in controls overlay', (tester) async {
      engine.state.value = MediaState.playing;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // TransmittedLight 应存在于 ControlsOverlay 中
      expect(find.byType(TransmittedLight), findsOneWidget);
    });

    testWidgets('has bottom transmission type', (tester) async {
      engine.state.value = MediaState.playing;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final light = tester.widget<TransmittedLight>(
        find.byType(TransmittedLight),
      );
      expect(light.type, TransmissionType.bottom);
    });

    testWidgets('has correct intensity (0.6)', (tester) async {
      engine.state.value = MediaState.playing;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final light = tester.widget<TransmittedLight>(
        find.byType(TransmittedLight),
      );
      expect(light.intensity, 0.6);
    });

    testWidgets('contains RadialGradient decoration', (tester) async {
      engine.state.value = MediaState.playing;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // TransmittedLight 内部有 RadialGradient 装饰的 Container
      final gradientContainers = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final boxDeco = widget.decoration as BoxDecoration;
          return boxDeco.gradient is RadialGradient;
        }
        return false;
      });

      expect(gradientContainers, findsAtLeastNWidgets(1));
    });

    testWidgets('renders in both idle and playing states', (tester) async {
      // Playing state
      engine.state.value = MediaState.playing;
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.byType(TransmittedLight), findsOneWidget);

      // Idle state — TransmittedLight 仍应存在
      engine.state.value = MediaState.idle;
      await tester.pump();
      expect(find.byType(TransmittedLight), findsOneWidget);
    });
  });

  group('Transmitted Light Golden', () {
    testWidgets('golden: transmitted light playing state', (tester) async {
      engine.state.value = MediaState.playing;
      await tester.pumpWidget(buildSubject());
      await tester.pump(const Duration(milliseconds: 500));

      await expectLater(
        find.byType(ControlsOverlay),
        matchesGoldenFile('../goldens/gradient_strip_playing.png'),
      );
    });

    testWidgets('golden: transmitted light idle state', (tester) async {
      engine.state.value = MediaState.idle;
      await tester.pumpWidget(buildSubject());
      await tester.pump(const Duration(milliseconds: 500));

      await expectLater(
        find.byType(ControlsOverlay),
        matchesGoldenFile('../goldens/gradient_strip_idle.png'),
      );
    });
  });
}
