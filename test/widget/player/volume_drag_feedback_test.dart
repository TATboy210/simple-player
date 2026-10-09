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
        Widget subject(ValueNotifier<double> source) => MaterialApp(
          home: Scaffold(
            body: VolumeSlider(
              volume: source,
              onSetVolume: writes.add,
              onInteractionStart: () => starts++,
              onInteractionEnd: () => ends++,
            ),
          ),
        );
        await tester.pumpWidget(subject(old));
        final slider = tester.widget<Slider>(find.byType(Slider));
        slider.onChangeStart?.call(0.5);
        slider.onChanged?.call(0.8);
        await tester.pump();
        await tester.pumpWidget(
          replacement ? subject(next) : const SizedBox.shrink(),
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
