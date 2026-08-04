import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  Widget buildSubject() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: VolumeSlider(volume: engine.volume, onSetVolume: engine.setVolume)),
  );

  group('VolumeSlider throttle', () {
    testWidgets('rapid onChanged produces ≤1 setVolume per 100ms window', (
      tester,
    ) async {
      engine.volume.value = 0.5;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final slider = tester.widget<Slider>(find.byType(Slider));
      final onChanged = slider.onChanged!;

      // 模拟 5 次快速拖拽（100ms 窗口内）
      onChanged(0.55);
      onChanged(0.60);
      onChanged(0.65);
      onChanged(0.70);
      onChanged(0.75);

      // 节流窗口内不应调用引擎
      expect(engine.setVolumeCallCount, 0);

      // 推进 100ms 让定时器触发
      await tester.pump(const Duration(milliseconds: 100));

      // 应该只调用一次，使用最新值
      expect(engine.setVolumeCallCount, 1);
      expect(engine.lastSetVolumeValue, 0.75);

      // 清理 OsdService 定时器
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('onChangeEnd immediately flushes final value', (
      tester,
    ) async {
      engine.volume.value = 0.5;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged!(0.6);
      slider.onChanged!(0.7);
      slider.onChangeEnd!(0.8);

      // onChangeEnd 应立即调用引擎，无需等待定时器
      expect(engine.setVolumeCallCount, 1);
      expect(engine.lastSetVolumeValue, 0.8);

      // 推进时间——定时器已被取消，不应再次调用
      await tester.pump(const Duration(milliseconds: 200));
      expect(engine.setVolumeCallCount, 1);

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('scroll wheel calls setVolume immediately (no throttle)', (
      tester,
    ) async {
      engine.volume.value = 0.5;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // 滚轮是离散事件，不经过 onChanged 节流路径
      final volumeSlider = find.byType(VolumeSlider);
      final center = tester.getRect(volumeSlider).center;

      final event = PointerScrollEvent(
        scrollDelta: const Offset(0, -100),
        position: center,
      );
      GestureBinding.instance.handlePointerEvent(event);
      await tester.pump();

      // 滚轮应立即调用 setVolume
      expect(engine.setVolumeCallCount, 1);
      expect(engine.lastSetVolumeValue, greaterThan(0.5));

      OsdService.I.hide();
    });

    testWidgets('dispose cancels pending timer (no leak)', (tester) async {
      engine.volume.value = 0.5;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // 触发节流定时器
      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged!(0.7);

      // 定时器尚未触发
      expect(engine.setVolumeCallCount, 0);

      // 移除 widget → dispose → cancel timer
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();

      // 推进时间——定时器已取消，不应调用
      await tester.pump(const Duration(milliseconds: 200));
      expect(engine.setVolumeCallCount, 0);
    });

    testWidgets('second throttle window works after first flush', (
      tester,
    ) async {
      engine.volume.value = 0.5;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final slider = tester.widget<Slider>(find.byType(Slider));
      final onChanged = slider.onChanged!;
      final onChangeEnd = slider.onChangeEnd!;

      // 第一个窗口
      onChanged(0.6);
      onChanged(0.7);
      await tester.pump(const Duration(milliseconds: 100));
      expect(engine.setVolumeCallCount, 1);
      expect(engine.lastSetVolumeValue, 0.7);

      // 第二个窗口
      onChanged(0.8);
      onChanged(0.9);
      await tester.pump(const Duration(milliseconds: 100));
      expect(engine.setVolumeCallCount, 2);
      expect(engine.lastSetVolumeValue, 0.9);

      // 松手
      onChangeEnd(1.0);
      expect(engine.setVolumeCallCount, 3);
      expect(engine.lastSetVolumeValue, 1.0);

      await tester.pump(const Duration(seconds: 2));
    });
  });
}
