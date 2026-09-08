/// v0.0.4 控制栏显现区域测试 — 显现/保活判定收窄到控制栏本体矩形。
///
/// 回归背景：原实现顶层 MouseRegion 的 onEnter 无条件 show()，
/// 鼠标从窗口任意位置进入即唤醒控制栏；onHover 用底部 150px 全宽
/// 触发区（bottomTriggerZoneHeight）。v0.0.4 起两者统一由
/// [PlayerVideoControls.isPointerInsideControlBar] 门控。
library;

import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/window_bridge/window_bridge.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import 'package:simple_player_flutter/ui/player/player_video_controls.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

import '../../helpers/fake_engine.dart';
import '../../helpers/fake_player_controls.dart';
import '../../helpers/fake_video_controls.dart';

/// 测试面尺寸 — 对齐 player_video_controls_test 的 pumpControls harness。
const _surface = Size(1280, 720);

/// 控制栏矩形内的代表点（1280×720 面）：x∈[18,1262], dy∈[594,704]。
const _insideBar = Offset(640, 650);

/// 控制栏矩形外的代表点：视频正中。
const _videoCenter = Offset(640, 360);

void main() {
  group('isPointerInsideControlBar 判定矩形', () {
    // 矩形边界推导：left/right = controlBarMarginH(18)，
    // 距底 [controlBarMarginBottom(16), +controlBarHeight(110)]，
    // 即 dy ∈ [720-126, 720-16] = [594, 704]。
    test('控制栏矩形内 → true', () {
      expect(
        PlayerVideoControls.isPointerInsideControlBar(_surface, _insideBar),
        isTrue,
      );
    });

    test('视频正中（旧触发区内）→ false', () {
      // 回归锁定：旧底部 150px 全宽触发区会把这里判为可显现。
      expect(
        PlayerVideoControls.isPointerInsideControlBar(_surface, _videoCenter),
        isFalse,
      );
    });

    test('控制栏顶边正上方（距底 140px，旧触发区内）→ false', () {
      expect(
        PlayerVideoControls.isPointerInsideControlBar(
          _surface,
          const Offset(640, 580),
        ),
        isFalse,
      );
    });

    test('控制栏下方的底部边距条（距底 8px）→ false', () {
      expect(
        PlayerVideoControls.isPointerInsideControlBar(
          _surface,
          const Offset(640, 712),
        ),
        isFalse,
      );
    });

    test('左右边距条（x=10 / x=1270）→ false', () {
      expect(
        PlayerVideoControls.isPointerInsideControlBar(
          _surface,
          const Offset(10, 650),
        ),
        isFalse,
      );
      expect(
        PlayerVideoControls.isPointerInsideControlBar(
          _surface,
          const Offset(1270, 650),
        ),
        isFalse,
      );
    });

    test('矩形边界含端点（x=18/1262, dy=594/704）→ true', () {
      expect(
        PlayerVideoControls.isPointerInsideControlBar(
          _surface,
          const Offset(18, 594),
        ),
        isTrue,
      );
      expect(
        PlayerVideoControls.isPointerInsideControlBar(
          _surface,
          const Offset(1262, 704),
        ),
        isTrue,
      );
    });
  });

  group('控制栏显现区域 widget 行为', () {
    late FakeEngine engine;
    late FakePlayerControls port;
    late FakeVideoControlsPort video;
    late ValueNotifier<String> currentFileName;
    late ValueNotifier<WindowMode> windowMode;

    setUp(() {
      engine = FakeEngine();
      port = FakePlayerControls(isPlayingNow: true);
      video = FakeVideoControlsPort(player: port);
      currentFileName = ValueNotifier<String>('movie.mp4');
      windowMode = ValueNotifier<WindowMode>(WindowMode.windowed);
    });

    tearDown(() {
      currentFileName.dispose();
      windowMode.dispose();
      video.dispose();
      port.dispose();
      engine.dispose();
    });

    Future<void> pumpPlaying(WidgetTester tester) async {
      // 默认测试表面 800×600 会把 1280×720 的 SizedBox 夹紧,坐标点漂移 —
      // 显式设定表面,使控制栏布局与谓词单测的 1280×720 几何一致。
      tester.view.physicalSize = _surface;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: _surface.width,
              height: _surface.height,
              child: PlayerVideoControls(
                video: video,
                engine: engine,
                actions: const PlayerActions(),
                currentFileName: currentFileName,
                windowMode: windowMode,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    /// 等待 playing 自动隐藏完成（3s 延迟 + 150ms 淡出）。
    Future<void> pumpUntilHidden(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: Tokens.hideDelayWindowed));
      await tester.pump(
        const Duration(milliseconds: Tokens.durationControlsFade + 1),
      );
    }

    /// 测试收尾协议：转非 playing 取消 pending hide timer 并永显，
    /// 避免手势 teardown 的 onExit 再排入新 timer（fake_async 终检报错）。
    Future<void> settleForTestEnd(WidgetTester tester) async {
      port.emitPlaying(false);
      await tester.pump();
      await tester.pumpAndSettle();
    }

    bool visibilityOf(WidgetTester tester) => tester
        .widget<Visibility>(find.byKey(const Key('player-controls-visibility')))
        .visible;

    /// 从实际布局取控制栏矩形（初始可见期）,判定点不依赖表面尺寸假设。
    Rect controlBarRect(WidgetTester tester) =>
        tester.getRect(find.byKey(const Key('player-controls-visibility')));

    testWidgets('鼠标从视频区进入不唤醒控制栏，移入控制栏矩形才显现', (tester) async {
      await pumpPlaying(tester);
      final barRect = controlBarRect(tester);
      // 控制栏上方 50px — 旧底部 150px 触发区内、新矩形外。
      final outsideBar = Offset(barRect.center.dx, barRect.top - 50);

      await pumpUntilHidden(tester);
      expect(visibilityOf(tester), isFalse);

      // 从控制栏上方进入 — 旧行为此处立即显现（onEnter 无条件 show）。
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: outsideBar - const Offset(40, 0));
      await gesture.moveTo(outsideBar);
      await tester.pump();
      expect(visibilityOf(tester), isFalse, reason: '控制栏外进入不得唤醒');

      // 移入控制栏本体矩形 → onHover 唤醒。
      await gesture.moveTo(barRect.center);
      await tester.pump();
      expect(visibilityOf(tester), isTrue, reason: '控制栏内移动应显现');

      await settleForTestEnd(tester);
    });

    testWidgets('鼠标直接进入控制栏矩形立即显现（onEnter 门控通过）', (tester) async {
      await pumpPlaying(tester);
      final barRect = controlBarRect(tester);
      await pumpUntilHidden(tester);
      expect(visibilityOf(tester), isFalse);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      // 直接落在控制栏矩形内进入 — onEnter 的 localPosition 在矩形内。
      await gesture.addPointer(location: barRect.center);
      await gesture.moveTo(barRect.center + const Offset(0, 5));
      await tester.pump();
      expect(visibilityOf(tester), isTrue, reason: '直接进入控制栏矩形应显现');

      await settleForTestEnd(tester);
    });

    testWidgets('控制栏可见后指针移出矩形，3s 静止即隐藏（保活收窄）', (tester) async {
      await pumpPlaying(tester);
      final barRect = controlBarRect(tester);
      final outsideBar = Offset(barRect.center.dx, barRect.top - 50);
      await pumpUntilHidden(tester);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: outsideBar - const Offset(40, 0));
      await gesture.moveTo(outsideBar);
      await tester.pump();
      await gesture.moveTo(barRect.center);
      await tester.pump();
      expect(visibilityOf(tester), isTrue);

      // 移出控制栏回到上方并静止 — 区外移动不刷新保活计时。
      await gesture.moveTo(outsideBar);
      await tester.pump();
      await pumpUntilHidden(tester);
      expect(visibilityOf(tester), isFalse, reason: '移出控制栏后应恢复自动隐藏');

      await settleForTestEnd(tester);
    });
  });
}
