import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/controls_overlay.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';
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

  group('Gradient Strip', () {
    testWidgets('renders above control bar', (tester) async {
      engine.state.value = MediaState.playing;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // 渐变条应存在于 Stack 中（带 LinearGradient decoration 的 Container）
      final gradientContainers = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final boxDeco = widget.decoration as BoxDecoration;
          return boxDeco.gradient is LinearGradient;
        }
        return false;
      });

      expect(gradientContainers, findsAtLeastNWidgets(1));
    });

    testWidgets('has correct height (60px)', (tester) async {
      engine.state.value = MediaState.playing;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // 找到渐变条的 Positioned (height = gradientStripHeight)
      final positioned = find.byWidgetPredicate((widget) {
        if (widget is Positioned) {
          return widget.height == Tokens.gradientStripHeight;
        }
        return false;
      });

      expect(positioned, findsOneWidget);
    });

    testWidgets('fades with control bar (FadeTransition)', (tester) async {
      engine.state.value = MediaState.playing;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // 渐变条应被 FadeTransition 包裹
      // 至少应有 2 个 FadeTransition: ControlBar + gradient strip
      final fadeTransitions = find.byType(FadeTransition);
      expect(fadeTransitions, findsAtLeastNWidgets(2));
    });

    testWidgets('gradient bottom color changes idle/playing', (tester) async {
      // Playing state → controlBarBg
      engine.state.value = MediaState.playing;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      LinearGradient? findGradient() {
        final container = tester.widget<Container>(
          find.byWidgetPredicate((widget) {
            if (widget is Container && widget.decoration is BoxDecoration) {
              final boxDeco = widget.decoration as BoxDecoration;
              if (boxDeco.gradient is LinearGradient) {
                final grad = boxDeco.gradient as LinearGradient;
                return grad.colors.first == Colors.transparent;
              }
            }
            return false;
          }).first,
        );
        final boxDeco = container.decoration as BoxDecoration;
        return boxDeco.gradient as LinearGradient?;
      }

      final playingGradient = findGradient();
      expect(playingGradient, isNotNull);
      expect(playingGradient!.colors.last, Tokens.controlBarBg);

      // Idle state → controlBarBgIdle
      engine.state.value = MediaState.idle;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final idleGradient = findGradient();
      expect(idleGradient, isNotNull);
      expect(idleGradient!.colors.last, Tokens.controlBarBgIdle);
    });

    testWidgets('is non-interactive (hit test passthrough)', (tester) async {
      engine.state.value = MediaState.playing;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // 渐变条的 GestureDetector 应使用 HitTestBehavior.translucent
      final gestureDetectors = find.byWidgetPredicate((widget) {
        if (widget is GestureDetector) {
          return widget.behavior == HitTestBehavior.translucent;
        }
        return false;
      });

      // 至少应有一个 translucent GestureDetector（渐变条使用）
      expect(gestureDetectors, findsAtLeastNWidgets(1));
    });
  });

  group('Gradient Strip Golden', () {
    testWidgets('golden: gradient strip playing state', (tester) async {
      engine.state.value = MediaState.playing;
      await tester.pumpWidget(buildSubject());
      await tester.pump(const Duration(milliseconds: 500));

      await expectLater(
        find.byType(ControlsOverlay),
        matchesGoldenFile('../goldens/gradient_strip_playing.png'),
      );
    });

    testWidgets('golden: gradient strip idle state', (tester) async {
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
