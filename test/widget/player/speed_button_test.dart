import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/media_engine.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/speed_button.dart';
import 'package:simple_player_flutter/ui/widgets/osd_overlay.dart';
import '../../helpers/fake_engine.dart';

void main() {
  late FakeEngine engine;

  setUp(() {
    engine = FakeEngine();
  });

  tearDown(() {
    OsdService.I.hide();
    engine.dispose();
  });

  Widget buildSubject({
    MediaEngine? eng,
    ValueNotifier<int>? popupCloseNotifier,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SpeedButton(
          engine: eng ?? engine,
          popupCloseNotifier: popupCloseNotifier,
        ),
      ),
    );
  }

  group('SpeedButton', () {
    testWidgets('displays current speed label', (tester) async {
      engine.playbackSpeed.value = 1.0;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text('1x'), findsOneWidget);
    });

    testWidgets('displays fractional speed label', (tester) async {
      engine.playbackSpeed.value = 1.5;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text('1.5x'), findsOneWidget);
    });

    testWidgets('label updates when speed changes', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.text('1x'), findsOneWidget);

      engine.playbackSpeed.value = 2.0;
      await tester.pump();

      expect(find.text('2x'), findsOneWidget);
    });
  });

  group('SpeedSelector', () {
    Widget buildSelector({MediaEngine? eng, VoidCallback? onClose}) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SpeedSelector(
              engine: eng ?? engine,
              onClose: onClose ?? () {},
            ),
          ),
        ),
      );
    }

    testWidgets('renders all speed options', (tester) async {
      await tester.pumpWidget(buildSelector());
      await tester.pump();

      for (final speed in SpeedSelector.speeds) {
        final label = speed == speed.roundToDouble()
            ? '${speed.toInt()}x'
            : '${speed}x';
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('selecting a speed calls engine.setPlaybackRate',
        (tester) async {
      engine.playbackSpeed.value = 1.0;
      await tester.pumpWidget(buildSelector());
      await tester.pump();

      await tester.tap(find.text('2x'));
      await tester.pump();
      OsdService.I.hide();

      expect(engine.playbackSpeed.value, 2.0);
    });

    testWidgets('selecting a speed calls onClose', (tester) async {
      var closed = false;
      engine.playbackSpeed.value = 1.0;
      await tester.pumpWidget(buildSelector(onClose: () => closed = true));
      await tester.pump();

      await tester.tap(find.text('2x'));
      await tester.pump();
      OsdService.I.hide();

      expect(closed, isTrue);
    });
  });
}
