// ignore_for_file: no-empty-block, avoid-passing-async-when-sync-expected, avoid-dynamic, avoid-redundant-async, avoid-self-compare, avoid-unnecessary-type-assertions, avoid-unused-parameters
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/volume_controls.dart';
import 'package:simple_player_flutter/ui/shared/osd_overlay.dart';

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

  Widget buildSubject({MediaEngine? eng, required Widget child}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  group('VolumeButton', () {
    testWidgets('shows volume_off icon when muted', (tester) async {
      engine.isMuted.value = true;
      await tester.pumpWidget(
        buildSubject(
          child: VolumeButton(
            volume: engine.volume,
            isMuted: engine.isMuted,
            onToggleMute: () => engine.setMute(!engine.isMuted.value),
            onSetVolume: engine.setVolume,
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.volume_off), findsOneWidget);
    });

    testWidgets('shows volume_off icon when volume is 0', (tester) async {
      engine.volume.value = 0;
      engine.isMuted.value = false;
      await tester.pumpWidget(
        buildSubject(
          child: VolumeButton(
            volume: engine.volume,
            isMuted: engine.isMuted,
            onToggleMute: () => engine.setMute(!engine.isMuted.value),
            onSetVolume: engine.setVolume,
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.volume_off), findsOneWidget);
    });

    testWidgets('shows volume_down icon when volume < 0.5', (tester) async {
      engine.volume.value = 0.3;
      engine.isMuted.value = false;
      await tester.pumpWidget(
        buildSubject(
          child: VolumeButton(
            volume: engine.volume,
            isMuted: engine.isMuted,
            onToggleMute: () => engine.setMute(!engine.isMuted.value),
            onSetVolume: engine.setVolume,
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.volume_down), findsOneWidget);
    });

    testWidgets('shows volume_up icon when volume >= 0.5', (tester) async {
      engine.volume.value = 0.8;
      engine.isMuted.value = false;
      await tester.pumpWidget(
        buildSubject(
          child: VolumeButton(
            volume: engine.volume,
            isMuted: engine.isMuted,
            onToggleMute: () => engine.setMute(!engine.isMuted.value),
            onSetVolume: engine.setVolume,
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.volume_up), findsOneWidget);
    });

    testWidgets('tap toggles mute on — 音量保持不动 (v0.0.8.1 原生静音)', (tester) async {
      engine.volume.value = 0.8;
      engine.isMuted.value = false;
      await tester.pumpWidget(
        buildSubject(
          child: VolumeButton(
            volume: engine.volume,
            isMuted: engine.isMuted,
            onToggleMute: () => engine.setMute(!engine.isMuted.value),
            onSetVolume: engine.setVolume,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();

      expect(engine.isMuted.value, isTrue);
      // 原生静音: mute 只切 isMuted, 音量属性不动 (滑条停在原值).
      expect(engine.volume.value, 0.8);
      expect(engine.setVolumeCallCount, 0, reason: 'mute 路径不得触碰音量');
      OsdService.I.hide();
    });

    testWidgets('tap toggles mute off and restores volume', (tester) async {
      engine.volume.value = 0.0;
      engine.isMuted.value = true;
      await tester.pumpWidget(
        buildSubject(
          child: VolumeButton(
            volume: engine.volume,
            isMuted: engine.isMuted,
            onToggleMute: () => engine.setMute(!engine.isMuted.value),
            onSetVolume: engine.setVolume,
          ),
        ),
      );
      await tester.pump();

      // First tap mutes (saves volume)
      // Second tap unmutes (restores volume)
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();

      // Since already muted, unmuting should restore
      expect(engine.isMuted.value, isFalse);
      OsdService.I.hide();
    });
  });

  group('VolumeSlider', () {
    testWidgets('slider reflects engine volume', (tester) async {
      engine.volume.value = 0.5;
      await tester.pumpWidget(
        buildSubject(
          child: VolumeSlider(
            volume: engine.volume,
            onSetVolume: engine.setVolume,
          ),
        ),
      );
      await tester.pump();

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 0.5);
    });

    testWidgets('slider updates when engine volume changes', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          child: VolumeSlider(
            volume: engine.volume,
            onSetVolume: engine.setVolume,
          ),
        ),
      );
      await tester.pump();

      engine.volume.value = 0.7;
      await tester.pump();

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 0.7);
    });

    testWidgets('dragging slider calls engine.setVolume', (tester) async {
      engine.volume.value = 0.5;
      await tester.pumpWidget(
        buildSubject(
          child: VolumeSlider(
            volume: engine.volume,
            onSetVolume: engine.setVolume,
          ),
        ),
      );
      await tester.pump();

      // Drag slider
      final slider = find.byType(Slider);
      final rect = tester.getRect(slider);
      final center = rect.center;

      // Drag from center to 80% of the slider width
      final startX = center.dx;
      final endX = rect.left + rect.width * 0.8;

      final gesture = await tester.startGesture(Offset(startX, center.dy));
      await gesture.moveBy(Offset(endX - startX, 0));
      await gesture.up();
      await tester.pump();

      // Volume should have changed
      expect(engine.volume.value, greaterThan(0.5));

      // Pump past OsdService hold timer to avoid pending timer
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('drag reports the interaction session boundaries', (
      tester,
    ) async {
      var started = 0;
      var ended = 0;
      engine.volume.value = 0.5;
      await tester.pumpWidget(
        buildSubject(
          child: VolumeSlider(
            volume: engine.volume,
            onSetVolume: engine.setVolume,
            onInteractionStart: () => started++,
            onInteractionEnd: () => ended++,
          ),
        ),
      );
      await tester.pump();

      final slider = find.byType(Slider);
      final center = tester.getRect(slider).center;
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(20, 0));
      await gesture.up();
      await tester.pump();

      expect(started, 1);
      expect(ended, 1);
      OsdService.I.hide();
    });

    testWidgets('scroll wheel up increases volume', (tester) async {
      engine.volume.value = 0.5;
      await tester.pumpWidget(
        buildSubject(
          child: VolumeSlider(
            volume: engine.volume,
            onSetVolume: engine.setVolume,
          ),
        ),
      );
      await tester.pump();

      final slider = find.byType(VolumeSlider);
      final center = tester.getRect(slider).center;

      // Scroll up → volume increases
      final event = PointerScrollEvent(
        scrollDelta: const Offset(0, -100),
        position: center,
      );
      GestureBinding.instance.handlePointerEvent(event);
      await tester.pump();

      expect(engine.volume.value, greaterThan(0.5));
      OsdService.I.hide();
    });

    testWidgets('scroll wheel down decreases volume', (tester) async {
      engine.volume.value = 0.5;
      await tester.pumpWidget(
        buildSubject(
          child: VolumeSlider(
            volume: engine.volume,
            onSetVolume: engine.setVolume,
          ),
        ),
      );
      await tester.pump();

      final slider = find.byType(VolumeSlider);
      final center = tester.getRect(slider).center;

      // Scroll down → volume decreases
      final event = PointerScrollEvent(
        scrollDelta: const Offset(0, 100),
        position: center,
      );
      GestureBinding.instance.handlePointerEvent(event);
      await tester.pump();

      expect(engine.volume.value, lessThan(0.5));
      OsdService.I.hide();
    });

    // ── Scroll boundary clamp ──

    testWidgets('scroll wheel up at max volume (1.0) clamps', (tester) async {
      engine.volume.value = 1.0;
      await tester.pumpWidget(
        buildSubject(
          child: VolumeSlider(
            volume: engine.volume,
            onSetVolume: engine.setVolume,
          ),
        ),
      );
      await tester.pump();

      final slider = find.byType(VolumeSlider);
      final center = tester.getRect(slider).center;

      final event = PointerScrollEvent(
        scrollDelta: const Offset(0, -100),
        position: center,
      );
      GestureBinding.instance.handlePointerEvent(event);
      await tester.pump();

      // Clamped at 1.0
      expect(engine.volume.value, 1.0);
      OsdService.I.hide();
    });

    testWidgets('scroll wheel down at min volume (0.0) clamps', (tester) async {
      engine.volume.value = 0.0;
      await tester.pumpWidget(
        buildSubject(
          child: VolumeSlider(
            volume: engine.volume,
            onSetVolume: engine.setVolume,
          ),
        ),
      );
      await tester.pump();

      final slider = find.byType(VolumeSlider);
      final center = tester.getRect(slider).center;

      final event = PointerScrollEvent(
        scrollDelta: const Offset(0, 100),
        position: center,
      );
      GestureBinding.instance.handlePointerEvent(event);
      await tester.pump();

      // Clamped at 0.0
      expect(engine.volume.value, 0.0);
      OsdService.I.hide();
    });

    testWidgets('unmute 保持音量不变 (原生静音, 无需快照恢复)', (tester) async {
      // Arrange: set volume to 0.7, then mute
      engine.volume.value = 0.7;
      engine.isMuted.value = false;
      await tester.pumpWidget(
        buildSubject(
          child: VolumeButton(
            volume: engine.volume,
            isMuted: engine.isMuted,
            onToggleMute: () => engine.setMute(!engine.isMuted.value),
            onSetVolume: engine.setVolume,
          ),
        ),
      );
      await tester.pump();

      // Tap to mute — 音量不动
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();
      expect(engine.isMuted.value, isTrue);
      expect(engine.volume.value, closeTo(0.7, 0.01));

      // Tap again to unmute — 音量原地即是原响度
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();
      expect(engine.isMuted.value, isFalse);
      expect(engine.volume.value, closeTo(0.7, 0.01));
      OsdService.I.hide();
    });

    testWidgets('静音时拖滑块到非零 — 自动取消静音', (tester) async {
      engine.volume.value = 0.0;
      engine.isMuted.value = true;
      await tester.pumpWidget(
        buildSubject(
          child: VolumeButton(
            volume: engine.volume,
            isMuted: engine.isMuted,
            onToggleMute: () => engine.setMute(!engine.isMuted.value),
            onSetVolume: engine.setVolume,
          ),
        ),
      );
      await tester.pump();

      // 模拟拖滑块到非零 — volume notifier 变更驱动 _onVolumeChanged.
      engine.volume.value = 0.45;
      await tester.pump();

      expect(engine.isMuted.value, isFalse, reason: '非零音量自动取消静音');
      OsdService.I.hide();
    });

    testWidgets('unmute OSD 显示当前音量百分比', (tester) async {
      engine.volume.value = 0.6;
      engine.isMuted.value = true;
      await tester.pumpWidget(
        buildSubject(
          child: VolumeButton(
            volume: engine.volume,
            isMuted: engine.isMuted,
            onToggleMute: () => engine.setMute(!engine.isMuted.value),
            onSetVolume: engine.setVolume,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();

      // OSD 渲染层挂载于 PlayerVideoControls — 本隔离装配断言 OsdService
      // 消息状态 (渲染层 find.text 由 player_video_controls_test 覆盖).
      expect(OsdService.I.message.value?.text, '60%', reason: 'OSD 显示当前音量');
      OsdService.I.hide();
      await tester.pump(const Duration(seconds: 2));
    });

    // ── Wave 2: interaction-level tests ──

    testWidgets('mute toggle 只切 isMuted 不触碰音量', (tester) async {
      // v0.0.8.1: _toggleMute 只走 onToggleMute(setMute), 不再 setVolume(0).
      engine.volume.value = 0.5;
      engine.isMuted.value = false;
      await tester.pumpWidget(
        buildSubject(
          child: VolumeButton(
            volume: engine.volume,
            isMuted: engine.isMuted,
            onToggleMute: () => engine.setMute(!engine.isMuted.value),
            onSetVolume: engine.setVolume,
          ),
        ),
      );
      await tester.pump();

      // Act: tap mute button
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();

      // Assert: muted + volume 保持
      expect(engine.isMuted.value, isTrue);
      expect(engine.volume.value, 0.5);
      expect(engine.setVolumeCallCount, 0);
      OsdService.I.hide();
    });

    testWidgets('unmute round-trip — 音量全程不被改动', (tester) async {
      // 验证静音→取消静音 的完整 round-trip (原生静音语义)
      engine.volume.value = 0.6;
      engine.isMuted.value = false;
      await tester.pumpWidget(
        buildSubject(
          child: VolumeButton(
            volume: engine.volume,
            isMuted: engine.isMuted,
            onToggleMute: () => engine.setMute(!engine.isMuted.value),
            onSetVolume: engine.setVolume,
          ),
        ),
      );
      await tester.pump();

      // Mute: 音量不动
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();
      expect(engine.isMuted.value, isTrue);
      expect(engine.volume.value, closeTo(0.6, 0.01));

      // Unmute: 音量原地即原响度
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();
      expect(engine.isMuted.value, isFalse);
      expect(engine.volume.value, closeTo(0.6, 0.01));
      expect(engine.setVolumeCallCount, 0);
      OsdService.I.hide();
    });

    testWidgets('slider value syncs with external engine.volume change', (
      tester,
    ) async {
      // 验证 VolumeSlider 的 ValueListenableBuilder 响应 engine.volume 变更
      engine.volume.value = 0.3;
      await tester.pumpWidget(
        buildSubject(
          child: VolumeSlider(
            volume: engine.volume,
            onSetVolume: engine.setVolume,
          ),
        ),
      );
      await tester.pump();

      var slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 0.3);

      // 模拟外部变更（如键盘快捷键触发）
      engine.volume.value = 0.9;
      await tester.pump();

      slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 0.9);
    });
  });
}
