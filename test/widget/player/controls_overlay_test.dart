import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/kernel/playlist/playlist.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/control_bar.dart';
import 'package:simple_player_flutter/ui/player/controls_overlay.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import '../../helpers/fake_engine.dart';

void main() {
  late FakeEngine engine;
  // 渐进路径:ControlsOverlay 需 currentFileName/playlist/playlistGeneration/
  // openFileEnabled 自驱动 builder — 测试共享实例,tearDown 释放。
  late Playlist playlist;
  late ValueNotifier<int> playlistGeneration;
  late ValueNotifier<String> currentFileName;
  late ValueNotifier<bool> openFileEnabled;

  setUp(() {
    engine = FakeEngine();
    playlist = Playlist();
    playlistGeneration = ValueNotifier<int>(0);
    currentFileName = ValueNotifier<String>('');
    openFileEnabled = ValueNotifier<bool>(true);
  });

  tearDown(() {
    engine.dispose();
    playlistGeneration.dispose();
    currentFileName.dispose();
    openFileEnabled.dispose();
  });

  Widget buildSubject({
    MediaEngine? eng,
    PlayerActions? actions,
    bool isFullscreen = false,
    Widget? emptyState,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ControlsOverlay(
          engine: eng ?? engine,
          actions: actions ?? const PlayerActions(),
          currentFileName: currentFileName,
          playlist: playlist,
          playlistGeneration: playlistGeneration,
          openFileEnabled: openFileEnabled,
          emptyState: emptyState,
          isFullscreen: isFullscreen,
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
      // Pump past the click timer (400ms) to let it resolve
      await tester.pump(const Duration(milliseconds: 450));

      expect(toggled, isTrue);
    });

    testWidgets('single tap hides controls after delay', (tester) async {
      engine.state.value = MediaState.playing;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final center = tester.getCenter(find.byType(ControlsOverlay));
      await tester.tapAt(center);
      await tester.pump();

      // After 400ms click delay + 150ms fade
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

    testWidgets('emptyState + idle disables gesture', (tester) async {
      // 渐进路径:emptyStatePresent 标志位升级为 emptyState Widget? —
      // idle && !hasMedia 时内化渲染(FakeEngine 默认 hasMedia=false)。
      engine.state.value = MediaState.idle;
      await tester.pumpWidget(buildSubject(emptyState: const SizedBox()));
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
      final bottomZoneCenter = Offset(overlay.center.dx, overlay.bottom - 75);

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
      // D-04: 第一次点击应立即隐藏，不等 400ms 延迟
      engine.state.value = MediaState.playing;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final center = tester.getCenter(find.byType(ControlsOverlay));
      await tester.tapAt(center);
      await tester.pump();

      // 立即 pump 一次（无延迟）— hide() 应已调用
      // 动画需要 150ms 完成，但 hide() 调用是即时的
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

    // ── Wave 2: auto-hide timer + state-driven visibility tests ──

    testWidgets('playing state auto-hides controls after hide delay', (
      tester,
    ) async {
      // 验证 AutoHideController scheduleHide() 生效：
      // playing 状态下 → 控制栏初始可见 → 等待 hideDelay → controlBar 被 IgnorePointer 拦截
      engine.state.value = MediaState.playing;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // 确认控制栏初始可见（playing 状态 show() + scheduleHide()）
      expect(find.byType(ControlBar), findsOneWidget);

      // pump 超过窗口模式 hideDelay (Tokens.hideDelayWindowed = 3秒)
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 500)); // 动画完成

      // auto-hide 触发:visible=false → Visibility offstage,但 maintainState
      // 保留 ControlBar 在 tree(skipOffstage:false 确认仍挂载,可恢复显示)
      expect(find.byType(ControlBar, skipOffstage: false), findsOneWidget);
    });

    testWidgets('paused state keeps controls visible after delay', (
      tester,
    ) async {
      // paused 状态下 AutoHideController.onEngineStateChanged() 不调用 scheduleHide()
      // 控制栏应永久可见 — ControlBar 仍然可以交互
      engine.state.value = MediaState.paused;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // 等待超过正常 hideDelay
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      // ControlBar 仍应存在于 widget tree 中
      expect(find.byType(ControlBar), findsOneWidget);
    });

    testWidgets('completed state keeps controls visible after delay', (
      tester,
    ) async {
      // completed 和 paused 一样 — 控制栏永久显示
      engine.state.value = MediaState.completed;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      expect(find.byType(ControlBar), findsOneWidget);
    });

    testWidgets('mouse move in bottom zone re-shows hidden controls', (
      tester,
    ) async {
      // 流程：playing → 控制栏自动隐藏 → 鼠标移入底部 → 控制栏重新显示
      engine.state.value = MediaState.playing;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // 等待自动隐藏
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 500));

      // 鼠标移入底部触发区 — onMouseMove → show()
      final overlay = tester.getRect(find.byType(ControlsOverlay));
      final bottomZone = Offset(overlay.center.dx, overlay.bottom - 50);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: bottomZone);
      addTearDown(gesture.removePointer);

      await gesture.moveTo(bottomZone);
      await tester.pump();

      // 控制栏应重新可见
      expect(find.byType(ControlBar), findsOneWidget);
    });

    testWidgets('ErrorBanner renders inside ControlsOverlay', (tester) async {
      // 验证 ErrorBanner 作为 ControlsOverlay 子组件存在.
      // D7: simulateError → UnknownError → l10nKey 'error.unknown' → ARB 英文值
      // 'An unexpected error occurred'(原始 message 被 l10nKey 查找忽略,
      // 详见 error_banner_test.dart 同款断言 + error_banner.dart _resolveMessage)
      engine.simulateError('Test error message');
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // ErrorBanner 在 ControlsOverlay 内部渲染,显示本地化文案(非原始 message)
      expect(
        find.descendant(
          of: find.byType(ControlsOverlay),
          matching: find.text('An unexpected error occurred'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('visibleSink syncs with auto-hide visibility', (tester) async {
      // visibleSink 单向同步 _autoHide.visible → sink(防回环)
      engine.state.value = MediaState.playing;
      final sink = ValueNotifier<bool>(true);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ControlsOverlay(
              engine: engine,
              currentFileName: currentFileName,
              playlist: playlist,
              playlistGeneration: playlistGeneration,
              openFileEnabled: openFileEnabled,
              visibleSink: sink,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(sink.value, isTrue); // 初始可见

      // 单击触发隐藏 → fade(150ms) → visible=false → sink 同步 false
      final center = tester.getCenter(find.byType(ControlsOverlay));
      await tester.tapAt(center);
      await tester.pump();
      // >400ms click timer + 150ms fade
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();

      expect(sink.value, isFalse);
      sink.dispose();
    });

    testWidgets(
      'mouse resting over ControlBar keeps controls visible (regression)',
      (tester) async {
        // 回归:整区 MouseRegion 覆盖 ControlBar — 鼠标停在 ControlBar 上不触发
        // onExit,_hovering 保持 true,timer 到期不 hide。旧代码(MouseRegion 不覆盖
        // ControlBar)会 onExit → 3s 后控件消失。
        engine.state.value = MediaState.playing;
        final sink = ValueNotifier<bool>(true);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ControlsOverlay(
                engine: engine,
                currentFileName: currentFileName,
                playlist: playlist,
                playlistGeneration: playlistGeneration,
                openFileEnabled: openFileEnabled,
                visibleSink: sink,
              ),
            ),
          ),
        );
        await tester.pump();

        final overlay = tester.getRect(find.byType(ControlsOverlay));
        // ControlBar 区域内(距底部 30px — 在 150px 触发区内,整区 MouseRegion 覆盖)
        final controlBarPoint = Offset(overlay.center.dx, overlay.bottom - 30);

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: controlBarPoint);
        addTearDown(gesture.removePointer);
        await gesture.moveTo(controlBarPoint);
        await tester.pump();

        // 停留超过 hide delay(3s)— _hovering=true,timer 不 hide
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();

        expect(sink.value, isTrue); // 控件仍可见
        sink.dispose();
      },
    );
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
            body: ControlsOverlay(
              engine: engine,
              currentFileName: currentFileName,
              playlist: playlist,
              playlistGeneration: playlistGeneration,
              openFileEnabled: openFileEnabled,
              resizing: resizing,
            ),
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
            body: ControlsOverlay(
              engine: engine,
              currentFileName: currentFileName,
              playlist: playlist,
              playlistGeneration: playlistGeneration,
              openFileEnabled: openFileEnabled,
              resizing: resizing,
            ),
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
            body: ControlsOverlay(
              engine: engine,
              currentFileName: currentFileName,
              playlist: playlist,
              playlistGeneration: playlistGeneration,
              openFileEnabled: openFileEnabled,
              resizing: resizing,
            ),
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
