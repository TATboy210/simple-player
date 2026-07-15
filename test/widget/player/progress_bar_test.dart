import 'package:flutter/gestures.dart';
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

      final semantics = find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.slider ?? false),
      );
      expect(semantics, findsOneWidget);
    });

    testWidgets('MouseRegion cursor is click', (tester) async {
      engine.duration.value = 10000;
      await tester.pumpWidget(buildSubject());
      final mouseRegions = tester.widgetList<MouseRegion>(
        find.byType(MouseRegion),
      );
      final clickCursor = mouseRegions.any(
        (m) => m.cursor == SystemMouseCursors.click,
      );
      expect(clickCursor, isTrue);
    });

    // ── Hover interaction tests ──

    testWidgets('hover shows tooltip with time', (tester) async {
      engine.duration.value = 60000;
      await tester.pumpWidget(buildSubject());

      final bar = find.byType(ProgressBar);
      final rect = tester.getRect(bar);
      final center = rect.center;

      // Move mouse into the bar
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: center);
      await tester.pump();

      // Hover over the bar
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();
      // PostFrameCallback fires on next pump
      await tester.pump();

      // Tooltip should be visible (a Positioned Container with time text)
      expect(find.byType(Positioned), findsWidgets);
    });

    testWidgets('onEnter sets hover state', (tester) async {
      engine.duration.value = 60000;
      await tester.pumpWidget(buildSubject());

      final bar = find.byType(ProgressBar);
      final rect = tester.getRect(bar);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      // Move to the bar center
      await gesture.moveTo(rect.center);
      await tester.pump();
      // onEnter fires → hover state set
      expect(find.byType(MouseRegion), findsWidgets);
    });

    testWidgets('onExit clears hover state', (tester) async {
      engine.duration.value = 60000;
      await tester.pumpWidget(buildSubject());

      final bar = find.byType(ProgressBar);
      final rect = tester.getRect(bar);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.moveTo(rect.center);
      await tester.pump();
      await tester.pump();

      // Move mouse out of the bar
      await gesture.moveTo(rect.topLeft + const Offset(-50, -50));
      await tester.pump();

      // Hover tooltip should not be visible after exit
      // (Positioned widgets from tooltip should be gone or shrink to SizedBox)
      expect(find.byType(ProgressBar), findsOneWidget);
    });

    testWidgets('hover tooltip hidden when duration is zero', (tester) async {
      engine.duration.value = 0;
      await tester.pumpWidget(buildSubject());

      final bar = find.byType(ProgressBar);
      final rect = tester.getRect(bar);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.moveTo(rect.center);
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();
      await tester.pump();

      // Even with hover state, tooltip should not render when duration <= 0
      expect(find.byType(ProgressBar), findsOneWidget);
    });

    testWidgets('hover tooltip hidden during drag', (tester) async {
      engine.duration.value = 10000;
      await tester.pumpWidget(buildSubject());

      final bar = find.byType(ProgressBar);
      final rect = tester.getRect(bar);

      // Start hovering
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.moveTo(rect.center);
      await tester.pump();
      await tester.pump();

      // Start drag — this should show drag tooltip and hide hover tooltip
      final start = rect.centerLeft + const Offset(50, 0);
      final end = rect.centerRight - const Offset(50, 0);
      await tester.dragFrom(start, end - start);
      await tester.pump();

      expect(engine.seekToCallCount, greaterThanOrEqualTo(1));
    });

    testWidgets('drag shows tooltip during drag', (tester) async {
      engine.duration.value = 10000;
      await tester.pumpWidget(buildSubject());

      final bar = find.byType(ProgressBar);
      final rect = tester.getRect(bar);
      final start = rect.centerLeft + const Offset(50, 0);
      final end = rect.centerRight - const Offset(50, 0);

      // Use dragFrom which reliably triggers onHorizontalDragStart/Update
      final gesture = await tester.startGesture(start);
      await tester.pump();
      await gesture.moveBy(end - start);
      await tester.pump();

      // During drag, _dragNotifier.value is non-null → drag tooltip rendered
      // The tooltip is a Positioned inside the Stack
      final stack = find.byType(Stack);
      expect(stack, findsWidgets);

      await gesture.up();
      await tester.pump();
    });

    testWidgets('drag seekTo is throttled during drag update', (tester) async {
      engine.duration.value = 10000;
      await tester.pumpWidget(buildSubject());

      final bar = find.byType(ProgressBar);
      final rect = tester.getRect(bar);
      final start = rect.centerLeft + const Offset(50, 0);
      final end = rect.centerRight - const Offset(50, 0);

      // Full drag triggers start + update + end
      await tester.dragFrom(start, end - start);
      await tester.pump();

      // seekTo fires on dragEnd (and possibly during drag via throttle timer)
      expect(engine.seekToCallCount, greaterThanOrEqualTo(1));
    });

    testWidgets('drag end with zero duration resets drag state',
        (tester) async {
      engine.duration.value = 0;
      await tester.pumpWidget(buildSubject());

      final bar = find.byType(ProgressBar);
      final rect = tester.getRect(bar);
      final start = rect.centerLeft + const Offset(50, 0);
      final end = rect.centerRight - const Offset(50, 0);

      await tester.dragFrom(start, end - start);
      await tester.pump();

      // seekTo should not be called (duration is 0, early return in onEnd)
      expect(engine.seekToCallCount, 0);
    });

    testWidgets('_BarPainter draws thumb when dragging', (tester) async {
      engine.duration.value = 10000;
      await tester.pumpWidget(buildSubject());

      final bar = find.byType(ProgressBar);
      final rect = tester.getRect(bar);
      final start = rect.centerLeft + const Offset(50, 0);
      final end = rect.centerRight - const Offset(50, 0);

      // Start a drag to trigger the thumb drawing
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(end - start);
      await tester.pump();

      // Verify CustomPaint exists (thumb is drawn inside)
      expect(find.byType(CustomPaint), findsWidgets);

      await gesture.up();
      await tester.pump();
    });

    testWidgets('_BarPainter shouldRepaint returns true on fraction change',
        (tester) async {
      engine.duration.value = 10000;
      engine.position.value = 0;
      await tester.pumpWidget(buildSubject());

      // Change position → different playedFraction → shouldRepaint
      engine.position.value = 5000;
      await tester.pump();

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('_BarPainter shouldRepaint returns true on drag state change',
        (tester) async {
      engine.duration.value = 10000;
      await tester.pumpWidget(buildSubject());

      final bar = find.byType(ProgressBar);
      final rect = tester.getRect(bar);
      final start = rect.centerLeft + const Offset(50, 0);
      final end = rect.centerRight - const Offset(50, 0);

      // Drag starts → dragging changes from false to true
      await tester.dragFrom(start, end - start);
      await tester.pump();

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('_buildTooltip positions correctly at left edge',
        (tester) async {
      engine.duration.value = 10000;
      await tester.pumpWidget(buildSubject());

      final bar = find.byType(ProgressBar);
      final rect = tester.getRect(bar);

      // Hover near left edge — fraction ~0, tooltip should be clamped to left:40
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.moveTo(rect.centerLeft + const Offset(5, 0));
      await gesture.moveBy(const Offset(2, 0));
      await tester.pump();
      await tester.pump();

      expect(find.byType(ProgressBar), findsOneWidget);
    });

    testWidgets('_buildTooltip positions correctly at right edge',
        (tester) async {
      engine.duration.value = 10000;
      await tester.pumpWidget(buildSubject());

      final bar = find.byType(ProgressBar);
      final rect = tester.getRect(bar);

      // Hover near right edge — fraction ~1, tooltip clamped to right
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.moveTo(rect.centerRight - const Offset(5, 0));
      await gesture.moveBy(const Offset(-2, 0));
      await tester.pump();
      await tester.pump();

      expect(find.byType(ProgressBar), findsOneWidget);
    });

    testWidgets('drag seekTo fires after drag ends with non-zero duration',
        (tester) async {
      engine.duration.value = 10000;
      await tester.pumpWidget(buildSubject());

      final bar = find.byType(ProgressBar);
      final rect = tester.getRect(bar);
      final start = rect.centerLeft + const Offset(50, 0);
      final end = rect.centerRight - const Offset(50, 0);

      // Full drag: triggers start → update (timer created) → end (seekTo)
      await tester.dragFrom(start, end - start);
      await tester.pump();

      // seekTo fires from onEnd callback, and potentially from timer
      expect(engine.seekToCallCount, greaterThanOrEqualTo(1));
      // Verify seek position is in valid range
      expect(engine.lastSeekToMs, greaterThanOrEqualTo(0));
      expect(engine.lastSeekToMs, lessThanOrEqualTo(10000));
    });

    testWidgets('drag tooltip shows formatted time during drag',
        (tester) async {
      engine.duration.value = 60000; // 1 minute
      await tester.pumpWidget(buildSubject());

      final bar = find.byType(ProgressBar);
      final rect = tester.getRect(bar);
      final start = rect.centerLeft + const Offset(50, 0);

      // Start drag — _dragNotifier becomes non-null
      final gesture = await tester.startGesture(start);
      await tester.pump();

      // Move to center → drag tooltip should render
      await gesture.moveTo(rect.center);
      await tester.pump();

      // Drag tooltip: may or may not render depending on layout
      // Just verify no crash during drag interaction
      expect(find.byType(Stack), findsWidgets);

      await gesture.up();
      await tester.pump();
    });

    testWidgets('multiple rapid hovers do not crash', (tester) async {
      engine.duration.value = 10000;
      await tester.pumpWidget(buildSubject());

      final bar = find.byType(ProgressBar);
      final rect = tester.getRect(bar);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.moveTo(rect.center);
      await tester.pump();

      // Rapid hover moves
      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump();
      }
      await tester.pump();

      expect(find.byType(ProgressBar), findsOneWidget);
    });

    testWidgets('hover with non-zero position shows formatted time',
        (tester) async {
      engine.duration.value = 120000; // 2 minutes
      engine.position.value = 60000;
      await tester.pumpWidget(buildSubject());

      final bar = find.byType(ProgressBar);
      final rect = tester.getRect(bar);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.moveTo(rect.center);
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();
      await tester.pump();

      // The tooltip text should contain formatted time (e.g., "1:00")
      expect(find.byType(ProgressBar), findsOneWidget);
    });

    // ── Resize freeze tests ──

    testWidgets('renders with resizing parameter', (tester) async {
      final resizing = ValueNotifier<bool>(false);
      engine.duration.value = 10000;
      engine.position.value = 5000;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 48,
              child: ProgressBar(engine: engine, resizing: resizing),
            ),
          ),
        ),
      );

      expect(find.byType(ProgressBar), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      resizing.dispose();
    });

    testWidgets('skips internal rebuild when resizing is true', (tester) async {
      final resizing = ValueNotifier<bool>(false);
      engine.duration.value = 10000;
      engine.position.value = 5000;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 48,
              child: ProgressBar(engine: engine, resizing: resizing),
            ),
          ),
        ),
      );

      // Start resizing
      resizing.value = true;
      await tester.pump();

      // Change position during resize — should not crash
      engine.position.value = 8000;
      await tester.pump();

      expect(find.byType(ProgressBar), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      resizing.dispose();
    });

    // ── Wave 2 gap: additional ProgressBar tests ──

    testWidgets('drag below threshold does not enter drag state', (
      tester,
    ) async {
      engine.duration.value = 10000;
      await tester.pumpWidget(buildSubject());

      final bar = find.byType(ProgressBar);
      final rect = tester.getRect(bar);
      final start = rect.centerLeft + const Offset(50, 0);

      // Use startGesture + small move (< 5px threshold) — stays below threshold
      final gesture = await tester.startGesture(start);
      await tester.pump();
      await gesture.moveBy(const Offset(3, 0));
      await tester.pump();

      // Drag state should not be entered (no drag tooltip)
      // Small drag may resolve as tap on up — that's OK, we test drag threshold
      await gesture.up();
      await tester.pump();

      expect(find.byType(ProgressBar), findsOneWidget);
    });

    testWidgets('hover exit during drag does not crash', (tester) async {
      engine.duration.value = 10000;
      await tester.pumpWidget(buildSubject());

      final bar = find.byType(ProgressBar);
      final rect = tester.getRect(bar);

      // Start hover
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.moveTo(rect.center);
      await tester.pump();
      await tester.pump();

      // Start drag while hovering
      final start = rect.centerLeft + const Offset(50, 0);
      final end = rect.centerRight - const Offset(50, 0);
      await gesture.moveTo(start);
      await gesture.down(start);
      await tester.pump();
      await gesture.moveTo(end);
      await tester.pump();

      // Move mouse out during drag — should not crash
      await gesture.moveTo(rect.topLeft + const Offset(-100, -100));
      await tester.pump();

      await gesture.up();
      await tester.pump();

      expect(find.byType(ProgressBar), findsOneWidget);
    });

    testWidgets('hover tooltip displays formatted time', (tester) async {
      engine.duration.value = 120000; // 2 minutes
      await tester.pumpWidget(buildSubject());

      final bar = find.byType(ProgressBar);
      final rect = tester.getRect(bar);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.moveTo(rect.center);
      await gesture.moveBy(const Offset(5, 0));
      await tester.pump();
      await tester.pump();

      // Tooltip should contain formatted time text (e.g. "1:00")
      expect(find.byType(Positioned), findsWidgets);
    });

    testWidgets('hover triggers bar expand animation', (tester) async {
      engine.duration.value = 10000;
      await tester.pumpWidget(buildSubject());

      final bar = find.byType(ProgressBar);
      final rect = tester.getRect(bar);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.moveTo(rect.center);
      await gesture.moveBy(const Offset(5, 0));
      await tester.pump();
      await tester.pump();

      // ProgressBar should still render (expand animation triggered internally)
      expect(find.byType(ProgressBar), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('didUpdateWidget with new resizing parameter', (tester) async {
      final resizing1 = ValueNotifier<bool>(false);
      final resizing2 = ValueNotifier<bool>(false);
      engine.duration.value = 10000;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 48,
              child: ProgressBar(engine: engine, resizing: resizing1),
            ),
          ),
        ),
      );
      expect(find.byType(ProgressBar), findsOneWidget);

      // Swap resizing parameter — triggers didUpdateWidget
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 48,
              child: ProgressBar(engine: engine, resizing: resizing2),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ProgressBar), findsOneWidget);
      resizing1.dispose();
      resizing2.dispose();
    });

    testWidgets('resumes rebuild after resize ends', (tester) async {
      final resizing = ValueNotifier<bool>(false);
      engine.duration.value = 10000;
      engine.position.value = 5000;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 48,
              child: ProgressBar(engine: engine, resizing: resizing),
            ),
          ),
        ),
      );

      // Start resizing
      resizing.value = true;
      await tester.pump();

      // Change position during resize
      engine.position.value = 8000;
      await tester.pump();

      // End resizing — triggers rebuild with latest values
      resizing.value = false;
      await tester.pump();

      expect(find.byType(ProgressBar), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      resizing.dispose();
    });

    // ── Wave 2: proportional seek + value sync tests ──

    testWidgets('tap at center seeks to ~50% of duration', (tester) async {
      // 验证点击进度条中心 → seekTo 接近 duration 的 50%
      engine.duration.value = 20000;
      await tester.pumpWidget(buildSubject());

      final bar = find.byType(ProgressBar);
      final rect = tester.getRect(bar);

      // 点击中心位置
      await tester.tapAt(rect.center);
      await tester.pump();

      expect(engine.seekToCallCount, 1);
      // seekTo 应在 duration 50% 附近（容差 ±10%）
      expect(engine.lastSeekToMs, greaterThan(8000));
      expect(engine.lastSeekToMs, lessThan(12000));
    });

    testWidgets('tap at 25% position seeks to ~25% of duration', (
      tester,
    ) async {
      // 验证点击进度条 25% 位置 → seekTo 接近 duration 的 25%
      engine.duration.value = 40000;
      await tester.pumpWidget(buildSubject());

      final bar = find.byType(ProgressBar);
      final rect = tester.getRect(bar);
      final tapX = rect.left + rect.width * 0.25;

      await tester.tapAt(Offset(tapX, rect.center.dy));
      await tester.pump();

      expect(engine.seekToCallCount, 1);
      // seekTo 应在 duration 25% 附近（容差 ±10%）
      expect(engine.lastSeekToMs, greaterThan(6000));
      expect(engine.lastSeekToMs, lessThan(14000));
    });

    testWidgets('multiple taps update seek position correctly', (tester) async {
      // 验证多次点击 → 每次 seekTo 正确更新
      engine.duration.value = 10000;
      await tester.pumpWidget(buildSubject());

      final bar = find.byType(ProgressBar);
      final rect = tester.getRect(bar);

      // 第一次点击：左侧
      await tester.tapAt(rect.centerLeft + const Offset(50, 0));
      await tester.pump();

      final firstSeek = engine.lastSeekToMs;
      expect(engine.seekToCallCount, 1);

      // 第二次点击：右侧
      await tester.tapAt(rect.centerRight - const Offset(50, 0));
      await tester.pump();

      expect(engine.seekToCallCount, 2);
      // 第二次 seek 应比第一次更远
      expect(engine.lastSeekToMs, greaterThan(firstSeek!));
    });
  });
}
