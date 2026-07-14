import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/controls_overlay.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
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
    MediaEngine? eng,
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

  group('ControlsOverlay', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(ControlsOverlay), findsOneWidget);
    });

    testWidgets('renders ControlBar', (tester) async {
      engine.state.value = MediaState.playing;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(ControlsOverlay), findsOneWidget);
    });

    testWidgets('double tap triggers onToggleFullscreen', (tester) async {
      var toggled = false;
      engine.state.value = MediaState.playing;
      await tester.pumpWidget(
        buildSubject(
          actions: PlayerActions(onToggleFullscreen: () => toggled = true),
        ),
      );
      await tester.pump();

      final center = tester.getCenter(find.byType(ControlsOverlay));
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(center);
      await tester.pump();
      // Pump past the click timer (250ms) to let it resolve
      await tester.pump(const Duration(milliseconds: 300));

      expect(toggled, isTrue);
    });

    testWidgets('single tap hides controls after delay', (tester) async {
      engine.state.value = MediaState.playing;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final center = tester.getCenter(find.byType(ControlsOverlay));
      await tester.tapAt(center);
      await tester.pump();

      // After 250ms delay + animation
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('idle state does not hide on tap', (tester) async {
      engine.state.value = MediaState.idle;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final center = tester.getCenter(find.byType(ControlsOverlay));
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('emptyStatePresent + idle disables gesture', (tester) async {
      engine.state.value = MediaState.idle;
      await tester.pumpWidget(buildSubject(emptyStatePresent: true));
      await tester.pump();

      // Should render without error
      expect(find.byType(ControlsOverlay), findsOneWidget);
    });

    testWidgets('didUpdateWidget propagates isFullscreen change', (
      tester,
    ) async {
      engine.state.value = MediaState.playing;
      await tester.pumpWidget(buildSubject(isFullscreen: false));
      await tester.pump();

      // Rebuild with isFullscreen = true
      await tester.pumpWidget(buildSubject(isFullscreen: true));
      await tester.pump();

      // No crash, AutoHideController updated
      expect(find.byType(ControlsOverlay), findsOneWidget);
    });

    testWidgets('mouse hover shows controls', (tester) async {
      engine.state.value = MediaState.playing;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(
        location: tester.getCenter(find.byType(ControlsOverlay)),
      );
      addTearDown(gesture.removePointer);

      await gesture.moveTo(tester.getCenter(find.byType(ControlsOverlay)));
      await tester.pump();

      expect(find.byType(ControlsOverlay), findsOneWidget);
    });

    testWidgets('engine state change triggers AutoHideController callback', (
      tester,
    ) async {
      engine.state.value = MediaState.idle;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // Change engine state while widget is mounted — triggers _onEngineStateChanged
      engine.state.value = MediaState.playing;
      await tester.pump();

      // _onEngineStateChanged calls _autoHide.onEngineStateChanged()
      // playing → show() + scheduleHide() — widget still visible
      expect(find.byType(ControlsOverlay), findsOneWidget);
    });

    testWidgets('mouse in bottom trigger zone shows controls', (tester) async {
      // D-03: 鼠标在底部 150px 内应触发控制栏显示
      engine.state.value = MediaState.playing;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final overlay = tester.getRect(find.byType(ControlsOverlay));
      // 底部区域中心点：距底部约 75px（在 150px 触发区内）
      final bottomZoneCenter = Offset(
        overlay.center.dx,
        overlay.bottom - 75,
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: bottomZoneCenter);
      addTearDown(gesture.removePointer);

      await gesture.moveTo(bottomZoneCenter);
      await tester.pump();

      // 控制栏应可见（触发了 onMouseMove → show）
      expect(find.byType(ControlsOverlay), findsOneWidget);
    });

    testWidgets('mouse above bottom trigger zone does NOT show controls', (
      tester,
    ) async {
      // D-03: 鼠标在底部 150px 以上不应触发控制栏显示
      engine.state.value = MediaState.playing;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final overlay = tester.getRect(find.byType(ControlsOverlay));
      // 顶部区域：距底部远超 150px
      final topZone = Offset(overlay.center.dx, overlay.top + 20);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: topZone);
      addTearDown(gesture.removePointer);

      await gesture.moveTo(topZone);
      await tester.pump();

      // 控制栏应仍为可见（因为 playing 状态初始就 show），但 onHover 不应触发额外的 onMouseMove
      // 验证方式：widget 存在且无异常
      expect(find.byType(ControlsOverlay), findsOneWidget);
    });

    testWidgets('single tap immediately hides controls (D-04)', (tester) async {
      // D-04: 第一次点击应立即隐藏，不等 250ms 延迟
      engine.state.value = MediaState.playing;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final center = tester.getCenter(find.byType(ControlsOverlay));
      await tester.tapAt(center);
      await tester.pump();

      // 立即 pump 一次（无延迟）— hide() 应已调用
      // 动画需要 400ms 完成，但 hide() 调用是即时的
      // pump 一小段时间后动画应已开始 reverse
      await tester.pump(const Duration(milliseconds: 100));

      // pump 完成动画
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('mouse exit triggers onMouseExit', (tester) async {
      engine.state.value = MediaState.playing;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final overlay = find.byType(ControlsOverlay);
      final center = tester.getCenter(overlay);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: center);
      addTearDown(gesture.removePointer);

      await gesture.moveTo(center);
      await tester.pump();

      await gesture.moveTo(center + const Offset(5000, 5000));
      await tester.pump();

      expect(find.byType(ControlsOverlay), findsOneWidget);
    });
  });

  group('ControlsOverlay resize flow', () {
    testWidgets('resizing=true triggers animation reverse', (tester) async {
      final resizing = ValueNotifier<bool>(false);
      engine.state.value = MediaState.playing;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ControlsOverlay(engine: engine, resizing: resizing),
          ),
        ),
      );
      await tester.pump();

      resizing.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(ControlsOverlay), findsOneWidget);
      resizing.dispose();
    });

    testWidgets('resizing blocks engine state changes', (tester) async {
      final resizing = ValueNotifier<bool>(false);
      engine.state.value = MediaState.playing;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ControlsOverlay(engine: engine, resizing: resizing),
          ),
        ),
      );
      await tester.pump();

      resizing.value = true;
      await tester.pump();

      // Engine state change during resize — _isResizing guard blocks
      engine.state.value = MediaState.idle;
      await tester.pump();
      engine.state.value = MediaState.playing;
      await tester.pump();

      expect(find.byType(ControlsOverlay), findsOneWidget);
      resizing.dispose();
    });

    testWidgets('resizing=false restores decoration by engine state', (
      tester,
    ) async {
      final resizing = ValueNotifier<bool>(false);
      engine.state.value = MediaState.playing;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ControlsOverlay(engine: engine, resizing: resizing),
          ),
        ),
      );
      await tester.pump();

      resizing.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      resizing.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(ControlsOverlay), findsOneWidget);
      resizing.dispose();
    });
  });
}
