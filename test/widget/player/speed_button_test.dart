import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/speed_button.dart';
import 'package:simple_player_flutter/ui/shared/osd_overlay.dart';
import '../../helpers/fake_engine.dart';

void main() {
  group('SpeedButton', () {
    late FakeEngine engine;

    setUp(() {
      engine = FakeEngine();
    });

    tearDown(() {
      OsdService.I.hide();
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
      final row = tester.widget<Row>(
        find.descendant(
          of: find.byType(SpeedButton),
          matching: find.byType(Row),
        ),
      );
      expect(row.children.length, 3);
    });

    // ── Scroll wheel tests ──

    testWidgets('scroll wheel up increases speed', (tester) async {
      engine.playbackSpeed.value = 1.0;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final button = find.byType(SpeedButton);
      final center = tester.getRect(button).center;

      final event = PointerScrollEvent(
        scrollDelta: const Offset(0, -100),
        position: center,
      );
      GestureBinding.instance.handlePointerEvent(event);
      await tester.pump();

      expect(engine.playbackSpeed.value, greaterThan(1.0));
      OsdService.I.hide();
    });

    testWidgets('scroll wheel down decreases speed', (tester) async {
      engine.playbackSpeed.value = 1.0;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final button = find.byType(SpeedButton);
      final center = tester.getRect(button).center;

      final event = PointerScrollEvent(
        scrollDelta: const Offset(0, 100),
        position: center,
      );
      GestureBinding.instance.handlePointerEvent(event);
      await tester.pump();

      expect(engine.playbackSpeed.value, lessThan(1.0));
      OsdService.I.hide();
    });

    testWidgets('scroll wheel at max speed clamps', (tester) async {
      engine.playbackSpeed.value = 4.0;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final button = find.byType(SpeedButton);
      final center = tester.getRect(button).center;

      final event = PointerScrollEvent(
        scrollDelta: const Offset(0, -100),
        position: center,
      );
      GestureBinding.instance.handlePointerEvent(event);
      await tester.pump();

      expect(engine.playbackSpeed.value, 4.0);
      OsdService.I.hide();
    });

    testWidgets('scroll wheel at min speed clamps', (tester) async {
      engine.playbackSpeed.value = 0.5;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final button = find.byType(SpeedButton);
      final center = tester.getRect(button).center;

      final event = PointerScrollEvent(
        scrollDelta: const Offset(0, 100),
        position: center,
      );
      GestureBinding.instance.handlePointerEvent(event);
      await tester.pump();

      expect(engine.playbackSpeed.value, 0.5);
      OsdService.I.hide();
    });

    // ── Double-tap reset test ──

    // ── Rendering assertions ──

    testWidgets('left arrow segment has chevron_left icon', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    });

    testWidgets('right arrow segment has chevron_right icon', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('each segment has a Tooltip', (tester) async {
      await tester.pumpWidget(buildSubject());
      // 3 segments → 3 Tooltips
      expect(find.byType(Tooltip), findsNWidgets(3));
    });

    testWidgets('each segment has InkWell for hover feedback', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.byType(InkWell), findsNWidgets(3));
    });

    testWidgets('SizedBox is 72x36', (tester) async {
      await tester.pumpWidget(buildSubject());
      // SpeedButton wraps everything in SizedBox(72, 36)
      final box = tester.widget<SizedBox>(
        find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 72 && w.height == 36,
        ),
      );
      expect(box.width, 72);
      expect(box.height, 36);
    });
  });
}
