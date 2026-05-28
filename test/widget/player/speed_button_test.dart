import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/speed_button.dart';
import '../../helpers/fake_engine.dart';

void main() {
  group('SpeedButton', () {
    late FakeEngine engine;

    setUp(() {
      engine = FakeEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    Widget buildSubject() {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SpeedButton(engine: engine),
        ),
      );
    }

    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.byType(SpeedButton), findsOneWidget);
    });

    testWidgets('displays current speed as 1x', (tester) async {
      engine.playbackSpeed.value = 1.0;
      await tester.pumpWidget(buildSubject());
      expect(find.text('1x'), findsOneWidget);
    });

    testWidgets('displays fractional speed correctly', (tester) async {
      engine.playbackSpeed.value = 1.5;
      await tester.pumpWidget(buildSubject());
      expect(find.text('1.50x'), findsOneWidget);
    });

    testWidgets('speed label shows 0.50x at minimum', (tester) async {
      engine.playbackSpeed.value = 0.5;
      await tester.pumpWidget(buildSubject());
      expect(find.text('0.50x'), findsOneWidget);
    });

    testWidgets('speed label shows 4x at maximum', (tester) async {
      engine.playbackSpeed.value = 4.0;
      await tester.pumpWidget(buildSubject());
      expect(find.text('4x'), findsOneWidget);
    });

    testWidgets('speed label shows 0.75x', (tester) async {
      engine.playbackSpeed.value = 0.75;
      await tester.pumpWidget(buildSubject());
      expect(find.text('0.75x'), findsOneWidget);
    });

    testWidgets('speed label shows 3x for integer speed', (tester) async {
      engine.playbackSpeed.value = 3.0;
      await tester.pumpWidget(buildSubject());
      expect(find.text('3x'), findsOneWidget);
    });

    testWidgets('renders three segments in a Row', (tester) async {
      await tester.pumpWidget(buildSubject());
      // SpeedButton builds a Row with 3 children
      final row = tester.widget<Row>(
        find.descendant(
          of: find.byType(SpeedButton),
          matching: find.byType(Row),
        ),
      );
      expect(row.children.length, 3);
    });
  });
}
