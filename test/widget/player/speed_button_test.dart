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
          body: SpeedButton(rate: engine.playbackSpeed, onSetRate: engine.setPlaybackRate),
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

    // ── Arrow tap tests ──

    testWidgets('left arrow tap decreases speed to previous gear',
        (tester) async {
      engine.playbackSpeed.value = 1.0;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // Tap left arrow (chevron_left icon)
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();

      // 1.0 → 0.75 (previous gear)
      expect(engine.playbackSpeed.value, 0.75);
      OsdService.I.hide();
    });

    testWidgets('right arrow tap increases speed to next gear',
        (tester) async {
      engine.playbackSpeed.value = 1.0;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // Tap right arrow (chevron_right icon)
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();

      // 1.0 → 1.25 (next gear)
      expect(engine.playbackSpeed.value, 1.25);
      OsdService.I.hide();
    });

    testWidgets('left arrow at min speed (0.5) clamps', (tester) async {
      engine.playbackSpeed.value = 0.5;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();

      // Already at min gear → stays at 0.5
      expect(engine.playbackSpeed.value, 0.5);
      OsdService.I.hide();
    });

    testWidgets('right arrow at max speed (4.0) clamps', (tester) async {
      engine.playbackSpeed.value = 4.0;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();

      // Already at max gear → stays at 4.0
      expect(engine.playbackSpeed.value, 4.0);
      OsdService.I.hide();
    });

    // ── Double-tap reset test ──

    testWidgets('double-tap center resets speed to 1.0', (tester) async {
      engine.playbackSpeed.value = 2.0;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // Double-tap the center segment (the text label)
      final centerSegment = find.byWidgetPredicate(
        (w) => w is GestureDetector && w.onDoubleTap != null,
      );
      await tester.tap(centerSegment);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(centerSegment);
      await tester.pump();

      expect(engine.playbackSpeed.value, 1.0);

      // Pump past OSD hold timer to avoid pending timer assertion
      await tester.pump(const Duration(seconds: 2));
      OsdService.I.hide();
    });

    testWidgets('non-standard speed snaps to nearest higher gear on arrow tap',
        (tester) async {
      // Set a non-standard speed (not in _gears list)
      // _gears = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0]
      // 1.1 → indexWhere >= 1.1 → idx=3 (1.25), right → next=4 (1.5)
      engine.playbackSpeed.value = 1.1;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();

      expect(engine.playbackSpeed.value, 1.5);
      OsdService.I.hide();
    });

    // ── Wave 2: reactive label sync + call tracking tests ──

    testWidgets('speed label updates reactively on external speed change', (
      tester,
    ) async {
      // 验证 ValueListenableBuilder<double> 正确响应 engine.playbackSpeed 变更
      engine.playbackSpeed.value = 1.0;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text('1x'), findsOneWidget);

      // 模拟外部倍速变更（如键盘快捷键）
      engine.playbackSpeed.value = 2.0;
      await tester.pump();

      expect(find.text('2x'), findsOneWidget);
      expect(find.text('1x'), findsNothing);
    });

    testWidgets('left arrow tap snaps non-standard speed to correct gear', (
      tester,
    ) async {
      // 验证非标准值 + 左箭头 → snap 到正确的较低挡位
      // _gears = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0]
      // 1.1 → indexWhere >= 1.1 → idx=3 (1.25), left → prev=2 (1.0)
      engine.playbackSpeed.value = 1.1;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();

      expect(engine.playbackSpeed.value, 1.0);
      OsdService.I.hide();
    });
  });
}
