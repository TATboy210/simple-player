import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/progress_bar.dart';
import '../../helpers/fake_engine.dart';

void main() {
  group('ProgressBar', () {
    late FakeEngine engine;

    setUp(() {
      engine = FakeEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    Widget buildSubject({double width = 800}) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: width,
            height: 48,
            child: ProgressBar(engine: engine),
          ),
        ),
      );
    }

    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.byType(ProgressBar), findsOneWidget);
    });

    testWidgets('renders with zero duration without error', (tester) async {
      engine.duration.value = 0;
      engine.position.value = 0;
      await tester.pumpWidget(buildSubject());
      expect(find.byType(ProgressBar), findsOneWidget);
    });

    testWidgets('renders with non-zero position and duration', (tester) async {
      engine.duration.value = 10000;
      engine.position.value = 5000;
      await tester.pumpWidget(buildSubject());
      expect(find.byType(ProgressBar), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('tap triggers seekTo', (tester) async {
      engine.duration.value = 10000;
      await tester.pumpWidget(buildSubject());

      // Tap at the center of the progress bar
      final bar = find.byType(ProgressBar);
      await tester.tapAt(
        tester.getRect(bar).center,
      );
      await tester.pump();

      expect(engine.seekToCallCount, greaterThanOrEqualTo(1));
    });

    testWidgets('does not seek when duration is zero', (tester) async {
      engine.duration.value = 0;
      await tester.pumpWidget(buildSubject());

      final bar = find.byType(ProgressBar);
      await tester.tapAt(tester.getRect(bar).center);
      await tester.pump();

      expect(engine.seekToCallCount, 0);
    });

    testWidgets('drag updates position and triggers seek on end',
        (tester) async {
      engine.duration.value = 10000;
      await tester.pumpWidget(buildSubject());

      final bar = find.byType(ProgressBar);
      final rect = tester.getRect(bar);
      final start = rect.centerLeft + const Offset(50, 0);
      final end = rect.centerRight - const Offset(50, 0);

      await tester.dragFrom(start, end - start);
      await tester.pump();

      expect(engine.seekToCallCount, greaterThanOrEqualTo(1));
    });
  });
}
