import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/player/volume_controls.dart';
import 'package:simple_player_flutter/ui/shared/osd_overlay.dart';

void main() {
  tearDown(() => OsdService.I.hide());
  testWidgets(
    'latest local move beats delayed echoes and release flushes once',
    (tester) async {
      final volume = ValueNotifier(0.5);
      addTearDown(volume.dispose);
      final writes = <double>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VolumeSlider(volume: volume, onSetVolume: writes.add),
          ),
        ),
      );
      Slider slider() => tester.widget<Slider>(find.byType(Slider));
      slider().onChangeStart?.call(0.5);
      for (final value in [0.6, 0.7, 0.8]) {
        slider().onChanged?.call(value);
        await tester.pump();
        expect(slider().value, value);
        volume.value = value - 0.2;
        await tester.pump();
        expect(
          slider().value,
          value,
          reason: 'engine echo cannot overwrite drag',
        );
      }
      expect(writes, isEmpty);
      await tester.pump(const Duration(milliseconds: 100));
      expect(writes, [0.8]);
      slider().onChanged?.call(0.9);
      await tester.pump();
      expect(slider().value, 0.9);
      slider().onChangeEnd?.call(0.9);
      await tester.pump();
      expect(writes, [0.8, 0.9]);
      expect(
        slider().value,
        volume.value,
        reason: 'release returns external authority',
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(writes, [0.8, 0.9]);
      OsdService.I.hide();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final replacement in [false, true]) {
    testWidgets(
      'pending drag cancels on ${replacement ? 'source replacement' : 'unmount'}',
      (tester) async {
        final old = ValueNotifier(0.5);
        final next = ValueNotifier(0.2);
        addTearDown(old.dispose);
        addTearDown(next.dispose);
        var starts = 0;
        var ends = 0;
        final writes = <double>[];
        // 可选 key 透传给 VolumeSlider.sourceKey —— 用例 C 在换源同时换键,
        // 断言与换源前完全一致(双信号同时触发的收敛行为不变)。
        Widget subject(ValueNotifier<double> source, {Object? key}) =>
            MaterialApp(
              home: Scaffold(
                body: VolumeSlider(
                  volume: source,
                  onSetVolume: writes.add,
                  onInteractionStart: () => starts++,
                  onInteractionEnd: () => ends++,
                  sourceKey: key,
                ),
              ),
            );
        await tester.pumpWidget(subject(old, key: 'source-a'));
        final slider = tester.widget<Slider>(find.byType(Slider));
        slider.onChangeStart?.call(0.5);
        slider.onChanged?.call(0.8);
        await tester.pump();
        await tester.pumpWidget(
          replacement
              ? subject(next, key: 'source-b')
              : const SizedBox.shrink(),
        );
        // Captured callbacks from the old gesture cannot resurrect a timer.
        slider.onChanged?.call(0.9);
        slider.onChangeEnd?.call(0.9);
        await tester.pump(const Duration(milliseconds: 200));
        expect(writes, isEmpty);
        expect(starts, 1);
        expect(ends, 1);
        if (replacement) {
          expect(tester.widget<Slider>(find.byType(Slider)).value, 0.2);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  group('sourceKey identity signal', () {
    testWidgets(
      'same sourceKey rebuild with fresh lambda keeps drag alive',
      (tester) async {
        // 用例 A（回归主场景）：上游把 tear-off 重构为 lambda 后，每次父级
        // 重建都会生成新 onSetVolume 闭包 —— 旧回调相等性推断会把这当成
        // 「源被替换」而中途取消拖动。只要 sourceKey 不变，拖动必须存活。
        final volume = ValueNotifier(0.5);
        addTearDown(volume.dispose);
        var starts = 0;
        var ends = 0;
        final writes = <double>[];
        // lambda 内联在 subject 函数体内：每次调用生成新闭包，复现
        // tear-off→lambda 重构场景。
        Widget subject(Object? key) => MaterialApp(
          home: Scaffold(
            body: VolumeSlider(
              volume: volume,
              onSetVolume: (v) => writes.add(v),
              onInteractionStart: () => starts++,
              onInteractionEnd: () => ends++,
              sourceKey: key,
            ),
          ),
        );
        await tester.pumpWidget(subject('stable'));
        final slider = tester.widget<Slider>(find.byType(Slider));
        slider.onChangeStart?.call(0.5);
        slider.onChanged?.call(0.8);
        await tester.pump();
        expect(writes, isEmpty);
        // 父级重建：同 sourceKey + 新 lambda —— 拖动不得被取消。
        await tester.pumpWidget(subject('stable'));
        final rebuilt = tester.widget<Slider>(find.byType(Slider));
        rebuilt.onChanged?.call(0.9);
        await tester.pump();
        expect(rebuilt.value, 0.9, reason: 'drag survives same-key rebuild');
        // 节流 flush 仍提交写入；ends 在 onChangeEnd 前保持 0。
        await tester.pump(const Duration(milliseconds: 200));
        expect(writes, [0.9], reason: 'throttled flush survives rebuild');
        expect(ends, 0, reason: 'same-key rebuild must not cancel drag');
        rebuilt.onChangeEnd?.call(0.9);
        await tester.pump();
        expect(ends, 1, reason: 'release still notifies end exactly once');
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('sourceKey change alone cancels pending drag', (tester) async {
      // 用例 B（安全属性）：notifier 不变、sourceKey 变化 = 显式声明的源
      // 替换 —— 在途拖动必须立即取消且安全属性保全：pending 写入清空、
      // ends 用旧 widget 的 onInteractionEnd 通知、滑条回落 notifier 值、
      // 旧捕获回调不再能复活定时器。
      final volume = ValueNotifier(0.5);
      addTearDown(volume.dispose);
      var starts = 0;
      var ends = 0;
      final writes = <double>[];
      Widget subject(Object? key) => MaterialApp(
        home: Scaffold(
          body: VolumeSlider(
            volume: volume,
            onSetVolume: writes.add,
            onInteractionStart: () => starts++,
            onInteractionEnd: () => ends++,
            sourceKey: key,
          ),
        ),
      );
      await tester.pumpWidget(subject('a'));
      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChangeStart?.call(0.5);
      slider.onChanged?.call(0.8);
      await tester.pump();
      await tester.pumpWidget(subject('b'));
      // 重建后用旧捕获的 Slider 回调再调用是 no-op。
      slider.onChanged?.call(0.9);
      slider.onChangeEnd?.call(0.9);
      await tester.pump(const Duration(milliseconds: 200));
      expect(writes, isEmpty, reason: 'pending write must be discarded');
      expect(starts, 1);
      expect(ends, 1, reason: 'cancel notifies the old hook');
      expect(
        tester.widget<Slider>(find.byType(Slider)).value,
        0.5,
        reason: 'slider falls back to notifier value',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets(
    'pointer cancel ends interaction without committing pending value',
    (tester) async {
      final volume = ValueNotifier(0.5);
      addTearDown(volume.dispose);
      final writes = <double>[];
      var ends = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VolumeSlider(
              volume: volume,
              onSetVolume: writes.add,
              onInteractionEnd: () => ends++,
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Slider)),
      );
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await gesture.cancel();
      await tester.pump(const Duration(milliseconds: 200));
      expect(writes, isEmpty);
      expect(ends, 1);
      expect(tester.widget<Slider>(find.byType(Slider)).value, 0.5);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
