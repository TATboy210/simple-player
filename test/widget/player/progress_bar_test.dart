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

      final bar = find.byType(ProgressBar);
      await tester.tapAt(tester.getRect(bar).center);
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

    testWidgets('drag does not seek when duration is zero', (tester) async {
      engine.duration.value = 0;
      await tester.pumpWidget(buildSubject());

      final bar = find.byType(ProgressBar);
      final rect = tester.getRect(bar);
      final start = rect.centerLeft + const Offset(50, 0);
      final end = rect.centerRight - const Offset(50, 0);

      await tester.dragFrom(start, end - start);
      await tester.pump();

      expect(engine.seekToCallCount, 0);
    });

    testWidgets('tap near left edge seeks to start', (tester) async {
      engine.duration.value = 10000;
      await tester.pumpWidget(buildSubject());

      final bar = find.byType(ProgressBar);
      final rect = tester.getRect(bar);
      await tester.tapAt(rect.centerLeft + const Offset(2, 0));
      await tester.pump();

      expect(engine.seekToCallCount, 1);
      expect(engine.lastSeekToMs, lessThanOrEqualTo(500));
    });

    testWidgets('tap near right edge seeks to end', (tester) async {
      engine.duration.value = 10000;
      await tester.pumpWidget(buildSubject());

      final bar = find.byType(ProgressBar);
      final rect = tester.getRect(bar);
      await tester.tapAt(rect.centerRight - const Offset(2, 0));
      await tester.pump();

      expect(engine.seekToCallCount, 1);
      expect(engine.lastSeekToMs, greaterThanOrEqualTo(9500));
    });

    testWidgets('renders with buffered content', (tester) async {
      engine.duration.value = 10000;
      engine.position.value = 3000;
      engine.buffered.value = 6000;
      await tester.pumpWidget(buildSubject());
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('Semantics slider is present', (tester) async {
      engine.duration.value = 10000;
      engine.position.value = 5000;
      await tester.pumpWidget(buildSubject());

      // The Semantics widget with slider:true should exist
      final semantics = find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.slider ?? false),
      );
      expect(semantics, findsOneWidget);
    });

    testWidgets('MouseRegion cursor is click', (tester) async {
      await tester.pumpWidget(buildSubject());
      // ProgressBar wraps content in MouseRegion with click cursor
      final mouseRegions = tester.widgetList<MouseRegion>(
        find.byType(MouseRegion),
      );
      final clickCursor = mouseRegions.any(
        (m) => m.cursor == SystemMouseCursors.click,
      );
      expect(clickCursor, isTrue);
    });
  });
}
